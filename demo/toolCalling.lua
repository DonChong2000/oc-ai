local ai = require("ai")
local config = dofile("config.lua")

math.randomseed(os.time())

local tools = {
  {
    type = "function",
    ["function"] = {
      name = "get_weather",
      description = "Get the weather in a location",
      parameters = {
        type = "object",
        properties = {
          location = {
            type = "string",
            description = "City or location",
          },
          unit = {
            type = "string",
            description = "Temperature unit",
            enum = { "C", "F" },
          },
        },
        required = { "location" },
      },
      execute = function(args)
        local safe_location = tostring(args and args.location or "")
        local safe_unit = args and args.unit == "F" and "F" or "C"
        local base_temp_c = 18 + math.random(-4, 6)
        local temperature = base_temp_c
        if safe_unit == "F" then
          temperature = math.floor((base_temp_c * 9 / 5) + 32)
        end
        return {
          location = safe_location,
          temperature = temperature,
          unit = safe_unit,
          condition = "clear",
        }
      end,
    },
  },
}

local result = ai.generateText({
  model = "google/gemini-2.5-flash",
  prompt = "What's the weather in Paris, return in Fahrenheit?",
  tools = tools,
  toolChoice = "auto",
  apiKey = config.AI_GATEWAY_API_KEY,
  maxOutputTokens = 200,
  maxSteps = 5,
})

print(result.text or "")
