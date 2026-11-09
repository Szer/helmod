-- Compare the entire solved tree, including linked profiles and finalized summaries.
local function equal(expected, actual, path)
    if expected == actual then return end
    assert(type(expected) == "table" and type(actual) == "table", path .. ": " .. tostring(expected) .. " vs " .. tostring(actual))
    for key, value in pairs(expected) do equal(value, actual[key], path .. "." .. tostring(key)) end
    for key in pairs(actual) do assert(expected[key] ~= nil, path .. ": unexpected " .. tostring(key)) end
end

local function subBlock(model, parent, name)
    local block = Model.newBlock(model, {name=name, type="recipe"})
    block.parent_id, block.index = parent.id, table_size(parent.children)
    parent.children[block.id], model.blocks[block.id] = block, block
    local _, recipe = ModelBuilder.addRecipeIntoProductionBlock(model, block, name, "recipe")
    return block, recipe
end

local function checkConsumer()
    local model = Model.newModel()
    local root = model.block_root
    local _, scrap = ModelBuilder.addRecipeIntoProductionBlock(model, root, "scrap-recycling", "recipe")
    local consumer = subBlock(model, root, "cargo-landing-pad-recycling")
    consumer.consumer, consumer.by_product = true, false
    ModelBuilder.addRecipeIntoProductionBlock(model, consumer, "cargo-landing-pad", "recipe")
    ModelBuilder.updateChildContraint(consumer, {type="master", item={name="concrete", type="item"}})
    ModelCompute.update(model)
    root.products["steel-plate"].input = 10
    ModelCompute.update(model)
    assert(consumer.ingredients["steel-plate"].amount > 0)
    local reference = table.deepcopy(model)
    local expected = {}
    local values = {0.75, 0.5, 1, 0.85}
    for i, value in ipairs(values) do
        ModelBuilder.updateRecipeProduction(reference.block_root.children[scrap.id], value)
        ModelCompute.update(reference)
        expected[i] = table.deepcopy(reference.block_root)
    end
    for i, value in ipairs(values) do
        ModelBuilder.updateRecipeProduction(scrap, value)
        ModelCompute.update(model, root)
        equal(expected[i], root, "consumer")
    end
end

return function()
    local model = Model.newModel()
    local root = model.block_root
    local science = subBlock(model, root, "utility-science-pack")
    local frames, frame = subBlock(model, science, "flying-robot-frame")
    ModelBuilder.addRecipeIntoProductionBlock(model, frames, "electronic-circuit", "recipe")
    science.products_linked = {["electronic-circuit"]=true}
    frames.products_linked = {["electronic-circuit"]=true}
    local sibling, gear = subBlock(model, root, "balance-test-gear")
    ModelBuilder.addRecipeIntoProductionBlock(model, sibling, "balance-test-plate", "recipe")
    local consumer = subBlock(model, root, "iron-gear-wheel")
    consumer.consumer, consumer.by_product = true, false
    sibling.solver = true
    ModelCompute.update(model)
    sibling.products["iron-gear-wheel"].input = 10
    root.products["utility-science-pack"].input = 60
    root.products["electronic-circuit"].input = 5
    ModelCompute.update(model)
    assert(math.abs(sibling.products["iron-gear-wheel"].amount - 10) < 1e-8)
    local reference = table.deepcopy(model)
    local percentages = {0.85, 0.95, 1, 0.75}
    local function edit(sheet, value)
        if value == 1 then
            sheet.blocks[sibling.id].children[gear.id].factory.quality = "uncommon"
            sheet.blocks[consumer.id].by_factory = true
        end
        ModelBuilder.updateRecipeProduction(sheet.blocks[frames.id].children[frame.id], value)
    end
    local expected = {}
    for index, value in ipairs(percentages) do
        edit(reference, value)
        ModelCompute.update(reference)
        expected[index] = table.deepcopy(reference.block_root)
    end
    local simplex = SolverLinkedMatrixSimplex.solve_matrix
    local solves = 0
    SolverLinkedMatrixSimplex.solve_matrix = function(...)
        solves = solves + 1
        return simplex(...)
    end
    for index, value in ipairs(percentages) do
        edit(model, value)
        solves = 0
        ModelCompute.update(model, frames)
        equal(expected[index], model.block_root, "root")
        assert(math.abs(root.products["electronic-circuit"].amount - 5) < 1e-8)
        if index == 1 or index == 3 then
            assert(solves > 0, "cold or changed matrix must solve")
        else
            assert(solves == 0, "unchanged sibling matrix must be reused")
        end
    end
    SolverLinkedMatrixSimplex.solve_matrix = simplex
    local original = User.getPreferenceSetting("one_block_factor_enable")
    for _, factor in ipairs({true, false}) do
        User.setPreference("one_block_factor_enable", nil, factor)
        checkConsumer()
    end
    User.setPreference("one_block_factor_enable", nil, original)
end
