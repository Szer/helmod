local ChildRemoval = {}

---@class ChildRemovalTarget
---@field model_id string
---@field block_id string Parent production block
---@field child_id string Recipe or nested block in the parent

---@class RequestChildRemoval : ChildRemovalTarget
---@field action "block-child-remove"

---@class ConfirmChildRemoval : ChildRemovalTarget
---@field action "block-child-remove-confirmed"

---@class CancelChildRemoval : ChildRemovalTarget
---@field action "block-child-remove-canceled"

---@alias ChildRemovalAction RequestChildRemoval | ConfirmChildRemoval | CancelChildRemoval

---@param event ChildRemovalAction
---@return string action, string model_id, string block_id, string child_id
function ChildRemoval.buttonArgs(event)
    return event.action, event.model_id, event.block_id, event.child_id
end

---@param event {action?:string, item1?:string, item2?:string, item3?:string}
---@return ChildRemovalAction?
function ChildRemoval.decode(event)
    if event.item1 == nil or event.item2 == nil or event.item3 == nil then return nil end
    local action = event.action
    if action == "block-child-remove" or action == "block-child-remove-confirmed" or action == "block-child-remove-canceled" then
        return {action=action, model_id=event.item1, block_id=event.item2, child_id=event.item3}
    end
    return nil
end

return ChildRemoval
