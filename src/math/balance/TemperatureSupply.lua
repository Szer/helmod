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

---@class TemperatureRoute
---@field source integer Supplied temperature column
---@field inlet integer Compatible ingredient column
---@field row integer Unit-for-unit transfer row

---Keep unmet demand at a real inlet when a virtual transfer exceeds the supplied fluid.
---@param routes TemperatureRoute[]
---@param balances number[] Net quantities after replaying all recipes
---@param objectives number[] Requested quantities by column
---@param parameters {recipe_count:number, recipe_production:number, coefficient:number}[]
function TemperatureSupply.limitTransfers(routes, balances, objectives, parameters)
    ---@param route TemperatureRoute
    ---@param limit number
    local function reduce(route, limit)
        local deficit = -balances[route.source]
        if deficit <= 0 then return end
        local transfer = parameters[route.row]
        local missing = math.min(deficit, transfer.recipe_count, limit)
        if missing <= 0 then return end
        transfer.recipe_count = transfer.recipe_count - missing
        if transfer.coefficient > 0 then
            transfer.recipe_production = transfer.recipe_count / transfer.coefficient
        end
        balances[route.source] = balances[route.source] + missing
        balances[route.inlet] = balances[route.inlet] - missing
    end

    -- Release unused transfers first, then preserve earlier allocations when several inlets compete.
    for _, route in ipairs(routes) do
        reduce(route, balances[route.inlet] - objectives[route.inlet])
    end
    for index = #routes, 1, -1 do
        reduce(routes[index], math.huge)
    end
end

return TemperatureSupply
