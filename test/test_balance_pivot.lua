local Balance = require "math.SimplexBalance"

return function()
    -- The second column is also an internal product, so the balance pass runs.
    local source = {rows={{1}, {-1}}, columns={{key="internal"}}, objectives={}}
    local function check(rows, expected, feasible)
        local matrix = {rows=rows, columns={{}, {}, {}, {}, {}}}
        local calls = 0
        local solver = {}
        function solver:clone(value) return table.deepcopy(value) end
        function solver:pivot(value, row, column)
            calls = calls + 1
            assert(expected and row == expected[1] and column == expected[2], "unexpected pivot coordinates")
            for i = 1, #value.columns do value.rows[#value.rows][i] = 0 end
            return value
        end
        local result = Balance.try(solver, matrix, source)
        assert((result ~= nil) == feasible, "wrong balance outcome")
        assert(calls == (expected and 1 or 0), "wrong pivot count")
    end
    -- Highest objective coefficient enters; smallest RHS/coefficient ratio leaves.
    check({{4,0,1,0,0},{6,0,3,0,0},{100,0,5,4,0}}, {2,3}, true)
    -- Equal objective and equal ratio retain the first eligible column and row.
    check({{4,0,2,1,0},{6,0,3,1,0},{0,0,4,4,0}}, {1,3}, true)
    check({{2,0,1,0,0},{4,0,2,0,0},{10,0,1e-8,0,0}}, nil, true)
    check({{2,0,1e-8,0,0},{4,0,-2,0,0},{0,0,1,0,0}}, nil, false)
end
