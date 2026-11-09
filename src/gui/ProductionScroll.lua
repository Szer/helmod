local BlockHeader = require "gui.controls.BlockHeader"
local BlockMode = require "gui.controls.BlockMode"
local BlockToolbar = require "gui.controls.BlockToolbar"
local ConstraintView = require "gui.controls.ConstraintView"
local TreeAction = require "gui.controls.TreeAction"

local ProductionScroll = {}

---@enum ProductionScrollPane
ProductionScroll.pane = {rows = "rows", header = "header"}

---@alias ProductionScrollTarget ProductionScrollPane|RowConstraintEdit

---@param event LuaEvent
---@param model ModelData
---@param removal ChildRemovalAction?
---@return ProductionScrollTarget? target A nil target rebuilds the whole panel.
function ProductionScroll.forUpdate(event, model, removal)
    local constraint = ConstraintView.edit(event)
    if constraint then return constraint end
    if BlockHeader.decode(event) then return ProductionScroll.pane.header end
    if removal or BlockToolbar.decodePanel(event) or BlockToolbar.decodeBlock(event) or event.action == BlockMode.action.consumer then
        return ProductionScroll.pane.rows
    end
    if event.action == BlockMode.action.icon and event.button == defines.mouse_button_type.left
        and event.control ~= event.shift then
        return ProductionScroll.pane.rows
    end
    local tree = TreeAction.decode(event)
    if tree and (tree.action == TreeAction.name.toggleLink or model.blocks[tree.block_id] or model.block_root.id == tree.block_id) then
        return ProductionScroll.pane.rows
    end
    return nil
end

return ProductionScroll
