local Planner = require "data.PercentagePlanner"

local function equal(a, b, path)
    if a == b then return end
    assert(type(a) == "table" and type(b) == "table", path .. ": " .. tostring(a) .. " vs " .. tostring(b))
    for k, v in pairs(a) do equal(v, b[k], path .. "." .. tostring(k)) end
    for k in pairs(b) do assert(a[k] ~= nil, path .. ": unexpected " .. tostring(k)) end
end

local function child(model, parent, name)
    local block = Model.newBlock(model, {name=name, type="recipe"})
    block.index, block.parent_id = table_size(parent.children), parent.id
    model.blocks[block.id], parent.children[block.id] = block, block
    local _, recipe = ModelBuilder.addRecipeIntoProductionBlock(model, block, name, "recipe")
    return block, recipe
end

local function compareJob(model)
    local original = table.deepcopy(model.block_root)
    local oracle = table.deepcopy(model)
    oracle.id = "percentage-oracle"
    ModelCompute.update(oracle)
    for _ = 1, 100 do
        Planner.tick()
        if not Planner.pending(model.id) then
            equal(oracle.block_root, model.block_root, "published")
            return
        end
        equal(original, model.block_root, "partially published")
    end
    error("percentage job did not finish")
end

local function snapshot(element)
    local node = {name=element.name, kind=element.type, children={}}
    if element.type == "label" or element.type == "button" or element.type == "sprite-button" then
        node.caption = element.caption
    end
    if element.type == "sprite-button" or element.type == "sprite" then node.sprite = element.sprite end
    node.tooltip = element.tooltip
    for _, child in ipairs(element.children) do table.insert(node.children, snapshot(child)) end
    return node
end

local function checkVisibleRows(player, model, block, recipe)
    local panel = Controller:getView("HMProductionPanel")
    for _, displayed in ipairs({model.block_root, block}) do
        Controller:send("on_gui_open", {name="OPEN", item1=model.id, item2=displayed.id}, panel.classname)
        local _, _, scroll = panel:getDataPanel()
        local list = scroll["list-data"]
        local row = recipe
        if displayed ~= block then
            row = block
            while row.parent_id ~= displayed.id do row = model.blocks[row.parent_id] end
        end
        local retained = list[GuiScroll("products", row.id):getName()]
        assert(retained and retained.valid, "missing product pane")
        ModelBuilder.updateRecipeProduction(recipe, recipe.production == 0.65 and 0.85 or 0.65)
        Planner.enqueue(model, block, player.index)
        compareJob(model)
        while #storage.percentage_planner.notifications > 0 do Planner.tick() end
        local incremental = snapshot(list)
        assert(retained.valid and list[retained.name] == retained, "row lost its scroll pane")
        panel:update({})
        equal(incremental, snapshot(list), "changed rows must match a full render")
    end
end

local function checkWideBlock(player)
    local model = Model.newModel()
    local block, recipe = child(model, model.block_root, "iron-gear-wheel")
    for _ = 1, 17 do ModelBuilder.addRecipeIntoProductionBlock(model, block, "iron-gear-wheel", "recipe") end
    ModelCompute.update(model)
    ModelBuilder.updateRecipeProduction(recipe, 0.85)
    Planner.enqueue(model, block, player.index)
    local oracle = table.deepcopy(model)
    oracle.id = "wide-oracle"
    ModelCompute.update(oracle)
    local original = ModelCompute.prepareRecipeFactory
    local prepared = 0
    ModelCompute.prepareRecipeFactory = function(...)
        prepared = prepared + 1
        return original(...)
    end
    local total = 0
    for _ = 1, 40 do
        prepared = 0
        Planner.tick()
        assert(prepared <= 8, "wide block exceeded the recipe preparation budget")
        total = total + prepared
        if not Planner.pending(model.id) then break end
    end
    ModelCompute.prepareRecipeFactory = original
    assert(total == 18 and not Planner.pending(model.id))
    equal(oracle.block_root, model.block_root, "wide block")
end

local function check(player)
    settings.global.helmod_incremental_percentages = {value=true}
    local model = Model.newModel()
    local root = model.block_root
    local science = child(model, root, "utility-science-pack")
    local frames, frame = child(model, science, "flying-robot-frame")
    ModelBuilder.addRecipeIntoProductionBlock(model, frames, "electronic-circuit", "recipe")
    science.products_linked = {["electronic-circuit"]=true}
    frames.products_linked = {["electronic-circuit"]=true}
    local oil, cracking = child(model, root, "light-oil-cracking")
    oil.solver = true
    ModelBuilder.addRecipeIntoProductionBlock(model, oil, "heavy-oil-cracking", "recipe")
    ModelBuilder.addRecipeIntoProductionBlock(model, oil, "coal-liquefaction", "recipe")
    local consumer = child(model, root, "cargo-landing-pad-recycling")
    consumer.by_product, consumer.consumer = false, true
    ModelBuilder.addRecipeIntoProductionBlock(model, consumer, "cargo-landing-pad", "recipe")
    ModelBuilder.updateChildContraint(consumer, {type="master",item={name="concrete",type="item"}})
    ModelCompute.update(model)
    root.products["electronic-circuit"].input = 5
    root.products["utility-science-pack"].input = 60
    oil.products["petroleum-gas"].input = 100
    ModelCompute.update(model)
    local function edit(block, recipe, value)
        ModelBuilder.updateRecipeProduction(recipe, value)
        Planner.enqueue(model, block, player.index)
    end
    local solved = {}
    local original = ModelCompute.solveUnit
    ModelCompute.solveUnit = function(sheet, block)
        solved[block.id] = true
        original(sheet, block)
    end
    for _, value in ipairs({0.85, 0.95, 0.85, 0.95}) do
        solved = {}
        edit(frames, frame, value)
        compareJob(model)
        assert(math.abs(root.products["electronic-circuit"].amount - 5) < 1e-8)
    end
    assert(solved[frames.id] and solved[science.id] and solved[root.id], "edited path must solve incrementally")
    assert(not solved[oil.id] and not solved[consumer.id], "stable siblings were solved again")
    edit(frames, frame, 0.75)
    Planner.tick()
    Planner.tick()
    edit(oil, cracking, 0.5)
    compareJob(model)
    assert(frame.production == 0.75, "replacement lost the first accepted edit")
    edit(frames, frame, 0.5)
    Planner.tick()
    model.parameters.effects.productivity = 0.1
    compareJob(model)
    edit(frames, frame, 0.9)
    Planner.tick()
    ModelCompute.update(model)
    assert(not Planner.pending(model.id), "full update must invalidate old work")
    ModelCompute.solveUnit = original
    checkVisibleRows(player, model, frames, frame)
    local other = Model.newModel()
    local otherBlock, gear = child(other, other.block_root, "iron-gear-wheel")
    ModelCompute.update(other)
    edit(frames, frame, 0.25)
    ModelBuilder.updateRecipeProduction(gear, 0.3)
    Planner.enqueue(other, otherBlock, player.index)
    for _ = 1, 30 do
        Planner.tick()
        if storage.percentage_planner.jobs[other.id].work then break end
    end
    assert(storage.percentage_planner.jobs[other.id].work, "second sheet was starved")
    ModelBuilder.removeModel(other.id)
    assert(not Planner.pending(other.id), "deleted sheet left a job behind")
    local oracle = table.deepcopy(model)
    oracle.id = "pause-oracle"
    ModelCompute.update(oracle)
    Planner.finishPending()
    assert(not Planner.pending(model.id), "pausing left work behind")
    equal(oracle.block_root, model.block_root, "paused")
    checkWideBlock(player)
    local mixed = Model.newModel()
    local mixedBlock, plate = child(mixed, mixed.block_root, "iron-plate")
    local _, orbit = ModelBuilder.addRecipeIntoProductionBlock(mixed, mixed.block_root, "automation-science-pack", "orbit")
    assert(orbit.type == "orbit")
    ModelCompute.update(mixed)
    ModelBuilder.updateRecipeProduction(plate, 0.8)
    Planner.enqueue(mixed, mixedBlock, player.index)
    compareJob(mixed)
    assert(not storage.percentage_planner.units[mixed.id], "unsupported sheets need a full solve")
end

local function queueForSave(player)
    settings.global.helmod_incremental_percentages = {value=true}
    local model = Model.newModel()
    local block, gear = child(model, model.block_root, "iron-gear-wheel")
    for _ = 1, 4 do child(model, model.block_root, "iron-plate") end
    ModelCompute.update(model)
    ModelBuilder.updateRecipeProduction(gear, 0.85)
    Planner.enqueue(model, block, player.index)
    Planner.tick()
    Planner.tick()
    local oracle = table.deepcopy(model)
    oracle.id = "reload-oracle"
    ModelCompute.update(oracle)
    storage.percentage_oracle = {id=model.id, root=oracle.block_root}
end

local function afterLoad()
    local saved = assert(storage.percentage_oracle)
    assert(Planner.pending(saved.id), "save must contain pending work")
    local model = storage.models[saved.id]
    for _ = 1, 50 do
        Planner.tick()
        if not Planner.pending(saved.id) then
            equal(saved.root, model.block_root, "reloaded")
            return
        end
    end
    error("pending solve did not survive reload")
end

return {check=check, queueForSave=queueForSave, afterLoad=afterLoad}
