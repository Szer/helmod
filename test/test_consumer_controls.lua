return function(player)
    local model = Model.newModel()
    local root = model.block_root
    local _, scrap = ModelBuilder.addRecipeIntoProductionBlock(model, root, "scrap-recycling", "recipe")
    local child = Model.newBlock(model, {name="cargo-landing-pad-recycling", type="recipe"})
    child.parent_id, child.index = root.id, 1
    child.by_product, child.consumer = false, true
    model.blocks[child.id], root.children[child.id] = child, child
    ModelBuilder.addRecipeIntoProductionBlock(model, child, "cargo-landing-pad-recycling", "recipe")
    ModelBuilder.addRecipeIntoProductionBlock(model, child, "cargo-landing-pad", "recipe")
    ModelBuilder.updateChildContraint(child,{type="master",item={name="concrete",type="item"}})
    ModelCompute.update(model)
    root.products["steel-plate"].input = 10
    ModelCompute.update(model)
    local before = child.ingredients["steel-plate"].amount
    assert(before > 0, "consumer must start active")
    Controller:getView("HMProductionPanel"):close()
    User.setParameterObjects("HMProductionPanel", model.id, root.id)
    Controller:send("on_gui_open",{name="OPEN",item1=model.id,item2=root.id},"HMProductionPanel")
    local function button(node, side, name, id)
        local action = "production-recipe-" .. side .. "-add="
        if node.name:find(action,1,true) and node.name:find("="..(id or child.id).."=",1,true) and node.tags.name == name then return node end
        for _, el in pairs(node.children) do
            local found = button(el,side,name,id)
            if found then return found end
        end
    end
    local _, _, viewport = Controller:getView("HMProductionPanel"):getDataPanel()
    local function clickConstraint(el, shift)
        local inner = el.parent
        while inner.type ~= "scroll-pane" do inner = inner.parent end
        viewport.scroll_to_element(inner)
        inner.scroll_to_element(el)
        EventController.onGuiClickButton{player_index=player.index,element=el,button=defines.mouse_button_type.left,control=not shift,shift=shift,alt=false}
        assert(viewport.valid and inner.valid, "constraint edit must preserve both scroll panes")
    end
    assert(child.products.concrete.amount == 0 and child.ingredients.concrete.amount > 0)
    assert(not button(player.gui.screen, "product", "concrete"), "duplicate zero concrete output")
    for i = 1, 2 do
        clickConstraint(assert(button(player.gui.screen, "ingredient", "concrete")), false)
        assert((child.contraints.concrete ~= nil) == (i == 2))
    end
    assert(not button(player.gui.screen, "product", "concrete"), "duplicate after restoring the constraint")
    local function clickSteel(shift)
        local steel = assert(button(player.gui.screen,"ingredient","steel-plate"), "missing steel input control")
        clickConstraint(steel, shift)
    end
    clickSteel(false)
    assert(child.ingredients["steel-plate"].amount == 0, "steel should stop consumption")
    assert(button(player.gui.screen,"ingredient","concrete"), "missing concrete input control")
    assert(button(player.gui.screen,"ingredient","processing-unit"), "missing processing-unit input control")
    clickSteel(false)
    assert(math.abs(child.ingredients["steel-plate"].amount - before) < 1e-8, "unset should restore consumption")
    clickSteel(true)
    assert(child.contraints["steel-plate"].type == "exclude")
    clickSteel(true)
    assert(child.contraints["steel-plate"] == nil)
    for _, shift in ipairs({false, true}) do
        for i = 1, 2 do
            clickConstraint(assert(button(player.gui.screen, "product", "holmium-ore", scrap.id)), shift)
            local constraint = scrap.contraints["holmium-ore"]
            if i == 1 then assert(constraint.type == (shift and "exclude" or "master"))
            else assert(constraint == nil) end
        end
    end
    for _, el in ipairs({
        assert(button(player.gui.screen,"ingredient","steel-plate")),
        assert(button(player.gui.screen,"ingredient","scrap",scrap.id)),
        assert(button(player.gui.screen,"product","steel-plate",scrap.id))
    }) do
        local tooltip = serpent.line(el.tooltip)
        assert(tooltip:find("controls.contraint-plus", 1, true), "missing Ctrl-click hint")
        assert(tooltip:find("controls.contraint-minus", 1, true), "missing Shift-click hint")
    end
end
