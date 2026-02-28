-- oc-code/agent.lua
-- Core agent logic for oc-code

local ai = require("ai")
local tools = require("oc-code.tools")
local skills = require("oc-code.skills")
local fs = require("filesystem")
local shell = require("shell")

local agent = {}

-- Default configuration
agent.config = {
  model = "anthropic/claude-sonnet-4",
  maxSteps = 10,
  maxOutputTokens = 4096,
  temperature = 0.7,
  systemPrompt = nil,
}

-- Agent state
agent.state = {
  messages = {},
  workingDirectory = nil,
  context = {},
}

-- Build system prompt with context
local function buildSystemPrompt()
  local parts = {}

  -- Base system prompt
  table.insert(parts, [[
You are oc-code, an AI coding assistant running inside Minecraft OpenComputers.
You help users with coding tasks by reading, writing, and editing files, running shell commands, and more.

## Environment
- Platform: Minecraft OpenComputers (Lua 5.2)
- Current directory: ]] .. (agent.state.workingDirectory or shell.getWorkingDirectory() or "/home"))

  -- Add working directory contents summary if available
  local pwd = agent.state.workingDirectory or shell.getWorkingDirectory() or "/home"
  if fs.exists(pwd) and fs.isDirectory(pwd) then
    local entries = {}
    for entry in fs.list(pwd) do
      table.insert(entries, entry)
      if #entries >= 20 then
        table.insert(entries, "...")
        break
      end
    end
    if #entries > 0 then
      table.insert(parts, "\n- Directory contents: " .. table.concat(entries, ", "))
    end
  end

  -- Core instructions
  table.insert(parts, [[

## Guidelines
- Read files before editing them
- Use the edit_file tool for modifications (not write_file for existing files)
- Keep responses concise - this is a terminal environment
- When running commands, check exit codes for errors
- For multi-step tasks, work through them systematically
- If a task is unclear, ask for clarification

## Available Tools
You have access to: read_file, write_file, edit_file, list_directory, glob, grep, shell
]])

  -- Add active skill system prompts
  for _, skill in pairs(skills.registry) do
    if skill.systemPrompt then
      table.insert(parts, "\n## " .. skill.name .. " Skill\n" .. skill.systemPrompt)
    end
  end

  -- Add custom system prompt if configured
  if agent.config.systemPrompt then
    table.insert(parts, "\n## Custom Instructions\n" .. agent.config.systemPrompt)
  end

  -- Add any CLAUDE.md or project instructions
  local claudeMdPath = fs.concat(pwd, "CLAUDE.md")
  if fs.exists(claudeMdPath) then
    local handle = io.open(claudeMdPath, "r")
    if handle then
      local content = handle:read("*a")
      handle:close()
      if content and #content > 0 then
        table.insert(parts, "\n## Project Instructions (CLAUDE.md)\n" .. content:sub(1, 2000))
      end
    end
  end

  return table.concat(parts, "\n")
end

-- Get all available tools
local function getAllTools()
  local allTools = tools.getAll()
  local skillTools = skills.getAllTools()
  for _, tool in ipairs(skillTools) do
    table.insert(allTools, tool)
  end
  return allTools
end

-- Initialize agent
function agent.init(config)
  if config then
    for k, v in pairs(config) do
      agent.config[k] = v
    end
  end

  agent.state.workingDirectory = shell.getWorkingDirectory() or "/home"
  agent.state.messages = {}
  agent.state.context = {}

  -- Load built-in skills
  local skillsDir = "/usr/lib/oc-code/skills"
  if fs.exists(skillsDir) then
    skills.loadFromDirectory(skillsDir)
  end

  -- Also try local skills directory
  local localSkillsDir = fs.concat(agent.state.workingDirectory, ".oc-code/skills")
  if fs.exists(localSkillsDir) then
    skills.loadFromDirectory(localSkillsDir)
  end

  return agent
end

-- Process a user message
function agent.process(input, callbacks)
  callbacks = callbacks or {}
  local onToolCall = callbacks.onToolCall
  local onToolResult = callbacks.onToolResult
  local onChunk = callbacks.onChunk
  local onFinish = callbacks.onFinish

  -- Check for slash commands
  if input:sub(1, 1) == "/" then
    local parts = {}
    for part in input:gmatch("%S+") do
      table.insert(parts, part)
    end
    local command = parts[1]
    local args = table.concat(parts, " ", 2)

    -- Handle built-in commands
    if command == "/clear" then
      agent.state.messages = {}
      return { type = "command", command = "clear" }
    elseif command == "/exit" or command == "/quit" then
      return { type = "command", command = "exit" }
    end

    -- Check skills for command handler
    local skill = skills.findByCommand(command)
    if skill and skill.onActivate then
      local prompt, directResult = skill.onActivate(agent, args)
      if directResult then
        return { type = "direct", text = directResult }
      end
      if prompt then
        input = prompt
      end
    end
  end

  -- Add user message
  table.insert(agent.state.messages, { role = "user", content = input })

  -- Build options
  local opts = {
    model = agent.config.model,
    messages = agent.state.messages,
    system = buildSystemPrompt(),
    tools = getAllTools(),
    maxSteps = agent.config.maxSteps,
    maxOutputTokens = agent.config.maxOutputTokens,
    temperature = agent.config.temperature,
  }

  -- Handle streaming vs non-streaming
  local result
  if onChunk then
    -- Streaming mode
    result = ai.streamText({
      model = opts.model,
      messages = opts.messages,
      system = opts.system,
      tools = opts.tools,
      maxSteps = opts.maxSteps,
      maxOutputTokens = opts.maxOutputTokens,
      temperature = opts.temperature,
      onChunk = function(chunk)
        if chunk.type == "text" then
          onChunk(chunk.text)
        elseif chunk.type == "tool_call" then
          if onToolCall then
            onToolCall(chunk.name, chunk.args)
          end
        elseif chunk.type == "tool_result" then
          if onToolResult then
            onToolResult(chunk.name, chunk.result)
          end
        end
      end,
      onFinish = function(res)
        if onFinish then
          onFinish(res)
        end
      end,
    })
  else
    -- Non-streaming mode with tool call callbacks
    local origExecuteTool = nil

    -- Wrap tool execution to provide callbacks
    if onToolCall or onToolResult then
      local allTools = opts.tools
      for _, tool in ipairs(allTools) do
        local origExecute = tool["function"].execute
        tool["function"].execute = function(args)
          if onToolCall then
            onToolCall(tool["function"].name, args)
          end
          local result = origExecute(args)
          if onToolResult then
            onToolResult(tool["function"].name, result)
          end
          return result
        end
      end
    end

    result = ai.generateText(opts)
  end

  -- Add assistant response to history
  if result and result.text then
    table.insert(agent.state.messages, { role = "assistant", content = result.text })
  end

  return {
    type = "response",
    text = result and result.text or "",
    finishReason = result and result.finishReason,
    toolResults = result and result.toolResults,
    usage = result and result.usage,
  }
end

-- Get conversation history
function agent.getHistory()
  return agent.state.messages
end

-- Clear conversation
function agent.clearHistory()
  agent.state.messages = {}
end

-- Set working directory
function agent.setWorkingDirectory(path)
  if fs.exists(path) and fs.isDirectory(path) then
    agent.state.workingDirectory = fs.canonical(path)
    shell.setWorkingDirectory(agent.state.workingDirectory)
    return true
  end
  return false
end

-- Export for use
return agent
