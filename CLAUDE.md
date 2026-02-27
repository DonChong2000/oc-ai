# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Environment

This is a Minecraft OpenComputers Lua library, not a typical software project. Code runs inside the OpenComputers Lua 5.2-ish runtime with access to OC-specific APIs (`component`, `internet`, `filesystem`, etc.). The working directory is the OC save path on a Windows host.

## Installation (OPPM)

Register and install via OPPM:
```
oppm register username/oc-ai
oppm install oc-ai
```

## Running Code

Run Lua scripts from the in-game OpenComputers shell:
```
lua examples/generateText.lua
```

Example scripts are in `examples/`. API keys are loaded from environment variables.

## Architecture

**lib/ai/init.lua** - Main AI SDK providing `ai.generateText()` and `ai.streamText()`:
- Supports Vercel AI Gateway (string models) and direct providers (model objects)
- Tool calling with automatic execution loop (`maxSteps`)
- Structured output via `ai.Output.object()`
- Returns `{ text, output, finishReason, usage, toolResults, response }`

**lib/ai/google.lua** - Google Generative AI provider:
- Direct access to Google's API
- Env: `GOOGLE_GENERATIVE_AI_API_KEY`

**lib/ai/openai.lua** - OpenAI provider:
- Direct access to OpenAI's API
- Env: `OPENAI_API_KEY`

**lib/ai/vercel.lua** - Vercel AI Gateway provider:
- Routes to multiple providers via gateway
- Env: `AI_GATEWAY_API_KEY`

**lib/ai/utils/init.lua** - Shared utilities:
- `httpPost`, `httpPostStream`, `parseSSELine`

**lib/ai/utils/json.lua** - JSON codec (rxi/json.lua)

**examples/** - Example scripts:
- `generateText.lua` - Basic text generation (gateway)
- `streamText.lua` - Streaming text generation
- `toolCalling.lua` - Tool/function calling
- `multistepToolCalling.lua` - Multi-step tool calling
- `generateStructuredOutput.lua` - Structured JSON output (using Output.object)
- `generateObject.lua` - Structured output with generateObject
- `simpleChatbot.lua` - Multi-turn conversation
- `Google/generateText.lua` - Using Google provider
- `OpenAI/generateText.lua` - Using OpenAI provider

## API Usage

### generateText (Gateway)
```lua
local ai = require("ai")

local result = ai.generateText({
  model = "google/gemini-2.5-flash",  -- provider/model format
  prompt = "Hello",                    -- or use messages = {...}
  system = "You are helpful.",         -- optional
  maxOutputTokens = 100,
  temperature = 0.7,
  maxSteps = 5,                        -- for multi-step tool calls
})

print(result.text)
```

### generateText (Provider)
```lua
local ai = require("ai")
local google = require("ai.google")

local result = ai.generateText({
  model = google("gemini-2.5-flash"),
  prompt = "Hello",
})
```

### streamText
```lua
local ai = require("ai")

ai.streamText({
  model = "openai/gpt-4o-mini",
  prompt = "Tell me a story",
  onChunk = function(chunk)
    if chunk.type == "text" then
      io.write(chunk.text)
    end
  end,
  onFinish = function(result)
    print("\nDone: " .. result.finishReason)
  end,
})
```

### generateObject
```lua
local ai = require("ai")

local result = ai.generateObject({
  model = "openai/gpt-4o-mini",
  schema = {
    type = "object",
    properties = {
      name = { type = "string" },
      age = { type = "number" },
    },
  },
  prompt = "Generate a person.",
})

print(result.object.name)  -- direct access to parsed object
```

### Structured Output (alternative)
```lua
-- Using generateText with Output.object
local result = ai.generateText({
  model = "openai/gpt-4o-mini",
  output = ai.Output.object({ schema = { ... } }),
  prompt = "Generate a person.",
})

print(result.output.name)
```

### Tool Helper
```lua
local weatherTool = ai.tool({
  name = "get_weather",
  description = "Get the weather in a location",
  parameters = {
    type = "object",
    properties = {
      location = { type = "string" },
    },
    required = { "location" },
  },
  execute = function(args)
    return { temperature = 72, condition = "sunny" }
  end,
})

local result = ai.generateText({
  model = "openai/gpt-4o-mini",
  prompt = "What's the weather in Paris?",
  tools = { weatherTool },
  maxSteps = 3,
})
```

## Environment Variables

- `AI_GATEWAY_API_KEY` - For gateway (string models)
- `GOOGLE_GENERATIVE_AI_API_KEY` - For Google provider
- `OPENAI_API_KEY` - For OpenAI provider

## Code Style

- 2-space indentation
- Double quotes for strings
- Local variables and functions (avoid globals)
- Modules return tables of public functions
- Use `type()` checks for public API arguments
- Wrap JSON decode with `pcall`
- Use `error("message")` for failures

## Constraints

- OC Lua 5.2 subset (no full Lua 5.3+ features)
- Limited memory - avoid large buffers
- Network via `require("internet")` with internet card
- No external package manager or build system
