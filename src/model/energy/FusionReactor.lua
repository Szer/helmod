local FusionReactor = {}

---@param fluid {default_temperature:number, max_temperature:number}
---@param target number? Outlet temperature of an isolated reactor in °C
---@param bonus number Prototype bonus per active neighbour
---@param neighbours number Average number of active neighbours per operating reactor
---@return number temperature °C
function FusionReactor.temperature(fluid, target, bonus, neighbours)
    local isolated = target or fluid.default_temperature
    return math.min(fluid.max_temperature, isolated + fluid.default_temperature * bonus * neighbours)
end

---@param fluid {default_temperature:number, heat_capacity:number}
---@param flow number Units of coolant per second
---@param effectivity number Burner efficiency
---@return number watts Fuel energy consumed per second
function FusionReactor.fuelPower(fluid, flow, effectivity)
    return flow * fluid.default_temperature * fluid.heat_capacity / effectivity
end

return FusionReactor
