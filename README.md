# oc-ai

The building block for AI-managed factories in OpenComputers.

## Libraries

| Library | Description |
|---------|-------------|
| [ai](docs/ai.md) | Core SDK - text generation, streaming, tools, structured output |
| [oc-code](docs/oc-code.md) | OpenComputerCode - To be implemented.|

## Quick Start for AI-SDK
It is inspired by the [Vercel AI SDK](https://sdk.vercel.ai/).

Set your API key in the OpenOS shell environemnt, you can get a free API key from [Google's AI Studio](https://aistudio.google.com/api-keys).

```
set GOOGLE_GENERATIVE_AI_API_KEY=<Your Key>
```



```lua
local ai = require("ai")
local google = require("ai.google")

local result = ai.generateText({
  model = google("gemini-2.5-flash"),
  prompt = "Hello, world!",
})

print(result.text)
```

## Installation

### OPPM

```
oppm register DonChong2000/oc-ai
oppm install oc-ai
```

### Manual

Copy the `lib/ai/` folder to your OpenComputers `/lib/` directory.

## Requirements

- OpenComputers computer with internet card
- API key for your chosen provider

## License

MIT
