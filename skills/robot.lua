-- Robot API Context Skill
-- Provides OpenComputers Robot API documentation as context for AI assistance

local M = {}

-- Path to the robot API documentation
local ROBOT_DOCS_PATH = "/home/oc-ai/docs/robot.md"

-- Load and return the robot API documentation
function M.getContext()
  local fs = require("filesystem")

  if not fs.exists(ROBOT_DOCS_PATH) then
    return nil, "Robot API documentation not found at " .. ROBOT_DOCS_PATH
  end

  local file = io.open(ROBOT_DOCS_PATH, "r")
  if not file then
    return nil, "Failed to open robot API documentation"
  end

  local content = file:read("*a")
  file:close()

  return content
end

-- Get a formatted system prompt with robot API context
function M.getSystemPrompt()
  local content, err = M.getContext()
  if not content then
    return nil, err
  end

  return [[You are an expert at OpenComputers robot programming in Lua. You have access to the complete Robot API documentation.

When helping with robot code:
- Use the robot API functions correctly (robot.forward(), robot.swing(), etc.)
- Remember slot alignment (internal vs external inventory views)
- Consider movement constraints (hovering, flight height)
- Handle energy requirements and tool durability
- Use proper error handling for movement and interactions

Robot API Documentation:
]] .. content
end

-- Get a concise reference for common robot operations
function M.getQuickReference()
  return [[OpenComputers Robot API Quick Reference:

Movement:
  robot.forward/back/up/down() -> boolean, string
  robot.turnLeft/turnRight/turnAround()

Inventory:
  robot.select([slot]) -> number
  robot.count([slot]) -> number
  robot.space([slot]) -> number
  robot.transferTo(slot, [count]) -> boolean

World Interaction:
  robot.detect/detectUp/detectDown() -> boolean, string
  robot.compare/compareUp/compareDown() -> boolean
  robot.swing/swingUp/swingDown([side, sneaky]) -> boolean, string
  robot.use/useUp/useDown([side, sneaky, duration]) -> boolean, string
  robot.place/placeUp/placeDown([side, sneaky]) -> boolean, string

Items:
  robot.drop/dropUp/dropDown([count]) -> boolean
  robot.suck/suckUp/suckDown([count]) -> boolean

Tools:
  robot.durability() -> number, number, number or nil, string

Fluids (if tank upgrades installed):
  robot.tankCount() -> number
  robot.selectTank(tank)
  robot.tankLevel([tank]) -> number
  robot.drain/drainUp/drainDown([count]) -> boolean
  robot.fill/fillUp/fillDown([count]) -> boolean
]]
end

-- Helper to augment AI messages with robot context
function M.augmentMessages(messages, includeFullDocs)
  messages = messages or {}

  local contextPrompt
  if includeFullDocs then
    contextPrompt = M.getSystemPrompt()
  else
    contextPrompt = [[You are an expert at OpenComputers robot programming in Lua.

]] .. M.getQuickReference()
  end

  if not contextPrompt then
    return messages
  end

  -- Add context as system message if no system message exists
  local hasSystem = false
  for _, msg in ipairs(messages) do
    if msg.role == "system" then
      hasSystem = true
      break
    end
  end

  if not hasSystem then
    table.insert(messages, 1, {
      role = "system",
      content = contextPrompt
    })
  end

  return messages
end

return M
