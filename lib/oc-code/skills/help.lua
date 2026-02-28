-- oc-code/skills/help.lua
-- Help skill - shows available commands and usage

local skills = require("oc-code.skills")

return skills.create({
  name = "help",
  description = "Show help and available commands",
  commands = { "/help", "/?" },

  onActivate = function(agent, args)
    local currentModel = agent.config.model
    local modelStr = type(currentModel) == "string" and currentModel or
      (currentModel.provider .. ":" .. currentModel.modelId)

    local lines = {
      "oc-code - AI Coding Agent for OpenComputers",
      "",
      "Current model: " .. modelStr,
      "",
      "Commands:",
      "  /help, /?       - Show this help message",
      "  /model, /m      - View/switch AI model or provider",
      "    /model                    - List available models",
      "    /model <provider/model>   - Use gateway model",
      "    /model google <model>     - Use Google directly",
      "    /model openai <model>     - Use OpenAI directly",
      "  /commit, /c     - Create a git commit",
      "  /clear          - Clear conversation history",
      "  /exit, /quit    - Exit oc-code",
      "",
      "Shell Commands:",
      "  !<command>      - Execute shell command directly",
      "    Examples:",
      "      !ls         - List files in current directory",
      "      !pwd        - Print working directory",
      "      !df -h      - Check disk space",
      "",
      "Tools:",
      "  read_file, write_file, edit_file, list_directory,",
      "  glob, grep, shell",
      "",
      "Tips:",
      "  - Type naturally to ask for help with code",
      "  - Use PageUp/PageDown to scroll",
      "  - Use Ctrl+C to cancel",
    }
    -- Return nil to prevent sending to AI, handle directly
    return nil, table.concat(lines, "\n")
  end,
})
