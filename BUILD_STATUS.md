# Alpha Crush — Agent Build Status

This repository is being built systematically from `ALPHA_CRUSH_MASTER_GODOT_BUILD_PROMPT.txt`.

## Current milestone: 2.2.0 / Kid-friendly, low-end-ready release (see RELEASE_2_2_0.md)

Not yet executed in a Godot runtime (none available in the authoring environment): run the editor import, `tests/run_tests.gd`, and the device checklist in RELEASE_2_2_0.md.

### 2.0.0 content arc (still current)

### Implemented in source
- Production-oriented Godot 4.x folder architecture
- Human third-person player, camera, movement, sprint, jump, carry/drop
- Contextual mobile controls with virtual joystick, camera drag, action buttons
- Contextual world prompts rather than a permanent quest-list-first HUD
- Deterministic data-driven word database and metadata
- Physical 3D letter objects with readable silhouettes, idle motion, pickup/drop/carry states, highlights and word assembly presentation
- Deferred word completion so physical pickup completes before world consequences clear carried letters
- Persistent carried-letter reconstruction from saved word progress
- Multi-stage starter world progression: LADDER → ORANGE → BASKET → MARKET → UPGRADE
- Physical harvest availability gating and visible garden upgrade state
- Persistent WorldState with deterministic IDs
- Opportunity registry allowing multiple discovered world problems to coexist
- Seeded chunk streaming with region-specific terrain heightfields/collision and progressive streamed-region map discovery
- Region catalog and 18+ region archetypes
- Inventory with distinct-stack capacity and currency exemption, transactional crafting UI at the workshop, marketplace/economy and progression services
- Discovery, hints, daily objectives, data-driven achievements/rewards, live-event framework, persisted weather and world clock with time-of-day lighting
- Save/load with atomic writes, backup recovery, versioned migration through save version 10, and clean-shutdown session metadata
- Persistent human player profile/customization data and avatar styling
- Per-opportunity word progress so discovering a second world problem preserves carried-letter progress on the first
- Physical empty field, locked storage, damaged boat, broken footbridge, broken workshop, closed dock, old gate, and dark beacon opportunities with SEEDS/KEY/ENGINE/REPAIR/TOOLS/BOAT/GATE/LIGHT consequences
- Persistent crop activation, cave lantern lighting/open entrance, usable boat, unlocked storage, restored footbridge collision, repaired workshop, open dock/meadow gate, and beacon light
- Save restoration occurs before world objective selection; completed world changes are rebuilt after load
- Executable headless test runner and synchronized Android version metadata checks
- Human NPC roles, lightweight routines and contextual dialogue
- Authority-aware world-state replication path for multiplayer
- ENet networking/session/avatar architecture
- Mobile quality presets and performance telemetry architecture
- Pooling/performance architecture
- Canonical AdMob/IAP configuration loaded from data without pretending SDKs are installed
- Analytics abstraction and security/transaction boundary
- Original generated SVG asset families for letters, UI, characters, buildings, props, resources and regions
- Generated cinematic Alpha Crush key art
- Original procedural SFX and music loops
- Source-level automated test coverage for word logic, inventory capacity, save migration, settings, harvest rejection, crafting, world authority, achievements, world clock, world state and seed determinism
- Source audit validating GDScript delimiters, unique class/function names, resource references, word-to-world coverage, release metadata, JSON, SVG, PNG and WAV assets

## Previous implementation pass (1.6.0)
- Added a workshop crafting panel with recipe requirements, craftability state, and immediate inventory feedback.
- Made crafting preflight resulting stack capacity and roll back consumed inputs if output insertion fails.
- Clarified backpack capacity as distinct item stacks; coins and gems do not consume backpack slots.
- Connected world clock and weather to sky/ambient/sun changes, and persisted/restored their state.
- Added six data-driven achievements for word completion, discovery, harvesting, trading, crafting, and distinct region discovery. All event sources are connected; progress, unique region markers, unlock claims, and currency rewards persist.
- Added achievement unlock analytics, player-facing notifications, and unit coverage for achievements, crafting, capacity, and world-clock restoration.
- Added a headless GDScript test runner aggregating unit and integration suites.
- Advanced save schema to v8 and synchronized release metadata to 1.6.0 / Android version code 11.

## Source inventory
- 89 GDScript files + 6 shaders (`visuals/shaders/`)
- 92 generated SVG assets plus the project icon SVG
- 15 original WAV files (SFX and music)
- 1 cinematic key-art PNG
- 13 JSON data sets
- 24 unit/integration test suites registered in the headless test runner
- `tools/gdlint`: engine-free static checker wired into `tests/source_audit.py`

## Realism pass (2.1.0, no engine available)
Procedural PBR art pipeline (`tools/assetgen`, `ASSET_PIPELINE.md`): 56 generated models, 44 textures, 6 shaders, ambience beds,
rebuilt village / terrain / vegetation / avatar / animals / sky. Statically checked (`tests/source_audit.py` now also runs
`tests/asset_audit.py`); **not yet run in the engine**.

## Debug audit pass (2.0.0, no engine available)
A full static audit fixed defects that would have stopped the project from loading, compiling or being
finished. See `AUDIT_REPORT.md` for the itemised list. Highlights: `project.godot` lacked
`config_version=5`; `Inventory` called an undefined function; several `:=` declarations inferred from
Variant; the campaign finale could never unlock; procedural terrain faced downward (invisible, no
collision); consent and purchase entitlements were never saved; the 7th market order demanded an
unobtainable item.

## Verification limitation
The execution environment still does not contain a working Godot editor/runtime or Android SDK. Therefore this repository does **not** claim successful Godot parser/runtime execution, Android AAB export, physical-device profiling, Play App Signing, live AdMob/IAP SDK behavior, or backend-hosted multiplayer validation.

The source is aligned to the current official stable Godot 4.7.2 release, but engine execution remains the next external-toolchain verification step.

## Not honestly marked complete
- Signed Android release AAB
- Play App Signing/upload-key verification
- Legacy Flutter entitlement migration against the live store app
- Production AdMob SDK wiring and Android consent-flow verification
- Google Play Billing SDK wiring and purchase-restore verification on Android
- Backend-hosted authoritative multiplayer service and device-to-device QA
- Physical-device FPS/thermal/memory profiling
- Final animation/audio/art QA on physical Android devices
- Final Google Play internal-testing/update-over-production migration test

## Previous implementation pass (1.7.0)
- Added a player-facing Settings & Accessibility panel for graphics quality, music, SFX, vibration, high contrast, text scaling, and camera sensitivity.
- Added player-facing LAN multiplayer host/join/leave controls, delayed client avatar registration until connection succeeds, late-join avatar snapshots, and 20 Hz transform updates.
- Added an allowlisted world-authority commit boundary that only accepts catalogued word completion states.
- Added regression suites for consent-aware ad rewards and consumable versus non-consumable purchase restore behavior.
- Added server-side word catalog/state validation for world-authority commits; live backend/device multiplayer security validation remains outstanding.
- Connected persisted settings to runtime quality, audio, player camera, and HUD accessibility behavior.
- Persisted inventory capacity and reconstructed the BASKET capacity bonus for legacy saves.
- Fixed full-inventory harvesting so resources are not consumed when the inventory rejects the item.
- Added a visible river strip/ripples and moved the damaged boat to the riverbank.
- Corrected procedural chunk placement to avoid overlapping the authored starter village.
- Added settings persistence and harvest-capacity regression suites.
- Advanced save schema to v9 and Android version code to 12.


## Latest implementation pass (1.8.0)
- Added deterministic streamed terrain heightfields, region-specific terrain materials, and per-chunk collision meshes outside the authored starter village.
- Added stable IDs for harvest nodes and persisted availability/cooldown/resource-state snapshots.
- Added resource state transitions LOCKED → ACTIVE → REFRESHING → ACTIVE and mirrored them into persistent WorldState.
- Added resource harvest regression coverage, including full-inventory rejection and cooldown restoration.
- Completed physical consequences for the remaining catalog words BOAT, GATE, and LIGHT, with save-safe restoration of their world visuals.
- Made the closed market, broken workshop, and dark cave visibly transform when their requirement words are completed.
- Advanced save schema to v10 and Android version code to 13.

## Complete game-content milestone (2.0.0)
- Added a complete 12-chapter world-repair campaign ending in TOGETHER at the Community Hall.
- Added persistent finale state, celebration visuals, completion messaging, and an explicit endless/postgame transition.
- Added a repeatable postgame challenge system with curated word challenges and rewards.
- Added roaming human-world animals (cow, goat, deer, chicken) with lightweight local simulation.
- Added a persistent marketplace order board with rotating orders, event multipliers, fulfillment rewards, and save state.
- Expanded deterministic region generation to all 18 curated region archetypes from the master specification.
- Added region-specific terrain palettes and procedural props for snow, desert, canyon, ruins, industrial, futuristic city, harbor, wetlands, mountain, highlands and beach regions.
- Added regression coverage for campaign completion, postgame challenges, and marketplace orders.
- Added localization entries for the complete campaign/postgame word set.

## Game-content completion definition
The playable game now has a complete beginning-to-finale arc plus repeatable postgame exploration. External SDK, device/export, backend, and release verification are deliberately outside this content-completion definition.
