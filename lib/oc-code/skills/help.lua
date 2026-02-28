-- oc-code/skills/help.lua
-- Help skill - shows available commands and usage

local skills = require("oc-code.skills")

return skills.create({
  name = "help",
  description = "Show help and available commands",
  commands = { "/help", "/?" },

  onActivate = function(agent, args)
    local lines = {
      "oc-code - AI Coding Agent for OpenComputers",
      "",
      "Commands:",
      "  /help, /?      - Show this help message",
      "  /commit, /c    - Create a git commit",
      "  /clear         - Clear conversation history",
      "  /exit, /quit   - Exit oc-code",
      "",
      "Available Tools:",
      "  read_file      - Read file contents",
      "  write_file     - Write/create files",
      "  edit_file      - Edit files with string replacement",
      "  list_directory - List directory contents",
      "  glob           - Find files by pattern",
      "  grep           - Search file contents",
      "  shell          - Execute OpenOS shell commands",
      "",
      "Tips:",
      "  - Just type naturally to ask for help with code",
      "  - The agent can read, edit, and create files",
      "  - Use Ctrl+C to cancel the current operation",
    }
    -- Return nil to prevent sending to AI, handle directly
    return nil, table.concat(lines, "\n")
  end,
})
