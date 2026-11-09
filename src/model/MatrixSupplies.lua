local MatrixSupplies = {}

---@param block BlockData
---@return boolean
function MatrixSupplies.available(block)
    return block.solver == true and block.by_product ~= false and block.by_factory ~= true
end

---@param block BlockData
---@param key string
---@return boolean
function MatrixSupplies.editable(block, key)
    local product = block.products[key]
    return MatrixSupplies.available(block) and block.ingredients[key] ~= nil and product ~= nil and product.input == nil
end

---@param block BlockData
---@param key string
---@return boolean
function MatrixSupplies.selected(block, key)
    return block.matrix_supplies ~= nil and block.matrix_supplies[key] == true
end

---@param block BlockData
---@param key string
---@param enabled boolean
---@return boolean changed
function MatrixSupplies.set(block, key, enabled)
    if not MatrixSupplies.editable(block, key) or enabled == MatrixSupplies.selected(block, key) then return false end
    local supplies = block.matrix_supplies or {}
    supplies[key] = enabled or nil
    block.matrix_supplies = next(supplies) and supplies or nil
    return true
end

return MatrixSupplies
