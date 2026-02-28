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
  -- Command popup state
  showCommandPopup = false,
  commandPopupIndex = 1,
  filteredCommands = {},
}

-- Available commands (will be updated with skills)
local availableCommands = {
  { cmd = "/help", desc = "Show help and commands" },
  { cmd = "/?", desc = "Show help (alias)" },
  { cmd = "/model", desc = "View/switch AI model" },
  { cmd = "/clear", desc = "Clear conversation" },
  { cmd = "/exit", desc = "Exit oc-code" },
  { cmd = "/quit", desc = "Exit (alias)" },
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

-- Draw status bar (above input line)
function tui.drawStatus()
  local y = state.height - 1  -- Status bar is just above input
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

-- Content area bounds (header at line 1, content from line 2, status at height-1, input at height)
local function getContentBounds()
  return 2, 2, state.width - 2, state.height - 3
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
    local argsStr = type(args) == "string" and args or require("cmn-utils.json").encode(args)
    if unicode.len(argsStr) > 100 then
      argsStr = unicode.sub(argsStr, 1, 97) .. "..."
    end
    tui.print("   " .. argsStr, tui.colors.dim)
  end
end

-- Print tool result
function tui.printToolResult(name, result)
  if not state.showTools then return end
  local resultStr = type(result) == "string" and result or require("cmn-utils.json").encode(result)
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

-- Draw input line (at the very bottom)
function tui.drawInput()
  local y = state.height
  gpu.setBackground(tui.colors.background)
  gpu.fill(1, y, state.width, 1, " ")
  gpu.setForeground(tui.colors.prompt)
  gpu.set(2, y, "> ")
  gpu.setForeground(tui.colors.foreground)

  local inputStart = 4
  local maxWidth = state.width - inputStart - 1
  local displayText = state.inputBuffer
  local visibleCursorPos = state.inputCursor
  local textOffset = 0

  if unicode.len(displayText) > maxWidth then
    local start = math.max(1, state.inputCursor - maxWidth + 10)
    textOffset = start - 1
    displayText = unicode.sub(state.inputBuffer, start, start + maxWidth - 1)
    visibleCursorPos = state.inputCursor - textOffset
  end

  gpu.set(inputStart, y, displayText)

  -- Draw visual cursor indicator
  local cursorX = inputStart + visibleCursorPos
  if cursorX <= state.width - 1 then
    local charAtCursor = unicode.sub(state.inputBuffer, state.inputCursor + 1, state.inputCursor + 1)
    if charAtCursor == "" then charAtCursor = " " end

    -- Draw inverted cursor (highlight the character at cursor position)
    gpu.setBackground(tui.colors.foreground)
    gpu.setForeground(tui.colors.background)
    gpu.set(cursorX, y, charAtCursor)
    gpu.setBackground(tui.colors.background)
    gpu.setForeground(tui.colors.foreground)
  end

  -- Also set hardware cursor position for accessibility
  term.setCursor(cursorX, y)
  term.setCursorBlink(false)  -- Disable blink since we have visual cursor
end

-- Filter commands based on input
local function filterCommands(input)
  if not input or input == "" then
    return {}
  end

  -- Only show popup if input starts with /
  if input:sub(1, 1) ~= "/" then
    return {}
  end

  local filtered = {}
  local searchTerm = input:lower()

  for _, cmd in ipairs(availableCommands) do
    if cmd.cmd:lower():find(searchTerm, 1, true) == 1 then
      table.insert(filtered, cmd)
    end
  end

  return filtered
end

-- Draw command popup above status bar
local function drawCommandPopup()
  if not state.showCommandPopup or #state.filteredCommands == 0 then
    return
  end

  local maxItems = math.min(#state.filteredCommands, 8)
  local popupWidth = 35
  local popupHeight = maxItems + 2  -- +2 for border
  local popupX = 2
  local popupY = state.height - 2 - popupHeight  -- Above status bar (height-1) and input (height)

  -- Draw popup background
  gpu.setBackground(tui.colors.status)
  gpu.setForeground(tui.colors.foreground)

  -- Top border
  gpu.fill(popupX, popupY, popupWidth, 1, " ")
  gpu.set(popupX, popupY, "Commands:")

  -- Draw commands
  for i = 1, maxItems do
    local cmd = state.filteredCommands[i]
    local y = popupY + i
    gpu.fill(popupX, y, popupWidth, 1, " ")

    if i == state.commandPopupIndex then
      gpu.setBackground(tui.colors.highlight)
      gpu.setForeground(tui.colors.assistant)
      gpu.fill(popupX, y, popupWidth, 1, " ")
    else
      gpu.setBackground(tui.colors.status)
      gpu.setForeground(tui.colors.foreground)
    end

    local cmdText = cmd.cmd
    local descText = cmd.desc
    local maxCmdLen = 12
    local maxDescLen = popupWidth - maxCmdLen - 4

    if unicode.len(descText) > maxDescLen then
      descText = unicode.sub(descText, 1, maxDescLen - 2) .. ".."
    end

    gpu.set(popupX + 1, y, cmdText)
    gpu.setForeground(tui.colors.dim)
    gpu.set(popupX + maxCmdLen + 2, y, descText)

    gpu.setBackground(tui.colors.status)
    gpu.setForeground(tui.colors.foreground)
  end

  -- Bottom border with hint
  local hintY = popupY + maxItems + 1
  gpu.fill(popupX, hintY, popupWidth, 1, " ")
  gpu.setForeground(tui.colors.dim)
  gpu.set(popupX + 1, hintY, "Tab/Enter: select  Esc: close")

  gpu.setBackground(tui.colors.background)
  gpu.setForeground(tui.colors.foreground)
end

-- Update command popup state
local function updateCommandPopup()
  state.filteredCommands = filterCommands(state.inputBuffer)
  state.showCommandPopup = #state.filteredCommands > 0
  state.commandPopupIndex = math.min(state.commandPopupIndex, math.max(1, #state.filteredCommands))
end

-- Hide command popup
local function hideCommandPopup()
  state.showCommandPopup = false
  state.filteredCommands = {}
  state.commandPopupIndex = 1
  tui.redrawContent()
end

-- Select command from popup
local function selectCommand()
  if state.showCommandPopup and state.filteredCommands[state.commandPopupIndex] then
    local cmd = state.filteredCommands[state.commandPopupIndex].cmd
    state.inputBuffer = cmd .. " "
    state.inputCursor = unicode.len(state.inputBuffer)
    hideCommandPopup()
    return true
  end
  return false
end

-- Read user input
function tui.readInput()
  state.inputBuffer = ""
  state.inputCursor = 0
  state.showCommandPopup = false
  state.commandPopupIndex = 1
  tui.drawInput()

  while true do
    local ev, _, char, code = event.pull()

    if ev == "interrupted" then
      hideCommandPopup()
      return nil

    elseif ev == "key_down" then
      if char == 13 then -- Enter
        -- If popup is showing, select the command
        if state.showCommandPopup and #state.filteredCommands > 0 then
          selectCommand()
        else
          -- Submit the input
          local input = state.inputBuffer
          state.inputBuffer = ""
          state.inputCursor = 0
          hideCommandPopup()
          return input
        end

      elseif char == 9 then -- Tab
        -- Select from popup if showing
        if state.showCommandPopup then
          selectCommand()
        end

      elseif char == 27 then -- Escape
        if state.showCommandPopup then
          hideCommandPopup()
        end

      elseif char == 8 or code == keyboard.keys.back then -- Backspace
        if state.inputCursor > 0 then
          state.inputBuffer = unicode.sub(state.inputBuffer, 1, state.inputCursor - 1) ..
                              unicode.sub(state.inputBuffer, state.inputCursor + 1)
          state.inputCursor = state.inputCursor - 1
          updateCommandPopup()
        end

      elseif code == keyboard.keys.delete then -- Delete
        if state.inputCursor < unicode.len(state.inputBuffer) then
          state.inputBuffer = unicode.sub(state.inputBuffer, 1, state.inputCursor) ..
                              unicode.sub(state.inputBuffer, state.inputCursor + 2)
          updateCommandPopup()
        end

      elseif code == keyboard.keys.left then -- Left arrow
        state.inputCursor = math.max(0, state.inputCursor - 1)

      elseif code == keyboard.keys.right then -- Right arrow
        state.inputCursor = math.min(unicode.len(state.inputBuffer), state.inputCursor + 1)

      elseif code == keyboard.keys.up then -- Up arrow
        if state.showCommandPopup then
          -- Navigate popup up
          state.commandPopupIndex = state.commandPopupIndex - 1
          if state.commandPopupIndex < 1 then
            state.commandPopupIndex = #state.filteredCommands
          end
        elseif keyboard.isControlDown() then
          tui.scrollUp(1)
        end

      elseif code == keyboard.keys.down then -- Down arrow
        if state.showCommandPopup then
          -- Navigate popup down
          state.commandPopupIndex = state.commandPopupIndex + 1
          if state.commandPopupIndex > #state.filteredCommands then
            state.commandPopupIndex = 1
          end
        elseif keyboard.isControlDown() then
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
        updateCommandPopup()
      end

      tui.drawInput()
      drawCommandPopup()

    elseif ev == "clipboard" then
      -- Paste from clipboard
      local pasted = char
      if pasted then
        state.inputBuffer = unicode.sub(state.inputBuffer, 1, state.inputCursor) ..
                            pasted ..
                            unicode.sub(state.inputBuffer, state.inputCursor + 1)
        state.inputCursor = state.inputCursor + unicode.len(pasted)
        updateCommandPopup()
        tui.drawInput()
        drawCommandPopup()
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
