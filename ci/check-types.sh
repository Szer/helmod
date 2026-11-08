#!/usr/bin/env bash
set -euo pipefail
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
check() {
  "${LUA_LANGUAGE_SERVER:-lua-language-server}" --check="$1" --checklevel=Warning --logpath="$tmp/log" --configpath="$(pwd)/.luarc.json"
}
check src/model/launch
check src/math/balance
check src/gui/controls

# Verify the live call site rejects swapped coordinates, without editing the checkout.
mkdir "$tmp/swapped"
sed 's/apply(solver, matrix, choice.row, choice.column)/apply(solver, matrix, choice.column, choice.row)/' \
  src/math/balance/Pivot.lua > "$tmp/swapped/Pivot.lua"
if check "$tmp/swapped" > "$tmp/negative.log" 2>&1; then
  echo 'Swapping pivot row and column should fail the type check.' >&2
  exit 1
fi
grep -q 'param-type-mismatch' "$tmp/negative.log" && grep -q 'PivotRow' "$tmp/negative.log" && grep -q 'PivotColumn' "$tmp/negative.log" || {
  cat "$tmp/negative.log" >&2
  exit 1
}
echo 'Verified that LuaLS rejects swapped pivot coordinates.'

# A constraint kind is not a button action, even though both are strings.
mkdir "$tmp/bad-action"
sed '/^return ConstraintView$/i ConstraintView.hint(false, "master")' \
  src/gui/controls/ConstraintView.lua > "$tmp/bad-action/ConstraintView.lua"
if check "$tmp/bad-action" > "$tmp/bad-action.log" 2>&1; then
  echo 'A constraint kind should not type-check as a control action.' >&2
  exit 1
fi
grep -q 'param-type-mismatch' "$tmp/bad-action.log" || { cat "$tmp/bad-action.log" >&2; exit 1; }

# Check action contracts at the production panel's real call sites.
panel="$tmp/panel"
mkdir -p "$panel/gui/controls"
cp src/gui/controls/*.lua "$panel/gui/controls/"
cp doc/runtime-api-model.lua src/dialog/ProductionPanel.lua "$panel/"
check_panel() {
  "${LUA_LANGUAGE_SERVER:-lua-language-server}" --check="$panel" --checklevel=Error \
    --logpath="$tmp/log" --configpath="$(pwd)/ci/child-removal.luarc.json"
}
check_panel
reject_panel_edit() {
  local edit=$1 diagnostic=$2 detail=$3
  sed "$edit" src/dialog/ProductionPanel.lua > "$panel/ProductionPanel.lua"
  if check_panel > "$tmp/panel.log" 2>&1; then
    echo "Expected LuaLS to reject $edit" >&2
    exit 1
  fi
  grep -Fq -- "($diagnostic)" "$tmp/panel.log" && grep -Fq -- "$detail" "$tmp/panel.log" || {
    cat "$tmp/panel.log" >&2
    exit 1
  }
}
reject_panel_edit 's/action="block-child-remove",/action="block-child-remvoe",/' assign-type-mismatch block-child-remvoe
reject_panel_edit 's/, child_id=recipe.id//' missing-fields child_id
reject_panel_edit 's/removal.action == "block-child-remove" then/removal.action == "block-child-remvoe" then/' assign-type-mismatch ConfirmChildRemoval
echo 'Verified removal button tags, required child IDs and handler narrowing.'
