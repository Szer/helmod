local DisplayMode = require "gui.controls.DisplayMode"
local ConstraintView = {}

---@enum ConstraintAction
ConstraintView.action = {
    product = "production-recipe-product-add",
    ingredient = "production-recipe-ingredient-add",
    edition = "product-edition",
}

ConstraintView.kind = require "math.balance.ConstraintKind"

---@enum ConstraintSide
ConstraintView.side = {products = "products", ingredients = "ingredients"}

ConstraintView.noTarget = "none"

---@class RowConstraintEdit
---@field side ConstraintSide
---@field child_id string
---@field kind ConstraintKind

---@param event {action?:string, item3?:string, item4?:string, control?:boolean, shift?:boolean}
---@return RowConstraintEdit?
function ConstraintView.edit(event)
    if event.item3 == nil or event.item3 == ConstraintView.noTarget then return nil end
    local kind
    if event.control then kind = ConstraintView.kind.master
    elseif event.shift then kind = ConstraintView.kind.exclude
    else return nil end
    if event.action == ConstraintView.action.product then
        return {side=ConstraintView.side.products, child_id=event.item3, kind=kind}
    elseif event.action == ConstraintView.action.ingredient and event.item4 ~= ConstraintView.noTarget then
        return {side=ConstraintView.side.ingredients, child_id=event.item3, kind=kind}
    end
    return nil
end

---@param simplex boolean?
---@param action ConstraintAction
---@return "contraint"?
function ConstraintView.hint(simplex, action)
    if simplex ~= true and action ~= ConstraintView.action.edition then
        return "contraint"
    end
    return nil
end

---@param constraints table<string, {type: ConstraintKind}>?
---@param key string
---@return ConstraintKind?
function ConstraintView.icon(constraints, key)
    if constraints and constraints[key] then return constraints[key].type end
    return nil
end

-- Active constraints need a clickable cell even when they stop the flow.
---@param constraint ConstraintKind?
---@param state integer?
---@param amount number?
---@return boolean
local function keepVisible(constraint, state, amount)
    return constraint ~= nil or (state == 3 and amount == 0)
end

---@param state integer?
---@param amount number?
---@param drivingSide boolean
---@param threshold number
---@param constraint ConstraintKind?
---@return boolean
function ConstraintView.showFlow(state, amount, drivingSide, threshold, constraint)
    return (state == 1 and drivingSide) or (amount or 0) > threshold or keepVisible(constraint, state, amount)
end

---@param constraint ConstraintKind?
---@param outputCount number
---@param hasVisibleInput boolean
---@param inputAction ConstraintAction
---@return boolean
function ConstraintView.duplicateOutput(constraint, outputCount, hasVisibleInput, inputAction)
    return constraint ~= nil and outputCount == 0 and hasVisibleInput and inputAction == ConstraintView.action.ingredient
end

---@param rowCount number?
---@param expanded boolean
---@param mode ProductDisplayMode
---@param threshold number
---@param maxCount number
---@return number? threshold Nil shows every cell in the row.
function ConstraintView.rowThreshold(rowCount, expanded, mode, threshold, maxCount)
    if (rowCount or 0) == 0 or expanded or threshold == 0 then return nil end
    if mode == DisplayMode.relative then return threshold * maxCount end
    return threshold
end

---@param cell {count:number, state:integer?, contraint_type:ConstraintKind?}
---@param threshold number?
---@return boolean
function ConstraintView.showCell(cell, threshold)
    return threshold == nil or cell.count > threshold or keepVisible(cell.contraint_type, cell.state, cell.count)
end

return ConstraintView
