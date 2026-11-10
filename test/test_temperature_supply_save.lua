local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 1e-7, label .. ": expected " .. expected .. ", got " .. actual)
end

script.on_nth_tick(1, function()
    Player.set{name="admin", index=1, force=game.forces.player, mod_settings=settings.global, admin=true}
    local _, model = next(storage.models)
    local block = model.block_root
    for _, solver in ipairs({defines.constant.solvers.default, defines.constant.solvers.matrix}) do
        User.setParameter("solver_selected", solver)
        for _, simplex in ipairs({false, true}) do
            block.solver = simplex
            block.products["steam#125"].input = nil
            ModelCompute.updateNow(model)
            near(block.products["stone-brick"].amount, 50, "brick target")
            near(block.ingredients.stone.amount, 50, solver .. " stone for 500 steam, simplex " .. tostring(simplex))
            for _, temperature in ipairs({125, 150, 175}) do
                near(block.products["steam#" .. temperature].amount, 0, "unused steam at " .. temperature)
            end
            near(block.ingredients.steam.amount, 0, "imported steam")
            block.products["steam#125"].input = 50
            ModelCompute.updateNow(model)
            near(block.ingredients.stone.amount, 55, "stone for 500 mixed steam and 50 exported steam")
            near(block.products["steam#125"].amount, 50, "cold export")
        end
    end
    log("TEMPERATURE SUPPLY SAVE PASSED")
    script.on_nth_tick(1, nil)
end)
