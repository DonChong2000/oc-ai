local internet = require("internet")
local json = require("ai.json")
local utils = require("ai.utils")

local DEFAULT_BASE_URL = "https://generativelanguage.googleapis.com/v1beta"

local function buildContents(opts)
  local contents = {}
  if opts.messages then
    for _, msg in ipairs(opts.messages) do
      local role = msg.role == "assistant" and "model" or msg.role
      if role ~= "system" then
        table.insert(contents, {
          role = role,
          parts = msg.parts or { { text = msg.content } },
        })
      end
    end
  elseif opts.prompt then
    table.insert(contents, {
      role = "user",
      parts = { { text = opts.prompt } },
    })
  end
  return contents
end

local function buildTools(tools)
  if not tools then return nil end
  local declarations = {}
  for _, tool in ipairs(tools) do
    if tool.type == "function" then
      table.insert(declarations, {
        name = tool["function"].name,
        description = tool["function"].description,
        parameters = tool["function"].parameters,
      })
    end
  end
  if #declarations == 0 then return nil end
  return { { functionDeclarations = declarations } }
end

local function parseResponse(response)
  local candidate = response.candidates and response.candidates[1]
  if not candidate then
    error("No candidates in response")
  end

  local content = candidate.content
  local text = ""
  local toolCalls = nil

  if content and content.parts then
    for i, part in ipairs(content.parts) do
      if part.text then
        text = text .. part.text
      end
      if part.functionCall then
        toolCalls = toolCalls or {}
        table.insert(toolCalls, {
          id = "call_" .. tostring(i),
          type = "function",
          ["function"] = {
            name = part.functionCall.name,
            arguments = json.encode(part.functionCall.args or {}),
          },
        })
      end
    end
  end

  local finishReason = candidate.finishReason
  if finishReason == "STOP" then finishReason = "stop"
  elseif finishReason == "MAX_TOKENS" then finishReason = "length"
  end

  local usage = {}
  if response.usageMetadata then
    usage.inputTokens = response.usageMetadata.promptTokenCount
    usage.outputTokens = response.usageMetadata.candidatesTokenCount
    usage.totalTokens = response.usageMetadata.totalTokenCount
  end

  return {
    text = text,
    finishReason = finishReason,
    toolCalls = toolCalls,
    usage = usage,
    rawParts = content and content.parts,
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
      error("API key is required. Set GOOGLE_GENERATIVE_AI_API_KEY environment variable or pass apiKey to createGoogleGenerativeAI().")
    end

    local url = config.baseURL .. "/models/" .. modelId .. ":generateContent"
    local headers = config.getHeaders()
    local contents = buildContents(opts)

    local requestBody = { contents = contents }

    if opts.system then
      requestBody.systemInstruction = {
        parts = { { text = opts.system } },
      }
    end

    local generationConfig = {}
    if opts.maxOutputTokens then
      generationConfig.maxOutputTokens = opts.maxOutputTokens
    end
    if opts.temperature then
      generationConfig.temperature = opts.temperature
    end
    if opts.topP then
      generationConfig.topP = opts.topP
    end
    if next(generationConfig) then
      requestBody.generationConfig = generationConfig
    end

    if opts.tools then
      requestBody.tools = buildTools(opts.tools)
    end

    local bodyJson = json.encode(requestBody)
    local responseText = utils.httpPost(url, headers, bodyJson)

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
    return {
      functionResponse = {
        name = toolCall["function"].name,
        response = result,
      },
    }
  end

  function model.addAssistantMessage(messages, parsed)
    table.insert(messages, {
      role = "model",
      parts = parsed.rawParts,
    })
  end

  function model.addToolResults(messages, toolResultParts)
    table.insert(messages, {
      role = "user",
      parts = toolResultParts,
    })
  end

  function model.doStream(opts, onChunk)
    local apiKey = config.getApiKey()
    if not apiKey or apiKey == "" then
      error("API key is required. Set GOOGLE_GENERATIVE_AI_API_KEY environment variable or pass apiKey to createGoogleGenerativeAI().")
    end

    local url = config.baseURL .. "/models/" .. modelId .. ":streamGenerateContent?alt=sse"
    local headers = config.getHeaders()
    local contents = buildContents(opts)

    local requestBody = { contents = contents }

    if opts.system then
      requestBody.systemInstruction = {
        parts = { { text = opts.system } },
      }
    end

    local generationConfig = {}
    if opts.maxOutputTokens then
      generationConfig.maxOutputTokens = opts.maxOutputTokens
    end
    if opts.temperature then
      generationConfig.temperature = opts.temperature
    end
    if opts.topP then
      generationConfig.topP = opts.topP
    end
    if next(generationConfig) then
      requestBody.generationConfig = generationConfig
    end

    if opts.tools then
      requestBody.tools = buildTools(opts.tools)
    end

    local bodyJson = json.encode(requestBody)
    local request = internet.request(url, bodyJson, headers)

    local fullText = ""
    local finishReason = nil
    local toolCalls = nil
    local rawParts = {}
    local buffer = ""

    for chunk in request do
      buffer = buffer .. chunk
      while true do
        local lineEnd = buffer:find("\n")
        if not lineEnd then break end
        local line = buffer:sub(1, lineEnd - 1)
        buffer = buffer:sub(lineEnd + 1)

        if line:sub(1, 6) == "data: " then
          local data = line:sub(7)
          local ok, parsed = pcall(json.decode, data)
          if ok and parsed.candidates then
            local candidate = parsed.candidates[1]
            if candidate and candidate.content and candidate.content.parts then
              for i, part in ipairs(candidate.content.parts) do
                if part.text then
                  fullText = fullText .. part.text
                  table.insert(rawParts, part)
                  if onChunk then
                    onChunk({ type = "text", text = part.text })
                  end
                end
                if part.functionCall then
                  toolCalls = toolCalls or {}
                  table.insert(toolCalls, {
                    id = "call_" .. tostring(#toolCalls + 1),
                    type = "function",
                    ["function"] = {
                      name = part.functionCall.name,
                      arguments = json.encode(part.functionCall.args or {}),
                    },
                  })
                  table.insert(rawParts, part)
                end
              end
            end
            if candidate and candidate.finishReason then
              finishReason = candidate.finishReason
              if finishReason == "STOP" then finishReason = "stop"
              elseif finishReason == "MAX_TOKENS" then finishReason = "length"
              end
            end
          end
        end
      end
    end

    return {
      text = fullText,
      finishReason = finishReason,
      toolCalls = toolCalls,
      usage = {},
      rawParts = rawParts,
    }
  end

  return model
end

local function createGoogleGenerativeAI(options)
  options = options or {}
  local baseURL = options.baseURL or DEFAULT_BASE_URL
  local providerName = options.name or "google"

  local function getApiKey()
    return options.apiKey or os.getenv("GOOGLE_GENERATIVE_AI_API_KEY")
  end

  local function getHeaders()
    local headers = {
      ["Content-Type"] = "application/json",
      ["x-goog-api-key"] = getApiKey(),
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

local google = setmetatable({
  createGoogleGenerativeAI = createGoogleGenerativeAI,
}, {
  __call = function(_, modelId)
    return createGoogleGenerativeAI()(modelId)
  end,
  __index = createGoogleGenerativeAI(),
})

return google
