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
      "google/gemini-2.5-pro",
    },
  },
  google = {
    name = "Google (Direct)",
    env = "GOOGLE_GENERATIVE_AI_API_KEY",
    models = {
      "gemini-2.5-flash",
      "gemini-2.5-pro",
      "gemini-2.0-flash",
    },
  },
  openai = {
    name = "OpenAI (Direct)",
    env = "OPENAI_API_KEY",
    models = {
      "gpt-4o",
      "gpt-4o-mini",
      "gpt-4-turbo",
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
  local providerModule
  local ok, mod = pcall(require, "ai." .. providerName)
  if not ok then
    return nil, "Provider '" .. providerName .. "' not found"
  end
  return mod(modelId)
end

return skills.create({
  name = "model",
  description = "View and switch AI models/providers",
  commands = { "/model", "/m" },

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
      return nil, table.concat(lines, "\n")
    end

    -- Check for direct provider usage: /model <provider> <model>
    local providerName = parts[1]:lower()
    local modelId = parts[2]

    if modelId and (providerName == "google" or providerName == "openai") then
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
