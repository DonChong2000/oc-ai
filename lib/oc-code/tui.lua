-- oc-code/tui.lua
-- Text User Interface for oc-code

local component = require("component")
local term = require("term")
local event = require("event")
local keyboard = require("keyboard")
local text = require("text")
local unicode = require("unicode")

local gpu = component.gpu

local tui = {}

-- Color scheme
tui.colors = {
  background = 0x1a1a2e,
  foreground = 0xeaeaea,
  prompt = 0x7b68ee,
  user = 0x98c379,
  assistant = 0x61afef,
  tool = 0xe5c07b,
  toolName = 0xc678dd,
  error = 0xe06c75,
  success = 0x98c379,
  dim = 0x5c6370,
  border = 0x3e4451,
  highlight = 0x2c323c,
  status = 0x282c34,
}

-- State
local state = {
  width = 80,
  height = 25,
  scrollOffset = 0,
  history = {},
  inputBuffer = "",
  inputCursor = 0,
  running = true,
  status = "Ready",
  showTools = true,
}

-- Initialize TUI
function tui.init()
  state.width, state.height = gpu.getResolution()
  state.running = true
  state.scrollOffset = 0
  state.history = {}
  state.inputBuffer = ""
  state.inputCursor = 0
  state.status = "Ready"
  gpu.setBackground(tui.colors.background)
  gpu.setForeground(tui.colors.foreground)
  term.clear()
  tui.drawHeader()
  tui.drawStatus()
end

-- Draw header bar
function tui.drawHeader()
  gpu.setBackground(tui.colors.status)
  gpu.setForeground(tui.colors.assistant)
  gpu.fill(1, 1, state.width, 1, " ")
  gpu.set(2, 1, "oc-code")
  gpu.setForeground(tui.colors.dim)
  local hint = "/help | PgUp/PgDn to scroll | /exit"
  gpu.set(state.width - unicode.len(hint) - 1, 1, hint)
  gpu.setBackground(tui.colors.background)
  gpu.setForeground(tui.colors.foreground)
end

-- Draw status bar
function tui.drawStatus()
  local y = state.height
  gpu.setBackground(tui.colors.status)
  gpu.setForeground(tui.colors.dim)
  gpu.fill(1, y, state.width, 1, " ")
  gpu.set(2, y, state.status)

  -- Show scroll indicator
  if state.scrollOffset > 0 then
    local scrollText = string.format("[Scroll: %d lines up]", state.scrollOffset)
    gpu.setForeground(tui.colors.tool)
    gpu.set(state.width - unicode.len(scrollText) - 1, y, scrollText)
  end

  gpu.setBackground(tui.colors.background)
  gpu.setForeground(tui.colors.foreground)
end

-- Set status message
function tui.setStatus(msg)
  state.status = msg or "Ready"
  tui.drawStatus()
end

-- Content area bounds
local function getContentBounds()
  return 2, 3, state.width - 2, state.height - 4
end

-- Clear content area
function tui.clearContent()
  local x, y, w, h = getContentBounds()
  gpu.setBackground(tui.colors.background)
  gpu.fill(x - 1, y, w + 2, h, " ")
end

-- Word wrap text
local function wrapText(str, width)
  local lines = {}
  for line in str:gmatch("([^\n]*)\n?") do
    if unicode.len(line) <= width then
      table.insert(lines, line)
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
            -- Break long words
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

-- Print message to content area
function tui.print(msg, color)
  local x, y, w, h = getContentBounds()
  color = color or tui.colors.foreground

  local lines = wrapText(tostring(msg), w)

  for _, line in ipairs(lines) do
    table.insert(state.history, { text = line, color = color })
  end

  -- Auto-scroll to bottom when new content is added
  state.scrollOffset = 0

  tui.redrawContent()
end

-- Print with role prefix
function tui.printRole(role, msg)
  local color, prefix
  if role == "user" then
    color = tui.colors.user
    prefix = "> "
  elseif role == "assistant" then
    color = tui.colors.assistant
    prefix = ""
  elseif role == "tool" then
    color = tui.colors.tool
    prefix = "  "
  elseif role == "error" then
    color = tui.colors.error
    prefix = "Error: "
  else
    color = tui.colors.foreground
    prefix = ""
  end

  tui.print(prefix .. msg, color)
end

-- Print tool call
function tui.printToolCall(name, args)
  if not state.showTools then return end
  gpu.setForeground(tui.colors.toolName)
  tui.print(">> " .. name, tui.colors.toolName)
  if args then
    local argsStr = type(args) == "string" and args or require("ai.utils.json").encode(args)
    if unicode.len(argsStr) > 100 then
      argsStr = unicode.sub(argsStr, 1, 97) .. "..."
    end
    tui.print("   " .. argsStr, tui.colors.dim)
  end
end

-- Print tool result
function tui.printToolResult(name, result)
  if not state.showTools then return end
  local resultStr = type(result) == "string" and result or require("ai.utils.json").encode(result)
  if unicode.len(resultStr) > 200 then
    resultStr = unicode.sub(resultStr, 1, 197) .. "..."
  end
  tui.print("<< " .. resultStr, tui.colors.dim)
end

-- Redraw content area with history
function tui.redrawContent()
  local x, y, w, h = getContentBounds()
  gpu.setBackground(tui.colors.background)
  gpu.fill(x - 1, y, w + 2, h, " ")

  local startIdx = math.max(1, #state.history - h + 1 - state.scrollOffset)
  local endIdx = math.min(#state.history, startIdx + h - 1)

  local row = y
  for i = startIdx, endIdx do
    local entry = state.history[i]
    gpu.setForeground(entry.color or tui.colors.foreground)
    gpu.set(x, row, unicode.sub(entry.text, 1, w))
    row = row + 1
  end

  gpu.setForeground(tui.colors.foreground)
  tui.drawStatus()
end

-- Scroll functions
function tui.scrollUp(lines)
  lines = lines or 1
  local _, _, _, h = getContentBounds()
  local maxScroll = math.max(0, #state.history - h)
  state.scrollOffset = math.min(maxScroll, state.scrollOffset + lines)
  tui.redrawContent()
end

function tui.scrollDown(lines)
  lines = lines or 1
  state.scrollOffset = math.max(0, state.scrollOffset - lines)
  tui.redrawContent()
end

function tui.scrollToBottom()
  state.scrollOffset = 0
  tui.redrawContent()
end

function tui.scrollToTop()
  local _, _, _, h = getContentBounds()
  state.scrollOffset = math.max(0, #state.history - h)
  tui.redrawContent()
end

-- Draw input line
function tui.drawInput()
  local y = state.height - 1
  gpu.setBackground(tui.colors.background)
  gpu.fill(1, y, state.width, 1, " ")
  gpu.setForeground(tui.colors.prompt)
  gpu.set(2, y, "> ")
  gpu.setForeground(tui.colors.foreground)

  local inputStart = 4
  local maxWidth = state.width - inputStart - 1
  local displayText = state.inputBuffer

  if unicode.len(displayText) > maxWidth then
    local start = math.max(1, state.inputCursor - maxWidth + 10)
    displayText = unicode.sub(displayText, start, start + maxWidth - 1)
  end

  gpu.set(inputStart, y, displayText)

  -- Position cursor
  local cursorX = inputStart + math.min(state.inputCursor, maxWidth - 1)
  term.setCursor(cursorX, y)
  term.setCursorBlink(true)
end

-- Read user input
function tui.readInput()
  state.inputBuffer = ""
  state.inputCursor = 0
  tui.drawInput()

  while true do
    local ev, _, char, code = event.pull()

    if ev == "interrupted" then
      return nil

    elseif ev == "key_down" then
      if char == 13 then -- Enter
        local input = state.inputBuffer
        state.inputBuffer = ""
        state.inputCursor = 0
        return input

      elseif char == 8 or code == keyboard.keys.back then -- Backspace
        if state.inputCursor > 0 then
          state.inputBuffer = unicode.sub(state.inputBuffer, 1, state.inputCursor - 1) ..
                              unicode.sub(state.inputBuffer, state.inputCursor + 1)
          state.inputCursor = state.inputCursor - 1
        end

      elseif code == keyboard.keys.delete then -- Delete
        if state.inputCursor < unicode.len(state.inputBuffer) then
          state.inputBuffer = unicode.sub(state.inputBuffer, 1, state.inputCursor) ..
                              unicode.sub(state.inputBuffer, state.inputCursor + 2)
        end

      elseif code == keyboard.keys.left then -- Left arrow
        state.inputCursor = math.max(0, state.inputCursor - 1)

      elseif code == keyboard.keys.right then -- Right arrow
        state.inputCursor = math.min(unicode.len(state.inputBuffer), state.inputCursor + 1)

      elseif code == keyboard.keys.up then -- Up arrow
        if keyboard.isControlDown() then
          tui.scrollUp(1)
        end

      elseif code == keyboard.keys.down then -- Down arrow
        if keyboard.isControlDown() then
          tui.scrollDown(1)
        end

      elseif code == keyboard.keys.home then -- Home
        if keyboard.isControlDown() then
          tui.scrollToTop()
        else
          state.inputCursor = 0
        end

      elseif code == keyboard.keys["end"] then -- End
        if keyboard.isControlDown() then
          tui.scrollToBottom()
        else
          state.inputCursor = unicode.len(state.inputBuffer)
        end

      elseif code == keyboard.keys.pageUp then -- Scroll up
        tui.scrollUp(5)

      elseif code == keyboard.keys.pageDown then -- Scroll down
        tui.scrollDown(5)

      elseif char >= 32 and char < 127 then -- Printable ASCII
        state.inputBuffer = unicode.sub(state.inputBuffer, 1, state.inputCursor) ..
                            string.char(char) ..
                            unicode.sub(state.inputBuffer, state.inputCursor + 1)
        state.inputCursor = state.inputCursor + 1
      end

      tui.drawInput()

    elseif ev == "clipboard" then
      -- Paste from clipboard
      local pasted = char
      if pasted then
        state.inputBuffer = unicode.sub(state.inputBuffer, 1, state.inputCursor) ..
                            pasted ..
                            unicode.sub(state.inputBuffer, state.inputCursor + 1)
        state.inputCursor = state.inputCursor + unicode.len(pasted)
        tui.drawInput()
      end

    elseif ev == "scroll" then
      -- Mouse wheel scrolling
      local direction = char
      if direction == 1 then
        -- Scroll up
        tui.scrollUp(3)
      elseif direction == -1 then
        -- Scroll down
        tui.scrollDown(3)
      end
    end
  end
end

-- Show streaming text character by character
function tui.streamText(char)
  local lastEntry = state.history[#state.history]
  if lastEntry and lastEntry.streaming then
    lastEntry.text = lastEntry.text .. char
  else
    table.insert(state.history, { text = char, color = tui.colors.assistant, streaming = true })
  end
  -- Auto-scroll to bottom during streaming
  state.scrollOffset = 0
  tui.redrawContent()
end

-- End streaming (mark as complete)
function tui.endStream()
  local lastEntry = state.history[#state.history]
  if lastEntry then
    lastEntry.streaming = false
  end
end

-- Clear conversation
function tui.clear()
  state.history = {}
  state.scrollOffset = 0
  tui.clearContent()
end

-- Cleanup on exit
function tui.cleanup()
  term.setCursorBlink(false)
  gpu.setBackground(0x000000)
  gpu.setForeground(0xffffff)
  term.clear()
end

-- Check if running
function tui.isRunning()
  return state.running
end

-- Stop running
function tui.stop()
  state.running = false
end

return tui
