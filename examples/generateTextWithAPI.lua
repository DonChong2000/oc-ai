local ai = require("ai")
local vercel = require("ai.vercel")

-- Create a Vercel provider instance with an explicit API key
-- This is useful when you want to use a different API key than the one in the environment
local provider = vercel.createVercel({
  apiKey = os.getenv("AI_GATEWAY_API_KEY"),  -- or pass a string directly: "your-api-key-here"
  -- Optional: customize the base URL
  -- baseURL = "https://ai-gateway.vercel.sh/v1",
  -- Optional: add custom headers
  -- headers = { ["X-Custom-Header"] = "value" },
})

-- Create a model using the provider
local model = provider("google/gemini-2.5-flash-lite")

-- Generate text using the model
local result = ai.generateText({
  model = model,
  prompt = "Why is the sky blue? (50 words)",
  maxOutputTokens = 100,
})

print(result.text)
