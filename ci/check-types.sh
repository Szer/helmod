#!/usr/bin/env bash
set -euo pipefail
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
check() {
  "${LUA_LANGUAGE_SERVER:-lua-language-server}" --check="$1" --checklevel=Warning --logpath="$tmp/log" --configpath="$(pwd)/.luarc.json"
}
check src/model/launch
check src/math/balance

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
