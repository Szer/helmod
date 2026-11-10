local RecipeTypes = require "model.recipe.RecipeTypes"
local FixedRecipe = {}

---@param machine {fixed_recipe?:{name:string}}?
---@param kind string?
---@param name string
---@return boolean
function FixedRecipe.allows(machine, kind, name)
    if kind ~= nil and kind ~= RecipeTypes.recipe.name and kind ~= RecipeTypes.burnt.name then return true end
    if machine == nil then return false end
    return machine.fixed_recipe == nil or machine.fixed_recipe.name == name
end

return FixedRecipe
