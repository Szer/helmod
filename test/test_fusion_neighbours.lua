local function near(actual, expected, label)
    assert(math.abs(actual - expected) <= 1e-5 * math.max(1, expected), label .. ": expected " .. expected .. ", got " .. tostring(actual))
end

local function paired(matrix)
    local model = Model.newModel()
    local block, generator = ModelBuilder.addRecipeIntoProductionBlock(model, model.block_root, "fusion-generator", "energy")
    local _, reactor = ModelBuilder.addRecipeIntoProductionBlock(model, block, "fusion-reactor", "energy")
    block.solver = matrix
    ModelBuilder.updateChildContraint(generator, {type="master", item={name="fluoroketone-hot", type="fluid"}})
    ModelCompute.updateNow(model)
    block.products["fluoroketone-hot"].input = 8
    for _, neighbours in ipairs({0, 1, 2.5, 0}) do
        reactor.factory.fusion_neighbours = neighbours
        ModelCompute.updateNow(model)
        near(reactor.factory.count, 2, "reactor count")
        near(generator.factory.count, 4 * (1 + neighbours), "generator count")
        near(block.ingredients["fluoroketone-cold"].amount, 8, "cold coolant")
        near(block.products["fluoroketone-hot"].amount, 8, "returned coolant")
        near(block.ingredients["fusion-power-cell"].amount, 0.005, "fuel cells per second")
        near(reactor.factory.energy * reactor.factory.count, 20e6, "reactor electrical draw")
        near(block.products.energy.amount, 200e6 * (1 + neighbours) - 20e6, "net electrical output")
        near(generator.factory.count * generator.factory.energy, 200e6 * (1 + neighbours), "gross electrical output")
    end
end

local function external()
    local model = Model.newModel()
    local block, row = ModelBuilder.addRecipeIntoProductionBlock(model, model.block_root, "fusion-generator", "energy")
    row.factory.fusion_inlet_temperature = 2e6
    ModelCompute.updateNow(model)
    block.products.energy.input = 400e6
    ModelCompute.updateNow(model)
    near(row.factory.count, 8, "generator rating with external plasma")
    near(block.ingredients["fusion-plasma"].amount, 8, "external plasma at 2 million degrees")
end

local function mixed()
    local model = Model.newModel()
    local block = model.block_root
    local _, pair = ModelBuilder.addRecipeIntoProductionBlock(model, block, "fusion-reactor", "energy")
    local _, single = ModelBuilder.addRecipeIntoProductionBlock(model, block, "fusion-reactor", "energy")
    pair.factory.fusion_neighbours = 1
    block.by_factory = true
    ModelBuilder.updateFactoryNumber(pair, 2)
    ModelBuilder.updateFactoryNumber(single, 1)
    ModelCompute.updateNow(model)
    local plasma = block.products["fusion-plasma"]
    near(plasma.amount, 12, "mixed volume")
    near(plasma.fusion_temperature, 5e6 / 3, "flow-weighted exported plasma temperature")
    local _, generator = ModelBuilder.addRecipeIntoProductionBlock(model, block, "fusion-generator", "energy")
    ModelBuilder.updateFactoryNumber(generator, 10)
    ModelCompute.updateNow(model)
    near(generator.factory.fusion_inlet_auto, 5e6 / 3, "flow-weighted generator inlet")
    ModelBuilder.updateFactoryNumber(generator, 9)
    ModelCompute.updateNow(model)
    assert(generator.factory.fusion_inlet_ambiguous and generator.factory.fusion_inlet_auto == nil, "surplus supplies allow several routes")
    generator.factory.fusion_inlet_temperature = 2e6
    ModelCompute.updateNow(model)
    assert(not generator.factory.fusion_inlet_ambiguous, "manual routing overrides the mixture")
end

local function nested()
    local model = Model.newModel()
    local root, generator = ModelBuilder.addRecipeIntoProductionBlock(model, model.block_root, "fusion-generator", "energy")
    local child = Model.newBlock(model, {name="fusion-reactor", type="energy"})
    child.parent_id, child.index = root.id, table_size(root.children)
    root.children[child.id], model.blocks[child.id] = child, child
    local _, reactor = ModelBuilder.addRecipeIntoProductionBlock(model, child, "fusion-reactor", "energy")
    reactor.factory.fusion_neighbours = 1
    ModelCompute.updateNow(model)
    root.products["fluoroketone-hot"].input = 8
    ModelBuilder.updateChildContraint(generator, {type="master", item={name="fluoroketone-hot", type="fluid"}})
    ModelCompute.updateNow(model)
    near(generator.factory.count, 8, "linked nested supply")
    near(root.ingredients["fluoroketone-cold"].amount, 8, "nested coolant input")
    reactor.factory.fusion_neighbours = nil
    ModelCompute.updateNow(model)
    near(generator.factory.count, 4, "resetting a nested supply removes its bonus")
end

local function modded()
    local model = Model.newModel()
    local block, row = ModelBuilder.addRecipeIntoProductionBlock(model, model.block_root, "test-warm-reactor", "energy")
    block.by_factory = true
    row.factory.quality = "legendary"
    ModelBuilder.updateFactoryNumber(row, 1)
    for neighbours, temperature in ipairs({1750000, 2000000, 2000000}) do
        row.factory.fusion_neighbours = neighbours
        ModelCompute.updateNow(model)
        near(block.products["test-reactor-plasma"].fusion_temperature, temperature, "prototype target, bonus and maximum")
        near(block.products["test-reactor-plasma"].amount, 10, "legendary throughput")
        near(block.ingredients["fusion-power-cell"].amount, 0.00625, "fuel at 50% efficiency")
    end
end

return function()
    for _, solver in ipairs({defines.constant.solvers.default, defines.constant.solvers.matrix}) do
        User.setParameter("solver_selected", solver)
        for _, matrix in ipairs({false, true}) do paired(matrix) end
    end
    external()
    mixed()
    nested()
    modded()
end
