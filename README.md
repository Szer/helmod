# Helmod

This a mod for Factorio: [Mod Page](https://mods.factorio.com/mod/helmod)

Data model [here](doc/runtime-api-model.lua)

To see the data in the game, open Helmod, click on Admin icon, choose Global tab

## Remote API

Name of remote interface `helmod_interface`
Use `remote.call` from your mod for request data

Methodes:

* get_models : Return all models
* get_recipe(recipe_data) : Return the recipe with products and ingredients

To traverse the model, start with the root block `model.block_root` and to traverse each block `block.children`

Data Class:

* Model : the model
* Block : a block that contains blocks or recipes
* Recipe : a helmod recipe, the type `recipe` is native recipe of Factorio, otherwise is custom recipe

Examples:
```LUA
-- return all models
local data = remote.call("helmod_interface", "get_models")
```

```LUA
---Traverse model to append products and ingredients on each recipe
---@param data ModelData | BlokcData | RecipeData
function UnitTestPanel:loopDataRemoteAPI(data)
    if data.class == "Model" then
        for _, child in pairs(data.block_root.children) do
            self:loopDataRemoteAPI(child)
        end
    elseif data.class == "Block" then
        for _, child in pairs(data.children) do
            self:loopDataRemoteAPI(child)
        end
    elseif data.class == "Recipe" then
        local recipe = remote.call("helmod_interface", "get_recipe", data)
        data.products = recipe.products
        data.ingredients = recipe.ingredients
    end
end
```

## Sending items to orbit

The rocket button opens the cargo selector. Set the “sent to orbit” output demand, then configure silo quality, modules and beacons in the recipe editor; cargo and rocket-building ingredients link to upstream recipes.

Each orbit row owns its silo count. Its tooltip shows launches, rocket parts and construction rates; the editor shows the launch interval and crafting speed needed for continuous launches.

Capacity, rocket recipes, part counts, buffers and animation properties come from prototypes. Counts assume full cargo loads and immediate launch availability; construction uses average productivity, so discrete craft and dispatch ticks can slightly change observed throughput.

## Orbit tests

`python3 test/run_factorio.py /path/to/factorio --data /path/to/factorio/data` tests the real Factorio prototypes and Helmod solvers in temporary mod/save directories. `--base-only` checks existing planning without Space Age; `--timing` runs actual silos for 40,000 ticks.

`--ui` uses a graphical Factorio client to exercise the selector and recipe editor. Screenshots are written to `/tmp/helmod-orbit-screenshots`, or the directory selected with `--output`.

`python3 test/run_compatibility.py /path/to/factorio --data /path/to/factorio/data --mods /path/to/mod-set` checks a separately prepared mod set, including each silo, cargo demand recalculation and available qualities. The directory supplies mod archives, `mod-list.json` (with Helmod enabled), and optional `mod-settings.dat`.

With Space Age enabled, `--launches` also measures normal and legendary silo launch intervals against the timing model using continuously supplied rocket parts.
