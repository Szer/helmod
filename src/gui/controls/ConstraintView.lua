local ConstraintView = {}

---@alias ConstraintAction "production-recipe-product-add" | "production-recipe-ingredient-add" | "product-edition"
---@alias ConstraintKind "master" | "exclude"

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
