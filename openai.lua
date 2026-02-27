local internet = require("internet")
local json = require("ai.json")

local DEFAULT_BASE_URL = "https://api.openai.com/v1"

local function httpPost(url, headers, body)
  local response = ""
  local request = internet.request(url, body, headers)
  for chunk in request do
    response = response .. chunk
  end
  return response
end

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

local function parseResponse(response)
  local choice = response.choices and response.choices[1]
  if not choice then
    error("No choices in response")
  end

  local message = choice.message
  local usage = {}
  if response.usage then
    usage.inputTokens = response.usage.prompt_tokens
    usage.outputTokens = response.usage.completion_tokens
    usage.totalTokens = response.usage.total_tokens
  end

  return {
    text = message.content or "",
    finishReason = choice.finish_reason,
    toolCalls = message.tool_calls,
    usage = usage,
    rawMessage = message,
  }
end

local function createLanguageModel(modelId, config)
  local model = {
    modelId = modelId,
    provider = config.provider,
  }

  function model.doGenerate(opts)
    local apiKey = config.getApiKey()
    if not apiKey or apiKey == "" then
      error("API key is required. Set OPENAI_API_KEY environment variable or pass apiKey to createOpenAI().")
    end

    local url = config.baseURL .. "/chat/completions"
    local headers = config.getHeaders()
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

    local bodyJson = json.encode(requestBody)
    local responseText = httpPost(url, headers, bodyJson)

    local ok, responseData = pcall(json.decode, responseText)
    if not ok then
      error("Failed to parse response: " .. responseText)
    end

    if responseData.error then
      error(responseData.error.message or json.encode(responseData.error))
    end

    return parseResponse(responseData), responseData
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

  return model
end

local function createOpenAI(options)
  options = options or {}
  local baseURL = options.baseURL or DEFAULT_BASE_URL
  local providerName = options.name or "openai"

  local function getApiKey()
    return options.apiKey or os.getenv("OPENAI_API_KEY")
  end

  local function getHeaders()
    local headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. (getApiKey() or ""),
    }
    if options.headers then
      for k, v in pairs(options.headers) do
        headers[k] = v
      end
    end
    return headers
  end

  local config = {
    provider = providerName,
    baseURL = baseURL,
    getHeaders = getHeaders,
    getApiKey = getApiKey,
  }

  local function createModel(modelId)
    return createLanguageModel(modelId, config)
  end

  local provider = setmetatable({
    languageModel = createModel,
    chat = createModel,
  }, {
    __call = function(_, modelId)
      return createModel(modelId)
    end,
  })

  return provider
end

local openai = setmetatable({
  createOpenAI = createOpenAI,
}, {
  __call = function(_, modelId)
    return createOpenAI()(modelId)
  end,
  __index = createOpenAI(),
})

return openai
