Saving a blank selector-filter rule causes table index is nil in recipe picker

1. Load `repro.zip`, which contains the blank rule created through the rule editor.
2. Close Bug Report and any Recipe Selector window.
3. Open Add recipe in Helmod and wait for the selector to populate.

From a new game: Open Admin → Rules → Add rule. Choose Mod base and Name selector-filter. Leave Value untouched and empty, then Save. Open the recipe selector.

Expected: Saving an incomplete rule should be rejected, or the selector should ignore it safely.

Cause: `RuleEdition` stores its untouched `rule_value` as nil. `Player.getRules` uses it as a table key (`rules_excluded[rule.category][rule.type][rule.value]`). The bad rule persists across save/reload. The lower-level probe also fails with base only.

Recovery: Delete the blank rule in Admin → Rules, or reset the rules.
