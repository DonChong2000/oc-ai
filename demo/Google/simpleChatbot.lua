local ai = require("ai")
local google = require("ai.google")

local messages = {}

print("Simple Chatbot - Google (type 'exit' to quit)")
print("")

while true do
  io.write("You: ")
  local input = io.read()

  if input == "exit" then
    print("Goodbye!")
    break
  end

  table.insert(messages, { role = "user", content = input })

  local result = ai.generateText({
    model = google("gemini-2.5-flash"),
    system = "You are a helpful assistant. Keep responses concise.",
    messages = messages,
    maxOutputTokens = 200,
  })

  table.insert(messages, { role = "assistant", content = result.text })

  print("Bot: " .. result.text)
  print("")
end
