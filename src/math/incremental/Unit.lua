local Unit = {}

---@class UnitPreparation
---@field recipes string[]
---@field next integer

-- Compare values, shared references, and traversal order, including mod-provided fields.
local function equal(left, right, seenLeft, seenRight)
    if type(left) ~= "table" or type(right) ~= "table" or left.__self or right.__self then
        return left == right
    end
    if seenLeft[left] or seenRight[right] then
        return seenLeft[left] == right and seenRight[right] == left
    end
    seenLeft[left], seenRight[right] = right, left
    local key
    while true do
        local a, x = next(left, key)
        local b, y = next(right, key)
        if a ~= b then return false end
        if a == nil then return true end
        if not equal(x, y, seenLeft, seenRight) then return false end
        key = a
    end
end

---@generic L, R
---@param left L
---@param right R
---@return boolean
function Unit.equal(left, right)
    return equal(left, right, {}, {})
end

return Unit
