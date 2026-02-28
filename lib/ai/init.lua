local json = require("cmn-utils.json")
local vercel = require("ai.vercel")

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
    model = vercel(opts.model)
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
    model = vercel(opts.model)
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
