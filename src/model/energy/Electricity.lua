local Electricity = {}

---@class ElectricityIngredient
---@field type "energy"
---@field name "energy"
---@field amount number Joules per craft

---@param watts number? Electrical load for one craft over the planning period
---@param seconds number? Planning period in seconds
---@return ElectricityIngredient?
function Electricity.ingredient(watts, seconds)
    if watts == nil or watts <= 0 or seconds == nil then return nil end
    return {type="energy", name="energy", amount=watts * seconds}
end

-- A powered vent is driven by the material it discards.
---@param products table
---@param ingredients table<string, {type: string, amount: number}>
---@return string?
function Electricity.ventMaterial(products, ingredients)
    if next(products) ~= nil or ingredients.energy == nil or ingredients.energy.type ~= "energy" then return nil end
    local material
    for key, ingredient in pairs(ingredients) do
        if key ~= "energy" then
            if material ~= nil or ingredient.amount <= 0 then return nil end
            material = key
        end
    end
    return material
end

return Electricity
