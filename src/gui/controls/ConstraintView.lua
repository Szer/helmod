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

---@param constraints table<string, {type: ConstraintKind, side:ConstraintSide?}>?
---@param key string
---@param side ConstraintSide
---@param legacySide? ConstraintSide Side inferred for an older sub-block constraint
---@return ConstraintKind?
function ConstraintView.icon(constraints, key, side, legacySide)
    local constraint = constraints and constraints[key]
    if constraint then
        local markedSide = constraint.side or legacySide
        if not markedSide or markedSide == side then return constraint.type end
    end
end

---@param product {amount:number}?
---@param ingredient {amount:number}?
---@param byProduct boolean
---@return ConstraintSide
function ConstraintView.legacySide(product, ingredient, byProduct)
    if not product then return ConstraintView.side.ingredients end
    if not ingredient then return ConstraintView.side.products end
    if product.amount > 0 and ingredient.amount == 0 then return ConstraintView.side.products end
    if ingredient.amount > 0 and product.amount == 0 then return ConstraintView.side.ingredients end
    if byProduct then return ConstraintView.side.products end
    return ConstraintView.side.ingredients
end

---@param cell {count:number, count_limit:number?}
---@param byLimit boolean?
---@return number
function ConstraintView.displayCount(cell, byLimit)
    if byLimit then return cell.count_limit or 0 end
    return cell.count
end

---@param count number
---@param showAll boolean?
---@return boolean
function ConstraintView.showQuantity(count, showAll)
    return showAll == true or count > 0
end

---@param expanded boolean
---@param mode ProductDisplayMode
---@param threshold number
---@param maxCount number
---@return number? threshold Nil shows every cell in the row.
function ConstraintView.rowThreshold(expanded, mode, threshold, maxCount)
    if expanded or threshold == 0 then return nil end
    if mode == DisplayMode.relative then return threshold * maxCount end
    return threshold
end

---@param cell {count:number, count_limit:number?, contraint_type:ConstraintKind?}
---@param threshold number?
---@param byLimit? boolean
---@return boolean
function ConstraintView.showCell(cell, threshold, byLimit)
    return threshold == nil or ConstraintView.displayCount(cell, byLimit) > threshold or cell.contraint_type ~= nil
end

return ConstraintView
