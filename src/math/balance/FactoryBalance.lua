local FactoryBalance = {}

---Apply the additional crafts supported by the current balance above a fixed factory row.
---@param row number[] Material quantities per craft
---@param balance number[] Net material quantities for the planning period
---@param parameters {recipe_production:number, recipe_count:number, coefficient:number, unlinked:integer?}
---@param pivot integer Material column, or zero when no material matches
function FactoryBalance.consume(row, balance, parameters, pivot)
    if pivot == 0 then return end
    local coefficient
    if parameters.unlinked == 1 then
        coefficient = 1 - parameters.coefficient
    else
        if row[pivot] == 0 then return end
        coefficient = -balance[pivot] / row[pivot]
    end
    if coefficient <= 0 then return end
    local crafts = parameters.recipe_production * coefficient
    parameters.coefficient = parameters.coefficient + coefficient
    parameters.recipe_count = parameters.recipe_count + crafts
    for column, quantity in ipairs(row) do
        balance[column] = balance[column] + crafts * quantity
    end
end

return FactoryBalance
