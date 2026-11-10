local MaterialBalance = {}

local zeroTolerance = 1e-10
local consumed, surplus = 2, 3

---@param balance number Signed net flow
---@return number
function MaterialBalance.amount(balance)
    local amount = math.abs(balance)
    if amount < zeroTolerance then return 0 end
    return amount
end

---@param state integer
---@param balance number Signed net flow
---@return integer
function MaterialBalance.surplusState(state, balance)
    if state == consumed or state == surplus then
        if balance >= zeroTolerance then return surplus end
        return consumed
    end
    return state
end

---Classify each material from its recipe coefficients and its final net flow.
---@param rows number[][]
---@param columnCount integer
---@return integer[]
function MaterialBalance.states(rows, columnCount)
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
    for column, state in ipairs(states) do
        states[column] = MaterialBalance.surplusState(state, balances[column] or 0)
    end
    return states
end

return MaterialBalance
