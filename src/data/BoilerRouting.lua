local BoilerInlet = require "model.energy.BoilerInlet"
local BoilerRouting = {}

---@class BoilerFeed
---@field name string
---@field probe number Feasible inlet in °C for the first flow calculation
---@field only_temperature? number Temperature of the sole available supply

---@param block BlockData
---@param boilers RecipeData[]
---@return table<string,BoilerFeed> feeds Row ID to possible supplies in this block
local function findFeeds(block, boilers)
    local feeds = {}
    for _, recipe in ipairs(boilers) do
        local entity = EntityPrototype(recipe.factory)
        local fluid = entity:getBoilerInletFluid()
        local temperatures = {}
        for _, product in pairs(block.products) do
            if product.type == "fluid" and product.name == fluid.name then
                temperatures[product.temperature or fluid.default_temperature] = true
            end
        end
        local first = next(temperatures)
        if first then
            local multiple = next(temperatures, first) ~= nil
            if multiple or first ~= fluid.default_temperature then
                local minimum, maximum, target = entity:getBoilerInletRange()
                local feed = {name=fluid.name, probe=minimum}
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
---@return table<string,BoilerRoute>
local function resolve(block, feeds)
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
                    local temperature = product.temperature or Player.getFluidPrototype(product.name).default_temperature
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
        local temperature, ambiguous = BoilerInlet.resolve(supplies[feed.name], demands[id] or 0)
        routes[id] = {temperature=temperature, ambiguous=ambiguous}
    end
    return routes
end

---@param block BlockData
---@param boilers RecipeData[]
---@param solve fun(trial:BlockData)
function BoilerRouting.apply(block, boilers, solve)
    local feeds = findFeeds(block, boilers)
    if not next(feeds) then return end

    -- Trial solves can change linked profiles and row constraints.
    local trial = table.deepcopy(block)
    for id, feed in pairs(feeds) do
        trial.children[id].factory.boiler_inlet_auto = feed.probe
    end
    solve(trial)
    local routes = resolve(trial, feeds)
    local verify = false
    for _, recipe in ipairs(boilers) do
        local route = routes[recipe.id]
        if route then
            recipe.factory.boiler_inlet_auto = route.temperature
            recipe.factory.boiler_inlet_ambiguous = route.ambiguous or nil
            if route.temperature and not feeds[recipe.id].only_temperature then verify = true end
        end
    end

    -- Changing the mixture can change a fixed boiler's demand and its suppliers' rates.
    if verify then
        local heated = table.deepcopy(block)
        solve(heated)
        local checked = resolve(heated, feeds)
        for _, recipe in ipairs(boilers) do
            local route = routes[recipe.id]
            if route and route.temperature then
                local revised = checked[recipe.id].temperature
                if not revised or math.abs(route.temperature - revised) > 1e-7 then
                    recipe.factory.boiler_inlet_auto = nil
                    recipe.factory.boiler_inlet_ambiguous = true
                end
            end
        end
    end
end

return BoilerRouting
