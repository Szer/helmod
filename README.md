# Helmod: Szer's Fork

An independent fork of [Helmod](https://mods.factorio.com/mod/helmod), the factory planner created by Helfima with the [Helmod contributors](https://github.com/Helfima/helmod/graphs/contributors). Szer maintains this fork for Factorio 2.1. Adds linked orbital cargo planning and fixes bugs in the [fork issue tracker](https://github.com/Szer/helmod/issues).

[Install from the Mod Portal](https://mods.factorio.com/mod/helmod-fork). To switch an existing Helmod 2.1 save, keep a backup, disable Helmod and enable Helmod Fork **in the same restart**, then load the original save. The fork takes over Helmod’s stored sheets, custom recipes and rules. Saving with neither mod active can discard the old data. Mods that explicitly require the original `helmod` ID need a compatibility update.

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

## Balancing recycling loops

In a product-driven **Matrix Solver** block, open **Block Edition → External supplies** and select the material and quality you can supply from outside. For copper upcycling, select **Copper plate (Normal)**, craft cable at normal through epic quality, recycle cable at every quality, and set the legendary plate output target.

## Experimental background solver

Enable **Experimental background sheet solver** under **Settings → Mod settings → Map** to try it for everyone in the save. Adding or moving recipes, changing machines and modules, editing quantities, and switching block modes all use the same solver. A small dot beside the block title turns yellow during calculation and green when the new totals appear.

Shared sheets take turns across simulation ticks. Another edit replaces the pending calculation and retains all accepted changes. Synthetic recipes such as orbital cargo and electricity use fresh block calculations. Paused games, exports, and remote reads finish pending work immediately. A single matrix solve can still take an entire tick.

## Sending items to orbit

The rocket button appears when a platform-capable silo is available, such as with Space Age enabled. Without one, existing satellite launch recipes remain available through the recipe selector.

Click the rocket button to select cargo and set how much to send to orbit. Silo quality, modules and beacons are configured in the recipe editor; cargo and rocket ingredients link to their production recipes.

Each cargo recipe calculates its own silo count. The tooltip shows launch and rocket-part rates; the editor shows the minimum launch interval and the crafting speed needed to sustain it.

Capacity, rocket recipes, part counts, buffers and animation properties come from prototypes. Counts assume full cargo loads and immediate launch availability; construction uses average productivity, so discrete craft and dispatch ticks can slightly change observed throughput.

## Silo timing data

`data-final-fixes.lua` copies silo animation fields unavailable through the runtime API into a [mod-data prototype](https://lua-api.factorio.com/latest/prototypes/ModData.html). This stores planner metadata without adding or changing items, entities or recipes.

## Orbit tests

Run `lua test/run_orbit.lua /path/to/factorio --data /path/to/factorio/data` to check orbit calculations through Helmod's solvers inside Factorio. The launcher uses Lua 5.1+ or LuaJIT without Lua packages, plus Linux coreutils or Windows PowerShell for file and process operations. On Windows, quote paths containing spaces.

The launcher creates isolated mod and save directories. Successful runs remove them; failed runs keep the files and print their location for inspection.

* `--base-only` checks existing planning without Space Age.
* `--timing` measures 18 silo configurations over 40,000 ticks.
* `--ui` uses a graphical Factorio client to exercise the selector and recipe editor, then closes that test client after 45 seconds. Screenshots go to `orbit-screenshots` in the current directory, or the directory selected with `--output`.
* `--mods /path/to/mod-set` checks a separately prepared mod set, including compatible silos, cargo demand recalculation and available qualities. The directory supplies mod archives, `mod-list.json` with helmod-fork enabled and helmod disabled, and optional `mod-settings.dat`.
* `--mods /path/to/mod-set --launches` also measures normal and legendary silo launch intervals using continuously supplied rocket parts. This requires platform-capable silos and the Space Age test platform prototypes.

Use `lua test/run_orbit.lua --help` for the command options. The test suites in `test/test_orbit*.lua` run inside Factorio; the launcher only prepares files and starts the engine.

To replay the [seven original reproduction saves](https://github.com/Szer/helmod/tree/codex/audit-repros/audit-repros), run `lua test/run_fork_repros.lua /path/to/graphical-factorio /path/to/data /path/to/audit-repros`. This also checks storage transfer from Helmod and confirms a quantity after reloading the saved dialog in a new process.

To build the release ZIP and checksum locally from a committed revision, run `ci/package.sh dist`.

## Development and releases

Target the `fork` branch for pull requests. GitHub Actions parses the Lua files, type-checks the rocket launch model, balance pivot selector and constraint controls with LuaLS (including a negative test for swapped coordinates), and runs the integration, base-only, timing and save regression suites on a pinned Factorio 2.1 headless build. It also creates a new map and migrates an old save with the packaged ZIP. The separate graphical suite remains available for UI changes.

To run the same checks locally, install Lua 5.2, then run `ci/install-tools.sh /tmp/helmod-tools` and `ci/fetch-repros.sh /tmp/helmod-repros`. Use `LUA_LANGUAGE_SERVER=/tmp/helmod-tools/luals/bin/lua-language-server ci/check-types.sh` and `lua test/run_fork_repros.lua /tmp/helmod-tools/factorio/bin/x64/factorio /tmp/helmod-tools/factorio/data /tmp/helmod-repros --headless`.

## Testing a preview

[Download the latest passing build](https://github.com/Szer/helmod/releases/download/nightly/helmod-fork-nightly.zip) or [see its commit, checksum and pending changes](https://github.com/Szer/helmod/releases/tag/nightly). This single rolling GitHub prerelease is updated after successful pushes to `fork`. It uses the same ZIP tested by CI, with the normal mod ID and version.

On Linux, run `./scripts/install-nightly.sh` from the repository. It verifies the GitHub asset checksum and installs it under the proper filename in `~/.factorio-nightly/mods`. Set the destination with `SAVE_FOLDER="/path/to/test/mods" ./scripts/install-nightly.sh`. This is the **mod ZIP destination**, not the folder containing saved maps. Requires Bash, curl, jq, unzip and GNU coreutils. A different ZIP with the same filename is backed up before replacement.

Rename the download to the filename shown on the prerelease page and put it in a separate test profile’s mod directory. Replace any other copy of the fork in that directory, restart Factorio, and load a **copy** of your save. The nightly does not update through the in-game Mod Portal. To return to the stable version, switch back to your normal profile and save.

## Versioning and changelogs

Squash PR titles determine the version bump and should read well on their own. For example, `fix: Keep the entered quantity after loading a save` describes the outcome. The PR’s `Release-note:` line supplies the initial changelog text.

| Title prefix | Version change | From 2.3.9 |
|---|---|---|
| `fix:` | Patch | 2.3.10 |
| `feat:` | Minor | 2.4.0 |
| `break:` | Major | 3.0.0 |

The largest change since the last fork tag wins. `docs:`, `ci:`, `chore:`, `test:`, `refactor:`, `style:` and `build:` do not bump the version or appear in the notes. Optional scopes such as `fix(ui):` are supported. Squash commits use the PR title and description. Describe the actual change in the title; put the specific reproduction in the body. Every release-worthy PR must include exactly one nonempty standalone line in its description for the public bullet, e.g. `Release-note: The matrix solver now tries to use up intermediate products before leaving a surplus.` The override changes wording only.

### Editing pending release notes

Put one line in `release-notes/<full-squash-commit-SHA>.txt` for each entry you want to change. Use `git log --first-parent --format='%H %s'` to find the squash commit on `fork`.

| Edit | File contents |
| --- | --- |
| Reword a note | `Release-note: <new player-facing sentence>` |
| Withdraw a note | `Omit-release-note` |
| Combine related notes | Write the combined sentence on one commit and omit the others. The chosen commit sets the changelog category. |
| Restore the original note | Delete its override file. |

Submit note edits with a `docs:` PR. Preview with `ci/semver.sh notes` or read **Pending release notes** in the Actions check summary. The release version still reflects every eligible commit, even when all of its notes are omitted. Published changelogs retain their original text.

### Publishing a batch

Merges test and accumulate without publishing. To release a batch, manually run **Fork checks and release batch** on branch **fork**, or use `gh workflow run fork.yml --repo Szer/helmod --ref fork`. After all checks pass, [git-cliff](https://git-cliff.org/) calculates the version and writes the curated player-facing notes in Factorio’s changelog format. Actions commits the generated manifest and changelog, atomically pushes that commit and its version tag, then dispatches the tag workflow. Tag CI independently verifies the version and notes and runs Factorio again; only then does it publish the tested ZIP and check the portal hash. An empty or maintenance-only batch creates no release. Do not hand-edit versions or move published tags. To retry a failed tag publication, rerun the failed Actions job, or dispatch `fork.yml` on that tag.

The Actions secret `FACTORIO_APIKEY` needs the Publish Mods, Upload Mods and Edit Mods permissions. Only the tag publish step receives it. Test the versioning policy locally with git-cliff on PATH and `ci/test-semver.sh`.

The read-only **Upstream drift** workflow checks Helfima’s `master`, `dev`, and `experimental` branches weekly. If upstream moves ahead, its run lists the commits for review. Bring applicable changes into a tested PR with a player-facing title; the check itself never merges or publishes.
