local ConstraintView = {}

---@enum ConstraintAction
ConstraintView.action = {
    product = "production-recipe-product-add",
    ingredient = "production-recipe-ingredient-add",
    edition = "product-edition",
}

---@enum ConstraintKind
ConstraintView.kind = {master = "master", exclude = "exclude"}

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

---@param cell {count:number, state:integer?, contraint_type:ConstraintKind?}
---@param maxCount number
---@param threshold number
---@param mode "absolute"|"relative"
---@return boolean
function ConstraintView.showCell(cell, maxCount, threshold, mode)
    if threshold == 0 or keepVisible(cell.contraint_type, cell.state, cell.count) then return true end
    if mode == "relative" then threshold = threshold * maxCount end
    return cell.count > threshold
end

return ConstraintView
