local json = require("ai.json")
local utils = require("ai.utils")

local ai = {}

-- Output specification helpers
ai.Output = {
  object = function(opts)
    return {
      type = "object",
      schema = opts.schema,
    }
  end,
}

-- Tool helper for cleaner tool definitions
function ai.tool(opts)
  if type(opts) ~= "table" then
    error("tool requires a table argument")
  end
  if not opts.name then
    error("tool requires a name")
  end
  return {
    type = "function",
    ["function"] = {
      name = opts.name,
      description = opts.description,
      parameters = opts.parameters,
      execute = opts.execute,
    },
  }
end

local GATEWAY_URL = "https://ai-gateway.vercel.sh/v1/chat/completions"

local function findTool(tools, name)
  if not tools then return nil end
  for _, tool in ipairs(tools) do
    if tool.type == "function" and tool["function"].name == name then
      return tool
    end
  end
  return nil
end

local function executeTool(tool, args)
  local fn = tool["function"]
  if fn and fn.execute then
    local ok, result = pcall(fn.execute, args)
    if ok then
      return result
    else
      return { error = tostring(result) }
    end
  end
  return { error = "No execute function" }
end

-- Gateway model (OpenAI-compatible)
local function createGatewayModel(modelId, apiKey)
  local model = {
    modelId = modelId,
    provider = "gateway",
  }

  local function buildMessages(opts)
    local messages = {}
    if opts.system then
      table.insert(messages, { role = "system", content = opts.system })
    end
    if opts.messages then
      for _, msg in ipairs(opts.messages) do
        table.insert(messages, msg)
      end
    elseif opts.prompt then
      table.insert(messages, { role = "user", content = opts.prompt })
    end
    return messages
  end

  local function buildTools(tools)
    if not tools then return nil end
    local result = {}
    for _, tool in ipairs(tools) do
      if tool.type == "function" then
        table.insert(result, {
          type = "function",
          ["function"] = {
            name = tool["function"].name,
            description = tool["function"].description,
            parameters = tool["function"].parameters,
          },
        })
      end
    end
    return #result > 0 and result or nil
  end

  function model.doGenerate(opts)
    local messages = buildMessages(opts)

    local requestBody = {
      model = modelId,
      messages = messages,
    }
    if opts.maxOutputTokens then
      requestBody.max_tokens = opts.maxOutputTokens
    end
    if opts.temperature then
      requestBody.temperature = opts.temperature
    end
    if opts.topP then
      requestBody.top_p = opts.topP
    end
    if opts.tools then
      requestBody.tools = buildTools(opts.tools)
    end
    if opts.toolChoice then
      requestBody.tool_choice = opts.toolChoice
    end

    local headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. (apiKey or ""),
    }

    local bodyJson = json.encode(requestBody)
    local responseText = utils.httpPost(GATEWAY_URL, headers, bodyJson)

    local ok, responseData = pcall(json.decode, responseText)
    if not ok then
      error("Failed to parse response: " .. responseText)
    end

    if responseData.error then
      error(responseData.error.message or json.encode(responseData.error))
    end

    local choice = responseData.choices and responseData.choices[1]
    if not choice then
      error("No choices in response")
    end

    local message = choice.message
    local usage = {}
    if responseData.usage then
      usage.inputTokens = responseData.usage.prompt_tokens
      usage.outputTokens = responseData.usage.completion_tokens
      usage.totalTokens = responseData.usage.total_tokens
    end

    return {
      text = message.content or "",
      finishReason = choice.finish_reason,
      toolCalls = message.tool_calls,
      usage = usage,
      rawMessage = message,
    }, responseData
  end

  function model.formatToolResult(toolCall, result)
    local resultStr = type(result) == "string" and result or json.encode(result)
    return {
      role = "tool",
      tool_call_id = toolCall.id,
      content = resultStr,
    }
  end

  function model.addAssistantMessage(messages, parsed)
    table.insert(messages, {
      role = "assistant",
      content = parsed.text,
      tool_calls = parsed.toolCalls,
    })
  end

  function model.addToolResults(messages, toolResults)
    for _, result in ipairs(toolResults) do
      table.insert(messages, result)
    end
  end

  function model.doStream(opts, onChunk)
    local messages = buildMessages(opts)

    local requestBody = {
      model = modelId,
      messages = messages,
      stream = true,
    }
    if opts.maxOutputTokens then
      requestBody.max_tokens = opts.maxOutputTokens
    end
    if opts.temperature then
      requestBody.temperature = opts.temperature
    end
    if opts.topP then
      requestBody.top_p = opts.topP
    end
    if opts.tools then
      requestBody.tools = buildTools(opts.tools)
    end
    if opts.toolChoice then
      requestBody.tool_choice = opts.toolChoice
    end

    local headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. (apiKey or ""),
    }

    local bodyJson = json.encode(requestBody)
    local request = utils.httpPostStream(GATEWAY_URL, headers, bodyJson)

    local fullText = ""
    local finishReason = nil
    local toolCalls = {}
    local buffer = ""

    for chunk in request do
      buffer = buffer .. chunk
      while true do
        local lineEnd = buffer:find("\n")
        if not lineEnd then break end
        local line = buffer:sub(1, lineEnd - 1)
        buffer = buffer:sub(lineEnd + 1)

        if line ~= "" then
          local eventType, data = utils.parseSSELine(line)
          if eventType == "done" then
            break
          elseif eventType == "data" and data then
            local choice = data.choices and data.choices[1]
            if choice then
              local delta = choice.delta
              if delta and delta.content then
                fullText = fullText .. delta.content
                if onChunk then
                  onChunk({ type = "text", text = delta.content })
                end
              end
              if delta and delta.tool_calls then
                for _, tc in ipairs(delta.tool_calls) do
                  local idx = (tc.index or 0) + 1
                  if not toolCalls[idx] then
                    toolCalls[idx] = {
                      id = tc.id,
                      type = "function",
                      ["function"] = { name = "", arguments = "" },
                    }
                  end
                  if tc.id then toolCalls[idx].id = tc.id end
                  if tc["function"] then
                    if tc["function"].name then
                      toolCalls[idx]["function"].name = toolCalls[idx]["function"].name .. tc["function"].name
                    end
                    if tc["function"].arguments then
                      toolCalls[idx]["function"].arguments = toolCalls[idx]["function"].arguments .. tc["function"].arguments
                    end
                  end
                end
              end
              if choice.finish_reason then
                finishReason = choice.finish_reason
              end
            end
          end
        end
      end
    end

    local toolCallsList = {}
    for _, tc in pairs(toolCalls) do
      table.insert(toolCallsList, tc)
    end

    return {
      text = fullText,
      finishReason = finishReason,
      toolCalls = #toolCallsList > 0 and toolCallsList or nil,
      usage = {},
    }
  end

  return model
end

function ai.generateText(opts)
  if type(opts) ~= "table" then
    error("generateText requires a table argument")
  end
  if not opts.model then
    error("model is required")
  end
  if not opts.prompt and not opts.messages then
    error("prompt or messages is required")
  end

  -- Get or create model
  local model
  if type(opts.model) == "table" and opts.model.doGenerate then
    model = opts.model
  else
    local apiKey = os.getenv("AI_GATEWAY_API_KEY")
    if not apiKey or apiKey == "" then
      error("API key is required. Set AI_GATEWAY_API_KEY environment variable.")
    end
    model = createGatewayModel(opts.model, apiKey)
  end

  local maxSteps = opts.maxSteps or 1
  local allToolResults = {}
  local totalUsage = { inputTokens = 0, outputTokens = 0, totalTokens = 0 }
  local text, finishReason, rawResponse

  -- Copy opts for mutation during tool loop
  local currentOpts = {}
  for k, v in pairs(opts) do
    currentOpts[k] = v
  end

  -- Handle structured output
  local outputSpec = opts.output
  if outputSpec and outputSpec.type == "object" then
    local schemaJson = json.encode(outputSpec.schema)
    local systemPrompt = "Output JSON only. No extra text. No code blocks. Schema:\n" .. schemaJson
    if currentOpts.system then
      currentOpts.system = currentOpts.system .. "\n\n" .. systemPrompt
    else
      currentOpts.system = systemPrompt
    end
  end

  for step = 1, maxSteps do
    local parsed
    parsed, rawResponse = model.doGenerate(currentOpts)

    text = parsed.text
    finishReason = parsed.finishReason
    totalUsage.inputTokens = totalUsage.inputTokens + (parsed.usage.inputTokens or 0)
    totalUsage.outputTokens = totalUsage.outputTokens + (parsed.usage.outputTokens or 0)
    totalUsage.totalTokens = totalUsage.totalTokens + (parsed.usage.totalTokens or 0)

    if not parsed.toolCalls or #parsed.toolCalls == 0 then
      break
    end

    -- Build messages for next iteration
    currentOpts.messages = currentOpts.messages or {}
    if currentOpts.prompt then
      table.insert(currentOpts.messages, { role = "user", content = currentOpts.prompt })
      currentOpts.prompt = nil
    end

    model.addAssistantMessage(currentOpts.messages, parsed)

    local toolResultParts = {}
    for _, toolCall in ipairs(parsed.toolCalls) do
      local tool = findTool(opts.tools, toolCall["function"].name)
      local args = {}
      if toolCall["function"].arguments then
        local ok, parsed_args = pcall(json.decode, toolCall["function"].arguments)
        if ok then args = parsed_args end
      end

      local result
      if tool then
        result = executeTool(tool, args)
      else
        result = { error = "Unknown tool: " .. toolCall["function"].name }
      end

      table.insert(allToolResults, {
        toolCallId = toolCall.id,
        toolName = toolCall["function"].name,
        args = args,
        result = result,
      })

      table.insert(toolResultParts, model.formatToolResult(toolCall, result))
    end

    model.addToolResults(currentOpts.messages, toolResultParts)

    if step == maxSteps then
      break
    end
  end

  -- Parse structured output
  local output = nil
  if outputSpec and outputSpec.type == "object" and text then
    local ok, parsed = pcall(json.decode, text)
    if ok then
      output = parsed
    end
  end

  return {
    text = text,
    output = output,
    finishReason = finishReason,
    usage = totalUsage,
    toolResults = allToolResults,
    response = rawResponse,
  }
end

function ai.streamText(opts)
  if type(opts) ~= "table" then
    error("streamText requires a table argument")
  end
  if not opts.model then
    error("model is required")
  end
  if not opts.prompt and not opts.messages then
    error("prompt or messages is required")
  end

  -- Get or create model
  local model
  if type(opts.model) == "table" and opts.model.doStream then
    model = opts.model
  elseif type(opts.model) == "table" and opts.model.doGenerate then
    error("This model does not support streaming")
  else
    local apiKey = os.getenv("AI_GATEWAY_API_KEY")
    if not apiKey or apiKey == "" then
      error("API key is required. Set AI_GATEWAY_API_KEY environment variable.")
    end
    model = createGatewayModel(opts.model, apiKey)
  end

  local maxSteps = opts.maxSteps or 1
  local allToolResults = {}
  local text, finishReason

  -- Copy opts for mutation during tool loop
  local currentOpts = {}
  for k, v in pairs(opts) do
    currentOpts[k] = v
  end

  local onChunk = opts.onChunk

  for step = 1, maxSteps do
    local parsed = model.doStream(currentOpts, onChunk)

    text = parsed.text
    finishReason = parsed.finishReason

    if not parsed.toolCalls or #parsed.toolCalls == 0 then
      break
    end

    -- Build messages for next iteration
    currentOpts.messages = currentOpts.messages or {}
    if currentOpts.prompt then
      table.insert(currentOpts.messages, { role = "user", content = currentOpts.prompt })
      currentOpts.prompt = nil
    end

    model.addAssistantMessage(currentOpts.messages, parsed)

    local toolResultParts = {}
    for _, toolCall in ipairs(parsed.toolCalls) do
      local tool = findTool(opts.tools, toolCall["function"].name)
      local args = {}
      if toolCall["function"].arguments then
        local ok, parsed_args = pcall(json.decode, toolCall["function"].arguments)
        if ok then args = parsed_args end
      end

      local result
      if tool then
        result = executeTool(tool, args)
      else
        result = { error = "Unknown tool: " .. toolCall["function"].name }
      end

      table.insert(allToolResults, {
        toolCallId = toolCall.id,
        toolName = toolCall["function"].name,
        args = args,
        result = result,
      })

      table.insert(toolResultParts, model.formatToolResult(toolCall, result))
    end

    model.addToolResults(currentOpts.messages, toolResultParts)

    if step == maxSteps then
      break
    end
  end

  if opts.onFinish then
    opts.onFinish({
      text = text,
      finishReason = finishReason,
      toolResults = allToolResults,
    })
  end

  return {
    text = text,
    finishReason = finishReason,
    toolResults = allToolResults,
  }
end

function ai.generateObject(opts)
  if type(opts) ~= "table" then
    error("generateObject requires a table argument")
  end
  if not opts.model then
    error("model is required")
  end
  if not opts.schema then
    error("schema is required")
  end
  if not opts.prompt and not opts.messages then
    error("prompt or messages is required")
  end

  local result = ai.generateText({
    model = opts.model,
    prompt = opts.prompt,
    messages = opts.messages,
    system = opts.system,
    maxOutputTokens = opts.maxOutputTokens,
    temperature = opts.temperature,
    topP = opts.topP,
    output = ai.Output.object({ schema = opts.schema }),
  })

  if not result.output then
    error("Failed to parse structured output")
  end

  return {
    object = result.output,
    finishReason = result.finishReason,
    usage = result.usage,
    response = result.response,
  }
end

return ai
