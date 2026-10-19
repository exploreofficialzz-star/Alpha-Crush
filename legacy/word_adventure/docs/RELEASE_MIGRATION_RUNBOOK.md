# Alpha Crush — release and Play migration runbook

Source-of-truth constraints from the master build specification:

1. Preserve package/application ID: `com.chastechgroup.alphacrush`.
2. The master specification referenced legacy version `1.1.0+6` and project target `1.3.0+8` when it was authored. This local source build has since advanced to `1.8.0+13`; verify the actual live Play track and installed production app before any upload.
3. Do not create or expose a replacement release/upload signing identity.
4. Before production upload, locate the existing Play App Signing configuration and the correct upload keystore.
5. Build a signed AAB with the production signing setup.
6. Test upgrade installation over the live application during internal testing.
7. Verify save/account entitlement migration before release.

The local source tree deliberately leaves release keystore fields empty.
That is intentional until the real signing configuration is supplied by the
release environment.


## Multiplayer source scaffold
The local ENet session UI hosts on UDP port `24560` and lets a player enter a LAN host address. This is not a hosted internet matchmaking service; device-to-device NAT traversal, backend identity, abuse prevention, authoritative pickup validation, and real-device network QA remain release work.
