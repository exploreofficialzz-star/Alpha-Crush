# Alpha Crush test runner

Run the source audit with Python. It needs no engine and now also runs the engine-free static
checks in `tools/gdlint` (undefined functions, `:=` inferred from Variant, redeclared locals, missing
return paths, wrong member names / argument counts / signal arity on project classes):

```bash
python3 tests/source_audit.py          # everything
python3 tools/gdlint/run_all.py        # static checks only (add --verbose to list unprovable `:=`)
```

Run the included suite runner once the Godot 4.7.x executable is available. The suites use the
project's `class_name` types, which Godot only registers after the project has been imported once,
so run the import first (a fresh clone has no `.godot/` cache yet):

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
```

The runner registers 23 suites. It covers inventory stack capacity, word duplicate handling, save schema/migration, daily objectives, persistent world state, economy transactions, transactional crafting, world clock restoration, achievement rewards, deterministic chunk seeds, the
campaign finale unlock, postgame challenges, market orders, object pooling, weather, and purchase entitlements.

Release validation must additionally cover network interruption, purchase interruption, ad unavailability, corrupted saves, missing letters, duplicate letters, disconnected chunks, and Android device profiling.
