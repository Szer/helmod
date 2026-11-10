return function()
    local function offers(recipe, machine)
        for _, candidate in pairs(RecipePrototype(recipe, "recipe"):getAllowedMachines()) do
            if candidate.name == machine then return true end
        end
        return false
    end

    local machine = "test-cable-assembler"
    assert(not offers("iron-gear-wheel", machine), "gear picker includes a cable-only machine")
    assert(offers("copper-cable", machine), "matching fixed recipe must remain usable")
    assert(not Player.getProductionsCrafting("crafting", prototypes.recipe["iron-gear-wheel"])[machine], "legacy machine lookup")
    local model = Model.newModel()
    local block, cable = ModelBuilder.addRecipeIntoProductionBlock(model, model.block_root, "copper-cable", "recipe")
    Model.setFactory(cable, machine, "uncommon")
    local defaults = table.deepcopy(User.getParameter("default_factory"))
    User.setDefaultFactory(cable)
    local _, gear = ModelBuilder.addRecipeIntoProductionBlock(model, block, "iron-gear-wheel", "recipe")
    local old_machine = gear.factory.name
    assert(old_machine ~= machine, "incompatible saved default")
    Model.setFactory(gear, machine, "rare")
    assert(gear.factory.name == old_machine, "incompatible direct selection")
    ModelBuilder.setFactoryBlock(block, cable)
    assert(gear.factory.name == old_machine, "incompatible bulk assignment")
    local _, second_cable = ModelBuilder.addRecipeIntoProductionBlock(model, block, "copper-cable", "recipe")
    assert(second_cable.factory.name == machine and second_cable.factory.quality == "uncommon", "compatible default")
    User.setParameter("default_factory", defaults)

    gear.factory.name, gear.factory.quality = machine, "rare"
    ModelCompute.update(model)
    assert(gear.factory.name ~= machine and gear.factory.quality == "rare", "repair old invalid assignment")
    assert(cable.factory.name == machine and cable.factory.quality == "uncommon", "preserve valid old assignment")

    local orphan = Model.newModel()
    local root, stalled = ModelBuilder.addRecipeIntoProductionBlock(orphan, orphan.block_root, "test-unbuildable-cable", "recipe")
    local _, sibling = ModelBuilder.addRecipeIntoProductionBlock(orphan, root, "iron-gear-wheel", "recipe")
    ModelCompute.update(orphan)
    local previous_solver = User.getParameter("solver_selected")
    for _, solver in ipairs({defines.constant.solvers.default, defines.constant.solvers.matrix}) do
        User.setParameter("solver_selected", solver)
        root.products["copper-cable"].input = 8
        root.products["iron-gear-wheel"].input = 2
        for _, matrix in ipairs({false, true}) do
            root.solver = matrix
            ModelCompute.update(orphan)
            assert(stalled.unbuildable and stalled.count == 0, "unbuildable row must be idle")
            assert(root.products["copper-cable"].input == 8 and root.products["copper-cable"].amount == 0, "keep unmet target")
            assert(sibling.count > 0 and root.products["iron-gear-wheel"].amount == 2, "independent row remains active")
        end
        stalled.factory = Model.newFactory("test-dedicated-assembler")
        stalled.factory.input = 4
        root.by_factory = true
        ModelCompute.update(orphan)
        assert(stalled.unbuildable and stalled.count == 0 and stalled.factory.input == 4, "keep a blocked machine target idle")
        root.by_factory = false
    end
    stalled.factory.name = "missing-test-cable-machine"
    ModelCompute.update(orphan)
    assert(stalled.unbuildable and stalled.count == 0, "orphan in a changed mod set")
    User.setParameter("solver_selected", previous_solver)
end
