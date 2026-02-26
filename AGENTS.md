# AGENTS.md

This repository is a Minecraft OpenComputers development workspace.
The working directory is the OpenComputers save path and the code runs
inside the OpenComputers Lua runtime (OC Lua 5.2-ish environment).

Environment (Minecraft OpenComputers)
- Code lives under the OpenComputers filesystem (e.g. lib/, bin/, home/).
- Runtime uses OpenComputers APIs (component, internet, filesystem, etc.).
- Standard Lua + OpenComputers libraries; no external package manager.
- Use an internet card for network requests in-game.

Repository layout (high level)
- lib/: core libraries and custom modules (Lua).
- lib/ai/: AI SDK-style wrapper for OpenComputers.
- lib/json.lua: JSON codec used by network clients.
- docs/: AI SDK reference docs (mdx).

Cursor/Copilot rules
- No .cursor/rules/ or .cursorrules found.
- No .github/copilot-instructions.md found.

Build / lint / test commands
- No build system detected (no package.json, makefile, or CI scripts).
- No lint commands detected.
- No automated test runner detected.

Single-test guidance
- There is no test framework in this repo.
- If you add tests in the future, document the exact command here.

How to run code in OpenComputers
- Use the in-game shell to run Lua programs (e.g. `lua myscript.lua`).
- Demo scripts live in `lib/ai/demo/`.
- Example: run `lib/ai/demo/generateText.lua`

Code style guidelines (Lua)
- Use 2-space indentation; follow existing lib/ style.
- Prefer local variables and local helper functions.
- Avoid global variables; return module tables from files.
- Require modules with `require("module")` and keep them at top.
- Keep functions small and focused; split helpers when logic grows.
- Use explicit nil checks (e.g. `if value ~= nil then`).
- Use `type(...)` checks for public API arguments.
- Prefer tables with named keys for structured options.

Imports and module structure
- Each module returns a table of public functions.
- Internal helpers should be `local function`.
- Require only what you use (e.g. `local json = require("json")`).
- Keep module names stable; OpenComputers uses filesystem layout.

Formatting
- Use double quotes for string literals in new code.
- Keep lines reasonably short; wrap long argument lists across lines.
- Align table fields vertically only when it improves readability.
- Use trailing commas only when it improves diff clarity.

Naming conventions
- Functions: lower_snake_case or lowerCamelCase; stay consistent per file.
- Variables: lower_snake_case; use descriptive names.
- Constants: UPPER_SNAKE_CASE only when truly constant.
- Module tables: short, lowercase (e.g. `ai`, `internet`).

Error handling
- Use `error("message")` with clear user-facing messages.
- Validate required options early and fail fast.
- Prefer `pcall` when decoding/parsing external data.
- When wrapping external APIs, surface provider errors clearly.

Networking
- Use `require("internet")` for HTTP requests.
- Always send `Content-Type: application/json` for JSON bodies.
- Include `Authorization: Bearer <key>` when required.

JSON handling
- Use `lib/json.lua` for encode/decode.
- Wrap decode with `pcall` and emit a friendly error.
- Preserve raw response bodies where helpful for debugging.

AI SDK wrapper expectations
- Functions should mirror AI SDK naming and return shape when possible.
- `generateText` is synchronous and returns an object with `text` and metadata.
- Provide a stable API even if some fields are `nil` in OC.

OpenComputers specifics
- Avoid Lua features not supported by OC's Lua version.
- Use `os.time()` for timestamps if needed.
- Assume limited memory; avoid large intermediate buffers where possible.

Documentation
- Reference `docs/` for AI SDK behavior and naming.
- Keep demos minimal and runnable in-game.
- Update AGENTS.md if you add a new build/test workflow.

Security / secrets
- Do not hardcode real API keys in committed files.
- Demo config uses placeholder keys; replace locally as needed.
- Avoid printing secrets unless explicitly requested.

Change management
- Keep edits scoped to the requested behavior.
- Avoid reformatting unrelated files.
- Preserve user modifications unless requested otherwise.

Common tasks checklist
- Confirm which file to edit before changes.
- Read relevant files and existing patterns first.
- Validate new APIs with simple demo scripts.
- Note any environment assumptions in the response.

Notes for future agents
- This repo is not a typical software project; it is a Minecraft OC filesystem.
- Paths are Windows host paths, but code runs inside OpenComputers.
- Use OpenComputers APIs, not OS-level Lua libraries.
