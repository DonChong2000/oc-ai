local ai = require("ai")
local openai = require("ai.openai")

ai.streamText({
  model = openai("gpt-4o-mini"),
  prompt = "Tell me a story",
  maxOutputTokens = 500,
  onChunk = function(chunk)
    if chunk.type == "text" then
      io.write(chunk.text)
    end
  end,
  onFinish = function(result)
    print("")
    print("--- Done ---")
    print("Finish reason: " .. (result.finishReason or "unknown"))
  end,
})
