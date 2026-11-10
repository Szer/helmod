local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 1e-7, label .. ": expected " .. expected .. ", got " .. actual)
end

script.on_nth_tick(1, function()
    Player.set{name="admin", index=1, force=game.forces.player, mod_settings=settings.global, admin=true}
    local _, model = next(storage.models)
    local block = model.block_root
    local hot, fresh
    for key, ingredient in pairs(block.ingredients) do
        if ingredient.name == "triage-used-coolant" and ingredient.minimum_temperature == 250 then hot = key end
        if ingredient.name == "triage-coolant" then fresh = key end
    end
    assert(hot and fresh, "expected the saved hot and fresh coolant inputs")
    for _, solver in ipairs({defines.constant.solvers.default, defines.constant.solvers.matrix}) do
        User.setParameter("solver_selected", solver)
        for _, case in ipairs({
            {plates=8, hot=20, fresh=0}, {plates=4, hot=10, fresh=0},
            {plates=8, supply=hot, hot=20, fresh=0}, {plates=8, supply=fresh, hot=0, fresh=16}
        }) do
            block.solver = true
            block.products["iron-plate"].input = case.plates
            block.matrix_supplies = case.supply and {[case.supply]=true} or nil
            ModelCompute.updateNow(model)
            near(block.products["iron-plate"].amount, case.plates, "casting output")
            for key, ingredient in pairs(block.ingredients) do
                if ingredient.name == "triage-used-coolant" then
                    near(ingredient.amount, key == hot and case.hot or 0, "used coolant at " .. key)
                elseif key == fresh then
                    near(ingredient.amount, case.fresh, "fresh coolant makeup")
                end
            end
            near(block.products["triage-used-coolant#300"].amount, 0, "hot coolant surplus")
            near(block.products["steam#175"].amount, (case.plates * 10 + case.hot) / 4, "cooling throughput")
        end
    end
    local nested = Model.newModel()
    local parent = nested.block_root
    local loop = Model.newBlock(nested, block)
    loop.parent_id, loop.index = parent.id, 0
    parent.children[loop.id], nested.blocks[loop.id] = loop, loop
    ModelBuilder.copyBlock(nested, loop, block)
    loop.matrix_supplies = nil
    ModelCompute.updateNow(nested)
    parent.products["iron-plate"].input = 16
    ModelCompute.updateNow(nested)
    near(parent.products["iron-plate"].amount, 16, "scaled child output")
    near(parent.ingredients[hot].amount, 40, "scaled child coolant demand")
    log("COOLANT DEFICIT SAVE PASSED")
    script.on_nth_tick(1, nil)
end)
