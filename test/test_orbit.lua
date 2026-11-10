local check_electricity = require "test_electricity"
local check_nested = require "test_nested_intermediates"
local recycling = require "test_recycling_balance"
local check_cracking = require "test_cracking"
local check_balance_pivot = require "test_balance_pivot"
local Orbit = require "model.Orbit"
local function near(actual, expected, label)
    assert(math.abs(actual - expected) < 1e-8, label .. ": expected " .. expected .. ", got " .. tostring(actual))
end

local function checkSplitCoalReturn()
    local model = Model.newModel()
    local block, recipe = ModelBuilder.addRecipeIntoProductionBlock(model, model.block_root, "test-split-coal-return", "recipe")
    Model.setFactory(recipe, "assembling-machine-3")
    ModelCompute.update(model)
    block.products.stone.input = 1
    ModelCompute.update(model)
    near(block.ingredients.coal.amount, 0.70, "coal input with no productivity")
    model.parameters.effects.productivity = 3
    ModelCompute.update(model)
    near(block.products.stone.amount, 1, "productivity-exempt target")
    near(block.ingredients.coal.amount, 0.25, "coal input after split returns at +300% productivity")
    near(block.products.coal.amount, 0, "recycled coal surplus")
    near(block.products["copper-plate"].amount, 7.5, "three results with a partially exempt return")

    model.parameters.effects.quality = 0.1
    ModelCompute.update(model)
    local gross_coal = 0
    for _, result in ipairs(RecipePrototype(recipe):getQualityProducts(recipe.factory, recipe.quality)) do
        if result.name == "coal" then gross_coal = gross_coal + Product(result):getAmount(recipe) end
    end
    near(gross_coal, 0.75, "gross coal return across qualities")
end

local function checkOffshoreExtraction()
    local function offers(fluid, name)
        for _, pump in pairs(RecipePrototype(fluid, "fluid"):getAllowedMachines()) do
            if pump.name == name then return true end
        end
        return false
    end
    assert(Player.getFluidRecipes()["sulfuric-acid"], "a filtered pump supplies acid without an acid tile")
    assert(offers("water", "offshore-pump") and not offers("water", "test-acid-pump"))
    assert(offers("sulfuric-acid", "test-acid-pump") and not offers("sulfuric-acid", "offshore-pump"))
    local model = Model.newModel()
    local block, acid = ModelBuilder.addRecipeIntoProductionBlock(model, model.block_root, "sulfuric-acid", "fluid")
    assert(acid.factory.name == "test-acid-pump")
    ModelCompute.update(model)
    block.products["sulfuric-acid"].input = 600
    ModelCompute.update(model)
    near(acid.factory.count, 2, "two pumps at five acid per tick")
    local old_defaults = table.deepcopy(User.getParameter("default_factory"))
    Model.setFactory(acid, "test-acid-pump", "uncommon")
    User.setDefaultFactory(acid)
    local _, water = ModelBuilder.addRecipeIntoProductionBlock(model, block, "water", "fluid")
    assert(water.factory.name == "offshore-pump", "ignore an incompatible extraction default")
    local second = Model.newModel()
    local _, other_acid = ModelBuilder.addRecipeIntoProductionBlock(second, second.block_root, "sulfuric-acid", "fluid")
    assert(other_acid.factory.name == "test-acid-pump" and other_acid.factory.quality == "uncommon", "keep a compatible default")
    User.setParameter("default_factory", old_defaults)
    Model.setFactory(water, "test-acid-pump", "uncommon")
    ModelCompute.update(model)
    assert(water.factory.name == "offshore-pump" and water.factory.quality == "uncommon", "repair saved incompatible pump")
    assert(acid.factory.name == "test-acid-pump" and block.products["sulfuric-acid"].input == 600)
end

local function check(background)
    settings.global.helmod_incremental_percentages = {value=background}
    assert(script.feature_flags.space_travel == true, "orbit feature flag")
    EventController.onInit()
    -- Map creation has no player, so supply the player context used by Helmod.
    Player.set{name="OrbitTester", index=1, force=game.forces.player, mod_settings=settings.global, admin=true, print=function(message) error(message) end}
    local model = Model.newModel()
    local block, recipe = ModelBuilder.addRecipeIntoProductionBlock(model, model.block_root, "automation-science-pack", "orbit")
    assert(recipe.factory and recipe.factory.name == "rocket-silo", "default silo")
    ModelCompute.update(model)

    near(Orbit.capacity("automation-science-pack", prototypes.entity["rocket-silo"]), 1000, "science capacity")
    near(Orbit.capacity("transport-belt", prototypes.entity["rocket-silo"]), 100, "belt capacity")
    assert(block.products["orbit/automation-science-pack#normal"], "distinct orbital output")
    assert(block.ingredients["automation-science-pack"], "ground cargo input")
    block.products["orbit/automation-science-pack#normal"].input = 60
    ModelCompute.update(model)
    assert(not recipe.orbit.at_launch_limit, "slow construction does not reach launch limit")
    near(recipe.factory.count, 9, "60 science/s crafting-limited silos")
    near(block.ingredients["automation-science-pack"].amount, 60, "cargo unchanged")
    local before = block.ingredients["processing-unit"].amount
    model.parameters.effects.productivity = 1
    ModelCompute.update(model)
    near(block.ingredients["processing-unit"].amount, before / 2, "productivity reduces parts ingredients")
    near(block.ingredients["automation-science-pack"].amount, 60, "productivity never duplicates cargo")
    near(recipe.factory.count, 4.5, "productivity accelerates construction")
    local target_speed = recipe.orbit.speed_required
    for _, factor in ipairs{0.999, 1, 1.001} do
        model.parameters.effects.speed = target_speed * factor - 1
        ModelCompute.update(model)
        assert(recipe.orbit.at_launch_limit == (factor >= 1), "launch target boundary " .. factor)
    end
    model.parameters.effects.speed = 100
    ModelCompute.update(model)
    near(recipe.factory.count, 60 / 1000 * 1617 / 60, "animation cap")
    recipe.factory.quality = "legendary"
    ModelCompute.update(model)
    near(recipe.factory.count, 60 / 1000 * 1097 / 60, "quality animation cap")
    near(block.ingredients["processing-unit"].amount, before / 2, "speed never changes ingredient consumption")
    local smelting = Model.newModel()
    local furnace_block, smelt = ModelBuilder.addRecipeIntoProductionBlock(smelting, smelting.block_root, "iron-plate", "recipe")
    Model.setFactory(smelt, "test-residue-furnace", "normal", "test-iron-residue-fuel", "normal")
    ModelCompute.update(smelting)
    furnace_block.products["iron-plate"].input = 1
    for _, matrix in ipairs({false, true}) do
        furnace_block.solver = matrix
        ModelCompute.update(smelting)
        local fuel_per_craft = 90000 * 3.2 / 4000000
        near(furnace_block.ingredients["iron-ore"].amount, 1 / (1 + fuel_per_craft), "ore for smelted plates plus burnt residue")
        near(furnace_block.ingredients["test-iron-residue-fuel"].amount, fuel_per_craft / (1 + fuel_per_craft), "residue fuel")
    end
    smelt.factory.fuel_quality = "uncommon"
    ModelCompute.update(smelting)
    near(furnace_block.ingredients["iron-ore"].amount, 1, "uncommon residue cannot supply normal plate demand")
    assert(furnace_block.products["iron-plate#uncommon"].amount > 0, "separate residue quality")

    near(Orbit.capacity("express-transport-belt", prototypes.entity["rocket-silo"]), 100, "express belt capacity")
    model.parameters.effects.speed = 0
    model.parameters.effects.productivity = 0
    recipe.factory.quality = "normal"
    ModelBuilder.setFactoryModulePriority(recipe, {{name="productivity-module-3", quality="normal", amount=4}})
    ModelCompute.update(model)
    near(recipe.factory.effects.productivity, 0.4, "four productivity modules")
    near(recipe.factory.effects.speed, -0.6, "module speed penalty")
    near(block.ingredients["processing-unit"].amount, before / 1.4, "module productivity")
    local speed_before = recipe.factory.speed_total
    local beacon = Model.addBeacon(recipe,"beacon","normal",8,8,0)
    ModelBuilder.setBeaconModulePriority(beacon,recipe,{{name="speed-module-3",quality="normal",amount=2}})
    ModelCompute.update(model)
    assert(recipe.factory.speed_total > speed_before, "beacon speed affects orbital construction")
    near(block.ingredients["processing-unit"].amount, before / 1.4, "beacons preserve ingredients")
    recipe.beacons = {}
    game.forces.player.technologies["rocket-part-productivity"].level = 6
    ModelCompute.update(model)
    near(recipe.factory.effects.productivity, 0.9, "research plus module productivity")
    model.parameters.effects.productivity = 10
    ModelCompute.update(model)
    near(recipe.factory.effects.productivity, 3, "recipe productivity cap")
    model.parameters.effects.productivity = 0
    ModelBuilder.addRecipeIntoProductionBlock(model, block, "automation-science-pack", "recipe")
    ModelCompute.update(model)
    near(block.ingredients["automation-science-pack"].amount, 0, "cargo production is linked")
    near(block.ingredients["copper-plate"].amount, 60, "linked copper demand")
    block.products["orbit/automation-science-pack#normal"].input = 120
    ModelCompute.update(model)
    near(block.ingredients["copper-plate"].amount, 120, "linked demand recalculates")
    recipe.quality = "uncommon"
    ModelCompute.update(model)
    assert(block.products["orbit/automation-science-pack#uncommon"], "cargo quality output")
    assert(block.ingredients["automation-science-pack#uncommon"], "cargo quality ingredient")
    assert(block.ingredients["processing-unit"], "rocket ingredients stay normal quality")
    local copied = helpers.json_to_table(helpers.table_to_json(model))
    ModelCompute.update(copied)
    assert(copied.block_root.products["orbit/automation-science-pack#uncommon"], "serialization round trip")
    for _, solver in pairs({defines.constant.solvers.default, defines.constant.solvers.matrix}) do
        User.setParameter("solver_selected", solver)
        for _, simplex in ipairs({false, true}) do
            local sample=Model.newModel()
            sample.block_root.solver=simplex
            local b,r=ModelBuilder.addRecipeIntoProductionBlock(sample,sample.block_root,"transport-belt","orbit")
            ModelCompute.update(sample)
            b.products["orbit/transport-belt#normal"].input=60
            ModelCompute.update(sample)
            near(r.count,60,"solver orbital demand")
            near(b.ingredients["transport-belt"].amount,60,"solver cargo demand")
            local silo_count=r.factory.count
            sample.time=60
            ModelCompute.update(sample)
            near(r.factory.count,silo_count/60,"base time scaling")
        end
    end
    local custom=Model.newModel()
    local cb,cr=ModelBuilder.addRecipeIntoProductionBlock(custom,custom.block_root,"iron-plate","orbit")
    Model.setFactory(cr,"orbit-test-silo")
    custom.parameters.effects.productivity=10
    ModelCompute.update(custom)
    near(cr.factory.effects.productivity,0.5,"custom recipe productivity cap")
    near(cr.orbit.capacity,2000,"custom lift capacity")
    near(cr.orbit.parts,100,"custom rocket part count")
    near(cb.ingredients["iron-plate"].amount,1+100/2000/1.5*4,"custom recipe consumes crafts, ignores recipe output amount")
    local custom_ticks=cr.orbit.launch_time
    cr.factory.quality="legendary"
    ModelCompute.update(custom)
    near(cr.orbit.launch_time,custom_ticks,"custom quality modifiers")
    assert(custom_ticks < 1617/60,"custom rocket animation speeds")
    Model.setFactory(cr,"orbit-test-burner", "normal", "uranium-fuel-cell", "normal")
    custom.parameters.effects.productivity=0
    ModelCompute.update(custom)
    assert(cb.ingredients.energy == nil, "switching to a burner clears electrical demand")
    local fuel = cb.ingredients["uranium-fuel-cell"].amount
    assert(fuel > 0, "burner fuel consumption")
    near(cb.products["depleted-uranium-fuel-cell"].amount, fuel, "burnt fuel output")
    custom.parameters.effects.productivity=0.5
    ModelCompute.update(custom)
    near(cb.ingredients["uranium-fuel-cell"].amount, fuel/1.5, "productive construction fuel")
    Model.setFactory(cr,"orbit-test-unbuffered")
    custom.parameters.effects.speed=100
    ModelCompute.update(custom)
    assert(cr.factory.speed_total>cr.orbit.speed_required,"unbuffered silo exceeds crafting target")
    assert(not cr.orbit.at_launch_limit,"unbuffered silo cannot sustain minimum launch interval")
    recipe.factory.quality="legendary"
    User.setDefaultFactory(recipe)
    local defaults=Model.newModel()
    local _,dr=ModelBuilder.addRecipeIntoProductionBlock(defaults,defaults.block_root,"transport-belt","orbit")
    assert(dr.factory.quality=="legendary","saved silo quality default")
    checkOffshoreExtraction()
    checkSplitCoalReturn()
    check_electricity()
    check_cracking()
    recycling.check()
    check_nested()
    check_balance_pivot()
    log("ORBIT TESTS PASSED")
end

script.on_init(function() check(false) end)
return check
