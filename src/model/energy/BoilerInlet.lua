local BoilerInlet = {}

---@class BoilerSupply
---@field volumes table<number, number> Fluid units supplied at each temperature in °C
---@field demand number Total fluid units consumed in the block

---@param supply BoilerSupply
---@param demand number Fluid units consumed by this row
---@param trialMixture? boolean Propose a mixture before checking the resulting generator demand
---@param relativeTolerance? number Relative precision of the flow rates
---@return number? temperature
---@return boolean ambiguous
function BoilerInlet.resolve(supply, demand, trialMixture, relativeTolerance)
    local volume, heat, temperatures = 0, 0, 0
    local suppliedTemperature
    for temperature, amount in pairs(supply.volumes) do
        if amount > 0 then
            suppliedTemperature = temperature
            volume = volume + amount
            heat = heat + temperature * amount
            temperatures = temperatures + 1
        end
    end
    if temperatures == 0 then return nil, false end
    local tolerance = (relativeTolerance or 1e-8) * math.max(volume, supply.demand)
    if temperatures == 1 and volume + tolerance >= supply.demand then
        return suppliedTemperature, false
    end
    if demand > 0 and (math.abs(volume - demand) <= tolerance or (trialMixture and temperatures > 1))
        and math.abs(supply.demand - demand) <= tolerance then
        return heat / volume, false
    end
    return nil, true
end

---@param power number Effective heating power in watts
---@param capacity number Joules per unit of fluid per °C
---@param inlet number °C
---@param minimum number °C, inclusive
---@param maximum number °C, inclusive
---@param target number °C
---@return number units_per_second
function BoilerInlet.rate(power, capacity, inlet, minimum, maximum, target)
    if inlet < minimum or inlet > maximum or inlet >= target or capacity <= 0 then return 0 end
    return power / (capacity * (target - inlet))
end

return BoilerInlet
