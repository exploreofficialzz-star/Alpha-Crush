# Alpha Crush Agent Milestone 1.8

## Playable core loop
HOME → EXPLORE → GARDEN → LADDER → ORANGE → HARVEST → BASKET → MARKET → SELL → UPGRADE → MORE WORLD OPPORTUNITIES

## World words and physical consequences
- LADDER unlocks the elevated garden and builds a ladder.
- ORANGE activates fruit harvesting.
- BASKET increases inventory capacity.
- MARKET/OPEN unlocks selling and removes the market shutter.
- UPGRADE unlocks a paid garden upgrade blueprint/build.
- REPAIR restores the broken footbridge.
- BRIDGE opens the blocked river path.
- SEEDS activates a harvestable field.
- TOOLS repairs the workshop and enables crafting.
- LANTERN opens the cave entrance and lights it.
- ENGINE repairs the damaged boat.
- KEY unlocks storage and starter materials.
- BOAT opens the river dock route.
- GATE opens the old meadow gate.
- LIGHT lights the beacon.

## 1.8 implementation
- Added deterministic streamed terrain heightfields, region-specific terrain materials, and per-chunk collision meshes outside the authored starter village.
- Persisted stable resource IDs, availability, cooldown, and state transitions.
- Added safe resource-state restoration after world state is rebuilt.
- Added explicit regression coverage for inventory-full harvesting and cooldown restoration.
- Made market, workshop, cave, dock, meadow gate, and beacon consequences visibly persistent.
- Preserved explicit consent and honest store/ad integration boundaries.

## Release identity
- Package: `com.chastechgroup.alphacrush`
- Version name: `1.8.0`
- Android version code: `13`
- Save schema: `10`
- World seed: `482913`

## Verification boundary
Godot 4.7.2 runtime parsing/headless execution, Android AAB export, signing, live AdMob/Play Billing SDK verification, hosted multiplayer backend, and physical Android QA still require the external release toolchain.
