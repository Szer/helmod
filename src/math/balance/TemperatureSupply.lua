local TemperatureSupply = {}

---@param product SolverMaterial
---@param ingredient SolverMaterial
---@return boolean
function TemperatureSupply.compatible(product, ingredient)
    local temperature = product.temperature
    local minimum, maximum = ingredient.minimum_temperature, ingredient.maximum_temperature
    if minimum or maximum then
        temperature = temperature or 25
        return (not minimum or temperature >= minimum) and (not maximum or temperature <= maximum)
    end
    local exact = ingredient.temperature
    if temperature == nil and exact == nil then return false end
    return temperature == nil or exact == nil or temperature == exact
end

---@class TemperatureTransfer
---@field output integer Column supplying this transfer
---@field yields table<integer,number> Compatible units per supplier run, by column

---Reserve temperature-specific targets before assigning the remaining fluid demand.
---@param transfer TemperatureTransfer
---@param balance number[] Net quantities before the supplier runs
---@param demand integer Column accepting the compatible temperatures
---@return number quantity
function TemperatureSupply.quantity(transfer, balance, demand)
    local required = -balance[demand]
    local totalYield, stock, runs = 0, 0, 0
    for column, yield in pairs(transfer.yields) do
        totalYield = totalYield + yield
        if column ~= demand then
            stock = stock + balance[column]
            runs = math.max(runs, -balance[column] / yield)
        end
    end
    runs = math.max(runs, (required - stock) / totalYield)
    local available = balance[transfer.output] + runs * transfer.yields[transfer.output]
    return math.max(0, math.min(required, available))
end

return TemperatureSupply
