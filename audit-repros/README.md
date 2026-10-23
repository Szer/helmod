Reproduction assets for original Helmod experimental b5627929370a5e452d1879de2160906809c9ba19, reported as Helmod 2.3.6, on Factorio 2.1.23 with the bundled Space Age, Quality, Elevated Rails and Recycler mods.

Install the included `helmod_2.3.6.zip` in an isolated mod directory, enable the bundled expansion mods, and load a case's `repro.zip` in single-player. Follow that case's README. The packaged Helmod source matches the baseline exactly and contains no orbit-planning changes or capture harness.

Each case directory contains a save, an actual graphical Factorio screenshot, its error text and the GUI-event case used to reproduce it. The custom-recipe and blank-rule saves contain the persisted problem; the other saves are immediately before the triggering action.

The capture harness runs in a temporary copy of the mod and drives its actual GUI handlers. It adds no fixes to Helmod functions. `capture.lua` is loaded as `audit.lua`, each case as `audit_case.lua`, with `require "audit"` appended to that temporary copy's control.lua. Screenshots show Helmod's own error report, enlarged to keep the text readable. The saves also load with the included uninstrumented build.

The checks directory records 951 initial recipe/research/resource cases, 20,010 factory/quality/module/solver calculations, and 96 linked/nested graph, import/export and removal cases. These checks found no runtime errors. They are coverage of vanilla and Space Age paths, not an exhaustive proof for all mod combinations or multiplayer interleavings.

- [Empty Recipe Explorer: Generate block dereferences nil block](empty-explorer/README.md)
- [Custom recipe with item ingredient calls missing get_ingredient_quality when Quality is enabled](custom-recipe-quality/README.md)
- [Saving a custom recipe without item ingredients passes nil categories to pairs](custom-recipe-categories/README.md)
- [Saving with product quantity dialog open causes nil input_quantity after reload](quantity-after-reload/README.md)
- [Saving a blank selector-filter rule causes table index is nil in recipe picker](blank-selector-rule/README.md)
- [Truncated plan import calls nil result from loadstring](truncated-import/README.md)
- [Conversion tab cannot decode a valid empty blueprint book](empty-blueprint-book/README.md)
