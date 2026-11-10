local RowFlows = {}

---@class SolverMaterial
---@field name string
---@field type string|integer
---@field quality? string
---@field temperature? number
---@field minimum_temperature? number
---@field maximum_temperature? number

---@class SolverMaterialFlow : SolverMaterial
---@field amount number

---@param flows table<string, SolverMaterialFlow>
---@param key string
---@param material SolverMaterial
---@param amount number
function RowFlows.add(flows, key, material, amount)
    local existing = flows[key]
    if existing then
        existing.amount = existing.amount + amount
    else
        flows[key] = {
            name=material.name, type=material.type, quality=material.quality, amount=amount,
            temperature=material.temperature, minimum_temperature=material.minimum_temperature,
            maximum_temperature=material.maximum_temperature
        }
    end
end

return RowFlows
