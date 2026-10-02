# Build and verification toolchain

## Required to verify the game in-engine
- Godot Engine **4.7.2 stable** with matching export templates.
- Python 3 for the repository source audit.

## Required for Android/Google Play release
- Android export templates, supported JDK, Android SDK/build tools.
- The correct upload keystore and passwords stored outside the repository.
- Access to the existing Google Play app and Play App Signing configuration.
- Official AdMob and Google Play Billing Godot plugins/SDK integration, plus their configured IDs.
- A hosted multiplayer backend if internet matchmaking/authoritative inventory and pickup validation are required; current networking is LAN ENet.

## Commands
Run from the project root:

```bash
python3 tests/source_audit.py
godot --headless --path . --script res://tests/run_tests.gd
```

The first command performs a source/resource/data audit. The second must be run with the real Godot executable; it has **not** been executed in the current environment because Godot is unavailable here.

Export the Android internal-testing bundle from Godot's Project → Export UI using `export_presets.cfg`. The preset targets `build/alpha_crush_internal.aab`. Do not treat an exported bundle as ready for Play until signing, package/version continuity, purchase/consent flows, and device QA have passed.

Never place production signing passwords or private keys in this repository or its archives.
