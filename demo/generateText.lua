local ai = require("ai")

local result = ai.generateText({
  model = "google/gemini-2.5-flash-lite",
  prompt = "Why is the sky blue? (50 words)",
  maxOutputTokens = 100,
})

print(result.text)
