-- oc-code/init.lua
-- Main module for oc-code: A Claude-like coding agent for OpenComputers

local agent = require("oc-code.agent")
local tools = require("oc-code.tools")
local skills = require("oc-code.skills")
local component = require("component")

local occode = {}

-- Re-export submodules
occode.agent = agent
occode.tools = tools
occode.skills = skills

-- Version
occode.version = "0.2.0"

-- Detect if we have TUI support (GPU + screen + sufficient color depth)
function occode.hasTuiSupport()
  local hasGpu = component.isAvailable("gpu")
  local hasScreen = component.isAvailable("screen")
  if hasGpu and hasScreen then
    local gpu = component.gpu
    -- Need at least 4-bit color depth (tier 2+ screen)
    -- Tier 1 screen = 1-bit (black/white only), TUI colors won't work
    return gpu.getDepth() > 1
  end
  return false
end

-- Get the appropriate UI module
function occode.getUI(forceTerminal)
  if forceTerminal or not occode.hasTuiSupport() then
    return require("oc-code.terminal")
  else
    return require("oc-code.tui")
  end
end

-- Lazy load tui for backward compatibility
occode.tui = setmetatable({}, {
  __index = function(_, key)
    local tui = require("oc-code.tui")
    return tui[key]
  end
})

-- Lazy load terminal
occode.terminal = setmetatable({}, {
  __index = function(_, key)
    local terminal = require("oc-code.terminal")
    return terminal[key]
  end
})

-- Internal run loop (shared between TUI and terminal modes)
local function runLoop(ui, config)
  -- Initialize agent
  agent.init(config)

  -- Initialize UI
  ui.init()
  ui.print("Welcome to oc-code v" .. occode.version, ui.colors and ui.colors.assistant)
  ui.print("Type /help for available commands.", ui.colors and ui.colors.dim)
  ui.print("Use !<command> to execute shell commands (e.g., !ls)", ui.colors and ui.colors.dim)
  ui.print("", ui.colors and ui.colors.foreground)

  -- Main loop
  while ui.isRunning() do
    ui.setStatus("Ready")

    -- Use simple input for terminal mode if event-based fails
    local input
    if ui.readInputSimple then
      -- Terminal mode - try event-based first, fallback to simple
      local ok
      ok, input = pcall(ui.readInput)
      if not ok then
        input = ui.readInputSimple()
      end
    else
      input = ui.readInput()
    end

    if input == nil then
      -- Ctrl+C pressed
      ui.print("^C", ui.colors and ui.colors.dim)
    elseif input == "" then
      -- Empty input, do nothing
    else
      -- Show user input
      ui.printRole("user", input)

      -- Process input
      ui.setStatus("Thinking...")

      local result = agent.process(input, {
        onToolCall = function(name, args)
          ui.setStatus("Running " .. name .. "...")
          ui.printToolCall(name, args)
        end,
        onToolResult = function(name, result)
          ui.printToolResult(name, result)
        end,
      })

      -- Handle result
      if result.type == "command" then
        if result.command == "exit" then
          ui.stop()
        elseif result.command == "clear" then
          ui.clear()
          ui.print("Conversation cleared.", ui.colors and ui.colors.dim)
        end
      elseif result.type == "error" then
        ui.printRole("error", result.text)
      elseif result.type == "direct" then
        ui.print(result.text, ui.colors and ui.colors.foreground)
      elseif result.type == "response" then
        if result.text and result.text ~= "" then
          ui.printRole("assistant", result.text)
        end
      end

      ui.print("", ui.colors and ui.colors.foreground)
    end
  end

  -- Cleanup
  ui.cleanup()
  print("Goodbye!")
end

-- Run the interactive application (auto-detects TUI vs terminal)
function occode.run(config)
  config = config or {}
  local ui = occode.getUI(config.forceTerminal)
  runLoop(ui, config)
end

-- Run in TUI mode (requires GPU + screen)
function occode.runTui(config)
  local tui = require("oc-code.tui")
  runLoop(tui, config)
end

-- Run in terminal mode (works on robots without GPU)
function occode.runTerminal(config)
  local terminal = require("oc-code.terminal")
  runLoop(terminal, config)
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
