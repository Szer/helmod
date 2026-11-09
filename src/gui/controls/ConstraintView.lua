local ConstraintView = {}

---@alias ConstraintAction "production-recipe-product-add" | "production-recipe-ingredient-add" | "product-edition"
---@alias ConstraintKind "master" | "exclude"

---@class RowConstraintEdit
---@field side "products"|"ingredients"
---@field child_id string
---@field kind ConstraintKind

---@param event {action?:string, item3?:string, item4?:string, control?:boolean, shift?:boolean}
---@return RowConstraintEdit?
function ConstraintView.edit(event)
    if event.item3 == nil or event.item3 == "none" then return nil end
    local kind
    if event.control then kind = "master"
    elseif event.shift then kind = "exclude"
    else return nil end
    if event.action == "production-recipe-product-add" then
        return {side="products", child_id=event.item3, kind=kind}
    elseif event.action == "production-recipe-ingredient-add" and event.item4 ~= "none" then
        return {side="ingredients", child_id=event.item3, kind=kind}
    end
    return nil
end

---@param simplex boolean?
---@param action ConstraintAction
---@return "contraint"?
function ConstraintView.hint(simplex, action)
    if simplex ~= true and action ~= "product-edition" then
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

-- State 3 is an external block flow, even when the sheet scales its amount to zero.
---@param state integer?
---@param amount number?
---@return boolean
function ConstraintView.zeroFlow(state, amount)
    return state == 3 and amount == 0
end

---@param state integer?
---@param amount number?
---@param drivingSide boolean
---@param threshold number
---@return boolean
function ConstraintView.showFlow(state, amount, drivingSide, threshold)
    return (state == 1 and drivingSide) or (amount or 0) > threshold or ConstraintView.zeroFlow(state, amount)
end

return ConstraintView
