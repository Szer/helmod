# Contributing to Helmod: Szer's Fork

The maintained branch is `fork`. Keep Helfima’s credits, original history, license and the stable mod ID. Use a separate branch for changes and explicit paths for staging.

- Reproduce bugs in Factorio. Keep regression tests outside `src/` and exercise the observable result, including save/reload when relevant. Do not put personal saves or credentials in the repository.
- Every calculation bug fix needs a regression test that fails on the unfixed code and passes with the fix. For new calculation behavior, assert independently expected quantities in a small Factorio plan, including a relevant boundary or fallback. Keep these tests in the PR engine suite so future changes run them.
- Type new Lua interfaces with LuaLS annotations. Reuse planner types in `doc/runtime-api-model.lua`; annotate units and optional values. Put calculation code that does not need Factorio in a module with no engine globals.
- Prefer explicit conditions. Use Factorio feature flags and prototype capabilities; do not assume vanilla entity names or mutate gameplay prototypes to implement planner features.
- Run the relevant engine suite with `lua test/run_orbit.lua`. For rocket timing, use `--timing` and the type gate in `ci/check-types.sh`. For persistence, run `test/run_fork_repros.lua` with the reproduction saves. GUI changes also need a graphical run with `--ui`.
- Release only when the maintainer manually triggers a batch on the fork branch. Merging a fix runs checks and never publishes on its own. Let the release workflow synchronize the changelog, manifest and tag version. Never upload from a local working copy, move a published tag or overwrite a released archive. See README for the release steps.

## PR titles are public release notes

Squash PR titles must be user-friendly and readable as standalone changelog bullets. Describe what changes for a player in one short sentence: `fix: Keep the entered quantity after loading a save`, not `fix: Guard input_quantity`. Describe the scope of the actual change. If the fix applies to matrix planning generally, do not title it as a fix for the oil recipe that exposed it. Put the reproduction, implementation details, and test evidence in the PR body. Every release-worthy PR (fix, feat or break, including scoped titles) must include exactly one nonempty standalone `Release-note: <player-facing sentence>` line to the PR body; the title still sets the version bump. For a breaking change, name the incompatible behavior and explain the migration in the body.

Use `fix:` for patch, `feat:` for minor, and `break:` for major. Keep maintenance under `chore:`, `docs:`, `test:`, `ci:`, `build:`, `refactor:`, or `style:`; these do not publish or appear in release notes. A maintainer reviews clarity; CI checks syntax. Let the release workflow update the version and changelog.
