local Pivot = {}

---@class BalanceTableau
---@field columns table[]
---@field rows number[][]

---@class BalancePivotSolver<T>
---@field pivot fun(self: BalancePivotSolver<T>, matrix: T, row: integer, column: integer, preserve_precision?: boolean): T

---@class PivotRow
---@field row integer

---@class PivotColumn
---@field column integer

---@class SelectedPivot
---@field kind "pivot"
---@field row PivotRow
---@field column PivotColumn

---@alias PivotSelection SelectedPivot | {kind: "finished"} | {kind: "blocked"}

-- Column one is the current right-hand side, transformed by each pivot.
---@param matrix BalanceTableau
---@return PivotSelection
local function nextPivot(matrix)
    local objective = matrix.rows[#matrix.rows]
    local best = 1e-8
    local column
    for i = 2, #matrix.columns do
        if objective[i] > best then
            column, best = i, objective[i]
        end
    end
    if column == nil then return {kind="finished"} end
    local row, ratio
    for i = 1, #matrix.rows - 1 do
        local values = matrix.rows[i]
        if values[column] > 1e-8 then
            local candidate = values[1] / values[column]
            if ratio == nil or candidate < ratio then
                row, ratio = i, candidate
            end
        end
    end
    if row == nil then return {kind="blocked"} end
    return {kind="pivot", row={row=row}, column={column=column}}
end

-- Small coefficients from earlier pivots can contribute to later material balances.
---@generic T: BalanceTableau
---@param solver BalancePivotSolver<T>
---@param matrix T
---@param row PivotRow
---@param column PivotColumn
---@return T
local function apply(solver, matrix, row, column)
    return solver:pivot(matrix, row.row, column.column, true)
end

---@generic T: BalanceTableau
---@param solver BalancePivotSolver<T>
---@param matrix T
---@param limit integer
---@return T?
function Pivot.solve(solver, matrix, limit)
    for _ = 1, limit do
        local choice = nextPivot(matrix)
        if choice.kind == "finished" then return matrix end
        if choice.kind == "blocked" then return nil end
        matrix = apply(solver, matrix, choice.row, choice.column)
    end
    return nil
end

return Pivot
