-- oc-code/init.lua
-- Main module for oc-code: A Claude-like coding agent for OpenComputers

local agent = require("oc-code.agent")
local tools = require("oc-code.tools")
local skills = require("oc-code.skills")
local tui = require("oc-code.tui")

local occode = {}

-- Re-export submodules
occode.agent = agent
occode.tools = tools
occode.skills = skills
occode.tui = tui

-- Version
occode.version = "0.1.0"

-- Run the interactive TUI application
function occode.run(config)
  -- Initialize agent
  agent.init(config)

  -- Initialize TUI
  tui.init()
  tui.print("Welcome to oc-code v" .. occode.version, tui.colors.assistant)
  tui.print("Type /help for available commands.", tui.colors.dim)
  tui.print("", tui.colors.foreground)

  -- Main loop
  while tui.isRunning() do
    tui.setStatus("Ready")
    local input = tui.readInput()

    if input == nil then
      -- Ctrl+C pressed
      tui.print("^C", tui.colors.dim)
    elseif input == "" then
      -- Empty input, do nothing
    else
      -- Show user input
      tui.printRole("user", input)

      -- Process input
      tui.setStatus("Thinking...")

      local result = agent.process(input, {
        onToolCall = function(name, args)
          tui.setStatus("Running " .. name .. "...")
          tui.printToolCall(name, args)
        end,
        onToolResult = function(name, result)
          tui.printToolResult(name, result)
        end,
        onChunk = function(text)
          tui.streamText(text)
        end,
        onFinish = function(res)
          tui.endStream()
        end,
      })

      -- Handle result
      if result.type == "command" then
        if result.command == "exit" then
          tui.stop()
        elseif result.command == "clear" then
          tui.clear()
          tui.print("Conversation cleared.", tui.colors.dim)
        end
      elseif result.type == "error" then
        tui.printRole("error", result.text)
      elseif result.type == "direct" then
        tui.print(result.text, tui.colors.foreground)
      elseif result.type == "response" then
        if result.text and result.text ~= "" then
          tui.printRole("assistant", result.text)
        end
      end

      tui.print("", tui.colors.foreground)
    end
  end

  -- Cleanup
  tui.cleanup()
  print("Goodbye!")
end

-- Simple non-TUI mode for scripting
function occode.chat(prompt, config)
  agent.init(config)
  local result = agent.process(prompt)
  return result.text, result
end

-- One-shot command execution
function occode.exec(prompt, config)
  config = config or {}
  config.maxSteps = config.maxSteps or 5
  return occode.chat(prompt, config)
end

return occode
