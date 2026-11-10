local FusionGenerator = {}

---@class FusionGeneratorRates
---@field power number Watts delivered by one generator at full load
---@field flow number Fluid units consumed and returned per second

---@class FusionGeneratorLimits
---@field powerLimit number Electrical output limit in watts
---@field flowLimit number Maximum fluid units per second
---@field minimumEnergy number Usable joules per unit at the lowest accepted inlet temperature
---@field maximumEnergy number Usable joules per unit at the highest accepted inlet temperature

---Use the lowest accepted inlet energy that can deliver full power within the flow limit.
---@param limits FusionGeneratorLimits
---@return FusionGeneratorRates
function FusionGenerator.fullLoad(limits)
    local powerLimit, flowLimit = limits.powerLimit, limits.flowLimit
    local minimumEnergy, maximumEnergy = limits.minimumEnergy, limits.maximumEnergy
    if flowLimit <= 0 or powerLimit <= 0 or maximumEnergy <= 0 or maximumEnergy < minimumEnergy then
        return {power=0, flow=0}
    end
    local power = math.min(powerLimit, flowLimit * maximumEnergy)
    local flow = flowLimit
    if minimumEnergy > 0 then flow = math.min(flow, power / minimumEnergy) end
    return {power=power, flow=flow}
end

return FusionGenerator
