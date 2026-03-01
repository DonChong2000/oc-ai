-- oc-code/skills/model.lua
-- Model selection skill - switch between AI providers and models

local skills = require("oc-code.skills")

-- Available providers and their popular models
local providers = {
  gateway = {
    name = "Gateway (Vercel)",
    env = "AI_GATEWAY_API_KEY",
    models = {
      "anthropic/claude-sonnet-4",
      "anthropic/claude-opus-4",
      "openai/gpt-4o",
      "openai/gpt-4o-mini",
      "google/gemini-2.5-flash",
      "Or Type in model ID",
    },
  },
  google = {
    name = "Google (Direct)",
    env = "GOOGLE_GENERATIVE_AI_API_KEY",
    models = {
      "gemini-flash-latest",
      "gemini-3-flash-preview",
    },
  },
  openai = {
    name = "OpenAI (Direct)",
    env = "OPENAI_API_KEY",
    models = {
      "gpt-5.2",
      "gpt-5-mini",
      "gpt-4o",
      "codex model are not supported yet"
    },
  },
  groq = {
    name = "Groq (Direct)",
    env = "GROQ_API_KEY",
    models = {
      "openai/gpt-oss-120b",
      "llama-3.3-70b-versatile",
    },
  },
}

-- Format model display
local function formatModel(model)
  if type(model) == "string" then
    return model
  elseif type(model) == "table" and model.provider and model.modelId then
    return model.provider .. ":" .. model.modelId .. " (direct)"
  else
    return tostring(model)
  end
end

-- Create direct provider model object
local function createDirectModel(providerName, modelId)
  local ok, mod = pcall(require, "ai." .. providerName)
  if not ok then
    return nil, "Provider '" .. providerName .. "' not found"
  end
  return mod(modelId)
end

-- Completion handler for /model command
local function getCompletions(args)
  local results = {}
  local parts = {}
  for part in args:gmatch("%S+") do
    table.insert(parts, part)
  end

  -- Check if completing provider-specific model
  -- Only show provider models when: 2+ parts OR 1 part with trailing space
  local hasTrailingSpace = args:match("%s$")
  if #parts >= 2 or (#parts == 1 and hasTrailingSpace) then
    local providerName = parts[1]:lower()
    local providerData = providers[providerName]
    if providerData and providerName ~= "gateway" then
      local modelSearch = parts[2] or ""
      local prefix = "/model " .. providerName .. " "
      for _, model in ipairs(providerData.models) do
        if modelSearch == "" or model:lower():find(modelSearch:lower(), 1, true) == 1 then
          table.insert(results, { cmd = prefix .. model, desc = providerData.name })
        end
      end
      return results
    end
  end

  -- Complete first argument (gateway models or providers)
  local searchTerm = (parts[1] or ""):lower()

  -- Gateway models
  for _, model in ipairs(providers.gateway.models) do
    if model:find("/") and (searchTerm == "" or model:lower():find(searchTerm, 1, true) == 1) then
      table.insert(results, { cmd = "/model " .. model, desc = "Gateway" })
    end
  end

  -- Direct providers
  for name, data in pairs(providers) do
    if name ~= "gateway" and (searchTerm == "" or name:find(searchTerm, 1, true) == 1) then
      table.insert(results, { cmd = "/model " .. name, desc = data.name })
    end
  end

  return results
end

-- Register completion handler with TUI (if available)
local ok, tui = pcall(require, "oc-code.tui")
if ok and tui.registerCompletion then
  tui.registerCompletion("/model", getCompletions, "Models")
end

return skills.create({
  name = "model",
  description = "View and switch AI models/providers",
  commands = { "/model" },

  onActivate = function(agent, args)
    args = args or ""
    local parts = {}
    for part in args:gmatch("%S+") do
      table.insert(parts, part)
    end

    local subcommand = parts[1]

    -- No args or "list" - show current model and available options
    if not subcommand or subcommand == "list" then
      local lines = {
        "Current model: " .. formatModel(agent.config.model),
        "",
        "Usage:",
        "  /model <provider/model>  - Set gateway model",
        "  /model <provider> <model> - Set direct provider model",
        "",
        "Gateway models (via Vercel AI Gateway):",
      }
      for _, model in ipairs(providers.gateway.models) do
        table.insert(lines, "  " .. model)
      end
      table.insert(lines, "")
      table.insert(lines, "Direct providers:")
      table.insert(lines, "  /model google <model>  - Use Google directly")
      for _, model in ipairs(providers.google.models) do
        table.insert(lines, "    " .. model)
      end
      table.insert(lines, "  /model openai <model>  - Use OpenAI directly")
      for _, model in ipairs(providers.openai.models) do
        table.insert(lines, "    " .. model)
      end
      table.insert(lines, "  /model groq <model>    - Use Groq directly")
      for _, model in ipairs(providers.groq.models) do
        table.insert(lines, "    " .. model)
      end
      return nil, table.concat(lines, "\n")
    end

    -- Check for direct provider usage: /model <provider> <model>
    local providerName = parts[1]:lower()
    local modelId = parts[2]

    if modelId and (providerName == "google" or providerName == "openai" or providerName == "groq") then
      local model, err = createDirectModel(providerName, modelId)
      if not model then
        return nil, "Error: " .. err
      end
      agent.config.model = model
      return nil, "Switched to " .. providerName .. " provider with model: " .. modelId
    end

    -- Otherwise treat as gateway model string
    local gatewayModel = args

    -- Validate it looks like a gateway model (provider/model format)
    if not gatewayModel:match("/") then
      return nil, "Invalid model format. Use 'provider/model' for gateway or '/model <provider> <model>' for direct."
    end

    agent.config.model = gatewayModel
    return nil, "Switched to gateway model: " .. gatewayModel
  end,
})
