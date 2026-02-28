local ai = require("ai")
local groq = require("ai.groq")

local result = ai.generateText({
  model = groq("llama-3.3-70b-versatile"),
  prompt = "Why is the sky blue?",
  maxOutputTokens = 100,
})

print(result.text)
