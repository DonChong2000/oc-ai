-- oc-code/skills/commit.lua
-- Git commit skill

local skills = require("oc-code.skills")

return skills.create({
  name = "commit",
  description = "Create a git commit with a generated message",
  commands = { "/commit", "/c" },

  systemPrompt = [[
When the user runs /commit, help them create a git commit:
1. First run `git status` to see changes
2. Run `git diff --staged` to see staged changes
3. If there are unstaged changes, ask if they want to stage them
4. Analyze the changes and generate a clear, concise commit message
5. Create the commit with the generated message

Commit message guidelines:
- Use imperative mood ("Add feature" not "Added feature")
- First line should be under 72 characters
- Focus on WHY the change was made, not just WHAT changed
]],

  onActivate = function(agent, args)
    local prompt = "Please help me create a git commit."
    if args and args ~= "" then
      prompt = prompt .. " Additional context: " .. args
    end
    return prompt
  end,
})
