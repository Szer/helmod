-- Adding a water supply must not change the oil balance of the refinery.
return function()
    for _, solver in ipairs({defines.constant.solvers.default, defines.constant.solvers.matrix}) do
        User.setParameter("solver_selected", solver)
        local factory_model = Model.newModel()
        local factory_block = factory_model.block_root
        factory_block.by_factory = true
        local _, cracking = ModelBuilder.addRecipeIntoProductionBlock(factory_model, factory_block, "light-oil-cracking", "recipe")
        local _, refinery = ModelBuilder.addRecipeIntoProductionBlock(factory_model, factory_block, "advanced-oil-processing", "recipe")
        ModelBuilder.updateFactoryNumber(refinery, 1)
        ModelCompute.update(factory_model)
        assert(math.abs(cracking.count - 0.3) < 1e-8, solver .. ": cracking should consume 9 light oil/s")
        assert(math.abs(factory_block.products["light-oil"].amount) < 1e-8)
        assert(math.abs(factory_block.products["petroleum-gas"].amount - 17) < 1e-8)
        local _, second = ModelBuilder.addRecipeIntoProductionBlock(factory_model, factory_block, "advanced-oil-processing", "recipe")
        ModelBuilder.updateFactoryNumber(second, 1)
        ModelCompute.update(factory_model)
        assert(math.abs(cracking.count - 0.6) < 1e-8, solver .. ": both fixed refineries must supply the row")
        assert(math.abs(factory_block.products["petroleum-gas"].amount - 34) < 1e-8)

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

    -- A parent sheet needs both the main output and a linked output of the same block.
    User.setParameter("solver_selected", defines.constant.solvers.default)
    local model = Model.newModel()
    local root = model.block_root
    ModelBuilder.addRecipeIntoProductionBlock(model, root, "solid-fuel-from-petroleum-gas", "recipe")
    ModelBuilder.addRecipeIntoProductionBlock(model, root, "lubricant", "recipe")
    local oil = Model.newBlock(model, {name="light-oil-cracking", type="recipe"})
    oil.parent_id, oil.index, oil.solver = root.id, 2, true
    model.blocks[oil.id], root.children[oil.id] = oil, oil
    for _, name in ipairs({"light-oil-cracking", "heavy-oil-cracking", "coal-liquefaction", "ice-melting"}) do
        ModelBuilder.addRecipeIntoProductionBlock(model, oil, name, "recipe")
    end
    oil.products_linked = {["heavy-oil"]=true}
    ModelCompute.update(model)
    root.products.lubricant.input = 50
    for _, demand in ipairs({10, 0.5, 10}) do
        root.products["solid-fuel"].input = demand
        ModelCompute.update(model)
        -- Heavy oil production alone yields 17.95 petroleum; any excess below that is unavoidable.
        local gas = math.max(20 * demand, 50 * (10 + 20 * 20 / 30) / 65)
        for name, expected in pairs({["light-oil"]=0, ["petroleum-gas"]=gas, ["heavy-oil"]=50}) do
            assert(math.abs(oil.products[name].amount - expected) < 1e-8, "linked block output: " .. name)
        end
        assert(math.abs(root.products["petroleum-gas"].amount - (gas - 20 * demand)) < 1e-8)
        if demand == 10 then
            local expected = {["coal-liquefaction"]=21, ["heavy-oil-cracking"]=11, ["light-oil-cracking"]=16}
            for _, recipe in pairs(oil.children) do
                if expected[recipe.name] then assert(math.ceil(recipe.factory.count) == expected[recipe.name], recipe.name) end
            end
        end
    end
end
