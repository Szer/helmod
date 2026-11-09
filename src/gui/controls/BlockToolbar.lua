local BlockToolbar = {}

---@enum BlockToolbarAction
BlockToolbar.action = {
    deep = "display-count-deep",
    limit = "block-limit",
    reset = "reset-production",
    logistics = "change-logistic",
    item = "change-logistic-item",
    fluid = "change-logistic-fluid",
    location = "change-location",
}

BlockToolbar.tooltip = {
    deep = "tooltip.display-deep-count",
    limit = "helmod_label.assembler-limitation",
    reset = "helmod_button.reset-block-production",
    logistics = "tooltip.display-logistic-row",
}

BlockToolbar.setting = {
    deep = "display_count_deep",
    logistics = "display_logistic_row",
    item = "logistic_row_item",
    fluid = "logistic_row_fluid",
}

---@class BlockToolbarTarget
---@field model_id string
---@field block_id string

---@class ToolbarDeep : BlockToolbarTarget
---@field action "display-count-deep"

---@class ToolbarLimit : BlockToolbarTarget
---@field action "block-limit"

---@class ToolbarReset : BlockToolbarTarget
---@field action "reset-production"

---@class ToolbarLogistics
---@field action "change-logistic"

---@class ToolbarItem
---@field action "change-logistic-item"

---@class ToolbarFluid
---@field action "change-logistic-fluid"

---@class ToolbarLocation
---@field action "change-location"

---@alias ScopedToolbarEdit ToolbarDeep|ToolbarLimit|ToolbarReset
---@alias PanelToolbarEdit ToolbarLogistics|ToolbarItem|ToolbarFluid|ToolbarLocation
---@alias ToolbarEdit ScopedToolbarEdit|PanelToolbarEdit

---@param edit PanelToolbarEdit
---@return BlockToolbarAction
function BlockToolbar.panelAction(edit)
    return edit.action
end

---@param edit ScopedToolbarEdit
---@return BlockToolbarAction action, string model_id, string block_id
function BlockToolbar.buttonArgs(edit)
    return edit.action, edit.model_id, edit.block_id
end

---@param event {action?:string,item1?:string,item2?:string}
---@return ToolbarEdit?
function BlockToolbar.decode(event)
    local action = event.action
    if action == BlockToolbar.action.logistics or action == BlockToolbar.action.item
        or action == BlockToolbar.action.fluid or action == BlockToolbar.action.location then
        return {action=action}
    end
    if event.item1 and event.item2 and (action == BlockToolbar.action.deep
        or action == BlockToolbar.action.limit or action == BlockToolbar.action.reset) then
        return {action=action, model_id=event.item1, block_id=event.item2}
    end
end

return BlockToolbar
