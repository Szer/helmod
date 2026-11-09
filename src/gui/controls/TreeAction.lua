local TreeAction = {}

---@enum TreeActionName
TreeAction.name = {
    toggleLink = "block-unlink",
    blockToParent = "tree-block-down",
    blockToChild = "tree-block-up",
    recipeToParent = "tree-recipe-down",
    recipeToChild = "tree-recipe-up",
}

---@class ToggleBlockLink
---@field action "block-unlink"
---@field model_id string
---@field block_id string

---@class MoveTreeRow
---@field action "tree-block-down"|"tree-recipe-down"|"tree-block-up"|"tree-recipe-up"
---@field model_id string
---@field block_id string Source block
---@field child_id string

---@alias TreeEdit ToggleBlockLink|MoveTreeRow

---@param edit ToggleBlockLink
---@return TreeActionName action, string model_id, string block_id
function TreeAction.linkButtonArgs(edit)
    return edit.action, edit.model_id, edit.block_id
end

---@param edit MoveTreeRow
---@return TreeActionName action, string model_id, string block_id, string child_id
function TreeAction.moveButtonArgs(edit)
    return edit.action, edit.model_id, edit.block_id, edit.child_id
end

---@param action TreeActionName
---@return boolean
function TreeAction.toParent(action)
    return action == TreeAction.name.blockToParent or action == TreeAction.name.recipeToParent
end

---@param event {action?:string,item1?:string,item2?:string,item3?:string}
---@return TreeEdit?
function TreeAction.decode(event)
    local action = event.action
    if event.item1 == nil or event.item2 == nil then return nil end
    if action == TreeAction.name.toggleLink then
        return {action=action, model_id=event.item1, block_id=event.item2}
    end
    if event.item3 ~= nil and (action == TreeAction.name.blockToParent or action == TreeAction.name.recipeToParent
        or action == TreeAction.name.blockToChild or action == TreeAction.name.recipeToChild) then
        return {action=action, model_id=event.item1, block_id=event.item2, child_id=event.item3}
    end
    return nil
end

return TreeAction
