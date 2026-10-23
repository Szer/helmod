Empty Recipe Explorer: Generate block dereferences nil block

1. Load `repro.zip`.
2. In the empty Recipe Explorer, click the gear button (Generate block) without selecting a recipe.

From a new game: Open Helmod, create a sheet, open Recipe Explorer (magnifying glass), then click Generate block before selecting any recipe.

Expected: The button should be disabled or leave the empty explorer unchanged.

Cause: `generateBlock` returns nil for an empty exploration tree, but the handler immediately reads `block.id`.

Recovery: Select a recipe before generating a block.
