# Alpha Crush content pipeline

DESIGN DATA → ASSET → IMPORT → PREFAB/SCENE → REGISTRATION → GENERATION RULE → GAMEPLAY TEST → PERFORMANCE TEST → DEVICE TEST

Words live in `data/words/words.json`.
Resources live in `data/items/items.json`.
Recipes live in `data/recipes/recipes.json`.
Regions live in `data/regions/regions.json`.
Buildings live in `data/buildings/buildings.json`.
Objectives live in `data/objectives/objectives.json`.
Character cosmetics live in `data/characters/cosmetics.json`.
Live events live in `data/events/events.json`.

Adding a word/resource/region is intended to be data-driven rather than
requiring changes to the core word or inventory engines.
