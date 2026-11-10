local MaterialBalance = require "math.balance.MaterialBalance"
local Profile = {}

---@param flows table<string, ProductData>
---@param additions table<string, ProductData>
---@param base number
---@param extra number
---@param divisor number
---@param driving boolean
local function combineFlows(flows, additions, base, extra, divisor, driving)
    for key, addition in pairs(additions) do
        local flow = flows[key]
        flow.amount = (flow.amount * base + addition.amount * extra) / divisor
        if driving then flow.state = MaterialBalance.surplusState(flow.state, flow.amount) end
    end
end

-- Descendant counts and flows are per unit of their parent block.
---@param block BlockData
---@param profile BlockData
---@param base number Existing units of this block
---@param extra number Additional units from the linked profile
---@param divisor number Units represented by the combined block
local function combineContents(block, profile, base, extra, divisor)
    for id, addition in pairs(profile.children) do
        local child = block.children[id]
        local existing = child.count * base
        local added = addition.count * extra
        local total = existing + added
        if added > 0 and child.class ~= "Recipe" and addition.class ~= "Recipe" and child.children and addition.children then
            combineContents(child, addition, existing, added, total)
        end
        child.count = total / divisor
    end
    combineFlows(block.products, profile.products, base, extra, divisor, block.by_product ~= false)
    combineFlows(block.ingredients, profile.ingredients, base, extra, divisor, block.by_product == false)
end

---@param block BlockData
---@param profile BlockData
---@param count number Solved units of the linked profile
function Profile.append(block, profile, count)
    if count <= 0 then return end
    local base = block.count
    if base == 0 then block.count = 1 end
    combineContents(block, profile, base, count, block.count)
end

return Profile
