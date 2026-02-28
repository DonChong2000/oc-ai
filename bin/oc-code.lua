-- oc-code: AI Coding Agent for OpenComputers
-- Usage: oc-code [options]
--   -m, --model <model>   Set the AI model (default: anthropic/claude-sonnet-4)
--   -h, --help            Show this help message

local shell = require("shell")
local args, opts = shell.parse(...)

-- Show help
if opts.h or opts.help then
  print("oc-code - AI Coding Agent for OpenComputers")
  print("")
  print("Usage: oc-code [options]")
  print("  -m, --model <model>   Set the AI model")
  print("  -h, --help            Show this help message")
  print("")
  print("Available models:")
  print("  anthropic/claude-sonnet-4 (default)")
  print("  anthropic/claude-haiku-3.5")
  print("  openai/gpt-4o")
  print("  openai/gpt-4o-mini")
  print("  google/gemini-2.5-flash")
  print("")
  print("Commands (inside oc-code):")
  print("  /help     Show available commands")
  print("  /clear    Clear conversation history")
  print("  /commit   Create a git commit")
  print("  /exit     Exit oc-code")
  return
end

-- Build config
local config = {}

if opts.m or opts.model then
  config.model = opts.m or opts.model
end

-- Run oc-code
local occode = require("oc-code")
occode.run(config)
