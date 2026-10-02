# Alpha Crush Test Plan

## Automated source tests
- Inventory stack capacity and currency slots
- Word validation, duplicate-letter handling, and completion
- Save schema and migration to the current version (including JSON int/float round-trips)
- Campaign finale unlock order, postgame challenges, and market orders
- Object pooling, weather, purchase entitlements, and world-authority validation
- Daily objective completion
- Persistent world state and object properties
- Economy sell transactions
- Seeded chunk determinism

## Runtime integration tests required
- LADDER world consequence and restored gate state
- ORANGE harvest availability and save/restore
- BASKET inventory capacity upgrade
- MARKET sale and coin persistence
- Upgrade visuals across app restart
- Corrupted save backup recovery
- App pause/resume and autosave
- Network interruption and authority rejection
- Purchase interruption and receipt verification
- Ad unavailability and consent restrictions
- Disconnected chunks and high-speed traversal
- Android device FPS, thermal, battery, memory, and input latency
