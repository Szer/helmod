local BlockHeader = {}

---@enum BlockHeaderAction
BlockHeader.action = {
    ingredients = "block-all-ingredient-visible",
    products = "block-all-product-visible",
    clear = "block-reset-input",
}

BlockHeader.setting = {ingredients = "block_all_ingredient_visible", products = "block_all_product_visible"}
BlockHeader.tooltip = {filter = "helmod_button.all-product-visible", ingredients = "helmod_button.all-ingredient-visible", clear = "helmod_button.clear"}

---@class BlockHeaderTarget
---@field model_id string
---@field block_id string

---@class ToggleHeaderIngredients : BlockHeaderTarget
---@field action "block-all-ingredient-visible"

---@class ToggleHeaderProducts : BlockHeaderTarget
---@field action "block-all-product-visible"

---@class ClearBlockInputs : BlockHeaderTarget
---@field action "block-reset-input"

---@alias BlockHeaderEdit ToggleHeaderIngredients|ToggleHeaderProducts|ClearBlockInputs

---@param edit BlockHeaderEdit
---@return BlockHeaderAction action, string model_id, string block_id
function BlockHeader.buttonArgs(edit)
    return edit.action, edit.model_id, edit.block_id
end

---@param event {action?:string,item1?:string,item2?:string}
---@return BlockHeaderEdit?
function BlockHeader.decode(event)
    if event.item1 == nil or event.item2 == nil then return nil end
    local action = event.action
    if action == BlockHeader.action.ingredients or action == BlockHeader.action.products or action == BlockHeader.action.clear then
        return {action=action, model_id=event.item1, block_id=event.item2}
    end
end

return BlockHeader
