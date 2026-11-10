local ReactorNeighbour = require "gui.controls.ReactorNeighbour"
local function near(actual, expected)
    assert(math.abs(actual - expected) < 1e-6, "expected " .. expected .. ", got " .. actual)
end

local function checkElectricityDemand()
    for _, solver in ipairs({defines.constant.solvers.default, defines.constant.solvers.matrix}) do
        User.setParameter("solver_selected", solver)
        local model = Model.newModel()
        local root, gears = ModelBuilder.addRecipeIntoProductionBlock(model, model.block_root, "iron-gear-wheel", "recipe")
        Model.setFactory(gears, "assembling-machine-1")
        local supply = Model.newBlock(model, {name="steam-engine", type="energy"})
        supply.parent_id, supply.index, supply.unlinked = root.id, 1, false
        root.children[supply.id], model.blocks[supply.id] = supply, supply
        local _, engine = ModelBuilder.addRecipeIntoProductionBlock(model, supply, "steam-engine", "energy")
        for _, seconds in ipairs({1, 60}) do
            model.time = seconds
            ModelCompute.update(model)
            for _, rate in ipairs({2, 4, 0}) do
                root.products["iron-gear-wheel"].input = rate * seconds
                ModelCompute.update(model)
                near(gears.factory.count_deep, rate)
                near(engine.factory.count_deep, rate * 77500 / 900000)
            end
        end
        model.time = 1
        root.products["iron-gear-wheel"].input = 2
        model.parameters.effects.consumption = 0.5
        ModelCompute.update(model)
        near(engine.factory.count_deep, 2 * (75000 * 1.5 + 2500) / 900000)
        Model.setFactory(gears, "assembling-machine-2")
        local beacon = Model.addBeacon(gears, "beacon", "normal", 0, 1, 0)
        ModelBuilder.setBeaconModulePriority(beacon, gears, {{name="speed-module", quality="normal", amount=1}})
        ModelCompute.update(model)
        near(engine.factory.count_deep, (2 * 0.5 / 0.75) * (150000 * 1.5 + 5000 + 480000) / 900000)
    end
end

local function checkFusionGenerator()
    local fusion = Model.newModel()
    local factory, load = ModelBuilder.addRecipeIntoProductionBlock(fusion, fusion.block_root, "iron-gear-wheel", "recipe")
    Model.setFactory(load, "assembling-machine-1")
    local _, plant = ModelBuilder.addRecipeIntoProductionBlock(fusion, factory, "fusion-generator", "energy")
    ModelCompute.update(fusion)
    factory.products["iron-gear-wheel"].input = 50000000 / 77500
    ModelBuilder.updateChildContraint(plant, {type="master", item={name="energy", type="energy"}})
    ModelCompute.update(fusion)
    local flow = prototypes.entity["fusion-generator"].get_fluid_usage_per_tick() * 60
    near(plant.factory.count_deep, 1)
    near(factory.products["fluoroketone-hot"].amount, flow)
    near(factory.ingredients["fusion-plasma"].amount, flow)
    ModelBuilder.updateChildContraint(plant, {type="master", item={name="energy", type="energy"}})
    ModelBuilder.updateChildContraint(plant, {type="master", item={name="fluoroketone-hot", type="fluid"}})
    factory.products["fluoroketone-hot"].input = 2 * flow
    ModelCompute.update(fusion)
    near(plant.factory.count_deep, 2)
    near(factory.products.energy.amount, 50000000)
    near(factory.ingredients["fusion-plasma"].amount, 2 * flow)
end

local function checkFusionGeneratorLimits()
    for _, case in ipairs({
        {name="test-capped-turbine", fluid="steam", power=4.5e6, flow=90},
        {name="test-hot-turbine", fluid="steam", power=3.6e6, flow=45},
        {name="test-unusable-turbine", fluid="steam", power=0, flow=0},
        {name="test-inefficient-turbine", fluid="steam", power=4.5e6, flow=90},
        {name="test-burning-turbine", fluid="test-turbine-fuel", power=9e6, flow=45}
    }) do
        local model = Model.newModel()
        local block, row = ModelBuilder.addRecipeIntoProductionBlock(model, model.block_root, case.name, "energy")
        ModelCompute.update(model)
        block.products.energy.input = case.power > 0 and case.power or 9e6
        ModelCompute.update(model)
        near(row.factory.count, case.power > 0 and 1 or 0)
        near(block.products.energy.amount, case.power)
        near(row.factory.energy, case.power)
        near(block.ingredients[case.fluid].amount, case.flow)
        near(block.products.water.amount, case.flow)
    end
end

local function checkTurbineByproduct()
    local mixed = Model.newModel()
    local plan, consumer = ModelBuilder.addRecipeIntoProductionBlock(mixed, mixed.block_root, "iron-gear-wheel", "recipe")
    Model.setFactory(consumer, "assembling-machine-1")
    local generator = Model.newBlock(mixed, {name="steam-engine", type="energy"})
    generator.parent_id, generator.index, generator.unlinked = plan.id, 1, false
    plan.children[generator.id], mixed.blocks[generator.id] = generator, generator
    local _, steam = ModelBuilder.addRecipeIntoProductionBlock(mixed, generator, "steam-engine", "energy")
    local _, expansion = ModelBuilder.addRecipeIntoProductionBlock(mixed, generator, "energy-test-expansion", "recipe")
    Model.setFactory(expansion, "energy-test-turbine")
    ModelCompute.update(mixed)
    generator.products.energy.input = 900000
    plan.products["iron-gear-wheel"].input = 900000 / 77500
    ModelBuilder.updateChildContraint(generator, {type="master", item={name="energy", type="energy"}})
    ModelCompute.update(mixed)
    near(steam.factory.count_deep, 1)
    near(plan.products.water.amount, 10)
    near(plan.ingredients["petroleum-gas"].amount, 15)
    near(plan.ingredients.energy.amount, 0)

    ModelBuilder.updateChildContraint(generator, {type="master", item={name="energy", type="energy"}})
    ModelBuilder.updateChildContraint(generator, {type="master", item={name="water", type="fluid"}})
    plan.products.water.input = 20
    ModelCompute.update(mixed)
    near(steam.factory.count_deep, 2)
    near(plan.products.energy.amount, 900000)
    near(plan.ingredients["petroleum-gas"].amount, 30)

    ModelBuilder.updateChildContraint(generator, {type="master", item={name="water", type="fluid"}})
    plan.products.water.input = nil
    local _, vent = ModelBuilder.addRecipeIntoProductionBlock(mixed, plan, "energy-test-vent", "recipe")
    Model.setFactory(vent, "energy-test-turbine")
    ModelCompute.update(mixed)
    near(steam.factory.count_deep, 1)
    near(vent.count_deep, 1)
    near(plan.products.water.amount, 0)

    Model.setFactory(vent, "chemical-plant")
    ModelCompute.update(mixed)
    near(vent.count_deep, 1)
    near(plan.products.water.amount, 0)
    near(plan.ingredients.energy.amount, 217000)

    plan.solver = true
    ModelCompute.update(mixed)
    local turbines = 900000 / (900000 - 217000)
    near(steam.factory.count_deep, turbines)
    near(vent.count_deep, turbines)
    near(plan.products.water.amount, 0)
    near(plan.ingredients.energy.amount, 0)
end

return function()
    assert(ReactorNeighbour.available(prototypes.entity["nuclear-reactor"]))
    assert(not ReactorNeighbour.available(prototypes.entity["heating-tower"]))
    checkElectricityDemand()
    User.setParameter("solver_selected", defines.constant.solvers.default)
    checkFusionGenerator()
    checkFusionGeneratorLimits()
    checkTurbineByproduct()
end
