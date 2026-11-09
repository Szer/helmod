local PercentageSolve = {}

---@class PercentageSolveEntry
---@field matrix Matrix
---@field solved Matrix
---@field solver function
---@field time number
---@field by_product boolean?
---@field by_factory boolean?

---@class PercentageSolvePass
---@field edited BlockData
---@field previous table<BlockData, PercentageSolveEntry>
---@field current table<BlockData, PercentageSolveEntry>

-- Preserve iteration order as well as values: the solver can break ties by column order.
local function sameInput(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    local key
    while true do
        local aKey, aValue = next(a, key)
        local bKey, bValue = next(b, key)
        if aKey ~= bKey then return false end
        if aKey == nil then return true end
        if not sameInput(aValue, bValue) then return false end
        key = aKey
    end
end

---@param pass PercentageSolvePass
---@param block BlockData
---@param matrix Matrix
---@param solver function
---@param compute fun():Matrix?
---@return Matrix?
function PercentageSolve.solve(pass, block, matrix, solver, compute)
    local old = pass.previous[block]
    if old and old.solver == solver and old.time == block.time and old.by_factory == block.by_factory
        and old.by_product == block.by_product and sameInput(matrix, old.matrix) then
        pass.current[block] = old
        return old.solved
    end
    local solved = compute()
    if solved then
        pass.current[block] = {
            matrix=table.deepcopy(matrix), solved=solved, solver=solver,
            time=block.time, by_factory=block.by_factory, by_product=block.by_product
        }
    end
    return solved
end

return PercentageSolve
