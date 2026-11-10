script.on_nth_tick(1, function()
    Player.set{name="admin", index=1, force=game.forces.player, mod_settings=settings.global, admin=true}
    local _, model = next(storage.models)
    local block = model.block_root
    local cargo = block.children.R1
    local placed = game.surfaces.nauvis.find_entity("triage-selectable-silo", {40, 40})
    local part = placed.get_recipe()
    assert(part.name == "triage-alternate-rocket-part" and not placed.prototype.fixed_recipe)
    assert(cargo.type == "orbit" and cargo.name == "iron-plate")
    assert(not placed.prototype.launch_to_space_platforms, "the saved silo cannot deliver orbital cargo")
    assert(not RecipePrototype(cargo):getAllowedMachines()[placed.name])
    assert(not Model.setFactory(cargo, placed.name), "saved plan rejects a non-platform silo")
    ModelCompute.updateNow(model)
    assert(cargo.factory.name == "rocket-silo" and cargo.factory.rocket_part_recipe == nil)
    assert(block.products["orbit/iron-plate#normal"].amount == 1, "keep the original cargo target")
    assert(block.ingredients["processing-unit"].amount > 0, "use the saved fixed silo recipe")
    log("SELECTABLE SILO SAVE PASSED")
    script.on_nth_tick(1, nil)
end)
