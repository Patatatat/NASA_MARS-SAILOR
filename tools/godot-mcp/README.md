# Godot MCP local

Source: https://github.com/Coding-Solo/godot-mcp
Revision: `1209744fad78f3998f98c7394fd0f6ef50da5281` (MIT), package version 0.1.1.

The server source lives in `server/`; its compiled output is generated locally.
`.gdignore` excludes this whole directory from Godot's resource import.
No game files or editor plugins are needed.

## Setup after cloning

Install Node.js 18 or newer and pnpm 9 or newer. From the project root:

```powershell
pnpm --dir tools/godot-mcp/server install --frozen-lockfile --ignore-scripts
pnpm --dir tools/godot-mcp/server run build
New-Item -ItemType Directory -Force .codex
Copy-Item tools/godot-mcp/codex-config.toml .codex/config.toml
```

In `.codex/config.toml`, replace the `C:\PATH\TO` placeholders with the
absolute project directory and Godot executable. `node` must be on PATH;
otherwise set `command` to its absolute executable path. This local configuration,
dependencies, build output, and package store are excluded from Git.
Dependencies were installed using bundled pnpm with lifecycle scripts disabled, then TypeScript and `scripts/build.js` were run explicitly. `server/pnpm-lock.yaml` records the resolved dependencies; the local package store is `.pnpm-store/`.

After the workspace was copied to this machine, missing root dependency folders
were restored from the bundled `.pnpm/node_modules` directory, without downloading
packages or running install scripts. The active configuration uses this machine's
Node runtime and Godot executable; `verify.mjs` reads `GODOT_PATH` from that config.

`codex-config.toml` is a portable template for the project `.codex/config.toml`.
Update the configured absolute paths if the project or Godot moves.
Project configuration requires a trusted project.

Verify without running the game:

```powershell
node tools/godot-mcp/verify.mjs
```

This checks MCP initialization, tool enumeration, engine version, and project information. It closes only its own MCP connection. It does not run the editor, modify scenes, or stop existing game instances.

`node tools/godot-mcp/check-playable.mjs` additionally starts the graphical
integration test using `run_project`, captures `get_debug_output`, and writes
screenshots/results under an isolated `.test_playable/mcp-<timestamp>` directory.
It leaves existing Godot sessions alone and lets its test scene exit normally.

Tools include project inspection, scene creation, node insertion, sprite loading, scene saving, game execution and debug output. They do not expose unsaved editor changes, and script edits still use normal file tools. Avoid concurrent writes to the same scene.

Already running agents may need a new session to load the MCP configuration. Leave ongoing jobs alone and initialize a new project chat when convenient.
