# Alpha Crush Agent Milestone 1.7

## Core loop
HOME → EXPLORE → ELEVATED GARDEN → LADDER → ORANGE → HARVEST → BASKET → MARKET → SELL → UPGRADE → EXPLORE NEW OPPORTUNITIES

## World-driven opportunities
- Blocked river path → BRIDGE
- Broken footbridge → REPAIR
- Empty field → SEEDS
- Broken workshop → TOOLS
- Dark cave → LANTERN
- Damaged boat → ENGINE
- Locked storage → KEY
- Closed market → OPEN

## 1.7 implementation
- Added player-facing Settings & Accessibility controls and runtime preference wiring.
- Saved inventory capacity, including migration/reconstruction of the BASKET bonus for older saves.
- Fixed harvest rejection when the backpack is full.
- Added visible river water and reduced procedural scenery overlap with the authored village.
- Added settings, harvesting, ad reward verification, purchase restore, and world-authority regression suites.
- Added explicit ad-consent persistence, store controls, and Android internet/network/vibration permissions.
- Added LAN multiplayer UI with host/join/leave, late-join avatar snapshots, and 20 Hz transform updates.

## Release identity
- Package: `com.chastechgroup.alphacrush`
- Version name: `1.7.0`
- Android version code: `12`
- Save schema: `9`
- World seed: `482913`

## Verification boundary
The project still needs Godot 4.7.2 runtime parsing/headless execution, Android export templates and SDK, signing credentials, production AdMob/IAP SDK verification, authoritative backend deployment, and physical-device QA. These are not claimed as completed.
