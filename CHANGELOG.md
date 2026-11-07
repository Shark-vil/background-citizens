# Changelog

Work log of the core rewrite (`refactor/core-rewrite`). See `REWRITE_PLAN.md` for stages.

## 2026-11-07

- STARTED: Stage 0 — preparation (plan, changelog, lint, self-test).
- DONE: `REWRITE_PLAN.md`, `CHANGELOG.md` created.
- DONE: Stage 0 — `glualint` baseline (9 warnings, no errors). Self-test command moved into Stage 1 core.
- STARTED: Stage 1 — core layer, slib removal.
- DONE (code): Stage 1 core in `lua/background_npcs_core/core/`:
  `sh_class` (OOP), `sh_net` (own serializer, compression, chunking, admin/rate checks, tool RPC),
  `sh_tasks` (coroutines), `sh_cvars` (admin-synced settings), `sh_commands`, `sh_player_ready`
  (`BGN_PlayerReady` hook), `sh_util` + `bgNPC.Table`, `sh_spatial_grid` (O(1) chunk lookup instead of
  a linear scan), `sh_animator`, `sh_selftest` (`bgn_selftest` / `bgn_selftest_cl`).
- DONE (code): new entry point `lua/autorun/background_npcs.lua` -> `background_npcs_core/sh_init.lua`;
  slib autoloader and "slib missing" screen removed. All 116 files ported, no slib/snet/scvar/scommand/async/sgui left.
- DONE: `bgn_fakeplayer` entity (copy of the Decent Vehicle fake player) for the Police System integration.
- REMOVED: `bgn_save_map` (saving nodes into a dupe file; it depended on slib overriding the sandbox duplicator).
- REMOVED: survey module (`sh_poll.lua`), by request.
- FIXED: seat tool "save" never reached the server (client called a server-only send).
- FIXED: `dance` state update used an undefined `data` variable.
- FIXED: version checker / client ready hooks ran for every admin that joined, not only for the local player.
- FIXED: `modules/sv_inpc.lua` was included but never committed; restored the iNPC integration: actors get `inpcIgnore`, so iNPC does not take over their AI.
- FIXED: `bgNPC.States.Register` required callbacks, breaking the marker state `scenic_npc`; callbacks are optional now.
- PENDING: Stage 1 in-game verification.
