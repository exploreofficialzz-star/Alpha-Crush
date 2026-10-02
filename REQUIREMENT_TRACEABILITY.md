# Alpha Crush — Master Build Order Traceability

This table follows the 20-phase build order in `ALPHA_CRUSH_MASTER_GODOT_BUILD_PROMPT.txt`. “Source implemented” means the project contains an implementation; it does **not** mean the Godot runtime, Android export, external SDK, or production service has been verified.

| Phase | Master requirement | Current state | Remaining proof/work |
|---|---|---|---|
| 1 | Project foundation | **Source implemented** — Godot 4.x project, configuration, services, folders, data, export preset | Godot 4.7.2 parser/import/runtime run |
| 2 | Player movement + camera + interaction | **Source implemented** — human third-person controller, keyboard/touch movement, jump/sprint, interact/drop, camera sensitivity | Device touch feel, camera clipping, movement/collision QA |
| 3 | World chunk architecture | **Source implemented** — seeded streamed chunks, terrain heightfields, collision meshes, chunk load budget | Long-session streaming soak, seams, memory, mobile frame-time QA |
| 4 | First environment and human characters | **Partial** — procedural human player/NPCs, roles, dialogue, generated art families | Production character models/animation polish and visual QA on device |
| 5 | Letter system | **Source implemented** — physical 3D letters, pickup/drop/carry, stable IDs, saved-letter reconstruction | Godot runtime input/physics verification |
| 6 | Word assembly | **Source implemented** — duplicate-letter counting, progress, assembly presentation, completion routing | Playtest clarity/usability and runtime tests |
| 7 | World consequence system | **Source implemented** — all catalog words map to visible consequences; world-state authority path | Multiplayer exploit testing and runtime verification |
| 8 | Harvesting and inventory | **Source implemented** — stack capacity, currency exemption, harvesting, cooldown/resource-state persistence, full-inventory rejection | Runtime tests, balancing, device interaction QA |
| 9 | Marketplace/economy | **Source implemented** — selling, currency, upgrade costs, transactional crafting support | Economy balancing and purchase loop playtests |
| 10 | World progression | **Source implemented** — LADDER → ORANGE → BASKET → MARKET/OPEN → UPGRADE plus optional world opportunities | Full playthrough and softlock QA in Godot |
| 11 | Procedural generation | **Partial** — deterministic regions, terrain, region props, physical letter placement | Expand content variety/biomes and validate large-world performance |
| 12 | Persistence | **Source implemented** — atomic save, backup recovery, schema v10 migrations, world/word/harvest/settings/profile/consent/entitlement snapshots | Run migration and recovery tests in Godot; validate real legacy production save formats |
| 13 | Multiplayer | **Partial** — LAN ENet host/join, avatar snapshots, 20 Hz transform updates, allowlisted word completion replication | Server-side pickup/letter proof, backend identity/matchmaking, NAT traversal, latency/cheat/device QA |
| 14 | Ads | **Partial** — consent choices/persistence, AdMob configuration, rewarded-ad verification boundary | Install official SDK/plugin, wire callbacks, test consent and ad behavior on Android |
| 15 | IAP | **Partial** — store UI, product config, entitlement handling, consumable/non-consumable restore logic | Install Google Play Billing plugin, server/store verification, purchase/restore tests on Play tracks |
| 16 | Live events | **Partial** — daily objectives, local live-event modifiers and event data framework | Remote schedule/config service, timezone rollover, reconnect/offline behavior QA |
| 17 | Optimization | **Partial** — chunk budget, quality presets, pooling/profiler architecture, procedural assets | Profile FPS, memory, thermal behavior, battery use and low-end Android devices |
| 18 | QA | **Partial** — source audit passes; 18 unit/integration suites are registered | Godot runtime is absent here, so GDScript suites have not been executed; fix all parser/runtime/test issues in the real engine |
| 19 | Google Play migration testing | **Partial** — package ID/version metadata, AAB export preset, permissions, migration runbook | Verify current production app/package, signing keys, entitlement migration, internal-track update over existing install |
| 20 | Production release | **Not complete** — release configuration exists | Export/sign AAB, verify Play App Signing, upload to internal track, device QA, staged rollout and production validation |

## Definition-of-done playthrough checklist

- [x] Discover a real-world situation in the starter world.
- [x] Reveal its word requirement through physical interaction.
- [x] Find and physically carry letters.
- [x] Assemble the word and apply a visible world consequence.
- [x] Use the result, harvest resources, sell resources, and develop the garden.
- [x] Discover additional opportunities with independent word progress.
- [x] Persist and restore world, word, inventory, settings, profile, consent, and resource cooldown state in source.
- [ ] Execute the complete playthrough in Godot 4.7.2.
- [ ] Save, close, reopen, and verify the same world state in the engine.
- [ ] Play with another human player on real devices.
- [ ] Verify Android AAB, signing, Play migration, ads/IAP and release QA.

The central identity remains **WORDS CHANGE THE WORLD**. Source scaffolding is not treated as proof of production readiness.
