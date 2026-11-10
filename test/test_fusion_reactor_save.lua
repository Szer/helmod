local function near(actual, expected)
    assert(math.abs(actual - expected) < 1e-5 * math.max(1, expected), "expected " .. expected .. ", got " .. tostring(actual))
end

script.on_nth_tick(1, function()
    Player.set{name="admin", index=1, force=game.forces.player, mod_settings=settings.global, admin=true}
    local _, model = next(storage.models)
    local block = model.block_root
    local reactor = block.children.R1
    assert(reactor.name == "fusion-reactor" and reactor.factory.fusion_neighbours == nil)
    for _, neighbours in ipairs({0, 1}) do
        if neighbours > 0 then reactor.factory.fusion_neighbours = neighbours end
        ModelCompute.updateNow(model)
        near(reactor.factory.count, 2)
        near(block.products["fusion-plasma"].amount, 8)
        near(block.products["fusion-plasma"].fusion_temperature, 1e6 * (1 + neighbours))
        near(block.ingredients["fluoroketone-cold"].amount, 8)
        near(block.ingredients["fusion-power-cell"].amount, 0.005)
        near(block.ingredients.energy.amount, 20e6)
    end
    log("FUSION REACTOR SAVE PASSED")
    script.on_nth_tick(1, nil)
end)
