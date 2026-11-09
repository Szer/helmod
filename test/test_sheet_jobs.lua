local Planner = require "data.SheetPlanner"

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
    oracle.id = "sheet-oracle"
    ModelCompute.updateFull(oracle)
    assert(Planner.pending(model.id), "edit must be scheduled")
    for _ = 1, 100 do
        Planner.tick()
        if not Planner.pending(model.id) then
            assert(not Planner.failure(model.id), Planner.failure(model.id))
            equal(oracle.block_root, model.block_root, "published")
            return
        end
        equal(original, model.block_root, "partially published")
    end
    error("sheet job did not finish")
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
    ModelCompute.updateFull(model)
    ModelBuilder.updateRecipeProduction(recipe, 0.85)
    Planner.enqueue(model, block, player.index)
    local oracle = table.deepcopy(model)
    oracle.id = "wide-oracle"
    ModelCompute.updateFull(oracle)
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

local function checkIndependentWork()
    local sheet = Model.newModel()
    local edited, gear = child(sheet, sheet.block_root, "iron-gear-wheel")
    local other = child(sheet, sheet.block_root, "copper-cable")
    local _, circuit = ModelBuilder.addRecipeIntoProductionBlock(sheet, edited, "electronic-circuit", "recipe")
    local _, engine = ModelBuilder.addRecipeIntoProductionBlock(sheet, sheet.block_root, "steam-engine", "energy")
    ModelCompute.updateNow(sheet)
    local solved, prepared = {}, {}
    local solve, prepare = ModelCompute.solveUnit, ModelCompute.prepareRecipeFactory
    ModelCompute.solveUnit = function(model, block)
        solved[block.id] = true
        return solve(model, block)
    end
    ModelCompute.prepareRecipeFactory = function(recipe, ...)
        prepared[recipe.id] = true
        return prepare(recipe, ...)
    end
    local function checkEdit()
        local reference = table.deepcopy(sheet)
        reference.id = "dependencies-oracle"
        ModelCompute.updateFull(reference)
        solved, prepared = {}, {}
        for _ = 1, 100 do
            Planner.tick()
            if not Planner.pending(sheet.id) then break end
        end
        assert(not Planner.pending(sheet.id) and not Planner.failure(sheet.id))
        equal(reference.block_root, sheet.block_root, "dependencies")
    end
    for _, value in ipairs({0.85, 0.95, 0.85, 0.95, 0.85}) do
        ModelBuilder.updateRecipeProduction(gear, value)
        ModelCompute.update(sheet, edited)
        checkEdit()
    end
    assert(solved[edited.id] and solved[sheet.block_root.id] and not solved[other.id])
    assert(prepared[engine.id] and prepared[gear.id] and not prepared[circuit.id],
        "only dependent recipes need preparing, even on a sheet containing a generator")
    ModelBuilder.addRecipeIntoProductionBlock(sheet, edited, "transport-belt", "recipe")
    ModelCompute.update(sheet)
    checkEdit()
    assert(not solved[other.id], "a new dependency in one block invalidated an unrelated block")
    ModelCompute.solveUnit, ModelCompute.prepareRecipeFactory = solve, prepare
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
    ModelCompute.updateFull(model)
    root.products["electronic-circuit"].input = 5
    root.products["utility-science-pack"].input = 60
    oil.products["petroleum-gas"].input = 100
    ModelCompute.updateFull(model)
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
    ModelCompute.updateNow(model)
    assert(not Planner.pending(model.id), "immediate updates must invalidate old work")
    ModelCompute.solveUnit = original
    checkVisibleRows(player, model, frames, frame)
    local other = Model.newModel()
    local otherBlock, gear = child(other, other.block_root, "iron-gear-wheel")
    ModelCompute.updateFull(other)
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
    ModelCompute.updateFull(oracle)
    Planner.finishPending()
    assert(not Planner.pending(model.id), "pausing left work behind")
    equal(oracle.block_root, model.block_root, "paused")
    ModelBuilder.updateRecipeProduction(frame, 0.63)
    ModelCompute.update(model, frames)
    ModelCompute.solveUnit = function() error("injected sheet failure") end
    for _ = 1, 100 do
        Planner.tick()
        if not Planner.pending(model.id) then break end
    end
    assert(Planner.failure(model.id):find("injected sheet failure", 1, true))
    ModelCompute.solveUnit = original
    ModelCompute.update(model, frames)
    compareJob(model)
    checkIndependentWork()
    checkWideBlock(player)
    local production = Controller:getView("HMProductionPanel")
    Controller:send("on_gui_open", {name="OPEN", item1=model.id, item2=frames.id, item3=frame.id}, production.classname)
    local _, _, scroll = production:getDataPanel()
    local list = scroll["list-data"]
    local oldRow = assert(list[GuiTable("action", frame.id):getName()])
    local navigator = production:getNavigatorPanel()
    local info = production:getInfoPanel2()
    info.parent["block-heading"].destroy()
    local savedLabel = GuiElement.add(info.parent, GuiLabel("label-info"))
    info.parent.swap_children(1, savedLabel.get_index_in_parent())
    production:updatePending(model)
    assert(info.valid and not savedLabel.valid, "existing open panel should keep its scroll pane")
    local heading = info.parent["block-heading"]
    local indicator = heading["solver-status"]
    local caption = heading["label-info"].caption
    assert(indicator.visible and indicator.sprite == "utility/status_working")
    local selector = Controller:getView("HMRecipeSelector")
    User.setParameterObjects(selector.classname, model.id, frames.id)
    selector:onEvent{action="element-select", item1="recipe", item2="iron-gear-wheel"}
    assert(Planner.pending(model.id), "adding a recipe must use the sheet worker")
    assert(oldRow.valid and navigator.valid and list.valid, "selector refresh cleared the visible block while calculating")
    assert(not list.enabled, "structural edits must disable outdated row actions")
    assert(indicator.visible and indicator.sprite == "utility/status_yellow")
    equal(caption, heading["label-info"].caption, "title changed during calculation")
    compareJob(model)
    local inserted
    for _, entry in pairs(frames.children) do
        if entry.name == "iron-gear-wheel" then inserted = entry end
    end
    assert(inserted)
    while #storage.percentage_planner.notifications > 0 do Planner.tick() end
    assert(list.valid and list.enabled and list[GuiTable("action", inserted.id):getName()], "new row missing after publication")
    assert(indicator.valid and indicator.sprite == "utility/status_working")
    Controller:send("on_gui_open", {name="OPEN", item1=model.id, item2=frames.id, item3=inserted.id}, "HMRecipeEdition")
    local editor = Controller:getView("HMRecipeEdition")
    local factoryButton = player.gui.screen.HMRecipeEdition
    editor:onEvent{action="factory-select", item4="assembling-machine-3", element=factoryButton}
    assert(inserted.factory.name == "assembling-machine-3")
    compareJob(model)
    editor:onEvent{action="factory-module-select", item4="speed-module", element=factoryButton}
    compareJob(model)
    assert(next(inserted.factory.modules))
    local panel = Controller:getView("HMProductionPanel")
    User.setParameterObjects(panel.classname, model.id, frames.id)
    panel:onEvent{action="block-child-up", item3=inserted.id}
    compareJob(model)
    panel:onEvent{action="change-computing", element={selected_index=3}}
    compareJob(model)
    assert(frames.solver)
    ModelBuilder.updateProduct(oil, "petroleum-gas", 80)
    ModelCompute.update(model)
    Planner.tick()
    ModelBuilder.blockChildRemove(model, frames, inserted)
    ModelCompute.update(model)
    compareJob(model)
    assert(oil.products["petroleum-gas"].input == 80 and not frames.children[inserted.id])
    while #storage.percentage_planner.notifications > 0 do Planner.tick() end
    assert(not editor:isOpened(), "removed recipe left its editor open")
    local mixed = Model.newModel()
    local mixedBlock, plate = child(mixed, mixed.block_root, "iron-plate")
    local _, orbit = ModelBuilder.addRecipeIntoProductionBlock(mixed, mixed.block_root, "automation-science-pack", "orbit")
    assert(orbit.type == "orbit")
    local _, steam = ModelBuilder.addRecipeIntoProductionBlock(mixed, mixed.block_root, "steam-engine", "energy")
    assert(steam.type == "energy")
    ModelCompute.updateFull(mixed)
    ModelBuilder.updateRecipeProduction(plate, 0.8)
    ModelCompute.update(mixed, mixedBlock)
    compareJob(mixed)
    assert(not Planner.failure(mixed.id))
    local cache = storage.percentage_planner.units[mixed.id]
    assert(not cache or (not cache.recipes[steam.id] and not cache.recipes[orbit.id]), "synthetic recipes must be prepared afresh")
    ModelCompute.update(mixed)
    Planner.tick()
    local research = player.force.technologies["rocket-part-productivity"]
    research.level = research.level + 1
    compareJob(mixed)
    settings.global.helmod_debug_solver = {value=true}
    ModelCompute.update(mixed)
    compareJob(mixed)
    assert(not storage.percentage_planner.units[mixed.id], "debug runs need fresh matrix traces")
    settings.global.helmod_debug_solver = {value=false}
    local empty = Model.newModel()
    ModelCompute.update(empty)
    compareJob(empty)
    local clone = table.deepcopy(mixed)
    local expected = table.deepcopy(clone)
    ModelCompute.updateFull(expected)
    assert(not ModelCompute.update(clone), "detached plan must finish before returning")
    equal(expected.block_root, clone.block_root, "detached")
    ModelBuilder.updateProduct(mixedBlock, "iron-plate", 10)
    ModelCompute.update(mixed)
    Planner.tick()
    local exported = table.deepcopy(mixed)
    ModelCompute.updateFull(exported)
    local sheets = remote.call("helmod_interface", "get_models")
    assert(not Planner.pending(mixed.id), "remote read returned an unfinished sheet")
    equal(exported.block_root, sheets[mixed.id].block_root, "remote read")
    ModelBuilder.updateProduct(mixedBlock, "iron-plate", 20)
    ModelCompute.update(mixed)
    Planner.tick()
    local disabled = table.deepcopy(mixed)
    ModelCompute.updateFull(disabled)
    settings.global.helmod_incremental_percentages = {value=false}
    EventController.onRuntimeModSettingChanged{setting="helmod_" .. Planner.setting}
    assert(not storage.percentage_planner)
    equal(disabled.block_root, mixed.block_root, "disabling while a sheet is pending")
end

local function queueForSave(player)
    settings.global.helmod_incremental_percentages = {value=true}
    local model = Model.newModel()
    local block, gear = child(model, model.block_root, "iron-gear-wheel")
    for _ = 1, 4 do child(model, model.block_root, "iron-plate") end
    ModelCompute.updateFull(model)
    ModelBuilder.updateRecipeProduction(gear, 0.85)
    ModelBuilder.addRecipeIntoProductionBlock(model, block, "copper-cable", "recipe")
    assert(ModelCompute.update(model), "structural edit should still be pending at save time")
    Planner.tick()
    Planner.tick()
    local oracle = table.deepcopy(model)
    oracle.id = "reload-oracle"
    ModelCompute.updateFull(oracle)
    storage.sheet_oracle = {id=model.id, root=oracle.block_root}
end

local function afterLoad()
    local saved = assert(storage.sheet_oracle)
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
