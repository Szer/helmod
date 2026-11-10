local supply = require "math.balance.TemperatureSupply"

local function check(solver, simplex, first, second)
    User.setParameter("solver_selected", solver)
    local model = Model.newModel()
    local block = model.block_root
    block.solver = simplex
    for _, recipe in ipairs({"test-steam-" .. first, "test-steam-" .. second, "test-split-steam"}) do
        ModelBuilder.addRecipeIntoProductionBlock(model, block, recipe, "recipe")
    end
    ModelCompute.update(model)
    for _, targets in ipairs({
        {any=100, hot=0, stone=10, surplus=0},
        {any=0, hot=60, stone=10, surplus=40},
        {any=50, hot=50, stone=10, surplus=0}
    }) do
        block.products["iron-plate"].input = targets.any
        block.products["copper-plate"].input = targets.hot
        ModelCompute.update(model)
        assert(math.abs(block.ingredients.stone.amount - targets.stone) < 1e-7,
            solver .. " " .. first .. " hot demand " .. targets.hot .. ": got " .. block.ingredients.stone.amount .. " stone")
        -- The matrix solver can consume surplus steam by making extra iron plates.
        local excess = block.products["steam#125"].amount + block.products["iron-plate"].amount - targets.any
        assert(math.abs(excess - targets.surplus) < 1e-7)
        assert(math.abs(block.products["copper-plate"].amount - targets.hot) < 1e-7)
        assert(math.abs(block.products["steam#175"].amount) < 1e-7)
    end
end

local function sharedShortfall()
    local routes = {{source=1, inlet=2, row=1}, {source=1, inlet=3, row=2}}
    local balances = {-20, 17, 0}
    local transfers = {
        {recipe_count=50, coefficient=50, recipe_production=1},
        {recipe_count=50, coefficient=50, recipe_production=1}
    }
    supply.limitTransfers(routes, balances, {0, 5, 0}, transfers)
    assert(balances[1] == 0 and balances[2] == 5 and balances[3] == -8, "keep the export and show the remaining shortage")
    assert(transfers[1].recipe_count == 38 and transfers[2].recipe_count == 42, "only 80 units were supplied")
    assert(transfers[1].recipe_production == 38/50 and transfers[2].recipe_production == 42/50)
end

return function()
    sharedShortfall()
    for _, solver in ipairs({defines.constant.solvers.default, defines.constant.solvers.matrix}) do
        for _, simplex in ipairs({false, true}) do
            check(solver, simplex, "iron-plate", "copper-plate")
            check(solver, simplex, "copper-plate", "iron-plate")
        end
    end
end
