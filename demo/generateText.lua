local ai = require("ai")
local config = dofile("config.lua")

local result = ai.generateText({
  model = "google/gemini-2.5-flash-lite",
  prompt = "Why is the sky blue?",
  apiKey = config.AI_GATEWAY_API_KEY,
  maxOutputTokens = 50,
})

print(result)
