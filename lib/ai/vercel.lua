local compat = require("ai.openai-compat")

local createVercel = compat.createProvider({
  baseURL = "https://ai-gateway.vercel.sh/v1",
  name = "vercel",
  envVar = "AI_GATEWAY_API_KEY",
  apiKeyError = "Set AI_GATEWAY_API_KEY environment variable or pass apiKey to createVercel().",
})

local vercel = setmetatable({
  createVercel = createVercel,
}, {
  __call = function(_, modelId)
    return createVercel()(modelId)
  end,
  __index = createVercel(),
})

return vercel
