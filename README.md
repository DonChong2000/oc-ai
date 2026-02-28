# ai

AI toolkit for OpenComputers - build AI-powered automation in Minecraft.

## Libraries

| Library | Description |
|---------|-------------|
| [ai](docs/ai.md) | Vercel-like Core SDK for text generation, streaming, tool calling, and structured output |
| [oc-code](docs/oc-code.md) | Interactive AI coding agent with file editing, shell access, and TUI |

## Quick Start: oc-code

oc-code is an AI coding assistant that runs directly in OpenComputers. It can read, write, and edit files, run shell commands, and help you with coding tasks.

### Setup

Set your API key (get one free from [Google AI Studio](https://aistudio.google.com/api-keys)):

```
set GOOGLE_GENERATIVE_AI_API_KEY=<your-key>
```

### Run

```
oc-code
```

### Features

- **Interactive TUI** - Color-coded interface with scrolling and command autocomplete
- **Terminal mode** - Works on robots without GPU/screen
- **Multi-provider support** - Anthropic, OpenAI, Google (direct or via gateway)
- **Built-in tools** - read_file, write_file, edit_file, list_directory, glob, grep, shell
- **Skills system** - Extensible command handlers

### Commands

| Command | Description |
|---------|-------------|
| `/help` | Show available commands |
| `/model` | View or switch AI model |
| `/clear` | Clear conversation history |
| `/exit` | Exit oc-code |
| `!<cmd>` | Execute shell command directly |

## Quick Start: AI SDK

The AI SDK provides programmatic access to AI models for your own scripts.

### Basic Usage

```lua
local ai = require("ai")
local google = require("ai.google")

local result = ai.generateText({
  model = google("gemini-2.5-flash"),
  prompt = "Hello, world!",
})

print(result.text)
```

### Tool Calling

```lua
local weatherTool = ai.tool({
  name = "get_weather",
  description = "Get current weather",
  parameters = {
    type = "object",
    properties = {
      location = { type = "string" },
    },
    required = { "location" },
  },
  execute = function(args)
    return { temp = 72, condition = "sunny" }
  end,
})

local result = ai.generateText({
  model = google("gemini-2.5-flash"),
  prompt = "What's the weather in Tokyo?",
  tools = { weatherTool },
  maxSteps = 3,
})
```

### Structured Output

```lua
local result = ai.generateObject({
  model = google("gemini-2.5-flash"),
  schema = {
    type = "object",
    properties = {
      name = { type = "string" },
      age = { type = "number" },
    },
  },
  prompt = "Generate a random person.",
})

print(result.object.name, result.object.age)
```

## Installation

### OPPM (Recommended)

```
oppm register DonChong2000/oc-ai
oppm install ai
```

### Manual

Copy `lib/ai/`, `lib/oc-code/`, and `lib/cmn-utils/` to your `/lib/` directory.

Copy `bin/oc-code.lua` to your `/bin/` directory.

## Environment Variables

| Variable | Provider | Required For |
|----------|----------|--------------|
| `GOOGLE_GENERATIVE_AI_API_KEY` | Google | `google("model")` or `/model google <model>` |
| `OPENAI_API_KEY` | OpenAI | `openai("model")` or `/model openai <model>` |
| `AI_GATEWAY_API_KEY` | Vercel Gateway | `"provider/model"` string format |

## Requirements

- OpenComputers computer with internet card
- API key for your chosen provider
- For TUI: Tier 2+ screen (4-bit color) and GPU
- For terminal mode: Any computer or robot

## License

MIT
