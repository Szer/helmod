local silo = table.deepcopy(data.raw["rocket-silo"]["rocket-silo"])
silo.name = "orbit-test-silo"
silo.hidden = true
silo.fixed_recipe = "orbit-test-parts"
silo.rocket_parts_required = 100
silo.rocket_parts_storage_cap = 100
silo.lift_weight = 2000000
silo.rocket_entity = "orbit-test-rocket"
silo.rocket_engine_starting_speed_modifier_per_quality_level = 0
silo.arms_speed_modifier_per_quality_level = 0
silo.rocket_rising_speed_modifier_per_quality_level = 0
local rocket = table.deepcopy(data.raw["rocket-silo-rocket"]["rocket-silo-rocket"])
rocket.name = "orbit-test-rocket"
rocket.rising_speed = rocket.rising_speed * 2
rocket.engine_starting_speed = rocket.engine_starting_speed * 2
local recipe = table.deepcopy(data.raw.recipe["rocket-part"])
recipe.name = "orbit-test-parts"
recipe.energy_required = 2
recipe.ingredients = {{type="item", name="iron-plate", amount=4}}
recipe.results = {{type="item", name="rocket-part", amount=17}}
recipe.maximum_productivity = 0.5
data:extend{silo,rocket,recipe}

local burner = table.deepcopy(silo)
burner.name = "orbit-test-burner"
burner.energy_source = {type="burner", fuel_categories={"nuclear"}, effectivity=1, fuel_inventory_size=1, burnt_inventory_size=1}
data:extend{burner}

local residue_furnace = table.deepcopy(data.raw.furnace["stone-furnace"])
residue_furnace.name = "test-residue-furnace"
residue_furnace.energy_source.burnt_inventory_size = 1
local residue_fuel = table.deepcopy(data.raw.item.coal)
residue_fuel.name = "test-iron-residue-fuel"
residue_fuel.burnt_result = "iron-plate"
data:extend{residue_furnace, residue_fuel}

local unbuffered = table.deepcopy(silo)
unbuffered.name = "orbit-test-unbuffered"
unbuffered.rocket_parts_storage_cap = 0
data:extend{unbuffered}

-- Producing a gear leaves at least one extra plate even when both recipes run.
for _, recipe in ipairs({
    {name="balance-test-gear", ingredients={{type="item",name="iron-plate",amount=1}},
        results={{type="item",name="iron-gear-wheel",amount=1},{type="item",name="copper-plate",amount=2}}},
    {name="balance-test-plate", ingredients={{type="item",name="copper-plate",amount=1}},
        results={{type="item",name="iron-plate",amount=1}}}
}) do
    recipe.type = "recipe"
    recipe.main_product = recipe.results[1].name
    data:extend{recipe}
end

local turbine = table.deepcopy(data.raw["assembling-machine"]["chemical-plant"])
turbine.name = "energy-test-turbine"
turbine.energy_source = {type="void"}
data:extend{
    turbine,
    {
        type="recipe", name="energy-test-expansion", categories={"chemistry"}, energy_required=1,
        ingredients={{type="fluid", name="petroleum-gas", amount=15}},
        results={{type="fluid", name="steam", amount=30, temperature=165}, {type="fluid", name="water", amount=10}},
        main_product="steam"
    },
    {
        type="recipe", name="energy-test-vent", categories={"chemistry"}, energy_required=1,
        ingredients={{type="fluid", name="water", amount=10}}, results={},
        icon="__base__/graphics/icons/fluid/water.png"
    }
}

data:extend{{
    type="recipe", name="test-split-coal-return", categories={"crafting"}, enabled=true,
    energy_required=1, allow_productivity=true, auto_recycle=false, main_product="stone",
    ingredients={{type="item", name="coal", amount=1}},
    results={
        {type="item", name="stone", amount=1, ignored_by_productivity=1},
        {type="item", name="coal", amount=1, independent_probability=0.15},
        {type="item", name="coal", amount=1, independent_probability=0.15, ignored_by_productivity=1},
        {type="item", name="copper-plate", amount=2, independent_probability=0.5, ignored_by_productivity=1},
        {type="item", name="copper-plate", amount=1, ignored_by_productivity=1},
        {type="item", name="copper-plate", amount=1}
    }
}}

local acid_pump = table.deepcopy(data.raw["offshore-pump"]["offshore-pump"])
acid_pump.name = "test-acid-pump"
acid_pump.fluid_box.filter = "sulfuric-acid"
acid_pump.pumping_speed = 5
data:extend{acid_pump}

local function cableMachine(name, category, recipe)
    local machine = table.deepcopy(data.raw["assembling-machine"]["assembling-machine-2"])
    machine.name = name
    machine.fixed_recipe = recipe
    machine.crafting_categories = {category}
    data:extend{machine}
end
cableMachine("test-cable-assembler", "crafting", "copper-cable")
data:extend{{type="recipe-category", name="test-dedicated-crafting"}}
for _, name in ipairs({"test-dedicated-cable", "test-unbuildable-cable"}) do
    local recipe = table.deepcopy(data.raw.recipe["copper-cable"])
    recipe.name = name
    recipe.categories = {"test-dedicated-crafting"}
    recipe.auto_recycle = false
    data:extend{recipe}
end
cableMachine("test-dedicated-assembler", "test-dedicated-crafting", "test-dedicated-cable")

data:extend{{
    type="recipe", name="test-warm-water", categories={"chemistry"}, enabled=true,
    energy_required=1, ingredients={{type="item", name="stone", amount=1}},
    results={{type="fluid", name="water", temperature=100, amount=100}}, auto_recycle=false
}}

for _, feed in ipairs({
    {name="test-cold-water-coproduct", product="iron-plate", temperature=15},
    {name="test-hot-water-coproduct", product="copper-plate", temperature=100},
}) do
    data:extend{{
        type="recipe", name=feed.name, categories={"chemistry"}, enabled=true, auto_recycle=false,
        energy_required=1, ingredients={{type="item", name="stone", amount=1}},
        main_product=feed.product,
        results={{type="item", name=feed.product, amount=1}, {type="fluid", name="water", temperature=feed.temperature, amount=1}}
    }}
end

local low_target = table.deepcopy(data.raw.boiler.boiler)
low_target.name = "test-low-target-boiler"
low_target.target_temperature = 99
local hot_inlet = table.deepcopy(data.raw.boiler.boiler)
hot_inlet.name = "test-hot-inlet-boiler"
if helpers.compare_versions(helpers.game_version, "2.1.22") >= 0 then
    hot_inlet.minimum_input_temperature = 50
else
    hot_inlet.fluid_box.minimum_temperature = 50
end
data:extend{low_target, hot_inlet}
