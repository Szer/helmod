local function near(actual, expected)
    assert(math.abs(actual - expected) < 1e-6, "expected " .. expected .. ", got " .. actual)
end

script.on_nth_tick(1, function()
    Player.set{name="admin", index=1, force=game.forces.player, mod_settings=settings.global, admin=true}
    local _, model = next(storage.models)
    local block = model.block_root
    local row = block.children.R1
    assert(row.name == "muluna-cycling-steam-turbine" and row.type == "energy")
    near(block.products.energy.input, 9e6)
    for _, solver in ipairs({defines.constant.solvers.default, defines.constant.solvers.matrix}) do
        User.setParameter("solver_selected", solver)
        for _, simplex in ipairs({false, true}) do
            block.solver = simplex
            for _, case in ipairs({
                {quality="normal", demand=9e6, count=1, flow=90},
                {quality="normal", demand=4.5e6, count=0.5, flow=45},
                {quality="legendary", demand=22.5e6, count=1, flow=225}
            }) do
                row.factory.quality = case.quality
                block.products.energy.input = case.demand
                ModelCompute.updateNow(model)
                near(row.factory.count, case.count)
                near(block.products.energy.amount, case.demand)
                near(block.ingredients.steam.amount, case.flow)
                near(block.products.water.amount, case.flow)
            end
        end
    end
    log("FUSION GENERATOR SAVE PASSED")
    script.on_nth_tick(1, nil)
end)
