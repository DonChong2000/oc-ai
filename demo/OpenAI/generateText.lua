local ai = require("ai")
local openai = require("ai.openai")

local result = ai.generateText({
  model = openai("gpt-4o-mini"),
  prompt = "Why is the sky blue?",
  maxOutputTokens = 100,
})

print(result.text)
