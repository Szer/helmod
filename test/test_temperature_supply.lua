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

return function()
    for _, solver in ipairs({defines.constant.solvers.default, defines.constant.solvers.matrix}) do
        for _, simplex in ipairs({false, true}) do
            check(solver, simplex, "iron-plate", "copper-plate")
            check(solver, simplex, "copper-plate", "iron-plate")
        end
    end
end
