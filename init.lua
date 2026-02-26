local internet = require("internet")
local json = require("json")

local ai = {}

local function normalize_system_messages(system)
  if system == nil then
    return {}
  end
  if type(system) == "string" then
    return { { role = "system", content = system } }
  end
  if type(system) == "table" then
    if system.role then
      return { system }
    end
    return system
  end
  error("invalid system type")
end

local function normalize_messages(options)
  if options.messages ~= nil then
    return options.messages
  end

  if options.prompt == nil then
    error("prompt or messages is required")
  end

  local messages = {}
  local system_messages = normalize_system_messages(options.system)
  for i = 1, #system_messages do
    messages[#messages + 1] = system_messages[i]
  end

  if type(options.prompt) == "string" then
    messages[#messages + 1] = { role = "user", content = options.prompt }
    return messages
  end

  if type(options.prompt) == "table" then
    for i = 1, #options.prompt do
      messages[#messages + 1] = options.prompt[i]
    end
    return messages
  end

  error("prompt must be a string or table")
end

local function read_all(handle)
  local chunks = {}
  while true do
    local chunk = handle()
    if not chunk then
      break
    end
    chunks[#chunks + 1] = chunk
  end
  return table.concat(chunks)
end

local function map_finish_reason(raw)
  if raw == "stop" then
    return "stop"
  end
  if raw == "length" then
    return "length"
  end
  if raw == "content_filter" then
    return "content-filter"
  end
  if raw == "tool_calls" then
    return "tool-calls"
  end
  if raw == "error" then
    return "error"
  end
  return "other"
end

local function build_usage(usage)
  if type(usage) ~= "table" then
    return nil
  end
  return {
    inputTokens = usage.prompt_tokens,
    outputTokens = usage.completion_tokens,
    totalTokens = usage.total_tokens,
    raw = usage,
  }
end

local function merge_headers(base, extra)
  if type(extra) ~= "table" then
    return base
  end
  for key, value in pairs(extra) do
    if value ~= nil then
      base[key] = tostring(value)
    end
  end
  return base
end

local function copy_tool_definition(tool)
  if type(tool) ~= "table" then
    return tool
  end
  local copied = {}
  for key, value in pairs(tool) do
    if key == "execute" then
    elseif key == "function" and type(value) == "table" then
      local func = {}
      for func_key, func_value in pairs(value) do
        if func_key ~= "execute" then
          func[func_key] = func_value
        end
      end
      copied[key] = func
    else
      copied[key] = value
    end
  end
  return copied
end

local function normalize_tools(tools)
  if type(tools) ~= "table" then
    return nil, {}
  end

  local api_tools = {}
  local executors = {}

  if tools[1] ~= nil then
    for i = 1, #tools do
      local tool = tools[i]
      api_tools[#api_tools + 1] = copy_tool_definition(tool)
      if type(tool) == "table" then
        local func = tool["function"]
        local name = func and func.name or nil
        local execute = (func and func.execute) or tool.execute
        if type(name) == "string" and type(execute) == "function" then
          executors[name] = execute
        end
      end
    end
    return api_tools, executors
  end

  for name, tool in pairs(tools) do
    if type(tool) == "table" then
      local func = tool["function"] or {}
      local tool_name = func.name or tool.name or name
      local execute = tool.execute or func.execute
      local parameters = func.parameters or tool.parameters
      local description = func.description or tool.description
      api_tools[#api_tools + 1] = {
        type = "function",
        ["function"] = {
          name = tool_name,
          description = description,
          parameters = parameters,
        },
      }
      if type(tool_name) == "string" and type(execute) == "function" then
        executors[tool_name] = execute
      end
    end
  end

  return api_tools, executors
end

local function decode_tool_args(raw_args)
  if type(raw_args) ~= "string" then
    return {}
  end
  local ok, decoded = pcall(json.decode, raw_args)
  if not ok or type(decoded) ~= "table" then
    return {}
  end
  return decoded
end

function ai.generateText(options)
  if type(options) ~= "table" then
    error("options must be a table")
  end
  if type(options.model) ~= "string" then
    error("model is required")
  end

  local messages = normalize_messages(options)

  local headers = {
    ["Content-Type"] = "application/json",
    ["Accept"] = "application/json",
  }

  if options.apiKey ~= nil then
    headers.Authorization = "Bearer " .. tostring(options.apiKey)
  end
  headers = merge_headers(headers, options.headers)

  if not headers.Authorization then
    error("missing API key: set options.apiKey or Authorization header")
  end

  local api_tools, executors = normalize_tools(options.tools)
  local max_steps = options.maxSteps
  if type(max_steps) ~= "number" or max_steps < 1 then
    if api_tools then
      max_steps = 5
    else
      max_steps = 1
    end
  end

  local steps = {}
  local all_tool_calls = {}
  local all_tool_results = {}
  local last_content = { { type = "text", text = "" } }
  local last_text = ""
  local last_finish_reason = "stop"
  local last_raw_finish_reason = nil
  local last_usage = nil
  local last_response = nil

  for step_number = 1, max_steps do
    local body = {
      model = options.model,
      messages = messages,
      stream = false,
    }

    if options.temperature ~= nil then
      body.temperature = options.temperature
    end
    if options.topP ~= nil then
      body.top_p = options.topP
    end
    if options.topK ~= nil then
      body.top_k = options.topK
    end
    if options.presencePenalty ~= nil then
      body.presence_penalty = options.presencePenalty
    end
    if options.frequencyPenalty ~= nil then
      body.frequency_penalty = options.frequencyPenalty
    end
    if options.stopSequences ~= nil then
      body.stop = options.stopSequences
    end
    if options.seed ~= nil then
      body.seed = options.seed
    end
    if options.maxOutputTokens ~= nil then
      body.max_tokens = options.maxOutputTokens
    elseif options.maxTokens ~= nil then
      body.max_tokens = options.maxTokens
    end
    if api_tools ~= nil then
      body.tools = api_tools
    end
    if options.toolChoice ~= nil then
      body.tool_choice = options.toolChoice
    end

    local response = internet.request(
      "https://ai-gateway.vercel.sh/v1/chat/completions",
      json.encode(body),
      headers,
      "POST"
    )

    local raw_body = read_all(response)
    local ok, decoded = pcall(json.decode, raw_body)
    if not ok then
      error("failed to parse response JSON")
    end

    if type(decoded) == "table" and decoded.error then
      local message = decoded.error.message or "unknown error"
      error(message)
    end

    local choice = decoded and decoded.choices and decoded.choices[1] or nil
    local message = choice and choice.message or nil
    local text = (message and message.content) or ""
    local raw_finish_reason = choice and choice.finish_reason or nil
    local finish_reason = map_finish_reason(raw_finish_reason)
    local usage = build_usage(decoded and decoded.usage or nil)

    local content = { { type = "text", text = text } }
    local response_info = {
      id = decoded and decoded.id or nil,
      modelId = decoded and decoded.model or options.model,
      timestamp = decoded and decoded.created or os.time(),
      headers = nil,
      body = decoded,
      messages = message and { message } or nil,
    }

    local step_tool_calls = {}
    local tool_calls = message and message.tool_calls or nil
    if type(tool_calls) == "table" then
      for i = 1, #tool_calls do
        local tool_call = tool_calls[i]
        local func_info = tool_call and tool_call["function"] or {}
        local tool_name = func_info.name
        local args = decode_tool_args(func_info.arguments)
        local normalized_call = {
          type = "tool-call",
          toolCallId = tool_call.id,
          toolName = tool_name,
          input = args,
          rawInput = func_info.arguments,
        }
        step_tool_calls[#step_tool_calls + 1] = normalized_call
        all_tool_calls[#all_tool_calls + 1] = normalized_call
      end
    end

    if message ~= nil then
      messages[#messages + 1] = message
    end

    local step_tool_results = {}
    if #step_tool_calls > 0 then
      if next(executors) == nil then
        error("tool execution requested but no executors were provided")
      end

      for i = 1, #step_tool_calls do
        local call = step_tool_calls[i]
        local execute = executors[call.toolName]
        if type(execute) ~= "function" then
          error("tool not implemented: " .. tostring(call.toolName))
        end
        local ok_exec, output = pcall(execute, call.input)
        if not ok_exec then
          output = { error = tostring(output) }
        end

        local tool_result = {
          type = "tool-result",
          toolCallId = call.toolCallId,
          toolName = call.toolName,
          output = output,
        }
        step_tool_results[#step_tool_results + 1] = tool_result
        all_tool_results[#all_tool_results + 1] = tool_result
        messages[#messages + 1] = {
          role = "tool",
          tool_call_id = call.toolCallId,
          content = json.encode(output),
        }
      end
    end

    local step = {
      content = content,
      text = text,
      reasoning = nil,
      reasoningText = nil,
      files = nil,
      sources = nil,
      toolCalls = step_tool_calls,
      toolResults = step_tool_results,
      finishReason = finish_reason,
      rawFinishReason = raw_finish_reason,
      usage = usage,
      response = response_info,
    }
    steps[#steps + 1] = step

    last_content = content
    last_text = text
    last_finish_reason = finish_reason
    last_raw_finish_reason = raw_finish_reason
    last_usage = usage
    last_response = response_info

    if #step_tool_calls == 0 then
      break
    end
  end

  return {
    content = last_content,
    text = last_text,
    reasoning = nil,
    reasoningText = nil,
    sources = nil,
    files = nil,
    toolCalls = all_tool_calls,
    toolResults = all_tool_results,
    staticToolCalls = {},
    dynamicToolCalls = {},
    staticToolResults = {},
    dynamicToolResults = {},
    finishReason = last_finish_reason,
    rawFinishReason = last_raw_finish_reason,
    usage = last_usage,
    response = last_response,
    warnings = nil,
    providerMetadata = nil,
    output = nil,
    steps = steps,
    experimental_context = nil,
  }
end

return ai
