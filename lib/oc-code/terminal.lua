-- oc-code/terminal.lua
-- Simple interactive terminal for robots (no TUI/GPU required)

local event = require("event")
local unicode = require("unicode")
local json = require("cmn-utils.json")

local terminal = {}

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
end

-- Set status (just prints for terminal mode)
function terminal.setStatus(msg)
  state.status = msg or "Ready"
  if msg and msg ~= "Ready" then
    io.write("[" .. msg .. "] ")
    io.flush()
  end
end

-- Check if we have keyboard support
local function hasKeyboard()
  local component = require("component")
  return component.isAvailable("keyboard")
end

-- Read user input with event-based handling (for computers with keyboard)
function terminal.readInput()
  io.write("> ")
  io.flush()

  -- If no keyboard, fall back to simple read
  if not hasKeyboard() then
    local line = io.read("*l")
    return line
  end

  -- Use event-based input to allow Ctrl+C handling
  local input = ""

  while true do
    local ev, _, char, code = event.pull()

    if ev == "interrupted" then
      print("^C")
      return nil
    elseif ev == "key_down" then
      if char == 13 then -- Enter
        print() -- newline
        return input
      elseif char == 8 or code == 14 then -- Backspace
        if #input > 0 then
          input = unicode.sub(input, 1, -2)
          io.write("\b \b")
          io.flush()
        end
      elseif char >= 32 and char < 127 then -- Printable ASCII
        input = input .. string.char(char)
        io.write(string.char(char))
        io.flush()
      end
    elseif ev == "clipboard" then
      -- Paste support
      if char then
        input = input .. char
        io.write(char)
        io.flush()
      end
    end
  end
end

-- Read input using simple io.read (fallback for robots)
function terminal.readInputSimple()
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
