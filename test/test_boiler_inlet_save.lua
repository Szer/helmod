script.on_nth_tick(1, function()
    Player.set{name="admin", index=1, force=game.forces.player, mod_settings=settings.global, admin=true}
    local _, model = next(storage.models)
    local block = model.block_root
    local boiler = block.children.R1
    assert(boiler.name == "water->steam#165" and boiler.factory.boiler_inlet_temperature == nil)
    assert(block.products["steam#165"].input == 60)
    ModelCompute.updateNow(model)
    assert(block.children.R1 == boiler and boiler.name == "water->steam#165")
    assert(math.abs(block.products["steam#165"].amount - 60) < 1e-7)
    assert(math.abs(boiler.factory.count - 65/150) < 1e-7, "100 °C supply in the imported plan")
    assert(math.abs(block.ingredients.coal.amount - 0.195) < 1e-7, "fuel for 60 steam/s")
    log("BOILER INLET SAVE PASSED")
    script.on_nth_tick(1, nil)
end)
