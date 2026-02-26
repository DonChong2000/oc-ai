local internet = require("internet")
local json = require("ai.json")

local ai = {}

local DEFAULT_BASE_URL = "https://ai-gateway.vercel.sh/v1"

local function read_all(handle)
  local chunks = {}
  for chunk in handle do
    chunks[#chunks + 1] = chunk
  end
  return table.concat(chunks)
end

local function decode_json(body)
  local ok, decoded = pcall(json.decode, body)
  if not ok then
    error("Failed to parse JSON response: " .. tostring(decoded))
  end
  return decoded
end

local function request_json(url, body, headers)
  local handle, reason = internet.request(url, body, headers)
  if not handle then
    error("HTTP request failed: " .. tostring(reason))
  end
  local response_body = read_all(handle)
  local decoded = decode_json(response_body)
  return decoded, response_body
end

local function build_messages(options)
  if options.messages ~= nil and options.prompt ~= nil then
    error("Use either prompt or messages, not both.")
  end

  local messages = {}
  if options.system ~= nil then
    messages[#messages + 1] = { role = "system", content = options.system }
  end

  if options.messages ~= nil then
    for _, message in ipairs(options.messages) do
      messages[#messages + 1] = message
    end
  elseif options.prompt ~= nil then
    messages[#messages + 1] = { role = "user", content = options.prompt }
  else
    error("Missing prompt or messages.")
  end

  return messages
end

local function build_tools(options)
  if options.tools == nil then
    return nil, nil
  end

  local tool_defs = {}
  local tool_map = {}

  for _, tool in ipairs(options.tools) do
    local tool_type = tool.type or "function"
    if tool_type ~= "function" then
      error("Only function tools are supported.")
    end

    local tool_function = tool["function"]
    if tool_function == nil or type(tool_function.name) ~= "string" then
      error("Tool function must include a name.")
    end

    tool_map[tool_function.name] = tool
    tool_defs[#tool_defs + 1] = {
      type = "function",
      ["function"] = {
        name = tool_function.name,
        description = tool_function.description,
        parameters = tool_function.parameters,
      },
    }
  end

  return tool_defs, tool_map
end

local function normalize_tool_choice(tool_choice)
  if tool_choice == nil then
    return nil
  end
  if type(tool_choice) == "string" then
    return tool_choice
  end
  if type(tool_choice) == "table" then
    if tool_choice.type ~= nil or tool_choice["function"] ~= nil then
      return tool_choice
    end
    if tool_choice.name ~= nil then
      return { type = "function", ["function"] = { name = tool_choice.name } }
    end
  end
  error("Invalid toolChoice value.")
end

local function decode_tool_args(args_json)
  if type(args_json) ~= "string" or args_json == "" then
    return nil
  end
  local ok, decoded = pcall(json.decode, args_json)
  if ok then
    return decoded
  end
  return nil
end

local function encode_tool_output(output)
  if type(output) == "table" then
    local ok, encoded = pcall(json.encode, output)
    if ok then
      return encoded
    end
  end
  return tostring(output)
end

local function execute_tool_call(tool_call, tool_map)
  local tool_name = tool_call["function"] and tool_call["function"].name or tool_call.name
  local args_json = tool_call["function"] and tool_call["function"].arguments or tool_call.arguments
  local args = decode_tool_args(args_json)
  local tool = tool_map[tool_name]

  if tool == nil or tool["function"] == nil or type(tool["function"].execute) ~= "function" then
    local message = "Tool not found or missing execute function."
    return {
      role = "tool",
      tool_call_id = tool_call.id,
      name = tool_name,
      content = json.encode({ error = message }),
    }, {
      toolCallId = tool_call.id,
      toolName = tool_name,
      error = message,
    }
  end

  local ok, output = pcall(tool["function"].execute, args)
  if not ok then
    local error_message = tostring(output)
    return {
      role = "tool",
      tool_call_id = tool_call.id,
      name = tool_name,
      content = json.encode({ error = error_message }),
    }, {
      toolCallId = tool_call.id,
      toolName = tool_name,
      error = error_message,
    }
  end

  return {
    role = "tool",
    tool_call_id = tool_call.id,
    name = tool_name,
    content = encode_tool_output(output),
  }, {
    toolCallId = tool_call.id,
    toolName = tool_name,
    output = output,
  }
end

function ai.generateText(options)
  if type(options) ~= "table" then
    error("generateText expects an options table.")
  end
  if type(options.model) ~= "string" or options.model == "" then
    error("generateText requires a model string.")
  end

  local base_url = options.baseUrl or DEFAULT_BASE_URL
  local url = base_url .. "/chat/completions"

  local messages = build_messages(options)
  local tools, tool_map = build_tools(options)
  local tool_choice = normalize_tool_choice(options.toolChoice)

  local max_steps = tonumber(options.maxSteps) or 1
  if max_steps < 1 then
    max_steps = 1
  end

  local tool_results = {}
  local last_response = nil
  local last_raw = nil
  local last_finish_reason = nil

  for step = 1, max_steps do
    local request_body = {
      model = options.model,
      messages = messages,
    }

    if tools ~= nil then
      request_body.tools = tools
    end
    if tool_choice ~= nil then
      request_body.tool_choice = tool_choice
    end
    if options.maxOutputTokens ~= nil then
      request_body.max_tokens = options.maxOutputTokens
    end
    if options.temperature ~= nil then
      request_body.temperature = options.temperature
    end
    if options.topP ~= nil then
      request_body.top_p = options.topP
    end
    if options.topK ~= nil then
      request_body.top_k = options.topK
    end
    if options.presencePenalty ~= nil then
      request_body.presence_penalty = options.presencePenalty
    end
    if options.frequencyPenalty ~= nil then
      request_body.frequency_penalty = options.frequencyPenalty
    end
    if options.stopSequences ~= nil then
      request_body.stop = options.stopSequences
    end
    if options.seed ~= nil then
      request_body.seed = options.seed
    end

    local headers = {
      ["Content-Type"] = "application/json",
    }
    if options.apiKey ~= nil and options.apiKey ~= "" then
      headers["Authorization"] = "Bearer " .. options.apiKey
    end
    if options.headers ~= nil then
      for key, value in pairs(options.headers) do
        headers[key] = value
      end
    end

    local body = json.encode(request_body)
    local response, raw_body = request_json(url, body, headers)
    last_response = response
    last_raw = raw_body

    if response.error ~= nil then
      local message = response.error.message or "AI Gateway error"
      error(message)
    end

    local choice = response.choices and response.choices[1]
    if choice == nil or choice.message == nil then
      error("No response message received.")
    end

    local message = choice.message
    last_finish_reason = choice.finish_reason
    messages[#messages + 1] = message

    local tool_calls = message.tool_calls
    if tool_calls == nil or #tool_calls == 0 then
      break
    end

    for _, tool_call in ipairs(tool_calls) do
      local tool_message, tool_result = execute_tool_call(tool_call, tool_map or {})
      messages[#messages + 1] = tool_message
      tool_results[#tool_results + 1] = tool_result
    end
  end

  local final_message = last_response
    and last_response.choices
    and last_response.choices[1]
    and last_response.choices[1].message
    or {}

  local result = {
    text = final_message.content or "",
    finishReason = last_finish_reason,
    usage = last_response and last_response.usage or nil,
    response = last_response,
    raw = last_raw,
    toolResults = tool_results,
  }

  return setmetatable(result, {
    __tostring = function()
      return result.text or ""
    end,
  })
end

return ai
