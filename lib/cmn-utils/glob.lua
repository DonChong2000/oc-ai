-- cmn-utils/glob.lua
-- File pattern matching utility for OpenOS

local fs = require("filesystem")
local shell = require("shell")

local glob = {}

-- Convert glob pattern to Lua pattern
local function globToPattern(globPat)
  local pat = globPat
  pat = pat:gsub("([%^%$%(%)%%%.%[%]%+%-%?])", "%%%1")
  pat = pat:gsub("%*%*", "\001")
  pat = pat:gsub("%*", "[^/]*")
  pat = pat:gsub("\001", ".*")
  return "^" .. pat .. "$"
end

-- Resolve path relative to working directory
local function resolvePath(path)
  if not path or path == "" then
    return shell.getWorkingDirectory()
  end
  if path:sub(1, 1) == "/" then
    return fs.canonical(path)
  end
  return fs.canonical(fs.concat(shell.getWorkingDirectory(), path))
end

-- Find files matching a glob pattern
-- @param pattern string: Glob pattern (e.g., "*.lua", "lib/**/*.lua")
-- @param basePath string: Starting directory (default: current directory)
-- @return table: { path = basePath, pattern = pattern, matches = {...} }
function glob.find(pattern, basePath)
  basePath = resolvePath(basePath or ".")
  local matches = {}
  local luaPattern = globToPattern(pattern)

  local function walk(dir, prefix)
    if not fs.isDirectory(dir) then return end
    for entry in fs.list(dir) do
      local fullPath = fs.concat(dir, entry)
      local relPath = prefix == "" and entry or (prefix .. "/" .. entry)
      if fs.isDirectory(fullPath) then
        walk(fullPath, relPath)
      else
        if relPath:match(luaPattern) then
          table.insert(matches, relPath)
        end
      end
    end
  end

  walk(basePath, "")
  table.sort(matches)
  return { path = basePath, pattern = pattern, matches = matches }
end

-- Check if a filename matches a glob pattern
-- @param name string: Filename to check
-- @param pattern string: Glob pattern (e.g., "*.lua")
-- @return boolean: True if matches
function glob.match(name, pattern)
  if not pattern then return true end
  local pat = pattern
  pat = pat:gsub("([%^%$%(%)%%%.%[%]%+%-%?])", "%%%1")
  pat = pat:gsub("%*", ".*")
  return name:match("^" .. pat .. "$") ~= nil
end

-- Convert glob to Lua pattern (exposed for advanced use)
glob.toPattern = globToPattern

return glob
