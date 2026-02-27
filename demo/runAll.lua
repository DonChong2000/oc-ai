-- runAll.lua: Run all demo scripts (excluding interactive ones)

local demoDir = "./"

local demos = {
  -- Main demos
  "generateText.lua",
  "streamText.lua",
  "generateObject.lua",
  "generateStructuredOutput.lua",
  "toolCalling.lua",
  "multistepToolCalling.lua",
  -- simpleChatbot.lua is skipped (interactive)

  -- Google provider demos
  "Google/generateText.lua",
  "Google/generateObject.lua",
  "Google/streamText.lua",
  "Google/toolCalling.lua",
  -- Google/simpleChatbot.lua is skipped (interactive)

  -- OpenAI provider demos
  "OpenAI/generateText.lua",
  "OpenAI/generateObject.lua",
  "OpenAI/streamText.lua",
  "OpenAI/toolCalling.lua",
  -- OpenAI/simpleChatbot.lua is skipped (interactive)
}

local passed = 0
local failed = 0
local errors = {}

print("=" .. string.rep("=", 59))
print("Running all demos")
print("=" .. string.rep("=", 59))
print("")

for _, demo in ipairs(demos) do
  local path = demoDir .. "/" .. demo
  print("-" .. string.rep("-", 59))
  print("Running: " .. demo)
  print("-" .. string.rep("-", 59))

  local ok, err = pcall(function()
    dofile(path)
  end)

  print("")

  if ok then
    passed = passed + 1
    print("[PASS] " .. demo)
  else
    failed = failed + 1
    table.insert(errors, { demo = demo, error = err })
    print("[FAIL] " .. demo)
    print("  Error: " .. tostring(err))
  end

  print("")
end

print("=" .. string.rep("=", 59))
print("Summary: " .. passed .. " passed, " .. failed .. " failed")
print("=" .. string.rep("=", 59))

if #errors > 0 then
  print("")
  print("Errors:")
  for _, e in ipairs(errors) do
    print("  - " .. e.demo .. ": " .. tostring(e.error))
  end
end
