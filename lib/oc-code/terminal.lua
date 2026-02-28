-- oc-code/terminal.lua
-- Simple interactive terminal for robots (no TUI/GPU required)

local event = require("event")
local unicode = require("unicode")
local json = require("cmn-utils.json")
local component = require("component")
local computer = require("computer")

local terminal = {}

-- Reset terminal to default state (fix GPU color issues from other modules)
local function resetTerminalState()
  if component.isAvailable("gpu") then
    local gpu = component.gpu
    -- Reset to default black/white colors
    pcall(function()
      gpu.setBackground(0x000000)
      gpu.setForeground(0xFFFFFF)
    end)
  end
end

-- Colors (ANSI-style, but simplified for OC)
terminal.colors = {
  reset = "",
  user = "",
  assistant = "",
  tool = "",
  error = "",
  dim = "",
}

-- State
local state = {
  running = true,
  status = "Ready",
  showTools = true,
  inputBuffer = "",
}

-- Word wrap text for terminal
local function wrapText(str, width)
  width = width or 50
  local lines = {}
  for line in str:gmatch("([^\n]*)\n?") do
    if unicode.len(line) <= width then
      if line ~= "" or #lines == 0 then
        table.insert(lines, line)
      end
    else
      local current = ""
      for word in line:gmatch("%S+") do
        if unicode.len(current) + unicode.len(word) + 1 <= width then
          current = current == "" and word or (current .. " " .. word)
        else
          if current ~= "" then
            table.insert(lines, current)
          end
          if unicode.len(word) > width then
            while unicode.len(word) > width do
              table.insert(lines, unicode.sub(word, 1, width))
              word = unicode.sub(word, width + 1)
            end
            current = word
          else
            current = word
          end
        end
      end
      if current ~= "" then
        table.insert(lines, current)
      end
    end
  end
  return lines
end

-- Initialize terminal
function terminal.init()
  state.running = true
  state.status = "Ready"
  state.inputBuffer = ""
  -- Reset GPU colors to prevent TUI color bleed
  resetTerminalState()
end

-- Print text (color param unused, kept for TUI interface compatibility)
function terminal.print(msg, _color)
  local lines = wrapText(tostring(msg), 60)
  for _, line in ipairs(lines) do
    print(line)
  end
end

-- Print with role prefix
function terminal.printRole(role, msg)
  local prefix
  if role == "user" then
    prefix = "> "
  elseif role == "assistant" then
    prefix = ""
  elseif role == "tool" then
    prefix = "  "
  elseif role == "error" then
    prefix = "[ERROR] "
  else
    prefix = ""
  end
  terminal.print(prefix .. msg)
end

-- Print tool call
function terminal.printToolCall(name, args)
  if not state.showTools then return end
  print(">> " .. name)
  if args then
    local argsStr = type(args) == "string" and args or json.encode(args)
    if unicode.len(argsStr) > 80 then
      argsStr = unicode.sub(argsStr, 1, 77) .. "..."
    end
    print("   " .. argsStr)
  end
end

-- Print tool result
function terminal.printToolResult(name, result)
  if not state.showTools then return end
  local resultStr = type(result) == "string" and result or json.encode(result)
  if unicode.len(resultStr) > 100 then
    resultStr = unicode.sub(resultStr, 1, 97) .. "..."
  end
  print("<< " .. resultStr)
  -- Reset terminal state after tool execution to prevent color bleed
  resetTerminalState()
end

-- Set status (just prints for terminal mode)
function terminal.setStatus(msg)
  state.status = msg or "Ready"
  -- In terminal mode, only print significant status changes as full lines
  -- to avoid mixing io.write with print which causes display glitches
end

-- Check if we have keyboard support
local function hasKeyboard()
  return component.isAvailable("keyboard")
end

-- Cursor blink interval
local CURSOR_BLINK_INTERVAL = 0.5  -- seconds

-- Track the maximum display length for proper clearing
local maxDisplayLen = 0

-- Get GPU for cursor rendering
local function getGpu()
  if component.isAvailable("gpu") then
    return component.gpu
  end
  return nil
end

-- Redraw the entire input line with block cursor (inverted colors)
local function redrawLine(input, cursor, showCursor)
  local len = unicode.len(input)
  local gpu = getGpu()

  -- Always write carriage return to go to start of line, then rewrite prompt
  io.write("\r> ")

  -- Write text before cursor
  if cursor > 0 then
    io.write(unicode.sub(input, 1, cursor))
  end

  -- Get character at cursor position (or space if at end)
  local cursorChar = cursor < len and unicode.sub(input, cursor + 1, cursor + 1) or " "

  -- Write cursor character with inverted colors if cursor visible
  if showCursor and gpu then
    -- Invert colors for block cursor effect
    gpu.setBackground(0xFFFFFF)
    gpu.setForeground(0x000000)
    io.write(cursorChar)
    -- Restore normal colors
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
  else
    io.write(cursorChar)
  end

  -- Write text after cursor (skip the cursor char since we already wrote it)
  if cursor + 1 < len then
    io.write(unicode.sub(input, cursor + 2))
  end

  -- Calculate display length (always includes cursor position)
  local displayLen = math.max(len, cursor + 1)

  -- Clear any leftover characters from longer previous display
  if displayLen < maxDisplayLen then
    io.write(string.rep(" ", maxDisplayLen - displayLen))
  end

  -- Update max display length
  if displayLen > maxDisplayLen then
    maxDisplayLen = displayLen
  end

  -- Calculate total width written
  local totalWidth = math.max(displayLen, maxDisplayLen)

  -- Move cursor back to position after the cursor char
  local targetCol = cursor + 1
  local moveBack = totalWidth - targetCol
  if moveBack > 0 then
    io.write(string.rep("\b", moveBack))
  end

  io.flush()
end

-- Read user input with event-based handling (for computers with keyboard)
function terminal.readInput()
  -- Reset terminal state before showing prompt
  resetTerminalState()
  io.write("> ")
  io.flush()

  -- Reset tracking variable
  maxDisplayLen = 0

  -- If no keyboard, fall back to simple read
  if not hasKeyboard() then
    local line = io.read("*l")
    return line
  end

  -- Use event-based input to allow Ctrl+C handling
  local input = ""
  local cursor = 0  -- Cursor position (0 = before first char)
  local cursorVisible = true
  local lastBlink = computer.uptime()

  -- Initial draw with cursor
  redrawLine(input, cursor, true)

  while true do
    local ev, _, char, code = event.pull(CURSOR_BLINK_INTERVAL)

    -- Handle cursor blinking
    local now = computer.uptime()
    if now - lastBlink >= CURSOR_BLINK_INTERVAL then
      cursorVisible = not cursorVisible
      lastBlink = now
      redrawLine(input, cursor, cursorVisible)
    end

    if ev == "interrupted" then
      -- Clear cursor and print
      redrawLine(input, cursor, false)
      print("^C")
      return nil
    elseif ev == "key_down" then
      cursorVisible = true  -- Show cursor on keypress
      lastBlink = now

      if char == 13 then -- Enter
        -- Clear cursor indicator before newline
        redrawLine(input, cursor, false)
        print() -- newline
        return input
      elseif char == 8 or code == 14 then -- Backspace
        if cursor > 0 then
          input = unicode.sub(input, 1, cursor - 1) .. unicode.sub(input, cursor + 1)
          cursor = cursor - 1
          redrawLine(input, cursor, true)
        end
      elseif code == 203 then -- Left arrow
        if cursor > 0 then
          cursor = cursor - 1
          redrawLine(input, cursor, true)
        end
      elseif code == 205 then -- Right arrow
        if cursor < unicode.len(input) then
          cursor = cursor + 1
          redrawLine(input, cursor, true)
        end
      elseif code == 199 then -- Home
        if cursor > 0 then
          cursor = 0
          redrawLine(input, cursor, true)
        end
      elseif code == 207 then -- End
        local len = unicode.len(input)
        if cursor < len then
          cursor = len
          redrawLine(input, cursor, true)
        end
      elseif code == 211 then -- Delete
        local len = unicode.len(input)
        if cursor < len then
          input = unicode.sub(input, 1, cursor) .. unicode.sub(input, cursor + 2)
          redrawLine(input, cursor, true)
        end
      elseif char >= 32 and char < 127 then -- Printable ASCII
        input = unicode.sub(input, 1, cursor) .. string.char(char) .. unicode.sub(input, cursor + 1)
        cursor = cursor + 1
        redrawLine(input, cursor, true)
      end
    elseif ev == "clipboard" then
      cursorVisible = true
      lastBlink = now
      if char then
        input = unicode.sub(input, 1, cursor) .. char .. unicode.sub(input, cursor + 1)
        cursor = cursor + unicode.len(char)
        redrawLine(input, cursor, true)
      end
    end
  end
end

-- Read input using simple io.read (fallback for robots)
function terminal.readInputSimple()
  -- Reset terminal state before showing prompt
  resetTerminalState()
  io.write("> ")
  io.flush()
  local ok, line = pcall(io.read, "*l")
  if ok then
    return line
  else
    return nil
  end
end

-- Clear (just prints separator)
function terminal.clear()
  print("---")
  print("Conversation cleared.")
  print("---")
end

-- Cleanup
function terminal.cleanup()
  -- Nothing to cleanup in terminal mode
end

-- Check if running
function terminal.isRunning()
  return state.running
end

-- Stop running
function terminal.stop()
  state.running = false
end

-- Interface compatibility stubs (required for TUI/terminal interoperability)
-- These functions exist so init.lua can use either UI module interchangeably
function terminal.drawHeader() end
function terminal.drawStatus() end
function terminal.redrawContent() end
function terminal.drawInput() end

return terminal
