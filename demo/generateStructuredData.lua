local ai = require("ai")
local json = require("json")
local config = dofile("config.lua")

local function strip_json_fence(text)
  if type(text) ~= "string" then
    return text
  end
  local stripped = text:gsub("^%s*```json%s*", "")
  stripped = stripped:gsub("^%s*```%s*", "")
  stripped = stripped:gsub("%s*```%s*$", "")
  return stripped
end

local function extract_json_object(text)
  if type(text) ~= "string" then
    return text
  end
  local start_index = text:find("{", 1, true)
  if not start_index then
    return text
  end

  local depth = 0
  local in_string = false
  local escape = false
  for i = start_index, #text do
    local ch = text:sub(i, i)
    if in_string then
      if escape then
        escape = false
      elseif ch == "\\" then
        escape = true
      elseif ch == "\"" then
        in_string = false
      end
    else
      if ch == "\"" then
        in_string = true
      elseif ch == "{" then
        depth = depth + 1
      elseif ch == "}" then
        depth = depth - 1
        if depth == 0 then
          return text:sub(start_index, i)
        end
      end
    end
  end

  return text:sub(start_index)
end

local function print_recipe(recipe)
  if type(recipe) ~= "table" then
    print("Recipe missing or invalid.")
    return
  end

  print("Recipe: " .. tostring(recipe.name or "(unknown)"))
  print("Ingredients:")
  local ingredients = recipe.ingredients
  if type(ingredients) == "table" then
    for i = 1, #ingredients do
      local item = ingredients[i]
      if type(item) == "table" then
        local name = tostring(item.name or "")
        local amount = tostring(item.amount or "")
        if name ~= "" or amount ~= "" then
          print("- " .. name .. " " .. amount)
        end
      end
    end
  end

  print("Steps:")
  local steps = recipe.steps
  if type(steps) == "table" then
    for i = 1, #steps do
      print(i .. ". " .. tostring(steps[i] or ""))
    end
  end
end

local result = ai.generateText({
  model = "google/gemini-2.5-flash",
  prompt = table.concat({
    "Return a JSON object that matches this schema:",
    "{",
    "  recipe: {",
    "    name: string,",
    "    ingredients: [{ name: string, amount: string }],",
    "    steps: [string]",
    "  }",
    "}",
    "Generate a lasagna recipe.",
    "Do not include markdown or extra text.",
    "Return a single-line JSON string.",
    "Use exactly 4 ingredients and 4 steps.",
    "Keep each ingredient name under 10 characters and amount under 8 characters.",
    "Keep each step under 32 characters.",
  }, "\n"),
  apiKey = config.AI_GATEWAY_API_KEY,
  maxOutputTokens = 800,
})

local raw_text = strip_json_fence(result.text or "")
local ok, decoded = pcall(json.decode, raw_text)
if not ok then
  local extracted = extract_json_object(raw_text)
  ok, decoded = pcall(json.decode, extracted)
end
if not ok then
  print("Failed to parse JSON. Raw response:")
  print(result.text or "")
  print("Finish reason: " .. tostring(result.finishReason or ""))
  if result.usage then
    print("Usage tokens: " .. tostring(result.usage.totalTokens or ""))
  end
  return
end

local recipe = decoded and decoded.recipe or nil
print("Finish reason: " .. tostring(result.finishReason or ""))
if result.usage then
  print("Usage tokens: " .. tostring(result.usage.totalTokens or ""))
end
print_recipe(recipe)
