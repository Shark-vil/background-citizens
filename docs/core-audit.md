# Core engineering audit

Local changes against `dev` at `cde2f701` (2.5.1, 2026-11-14); publication is not verified.
Legacy was read as a historical reference and remains unchanged.

## Scope and decisions

The review followed the [load sequence and module map](architecture.md): core services and public/compatibility
APIs, actor components and both bodies, FSM/GOAP, navigation providers and route IO, population/vehicles,
wanted/arrest, perception and team reactions, medics/corpses, siege/doors, scenic/carry/ghost systems,
optional integrations, client rendering, debug tools and settings/spawn menus. GLua parsing covers the entire
current core. Behavioral regression checks concentrate on the changed paths; this is not evidence that every
map, engine callback or optional addon combination has been exercised.

Legacy's useful lessons are direct operations, small event handlers and explicit configuration. Its large
actor base, repeated registry scans and dependence on SLibrary are not restoration targets. The current
Actor → brain → body split, navigation providers, shared task budget and compatibility aliases remain.
The body adapters have distinct engine responsibilities; the registries and old aliases have external users.
Absence of a direct internal caller was not used as grounds to delete public APIs.

## Confirmed fixes

| Area | Problem and correction |
|---|---|
| Mechanics | Lua's `and/or` selection discarded explicit `false`. Boolean overrides now survive. The duplicate iNPC init hook is removed; actor initialization/rebind owns its flag. |
| Recurring services | Door passage, player observation and ambient coughs returned after one pass. Explicit loops now keep them alive, including an initially empty server. Looking away resets continuous observation. |
| Scheduler | Tasks changed the live order during iteration, skipping/repeating work. Each tick visits a snapshot of IDs once; new IDs start next tick, removals take effect immediately; replacing an existing ID can run its new task in the same tick. |
| Identity/lifetime | UID allocation and snapshot sequences restarted on Lua reload. The allocator persists and supplies sync sequences too. Client retirement marks the actor removed before delayed initialization can register it again; server entity removal stops its actor/brain. String UIDs get a numeric LOD phase without changing their identity. |
| Navigation | Empty random queries could fail or fall back outside the requested graph radius. They now return nil. NavMesh sampling indexes the actual area list, independent of area IDs. Reload navigation after editing the mesh externally. |
| GOAP | Counting unsatisfied facts overestimated the cost when one action changes several facts. The lower bound is now one action; goal conditions distinguish cache entries, and action registration invalidates cached plans. The 200-iteration search limit remains. |
| Spawning | Skin/bodygroup selection included invalid upper indices; the applied skin could differ from the hook-approved value. Indices are zero-based and the approved value is applied once. Player-owned menu/Tool spawns now respect the gamemode spawn hooks and ownership/counting; automatic population retains its existing rules. |
| Configuration | Spawnmenu read/decompressed `custom.dat` on every entity creation. It now loads at initialization/reload, invalidates resolved actor config after updates, and drops disconnected players' defaults. |
| Regeneration/client | Regeneration honors the configured interval/ceiling without reducing excess health. Client seat downloads use the active local tool, not a nonexistent server sender. Language sync sends only the language code. |
| Network | Invalid string/count fields, excessive nesting and inconsistent fragments are rejected. Client buffering/decompression is bounded; transfer/wait IDs persist across reloads. See the transport contract below. |

Small removals include unused radius calculations, an unused entity lookup, GOAP's invalid bit-count heuristic,
the duplicate iNPC hook, duplicate registry reset code and a second copy of the idle sequence list.
The object scan no longer yields twice per candidate: it yields only when the shared budget is spent, retaining its
100-unit radius and one forward trace. It rechecks the body after event callbacks that may remove/rebind it.
These changes remove demonstrable work; no FPS or percentage speedup is claimed.

## Transport contract

`bgNPC.Net` retains its message names, wire encoding, admin gates and nil argument handling. Both realms
reject table nesting beyond 64 levels; callbacks accept at most 256 arguments. Chunk headers must agree on message name, compression and total;
each part is at most 60,000 bytes and its index/length must match the packet.

SERVER accepts at most eight incomplete transfers and 8 MiB of buffered fragments per client, and at most
32 MiB after decompression per message, with at most 100,000 decoded values (including table keys/values).
`Net.Deserialize(data, value_limit)` also accepts an optional value budget for direct callers.
Partial transfers expire after 30 seconds, checked every five seconds;
duplicate fragments do not extend this lifetime. The existing 100 packets/s client limit remains.
These caps do not limit server-to-client route packs. Custom callers uploading larger data need to split it
into separate messages. Invalid payloads are never passed to a registered callback.

Engine references: [NavMesh area list](https://wiki.facepunch.com/gmod/navmesh.GetAllNavAreas),
[skin count](https://wiki.facepunch.com/gmod/Entity:SkinCount),
[bounded decompression](https://wiki.facepunch.com/gmod/util.Decompress).
Manual-spawn integration also follows the installed Sandbox `gamemode/player.lua` and `commands.lua`.

## Verification and remaining limits

`python tools/test_core_audit.py` runs isolated copies of the real modules through LuaJIT/lupa; the assertions
live in `lua/background_npcs_core/tests/sv_engineering_audit.lua`. `--baseline` runs those checks against
the starting `dev` source without changing the working tree. The same Lua file is available through
SERVER `bgn_selftest`; it creates no live game entities. The offline harness isolates the actual spawn factory
from unrelated GLua `continue` helpers; GLua syntax is checked separately with `glualint dump-ast`.
For the object scan, unused `continue` paths are translated for LuaJIT; the checked valid-object and
callback-removal paths run unchanged.
See [testing](systems/testing.md) for the other checks.

The final offline run passed all 15 audit cases, the existing regression, actor LOD/debug, animator, carry,
scenic, police-force and gang-skin checks, and seven build tests. The existing regression fixtures were
updated for current witness/confirmed-damage, selected-enemy and actor-retirement contracts; production
checks were not weakened to satisfy old fixtures. The complete current core and changed Tool passed GLua
parsing, documentation passed strict EN/RU MkDocs build, and `git diff --check` passed.

No native game session was running for this audit. Multiplayer permissions/replication, actual NPC/NextBot
movement and collision, door/vehicle physics and optional-addon combinations still need native verification.
Script reload recreates class definitions while existing objects can retain old metatables and runtime
references; updating every active action safely is outside these local fixes. Use a map restart for a clean
body/brain validation. Externally changing GOAP action objects directly still requires `GOAP.ClearCache()`.

The audit does not replace existing state machines, remove features, alter default ConVar values or rewrite
users' route/configuration files. The new player-owner argument is optional; existing server spawn calls keep
their behavior. No game saves, generated site files or Legacy sources are part of the changes.

## Independent recheck after d774aeb4

The two audit commits were checked against `cde2f701`, including their callers and test fixtures.
The mechanics/UID/client-retirement fixes, recurring loops, random navigation, GOAP lower bound/cache,
spawn permission and appearance changes, config IO, serialization bounds, seat receiver and language
argument fixes remain justified. `Table.Shuffle` already copies its input; `ResetStorage` resets exactly
the same five registries. Neither removal needs reverting. NPC/NextBot adapters and FSM/GOAP boundaries
remain unchanged. Legacy still contains the constant-first regeneration expressions; its code is a reference,
not evidence of correctness under the current seated-character contract.

The previous lifetime verification was incomplete. A living seated Actor can have a NULL engine body.
Regeneration, ambient voices and foreign NPC disposition polling still assumed otherwise. The object scan
also replaced a necessary `IsValid` check after yielding with `IsAlive`, introducing a regression. These
services now validate the body before engine access; the scan also validates it after budget yields.
The actor is retained for the existing vehicle recovery path. Four isolated tests cover these boundaries,
service continuation and return to normal operation; the three coroutine cases failed before correction.
Earlier mocks often made `IsAlive` track entity validity, masking this distinction.

Performance conclusions are limited: removing per-entity disk reads and duplicate copies removes work;
replacing two yields per candidate reduces scan latency, not necessarily CPU time per second. More frequent
completed scans can increase throughput and CPU usage. The shared budget remains cooperative. The admissible
GOAP heuristic corrects plan cost ordering but can explore more states within the unchanged 200-state cap.
The scheduler snapshot trades one small allocation per tick for safe iteration; it was a correctness fix.
No native frame-time improvement is established by these tests.

Recheck validation: 21 audit cases, existing regression/LOD/debug/animation/carry/scenic/police/gang tests,
seven build tests, full current-core GLua parsing, strict bilingual documentation build and diff checks.
A running game was unavailable; native physics, multiplayer and optional-addon combinations remain unverified.
