local RecipeSearchIndex = {}

---@class RecipeSearchEntry
---@field name string
---@field type string
---@field group string
---@field subgroup string
---@field order string?

---@alias RecipeMaterialIndex table<string, table<string, RecipeSearchEntry>>

---@param index RecipeMaterialIndex
---@param material string
---@param key string
---@param entry RecipeSearchEntry
local function add(index, material, key, entry)
    local recipes = index[material]
    if recipes == nil then
        recipes = {}
        index[material] = recipes
    end
    recipes[key] = entry
end

---@param index RecipeMaterialIndex
---@param entry RecipeSearchEntry
---@param materials {name:string}[]?
---@param translate fun(material:{name:string})
function RecipeSearchIndex.register(index, entry, materials, translate)
    local key = entry.type .. "-" .. entry.name
    if materials == nil or next(materials) == nil then
        -- An empty material name matches only an empty filter.
        add(index, "", key, entry)
        return
    end
    for _, material in pairs(materials) do
        if material.name ~= nil then
            add(index, material.name, key, entry)
            translate(material)
        end
    end
end

return RecipeSearchIndex
