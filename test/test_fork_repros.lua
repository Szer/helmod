-- Exercise the fixed paths with the planner data and player from the original repro save.
local checkConsumerControls = require "test_consumer_controls"
local Blueprint = require "core.Blueprint"
local function find(element, name, kind)
    if element.name:find(name, 1, true) and (kind == nil or element.type == kind) then return element end
    for _, child in pairs(element.children) do
        local found = find(child, name, kind)
        if found ~= nil then return found end
    end
end

local function click(player, name, exact)
    local element = assert(find(player.gui.screen, name), name)
    if exact then assert(element.name == name, "expected exact button name " .. name) end
    EventController.onGuiClickButton{player_index=player.index, element=element, button=defines.mouse_button_type.left}
    game.tick_paused = false
end

---@param model ModelData
---@param block BlockData
---@return ProductionPanel
local function openBlock(model, block)
    local panel = Controller:getView("HMProductionPanel")
    panel:close()
    User.setParameterObjects("HMProductionPanel", model.id, block.id)
    Controller:send("on_gui_open", {name="OPEN", item1=model.id, item2=block.id}, "HMProductionPanel")
    return panel
end

---@param player LuaPlayer
local function checkExcludedOutput(player)
    local model = Model.newModel()
    local root = model.block_root
    ModelBuilder.addRecipeIntoProductionBlock(model, root, "inserter-recycling", "recipe")
    local child = Model.newBlock(model, {name="inserter", type="recipe"})
    child.parent_id, child.index, child.by_product = root.id, 1, false
    root.children[child.id], model.blocks[child.id] = child, child
    ModelBuilder.addRecipeIntoProductionBlock(model, child, "inserter", "recipe")
    ModelCompute.update(model)
    local button = "production-recipe-product-add=" .. model.id .. "=" .. root.id .. "=" .. child.id .. "=inserter"
    local function shiftClick()
        local el = assert(find(player.gui.screen, button), "missing inserter output control")
        EventController.onGuiClickButton{player_index=player.index, element=el, button=defines.mouse_button_type.left, shift=true, control=false}
    end
    for _, threshold in ipairs({User.getPreferenceSetting("display_hidden_products"), 0}) do
        User.setPreference("display_hidden_products", nil, threshold)
        openBlock(model, root)
        assert(child.products.inserter.amount == 1)
        shiftClick()
        assert(child.contraints.inserter.type == "exclude" and child.products.inserter.amount == 0)
        openBlock(model, root)
        shiftClick()
        assert(child.contraints.inserter == nil and child.products.inserter.amount == 1)
    end
end

---@param player LuaPlayer
local function checkHeaderRemoval(player)
    local model = Model.newModel()
    local root = model.block_root
    local parent = Model.newBlock(model, {name="iron-gear-wheel", type="recipe"})
    parent.parent_id, parent.index = root.id, 0
    root.children[parent.id], model.blocks[parent.id] = parent, parent
    local child = Model.newBlock(model, {name="iron-gear-wheel", type="recipe"})
    child.parent_id, child.index = parent.id, 0
    parent.children[child.id], model.blocks[child.id] = child, child
    ModelBuilder.addRecipeIntoProductionBlock(model, child, "iron-gear-wheel", "recipe")
    ModelCompute.update(model)
    local panel = openBlock(model, child)
    local target = "=" .. model.id .. "=" .. child.id
    local _, _, rows = panel:getDataPanel()
    local navigator = panel:getNavigatorPanel()
    click(player, "HMProductionPanel=block-remove" .. target, true)
    assert(not rows.valid and not navigator.valid, "header removal uses a full refresh")
    click(player, "HMProductionPanel=block-remove-canceled" .. target, true)
    assert(parent.children[child.id] == child, "cancel must keep the selected block")
    assert(not find(player.gui.screen, "block-remove-confirmed" .. target), "cancel must close confirmation")
    click(player, "HMProductionPanel=block-remove" .. target, true)
    child.parent_id = nil
    click(player, "HMProductionPanel=block-remove-confirmed" .. target, true)
    assert(parent.children[child.id] == nil and storage.models[model.id] == model)
    local current, selected = panel:getParameterObjects()
    assert(current == model and selected == parent, "nested deletion must open the parent")
    openBlock(model, root)
    target = "=" .. model.id .. "=" .. root.id
    click(player, "HMProductionPanel=block-remove" .. target, true)
    assert(storage.models[model.id] == model, "request must keep the model")
    click(player, "HMProductionPanel=block-remove-confirmed" .. target, true)
    assert(storage.models[model.id] == nil, "root confirmation must delete the model")
    current = panel:getParameterObjects()
    assert(current ~= nil and current.id ~= model.id, "root deletion must leave the deleted sheet")
end

---@param player LuaPlayer
local function checkTreeControls(player)
    local model = Model.newModel()
    local root = model.block_root
    local parent = Model.newBlock(model, {name="iron-gear-wheel", type="recipe"})
    parent.parent_id, parent.index = root.id, 0
    root.children[parent.id], model.blocks[parent.id] = parent, parent
    for i = 1, 16 do
        ModelBuilder.addRecipeIntoProductionBlock(model, parent, "iron-gear-wheel", "recipe")
    end
    local child = Model.newBlock(model, {name="copper-cable", type="recipe"})
    child.parent_id, child.index = parent.id, 16
    parent.children[child.id], model.blocks[child.id] = child, child
    ModelBuilder.addRecipeIntoProductionBlock(model, child, "copper-cable", "recipe")
    local _, recipe = ModelBuilder.addRecipeIntoProductionBlock(model, parent, "copper-cable", "recipe")
    ModelCompute.update(model)
    local panel = openBlock(model, parent)
    local _, _, pane = panel:getDataPanel()
    local function press(action, target)
        local name = "HMProductionPanel=" .. action .. "=" .. model.id .. "=" .. target
        pane.scroll_to_element(assert(find(pane, name)))
        click(player, name, true)
        assert(pane.valid, action .. " replaced the scrolled viewport")
    end
    local before = child.unlinked == true
    press("block-unlink", child.id)
    assert(child.unlinked ~= before)
    press("block-unlink", child.id)
    assert(child.unlinked == before)
    for _, row in ipairs({child, recipe}) do
        local prefix = row == child and "tree-block-" or "tree-recipe-"
        local target = parent.id .. "=" .. row.id
        local left = assert(find(pane, prefix .. "down=" .. model.id .. "=" .. target))
        local right = assert(find(pane, prefix .. "up=" .. model.id .. "=" .. target))
        assert(left.tooltip[1] == "tooltip.down-element-in-tree" and right.tooltip[1] == "tooltip.up-element-in-tree")
        press(prefix .. "up", target)
        local wrapper = parent.children[row.parent_id]
        assert(wrapper and wrapper.children[row.id] == row)
        ModelBuilder.addRecipeIntoProductionBlock(model, wrapper, "iron-gear-wheel", "recipe")
        ModelCompute.update(model)
        panel = openBlock(model, wrapper)
        _, _, pane = panel:getDataPanel()
        press(prefix .. "down", wrapper.id .. "=" .. row.id)
        assert(parent.children[row.id] == row)
        panel = openBlock(model, parent)
        _, _, pane = panel:getDataPanel()
    end
end

---@param player LuaPlayer
local function checkRowRemoval(player)
    local model = Model.newModel()
    local block = model.block_root
    local rows = {}
    for i = 1, 24 do
        local _, row = ModelBuilder.addRecipeIntoProductionBlock(model, block, "firearm-magazine", "recipe")
        rows[i] = row
    end
    local child = Model.newBlock(model, {name="iron-gear-wheel", type="recipe"})
    child.parent_id, child.index = block.id, #rows
    block.children[child.id], model.blocks[child.id] = child, child
    ModelBuilder.addRecipeIntoProductionBlock(model, child, "iron-gear-wheel", "recipe")
    ModelCompute.update(model)
    local panel = openBlock(model, block)
    local _, _, pane = panel:getDataPanel()
    local navigator = panel:getNavigatorPanel()
    for _, i in ipairs({12, 24}) do
        local button = "block-child-remove=" .. model.id .. "=" .. block.id .. "=" .. rows[i].id
        pane.scroll_to_element(assert(find(pane, button)))
        click(player, button)
        assert(block.children[rows[i].id] == nil, "clicked row must be removed")
        assert(pane.valid and navigator.valid, "row removal must preserve both scroll panes")
        assert(not find(pane, button), "removed row must disappear from the table")
    end
    local target = "=" .. model.id .. "=" .. block.id .. "=" .. child.id
    for _, action in ipairs({"remove", "remove-canceled", "remove", "remove-confirmed"}) do
        click(player, "block-child-" .. action .. target)
        assert(pane.valid and navigator.valid, "block removal controls must preserve both scroll panes")
        if action ~= "remove-confirmed" then
            assert(block.children[child.id] == child, "only confirmation may delete the block")
        end
        if action == "remove" then
            assert(find(pane, "block-child-remove-confirmed" .. target), "request must offer confirmation")
        elseif action == "remove-canceled" then
            assert(not find(pane, "block-child-remove-confirmed" .. target), "cancel must close confirmation")
        end
    end
    assert(block.children[child.id] == nil, "confirmed block must be removed")
end

return function(case)
    local done = false
    script.on_nth_tick(1, function()
        if done then return end
        done = true
        local player = game.players[1]
        Player.set(player)
        Controller:getViews()
        Player.getStorageDebug()[player.index] = nil
        assert(storage.models, "original sheets must migrate")
        local _, model = next(storage.models)
        assert(model and model.block_root, "expected a saved sheet")
        if case == "consumer-controls" then
            checkConsumerControls(player)
        elseif case == "excluded-output" then
            checkExcludedOutput(player)
        elseif case == "electricity-inputs" then
            local sheet = Model.newModel()
            local block, recipe = ModelBuilder.addRecipeIntoProductionBlock(sheet, sheet.block_root, "iron-gear-wheel", "recipe")
            Model.setFactory(recipe, "assembling-machine-1")
            ModelCompute.update(sheet)
            local demand = block.ingredients.energy.amount
            assert(demand > 0)
            assert(User.getPreferenceSetting("show_electricity_inputs") == false)
            openBlock(sheet, block)
            Controller:send("on_gui_open", {name="OPEN"}, "HMPreferenceEdition")
            for _, show in ipairs({false, true, false}) do
                local checkbox = assert(find(player.gui.screen, "preference-setting=show_electricity_inputs", "checkbox"))
                if checkbox.state ~= show then
                    checkbox.state = show
                    EventController.onGuiClick{player_index=player.index, element=checkbox}
                end
                assert(User.getPreferenceSetting("show_electricity_inputs") == show)
                for _, name in ipairs({"input-table", "ingredients=" .. recipe.id}) do
                    local container = assert(find(player.gui.screen, name, "table"))
                    assert((find(container, "=energy") ~= nil) == show, name)
                    assert(find(container, "=iron-plate"), name)
                end
                assert(block.ingredients.energy.amount == demand)
            end
        elseif case == "header-block-removal" then
            checkHeaderRemoval(player)
        elseif case == "tree-controls" then
            checkTreeControls(player)
        elseif case == "row-removal-scroll" then
            checkRowRemoval(player)
        elseif case == "quantity-confirm" then
            local input = assert(find(player.gui.screen.HMProductEdition, "product-update", "textfield"))
            input.text = "10"
            EventController.onGuiClick{player_index=player.index, element=input}
            local _, block = Model.getParameterObjects{model=model.id, block=storage.fork_test_block}
            assert(block.id == storage.fork_test_block)
            assert(block and block.products["iron-gear-wheel"].input == 10, "quantity after reload")
        else
            User.setParameterObjects("HMProductionPanel", model.id, model.block_root.id)
            Controller:send("on_gui_open", {name="OPEN",item1=model.id,item2=model.block_root.id}, "HMProductionPanel")
            if case == "empty-explorer" then
                local count = table_size(model.block_root.children)
                click(player, "HMRecipeExplorer=OPEN")
                click(player, "HMRecipeExplorer=generate-block")
                assert(table_size(model.block_root.children) == count)
            elseif case == "custom-recipe-quality" or case == "custom-recipe-categories" then
                local name, saved = next(assert(storage.customized_recipes))
                assert(name, "expected the original custom recipe")
                click(player, "HMRecipeCustomization=OPEN")
                click(player, "HMRecipeCustomization=recipe-select")
                local prototype = RecipePrototype(saved)
                assert(next(prototype:getAllowedMachines()), "expected a crafting machine")
                local ingredients = prototype:getQualityIngredients(nil, "normal")
                if case == "custom-recipe-quality" then
                    assert(#ingredients == 1 and ingredients[1].quality == "normal")
                else
                    assert(#ingredients == 0)
                end
                assert(#prototype:getQualityProducts(nil, "normal") > 0)
            elseif case == "blank-selector-rule" then
                local blank = false
                for _, rule in pairs(Model.getRules()) do
                    if rule.name == "selector-filter" and rule.value == nil then blank = true end
                end
                assert(blank, "expected a persisted incomplete rule")
                Player.getRules("selector-filter")
                local rules = Model.getRules()
                local count = table_size(rules)
                click(player, "HMAdminPanel=OPEN")
                local tab = assert(find(player.gui.screen, "HMAdminPanel=change-tab"))
                tab.selected_tab_index = 2
                EventController.onGuiClick{player_index=player.index, element=tab}
                click(player, "HMRuleEdition=OPEN")
                click(player, "HMRuleEdition=save")
                assert(table_size(rules) == count, "incomplete rule must not be saved")
                Controller:getView("HMRuleEdition"):close()
                Controller:getView("HMAdminPanel"):close()
                click(player, "HMRecipeSelector=OPEN")
            elseif case == "truncated-import" then
                local count = table_size(storage.models)
                click(player, "HMDownload=OPEN=" .. model.id .. "=download")
                local box = assert(find(player.gui.screen.HMDownload, "data-text"))
                box.text = "do local"
                click(player, "HMDownload=download-model")
                assert(table_size(storage.models) == count)
                local valid = Converter.read(Converter.write({time=60}))
                assert(valid and valid.time == 60, "valid export must still decode")
            elseif case == "empty-blueprint-book" then
                player.clear_cursor()
                player.cursor_stack.set_stack{name="blueprint-book"}
                local encoded = player.cursor_stack.export_stack()
                local book = helpers.json_to_table(helpers.decode_string(encoded:sub(2)))
                assert(book.blueprint_book and next(Blueprint.get_entities(book)) == nil)
                assert(next(Blueprint.get_tiles(book)) == nil)
            elseif case == "quantity-after-reload" then
                local block = ModelBuilder.addRecipeIntoProductionBlock(model, model.block_root, "iron-gear-wheel", "recipe")
                ModelCompute.update(model)
                storage.fork_test_block = block.id
                User.setParameterObjects("HMProductionPanel", model.id, block.id)
                Controller:send("on_gui_update", {item1=model.id,item2=block.id}, "HMProductionPanel")
                click(player, "HMProductionPanel=product-edition")
                assert(player.gui.screen.HMProductEdition)
                game.tick_paused = false
                if game.is_multiplayer() then
                    game.server_save("fork-quantity")
                else
                    game.auto_save("fork-quantity")
                end
            end
        end
        assert(Player.getLastError() == nil, tostring(Player.getLastError()))
        log("FORK REGRESSION PASS " .. case)
    end)
end
