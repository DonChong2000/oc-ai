local ai = require("ai")
local json = require("ai.json")
local config = dofile("config.lua")

--- Google and OpenAI have different way to specify the output format.
--- And JSON schema seems important in enforcing JSON output, where it isnt as easy to just prompt the model.

local prompt = [[
Output JSON only, No extra Output,No Code Block. schema:
{
  "name": string,
  "ingredients": [string],
  "steps": [string]
}

Generate a recipe, keep it simple.
]]

local result = ai.generateText({
  model = "openai/gpt-4o-mini",
  prompt = prompt,
  apiKey = config.AI_GATEWAY_API_KEY,
  maxOutputTokens = 1000,
  temperature = 0.4,
})



print(result.text)

print("---")
