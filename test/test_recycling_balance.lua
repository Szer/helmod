local MaterialBalance = require "math.balance.MaterialBalance"
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

local function buildCircuitLoop()
    local sheet = Model.newModel()
    sheet.time = 1
    local block = sheet.block_root
    block.solver = true
    for _, grade in ipairs(grades) do
        for _, recycle in ipairs({true, false}) do
            if not recycle or grade ~= "legendary" then
                local name = recycle and "electronic-circuit-recycling" or "electronic-circuit"
                local _, row = ModelBuilder.addRecipeIntoProductionBlock(sheet, block, name, "recipe")
                row.quality = grade
                Model.setFactory(row, recycle and "recycler" or "electromagnetic-plant", "legendary")
                ModelBuilder.addFactoryModule(row, "quality-module-3", "legendary", true)
            end
        end
    end
    ModelCompute.update(sheet)
    local goal = "electronic-circuit#legendary"
    block.products[goal].input = 1
    return sheet
end

local function checkCircuitBalances(block)
    local goal = "electronic-circuit#legendary"
    -- Each craft takes one iron and three cables. Recycling returns a quarter of each on average.
    local feed = {["iron-plate"]=29.5677776340656, ["copper-cable"]=88.7033329021969}
    for key, product in pairs(block.products) do near(product.amount, key == goal and 1 or 0, key) end
    for key, input in pairs(block.ingredients) do
        if key ~= "energy" then near(input.amount, feed[key] or 0, key) end
    end
    for key, amount in pairs(feed) do near(block.ingredients[key].amount, amount, key) end
end

local function buildNestedFoundries()
    local model = Model.newModel()
    model.time = 1
    local root = model.block_root
    local loop = Model.newBlock(model, {name="foundry-recycling", type="recipe"})
    loop.parent_id, loop.index, loop.solver = root.id, 0, true
    model.blocks[loop.id], root.children[loop.id] = loop, loop
    for _, quality in ipairs({"normal", "uncommon", "rare", "epic"}) do
        for _, name in ipairs({"foundry-recycling", "foundry"}) do
            local _, recipe = ModelBuilder.addRecipeIntoProductionBlock(model, loop, name, "recipe")
            recipe.quality = quality
            Model.setFactory(recipe, name == "foundry" and "foundry" or "recycler", "legendary")
            ModelBuilder.addFactoryModule(recipe, "quality-module-3", "legendary", true)
        end
    end
    local carbide = "tungsten-carbide#legendary"
    loop.products_linked = {[carbide]=true}
    loop.matrix_supplies = {["tungsten-carbide"]=true, ["electronic-circuit"]=true, ["steel-plate"]=true, ["refined-concrete"]=true}
    ModelCompute.updateNow(model)
    return model, loop
end

local function checkFoundrySurplus(block)
    for _, key in ipairs({"steel-plate#uncommon", "tungsten-carbide#uncommon", "foundry#rare", "foundry#epic"}) do
        local output = block.products[key]
        assert(output.amount == 0, "balanced foundry material: " .. key)
        assert(output.state ~= 3, "zero foundry output marked as surplus: " .. key)
    end
end

local function checkSurplusThreshold()
    for _, solver in ipairs({SolverMatrix(), SolverLinkedMatrix()}) do
        for _, case in ipairs({
            {net=-1e-10, amount=1e-10, surplus=false},
            {net=-5e-11, amount=0, surplus=false},
            {net=0, amount=0, surplus=false},
            {net=5e-11, amount=0, surplus=false},
            {net=1e-10, amount=1e-10, surplus=true},
            {net=2e-10, amount=2e-10, surplus=true}
        }) do
            local matrix = {columns={{}}, rows={{1}, {-1}, {case.net}}}
            solver:apply_state(matrix)
            assert((matrix.states[1] == 3) == case.surplus, "surplus threshold at " .. case.net)
            local reported = matrix.rows[#matrix.rows][1]
            assert(reported == (case.net < 0 and -case.amount or case.amount), "signed net balance")
            local flow = {state=3, amount=1}
            MaterialBalance.setFlow(flow, case.net, true)
            assert(flow.amount == reported and (flow.state == 3) == case.surplus, "scaled block balance")
        end
    end
end

local function checkNestedFoundries()
    local model, loop = buildNestedFoundries()
    local root = model.block_root
    local carbide = "tungsten-carbide#legendary"
    local standalone = table.deepcopy(model)
    standalone.block_root = standalone.blocks[loop.id]
    standalone.block_root.products[carbide].input = 1
    for _, solver in ipairs({defines.constant.solvers.matrix, defines.constant.solvers.default}) do
        User.setParameter("solver_selected", solver)
        ModelCompute.updateNow(standalone)
        near(standalone.block_root.products[carbide].amount, 1, "standalone legendary target")
        checkFoundrySurplus(standalone.block_root)
    end
    root.products[carbide].input = 1
    for _, matrix in ipairs({true, false, true}) do
        root.solver = matrix
        ModelCompute.updateNow(model)
        checkFoundrySurplus(loop)
        near(root.products[carbide].amount, 1, "parent legendary output")
        near(root.ingredients.foundry.amount, 0, "foundries are made inside the loop")
        near(root.products["tungsten-carbide#uncommon"].amount, 0, "intermediates stay inside the loop")
        near(root.products["steel-plate#legendary"].amount, 1, "steel coproduct")
        for _, side in ipairs({"products", "ingredients"}) do
            for key, material in pairs(standalone.block_root[side]) do
                near(root[side][key].amount, material.amount, "parent "..key)
                near(loop[side][key].amount * loop.count_deep, material.amount, "child "..key)
            end
        end
        for id, row in pairs(standalone.block_root.children) do
            near(loop.children[id].count_deep, row.count_deep, "craft count "..id)
        end
    end
    -- A primary profile can return the linked material as a byproduct of a different target.
    root.solver = false
    loop.products["tungsten-carbide"].input = 9.375
    ModelCompute.updateNow(model)
    near(root.ingredients.foundry.amount, 0, "use the linked profile for its requested quality")
    near(root.products[carbide].amount, 1, "linked demand with a different local target")
    assert(loop.products["tungsten-carbide"].input == 9.375, "preserve the explicit local target")
    loop.products["tungsten-carbide"].input = nil
    root.products[carbide].input = nil
    ModelBuilder.updateChildContraint(loop, {type="master", item={name="tungsten-carbide", quality="legendary", type="item"}})
    for _, matrix in ipairs({true, false}) do
        root.solver = matrix
        ModelCompute.updateNow(model)
        assert(root.products[carbide].amount > 0, "a selected main output can drive an untargeted parent")
        near(root.ingredients.foundry.amount, 0, "implicit target respects the recycling loop")
    end
end

local function check()
    checkSurplusThreshold()
    local previous = User.getParameter("solver_selected")
    for _, solver in ipairs({defines.constant.solvers.default, defines.constant.solvers.matrix}) do
        User.setParameter("solver_selected", solver)
        local circuits = buildCircuitLoop()
        circuits.block_root.matrix_supplies = {["iron-plate"]=true, ["copper-cable"]=true}
        ModelCompute.update(circuits)
        checkCircuitBalances(circuits.block_root)
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
    checkNestedFoundries()
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

return {check=check, buildNestedFoundries=buildNestedFoundries, buildLoop=buildLoop, checkBalances=checkBalances, buildCircuitLoop=buildCircuitLoop, checkCircuitBalances=checkCircuitBalances}
