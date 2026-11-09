local ConstraintView = require "gui.controls.ConstraintView"
local ProductionScroll = {}

---@class ProductionView
---@field model_id string
---@field block_id string

---@param previous {model_id?:string,block_id?:string}
---@param current ProductionView
---@return boolean
function ProductionScroll.sameBlock(previous, current)
    return previous.model_id == current.model_id and previous.block_id == current.block_id
end

---@param list LuaGuiElement
---@param block BlockData
function ProductionScroll.clearRowCells(list, block)
	local keep = {}
	for id in pairs(block.children) do
		keep[GuiScroll(ConstraintView.side.products, id):getName()] = true
		keep[GuiScroll(ConstraintView.side.ingredients, id):getName()] = true
	end
	local cells = list.children
	for i = #cells, 1, -1 do
		local cell = cells[i]
		if keep[cell.name] then cell.clear() else cell.destroy() end
	end
end

return ProductionScroll
