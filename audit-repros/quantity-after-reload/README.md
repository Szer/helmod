Saving with product quantity dialog open causes nil input_quantity after reload

1. Load `repro.zip` with the existing product quantity dialog still open.
2. Enter 10 and press Enter without closing/reopening the dialog.

From a new game: Add an iron gear wheel recipe to a sheet and open the output quantity editor. Save the game with that dialog open, exit, reload the save, and confirm a quantity.

Expected: An open quantity editor should continue to work after loading a save, or be closed/rebuilt on load.

Cause: `input_quantity` is a module-local LuaGuiElement reference assigned while building the dialog. The GUI survives in the save, but the local resets to nil. `product-update` reads `.text` before its inner pcall. Confirmed in a fresh Factorio process after save/reload.

Recovery: Close and reopen the quantity dialog before editing.
