# Contributing to Helmod: Szer's Fork

The maintained branch is `fork`. Keep Helfima’s credits, original history, license and the stable mod ID. Use a separate branch for changes and explicit paths for staging.

- Reproduce bugs in Factorio. Keep regression tests outside `src/` and exercise the observable result, including save/reload when relevant. Do not put personal saves or credentials in the repository.
- Type new Lua interfaces with LuaLS annotations. Reuse planner types in `doc/runtime-api-model.lua`; annotate units and optional values. Put calculation code that does not need Factorio in a module with no engine globals.
- Prefer explicit conditions. Use Factorio feature flags and prototype capabilities; do not assume vanilla entity names or mutate gameplay prototypes to implement planner features.
- Run the relevant engine suite with `lua test/run_orbit.lua`. For rocket timing, use `--timing` and the type gate in `ci/check-types.sh`. For persistence, run `test/run_fork_repros.lua` with the reproduction saves. GUI changes also need a graphical run with `--ui`.
- Release through GitHub Actions. Keep source, changelog, tag version and package identity in agreement. Never upload from a local working copy, move a published tag or overwrite a released archive. See README for the release steps.
