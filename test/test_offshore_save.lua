script.on_nth_tick(1, function()
    Player.set{name="admin", index=1, force=game.forces.player, mod_settings=settings.global, admin=true}
    local _, model = next(storage.models)
    local block = model.block_root
    local water = block.children.R1
    assert(water.name == "water" and water.type == "fluid" and block.products.water.input == 100)
    local selector = Cache.getData("HMRecipeSelector", "list_products")
    assert(selector["sulfuric-acid"]["fluid-sulfuric-acid"], "saved recipe selector needs the acid extraction entry")
    ModelCompute.updateNow(model)
    assert(water.factory.name == "offshore-pump" and block.products.water.amount == 100)
    local _, acid = ModelBuilder.addRecipeIntoProductionBlock(model, block, "sulfuric-acid", "fluid")
    assert(acid.factory.name == "triage-acid-pump")
    log("OFFSHORE SAVE PASSED")
    script.on_nth_tick(1, nil)
end)
