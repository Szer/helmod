local ProductYield = {}

---@class ProductIdentity
---@field type string
---@field name string
---@field temperature? number

---@class CombinedProduct : ProductIdentity
---@field amount number Expected output per craft
---@field ignored_by_productivity number Expected output excluded from a bonus craft

---@class ProductAmountSource
---@field get_product_amount fun(index: integer, productivity?: number): number

---@param total CombinedProduct
---@param source ProductAmountSource
---@param index integer
local function addRecipeResult(total, source, index)
    local base = source.get_product_amount(index)
    local bonus = source.get_product_amount(index, 1) - base
    total.amount = total.amount + base
    total.ignored_by_productivity = total.ignored_by_productivity + (base - bonus)
end

---@param source ProductAmountSource
---@param result ProductIdentity
---@param previous_index integer
---@param index integer
---@param total CombinedProduct?
---@return CombinedProduct
function ProductYield.combine(source, result, previous_index, index, total)
    if total == nil then
        total = {type=result.type, name=result.name, temperature=result.temperature, amount=0, ignored_by_productivity=0}
        addRecipeResult(total, source, previous_index)
    end
    addRecipeResult(total, source, index)
    return total
end

return ProductYield
