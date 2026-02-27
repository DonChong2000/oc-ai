local ai = require("ai")
local google = require("ai.google")

ai.streamText({
  model = google("gemini-2.5-flash"),
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
