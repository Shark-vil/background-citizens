# Background NPCs: entry point for AI contributors

Read [documentation maintenance rules](docs/ai.md) ([по-русски](docs/ai.ru.md)) before changing documentation or public behavior. Start with [project architecture](docs/architecture.md) and [version history](docs/history.md).

Keep EN/RU pages aligned, preserve existing documentation URLs, and distinguish SERVER, CLIENT and SHARED usage by implementation and synchronization behavior. Update the affected docs with public API/default/behavior changes. Validate documentation with `python -m mkdocs build --strict` and `git diff --check`.

Work only with the current version of the project. The Legacy core (`lua/background_npcs_legacy/`) is obsolete: do not change or analyze it during normal work unless the user explicitly asks.

Keep changes within the user’s task, preserve unrelated work and prefer the smallest complete solution. Do not edit generated `site/` or launch in-game lab fixtures for a docs-only task. State verification limits. A requested local commit does not authorize a push or deployment.

When a task requires a unit test, put it in `lua/background_npcs_core/tests/` (file name prefixed by realm: `sh_`, `sv_`, `cl_`), never in production code.

## Skills

- **Ponytail**: use by default when writing, changing, refactoring or debugging code. Build the minimal sufficient implementation, reuse existing code, add no extra architecture.
- **Universal Modder**: use when researching game engines, APIs or resource formats, building non-standard game mechanics, integrating mods or testing in game.
- **Both**: when a task needs game research and code, apply both skills.
- **Be selective**: skip Universal Modder stages a simple task does not need. Do not complicate a solution to follow a formal process.
