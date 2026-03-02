-- oc-code/skills/robot.lua
-- Robot skill - loads Robot API context for AI assistance

local skills = require("oc-code.skills")
local fs = require("filesystem")
local shell = require("shell")

-- Path to robot API documentation (relative to working directory)
local ROBOT_DOCS_PATH = "/home/oc-ai/docs/robot.md"

-- Quick reference for common robot operations
local function getQuickReference()
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

return skills.create({
  name = "robot",
  description = "Load Robot API documentation as context",
  commands = { "/robot" },

  onActivate = function(agent, args)
    -- Parse arguments to determine if "full" is specified and extract user prompt
    local loadFull = false
    local userPrompt = args or ""

    if args and args:match("^%s*full%s+") then
      -- "/robot full <prompt>"
      loadFull = true
      userPrompt = args:match("^%s*full%s+(.+)") or ""
    elseif args and args:match("^%s*full%s*$") then
      -- Just "/robot full" with no prompt
      loadFull = true
      userPrompt = ""
    end

    -- Build context (quick reference or full docs)
    local context
    if loadFull then
      -- Try to load full documentation
      if not fs.exists(ROBOT_DOCS_PATH) then
        context = getQuickReference()
      else
        local handle = io.open(ROBOT_DOCS_PATH, "r")
        if handle then
          context = handle:read("*a")
          handle:close()
        else
          context = getQuickReference()
        end
      end
    else
      -- Load quick reference
      context = getQuickReference()
    end

    -- If user provided a prompt, combine context with their question
    if userPrompt ~= "" then
      return "I need help with OpenComputers robot programming.\n\n" ..
             context .. "\n\n" ..
             "My question: " .. userPrompt
    else
      -- No prompt provided, just show the context
      return nil, "Robot API context loaded. You can now ask robot programming questions.\n\n" ..
                  (loadFull and "Full documentation loaded." or "Quick reference loaded.") ..
                  "\n\nExample: /robot write a script to mine a 3x3 area"
    end
  end,

  systemPrompt = [[
## Robot Programming Context
You are helping with OpenComputers robot programming in Lua. Robots have special capabilities:
- Movement and turning
- Inventory management (internal slot alignment)
- Block detection and interaction
- Tool usage and item manipulation
- Fluid handling (with upgrades)

Key considerations:
- Slot indexes differ between internal (robot's view) and external (observer's view)
- Robots have flight height limitations (hovering)
- Tools lose durability and need replacement
- Energy management is critical
]],
})
