local compat = require("ai.openai-compat")

local createOpenAI = compat.createProvider({
  baseURL = "https://api.openai.com/v1",
  name = "openai",
  envVar = "OPENAI_API_KEY",
  apiKeyError = "Set OPENAI_API_KEY environment variable or pass apiKey to createOpenAI().",
})

local openai = setmetatable({
  createOpenAI = createOpenAI,
}, {
  __call = function(_, modelId)
    return createOpenAI()(modelId)
  end,
  __index = createOpenAI(),
})

return openai
