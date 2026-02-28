# oc-code v0.2.0

Interactive AI coding agent for OpenComputers.

## Installation

```
oppm register DonChong2000/oc-ai
oppm install ai
```

## Usage

### Command Line

```
oc-code [options]
  -m, --model <model>   Set AI model (default: anthropic/claude-sonnet-4)
  -t, --terminal        Force terminal mode (for robots)
  -h, --help            Show help
```

### Programmatic

```lua
local occode = require("oc-code")

-- Interactive mode
occode.run()

-- One-shot execution
local response = occode.exec("List files in /home")
print(response)

-- Chat mode
local text = occode.chat("What is 2+2?")
print(text)
```

## Commands

| Command | Description |
|---------|-------------|
| `/help`, `/?` | Show available commands |
| `/model` | View current model |
| `/model <provider/model>` | Switch to gateway model |
| `/model google <model>` | Use Google directly |
| `/model openai <model>` | Use OpenAI directly |
| `/clear` | Clear conversation history |
| `/exit`, `/quit` | Exit oc-code |
| `!<command>` | Execute shell command directly |

## Tools

The agent has access to these tools:

| Tool | Description |
|------|-------------|
| `read_file` | Read file contents with line numbers |
| `write_file` | Create or overwrite a file |
| `edit_file` | Replace exact string in file |
| `list_directory` | List files and directories |
| `glob` | Find files by pattern (e.g., `*.lua`) |
| `grep` | Search file contents |
| `shell` | Execute OpenOS shell commands |

## Display Modes

### TUI Mode (Default)

Requires a Tier 2+ screen (4-bit color depth) and GPU. Features:
- Color-coded output (user, assistant, tools, errors)
- Header bar with hints
- Status bar showing current operation
- Scrolling with PageUp/PageDown
- Command autocomplete popup
- Mouse wheel scrolling

### Terminal Mode

For robots or computers without GPU/screen. Activated automatically when TUI is unavailable, or forced with `-t` flag. Features:
- Simple line-by-line output
- Works on any computer or robot
- Minimal resource usage

## Configuration

### Environment Variables

| Variable | Description |
|----------|-------------|
| `AI_GATEWAY_API_KEY` | For gateway models (`provider/model` format) |
| `GOOGLE_GENERATIVE_AI_API_KEY` | For Google direct (`/model google <model>`) |
| `OPENAI_API_KEY` | For OpenAI direct (`/model openai <model>`) |

### CLAUDE.md

oc-code reads `CLAUDE.md` from the current directory to get project-specific instructions. This is included in the system prompt.

### Skills

Skills are extensible command handlers. Built-in skills:
- `help` - `/help` command
- `model` - `/model` command

Custom skills can be placed in:
- `/usr/lib/oc-code/skills/` - System-wide
- `.oc-code/skills/` - Project-local

## Available Models

### Gateway (via Vercel AI Gateway)

```
anthropic/claude-sonnet-4
anthropic/claude-opus-4
openai/gpt-4o
openai/gpt-4o-mini
google/gemini-2.5-flash
google/gemini-2.5-pro
```

### Direct Providers

Google:
```
/model google gemini-2.5-flash
/model google gemini-2.5-pro
/model google gemini-2.0-flash
```

OpenAI:
```
/model openai gpt-4o
/model openai gpt-4o-mini
/model openai gpt-4-turbo
```

## API Reference

### occode.run(config)

Run interactive session.

```lua
occode.run({
  model = "openai/gpt-4o",
  forceTerminal = false,
})
```

### occode.exec(prompt, config)

Execute a one-shot prompt with tool access.

```lua
local response = occode.exec("Create a hello.lua file", {
  maxSteps = 5,
})
```

### occode.chat(prompt, config)

Send a single message and get a response.

```lua
local text, result = occode.chat("Explain this code", {
  model = "google/gemini-2.5-flash",
})
```

## Examples

### Interactive Session

```
> Create a simple calculator function

>> write_file
   {"path":"calculator.lua","content":"..."}
<< {"success":true,"bytesWritten":245}

Created calculator.lua with add, subtract, multiply, and divide functions.

> Add a power function to it

>> read_file
   {"path":"calculator.lua"}
<< {"content":"..."}

>> edit_file
   {"path":"calculator.lua","old_string":"return calc","new_string":"function calc.power(a, b)\n  return a ^ b\nend\n\nreturn calc"}
<< {"success":true}

Added the power function to calculator.lua.
```

### Shell Commands

```
> !ls -la
drwxr-xr-x  home
drwxr-xr-x  lib
-rw-r--r--  init.lua

> !df
filesystem    used   total
/dev/hdd1     45%    2048k
```
