local BlockMode = {}

---@enum BlockModeAction
BlockMode.action = {
    icon = "row-block-mode",
    consumer = "block-consumer",
    input = "block-by-product",
}

---@class BlockModeTarget
---@field model_id string
---@field block_id string

---@class BlockIconClick : BlockModeTarget
---@field action "row-block-mode"

---@class ToggleConsumer : BlockModeTarget
---@field action "block-consumer"

---@class ToggleInput : BlockModeTarget
---@field action "block-by-product"

---@alias BlockModeClick BlockIconClick|ToggleConsumer|ToggleInput

---@param click BlockModeClick
---@return BlockModeAction action, string model_id, string block_id
function BlockMode.buttonArgs(click)
    return click.action, click.model_id, click.block_id
end

---@param event {action?:string, item1?:string, item2?:string}
---@return BlockModeClick?
function BlockMode.decode(event)
    if event.item1 == nil or event.item2 == nil then return nil end
    local action = event.action
    if action == BlockMode.action.icon or action == BlockMode.action.consumer or action == BlockMode.action.input then
        return {action=action, model_id=event.item1, block_id=event.item2}
    end
end

return BlockMode
