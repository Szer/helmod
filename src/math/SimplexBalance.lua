local Balance = {}

-- A second, opposite column makes zero net output an equality for an internal material.
---@param matrix Matrix Prepared simplex tableau
---@param source Matrix Recipe coefficients before external inputs were added
---@return boolean changed
local function addColumns(matrix, source)
    local position = #matrix.columns - #source.rows + 1
    local changed = false
    for col, element in ipairs(source.columns) do
        local produced, consumed = false, false
        for _, row in ipairs(source.rows) do
            local value = row[col] or 0
            produced = produced or value > 0
            consumed = consumed or value < 0
        end
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

-- Column one is the current right-hand side, transformed by each pivot.
---@param matrix Matrix
---@return integer? col
---@return integer? row
local function nextPivot(matrix)
    local objective = matrix.rows[#matrix.rows]
    local best = 1e-8
    local column
    for i = 2, #matrix.columns do
        if objective[i] > best then
            column, best = i, objective[i]
        end
    end
    if column == nil then return nil, nil end
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
    return column, row
end

-- If exact balance is infeasible or degenerates, keep the ordinary surplus solution.
---@param solver SolverMatrix|SolverLinkedMatrix
---@param prepared Matrix
---@param source Matrix
---@return Matrix?
function Balance.try(solver, prepared, source)
    local matrix = solver:clone(prepared)
    if not addColumns(matrix, source) then return nil end
    for _ = 1, 4 * (#matrix.columns + #matrix.rows) do
        local col, row = nextPivot(matrix)
        if col == nil then return matrix end
        if row == nil then return nil end
        matrix = solver:pivot(matrix, row, col)
    end
    return nil
end

return Balance
