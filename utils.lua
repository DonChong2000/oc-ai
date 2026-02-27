local internet = require("internet")

local utils = {}

function utils.httpPost(url, headers, body)
  local response = ""
  local request = internet.request(url, body, headers)
  for chunk in request do
    response = response .. chunk
  end
  return response
end

function utils.httpPostStream(url, headers, body)
  return internet.request(url, body, headers)
end

function utils.parseSSELine(line)
  if line:sub(1, 6) == "data: " then
    local data = line:sub(7)
    if data == "[DONE]" then
      return "done", nil
    end
    local json = require("ai.json")
    local ok, parsed = pcall(json.decode, data)
    if ok then
      return "data", parsed
    end
  end
  return nil, nil
end

return utils
