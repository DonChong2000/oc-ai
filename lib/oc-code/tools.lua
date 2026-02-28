-- oc-code/tools.lua
-- Core tools for the oc-code agent (OpenOS compatible)

local ai = require("ai")
local fs = require("filesystem")
local shell = require("shell")
local process = require("process")
local cmnGlob = require("cmn-utils.glob")
local cmnGrep = require("cmn-utils.grep")

local tools = {}

-- Helper: resolve path relative to working directory
local function resolvePath(path)
  if not path or path == "" then
    return shell.getWorkingDirectory()
  end
  if path:sub(1, 1) == "/" then
    return fs.canonical(path)
  end
  return fs.canonical(fs.concat(shell.getWorkingDirectory(), path))
end

-- Helper: read file with line numbers
local function readWithLineNumbers(content, offset, limit)
  local lines = {}
  local i = 0
  for line in content:gmatch("([^\n]*)\n?") do
    i = i + 1
    if i >= offset then
      table.insert(lines, string.format("%4d\t%s", i, line))
    end
    if limit and #lines >= limit then
      break
    end
  end
  return table.concat(lines, "\n")
end

-- Helper: count lines in content
local function countLines(content)
  local count = 1
  for _ in content:gmatch("\n") do
    count = count + 1
  end
  return count
end

-- Tool: Read file
tools.read_file = ai.tool({
  name = "read_file",
  description = "Read the contents of a file. Returns the file content with line numbers.",
  parameters = {
    type = "object",
    properties = {
      path = { type = "string", description = "Path to the file to read" },
      offset = { type = "number", description = "Line number to start reading from (default: 1)" },
      limit = { type = "number", description = "Maximum number of lines to read" },
    },
    required = { "path" },
  },
  execute = function(args)
    local path = resolvePath(args.path)
    if not fs.exists(path) then
      return { error = "File not found: " .. path }
    end
    if fs.isDirectory(path) then
      return { error = "Path is a directory: " .. path }
    end
    local handle = io.open(path, "r")
    if not handle then
      return { error = "Cannot open file: " .. path }
    end
    local content = handle:read("*a")
    handle:close()
    local offset = args.offset or 1
    local limit = args.limit
    return {
      path = path,
      content = readWithLineNumbers(content, offset, limit),
      totalLines = countLines(content)
    }
  end,
})

-- Tool: Write file
tools.write_file = ai.tool({
  name = "write_file",
  description = "Write content to a file, creating it if it doesn't exist or overwriting if it does.",
  parameters = {
    type = "object",
    properties = {
      path = { type = "string", description = "Path to the file to write" },
      content = { type = "string", description = "Content to write to the file" },
    },
    required = { "path", "content" },
  },
  execute = function(args)
    local path = resolvePath(args.path)
    -- Ensure parent directory exists
    local dir = fs.path(path)
    if dir and dir ~= "" and not fs.exists(dir) then
      fs.makeDirectory(dir)
    end
    local handle = io.open(path, "w")
    if not handle then
      return { error = "Cannot write to file: " .. path }
    end
    handle:write(args.content)
    handle:close()
    return { success = true, path = path, bytesWritten = #args.content }
  end,
})

-- Tool: Edit file (string replacement)
tools.edit_file = ai.tool({
  name = "edit_file",
  description = "Edit a file by replacing an exact string match with new content. The old_string must be unique in the file.",
  parameters = {
    type = "object",
    properties = {
      path = { type = "string", description = "Path to the file to edit" },
      old_string = { type = "string", description = "The exact string to find and replace" },
      new_string = { type = "string", description = "The string to replace it with" },
      replace_all = { type = "boolean", description = "Replace all occurrences (default: false)" },
    },
    required = { "path", "old_string", "new_string" },
  },
  execute = function(args)
    local path = resolvePath(args.path)
    if not fs.exists(path) then
      return { error = "File not found: " .. path }
    end
    local handle = io.open(path, "r")
    if not handle then
      return { error = "Cannot open file: " .. path }
    end
    local content = handle:read("*a")
    handle:close()

    -- Count occurrences
    local count = 0
    local pos = 1
    while true do
      local found = content:find(args.old_string, pos, true)
      if not found then break end
      count = count + 1
      pos = found + 1
    end

    if count == 0 then
      return { error = "String not found in file" }
    end
    if count > 1 and not args.replace_all then
      return { error = "String found " .. count .. " times. Use replace_all=true or provide more context." }
    end

    local newContent
    if args.replace_all then
      newContent = content:gsub(args.old_string:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"), args.new_string)
    else
      local idx = content:find(args.old_string, 1, true)
      newContent = content:sub(1, idx - 1) .. args.new_string .. content:sub(idx + #args.old_string)
    end

    handle = io.open(path, "w")
    if not handle then
      return { error = "Cannot write to file: " .. path }
    end
    handle:write(newContent)
    handle:close()
    return { success = true, path = path, replacements = args.replace_all and count or 1 }
  end,
})

-- Tool: List directory
tools.list_directory = ai.tool({
  name = "list_directory",
  description = "List files and directories in a path.",
  parameters = {
    type = "object",
    properties = {
      path = { type = "string", description = "Directory path to list (default: current directory)" },
    },
    required = {},
  },
  execute = function(args)
    local path = resolvePath(args.path or ".")
    if not fs.exists(path) then
      return { error = "Path not found: " .. path }
    end
    if not fs.isDirectory(path) then
      return { error = "Path is not a directory: " .. path }
    end
    local entries = {}
    for entry in fs.list(path) do
      local fullPath = fs.concat(path, entry)
      local isDir = fs.isDirectory(fullPath)
      local size = 0
      if not isDir then
        size = fs.size(fullPath) or 0
      end
      table.insert(entries, {
        name = entry,
        type = isDir and "directory" or "file",
        size = size,
      })
    end
    table.sort(entries, function(a, b)
      if a.type ~= b.type then
        return a.type == "directory"
      end
      return a.name < b.name
    end)
    return { path = path, entries = entries }
  end,
})

-- Tool: Glob (file pattern matching)
tools.glob = ai.tool({
  name = "glob",
  description = "Find files matching a glob pattern (e.g., '*.lua', 'lib/**/*.lua').",
  parameters = {
    type = "object",
    properties = {
      pattern = { type = "string", description = "Glob pattern to match files" },
      path = { type = "string", description = "Starting directory (default: current directory)" },
    },
    required = { "pattern" },
  },
  execute = function(args)
    return cmnGlob.find(args.pattern, args.path)
  end,
})

-- Tool: Grep (search file contents)
tools.grep = ai.tool({
  name = "grep",
  description = "Search for a pattern in files. Returns matching lines with file paths and line numbers.",
  parameters = {
    type = "object",
    properties = {
      pattern = { type = "string", description = "Lua pattern or literal string to search for" },
      path = { type = "string", description = "File or directory to search in (default: current directory)" },
      glob = { type = "string", description = "Only search files matching this glob pattern (e.g., '*.lua')" },
      literal = { type = "boolean", description = "Treat pattern as literal string (default: false)" },
      max_results = { type = "number", description = "Maximum number of results (default: 50)" },
    },
    required = { "pattern" },
  },
  execute = function(args)
    return cmnGrep.search(args.pattern, {
      path = args.path,
      glob = args.glob,
      literal = args.literal,
      maxResults = args.max_results,
    })
  end,
})

-- Tool: Shell (execute OpenOS shell command)
tools.shell = ai.tool({
  name = "shell",
  description = "Execute an OpenOS shell command. Available commands: ls, cat, cp, mv, rm, mkdir, cd, pwd, echo, lua. Note: stdout capture is limited in OpenOS.",
  parameters = {
    type = "object",
    properties = {
      command = { type = "string", description = "The shell command to execute" },
      workdir = { type = "string", description = "Working directory (default: current directory)" },
    },
    required = { "command" },
  },
  execute = function(args)
    local workdir = args.workdir and resolvePath(args.workdir) or nil
    local oldPwd = shell.getWorkingDirectory()

    if workdir and fs.isDirectory(workdir) then
      shell.setWorkingDirectory(workdir)
    end

    -- Try to capture output by redirecting to temp file
    local tempFile = "/tmp/.oc-code-out"
    local cmdWithRedirect = args.command .. " > " .. tempFile .. " 2>&1"

    -- Use shell.execute for OpenOS
    local success, reason = shell.execute(cmdWithRedirect)

    local output = ""
    if fs.exists(tempFile) then
      local handle = io.open(tempFile, "r")
      if handle then
        output = handle:read("*a") or ""
        handle:close()
      end
      fs.remove(tempFile)
    end

    -- Restore working directory
    if workdir and oldPwd then
      shell.setWorkingDirectory(oldPwd)
    end

    -- If redirect didn't work, try executing without redirect
    if output == "" and not success then
      success, reason = shell.execute(args.command)
      output = reason or (success and "Command completed" or "Command failed")
    end

    return {
      command = args.command,
      output = output:sub(1, 4000),
      success = success,
      truncated = #output > 4000,
    }
  end,
})

-- Get all tools as an array
function tools.getAll()
  return {
    tools.read_file,
    tools.write_file,
    tools.edit_file,
    tools.list_directory,
    tools.glob,
    tools.grep,
    tools.shell,
  }
end

-- Get tool by name
function tools.get(name)
  if tools[name] and tools[name]["function"] then
    return tools[name]
  end
  return nil
end

return tools
