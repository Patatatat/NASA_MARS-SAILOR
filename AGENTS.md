# Godot MCP

This Godot project's root is the directory containing this file and `project.godot`.
The local `godot` MCP server is installed in `tools/godot-mcp/server` and configured in `.codex/config.toml`.
See `tools/godot-mcp/README.md` for setup and verification.

Prefer MCP tools for engine version, project inspection, scene operations, and debug output when available. Use normal file tools for GDScript edits and review.
Before changing scenes or scripts, inspect their current contents and preserve ongoing work. Do not launch duplicate editors, stop existing Godot sessions, or resave all project UIDs as part of setup/inspection. Coordinate ownership of files before concurrent edits.
The MCP server runs separate Godot processes; it does not inspect unsaved changes in an existing editor. Debug output belongs to the game process started by that MCP server.
If MCP is not loaded in the current chat, report that accurately; use a newly initialized project session after current work finishes. Do not restart running agents to activate it.
