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

local function click(player, name)
    local element = assert(find(player.gui.screen, name), name)
    EventController.onGuiClickButton{player_index=player.index, element=element, button=defines.mouse_button_type.left}
    game.tick_paused = false
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
        elseif case == "row-removal-scroll" then
            model = Model.newModel()
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
            local panel = Controller:getView("HMProductionPanel")
            panel:close()
            User.setParameterObjects("HMProductionPanel", model.id, block.id)
            Controller:send("on_gui_open", {name="OPEN", item1=model.id, item2=block.id}, "HMProductionPanel")
            local _, _, pane = panel:getDataPanel()
            for _, i in ipairs({12, 24}) do
                local button = "block-child-remove=" .. model.id .. "=" .. block.id .. "=" .. rows[i].id
                pane.scroll_to_element(assert(find(pane, button)))
                click(player, button)
                assert(block.children[rows[i].id] == nil, "clicked row must be removed")
                assert(pane.valid, "row removal must preserve the scrolled viewport")
                assert(not find(pane, button), "removed row must disappear from the table")
            end
            local target = "=" .. model.id .. "=" .. block.id .. "=" .. child.id
            for _, action in ipairs({"remove", "remove-canceled", "remove", "remove-confirmed"}) do
                click(player, "block-child-" .. action .. target)
                assert(pane.valid, "block removal controls must preserve the scrolled viewport")
            end
            assert(block.children[child.id] == nil, "confirmed block must be removed")
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
