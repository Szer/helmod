Custom recipe with item ingredient calls missing get_ingredient_quality when Quality is enabled

1. Load `repro.zip`, which contains a custom gear recipe with an iron-plate ingredient.
2. Close Bug Report and the custom-recipe window if visible.
3. Open Custom recipes from the Helmod toolbar. The error recurs while loading the saved recipe list.

From a new game: Open Custom recipes, add an iron gear wheel product and an iron plate ingredient, leave recipe type as recipe, then click Save. The recipe is stored before the UI fails; reopening the editor also fails.

Expected: Saving and reopening an ordinary custom recipe should work with Quality enabled.

Cause: Custom recipes are plain Lua tables from `storage.customized_recipes`. The Quality-enabled constructor calls the `LuaRecipePrototype.get_ingredient_quality` method on that table. The same constructor probe succeeds with Quality disabled.

Recovery: The saved custom recipe remains in storage; closing and reopening the editor does not clear it.
