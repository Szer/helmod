script.on_nth_tick(1, function()
    Player.set{name="admin", index=1, force=game.forces.player, mod_settings=settings.global, admin=true}
    local _, model = next(storage.models)
    local block = model.block_root
    local gear = block.children.R1
    assert(gear.factory.name == "triage-cable-machine" and gear.name == "iron-gear-wheel")
    ModelCompute.updateNow(model)
    assert(gear.factory.name ~= "triage-cable-machine" and not gear.unbuildable)
    assert(block.products["iron-gear-wheel"].input == 1 and block.products["iron-gear-wheel"].amount == 1)
    assert(block.ingredients["iron-plate"].amount == 2)
    log("FIXED RECIPE SAVE PASSED")
    script.on_nth_tick(1, nil)
end)
