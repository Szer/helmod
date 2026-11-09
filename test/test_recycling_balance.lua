local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 1e-6, label .. ": expected " .. expected .. ", got " .. actual)
end

local grades = {"normal", "uncommon", "rare", "epic", "legendary"}
local target = "copper-plate#legendary"

local function machine(model, block, quality, recycle)
    local name = recycle and "copper-cable-recycling" or "copper-cable"
    local _, recipe = ModelBuilder.addRecipeIntoProductionBlock(model, block, name, "recipe")
    recipe.quality = quality
    Model.setFactory(recipe, recycle and "recycler" or "electromagnetic-plant", "legendary")
    ModelBuilder.addFactoryModule(recipe, "quality-module-3", "legendary", true)
    return recipe
end

local function consumer(model)
    local root = model.block_root
    local child = Model.newBlock(model, {name="copper-cable",type="recipe"})
    child.parent_id, child.index = root.id, table_size(root.children)
    child.consumer, child.by_product = true, false
    model.blocks[child.id], root.children[child.id] = child, child
    return child
end

local function checkBalances(block)
    near(block.ingredients["copper-plate"].amount, 75.62022374546, "normal plate supply")
    for key, p in pairs(block.products) do near(p.amount, key == target and 1 or 0, key) end
    for key, p in pairs(block.ingredients) do
        if key ~= "energy" and key ~= "copper-plate" then near(p.amount, 0, key) end
    end
end

local function buildLoop()
    local model = Model.newModel()
    local block = model.block_root
    model.time, block.solver = 1, true
    local plants, recyclers = {}, {}
    for i, quality in ipairs(grades) do
        recyclers[i] = machine(model, block, quality, true)
        if quality ~= "legendary" then plants[i] = machine(model, block, quality, false) end
    end
    ModelCompute.update(model)
    block.products[target].input = 1
    return model, plants, recyclers
end

local function check()
    local previous = User.getParameter("solver_selected")
    for _, solver in ipairs({defines.constant.solvers.default, defines.constant.solvers.matrix}) do
        User.setParameter("solver_selected", solver)
        local model, plants, recyclers = buildLoop()
        local block = model.block_root
        block.matrix_supplies = {["copper-plate"]=true, [target]=true}
        ModelCompute.update(model)
        checkBalances(block)
        -- Per plate craft: 3 cables, 31.25% upgrade. Per cable recycled: 1/8 plate, 25% upgrade.
        local craftRates = {93.747105467, 15.934738024, 7.059928865, 2.650585638}
        local recyclingRates = {193.353405025, 111.964517411, 35.915950514, 13.559132581, 3.384068447}
        for i, recipe in ipairs(plants) do near(recipe.count, craftRates[i], grades[i] .. " crafting") end
        for i, recipe in ipairs(recyclers) do near(recipe.count, recyclingRates[i], grades[i] .. " recycling") end
        local unused = machine(model, block, "legendary", false)
        ModelCompute.update(model)
        checkBalances(block)
        near(unused.count, 0, "an external feed cannot satisfy its own output target")
        local imported = Model.newModel()
        imported.time = model.time
        ModelBuilder.copyModel(imported, Converter.read(Converter.write(model)))
        ModelCompute.update(imported)
        checkBalances(imported.block_root)
    end

    User.setParameter("solver_selected", defines.constant.solvers.default)
    local model = Model.newModel()
    model.time = 1
    local root = model.block_root
    machine(model, root, "normal", true)
    machine(model, root, "normal", false)
    machine(model, consumer(model), "uncommon", false)
    machine(model, consumer(model), "uncommon", true)
    ModelCompute.update(model)
    root.products[target].input = 1
    ModelCompute.update(model)
    near(root.products["copper-plate#uncommon"].amount, 1401.29616477, "sequential consumers")
    root.solver = true
    root.matrix_supplies = {["copper-plate"]=true}
    ModelCompute.update(model)
    near(root.products[target].amount, 1, "nested target")
    near(root.ingredients["copper-plate#uncommon"].amount, 0, "uncommon input")
    near(root.products["copper-plate#uncommon"].amount, 0, "uncommon surplus")
    near(root.products["copper-cable#uncommon"].amount, 0, "uncommon cable surplus")
    near(root.products["copper-plate#rare"].amount, 90, "untreated rare byproduct")
    User.setParameter("solver_selected", previous)
end

return {check=check, buildLoop=buildLoop, checkBalances=checkBalances}
