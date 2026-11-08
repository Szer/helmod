-- Adding a water supply must not change the oil balance of the refinery.
return function()
    for _, solver in ipairs({defines.constant.solvers.default, defines.constant.solvers.matrix}) do
        User.setParameter("solver_selected", solver)
        local model = Model.newModel()
        local block = model.block_root
        block.solver = true
        for _, name in ipairs({"light-oil-cracking", "heavy-oil-cracking", "coal-liquefaction"}) do
            ModelBuilder.addRecipeIntoProductionBlock(model, block, name, "recipe")
        end
        ModelBuilder.addRecipeIntoProductionBlock(model, block, "water->steam#165", "boiler")
        ModelCompute.update(model)
        block.products["petroleum-gas"].input = 100
        ModelCompute.update(model)
        local counts = {}
        for id, recipe in pairs(block.children) do
            assert(recipe.count > 0, solver .. ": expected active " .. recipe.name)
            counts[id] = recipe.count
        end
        local _, ice = ModelBuilder.addRecipeIntoProductionBlock(model, block, "ice-melting", "recipe")
        ModelCompute.update(model)
        assert(ice.count > 0)
        for id, count in pairs(counts) do
            assert(math.abs(block.children[id].count - count) < 1e-8, solver .. ": changed " .. block.children[id].name)
        end
        for name, expected in pairs({["petroleum-gas"]=100, ["heavy-oil"]=0, ["light-oil"]=0, water=0}) do
            assert(math.abs(block.products[name].amount - expected) < 1e-8, solver .. ": unexpected " .. name)
        end
        local loop = Model.newModel()
        local cycle = loop.block_root
        cycle.solver = true
        ModelBuilder.addRecipeIntoProductionBlock(loop, cycle, "balance-test-gear", "recipe")
        ModelBuilder.addRecipeIntoProductionBlock(loop, cycle, "balance-test-plate", "recipe")
        ModelCompute.update(loop)
        cycle.products["iron-gear-wheel"].input = 10
        ModelCompute.update(loop)
        assert(math.abs(cycle.products["iron-gear-wheel"].amount - 10) < 1e-8)
        local surplus = cycle.products["iron-plate"].amount + cycle.products["copper-plate"].amount
        assert(math.abs(surplus - 10) < 1e-8, solver .. ": unavoidable surplus must remain visible")
    end
end
