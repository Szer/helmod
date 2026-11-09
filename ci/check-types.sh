#!/usr/bin/env bash
set -euo pipefail
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
check() {
  "${LUA_LANGUAGE_SERVER:-lua-language-server}" --check="$1" --checklevel=Warning --logpath="$tmp/log" --configpath="$(pwd)/.luarc.json"
}
check src/model/launch
check src/model/energy
check src/math/balance
mkdir "$tmp/linked"
cp src/math/linked/*.lua "$tmp/linked/"
ln -s "$PWD/doc" "$tmp/doc"
check_profile() {
  "${LUA_LANGUAGE_SERVER:-lua-language-server}" --check="$tmp/linked" --checklevel=Warning \
    --logpath="$tmp/log" --configpath="$PWD/ci/linked-profile.luarc.json"
}
check_profile
sed -i '/^return Profile$/i \---@param recipe RecipeData\nlocal function invalid(recipe) Profile.append(recipe, recipe, 1) end' "$tmp/linked/Profile.lua"
if check_profile > "$tmp/profile.log" 2>&1; then
  echo 'A recipe cannot be used as a linked block profile.' >&2
  exit 1
fi
grep -q 'param-type-mismatch' "$tmp/profile.log" && grep -q 'BlockData' "$tmp/profile.log" || {
  cat "$tmp/profile.log" >&2
  exit 1
}
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
cp src/gui/controls/DisplayMode.lua "$tmp/bad-action/"
sed '/^return ConstraintView$/i ConstraintView.hint(false, "master")' \
  src/gui/controls/ConstraintView.lua > "$tmp/bad-action/ConstraintView.lua"
if check "$tmp/bad-action" > "$tmp/bad-action.log" 2>&1; then
  echo 'A constraint kind should not type-check as a control action.' >&2
  exit 1
fi
grep -q 'param-type-mismatch' "$tmp/bad-action.log" || { cat "$tmp/bad-action.log" >&2; exit 1; }

# Check action contracts at the production panel's real call sites.
panel="$tmp/panel"
mkdir -p "$panel/gui/controls" "$panel/model"
cp src/model/ProductionBlockMode.lua "$panel/model/"
cp src/gui/controls/*.lua "$panel/gui/controls/"
cp src/gui/ProductionScroll.lua "$panel/gui/"
cp doc/runtime-api-model.lua src/dialog/ProductionPanel.lua "$panel/"
check_panel() {
  "${LUA_LANGUAGE_SERVER:-lua-language-server}" --check="$panel" --checklevel=Error \
    --logpath="$tmp/log" --configpath="$(pwd)/ci/production-panel.luarc.json"
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
reject_panel_edit 's/action="block-remove",/action="block-remvoe",/' assign-type-mismatch block-remvoe
reject_panel_edit 's/, block_id=block_id$//' missing-fields block_id
reject_panel_edit 's/model_id=model.id, block_id=block_id/block_id=block_id/' missing-fields model_id
reject_panel_edit 's/removal.action == "block-remove-canceled" then/removal.action == "block-remvoe-canceled" then/' assign-type-mismatch ConfirmBlockRemoval
reject_panel_edit 's/ProductionScroll.forUpdate(event, model, removal)/ProductionScroll.forUpdate(event, model, BlockRemoval.decode(event))/' param-type-mismatch RequestChildRemoval
reject_panel_edit 's/self:clearForUpdate(ProductionScroll.forUpdate(event, model, removal))/self:clearForUpdate(BlockRemoval.decode(event))/' param-type-mismatch ProductionScrollPane
reject_panel_edit 's/addRowScroll(gui_table, ConstraintView.side.products, recipe.id)/addRowScroll(gui_table, "produtcs", recipe.id)/' param-type-mismatch produtcs
reject_panel_edit 's/skip_hidden_products, display_hidden_products_mode, display_hidden_products, max_count)/skip_hidden_products, "relativ", display_hidden_products, max_count)/' param-type-mismatch relativ
reject_panel_edit 's/action=TreeAction.name.blockToChild, model_id=model.id, block_id=parent.id, child_id=block.id/action=TreeAction.name.blockToChild, model_id=model.id, block_id=parent.id/' missing-fields child_id
reject_panel_edit 's/action=BlockMode.action.icon, model_id=model.id/action="row-bock-mode", model_id=model.id/' assign-type-mismatch row-bock-mode
reject_panel_edit 's/action=BlockMode.action.icon, model_id=model.id, block_id=block.id/action=BlockMode.action.icon, model_id=model.id/' missing-fields block_id
reject_panel_edit 's/click.action == "block-consumer" then/click.action == "block-by-product" then/' assign-type-mismatch ToggleInput
reject_panel_edit 's/ProductionBlockMode.toggle(block, option)/ProductionBlockMode.toggle(block, "by_factory")/' param-type-mismatch by_factory
reject_panel_edit 's/action=BlockHeader.action.clear, model_id=model.id/action="block-reset-inpt", model_id=model.id/' assign-type-mismatch block-reset-inpt
reject_panel_edit 's/action=BlockHeader.action.clear, model_id=model.id, block_id=block.id/action=BlockHeader.action.clear, model_id=model.id/' missing-fields block_id
reject_panel_edit 's/edit.action == "block-all-product-visible" then/edit.action == "block-all-ingredient-visible" then/' assign-type-mismatch ClearBlockInputs
reject_panel_edit 's/action=BlockToolbar.action.deep, model_id=model.id/action="display-count-dep", model_id=model.id/' assign-type-mismatch display-count-dep
reject_panel_edit 's/action=BlockToolbar.action.reset, model_id=model.id, block_id=block_id/action=BlockToolbar.action.reset, model_id=model.id/' missing-fields block_id
reject_panel_edit 's/limit = function(model, block, event)/limti = function(model, block, event)/' missing-fields limit
reject_panel_edit 's/location = function(event, model)/loaction = function(event, model)/' missing-fields location
reject_panel_edit 's/panelAction{action=BlockToolbar.action.location}/panelAction{action=BlockToolbar.action.deep}/' assign-type-mismatch display-count-deep
echo 'Verified removal contracts, display modes, constraint pane sides and viewport refresh scope.'
