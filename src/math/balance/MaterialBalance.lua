local MaterialBalance = {}

local zeroTolerance = 1e-10
local consumed, surplus = 2, 3

---@param balance number Signed net flow
---@return number
function MaterialBalance.normalize(balance)
    if math.abs(balance) < zeroTolerance then return 0 end
    return balance
end

---@param state number
---@param balance number Normalized signed net flow
---@return number
local function surplusState(state, balance)
    if state == consumed or state == surplus then
        if balance > 0 then return surplus end
        return consumed
    end
    return state
end

---@param flow {amount:number, state:number}
---@param amount number Combined or scaled block flow
---@param driving boolean Whether this side can acquire a surplus when combining profiles
function MaterialBalance.setFlow(flow, amount, driving)
    flow.amount = MaterialBalance.normalize(amount)
    if driving or flow.state == surplus then flow.state = surplusState(flow.state, flow.amount) end
end

---Normalize the final balance row and classify each material from its recipe coefficients and net flow.
---@param rows number[][]
---@param columnCount integer
---@return number[]
function MaterialBalance.finalize(rows, columnCount)
    local states = {}
    for row = 1, #rows - 1 do
        for column = 1, columnCount do
            local coefficient = rows[row][column] or 0
            local state = states[column] or 0
            if coefficient < 0 then
                state = consumed
            elseif coefficient > 0 and state ~= consumed then
                state = 1
            end
            states[column] = state
        end
    end
    local balances = rows[#rows]
    for column, value in ipairs(balances) do
        balances[column] = MaterialBalance.normalize(value)
        if states[column] then states[column] = surplusState(states[column], balances[column]) end
    end
    return states
end

return MaterialBalance
