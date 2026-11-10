local ConstraintKind = require "math.balance.ConstraintKind"
local DefaultObjective = {}

---@enum ObjectivePriority
local priority = {ineligible=0, fallback=1, output=2, main=3}
DefaultObjective.priority = priority

---Pick a default from positive flows, preferring a selected main material and then a net output of a loop.
---@param key string
---@param amount number Per-unit output or consumption of the child
---@param netOutput boolean
---@param supplies table<string,boolean>? External inputs of a matrix block
---@param constraints table<string,{type:string}>?
---@return ObjectivePriority
function DefaultObjective.rank(key, amount, netOutput, supplies, constraints)
    if amount <= 0 or (supplies and supplies[key]) then return priority.ineligible end
    local constraint = constraints and constraints[key]
    if constraint then
        if constraint.type == ConstraintKind.master then return priority.main end
        return priority.ineligible
    end
    if supplies and netOutput then return priority.output end
    return priority.fallback
end

return DefaultObjective
