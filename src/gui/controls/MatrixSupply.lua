local ConstraintView = require "gui.controls.ConstraintView"
local MatrixSupply = {action = "matrix-external-supply"}
MatrixSupply.hint = {
    toggle = MatrixSupply.action,
    automatic = "matrix-automatic-supply",
    mode = "matrix-supply-mode",
}

MatrixSupply.element = {label = "supply-label", scroll = "supply-scroll", options = "supply-options"}
MatrixSupply.label = {
    supplies = "helmod_block_edition_panel.external-supplies",
    quality = "helmod_block_edition_panel.external-supply-quality",
}
MatrixSupply.tooltip = {
    help = "helmod_block_edition_panel.external-supplies-help",
    filter = "helmod_button.matrix-input-filter",
    mode = "helmod_button.matrix-supply-mode",
    automatic = "helmod_button.matrix-automatic-supply",
    target = "helmod_block_edition_panel.external-supply-target",
    toggle = "controls.matrix-supply-toggle",
    remove = "controls.matrix-supply-remove",
}

---@class MatrixSupplyEdit
---@field action "matrix-external-supply"
---@field model_id string
---@field block_id string
---@field material string

---@param edit MatrixSupplyEdit
---@return string, string, string, string
function MatrixSupply.buttonArgs(edit)
    return edit.action, edit.model_id, edit.block_id, edit.material
end

---@param event {action?:string,item1?:string,item2?:string,item3?:string}
---@return MatrixSupplyEdit?
function MatrixSupply.decode(event)
    if event.action == MatrixSupply.action and event.item1 and event.item2 and event.item3 then
        return {action=MatrixSupply.action, model_id=event.item1, block_id=event.item2, material=event.item3}
    end
end

---Header ingredient buttons encode the full material key after the prototype name.
---@param event {action?:string,item1?:string,item2?:string,item3?:string,item5?:string,control?:boolean,shift?:boolean}
---@return MatrixSupplyEdit?
function MatrixSupply.headerEdit(event)
    if event.action == ConstraintView.action.ingredient and event.item3 == ConstraintView.noTarget
        and event.item1 and event.item2 and event.item5 and (event.control or event.shift) then
        return {action=MatrixSupply.action, model_id=event.item1, block_id=event.item2, material=event.item5}
    end
end

return MatrixSupply
