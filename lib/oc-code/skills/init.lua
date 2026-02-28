-- oc-code/skills/init.lua
-- Skills system for extensible agent capabilities

local fs = require("filesystem")

local skills = {}

-- Registered skills
skills.registry = {}

-- Base skill class
skills.Skill = {}
skills.Skill.__index = skills.Skill

function skills.Skill:new(opts)
  local self = setmetatable({}, skills.Skill)
  self.name = opts.name or error("Skill requires a name")
  self.description = opts.description or ""
  self.commands = opts.commands or {}  -- Slash commands this skill handles
  self.tools = opts.tools or {}        -- Additional tools this skill provides
  self.onActivate = opts.onActivate    -- Called when skill is activated via command
  self.onMessage = opts.onMessage      -- Called for each user message
  self.systemPrompt = opts.systemPrompt -- Additional system prompt
  return self
end

-- Register a skill
function skills.register(skill)
  if not skill.name then
    error("Cannot register skill without name")
  end
  skills.registry[skill.name] = skill
  return skill
end

-- Get a skill by name
function skills.get(name)
  return skills.registry[name]
end

-- Get all registered skills
function skills.getAll()
  local list = {}
  for _, skill in pairs(skills.registry) do
    table.insert(list, skill)
  end
  return list
end

-- Find skill that handles a command
function skills.findByCommand(command)
  for _, skill in pairs(skills.registry) do
    for _, cmd in ipairs(skill.commands or {}) do
      if cmd == command then
        return skill
      end
    end
  end
  return nil
end

-- Get all tools from all skills
function skills.getAllTools()
  local allTools = {}
  for _, skill in pairs(skills.registry) do
    if skill.tools then
      for _, tool in ipairs(skill.tools) do
        table.insert(allTools, tool)
      end
    end
  end
  return allTools
end

-- Load skills from directory
function skills.loadFromDirectory(dir)
  if not fs.exists(dir) or not fs.isDirectory(dir) then
    return
  end
  for file in fs.list(dir) do
    if file:match("%.lua$") and file ~= "init.lua" then
      local path = fs.concat(dir, file)
      local ok, skill = pcall(dofile, path)
      if ok and skill and skill.name then
        skills.register(skill)
      end
    end
  end
end

-- Create a new skill (helper function)
function skills.create(opts)
  return skills.Skill:new(opts)
end

return skills
