# Contributing to Helmod: Szer's Fork

The maintained branch is `fork`. Keep Helfima’s credits, original history, license and the stable mod ID. Use a separate branch for changes and explicit paths for staging. Leave PRs open for maintainer review until the maintainer requests a merge.

- Reproduce bugs in Factorio. Keep regression tests outside `src/` and exercise the observable result, including save/reload when relevant. Do not put personal saves or credentials in the repository.
- Every calculation bug fix needs a regression test that fails on the unfixed code and passes with the fix. For new calculation behavior, assert independently expected quantities in a small Factorio plan, including a relevant boundary or fallback. Keep these tests in the PR engine suite so future changes run them.
- Type new Lua interfaces with LuaLS annotations. Reuse planner types in `doc/runtime-api-model.lua`; annotate units and optional values. Put calculation code that does not need Factorio in a module with no engine globals.
- Prefer explicit conditions. Use Factorio feature flags and prototype capabilities; do not assume vanilla entity names or mutate gameplay prototypes to implement planner features.
- Run the relevant engine suite with `lua test/run_orbit.lua`. For rocket timing, use `--timing` and the type gate in `ci/check-types.sh`. For persistence, run `test/run_fork_repros.lua` with the reproduction saves. GUI changes also need a graphical run with `--ui`.
- Release only when the maintainer manually triggers a batch on the fork branch. Merging a fix runs checks and never publishes on its own. Let the release workflow synchronize the changelog, manifest and tag version. Never upload from a local working copy, move a published tag or overwrite a released archive. See README for the release steps.

## Typed refactors

Characterize the current behavior before changing representations. Keep the refactor local to the bug or boundary under test, and distinguish intended fixes from behavior that must remain unchanged.

- Move new typed logic into the LuaLS CI check, leaving Factorio/GUI adapters small. For a promised type guarantee, test it with an intentionally invalid call that must fail for the expected diagnostic.
- Split bindings that change meaning. Use tagged alternatives for real alternatives; keep `nil`, `false`, and zero distinct. If the contract is ambiguous, stop and discuss it rather than adding `any`, casts, or suppressions to silence the checker.
- Run the same characterization tests after refactoring, plus a regression for the intended fix. Verify observable quantities or controls in Factorio, not just helper return values.

Keep persisted field names, recipe identifiers and import keys compatible with original Helmod plans. Exercise existing saved data when a change affects how plans are read or recalculated.

## Sheet calculations

Use `ModelCompute.update(model)` after editing a sheet. Supply a block hint only when the edit is confined to that block. Use `updateNow` for migrations that need completed totals before returning.
Record external calculation inputs in `SheetDependencies`. Test changed and independent branches against a fresh full solve, including edits submitted before publication.

## Typed GUI actions

- Follow `ChildRemoval` for panel actions. Give each variant a literal `action` and required named fields, and share that discriminated union between button construction and handling.
- Encode the payload at the button and decode it at the dispatcher boundary. Keep the existing button names and argument order so saved GUI controls still work.
- Narrow the union in the handler and type the remaining case explicitly. Include live call sites in the LuaLS gate and verify that a misspelled tag, a missing payload field, and an unhandled variant fail CI.
- Use shared named actions in buttons and handlers. When using a handler table, type its required entries and make CI reject a missing handler.
- The production panel keeps scroll panes when the displayed sheet and block stay the same. Reserve explicit scroll targets for navigation, added recipes, and moved rows.

## PR titles and release notes

Write a squash title that describes the full player-visible change. Use the PR body for the reproduction, implementation and tests. For breaking changes, include migration steps in the body.

Each `fix`, `feat` or `break` PR (including scoped titles) needs one standalone `Release-note: <text>` line. Lead with the change and aim for one line in the in-game changelog, e.g. “Fixed false surplus highlights on balanced materials.” Include a shortcut or setting only when players need it to find the feature.

Curate a pending batch with the per-commit overrides in `release-notes/`. Use `Release-note: <text>` to amend one entry and `Omit-release-note` to withdraw it. Combine related fixes by keeping one summary.

Use `fix:` for patch, `feat:` for minor, and `break:` for major. Keep maintenance under `chore:`, `docs:`, `test:`, `ci:`, `build:`, `refactor:`, or `style:`; these do not publish or appear in release notes. A maintainer reviews clarity; CI checks syntax. Let the release workflow update the version and changelog.
