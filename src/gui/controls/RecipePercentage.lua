local RecipePercentage = {action = "recipe-update-production"}

---@class RecipePercentageEdit
---@field action "recipe-update-production"
---@field model_id string
---@field block_id string
---@field recipe_id string

---@param edit RecipePercentageEdit
---@return string action, string model_id, string block_id, string recipe_id
function RecipePercentage.buttonArgs(edit)
    return edit.action, edit.model_id, edit.block_id, edit.recipe_id
end

---@param event {action?:string,item1?:string,item2?:string,item3?:string}
---@return RecipePercentageEdit?
function RecipePercentage.decode(event)
    if event.action == RecipePercentage.action and event.item1 and event.item2 and event.item3 then
        return {action=RecipePercentage.action, model_id=event.item1, block_id=event.item2, recipe_id=event.item3}
    end
end

return RecipePercentage
