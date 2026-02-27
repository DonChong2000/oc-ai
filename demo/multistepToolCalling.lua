local ai = require("ai")

-- Tools for a simple math assistant
local tools = {
  {
    type = "function",
    ["function"] = {
      name = "add",
      description = "Add two numbers",
      parameters = {
        type = "object",
        properties = {
          a = { type = "number", description = "First number" },
          b = { type = "number", description = "Second number" },
        },
        required = { "a", "b" },
      },
      execute = function(args)
        print("[Tool] add(" .. args.a .. ", " .. args.b .. ") = " .. (args.a + args.b))
        return { result = args.a + args.b }
      end,
    },
  },
  {
    type = "function",
    ["function"] = {
      name = "multiply",
      description = "Multiply two numbers",
      parameters = {
        type = "object",
        properties = {
          a = { type = "number", description = "First number" },
          b = { type = "number", description = "Second number" },
        },
        required = { "a", "b" },
      },
      execute = function(args)
        print("[Tool] multiply(" .. args.a .. ", " .. args.b .. ") = " .. (args.a * args.b))
        return { result = args.a * args.b }
      end,
    },
  },
  {
    type = "function",
    ["function"] = {
      name = "subtract",
      description = "Subtract two numbers",
      parameters = {
        type = "object",
        properties = {
          a = { type = "number", description = "First number" },
          b = { type = "number", description = "Second number to subtract" },
        },
        required = { "a", "b" },
      },
      execute = function(args)
        print("[Tool] subtract(" .. args.a .. ", " .. args.b .. ") = " .. (args.a - args.b))
        return { result = args.a - args.b }
      end,
    },
  },
}

print("Prompt: Calculate (5 + 3) * 2 - 4")
print("")

local result = ai.generateText({
  model = "openai/gpt-4o-mini",
  system = "You are a calculator. Use the provided tools to solve math problems step by step.",
  prompt = "Calculate (5 + 3) * 2 - 4",
  tools = tools,
  maxSteps = 5,
  maxOutputTokens = 200,
})

print("")
print("--- Result ---")
print(result.text)
print("")
print("Tool calls made: " .. #result.toolResults)
for i, tr in ipairs(result.toolResults) do
  print("  " .. i .. ". " .. tr.toolName)
end
