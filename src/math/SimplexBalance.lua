local Pivot = require "math.balance.Pivot"
local TemperatureSupply = require "math.balance.TemperatureSupply"
local Balance = {}

---@param rows number[][]
---@param col integer
---@return boolean produced, boolean consumed
local function materialFlows(rows, col)
    local produced, consumed = false, false
    for _, row in ipairs(rows) do
        local amount = row[col] or 0
        produced = produced or amount > 0
        consumed = consumed or amount < 0
        if produced and consumed then break end
    end
    return produced, consumed
end

---A recycled ingredient can still draw its shortfall from a selected external supply.
---@param source Matrix
---@return integer[] columns
function Balance.supplyColumns(source)
    local columns = {}
    for col, element in ipairs(source.columns) do
        local produced, consumed = materialFlows(source.rows, col)
        local selected = source.external_supplies and source.external_supplies[element.key]
        if not produced or (selected and consumed and not source.objectives[element.key]) then
            table.insert(columns, col)
        end
    end
    return columns
end

-- A second, opposite column makes zero net output an equality for an internal material.
---@param matrix Matrix Prepared simplex tableau
---@param source Matrix Recipe coefficients before external inputs were added
---@return boolean changed
local function addColumns(matrix, source)
    local position = #matrix.columns - #source.rows + 1
    local changed = false
    for col, element in ipairs(source.columns) do
        local produced, consumed = materialFlows(source.rows, col)
        if produced and consumed and source.objectives[element.key] == nil then
            table.insert(matrix.columns, position, table.deepcopy(element))
            for _, row in ipairs(matrix.rows) do
                table.insert(row, position, -(row[col + 1] or 0))
            end
            position = position + 1
            changed = true
        end
    end
    return changed
end

-- If exact balance is infeasible or degenerates, keep the ordinary surplus solution.
---@param solver SolverMatrixSimplex|SolverLinkedMatrixSimplex
---@param prepared Matrix
---@param source Matrix
---@return Matrix?
function Balance.try(solver, prepared, source)
    local matrix = solver:clone(prepared)
    if not addColumns(matrix, source) then return nil end
    return Pivot.solve(solver, matrix, 4 * (#matrix.columns + #matrix.rows))
end

---@param solver SolverMatrixSimplex|SolverLinkedMatrixSimplex
---@param matrix Matrix
---@return Matrix
function Balance.finalize(solver, matrix)
    matrix = solver:finalize(matrix)
    if matrix.temperature_routes then
        local balances = matrix.rows[#matrix.rows]
        TemperatureSupply.limitTransfers(matrix.temperature_routes, balances, matrix.objective_values, matrix.parameters)
    end
    return solver:apply_state(matrix)
end

return Balance
