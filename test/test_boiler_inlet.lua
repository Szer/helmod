local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 1e-6, label .. ": expected " .. expected .. ", got " .. actual)
end

local function plan(matrix)
    local model = Model.newModel()
    local block, boiler = ModelBuilder.addRecipeIntoProductionBlock(model, model.block_root, "water->steam#165", "boiler")
    block.solver = matrix
    Model.setFactory(boiler, "boiler", "normal", "coal")
    ModelCompute.update(model)
    block.products["steam#165"].input = 60
    ModelCompute.update(model)
    return model, block, boiler
end

local function supply(model, block, name)
    local _, recipe = ModelBuilder.addRecipeIntoProductionBlock(model, block, name, "recipe")
    Model.setFactory(recipe, "chemical-plant")
    return recipe
end

local function rates(block, boiler, steam_rate, coal_rate)
    near(block.products["steam#165"].amount, 60, "steam target")
    near(60 / boiler.factory.count, steam_rate, "steam per boiler per second")
    near(block.ingredients.coal.amount, coal_rate, "coal per second")
end

local function single(matrix)
    local model, block, boiler = plan(matrix)
    rates(block, boiler, 60, 0.45)
    local producer = supply(model, block, "test-warm-water")
    ModelCompute.update(model)
    near(producer.count, 0.06, "crafts supplying 100 °C water")
    rates(block, boiler, 138.461538, 0.195)
end

local function nestedSupply()
    local model, block, boiler = plan(false)
    local child = Model.newBlock(model, {name="test-warm-water", type="recipe"})
    child.parent_id, child.index = block.id, table_size(block.children)
    block.children[child.id], model.blocks[child.id] = child, child
    supply(model, child, "test-warm-water")
    ModelCompute.update(model)
    rates(block, boiler, 138.461538, 0.195)
    block.children[child.id] = nil
    model.blocks[child.id] = nil
    ModelCompute.update(model)
    rates(block, boiler, 60, 0.45)
end

local function mixed(matrix)
    local model, block, boiler = plan(matrix)
    local cold = supply(model, block, "test-cold-water-coproduct")
    local hot = supply(model, block, "test-hot-water-coproduct")
    ModelCompute.update(model)
    for _, mix in ipairs({
        {cold=3, hot=3, steam=83.720930, coal=0.3225},
        {cold=4.5, hot=1.5, steam=69.902913, coal=0.38625}
    }) do
        block.products["iron-plate"].input = mix.cold
        block.products["copper-plate"].input = mix.hot
        if not matrix then cold.production = mix.cold / 6 end
        ModelCompute.update(model)
        near(cold.count, mix.cold, "cold water per second")
        near(hot.count, mix.hot, "hot water per second")
        rates(block, boiler, mix.steam, mix.coal)
    end
end

local function ambiguous()
    local model, block, boiler = plan(false)
    supply(model, block, "test-cold-water-coproduct")
    supply(model, block, "test-hot-water-coproduct")
    ModelCompute.update(model)
    block.products["copper-plate"].input = 3
    block.products["iron-plate"].input = 6
    ModelCompute.update(model)
    assert(boiler.factory.boiler_inlet_ambiguous, "9 water/s for a 6 water/s boiler has several possible mixtures")
    rates(block, boiler, 60, 0.45)
    boiler.factory.boiler_inlet_temperature = 100
    ModelCompute.update(model)
    rates(block, boiler, 138.461538, 0.195)
    assert(ModelBuilder.copyFactory(boiler.factory).boiler_inlet_temperature == 100, "copy manual inlet")
    boiler.factory.boiler_inlet_temperature = nil
    ModelCompute.update(model)
    rates(block, boiler, 60, 0.45)
end

local function limitedSupply()
    local model, block, boiler = plan(false)
    local hot = supply(model, block, "test-warm-water")
    ModelBuilder.updateRecipeProduction(hot, 0.5)
    ModelCompute.update(model)
    near(hot.count, 0.03, "partial hot water supply")
    assert(boiler.factory.boiler_inlet_ambiguous, "remaining water has an unknown temperature")
    rates(block, boiler, 60, 0.45)

    block.by_factory = true
    ModelBuilder.updateRecipeProduction(hot, 1)
    ModelBuilder.updateFactoryNumber(boiler, 1)
    ModelBuilder.updateFactoryNumber(hot, 0.06)
    ModelCompute.update(model)
    assert(boiler.factory.boiler_inlet_ambiguous, "6 hot water/s only covers the initial cold-water estimate")
    rates(block, boiler, 60, 0.45)
    ModelBuilder.updateFactoryNumber(hot, 0)
    ModelCompute.update(model)
    near(boiler.factory.count, 1, "requested boiler")
    near(block.products["steam#165"].amount, 138.461538, "hot steam rate at a fixed boiler count")
    near(block.ingredients.coal.amount, 0.45, "coal for one full boiler")
end

local function invalidInlet()
    local model, block, boiler = plan(false)
    for _, temperature in ipairs({14, 101, 165}) do
        boiler.factory.boiler_inlet_temperature = temperature
        ModelCompute.update(model)
        assert(block.products["steam#165"].input == 60, "keep the requested steam target")
        near(block.products["steam#165"].amount, 0, "steam from an invalid inlet")
        near(block.ingredients.coal.amount, 0, "fuel for an idle boiler")
    end
end

local function temperatureLimits()
    for _, case in ipairs({
        {machine="test-hot-inlet-boiler", target=165, output=60, coal=0.195},
        {machine="test-low-target-boiler", target=99, output=0, coal=0}
    }) do
        local model = Model.newModel()
        local steam = "steam#" .. case.target
        local block, boiler = ModelBuilder.addRecipeIntoProductionBlock(model, model.block_root, "water->" .. steam, "boiler")
        Model.setFactory(boiler, case.machine, "normal", "coal")
        if case.machine == "test-hot-inlet-boiler" then
            ModelCompute.update(model)
            block.products[steam].input = 60
            ModelCompute.update(model)
            near(block.products[steam].amount, 0, "cold inlet below the boiler minimum")
        end
        supply(model, block, "test-warm-water")
        ModelCompute.update(model)
        block.products[steam].input = 60
        ModelCompute.update(model)
        assert(boiler.factory.boiler_inlet_auto == 100, case.machine .. " must retain its only supply temperature")
        assert(block.products[steam].input == 60)
        near(block.products[steam].amount, case.output, "steam produced by " .. case.machine)
        near(block.ingredients.coal.amount, case.coal, "coal used by " .. case.machine)
        if case.output == 0 then
            block.by_factory = true
            ModelBuilder.updateFactoryNumber(boiler, 1)
            ModelCompute.update(model)
            near(block.products[steam].amount, 0, "blocked boiler at fixed count")
            near(block.ingredients.coal.amount, 0, "idle boiler at fixed count")
        end
    end
end

local function check()
    for _, matrix in ipairs({false, true}) do
        single(matrix)
        mixed(matrix)
    end
    ambiguous()
    nestedSupply()
    limitedSupply()
    invalidInlet()
    temperatureLimits()
end

return function()
    local previous = User.getParameter("solver_selected")
    for _, solver in ipairs({defines.constant.solvers.default, defines.constant.solvers.matrix}) do
        User.setParameter("solver_selected", solver)
        check()
    end
    User.setParameter("solver_selected", previous)
end
