local ai = require("ai")
local openai = require("ai.openai")
math.randomseed(os.time())

local tools = {
  ai.tool({
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
      local location = tostring(args and args.location or "")
      local unit = args and args.unit == "F" and "F" or "C"
      local base_temp_c = 18 + math.random(-4, 6)
      local temperature = base_temp_c
      if unit == "F" then
        temperature = math.floor((base_temp_c * 9 / 5) + 32)
      end
      return {
        location = location,
        temperature = temperature,
        unit = unit,
        condition = "clear",
      }
    end,
  }),
}

local result = ai.generateText({
  model = openai("gpt-4o-mini"),
  prompt = "What's the weather in Paris, return in Fahrenheit?",
  tools = tools,
  toolChoice = "auto",
  maxOutputTokens = 200,
  maxSteps = 5,
})

print(result.text or "")
