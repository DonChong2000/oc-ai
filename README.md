# oc-ai

AI SDK for OpenComputers Lua - generate text, stream responses, use tools, and get structured output.

Inspired by the [Vercel AI SDK](https://sdk.vercel.ai/).

## Requirements
- OpenComputers computer with internet card
- API key for your chosen provider

## Installation

### OPPM

```
oppm register username/oc-ai
oppm install oc-ai
```

### Manual

Copy the `lib/ai/` folder to your OpenComputers `/lib/` directory.

## Quick Start
Set environement key by running `set` in OpenOS shell:

You may use Google's [free API key](https://aistudio.google.com/api-keys)
```
set GOOGLE_GENERATIVE_AI_API_KEY=<Your Key>
```

In `helloworld.lua`:
```lua
local ai = require("ai")
local google = require("ai.google")

local result = ai.generateText({
  model = google("gemini-2.5-flash"),
  prompt = "Hello, world!",
})

print(result.text)
```

## Providers

### Vercel AI Gateway (default)

Use `provider/model` string format. Requires `AI_GATEWAY_API_KEY` env var.

```lua
local ai = require("ai")

ai.generateText({
  model = "openai/gpt-4o-mini",
  prompt = "Hello",
})
```

### Google Generative AI

Direct access to Google's API. Requires `GOOGLE_GENERATIVE_AI_API_KEY` env var.

```lua
local ai = require("ai")
local google = require("ai.google")

ai.generateText({
  model = google("gemini-2.5-flash"),
  prompt = "Hello",
})
```

### OpenAI

Direct access to OpenAI's API. Requires `OPENAI_API_KEY` env var.

```lua
local ai = require("ai")
local openai = require("ai.openai")

ai.generateText({
  model = openai("gpt-4o-mini"),
  prompt = "Hello",
})
```

## API

### generateText

Generate text from a prompt or messages.

```lua
local result = ai.generateText({
  model = "google/gemini-2.5-flash",
  prompt = "Write a recipe (50 words)",           -- or use messages = {...}
  system = "You are a chef.",         -- optional system prompt
  maxOutputTokens = 100,              -- optional
  temperature = 0.7,                  -- optional
})

print(result.text)
print(result.finishReason)  -- "stop", "length", "tool_calls", etc.
```

### streamText

Stream text chunks as they arrive.

```lua
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

Generate structured JSON output.

```lua
local result = ai.generateObject({
  model = "openai/gpt-4o-mini",
  schema = {
    type = "object",
    properties = {
      name = { type = "string" },
      age = { type = "number" },
    },
  },
  prompt = "Generate a random person.",
})

print(result.object.name)
print(result.object.age)
```

### Tool Calling

Define tools that the model can call.

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
  maxSteps = 3,  -- allow multi-step tool calling
})
```

## Examples
Examples of function usage are in the `examples` folder

Run examples from the OpenComputers shell:

```
lua examples/generateText.lua
lua examples/streamText.lua
lua examples/toolCalling.lua
lua examples/generateObject.lua
```

## Environment Variables

Set these in your OpenComputers environment:

- `AI_GATEWAY_API_KEY` - For Vercel AI Gateway (string models)
- `GOOGLE_GENERATIVE_AI_API_KEY` - For Google provider
- `OPENAI_API_KEY` - For OpenAI provider

## License

MIT
