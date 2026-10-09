# Alpha Crush — Godot 4.x Production Build

**Core identity: WORDS CHANGE THE WORLD.**

This is an actively constructed Godot project following `ALPHA_CRUSH_MASTER_GODOT_BUILD_PROMPT.txt` as the source of truth.

## Current architecture

- `core/` — bootstrap, configuration, services, save system
- `player/` — human third-person controller
- `world/` — world state, deterministic chunk streaming, regions, weather
- `words/` — word database, physical letters, assembly
- `gameplay/` — discovery, harvesting, crafting, marketplace, progression
- `economy/` — currencies and purchase boundaries
- `multiplayer/` — ENet networking and world-authority boundary
- `ads/` — AdMob integration boundary + consent
- `analytics/` — event collection boundary
- `mobile/` — scalable quality levels
- `ui/` — mobile HUD, contextual actions, inventory/map/daily/workshop/settings panels
- `assets/` — generated original SVG UI/letter/character reference assets and procedural 3D construction
- `audio/` — generated original SFX and looping music
- `data/` — deterministic content definitions
- `tests/` — source-ready unit/integration test coverage

## Playable progression currently wired

HOME → EXPLORE → ELEVATED GARDEN → LADDER → ORANGE → HARVEST → BASKET → MARKET → SELL → UPGRADE → NEXT DISCOVERY.

Additional discoverable situations are playable in the starter world: a blocked river path (BRIDGE), broken footbridge (REPAIR), empty field (SEEDS), broken workshop (TOOLS), dark cave (LANTERN), damaged boat (ENGINE), locked storage (KEY), closed market (OPEN), closed dock (BOAT), old meadow gate (GATE), and dark beacon (LIGHT). Per-word progress is retained when the player investigates another situation, and the garden interaction resumes the next unfinished garden stage. Outside the hand-authored starter village, deterministic streamed region chunks generate heightfield terrain, collision, and region-specific props.

## Verification boundary

The current environment has no Godot editor/runtime or Android SDK. Therefore this repository does **not** claim successful engine compilation, Android export, physical-device profiling, Play App Signing, live AdMob/IAP, or backend multiplayer validation. Those require the corresponding toolchain and credentials.


The repository also includes canonical monetization configuration, explicit ad-consent persistence, store/restore controls, reward verification boundaries, original procedural music loops, persistent player profile/customization data, a multi-opportunity registry, a Settings & Accessibility panel, LAN multiplayer host/join/leave controls, and persisted inventory capacity and resource refresh state.

## 2.1.0 — Realism pass
The world, human avatar, animals, sky and soundscape were rebuilt on a procedural PBR art pipeline.
See `ASSET_PIPELINE.md` (what is generated, how to regenerate, honest limits) and `docs/previews/` (offline renders).
First run on a fresh clone: `godot --headless --path . --import`, then open the project.
