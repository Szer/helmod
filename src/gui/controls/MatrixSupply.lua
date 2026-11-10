local ConstraintView = require "gui.controls.ConstraintView"
local MatrixSupply = {action = "matrix-external-supply"}
MatrixSupply.hint = {
    toggle = MatrixSupply.action,
    automatic = "matrix-automatic-supply",
    mode = "matrix-supply-mode",
}

MatrixSupply.tooltip = {
    filter = "helmod_button.matrix-input-filter",
    mode = "helmod_button.matrix-supply-mode",
    automatic = "helmod_button.matrix-automatic-supply",
    toggle = "controls.matrix-supply-toggle",
}

---@class MatrixSupplyEdit
---@field action "matrix-external-supply"
---@field model_id string
---@field block_id string
---@field material string

---Header ingredient buttons encode the full material key after the prototype name.
---@param event {action?:string,item1?:string,item2?:string,item3?:string,item5?:string,control?:boolean,shift?:boolean,alt?:boolean}
---@return MatrixSupplyEdit?
function MatrixSupply.headerEdit(event)
    if event.action == ConstraintView.action.ingredient and event.item3 == ConstraintView.noTarget
        and event.item1 and event.item2 and event.item5 and event.control == true and not event.shift and not event.alt then
        ---@type MatrixSupplyEdit
        local edit = {action=MatrixSupply.action, model_id=event.item1, block_id=event.item2, material=event.item5}
        return edit
    end
end

return MatrixSupply
