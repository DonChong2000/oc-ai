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
  if options.tools ~= nil then
    body.tools = options.tools
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

  local step = {
    content = content,
    text = text,
    reasoning = nil,
    reasoningText = nil,
    files = nil,
    sources = nil,
    toolCalls = {},
    toolResults = {},
    finishReason = finish_reason,
    rawFinishReason = raw_finish_reason,
    usage = usage,
    response = response_info,
  }

  return {
    content = content,
    text = text,
    reasoning = nil,
    reasoningText = nil,
    sources = nil,
    files = nil,
    toolCalls = {},
    toolResults = {},
    staticToolCalls = {},
    dynamicToolCalls = {},
    staticToolResults = {},
    dynamicToolResults = {},
    finishReason = finish_reason,
    rawFinishReason = raw_finish_reason,
    usage = usage,
    response = response_info,
    warnings = nil,
    providerMetadata = nil,
    output = nil,
    steps = { step },
    experimental_context = nil,
  }
end

return ai
