local EntityType = require "model.EntityType"
local BoilerInlet = require "model.energy.BoilerInlet"
local BoilerRouting = {}

---@class BoilerFeed
---@field name string
---@field generator boolean
---@field probe number Feasible inlet in °C for the first flow calculation
---@field only_temperature? number Temperature of the sole available supply

---@param block BlockData
---@param inlets RecipeData[]
---@param outputs table<string,PlasmaOutput>
---@return table<string,BoilerFeed> feeds Row ID to possible supplies in this block
local function findFeeds(block, inlets, outputs)
    local feeds = {}
    for _, recipe in ipairs(inlets) do
        local entity = EntityPrototype(recipe.factory)
        local generator = entity:getType() == EntityType.fusionGenerator
        local fluid
        if generator then fluid = entity:getFluidConsumptionFilter()
        else fluid = entity:getBoilerInletFluid() end
        local temperatures = {}
        for _, product in pairs(block.products) do
            if product.type == "fluid" and product.name == fluid.name then
                local output = outputs[product.key]
                if output then
                    for temperature in pairs(output.temperatures) do temperatures[temperature] = true end
                else
                    temperatures[product.temperature or fluid.default_temperature] = true
                end
            end
        end
        local first = next(temperatures)
        if first then
            local multiple = next(temperatures, first) ~= nil
            if multiple or first ~= fluid.default_temperature or (generator and outputs[fluid.name]) then
                local minimum, maximum = entity:getFluidInletRange(fluid)
                local target = generator and math.huge or entity:getTargetTemperature()
                local feed = {name=fluid.name, probe=minimum, generator=generator}
                if not multiple then
                    feed.only_temperature = first
                    if first >= minimum and first <= maximum and first < target then feed.probe = first end
                end
                feeds[recipe.id] = feed
            end
        end
    end
    return feeds
end

---@class BoilerRoute
---@field temperature? number
---@field ambiguous boolean

---@param block BlockData Solved block
---@param feeds table<string,BoilerFeed>
---@param trial boolean
---@return table<string,BoilerRoute>
local function resolve(block, feeds, trial)
    ---@type table<string,BoilerSupply>
    local supplies = {}
    local demands = {}
    for _, feed in pairs(feeds) do
        supplies[feed.name] = {volumes={}, demand=0}
    end
    for _, child in pairs(block.children) do
        if child.count and child.count > 0 then
            local products, ingredients
            if child.class == "Block" then
                products, ingredients = child.products, child.ingredients
            else
                local recipe = RecipePrototype(child)
                products = recipe:getQualityProducts(child.factory, child.quality)
                ingredients = recipe:getQualityIngredients(child.factory, child.quality)
            end
            for _, product in pairs(products) do
                local supply = supplies[product.name]
                if product.type == "fluid" and supply then
                    local amount
                    if child.class == "Block" then
                        amount = product.amount * child.count
                    else
                        amount = Product(product):countProduct(child)
                    end
                    local temperature = product.fusion_temperature or product.temperature or Player.getFluidPrototype(product.name).default_temperature
                    supply.volumes[temperature] = (supply.volumes[temperature] or 0) + amount
                end
            end
            for _, ingredient in pairs(ingredients) do
                local supply = supplies[ingredient.name]
                if ingredient.type == "fluid" and supply then
                    local amount
                    if child.class == "Block" then
                        amount = ingredient.amount * child.count
                    else
                        amount = Product(ingredient):countIngredient(child)
                    end
                    supply.demand = supply.demand + amount
                    local feed = feeds[child.id]
                    if feed and feed.name == ingredient.name then demands[child.id] = amount end
                end
            end
        end
    end
    local routes = {}
    for id, feed in pairs(feeds) do
        local supply = supplies[feed.name]
        local temperature, ambiguous
        if feed.generator then
            temperature, ambiguous = BoilerInlet.resolve(supply, demands[id] or 0, trial, 1e-6)
        else
            temperature, ambiguous = BoilerInlet.resolve(supply, demands[id] or 0)
        end
        routes[id] = {temperature=temperature, ambiguous=ambiguous}
    end
    return routes
end

---@param factory FactoryData
---@param feed BoilerFeed
---@param temperature number?
---@param ambiguous boolean?
local function setInlet(factory, feed, temperature, ambiguous)
    if feed.generator then
        factory.fusion_inlet_auto, factory.fusion_inlet_ambiguous = temperature, ambiguous
    else
        factory.boiler_inlet_auto, factory.boiler_inlet_ambiguous = temperature, ambiguous
    end
end

---@param block BlockData
---@param inlets RecipeData[]
---@param solve fun(trial:BlockData)
---@param outputs? table<string,PlasmaOutput>
function BoilerRouting.apply(block, inlets, solve, outputs)
    local feeds = findFeeds(block, inlets, outputs or {})
    if not next(feeds) then return end

    -- Trial solves can change linked profiles and row constraints.
    local trial = table.deepcopy(block)
    for id, feed in pairs(feeds) do
        setInlet(trial.children[id].factory, feed, feed.probe)
    end
    solve(trial)
    local routes = resolve(trial, feeds, true)
    local verify = false
    for _, recipe in ipairs(inlets) do
        local route = routes[recipe.id]
        if route then
            setInlet(recipe.factory, feeds[recipe.id], route.temperature, route.ambiguous or nil)
            if route.temperature and not feeds[recipe.id].only_temperature then verify = true end
        end
    end

    -- Changing the mixture can change a fixed boiler's demand and its suppliers' rates.
    if verify then
        local heated = table.deepcopy(block)
        solve(heated)
        local checked = resolve(heated, feeds, false)
        for _, recipe in ipairs(inlets) do
            local route = routes[recipe.id]
            if route and route.temperature then
                local revised = checked[recipe.id].temperature
                local tolerance = 1e-7
                if feeds[recipe.id].generator then tolerance = tolerance * math.max(1, math.abs(route.temperature)) end
                if not revised or math.abs(route.temperature - revised) > tolerance then
                    setInlet(recipe.factory, feeds[recipe.id], nil, true)
                end
            end
        end
    end
end

return BoilerRouting
