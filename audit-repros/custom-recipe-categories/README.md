Saving a custom recipe without item ingredients passes nil categories to pairs

1. Load `repro.zip`.
2. Close Bug Report and the custom-recipe window if visible.
3. Open Custom recipes and select the saved gear recipe in the top row.

From a new game: Open Custom recipes, add an iron gear wheel product, leave the ingredients empty and the type as recipe, then click Save. The error occurs in the machine list. Selecting the saved recipe after reopening reproduces it.

Expected: Custom recipes should provide a valid category list, or the editor should validate an incomplete recipe before storing it.

Cause: `getAllCategories` returns `.categories` for every object whose type is recipe. Custom recipes store the singular `.category` instead. `getAllowedMachines` then iterates nil at line 123. This path is independent of the missing Quality method: the repro has no item ingredients.

Recovery: The custom editor can reopen, but selecting the saved recipe triggers the error again.
