-- cmn-utils/grep.lua
-- File content search utility for OpenOS

local fs = require("filesystem")
local shell = require("shell")
local cmnGlob = require("cmn-utils.glob")

local grep = {}

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

-- Escape special pattern characters for literal search
local function escapeLiteral(str)
  return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

-- Search for pattern in files
-- @param pattern string: Lua pattern or literal string to search for
-- @param opts table: Options
--   - path: File or directory to search (default: current directory)
--   - glob: Only search files matching this glob pattern (e.g., "*.lua")
--   - literal: Treat pattern as literal string (default: false)
--   - maxResults: Maximum number of results (default: 50)
--   - maxLineLength: Maximum line length to return (default: 200)
-- @return table: { pattern, results = {...}, truncated = bool }
function grep.search(pattern, opts)
  opts = opts or {}
  local basePath = resolvePath(opts.path or ".")
  local maxResults = opts.maxResults or 50
  local maxLineLength = opts.maxLineLength or 200
  local results = {}

  if opts.literal then
    pattern = escapeLiteral(pattern)
  end

  local function searchFile(filePath, relPath)
    local handle = io.open(filePath, "r")
    if not handle then return end
    local lineNum = 0
    for line in handle:lines() do
      lineNum = lineNum + 1
      if line:find(pattern) then
        table.insert(results, {
          file = relPath,
          line = lineNum,
          content = line:sub(1, maxLineLength),
        })
        if #results >= maxResults then
          handle:close()
          return true
        end
      end
    end
    handle:close()
  end

  local function walk(dir, prefix)
    if not fs.isDirectory(dir) then
      -- Single file
      if cmnGlob.match(fs.name(dir), opts.glob) then
        searchFile(dir, prefix)
      end
      return
    end
    for entry in fs.list(dir) do
      local fullPath = fs.concat(dir, entry)
      local relPath = prefix == "" and entry or (prefix .. "/" .. entry)
      if fs.isDirectory(fullPath) then
        walk(fullPath, relPath)
      else
        if cmnGlob.match(entry, opts.glob) then
          if searchFile(fullPath, relPath) then
            return -- Max results reached
          end
        end
      end
      if #results >= maxResults then return end
    end
  end

  walk(basePath, fs.isDirectory(basePath) and "" or fs.name(basePath))
  return {
    pattern = opts.literal and ("literal: " .. pattern) or pattern,
    results = results,
    truncated = #results >= maxResults
  }
end

-- Search in a single file
-- @param pattern string: Pattern to search for
-- @param filePath string: Path to file
-- @param opts table: Options (literal, maxResults, maxLineLength)
-- @return table: Array of { line, content } matches
function grep.searchFile(pattern, filePath, opts)
  opts = opts or {}
  local path = resolvePath(filePath)
  local maxResults = opts.maxResults or 50
  local maxLineLength = opts.maxLineLength or 200
  local results = {}

  if opts.literal then
    pattern = escapeLiteral(pattern)
  end

  local handle = io.open(path, "r")
  if not handle then
    return nil, "Cannot open file: " .. path
  end

  local lineNum = 0
  for line in handle:lines() do
    lineNum = lineNum + 1
    if line:find(pattern) then
      table.insert(results, {
        line = lineNum,
        content = line:sub(1, maxLineLength),
      })
      if #results >= maxResults then
        break
      end
    end
  end
  handle:close()
  return results
end

-- Expose helper for literal escaping
grep.escapeLiteral = escapeLiteral

return grep
