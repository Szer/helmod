local FixedRecipe = {}

---@param machine {type:string, fixed_recipe?:{name:string}}?
---@param kind string?
---@param name string
---@return boolean
function FixedRecipe.allows(machine, kind, name)
    if kind ~= nil and kind ~= "recipe" and kind ~= "recipe-burnt" then return true end
    if machine == nil then return false end
    if machine.type ~= "assembling-machine" and machine.type ~= "rocket-silo" then return true end
    return machine.fixed_recipe == nil or machine.fixed_recipe.name == name
end

return FixedRecipe
