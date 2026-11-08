local BlockRemoval = {}

---@class BlockRemovalTarget
---@field model_id string
---@field block_id string Selected production block, including the root

---@class RequestBlockRemoval : BlockRemovalTarget
---@field action "block-remove"

---@class ConfirmBlockRemoval : BlockRemovalTarget
---@field action "block-remove-confirmed"

---@class CancelBlockRemoval : BlockRemovalTarget
---@field action "block-remove-canceled"

---@alias BlockRemovalAction RequestBlockRemoval | ConfirmBlockRemoval | CancelBlockRemoval

---@param event BlockRemovalAction
---@return string action, string model_id, string block_id
function BlockRemoval.buttonArgs(event)
    return event.action, event.model_id, event.block_id
end

---@param action string?
---@return "block-remove"|"block-remove-confirmed"|"block-remove-canceled"|nil
function BlockRemoval.tag(action)
    if action == "block-remove" or action == "block-remove-confirmed" or action == "block-remove-canceled" then
        return action
    end
    return nil
end

---@param event {action?:string, item1?:string, item2?:string}
---@return BlockRemovalAction?
function BlockRemoval.decode(event)
    local action = BlockRemoval.tag(event.action)
    if action == nil or event.item1 == nil or event.item2 == nil then return nil end
    return {action=action, model_id=event.item1, block_id=event.item2}
end

return BlockRemoval
