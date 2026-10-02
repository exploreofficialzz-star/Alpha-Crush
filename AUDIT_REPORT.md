# Alpha Crush 2.0.0 — Audit & Debug Report

Scope: all 81 GDScript files, `project.godot`, `export_presets.cfg`, the 13 JSON data sets, tests and tooling.
Changed files: 52 modified, 10 added (list at the bottom).

## How this was verified (read this first)
No Godot editor/runtime exists in the audit environment, so **nothing here was run in the engine**.
Every finding below was found by reading the code and confirmed with engine-free tooling:

* `tools/gdlint/` (new, also run by `tests/source_audit.py`) — static checks for undefined functions,
  `:=` inferred from a Variant, redeclared locals, missing return paths, and unknown members / wrong
  argument counts / wrong signal arity on project classes. Each check was proven by planting the
  original defect in a scratch copy and confirming it is reported.
* JSON/data cross-checks (ids in code vs `items.json`, `economy.json`, `words.json`, `regions.json`, …).
* A numeric check of the terrain triangle winding using Godot's own plane-normal formula.

First thing to do on your machine: `godot --headless --path . --import`, then
`godot --headless --path . --script res://tests/run_tests.gd`, then play a full run.

## A. Project would not open or compile
| # | File | Problem | Fix |
|---|------|---------|-----|
| 1 | `project.godot` | No `config_version=5`, so Godot 4 treats it as a Godot 3 project. Also an invalid `[android]` section. | Added `config_version=5`; removed the section (identity/version already live in `export_presets.cfg`). |
| 2 | `gameplay/inventory.gd` | Called `_is_currency()` which does not exist → script fails to compile; almost every system depends on `Inventory`. | Defined the helper (`CURRENCY_IDS`). |
| 3 | `save_system`, `daily_manager`, `live_event_manager`, `seeded_generator`, `weather_manager`, `marketplace_manager`, `camera_drag`, `player`, `test_inventory` | `:=` initialised from a Variant (`_read_json()`, `Dictionary.get()`, `abs()`, `min()`, untyped array element, un-cast `event.position`) → "Cannot infer the type". | Explicit types / typed helpers (`absi`, `minf`, `Array[String]`, `as InputEventScreenDrag`). |
| 4 | `export_presets.cfg` | `.aab` target without the Gradle flags AAB export needs. | Added them; tests/docs/tools excluded from shipped builds. |

## B. Gameplay-breaking
| # | Area | Problem | Fix |
|---|------|---------|-----|
| 5 | Campaign | **Finale could never unlock**: it required the TOGETHER chapter, but TOGETHER can only start after the finale unlocks. | Unlock depends on the 11 story chapters; TOGETHER is the finale word. Order-independent progress, self-heals affected saves. `OPEN` now counts for the Market chapter. |
| 6 | Terrain (`chunk_streamer`) | Triangle winding faced **down**: procedural terrain was invisible from above and had no collision from above (falling through the world beyond the 240 m start slab). | Reversed winding, `backface_collision = true`. |
| 7 | Player | Movement used world axes (not camera-relative), the camera pivot inherited body rotation, drag sensitivity was 0.02°/px, no desktop camera control, spawn wrote `global_position` before entering the tree. | Camera-relative movement, independent camera rig, 0.22°/px, right-mouse orbit on desktop, local spawn position, freefall safety net, drop-in-front, working limb animation. |
| 8 | Touch joystick | Subtracted `global_position` from an already-local event position → wrong stick offset. | Use local coordinates. |
| 9 | Persistence | Ad **consent** and **purchase entitlements** were restored but never written. | Saved in `_save()`. |
| 10 | Persistence | JSON turns ints into floats; `migrate()` treated that as a type mismatch and **reset the BASKET capacity bonus on every load**. | Numbers are type-compatible; ints restored as ints. |
| 11 | Economy | `ore` had no price: selling destroyed the stack for 0 coins, market order #7 was impossible, and nothing in the world yields ore. | Price added; unpriced items are never sold; ore deposits appear once the cave lantern is lit. |
| 12 | Purchases | Consumable packs were stored as permanent entitlements. | Only non-consumables are entitlements. |
| 13 | HUD | I / M / H / Esc were registered but never handled; settings & crafting rows leaked (deferred `queue_free` + duplicate names); the close button sat partly off-screen. | Shortcuts wired, rows removed synchronously, layout fixed. |
| 14 | Harvesting | Fruit stayed visible while regrowing. | Hidden until harvestable. |
| 15 | `ObjectPool` | A freshly created node was tracked as both free and active → same node handed out twice. | Fixed; double-release safe. |

## C. Robustness / engine correctness
* `WorldAuthority` read `multiplayer` on a node outside the tree (null → crash in its own test); host emitted world changes twice (local + `call_local`). New `NetworkStatus` helper (also handles Godot's default offline peer).
* `Vector2i.distance_squared_to` (version-sensitive) replaced; identifiers that shadowed engine members/globals (`seed`, `position`, `scale`, `name`, `min`/`max`/`clamp` Variant calls) renamed or typed.
* NPC movement moved to `_physics_process`; remote avatars interpolate yaw with `lerp_angle`; burst particles get a visible unshaded material and `one_shot`.

## D. Tests & tooling
* Three suites (`campaign`, `postgame`, `market_order_board`) existed but were non-static and unregistered; rewritten and registered. The old campaign test asserted the deadlocked behaviour.
* Stale `SAVE_VERSION == 10` assertions fixed; regression tests added (JSON int/float, finale order, OPEN alias, object pool, weather, consumables, currency slots, harvest visuals).
* `tests/source_audit.py` had *encoded* the invalid project settings; it now checks `config_version`, release metadata in the right files, suite registration, and runs gdlint.

## Deliberately left as-is (not bugs, or design decisions for you)
* `flower` has no in-world source, so the `seed_bundle` recipe stays locked. `items.json` stack limits are not enforced. Live events never recur after they expire. "Sell" at the market sells every sellable stack, including partial stock for the active order.
* AdMob / Play Billing / backend multiplayer remain stubs, as the original status docs already state.
* Version numbers unchanged (2.0.0, code 14).

## Residual risk
Static analysis cannot prove runtime behaviour (physics feel, visuals, performance, networking). 53 `:=`
initialisers depend on engine property types that gdlint cannot see (`get_node_or_null()`, `size * 0.5`, `global_position` maths, …);
I checked each by hand against the engine's documented types, and the first headless import will confirm.

## Files
Modified: `project.godot`, `export_presets.cfg`, `core/main.gd`, `core/services/save_system.gd`, `core/pooling/object_pool.gd`,
`data/economy/economy.json`, `economy/currencies/economy_manager.gd`, `economy/purchases/purchase_service.gd`,
`gameplay/{campaign/campaign_manager,crafting/crafting_manager,daily/daily_manager,hints/hint_manager,inventory,live_events/live_event_manager,map/map_manager,marketplace/marketplace_manager,opportunities/opportunity_manager,progression/progression_manager}.gd`,
`multiplayer/authority/world_authority.gd`, `multiplayer/session/multiplayer_avatar.gd`, `performance/profiler.gd`,
`player/player.gd`, `player/npc/npc_agent.gd`, `ui/hud.gd`, `ui/map/map_view.gd`, `ui/mobile/{camera_drag,virtual_joystick}.gd`,
`vfx/vfx_manager.gd`, `words/assembly/word_assembly.gd`, `words/letters/letter_object.gd`,
`world/world.gd`, `world/generation/{chunk_streamer,seeded_generator}.gd`, `world/harvesting/harvest_node.gd`,
`world/simulation/animal_agent.gd`, `world/weather/weather_manager.gd`, `tests/*` (see above), docs.
Added: `multiplayer/network_status.gd`, `tests/unit/test_object_pool.gd`, `tests/unit/test_weather_manager.gd`, `tools/gdlint/*`.
