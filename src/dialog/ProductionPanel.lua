local MatrixSupply = require "gui.controls.MatrixSupply"
local MatrixSupplies = require "model.MatrixSupplies"
local SheetPlanner = require "data.SheetPlanner"
local ProductionScroll = require "gui.ProductionScroll"
local BlockToolbar = require "gui.controls.BlockToolbar"
local BlockHeader = require "gui.controls.BlockHeader"
local ProductionBlockMode = require "model.ProductionBlockMode"
local BlockMode = require "gui.controls.BlockMode"
local TreeAction = require "gui.controls.TreeAction"
local DisplayMode = require "gui.controls.DisplayMode"
local BlockRemoval = require "gui.controls.BlockRemoval"
local ChildRemoval = require "gui.controls.ChildRemoval"
local ConstraintView = require "gui.controls.ConstraintView"
local resultTableName = "list-data"
local Orbit = require "model.Orbit"
-------------------------------------------------------------------------------
---Class to build production panel
---@class ProductionPanel : FormModel
ProductionPanel = newclass(FormModel, function(base, classname)
	FormModel.init(base, classname)
	base.add_special_button = true
	base.has_tips = true
	base.auto_clear = false
end)

-------------------------------------------------------------------------------
---On initialization
function ProductionPanel:onInit()
	self.panelCaption = string.format("Helmod: Szer's Fork %s", script.active_mods[script.mod_name])
end

-------------------------------------------------------------------------------
---On Bind Dispatcher
function ProductionPanel:onBind()
	Dispatcher:bind("on_gui_recipe_update", self, self.update)
	Dispatcher:bind("on_gui_refresh", self, self.update)
	Dispatcher:bind("on_gui_pause", self, self.updateTopMenu)
end

-------------------------------------------------------------------------------
---Return button caption
---@return string
function ProductionPanel:getButtonCaption()
	local model, block, recipe = self:getParameterObjects()
	if block == nil then return { "helmod_result-panel.tab-button-production-line" } end
	return { "helmod_result-panel.tab-button-production-block" }
end

-------------------------------------------------------------------------------
---Get Button Sprites
---@return string, string
function ProductionPanel:getButtonSprites()
	return "factory-white", "factory"
end

-------------------------------------------------------------------------------
---Is visible
---@return boolean
function ProductionPanel:isVisible()
	return true
end

-------------------------------------------------------------------------------
---On Style
---@param styles table
---@param width_main number
---@param height_main number
function ProductionPanel:onStyle(styles, width_main, height_main)
	styles.block_info = {
		height = 60 * 2 + 40,
	}
end

-------------------------------------------------------------------------------
---Get or create result panel
---@return LuaGuiElement, LuaGuiElement
function ProductionPanel:getResultPanel()
	local panel = self:getFramePanel("result", nil, "horizontal")
	local panel_name1 = "result1"
	local panel_name2 = "result2"
	if panel[panel_name1] ~= nil and panel[panel_name1].valid then
		return panel[panel_name1], panel[panel_name2]
	end

	local panel1 = GuiElement.add(panel, GuiFlowH(panel_name1))
	panel1.style.horizontally_stretchable = true
	panel1.style.padding = 2
	panel1.style.width = 120
	
	local panel2 = GuiElement.add(panel, GuiFlowV(panel_name2))
	panel2.style.horizontally_stretchable = true
	panel2.style.vertically_stretchable = true
	panel2.style.padding = 2
	--panel2.style.natural_width = width_main - 25
	return panel1, panel2
end

-------------------------------------------------------------------------------
---Get or create result scroll panel
---@return LuaGuiElement
function ProductionPanel:getNavigatorPanel()
	local panel1, panel2 = self:getResultPanel()
	local panel_name = "panel-navigator"
	local scroll_name = "scroll-navigator"
	if panel1[panel_name] ~= nil and panel1[panel_name].valid then
		return panel1[panel_name][scroll_name]
	end
	
	local panel = GuiElement.add(panel1, GuiFrameV(panel_name):style("helmod_deep_frame"))
	panel.style.padding = 0
	
	local scroll_panel = GuiElement.add(panel, GuiScroll(scroll_name):style("helmod_scroll_pane"))
	scroll_panel.style.vertically_stretchable = true
	scroll_panel.style.horizontally_stretchable = true
	scroll_panel.style.margin = 0
	return scroll_panel
end

-------------------------------------------------------------------------------
---Get or create result scroll panel
---@return LuaGuiElement, LuaGuiElement, LuaGuiElement
function ProductionPanel:getDataPanel()
	local panel1, panel2 = self:getResultPanel()
	local menu_name = "menu-data"
	local header_name = "header-data"
	local panel_name = "panel-data"
	local scroll_name = "scroll-data"
	if panel2[menu_name] ~= nil and panel2[menu_name].valid then
		return panel2[menu_name], panel2[header_name], panel2[panel_name][scroll_name]
	end
	local menu_panel = GuiElement.add(panel2, GuiFlowH(menu_name))
	menu_panel.style.horizontally_stretchable = true

	local header_panel = GuiElement.add(panel2, GuiFlowH(header_name))
	header_panel.style.horizontally_stretchable = true
	header_panel.style.top_padding = 6
	header_panel.style.bottom_padding = 6

	local data_panel = GuiElement.add(panel2, GuiFrameV(panel_name):style("helmod_deep_frame"))
	data_panel.style.padding = 0
	local scroll_panel = GuiElement.add(data_panel, GuiScroll(scroll_name):style("helmod_scroll_pane"))
	scroll_panel.style.horizontally_stretchable = true
	scroll_panel.style.vertically_stretchable = true
	return menu_panel, header_panel, scroll_panel
end

local statusSprites = {
    ready = "utility/status_working",
    pending = "utility/status_yellow",
    failed = "utility/status_not_working",
}

---@param info LuaGuiElement
---@return LuaGuiElement label, LuaGuiElement indicator
local function infoHeading(info)
    local heading = info["block-heading"]
    if not heading then
        heading = GuiElement.add(info, GuiFlowH("block-heading"))
        heading.style.vertical_align = "center"
        local label = GuiElement.add(heading, GuiLabel("label-info"):style(defines.styles.label.frame_title))
        local indicator = GuiElement.add(heading, GuiSprite("solver-status"):sprite(statusSprites.ready))
        indicator.style.size = 16
        local previous = info["label-info"]
        if previous then
            label.tooltip = previous.tooltip
            info.swap_children(previous.get_index_in_parent(), heading.get_index_in_parent())
            previous.destroy()
        end
    end
    return heading["label-info"], heading["solver-status"]
end

-------------------------------------------------------------------------------
---Get or create info panel
---@return LuaGuiElement, LuaGuiElement, LuaGuiElement
function ProductionPanel:getInfoPanel2()
	local menu_panel, header_panel, scroll_panel = self:getDataPanel()
	local info_name = "info"
	local info_scroll_name = "info-scroll"
	local left_name = "left-info"
	local right_name = "right-info"
	if header_panel[info_name] ~= nil and header_panel[info_name].valid then
		return header_panel[info_name][info_scroll_name], header_panel[left_name], header_panel[right_name]
	end
	header_panel.style.horizontal_spacing = 10
	self:setStyle(header_panel, "block_info", "height")

	local info_panel = GuiElement.add(header_panel, GuiFlowV(info_name))
	infoHeading(info_panel)
	local info_scroll = GuiElement.add(info_panel, GuiScroll(info_scroll_name):style("helmod_scroll_pane"))
	info_scroll.style.width = 300

	local left_panel = GuiElement.add(header_panel, GuiFlowV(left_name))

	local right_panel = GuiElement.add(header_panel, GuiFlowV(right_name))

	return info_scroll, left_panel, right_panel
end

-------------------------------------------------------------------------------
---Get or create left info panel
---@return LuaGuiElement, LuaGuiElement, LuaGuiElement
function ProductionPanel:getLeftInfoPanel2()
	local _, parent_panel, _ = self:getInfoPanel2()
	local panel_name = "left-scroll"
	local header_name = "left-header"
	local label_name = "left-label"
	local tool_name = "left-tool"
	if parent_panel[panel_name] ~= nil and parent_panel[panel_name].valid then
		return parent_panel[header_name][label_name], parent_panel[header_name][tool_name], parent_panel[panel_name]
	end
	local header_panel = GuiElement.add(parent_panel, GuiFlowH(header_name))
	local label_panel = GuiElement.add(header_panel, GuiLabel(label_name):caption({ "helmod_common.output" }):style("helmod_label_title_frame"))
	local tool_panel = GuiElement.add(header_panel, GuiFlowH(tool_name))
	tool_panel.style.horizontal_spacing = 3
	--tool_panel.style.horizontally_stretchable = true
	--tool_panel.style.horizontal_align = "right"
	local scroll_panel = GuiElement.add(parent_panel, GuiScroll(panel_name):style("helmod_scroll_pane"))
	--scroll_panel.style.horizontally_stretchable = true

	return label_panel, tool_panel, scroll_panel
end

-------------------------------------------------------------------------------
---Get or create right info panel
---@return LuaGuiElement, LuaGuiElement, LuaGuiElement
function ProductionPanel:getRightInfoPanel2()
	local _, _, parent_panel = self:getInfoPanel2()
	local panel_name = "right-scroll"
	local header_name = "right-header"
	local label_name = "right-label"
	local tool_name = "right-tool"
	if parent_panel[panel_name] ~= nil and parent_panel[panel_name].valid then
		return parent_panel[header_name][label_name], parent_panel[header_name][tool_name], parent_panel[panel_name]
	end
	local header_panel = GuiElement.add(parent_panel, GuiFlowH(header_name))
	local label_panel = GuiElement.add(header_panel, GuiLabel(label_name):caption({ "helmod_common.input" }):style("helmod_label_title_frame"))
	local tool_panel = GuiElement.add(header_panel, GuiFlowH(tool_name))
	tool_panel.style.horizontal_spacing = 3
	--tool_panel.style.horizontally_stretchable = true
	--tool_panel.style.horizontal_align = "right"
	local scroll_panel = GuiElement.add(parent_panel, GuiScroll(panel_name):style("helmod_scroll_pane"))
	--scroll_panel.style.horizontally_stretchable = true

	return label_panel, tool_panel, scroll_panel
end

-------------------------------------------------------------------------------
---Get the menu panel
---@return LuaGuiElement, LuaGuiElement
function ProductionPanel:getSubMenuPanel()
	local width = GuiElement.getWidthMainPanel()
	local one_line = true
	-- 1.25 1741 1.5 1451
	if width < 1700 then
		one_line = false
	end

	local ui_menu_lines = User.getPreferenceSetting("ui_menu_lines")
	if ui_menu_lines == "one line" then
		one_line = true
	end
	if ui_menu_lines == "two lines" then
		one_line = false
	end
	
	local menu_panel, header_panel, scroll_panel = self:getDataPanel()
	local panel_name = "menu"
	local left_name = "left_menu"
	local right_name = "right_menu"
	if menu_panel[panel_name] ~= nil and menu_panel[panel_name].valid then
		return menu_panel[panel_name][left_name], menu_panel[panel_name][right_name]
	end
	local panel_frame = GuiFrameH(panel_name):style("helmod_deep_frame")
	if one_line == false then
		panel_frame = GuiFrameV(panel_name):style("helmod_deep_frame")
	end
	local panel = GuiElement.add(menu_panel, panel_frame)
	panel.style.horizontally_stretchable = true
	if one_line == true then
		panel.style.height = 38
	else
		panel.style.height = 70
	end
	

	local left_panel = GuiElement.add(panel, GuiFlowH(left_name))
	left_panel.style.horizontal_spacing = 10

	local right_panel = GuiElement.add(panel, GuiFlowH(right_name))
	right_panel.style.horizontal_spacing = 10
	right_panel.style.horizontally_stretchable = true
	if one_line == true then
		right_panel.style.horizontal_align = "right"
	else
		right_panel.style.top_margin = 2
	end
	return left_panel, right_panel
	
end

-------------------------------------------------------------------------------
---Update
---@param event LuaEvent
function ProductionPanel:onUpdate(event)
	local removal = ChildRemoval.decode(event)
	local model, block = self:getParameterObjects()
	local _, content = self:getPanel()
	local displayed = block or model.block_root
	local sameBlock = false
	if displayed then
		---@type ProductionView
		local view = {model_id=model.id, block_id=displayed.id}
		sameBlock = ProductionScroll.sameBlock(content.tags, view)
		content.tags = view
	end
	if sameBlock then
		local menu = self:getDataPanel()
		menu.clear()
		self:getNavigatorPanel().clear()
	else
		content.clear()
	end
	if not event.changed_rows then self:onEventAutoCancel(event, removal) end

	self:updateIndexPanel(model)
	local width, _, scale = User.getMainSizes()
	self:getFramePanel("result", nil, "horizontal").style.natural_width = width / scale - 25

	self:updateSubMenuPanel(model, block)

	self:updateData(not sameBlock, sameBlock and event and event.changed_rows or nil)
end

-------------------------------------------------------------------------------
---Update index panel
---@param model table
function ProductionPanel:updateIndexPanel(model)
	local sorter = function(t, a, b) return t[b]["index"] > t[a]["index"] end
	local models_by_owner = Model.getModelsByOwner()
	---index panel
	local index_panel = self:getFrameDeepPanel("model_index")
	index_panel.style.padding = 2
	local scroll_table = index_panel.scroll_table or GuiElement.add(index_panel, GuiScroll("scroll_table"))
	scroll_table.clear()
	local top_lines = User.getPreferenceSetting("ui_production_lines_menu")
	if top_lines > 0 then
		scroll_table.style.maximal_height = top_lines * 40
	else
		scroll_table.style = GuiScroll("scroll_table").options.style
	end
	local table_index = GuiElement.add(scroll_table, GuiTable("table_index"):column(GuiElement.getIndexColumnNumber()):style("helmod_table_list"))
	local button = GuiElement.add(table_index, GuiButton(self.classname, "new-model"):sprite("menu", defines.sprites.add_table.black, defines.sprites.add_table.black):style(defines.styles.button.menu_actived_green):tooltip({"helmod_button.add-production-line" }))
	button.style.width = 36
	button.style.height = 36

	if table.size(models_by_owner) > 0 then
		local i = 0
		for _, models in pairs(models_by_owner) do
			table.reindex_list(models)
			for _, imodel in spairs(models, sorter) do
				i = i + 1
                local button = nil
				-- sprite definition
				local icons = GuiHelper.getModelIcons(imodel)

				local button_style = defines.styles.button.select_icon
				local button_sprite_style = nil
				if imodel.id == model.id then
					button_style = "helmod_button_actived_icon_yellow"
					button_sprite_style = "helmod_button_actived_icon_yellow"
				end

				if icons.primary ~= nil and icons.primary.type ~= nil then
					local tooltip = GuiTooltipModel("tooltip.info-model"):element(imodel)
					button = GuiElement.add(table_index, GuiButtonSelectSprite(self.classname, "change-model", imodel.id):sprite_with_quality(icons.primary.type, icons.primary.name, icons.primary.quality):style(button_sprite_style):tooltip(tooltip))
					GuiElement.infoRecipe(button, icons.first_child)
				else
					button = GuiElement.add(table_index, GuiButton(self.classname, "change-model", imodel.id):sprite("menu", defines.sprites.status_help.white, defines.sprites.status_help.black):style(button_style))
				end
				if icons.secondary ~= nil then
					GuiElement.maskSecondaryIcon(button, icons.secondary.type, icons.secondary.name, icons.secondary.quality)
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
---Update menu panel
---@param model ModelData
---@param block BlockData
function ProductionPanel:updateSubMenuPanel(model, block)
	self:updateSubMenuLeftPanel(model, block)
	self:updateSubMenuRightPanel(model, block)
end

-------------------------------------------------------------------------------
---Update menu panel
---@param model ModelData
---@param block BlockData
function ProductionPanel:updateSubMenuLeftPanel(model, block)
	if model == nil or block == nil then return end
	---action panel
	local left_panel, right_panel = self:getSubMenuPanel()
	left_panel.clear()

	local button_spacing = 2

	---add recipe
	local group_selector = GuiElement.add(left_panel, GuiFlowH("group_selector"))
	group_selector.style.horizontal_spacing = button_spacing
	local block_id = block.id
	GuiElement.add(group_selector, GuiButton("HMRecipeSelector", "OPEN", model.id, block_id):sprite("menu", defines.sprites.script.black, defines.sprites.script.black):style("helmod_button_menu_actived_green"):tooltip({"helmod_result-panel.add-button-recipe" }))
	if next(Orbit.machines()) ~= nil then
		GuiElement.add(group_selector, GuiButton("HMOrbitSelector", "OPEN", model.id, block_id):sprite("menu", defines.sprites.rocket.blue):style("helmod_button_menu_actived_green"):tooltip({"helmod_orbit.add"}))
	end
	GuiElement.add(group_selector, GuiButton("HMTechnologySelector", "OPEN", model.id, block_id):sprite("menu", defines.sprites.education.black, defines.sprites.education.black):style("helmod_button_menu_actived_green"):tooltip({"helmod_result-panel.add-button-technology" }))
	GuiElement.add(group_selector, GuiButton("HMRecipeCustomization", "OPEN", model.id, block_id):sprite("menu", defines.sprites.create.black, defines.sprites.create.black):style("helmod_button_menu_actived_green"):tooltip({"helmod_result-panel.add-button-customized-recipe" }))

	--GuiElement.add(group_selector, GuiButton("HMArrangeModels", "OPEN", model.id, block_id):sprite("menu", defines.sprites.education.black, defines.sprites.education.black):style("helmod_button_menu_actived_green"):tooltip({"helmod_result-panel.add-button-technology" }))

	---delete button
	local group_delete = GuiElement.add(left_panel, GuiFlowH("group_delete"))
	local block_remove_confirm = User.getParameter("block_remove_confirm")
	if block.id == block_remove_confirm then
		local confirm = GuiButton(self.classname, BlockRemoval.buttonArgs{
		    action="block-remove-confirmed", model_id=model.id, block_id=block_id
		})
		GuiElement.add(group_delete, confirm:sprite("menu", defines.sprites.checkmark.black, defines.sprites.checkmark.black):style("helmod_button_menu_sm_actived_green"):tooltip({ "tooltip.remove-block-confirm" }))
        local cancel = GuiButton(self.classname, BlockRemoval.buttonArgs{
            action="block-remove-canceled", model_id=model.id, block_id=block_id
        })
        GuiElement.add(group_delete, cancel:sprite("menu", defines.sprites.close.black, defines.sprites.close.black):style("helmod_button_menu_sm_actived_red"):tooltip({ "tooltip.remove-block-cancel" }))
	else
		local remove = GuiButton(self.classname, BlockRemoval.buttonArgs{
		    action="block-remove", model_id=model.id, block_id=block_id
		})
		local delete_button = GuiElement.add(group_delete, remove:sprite("menu", defines.sprites.close.black, defines.sprites.close.black):style("helmod_button_menu_actived_red"):tooltip({"helmod_result-panel.remove-button-production-block" }))
		if not (User.isDeleter(model)) then
			delete_button.enabled = false
		end
	end

	---Model Debug
	if User.getModGlobalSetting("debug_solver") == true then
		local group_debug = GuiElement.add(left_panel, GuiFlowH("group_debug"))
		group_debug.style.horizontal_spacing = button_spacing
		GuiElement.add(group_debug, GuiButton("HMModelDebug", "OPEN", model.id, block_id):sprite("menu", defines.sprites.run_test.black, defines.sprites.run_test.black):style("helmod_button_menu"):tooltip("Open Debug"))
		local default_solver = User.getParameter("solver_selected") or defines.constant.solvers.default
		local items = {}
		for _, value in pairs(defines.constant.solvers) do
			table.insert(items, value)
		end
		local selector = GuiElement.add(group_debug, GuiDropDown(self.classname, "solver_switch"):items(items, default_solver))
		selector.style.font = "helmod_font_default"
		selector.style.height = 32
		selector.style.width = 64
	end

	---group tool
	local group_tool = GuiElement.add(left_panel, GuiFlowH("group_tool"))
	group_tool.style.horizontal_spacing = button_spacing
	GuiElement.add(group_tool, GuiButton("HMSummaryPanel", "OPEN", model.id, block_id):sprite("menu", defines.sprites.list_view.black, defines.sprites.list_view.black):style("helmod_button_menu"):tooltip({"helmod_result-panel.tab-button-summary" }))
	if block ~= nil then
		---unlinked button
		local unlinked = Model.isUnlinkedBlock(block)
		local toggle = GuiButton(self.classname, TreeAction.linkButtonArgs{action=TreeAction.name.toggleLink, model_id=model.id, block_id=block.id})
		if unlinked or block.index == 0 then
			GuiElement.add(group_tool, toggle:sprite("menu", defines.sprites.unplugged.black, defines.sprites.unplugged.black):style("helmod_button_menu"):tooltip({ "tooltip.unlink-element" }))
		else
			GuiElement.add(group_tool, toggle:sprite("menu", defines.sprites.plugged.white, defines.sprites.plugged.black):style("helmod_button_menu_selected"):tooltip({ "tooltip.unlink-element" }))
		end

		GuiElement.add(group_tool, GuiButton("HMPinPanel", "OPEN", model.id, block_id):sprite("menu", defines.sprites.push_pin.black, defines.sprites.push_pin.black):style("helmod_button_menu"):tooltip({"helmod_result-panel.tab-button-pin" }))

		local display_count_deep = User.getParameter(BlockToolbar.setting.deep)
		local deepButton = GuiButton(self.classname, BlockToolbar.buttonArgs{action=BlockToolbar.action.deep, model_id=model.id, block_id=block_id})
		if display_count_deep then
			GuiElement.add(group_tool, deepButton:sprite(defines.sprite_type.menu, defines.sprites.three_rows.white, defines.sprites.three_rows.black):style(defines.styles.button.menu_selected):tooltip({ BlockToolbar.tooltip.deep }))
		else
			GuiElement.add(group_tool, deepButton:sprite(defines.sprite_type.menu, defines.sprites.two_rows.black, defines.sprites.two_rows.black):style(defines.styles.button.menu):tooltip({ BlockToolbar.tooltip.deep }))
		end

		---by limit
		local limitButton = GuiButton(self.classname, BlockToolbar.buttonArgs{action=BlockToolbar.action.limit, model_id=model.id, block_id=block_id})
		if block.by_limit == true then
			GuiElement.add(group_tool, limitButton:sprite(defines.sprite_type.menu, defines.sprites.gauge_round.white, defines.sprites.gauge_round.black):style(defines.styles.button.menu_selected):tooltip({ BlockToolbar.tooltip.limit }))
		else
			GuiElement.add(group_tool, limitButton:sprite(defines.sprite_type.menu, defines.sprites.gauge_round.black, defines.sprites.gauge_round.black):style(defines.styles.button.menu):tooltip({ BlockToolbar.tooltip.limit }))
		end

		---by product
		local inputButton = GuiButton(self.classname, BlockMode.buttonArgs{action=BlockMode.action.input, model_id=model.id, block_id=block_id})
		if block.by_product == false then
			GuiElement.add(group_tool, inputButton:sprite(defines.sprite_type.menu, defines.sprites.graph_bottom_to_top.white, defines.sprites.graph_bottom_to_top.black):style(defines.styles.button.menu_selected):tooltip({ BlockMode.label.product }))
		else
			GuiElement.add(group_tool, inputButton:sprite(defines.sprite_type.menu, defines.sprites.graph_top_to_bottom.black, defines.sprites.graph_top_to_bottom.black):style(defines.styles.button.menu):tooltip({ BlockMode.label.ingredient }))
		end

		---consumer
		local consumerButton = GuiButton(self.classname, BlockMode.buttonArgs{action=BlockMode.action.consumer, model_id=model.id, block_id=block_id})
		if block.consumer == true then
			GuiElement.add(group_tool, consumerButton:sprite(defines.sprite_type.menu, defines.sprites.cookie_cutter.white, defines.sprites.cookie_cutter.black):style(defines.styles.button.menu_selected):tooltip({ BlockMode.label.producer }))
		else
			GuiElement.add(group_tool, consumerButton:sprite(defines.sprite_type.menu, defines.sprites.cookie_cutter.black, defines.sprites.cookie_cutter.black):style(defines.styles.button.menu):tooltip({ BlockMode.label.consumer }))
		end

		-- reset production %
		GuiElement.add(group_tool, GuiButton(self.classname, BlockToolbar.buttonArgs{action=BlockToolbar.action.reset, model_id=model.id, block_id=block_id}):sprite(defines.sprite_type.menu, defines.sprites.reset.black, defines.sprites.reset.black):style(defines.styles.button.menu):tooltip({ BlockToolbar.tooltip.reset }))

		---computing
		local block_compunting = GuiElement.add(group_tool, GuiFlowH("block-computing"))
		block_compunting.style.horizontal_spacing = 10
		local default_compunting = ""
		local items = {}
		table.insert(items, { "helmod_label.compute-by-element" })
		table.insert(items, { "helmod_label.compute-by-factory" })
		table.insert(items, { "helmod_label.matrix-solver" })
		if block.solver == true then
			default_compunting = items[3]
		elseif block.by_factory == true then
			default_compunting = items[2]
		else
			default_compunting = items[1]
		end

		local selector = GuiElement.add(block_compunting, GuiDropDown(self.classname, "change-computing", model.id, block.id):items(items, default_compunting))
		selector.style.font = "helmod_font_default"
		selector.style.height = 32
	end
end

-------------------------------------------------------------------------------
---Update menu panel
---@param model table
---@param block table
function ProductionPanel:updateSubMenuRightPanel(model, block)
	if model == nil then return end
	---action panel
	local left_panel, right_panel = self:getSubMenuPanel()
	right_panel.clear()

	local button_spacing = 2
	local block_id = "new"
	if block ~= nil then block_id = block.id end

	---space locations
	local hm_locations = Player.getHMLocations()
	if #hm_locations > 1 then
		local group_locations = GuiElement.add(right_panel, GuiFlowH("group_locations"))
		local current_location = model.location or {}
		local locations = {}
		local default_surface = nil
		for _, hm_location in pairs(hm_locations) do
			local space_location = GuiTooltipLocation(""):element(hm_location)
			local item_location = space_location:create()
			if hm_location.key == current_location.key then 
				default_surface = item_location
			end
			table.insert(locations, item_location)
		end
		local locationSelector = GuiElement.add(group_locations, GuiDropDown(self.classname, BlockToolbar.panelAction{action=BlockToolbar.action.location}):items(locations, default_surface):tooltip(default_surface))
		locationSelector.style.font = "helmod_font_default"
		locationSelector.style.height = 32
		locationSelector.style.width = 64
	end
	---logistics
	local display_logistic_row = User.getParameter(BlockToolbar.setting.logistics)
	if display_logistic_row == true then
		local logistic_row_item = User.getParameter(BlockToolbar.setting.item) or "belt"
		local logistic2 = GuiElement.add(right_panel, GuiFlowH("logistic2"))
		logistic2.style.horizontal_spacing = button_spacing
		
		local default_logistic_item = nil
		local items = {}
		local tooltip_item = nil
		for _, type in pairs(defines.constant.logistic_list_for_item) do
			local item_logistic = Player.getDefaultItemLogistic(type)
			local item = string.format("[%s=%s,quality=%s]", item_logistic.type, item_logistic.name, item_logistic.quality)
			if logistic_row_item == type then
				default_logistic_item = item
				tooltip_item = EntityPrototype(item_logistic):getLocalisedName()
			end
			table.insert(items, item)
		end
		local selector_logistic_item = GuiElement.add(logistic2, GuiDropDown(self.classname, BlockToolbar.panelAction{action=BlockToolbar.action.item}):items(items, default_logistic_item):tooltip(tooltip_item))
		selector_logistic_item.style.font = "helmod_font_default"
		selector_logistic_item.style.height = 32
		selector_logistic_item.style.width = 64

		local logistic_row_fluid = User.getParameter(BlockToolbar.setting.fluid) or "pipe"
		local logistic3 = GuiElement.add(right_panel, GuiFlowH("logistic3"))
		logistic3.style.horizontal_spacing = button_spacing

		local default_logistic_fluid = nil
		local fluids = {}
		local tooltip_fluid = nil
		for _, type in pairs(defines.constant.logistic_list_for_fluid) do
			local fluid_logistic = Player.getDefaultFluidLogistic(type)
			local fluid = string.format("[%s=%s,quality=%s]", fluid_logistic.type, fluid_logistic.name, fluid_logistic.quality)
			if logistic_row_fluid == type then 
				default_logistic_fluid = fluid
				tooltip_fluid = EntityPrototype(fluid_logistic):getLocalisedName()
			end
			table.insert(fluids, fluid)
		end
		local selector_logistic_fluid = GuiElement.add(logistic3, GuiDropDown(self.classname, BlockToolbar.panelAction{action=BlockToolbar.action.fluid}):items(fluids, default_logistic_fluid):tooltip(tooltip_fluid))
		selector_logistic_fluid.style.font = "helmod_font_default"
		selector_logistic_fluid.style.height = 32
		selector_logistic_fluid.style.width = 64
	end

	local group_pref = GuiElement.add(right_panel, GuiFlowH("group_pref"))
	group_pref.style.horizontal_spacing = button_spacing
	if display_logistic_row == true then
		GuiElement.add(group_pref, GuiButton(self.classname, BlockToolbar.panelAction{action=BlockToolbar.action.logistics}):sprite(defines.sprite_type.menu, defines.sprites.transport.white, defines.sprites.transport.black):style(defines.styles.button.menu_selected):tooltip({ BlockToolbar.tooltip.logistics }))
	else
		GuiElement.add(group_pref, GuiButton(self.classname, BlockToolbar.panelAction{action=BlockToolbar.action.logistics}):sprite(defines.sprite_type.menu, defines.sprites.transport.black, defines.sprites.transport.black):style(defines.styles.button.menu):tooltip({ BlockToolbar.tooltip.logistics }))
	end
	GuiElement.add(group_pref, GuiButton("HMPreferenceEdition", "OPEN", model.id, block_id):sprite("menu", defines.sprites.process.black, defines.sprites.process.black):style("helmod_button_menu"):tooltip({ "helmod_button.preferences" }))

	local group_models = GuiElement.add(right_panel, GuiFlowH("group_models"))
	group_models.style.horizontal_spacing = button_spacing
	GuiElement.add(group_models, GuiButton("HMBlockEdition", "OPEN", model.id, "none", "model"):sprite("menu", defines.sprites.edit_document.black, defines.sprites.edit_document.black):style("helmod_button_menu"):tooltip({ "helmod_panel.model-edition" }))
	GuiElement.add(group_models, GuiButton("HMBlockEdition", "OPEN", model.id, block_id, "block"):sprite("menu", defines.sprites.edit_subdocument.black, defines.sprites.edit_document.black):style("helmod_button_menu"):tooltip({ "helmod_block_edition_panel.pane-title" }))
	GuiElement.add(group_models, GuiButton("HMParametersEdition", "OPEN", model.id, block_id):sprite("menu", defines.sprites.parameter.black, defines.sprites.parameter.black):style("helmod_button_menu"):tooltip({"helmod_parameters_edition_panel.title" }))
	local button_model_up = GuiElement.add(group_models, GuiButton(self.classname, "model-index-up", model.id, block_id):sprite("menu", defines.sprites.arrow_left.black, defines.sprites.arrow_left.black):style("helmod_button_menu"):tooltip({ "helmod_panel.model-index-up" }))
	button_model_up.enabled = model.owner == Player.native().name
	local button_model_down = GuiElement.add(group_models, GuiButton(self.classname, "model-index-down", model.id, block_id):sprite("menu", defines.sprites.arrow_right.black, defines.sprites.arrow_right.black):style("helmod_button_menu"):tooltip({"helmod_panel.model-index-down" }))
	button_model_down.enabled = model.owner == Player.native().name

	local group_action = GuiElement.add(right_panel, GuiFlowH("group_action"))
	group_action.style.horizontal_spacing = button_spacing
	---copy past
	GuiElement.add(group_action, GuiButton(self.classname, "copy-block", model.id, block_id):sprite("menu", defines.sprites.copy.black, defines.sprites.copy.black):style("helmod_button_menu"):tooltip({ "helmod_button.copy" }))
	GuiElement.add(group_action, GuiButton(self.classname, "past-block", model.id, block_id):sprite("menu", defines.sprites.paste.black, defines.sprites.paste.black):style("helmod_button_menu"):tooltip({ "helmod_button.past" }))
	---download
	if self.classname == "HMProductionPanel" then
		GuiElement.add(group_action, GuiButton("HMDownload", "OPEN", model.id, "download"):sprite("menu", defines.sprites.download_document.black, defines.sprites.download_document.black):style("helmod_button_menu"):tooltip({"helmod_result-panel.download-button-production-line" }))
		GuiElement.add(group_action, GuiButton("HMDownload", "OPEN", model.id, "upload"):sprite("menu", defines.sprites.upload_document.black, defines.sprites.upload_document.black):style("helmod_button_menu"):tooltip({"helmod_result-panel.upload-button-production-line" }))
	end
	---refresh control
	GuiElement.add(group_action, GuiButton(self.classname, "refresh-model", model.id):sprite("menu", defines.sprites.refresh.black, defines.sprites.refresh.black):style("helmod_button_menu"):tooltip({ "helmod_result-panel.refresh-button" }))

	local items = {}
	local default_time = 1
	for index, base_time in pairs(defines.constant.base_times) do
		table.insert(items, base_time.tooltip)
		if model.time == base_time.value then
			default_time = base_time.tooltip
		end
	end

	local group_time = GuiElement.add(right_panel, GuiFlowH("group_time"))
	GuiElement.add(group_time, GuiLabel("label_time"):caption({ "helmod_data-panel.base-time", "" }):style("helmod_label_title_frame"))

	GuiElement.add(group_time, GuiDropDown(self.classname, "change-time", model.id):items(items, default_time))
end

-------------------------------------------------------------------------------
---@param model ModelData
function ProductionPanel:updatePending(model)
	local selected = self:getParameterObjects()
	if selected.id ~= model.id then return end
	local info = self:getInfoPanel2()
	local _, _, scroll = self:getDataPanel()
	local list = scroll[resultTableName]
	if list then list.enabled = not SheetPlanner.pendingStructure(model.id) and not SheetPlanner.failure(model.id) end
	local label, indicator = infoHeading(info.parent)
	label.caption = {"", self:getButtonCaption(), " [img=info]"}
	indicator.visible = User.getModGlobalSetting(SheetPlanner.setting)
	if SheetPlanner.pending(model.id) then
		indicator.sprite = statusSprites.pending
		indicator.tooltip = {"helmod_common.solver-calculating"}
	elseif SheetPlanner.failure(model.id) then
		indicator.sprite = statusSprites.failed
		indicator.tooltip = {"helmod_common.solver-failed"}
	else
		indicator.sprite = statusSprites.ready
		indicator.tooltip = {"helmod_common.solver-ready"}
	end
end

---@param model ModelData
---@param block BlockData
function ProductionPanel:updateInfoBlock(model, block)
	local info_scroll, output_scroll, input_scroll = self:getInfoPanel2()
	local label = infoHeading(info_scroll.parent)
	self:updatePending(model)
	label.tooltip = GuiTooltipModel("tooltip.info-model"):element(model):create()
	info_scroll.clear()
	---info panel

	---production block result
	if block ~= nil and table.size(block.children) > 0 then
		---block informations
		local block_table = GuiElement.add(info_scroll, GuiTable("output-table"):column(5))
		block_table.style.horizontally_stretchable = false
		block_table.vertical_centering = false
		block_table.style.horizontal_spacing = 10

		local default_color = User.getThumbnailColor(defines.thumbnail_color.names.default)
		GuiElement.add(block_table, GuiCellBlockInfo("block-count"):element(block):tooltip("tooltip.info-block"):color(GuiElement.color_button_default):color(default_color):index(1):byLimit(block.by_limit))
		GuiElement.add(block_table, GuiCellEnergy("block-power"):element(block):tooltip("tooltip.info-block"):color(GuiElement.color_button_default):color(default_color):index(2):byLimit(block.by_limit))
		if User.getPreferenceSetting("display_pollution") then
			GuiElement.add(block_table, GuiCellPollution("block-pollution"):element(block):tooltip("tooltip.info-block"):color(GuiElement.color_button_default):color(default_color):index(3):byLimit(block.by_limit))
		end
		if User.getPreferenceSetting("display_building") then
			GuiElement.add(block_table, GuiCellBuilding(self.classname, "building-constant", model.id, block_id):element(block):tooltip("tooltip.smart-pipette"):color(GuiElement.color_button_default):color(default_color):index(4):byLimit(block.by_limit))
		end
	end
end

-------------------------------------------------------------------------------
---Toggle an input in the combinator selection set (selection mode).
---@param block table
---@param type string
---@param item table {type, name, quality}
function ProductionPanel:toggleCombinatorSelection(block, type, item)
	if item == nil or item.name == nil then return end
	local selection = User.getParameter("combinator_selection") or {}
	local key = Product(item):getTableKey()
	if selection[key] ~= nil then
		selection[key] = nil
	else
		local elements = nil
		if type == "products" then
			elements = block.products
		else
			elements = block.ingredients
		end
		for index, lua_product in spairs(elements, User.getProductSorter()) do
			if key == Product(lua_product):getTableKey() then
				local product = ProductionPanel.get_element(block, lua_product)
				selection[key] = product
			end
		end
	end
	User.setParameter("combinator_selection", selection)
end

-------------------------------------------------------------------------------
---Update header
---@param model table
---@param block table
function ProductionPanel:updateInputBlock(model, block)
	local combinator_select_mode = User.getParameter("combinator_select_mode") == "ingredients"
	---data
	local block_by_product = not (block ~= nil and block.by_product == false)

	local left_label, left_tool, left_scroll = self:getLeftInfoPanel2()
	local right_label, right_tool, right_scroll = self:getRightInfoPanel2()

	local input_label = right_label
	local input_tool = right_tool
	local input_scroll = right_scroll
	if not (block_by_product) then
		input_label = left_label
		input_scroll = left_scroll
		input_tool = left_tool
	end

	input_tool.clear()
	local all_visible = User.getParameter(BlockHeader.setting.ingredients)
	local filter = GuiButton(self.classname, BlockHeader.buttonArgs{action=BlockHeader.action.ingredients, model_id=model.id, block_id=block.id})
	if all_visible == true then
		GuiElement.add(input_tool, filter:sprite(defines.sprite_type.menu, defines.sprites.filter.white, defines.sprites.filter.black):style(defines.styles.button.menu_sm_selected):tooltip({ BlockHeader.tooltip.filter }))
	else
		GuiElement.add(input_tool, filter:sprite(defines.sprite_type.menu, defines.sprites.filter.black, defines.sprites.filter.black):style(defines.styles.button.menu_sm):tooltip({ BlockHeader.tooltip.filter }))
	end
	if block_by_product == false then
		GuiElement.add(input_tool, GuiButton(self.classname, BlockHeader.buttonArgs{action=BlockHeader.action.clear, model_id=model.id, block_id=block.id}):sprite(defines.sprite_type.menu, defines.sprites.eraser.black, defines.sprites.eraser.black):style(defines.styles.button.menu_sm):tooltip({ BlockHeader.tooltip.clear }))
	end

	---generate a constant combinator from the input list (item/fluid request lists)
	local solid_items = ProductionPanel.get_elements(block, "ingredients", "item")
	local solid_pipette_tooltip = GuiTooltipBlockPipette("tooltip.smart-pipette"):element(solid_items):append_information({ "helmod_button.combinator-solids" })
	GuiElement.add(input_tool, GuiButton(self.classname, "block-combinator-solids", model.id, block.id, "ingredients"):sprite("menu", defines.sprites.item.black, defines.sprites.item.black):style("helmod_button_menu_sm"):tooltip(solid_pipette_tooltip))
	local fluid_items = ProductionPanel.get_elements(block, "ingredients", "fluid")
	local fluid_pipette_tooltip = GuiTooltipBlockPipette("tooltip.smart-pipette"):element(fluid_items):append_information({ "helmod_button.combinator-fluids" })
	GuiElement.add(input_tool, GuiButton(self.classname, "block-combinator-fluids", model.id, block.id, "ingredients"):sprite("menu", defines.sprites.fluid.black, defines.sprites.fluid.black):style("helmod_button_menu_sm"):tooltip(fluid_pipette_tooltip))
	local custom_pipette_tooltip = GuiTooltipBlockPipette("tooltip.smart-pipette"):append_information({ "helmod_button.combinator-select" })
	if combinator_select_mode then
		GuiElement.add(input_tool, GuiButton(self.classname, "block-combinator-select", model.id, block.id, "ingredients"):sprite("menu", defines.sprites.pipette.white, defines.sprites.pipette.black):style("helmod_button_menu_sm_selected"):tooltip(custom_pipette_tooltip))
	else
		GuiElement.add(input_tool, GuiButton(self.classname, "block-combinator-select", model.id, block.id, "ingredients"):sprite("menu", defines.sprites.pipette.black, defines.sprites.pipette.black):style("helmod_button_menu_sm"):tooltip(custom_pipette_tooltip))
	end

	---input panel
	input_label.caption = { "helmod_common.input" }
	input_scroll.clear()

	local display_hidden_products_mode = User.getPreferenceSetting("display_hidden_products_mode")
	local display_hidden_products = User.getPreferenceSetting("display_hidden_products")
	---production block result
	if block ~= nil and table.size(block.children) > 0 then
		---input panel, 50 is the real width of icons
		local column_count, columns_width = GuiElement.getElementColumnNumber(50)
		input_tool.style.width = columns_width
		local input_table = GuiElement.add(input_scroll, GuiTable("input-table"):column(column_count):style("helmod_table_element"))
		if block.ingredients ~= nil then
			local all_ingredients = {}
			local hidden_ingredients = {}
			
			local show_hidden_input_products = User.getParameter("show_hidden_input_products")
			local canEditSupplies = MatrixSupplies.available(block) and User.isWriter(model)
			local visible = GuiElement.visibleIngredients(block.ingredients)
			local skip_hidden_products = table.size(visible) < 2*column_count

			local max_count = 0
			for index, lua_ingredient in spairs(visible, User.getProductSorter()) do
				local supplyEligible = not combinator_select_mode and MatrixSupplies.editable(block, index)
				local supplied = supplyEligible and MatrixSupplies.selected(block, index)
				if supplied or all_visible == true or ((lua_ingredient.state or 0) == 1 and not (block_by_product)) or (lua_ingredient.amount or 0) > ModelCompute.waste_value then
					local ingredient = Product(lua_ingredient):clone()
					ingredient.key = Product(lua_ingredient):getTableKey()
					ingredient.time = model.time
					ingredient.count = lua_ingredient.amount
					ingredient.count_limit = lua_ingredient.amount * (block.count_limit or 0)
					ingredient.count_deep = lua_ingredient.amount * (block.count_deep or 0)

					ingredient.has_input = lua_ingredient.input ~= nil
					ingredient.button_action = ConstraintView.action.ingredient
					ingredient.button_tooltip = "tooltip.ingredient"
					ingredient.control_info = "link-intermediate"
					if block_by_product then
						ingredient.button_action = ConstraintView.action.ingredient
						ingredient.button_tooltip = "tooltip.add-recipe"
						ingredient.control_info = canEditSupplies and supplyEligible and MatrixSupply.hint or nil
						if supplied then ingredient.contraint_type = ConstraintView.kind.master end
					else
						if not (block.unlinked or true) or block.by_factory == true then
							ingredient.button_action = "product-info"
							ingredient.button_tooltip = "tooltip.info-product"
							if block.products_linked ~= nil and block.products_linked[ingredient.key] then
								ingredient.contraint_type = "linked"
							end
						else
							ingredient.button_action = ConstraintView.action.edition
							ingredient.button_tooltip = "tooltip.edit-product"
						end
					end
					if combinator_select_mode then
						ingredient.button_action = "block-combinator-pick"
					end
					---color
					ingredient.ingredient_color = User.getThumbnailColor(defines.thumbnail_color.names.ingredient_default)
					if lua_ingredient.state == 1 then
						if not (block.unlinked) or block.by_factory == true then
							ingredient.ingredient_color = User.getThumbnailColor(defines.thumbnail_color.names.ingredient_default)
						else
							ingredient.ingredient_color = User.getThumbnailColor(defines.thumbnail_color.names.ingredient_driving)
						end
					elseif lua_ingredient.state == 3 then
						ingredient.ingredient_color = User.getThumbnailColor(defines.thumbnail_color.names.ingredient_overflow)
					else
						ingredient.ingredient_color = User.getThumbnailColor(defines.thumbnail_color.names.ingredient_default)
					end

					table.insert(all_ingredients, ingredient)
					max_count = math.max(max_count, ingredient.count)
				end
			end

			---constant-combinator selection mode: expand all inputs so any can be picked
			local combinator_selection = combinator_select_mode and (User.getParameter("combinator_selection") or {}) or {}
			for index, ingredient in pairs(all_ingredients) do
				local is_visible = ingredient.count > display_hidden_products
				if display_hidden_products_mode == DisplayMode.relative then
					is_visible = ingredient.count > max_count*display_hidden_products
				end
				local combinator_selected = combinator_select_mode and combinator_selection[ingredient.key] ~= nil
				if combinator_selected then
					ingredient.ingredient_color = User.getThumbnailColor(defines.thumbnail_color.names.combinator_pick)
				end
				if ingredient.contraint_type == ConstraintView.kind.master or combinator_select_mode or skip_hidden_products == true or all_visible == true or show_hidden_input_products or display_hidden_products == 0 or is_visible then
					local input_cell = GuiCellElementM(self.classname, ingredient.button_action, model.id, block.id, ConstraintView.noTarget):element(ingredient)
					:tooltip(ingredient.button_tooltip):index(index):color(ingredient.ingredient_color):byLimit(block.by_limit)
					:contraintIcon(ingredient.contraint_type):hasInput(ingredient.has_input):controlInfo(ingredient.control_info)
					if combinator_selected then
						input_cell:mask(true)
					end
					GuiElement.add(input_table, input_cell)
				else
					table.insert(hidden_ingredients, ingredient)
				end
			end

			if #hidden_ingredients > 0 then
				local product_color = User.getThumbnailColor(defines.thumbnail_color.names.ingredient_default)
				GuiElement.add(input_table, GuiCellHiddenElementM(self.classname, "show-hidden-input-products", model.id, block.id, ConstraintView.noTarget):element(hidden_ingredients):tooltip("tooltip.add-recipe")
					:color(product_color))
			end
		end
	end
end

-------------------------------------------------------------------------------
---Update header
---@param model table
---@param block table
function ProductionPanel:updateOutputBlock(model, block)
	local combinator_select_mode = User.getParameter("combinator_select_mode") == "products"
			
	---data
	local block_by_product = not (block ~= nil and block.by_product == false)

	local left_label, left_tool, left_scroll = self:getLeftInfoPanel2()
	local right_label, right_tool, right_scroll = self:getRightInfoPanel2()

	local output_label = left_label
	local output_tool = left_tool
	local output_scroll = left_scroll
	if not (block_by_product) then
		output_label = right_label
		output_scroll = right_scroll
		output_tool = right_tool
	end

	output_tool.clear()
	local all_visible = User.getParameter(BlockHeader.setting.products)
	local filter = GuiButton(self.classname, BlockHeader.buttonArgs{action=BlockHeader.action.products, model_id=model.id, block_id=block.id})
	if all_visible == true then
		GuiElement.add(output_tool, filter:sprite(defines.sprite_type.menu, defines.sprites.filter.white, defines.sprites.filter.black):style(defines.styles.button.menu_sm_selected):tooltip({ BlockHeader.tooltip.filter }))
	else
		GuiElement.add(output_tool, filter:sprite(defines.sprite_type.menu, defines.sprites.filter.black, defines.sprites.filter.black):style(defines.styles.button.menu_sm):tooltip({ BlockHeader.tooltip.filter }))
	end
	if block_by_product ~= false then
		GuiElement.add(output_tool, GuiButton(self.classname, BlockHeader.buttonArgs{action=BlockHeader.action.clear, model_id=model.id, block_id=block.id}):sprite(defines.sprite_type.menu, defines.sprites.eraser.black, defines.sprites.eraser.black):style(defines.styles.button.menu_sm):tooltip({ BlockHeader.tooltip.clear }))
	end

	---generate a constant combinator from the input list (item/fluid request lists)
	local solid_items = ProductionPanel.get_elements(block, "products", "item")
	local solid_pipette_tooltip = GuiTooltipBlockPipette("tooltip.smart-pipette"):element(solid_items):append_information({ "helmod_button.combinator-solids" })
	GuiElement.add(output_tool, GuiButton(self.classname, "block-combinator-solids", model.id, block.id, "products"):sprite("menu", defines.sprites.item.black, defines.sprites.item.black):style("helmod_button_menu_sm"):tooltip(solid_pipette_tooltip))
	local fluid_items = ProductionPanel.get_elements(block, "products", "fluid")
	local fluid_pipette_tooltip = GuiTooltipBlockPipette("tooltip.smart-pipette"):element(fluid_items):append_information({ "helmod_button.combinator-fluids" })
	GuiElement.add(output_tool, GuiButton(self.classname, "block-combinator-fluids", model.id, block.id, "products"):sprite("menu", defines.sprites.fluid.black, defines.sprites.fluid.black):style("helmod_button_menu_sm"):tooltip(fluid_pipette_tooltip))
	local custom_pipette_tooltip = GuiTooltipBlockPipette("tooltip.smart-pipette"):append_information({ "helmod_button.combinator-select" })
	if combinator_select_mode == true then
		GuiElement.add(output_tool, GuiButton(self.classname, "block-combinator-select", model.id, block.id, "products"):sprite("menu", defines.sprites.pipette.white, defines.sprites.pipette.black):style("helmod_button_menu_sm_selected"):tooltip(custom_pipette_tooltip))
	else
		GuiElement.add(output_tool, GuiButton(self.classname, "block-combinator-select", model.id, block.id, "products"):sprite("menu", defines.sprites.pipette.black, defines.sprites.pipette.black):style("helmod_button_menu_sm"):tooltip(custom_pipette_tooltip))
	end

	---ouput panel
	output_label.caption = { "helmod_common.output" }
	output_scroll.clear()

	local display_hidden_products_mode = User.getPreferenceSetting("display_hidden_products_mode")
	local display_hidden_products = User.getPreferenceSetting("display_hidden_products")
	local scroll_width = output_scroll.width
	---production block result
	if block ~= nil and table.size(block.children) > 0 then
		---ouput panel, 50 is the real width of icons
		local column_count, columns_width = GuiElement.getElementColumnNumber(50)
		output_tool.style.width = columns_width
		local output_table = GuiElement.add(output_scroll, GuiTable("output-table"):column(column_count):style("helmod_table_element"))
		if block.products ~= nil then
			local all_products = {}
			local hidden_products = {}
			local show_hidden_output_products = User.getParameter("show_hidden_output_products")
			local skip_hidden_products = table.size(block.products) < 2*column_count
			
			local max_count = 0
			for index, lua_product in spairs(block.products, User.getProductSorter()) do
				if all_visible == true or ((lua_product.state or 0) == 1 and block_by_product) or (lua_product.amount or 0) > ModelCompute.waste_value then
					local product = Product(lua_product):clone()
					product.key = Product(lua_product):getTableKey()
					product.time = model.time
					product.count = lua_product.amount
					product.count_limit = lua_product.amount * (block.count_limit or 0)
					product.count_deep = lua_product.amount * (block.count_deep or 0)

					product.has_input = lua_product.input ~= nil
					product.button_action = ConstraintView.action.product
					product.button_tooltip = "tooltip.product"
					product.product_color = User.getThumbnailColor(defines.thumbnail_color.names.product_default)
					product.control_info = "link-intermediate"
					if not block_by_product then
						product.button_action = ConstraintView.action.product
						product.button_tooltip = "tooltip.add-recipe"
						product.control_info = nil
					elseif not (block.unlinked or true) or block.by_factory == true then
						-- TODO disable solver can't do that
						product.button_action = "product-info"
						product.button_tooltip = "tooltip.info-product"
						if block.products_linked ~= nil and block.products_linked[product.key] then
							product.contraint_type = "linked"
						end
					else
						product.button_action = ConstraintView.action.edition
						product.button_tooltip = "tooltip.edit-product"
						if block.products_linked ~= nil and block.products_linked[product.key] then
							product.contraint_type = "linked"
						end
					end
					if combinator_select_mode then
						product.button_action = "block-combinator-pick"
					end
					---color
					if lua_product.state == 1 then
						if not (block.unlinked or true) or block.by_factory == true then
							product.product_color = User.getThumbnailColor(defines.thumbnail_color.names.product_default)
						else
							product.product_color = User.getThumbnailColor(defines.thumbnail_color.names.product_driving)
						end
					elseif lua_product.state == 3 then
						product.product_color = User.getThumbnailColor(defines.thumbnail_color.names.product_overflow)
					else
						product.product_color = User.getThumbnailColor(defines.thumbnail_color.names.product_default)
					end
					table.insert(all_products, product)
					max_count = math.max(max_count, product.count)
				end
			end

			local combinator_selection = combinator_select_mode and (User.getParameter("combinator_selection") or {}) or {}
			for index, product in pairs(all_products) do
				local is_visible = product.count > display_hidden_products
				if display_hidden_products_mode == DisplayMode.relative then
					is_visible = product.count > max_count*display_hidden_products
				end
				local combinator_selected = combinator_select_mode and combinator_selection[product.key] ~= nil
				if combinator_selected then
					product.product_color = User.getThumbnailColor(defines.thumbnail_color.names.combinator_pick)
				end
				if combinator_select_mode or skip_hidden_products == true or all_visible == true or show_hidden_output_products or display_hidden_products == 0 or is_visible then
					local input_cell = GuiCellElementM(self.classname, product.button_action, model.id, block.id, ConstraintView.noTarget):element(product)
					:tooltip(product.button_tooltip):index(index):color(product.product_color):byLimit(block.by_limit):contraintIcon(product.contraint_type)
					:hasInput(product.has_input):controlInfo(product.control_info)
					if combinator_selected then
						input_cell:mask(true)
					end
					GuiElement.add(output_table, input_cell)
				else
					table.insert(hidden_products, product)
				end
			end

			if #hidden_products > 0 then
				local product_color = User.getThumbnailColor(defines.thumbnail_color.names.product_default)
				GuiElement.add(output_table, GuiCellHiddenElementM(self.classname, "show-hidden-output-products", model.id, block.id, ConstraintView.noTarget):element(hidden_products):tooltip("tooltip.add-recipe")
					:color(product_color))
			end
		end
	end
end

-------------------------------------------------------------------------------
---Update data
---@param focusBlock boolean
---@param changedRows? table<string,boolean>
function ProductionPanel:updateData(focusBlock, changedRows)
	local model, block = self:getParameterObjects()

	if model.block_root == nil then
        -- TODO this is must be in update file --
		local first_block = Model.firstChild(model.blocks)
        local element_block = first_block or { name = model.id, power = 0, pollution = 0, summary = {} }
		local block_root = Model.newBlock(model, element_block)
		block_root.power = 0
		block_root.pollution = 0
		local index = 0
		for key, block in pairs(model.blocks) do
			block.index = index
			block_root.children[block.id] = block
            block.parent_id = block_root.id
            index = index + 1
		end
		model.block_root = block_root
	end
	
	self:bluidNavigator(model, block, focusBlock)

	---col recipe
	if block == nil then
		self:updateDataBlock(model, model.block_root, changedRows)
	else
		self:updateDataBlock(model, block, changedRows)
	end
	
	-- reset show hidden products
	User.setParameter("show_hidden_recipe_products", nil)
	User.setParameter("show_hidden_recipe_ingredients", nil)
	User.setParameter("show_hidden_block_products", nil)
	User.setParameter("show_hidden_block_ingredients", nil)
	User.setParameter("show_hidden_input_products", nil)
	User.setParameter("show_hidden_output_products", nil)
end

-------------------------------------------------------------------------------
---Update data
---@param model table
---@param block table
---@param changedRows? table<string,boolean>
function ProductionPanel:updateDataBlock(model, block, changedRows)
	if block == nil then return end

	self:updateInfoBlock(model, block)

	self:updateOutputBlock(model, block)

	self:updateInputBlock(model, block)

	---data panel
	local menu_panel, header_panel, scroll_panel = self:getDataPanel()
	---production block result
	if block ~= nil and table.size(block.children) > 0 then
		---data panel
		local extra_cols = 0
		local display_hidden_column = User.getModGlobalSetting("display_hidden_column")
		if User.getPreferenceSetting("display_pollution") then
			extra_cols = extra_cols + 1
		end
		if display_hidden_column == "Index and Id" or display_hidden_column == "All" then
			extra_cols = extra_cols + 2
		end
		if display_hidden_column == "Type and Name" or display_hidden_column == "All" then
			extra_cols = extra_cols + 2
		end

		local columns = 7 + extra_cols
		local result_table = scroll_panel[resultTableName]
		if changedRows and result_table and result_table.column_count == columns
            and self:refreshChangedRows(result_table, model, block, changedRows) then
            return
        end
        if result_table and result_table.column_count == columns then
			ProductionScroll.clearRowCells(result_table, block)
		else
			scroll_panel.clear()
			result_table = GuiElement.add(scroll_panel, GuiTable(resultTableName):column(columns):style("helmod_table_result"))
		end
		result_table.vertical_centering = false
		self:addTableHeader(result_table, block)

		local sorter = defines.sorters.block.sort
		if block.by_product == false then sorter = defines.sorters.block.reverse end
		local last_element = nil
		for _, child in spairs(block.children, sorter) do
			local row_cell = nil
			local is_block = Model.isBlock(child)
			if is_block then
				row_cell = self:addTableRowBlock(result_table, model, block, child)
			else
				row_cell = self:addTableRowRecipe(result_table, model, block, child)
			end
			if User.getParameter("scroll_element") == child.id then last_element = row_cell end
		end

		if last_element ~= nil then
			scroll_panel.scroll_to_element(last_element)
		end
	else
		scroll_panel.clear()
	end
	User.setParameter("scroll_element", nil)
end

---@param list LuaGuiElement
---@param model ModelData
---@param block BlockData
---@param rows table<string,boolean>
---@return boolean
function ProductionPanel:refreshChangedRows(list, model, block, rows)
    local columns = list.column_count
    if #list.children ~= columns * (1 + table_size(block.children)) then return false end
    local sort = block.by_product == false and defines.sorters.block.reverse or defines.sorters.block.sort
    local first = columns + 1
    for _, child in spairs(block.children, sort) do
        local action = list[GuiTable("action", child.id):getName()]
        if not action or action.get_index_in_parent() ~= first then return false end
        if rows[child.id] then
            ProductionScroll.replaceRow(list, first, function()
                if Model.isBlock(child) then
                    self:addTableRowBlock(list, model, block, child)
                else
                    self:addTableRowRecipe(list, model, block, child)
                end
            end)
        end
        first = first + columns
    end
    return true
end

-------------------------------------------------------------------------------
---Build Navigator
---@param model table
---@param current_block table
---@param focusBlock boolean
function ProductionPanel:bluidNavigator(model, current_block, focusBlock)
	local scroll_panel = self:getNavigatorPanel()

	---bluid tree
	if model.blocks ~= nil then
		self:bluidRootLeaf(scroll_panel, model, current_block, 0)
		Model.setExpandBlock(model.block_root, true)
		local root_node = self:bluidTreeNodes(model.block_root)
		local tree_view = GuiElement.add(scroll_panel, GuiTreeView():source(root_node):class_decorator(self)
			:item_decorator(ProductionPanel.item_decorator):item_changed(ProductionPanel.on_item_changed))
		if focusBlock and root_node.scroll_to_element ~= nil then
			scroll_panel.scroll_to_element(root_node.scroll_to_element)
		end
	end
end

-------------------------------------------------------------------------------
---On item changed
---@param tree_node table
function ProductionPanel.on_item_changed(self, tree_node)
	local model, current_block, recipe = self:getParameterObjects()
	local block_node = model.blocks[tree_node.id]
	if block_node ~= nil then
		Model.setExpandBlock(block_node, tree_node.expanded)
	end
end

-------------------------------------------------------------------------------
---Item decorator
---@param parent LuaGuiElement --container for element
---@param root_node table
---@param tree_node table
function ProductionPanel.item_decorator(self, parent, root_node, tree_node)
	local model, current_block, recipe = self:getParameterObjects()
	local block_node = model.blocks[tree_node.id]
	if block_node ~= nil then
		local block_color = User.getThumbnailColor(defines.thumbnail_color.names.block_default)
		local background = GuiElement.add(parent, GuiFrame("block", block_node.id):style("helmod_frame_element_w30", "gray", 1))
		background.style.padding = 1
		background.style.horizontally_stretchable = false

		local cell_tree = GuiElement.add(background, GuiTable("block", block_node.id):column(1):style("helmod_table_list"))
		if current_block ~= nil and current_block.id == block_node.id then
			root_node.scroll_to_element = cell_tree
			block_color = User.getThumbnailColor(defines.thumbnail_color.names.block_selected)
		end
		if block_node.name == nil then
			local cell_block = GuiElement.add(cell_tree, GuiButton("HMProductionPanel", "HMProductionPanel", model.id, block_node.id):sprite("menu", defines.sprites.hangar.black, defines.sprites.hangar.black):style("helmod_button_menu"):tooltip("tooltip.edit-block"))
		else
			local cell_block = GuiElement.add(cell_tree, GuiCellBlockM("HMProductionPanel", "change-block", model.id, block_node.id):element(block_node):withTitle():tooltip("tooltip.edit-block"):color(block_color))
		end
	end
end

-------------------------------------------------------------------------------
---Build Navigator
---@param block BlockData
function ProductionPanel:bluidTreeNodes(block)
	if block == nil then
		return nil
	end
	local is_expanded = Model.isExpandBlock(block)
	local tree_node = {}
	tree_node.id = block.id
	tree_node.infos = block.infos
	tree_node.name = block.name
	tree_node.type = block.type
	tree_node.expanded = is_expanded
	
	if block.children ~= nil then
		tree_node.children = {}
		local sorter = defines.sorters.block.sort
		for _, child in spairs(block.children, sorter) do
			local is_block = Model.isBlock(child)
			if is_block then
				local child_node = self:bluidTreeNodes(child)
				table.insert(tree_node.children, child_node)
			end
		end
	end
	return tree_node
end

-------------------------------------------------------------------------------
---Build Tree
---@param tree_panel LuaGuiElement
---@param model ModelData
---@param current_block BlockData
---@param level number
function ProductionPanel:bluidRootLeaf(tree_panel, model, current_block, level)
	if model ~= nil then
		local block_color = User.getThumbnailColor(defines.thumbnail_color.names.block_default)
		local background = GuiElement.add(tree_panel, GuiFrame("model", model.id, model.block_root.id):style("helmod_frame_element_w50", "gray", 1))
		background.style.padding = 1
		background.style.horizontally_stretchable = false
		local cell_tree = GuiElement.add(background, GuiTable("model", model.id, model.block_root.id):column(1):style("helmod_table_list"))
		if current_block == nil or current_block ~= nil and current_block.id == model.block_root.id then
			--last_element = cell_tree
			block_color = User.getThumbnailColor(defines.thumbnail_color.names.block_selected)
		end
		if model ~= nil and model.block_root.type ~= nil then
			local cell_block = GuiElement.add(cell_tree, GuiCellModel(self.classname, "change-block", model.id, model.block_root.id):element(model):withTitle():tooltip("tooltip.info-model"):color(block_color))
			cell_block.style.left_padding = 10 * level
		else
			local cell_block = GuiElement.add(cell_tree, GuiButton(self.classname, "change-block", model.id, model.block_root.id):sprite("menu", defines.sprites.status_help.black, defines.sprites.status_help.black):style("helmod_button_menu_flat"))
			cell_block.style.left_padding = 10 * level
		end
	end
end

-------------------------------------------------------------------------------
---Add table header
---@param itable LuaGuiElement
---@param block table
function ProductionPanel:addTableHeader(itable, block)
	self:addCellHeader(itable, "action", { "helmod_result-panel.col-header-action" })
	---optionnal columns
	local display_hidden_column = User.getModGlobalSetting("display_hidden_column")
	if display_hidden_column == "Index and Id" or display_hidden_column == "All" then
		self:addCellHeader(itable, "index", { "helmod_result-panel.col-header-index" }, "index")
		self:addCellHeader(itable, "id", { "helmod_result-panel.col-header-id" }, "id")
	end
	if display_hidden_column == "Type and Name" or display_hidden_column == "All" then
		self:addCellHeader(itable, "name", { "helmod_result-panel.col-header-name" }, "name")
		self:addCellHeader(itable, "type", { "helmod_result-panel.col-header-type" }, "type")
	end
	---data columns
	self:addCellHeader(itable, "recipe", { "helmod_result-panel.col-header-recipe" }, "index")
	self:addCellHeader(itable, "energy", { "helmod_common.energy-consumption" }, "energy_total")
	if User.getPreferenceSetting("display_pollution") then
		self:addCellHeader(itable, "pollution", { "helmod_common.pollution" })
	end
	---col building
	if User.getPreferenceSetting("display_building") or block ~= nil then
		self:addCellHeader(itable, "factory", { "helmod_result-panel.col-header-factory" })
	end
	if block ~= nil then
		self:addCellHeader(itable, "beacon", { "helmod_result-panel.col-header-beacon" })
	end
	if block ~= nil then
		for _, order in pairs(Model.getBlockOrder(block)) do
			if order == "products" then
				self:addCellHeader(itable, "products", { "helmod_result-panel.col-header-products" })
			else
				self:addCellHeader(itable, "ingredients", { "helmod_result-panel.col-header-ingredients" })
			end
		end
	else
		self:addCellHeader(itable, "products", { "helmod_result-panel.col-header-products" })
		self:addCellHeader(itable, "ingredients", { "helmod_result-panel.col-header-ingredients" })
	end
end

---@param list LuaGuiElement
---@param side ConstraintSide
---@param child_id string
---@return LuaGuiElement
local function addRowScroll(list, side, child_id)
	local scroll = GuiScroll(side, child_id)
	local existing = list[scroll:getName()]
	if existing == nil then return GuiElement.add(list, scroll) end
	-- Move the retained pane to its place in the rebuilt row without resetting its scroll position.
	local slot = GuiElement.add(list, GuiEmptyWidget())
	list.swap_children(existing.get_index_in_parent(), slot.get_index_in_parent())
	slot.destroy()
	return existing
end

local maximal_height = 93*3/1.25 + 4 -- for scale 125%

-------------------------------------------------------------------------------
---Add table row
---@param gui_table LuaGuiElement
---@param element table
function ProductionPanel:addTableRowCommon(gui_table, element)
	local display_hidden_column = User.getModGlobalSetting("display_hidden_column")
	if display_hidden_column == "Index and Id" or display_hidden_column == "All" then
		---col index
		GuiElement.add(gui_table, GuiLabel("value_index", element.id):caption(element.index))
		---col id
		GuiElement.add(gui_table, GuiLabel("value_id", element.id):caption(element.id))
	end
	if display_hidden_column == "Type and Name" or display_hidden_column == "All" then
		---col name
		GuiElement.add(gui_table, GuiLabel("value_name", element.id):caption(element.name))
		---col type
		GuiElement.add(gui_table, GuiLabel("value_type", element.id):caption(element.type))
	end
end

---@param cell LuaGuiElement
---@param classname string
---@param edit MoveTreeRow
local function addTreeArrow(cell, classname, edit)
	local sprite, tooltip = defines.sprites.arrow_right.black, "tooltip.up-element-in-tree"
	if TreeAction.toParent(edit.action) then
		sprite, tooltip = defines.sprites.arrow_left.black, "tooltip.down-element-in-tree"
	end
	local button = GuiButton(classname, TreeAction.moveButtonArgs(edit))
	GuiElement.add(cell, button:sprite("menu", sprite, sprite):style("helmod_button_menu_sm"):tooltip({tooltip, User.getModSetting("row_move_step")}))
end

-------------------------------------------------------------------------------
---Add table row
---@param gui_table LuaGuiElement
---@param model ModelData
---@param block BlockData
---@param recipe RecipeData
---@return LuaGuiElement
function ProductionPanel:addTableRowRecipe(gui_table, model, block, recipe)
	local recipe_prototype = RecipePrototype(recipe)

	---col action
	local cell_action = GuiElement.add(gui_table, GuiTable("action", recipe.id):column(3))
	---by ingredient
	local uri_button_top = "block-child-up"
	local uri_button_bottom = "block-child-down"
	---by product
	if block.by_product == false then
		uri_button_top = "block-child-down"
		uri_button_bottom = "block-child-up"
	end
	local uri_button_copy = "recipe-copy"
	addTreeArrow(cell_action, self.classname, {
	    action=TreeAction.name.recipeToParent, model_id=model.id, block_id=block.id, child_id=recipe.id
	})
	GuiElement.add(cell_action, GuiButton(self.classname, uri_button_top, model.id, block.id, recipe.id):sprite("menu", defines.sprites.arrow_top.black, defines.sprites.arrow_top.black):style("helmod_button_menu_sm"):tooltip({"tooltip.up-element", User.getModSetting("row_move_step") }))
	local remove = GuiButton(self.classname, ChildRemoval.buttonArgs{
	    action="block-child-remove", model_id=model.id, block_id=block.id, child_id=recipe.id
	})
	GuiElement.add(cell_action, remove:sprite("menu", defines.sprites.close.black, defines.sprites.close.black):style("helmod_button_menu_sm_red"):tooltip({"tooltip.remove-element" }))

	addTreeArrow(cell_action, self.classname, {
	    action=TreeAction.name.recipeToChild, model_id=model.id, block_id=block.id, child_id=recipe.id
	})
	GuiElement.add(cell_action, GuiButton(self.classname, uri_button_bottom, model.id, block.id, recipe.id):sprite("menu", defines.sprites.arrow_bottom.black, defines.sprites.arrow_bottom.black):style("helmod_button_menu_sm"):tooltip({ "tooltip.down-element", User.getModSetting("row_move_step") }))
	local tooltip_copy = {"", {"tooltip.copy-element"}}
	if Player.hasFeatureQuality() and recipe_prototype.is_support_quality then
		table.insert(tooltip_copy, "\n")
		table.insert(tooltip_copy, {"tooltip.copy-element-quality-up"})
		table.insert(tooltip_copy, "\n")
		table.insert(tooltip_copy, {"tooltip.copy-element-quality-down"})
	end
	GuiElement.add(cell_action, GuiButton(self.classname, uri_button_copy, model.id, block.id, recipe.id):sprite("menu", defines.sprites.copy.black, defines.sprites.copy.black):style("helmod_button_menu_sm"):tooltip(tooltip_copy))

	local recipe_color = User.getThumbnailColor(defines.thumbnail_color.names.recipe_default)
	---common cols
	self:addTableRowCommon(gui_table, recipe)
	---col recipe
	local cell_recipe = GuiElement.add(gui_table, GuiTable("recipe", recipe.id):column(2):style("helmod_table_list"))
	local edition_panel = "HMRecipeEdition"
	local is_support_factory = recipe_prototype:isSupportFactory()
	GuiElement.add(cell_recipe, GuiCellRecipe(edition_panel, "OPEN", model.id, block.id, recipe.id):element(recipe):infoIcon(recipe.type) :tooltip("tooltip.edit-recipe"):color(recipe_color):broken(recipe_prototype:native() == nil) :byLimit(block.by_limit))
	if recipe_prototype:native() == nil then
		Player.print("ERROR: Recipe " .. recipe.name .. " not exist in game")
	end
	---col energy
	local cell_energy = GuiElement.add(gui_table, GuiTable("energy", recipe.id):column(2):style("helmod_table_list"))
	if is_support_factory then
		GuiElement.add(cell_energy, GuiCellEnergy(edition_panel, "OPEN", model.id, block.id, recipe.id):element(recipe):tooltip( "tooltip.edit-recipe"):color(recipe_color):byLimit(block.by_limit))
	end

	---col pollution
	if User.getPreferenceSetting("display_pollution") then
		local cell_pollution = GuiElement.add(gui_table, GuiTable("pollution", recipe.id):column(2):style("helmod_table_list"))
		if is_support_factory then
			GuiElement.add(cell_pollution, GuiCellPollution(edition_panel, "OPEN", model.id, block.id, recipe.id):element(recipe):tooltip( "tooltip.edit-recipe"):color(recipe_color):byLimit(block.by_limit))
		end
	end

	---col factory
	local cell_factory = GuiElement.add(gui_table, GuiTable("factory", recipe.id):column(2):style("helmod_table_list"))
	if is_support_factory then
		local factory = recipe.factory
		if factory ~= nil then
			local gui_cell_factory = GuiCellFactory(self.classname, "factory-action", model.id, block.id, recipe.id):element(factory):tooltip("tooltip.edit-recipe"):color(recipe_color):byLimit(block.by_limit):controlInfo( "crafting-add")
			if block.by_limit == true then
				gui_cell_factory:byLimitUri(self.classname, "update-factory-limit", model.id, block.id, recipe.id)
			end
			if block.by_factory == true then
				gui_cell_factory:byFactory(self.classname, "update-factory-number", model.id, block.id, recipe.id)
			end
			GuiElement.add(cell_factory, gui_cell_factory)
		end
	end

	---col beacon
	local cell_beacons = GuiElement.add(gui_table, GuiFlowH("beacon", recipe.id))
	cell_beacons.style.horizontally_stretchable = false
	cell_beacons.style.horizontal_spacing = 2
	if is_support_factory then
		local beacons = recipe.beacons
		if beacons ~= nil then
			for index, beacon in pairs(beacons) do
				local gui_cell_beacon = GuiCellFactory(self.classname, "beacon-action", model.id, block.id, recipe.id, index):element(beacon):index(index):tooltip("tooltip.edit-recipe"):color(recipe_color):byLimit(block.by_limit):controlInfo("crafting-add")
				GuiElement.add(cell_beacons, gui_cell_beacon)
			end
		end
	end

	local display_hidden_products_mode = User.getPreferenceSetting("display_hidden_products_mode")
	local display_hidden_products = User.getPreferenceSetting("display_hidden_products")
	for _, order in pairs(Model.getBlockOrder(block)) do
		if order == "products" then
			---products
			local all_products = {}
			local hidden_products = {}
			local show_hidden_recipe_products = User.getParameter("show_hidden_recipe_products")
			local skip_hidden_products = show_hidden_recipe_products == recipe.id

			local display_product_cols = User.getPreferenceSetting("display_product_cols")
			local cell_scroll = addRowScroll(gui_table, ConstraintView.side.products, recipe.id)
			cell_scroll.style.maximal_height = maximal_height
			cell_scroll.horizontal_scroll_policy = "never"
			local cell_products = GuiElement.add(cell_scroll, GuiTable(ConstraintView.side.products, recipe.id):column(display_product_cols):style("helmod_table_list"))
			local product_color = User.getThumbnailColor(defines.thumbnail_color.names.product_default)
			local lua_products = recipe_prototype:getQualityProducts(recipe.factory, recipe.quality)
			if #lua_products <= 2*display_product_cols then
				skip_hidden_products = true
			end
			
			local max_count = 0
			for index, lua_product in spairs(lua_products, User.getProductSorter()) do
				local product_prototype = Product(lua_product)
				local product_key = product_prototype:getTableKey()
				
				if recipe.spoilage ~= nil and table.size(recipe.spoilage.products) then
					local spoilage = recipe.spoilage.products[product_key]
					if spoilage ~= nil then
						lua_product.spoil = spoilage.spoil
					end
				end

				local product = product_prototype:clone()
				product.time = model.time
				product.count = product_prototype:countProduct(recipe)
				product.count_limit = product_prototype:countLimitProduct(recipe)
				product.count_deep = product_prototype:countDeepProduct(recipe)
				
				product.contraint_type = ConstraintView.icon(recipe.contraints, product_key)
				
				product.control_info = ConstraintView.hint(block.solver, ConstraintView.action.product)
				
				product.is_pivot = false
				if recipe.pivot ~= nil and not(block.by_product == false) then
					local pivot = recipe.pivot
					if product_prototype:match(pivot) then
						product.is_pivot = true
					end
				end

				table.insert(all_products, product)
				max_count = math.max(max_count, product.count)
			end

			local threshold = ConstraintView.rowThreshold(recipe.count, skip_hidden_products, display_hidden_products_mode, display_hidden_products, max_count)
			for index, product in pairs(all_products) do
				if ConstraintView.showCell(product, threshold) then
					GuiElement.add(cell_products, GuiCellElement(self.classname, ConstraintView.action.product, model.id, block.id, recipe.id):element(product):tooltip("tooltip.add-recipe")
					:color(product_color):index(index):byLimit(block.by_limit):contraintIcon(product.contraint_type):isPivot(product.is_pivot):controlInfo(product.control_info))
				else
					table.insert(hidden_products, product)
				end
			end
			if #hidden_products > 0 then
				GuiElement.add(cell_products, GuiCellHiddenElement(self.classname, "show-hidden-recipe-products", model.id, block.id, recipe.id):element(hidden_products):tooltip("tooltip.add-recipe")
					:color(product_color))
			end
		else
			---ingredients
			local all_ingredients = {}
			local hidden_ingredients = {}
			
			local show_hidden_recipe_ingredients = User.getParameter("show_hidden_recipe_ingredients")
			local skip_hidden_products = show_hidden_recipe_ingredients == recipe.id

			local display_ingredient_cols = User.getPreferenceSetting("display_ingredient_cols")
			local cell_scroll = addRowScroll(gui_table, ConstraintView.side.ingredients, recipe.id)
			cell_scroll.style.maximal_height = maximal_height
			cell_scroll.horizontal_scroll_policy = "never"
			local cell_ingredients = GuiElement.add(cell_scroll, GuiTable(ConstraintView.side.ingredients, recipe.id):column(display_ingredient_cols):style("helmod_table_list"))
			local ingredient_color = User.getThumbnailColor(defines.thumbnail_color.names.ingredient_default)
			local lua_ingredients = GuiElement.visibleIngredients(recipe_prototype:getQualityIngredients(recipe.factory, recipe.quality))
			if table.size(lua_ingredients) <= 2*display_ingredient_cols then
				skip_hidden_products = true
			end

			local max_count = 0
			for index, lua_ingredient in spairs(lua_ingredients, User.getProductSorter()) do
				local ingredient_prototype = Product(lua_ingredient)
				local ingredient_key = ingredient_prototype:getTableKey()

				if recipe.spoilage ~= nil and table.size(recipe.spoilage.ingredients) then
					local spoilage = recipe.spoilage.ingredients[ingredient_key]
					if spoilage ~= nil then
						lua_ingredient.spoil = spoilage.spoil
					end
				end

				local ingredient = ingredient_prototype:clone()
				ingredient.time = model.time
				ingredient.count = ingredient_prototype:countIngredient(recipe)
				ingredient.count_limit = ingredient_prototype:countLimitIngredient(recipe)
				ingredient.count_deep = ingredient_prototype:countDeepIngredient(recipe)
				---si constant compte comme un produit (recipe rocket)
				if ingredient.constant == true then
					ingredient.count = ingredient_prototype:countProduct(recipe)
				end
				
				ingredient.contraint_type = ConstraintView.icon(recipe.contraints, ingredient_key)

				ingredient.control_info = ConstraintView.hint(block.solver, ConstraintView.action.ingredient)

				ingredient.is_pivot = false
				if recipe.pivot ~= nil and block.by_product == false then
					local pivot = recipe.pivot
					if ingredient_prototype:match(pivot) then
						ingredient.is_pivot = true
					end
				end

				table.insert(all_ingredients, ingredient)
				max_count = math.max(max_count, ingredient.count)
			end
			
			local threshold = ConstraintView.rowThreshold(recipe.count, skip_hidden_products, display_hidden_products_mode, display_hidden_products, max_count)
			for index, ingredient in pairs(all_ingredients) do
				if ConstraintView.showCell(ingredient, threshold) then
					GuiElement.add(cell_ingredients, GuiCellElement(self.classname, ConstraintView.action.ingredient, model.id, block.id, recipe.id):element(ingredient):tooltip("tooltip.add-recipe")
					:color(ingredient_color):index(index):byLimit(block.by_limit):contraintIcon(ingredient.contraint_type):isPivot(ingredient.is_pivot):controlInfo(ingredient.control_info))
				else
					table.insert(hidden_ingredients, ingredient)
				end
			end

			if #hidden_ingredients > 0 then
				GuiElement.add(cell_ingredients, GuiCellHiddenElement(self.classname, "show-hidden-recipe-ingredients", model.id, block.id, recipe.id):element(hidden_ingredients):tooltip("tooltip.add-recipe")
					:color(ingredient_color))
			end
		end
	end

	return cell_recipe
end

-------------------------------------------------------------------------------
---Add row data tab
---@param gui_table LuaGuiElement
---@param model ModelData
---@param parent BlockData
---@param block BlockData
---@return LuaGuiElement
function ProductionPanel:addTableRowBlock(gui_table, model, parent, block)
	local by_limit = false -- parent.by_limit
	local unlinked = Model.isUnlinkedBlock(block)
	local block_by_product = not (block ~= nil and block.by_product == false)
	---col action
	local cell_action = GuiElement.add(gui_table, GuiTable("action", block.id):column(3))
    local block_child_remove_confirm = User.getParameter("block_child_remove_confirm")
    
    if block.id == block_child_remove_confirm then
        local confirm = GuiButton(self.classname, ChildRemoval.buttonArgs{
            action="block-child-remove-confirmed", model_id=model.id, block_id=parent.id, child_id=block.id
        })
        GuiElement.add(cell_action, confirm:sprite("menu", defines.sprites.checkmark.black, defines.sprites.checkmark.black):style("helmod_button_menu_sm_actived_green"):tooltip({ "tooltip.remove-element-confirm" }))
        local cancel = GuiButton(self.classname, ChildRemoval.buttonArgs{
            action="block-child-remove-canceled", model_id=model.id, block_id=parent.id, child_id=block.id
        })
        GuiElement.add(cell_action, cancel:sprite("menu", defines.sprites.close.black, defines.sprites.close.black):style("helmod_button_menu_sm_actived_red"):tooltip({ "tooltip.remove-element-cancel" }))
    else
        ---by ingredient
        local uri_button_top = "block-child-up"
        local uri_button_bottom = "block-child-down"
        ---by product
        if parent.by_product == false then
            uri_button_top = "block-child-down"
            uri_button_bottom = "block-child-up"
        end
        addTreeArrow(cell_action, self.classname, {
            action=TreeAction.name.blockToParent, model_id=model.id, block_id=parent.id, child_id=block.id
        })
        GuiElement.add(cell_action, GuiButton(self.classname, uri_button_top, model.id, parent.id, block.id):sprite("menu", defines.sprites.arrow_top.black, defines.sprites.arrow_top.black):style("helmod_button_menu_sm"):tooltip({"tooltip.up-element", User.getModSetting("row_move_step") }))
        local remove = GuiButton(self.classname, ChildRemoval.buttonArgs{
            action="block-child-remove", model_id=model.id, block_id=parent.id, child_id=block.id
        })
        GuiElement.add(cell_action, remove:sprite("menu", defines.sprites.close.black, defines.sprites.close.black):style("helmod_button_menu_sm_red"):tooltip({ "tooltip.remove-element" }))

        addTreeArrow(cell_action, self.classname, {
            action=TreeAction.name.blockToChild, model_id=model.id, block_id=parent.id, child_id=block.id

        })
        GuiElement.add(cell_action, GuiButton(self.classname, uri_button_bottom, model.id, parent.id, block.id):sprite("menu", defines.sprites.arrow_bottom.black, defines.sprites.arrow_bottom.black):style("helmod_button_menu_sm"):tooltip({ "tooltip.down-element", User.getModSetting("row_move_step") }))
        local toggle = GuiButton(self.classname, TreeAction.linkButtonArgs{action=TreeAction.name.toggleLink, model_id=model.id, block_id=block.id})
        if unlinked then
            GuiElement.add(cell_action, toggle:sprite("menu", defines.sprites.unplugged.black, defines.sprites.unplugged.black):style("helmod_button_menu_sm"):tooltip({"tooltip.unlink-element" }))
        else
            GuiElement.add(cell_action, toggle:sprite("menu", defines.sprites.plugged.white, defines.sprites.plugged.black):style("helmod_button_menu_sm_selected"):tooltip({ "tooltip.unlink-element" }))
        end
    end
    ---common cols
	self:addTableRowCommon(gui_table, block)

	---col recipe
	local cell_recipe = GuiElement.add(gui_table, GuiTable("recipe", block.id):column(1):style("helmod_table_list"))

	local block_color = User.getThumbnailColor(defines.thumbnail_color.names.block_default)
	if not (block_by_product) then block_color = User.getThumbnailColor(defines.thumbnail_color.names.block_reverted) end
	GuiElement.add(cell_recipe, GuiCellBlock(self.classname, BlockMode.buttonArgs{action=BlockMode.action.icon, model_id=model.id, block_id=block.id}):element(block):infoIcon(block.type):tooltip(BlockMode.label.edit):color(block_color):byLimit(by_limit))

	---col energy
	local cell_energy = GuiElement.add(gui_table, GuiTable(block.id, "energy"):column(1):style("helmod_table_list"))
	GuiElement.add(cell_energy, GuiCellEnergy(self.classname, "row-change-block", model.id, block.id):element(block):tooltip("tooltip.edit-block"):color(block_color):byLimit(by_limit))

	---col pollution
	if User.getPreferenceSetting("display_pollution") then
		local cell_pollution = GuiElement.add(gui_table, GuiTable(block.id, "pollution"):column(1):style("helmod_table_list"))
		GuiElement.add(cell_pollution, GuiCellPollution(self.classname, "row-change-block", model.id, block.id):element(block):tooltip("tooltip.edit-block"):color(block_color):byLimit(by_limit))
	end

	---col building
	local cell_building = GuiElement.add(gui_table, GuiTable(block.id, "building"):column(1):style("helmod_table_list"))
	if User.getPreferenceSetting("display_building") then
		GuiElement.add(cell_building, GuiCellBuilding(self.classname, "row-change-block", model.id, block.id):element(block):forceGlobal(true):tooltip("tooltip.info-building"):color(block_color):byLimit(by_limit))
	end

	---col beacon
	local cell_beacons = GuiElement.add(gui_table, GuiFlowH(block.id, "beacon"))
	cell_beacons.style.horizontally_stretchable = false
	cell_beacons.style.horizontal_spacing = 2

	local product_sorter = User.getProductSorter()
	local visibleInputs = GuiElement.visibleIngredients(block.ingredients or {})
	local inputAction = ConstraintView.action.ingredient
	if not block_by_product and block.unlinked and block.by_factory ~= true then
		inputAction = ConstraintView.action.edition
	end

	local display_hidden_products_mode = User.getPreferenceSetting("display_hidden_products_mode")
	local display_hidden_products = User.getPreferenceSetting("display_hidden_products")
	
	for _, order in pairs(Model.getBlockOrder(parent)) do
		if order == "products" then
			---products
			local display_product_cols = User.getPreferenceSetting("display_product_cols")
			local cell_scroll = addRowScroll(gui_table, ConstraintView.side.products, block.id)
			cell_scroll.style.maximal_height = maximal_height
			cell_scroll.horizontal_scroll_policy = "never"
			local cell_products = GuiElement.add(cell_scroll, GuiTable(ConstraintView.side.products, block.id):column(display_product_cols):style("helmod_table_list"))
			cell_products.style.horizontally_stretchable = false
			if block.products ~= nil then
				local show_hidden_block_products = User.getParameter("show_hidden_block_products")
				local skip_hidden_products = show_hidden_block_products == block.id
				local all_products = {}
				local hidden_products = {}
				
				if table.size(block.products) <= 2*display_product_cols then
					skip_hidden_products = true
				end

				local max_count = 0
				for index, lua_product in spairs(block.products, product_sorter) do
					local constraint = ConstraintView.icon(block.contraints, index)
					local amount = lua_product.amount or 0
					local count = amount * (block.count or 0)
					local duplicate = ConstraintView.duplicateOutput(constraint, count, visibleInputs[index] ~= nil, inputAction)
					if not duplicate and ConstraintView.showFlow(lua_product.state, lua_product.amount, block_by_product, ModelCompute.waste_value, constraint) then
						local product_prototype = Product(lua_product)
						local product = product_prototype:clone()
						product.parent_id = parent.id
						product.time = model.time
						product.count = count
						product.count_limit = amount * (block.count_limit or 0)
						product.count_deep = amount * (block.count_deep or 0)

						product.button_action = ConstraintView.action.product
						product.button_tooltip = "tooltip.product"
						if not (block_by_product) or not (Model.isUnlinkedBlock(block)) or block.by_factory == true then
							product.button_action = ConstraintView.action.product
							product.button_tooltip = "tooltip.add-recipe"
						else
							product.button_action = ConstraintView.action.edition
							product.button_tooltip = "tooltip.edit-product"
							product.parent_id = block.id
						end

						product.contraint_type = constraint
						---color
						product.product_color = User.getThumbnailColor(defines.thumbnail_color.names.product_default)
						if product.state == 1 then
							if not (Model.isUnlinkedBlock(block)) or block.by_factory == true then
								product.product_color = User.getThumbnailColor(defines.thumbnail_color.names.product_default)
							else
								block_id = block.id
								product.product_color = User.getThumbnailColor(defines.thumbnail_color.names.product_driving)
							end
						elseif product.state == 3 then
							product.product_color = User.getThumbnailColor(defines.thumbnail_color.names.product_overflow)
						else
							product.product_color = User.getThumbnailColor(defines.thumbnail_color.names.product_default)
						end

						product.is_pivot = false
						if parent.by_product ~= false and block.pivot ~= nil  then
							local pivot = block.pivot
							if product_prototype:match(pivot) then
								product.is_pivot = true
							end
						end
						
						product.control_info = ConstraintView.hint(parent.solver, product.button_action)

						table.insert(all_products, product)
						max_count = math.max(max_count, product.count)
					end
				end

				local threshold = ConstraintView.rowThreshold(block.count, skip_hidden_products, display_hidden_products_mode, display_hidden_products, max_count)
				for index, product in pairs(all_products) do
					if ConstraintView.showCell(product, threshold) then
						GuiElement.add(cell_products, GuiCellElement(self.classname, product.button_action, model.id, product.parent_id, block.id):element(product):byLimit(by_limit)
						:tooltip(product.button_tooltip):color(product.product_color):index(index):contraintIcon(product.contraint_type):isPivot(product.is_pivot):controlInfo(product.control_info))
					else
						table.insert(hidden_products, product)
					end
				end

				if #hidden_products > 0 then
					local product_color = User.getThumbnailColor(defines.thumbnail_color.names.product_default)
					GuiElement.add(cell_products, GuiCellHiddenElement(self.classname, "show-hidden-block-products", model.id, parent.id, block.id):element(hidden_products):tooltip("tooltip.add-recipe")
						:color(product_color))
				end
			end
		else
			---ingredients
			local all_ingredients = {}
			local hidden_ingredients = {}

			local display_ingredient_cols = User.getPreferenceSetting("display_ingredient_cols")
			local cell_scroll = addRowScroll(gui_table, ConstraintView.side.ingredients, block.id)
			cell_scroll.style.maximal_height = maximal_height
			cell_scroll.horizontal_scroll_policy = "never"
			local cell_ingredients = GuiElement.add(cell_scroll, GuiTable(ConstraintView.side.ingredients, block.id):column(display_ingredient_cols))
			cell_ingredients.style.horizontally_stretchable = false
			if block.ingredients ~= nil then
				local show_hidden_block_ingredients = User.getParameter("show_hidden_block_ingredients")
				local skip_hidden_products = show_hidden_block_ingredients == block.id
				
				if table.size(visibleInputs) <= 2*display_ingredient_cols then
					skip_hidden_products = true
				end

				local max_count = 0
				for index, lua_ingredient in spairs(visibleInputs, product_sorter) do
					local constraint = ConstraintView.icon(block.contraints, index)
					if ConstraintView.showFlow(lua_ingredient.state, lua_ingredient.amount, not (block_by_product), ModelCompute.waste_value, constraint) then
						local ingredient_prototype = Product(lua_ingredient)
						local ingredient = ingredient_prototype:clone()
						ingredient.time = model.time
						ingredient.count = lua_ingredient.amount * (block.count or 0)
						ingredient.count_limit = lua_ingredient.amount * (block.count_limit or 0)
						ingredient.count_deep = lua_ingredient.amount * (block.count_deep or 0)

						ingredient.parent_id = parent.id
						ingredient.button_action = inputAction
						if inputAction == ConstraintView.action.ingredient then
							ingredient.button_tooltip = "tooltip.add-recipe"
						else
							ingredient.button_tooltip = "tooltip.edit-product"
							ingredient.parent_id = block.id
						end
						---color
						ingredient.ingredient_color = User.getThumbnailColor(defines.thumbnail_color.names.ingredient_default)
						if ingredient.state == 1 then
							if not (block.unlinked) or block.by_factory == true then
								ingredient.ingredient_color = User.getThumbnailColor(defines.thumbnail_color.names.ingredient_default)
							else
								ingredient.ingredient_color = User.getThumbnailColor(defines.thumbnail_color.names.ingredient_driving)
							end
						elseif ingredient.state == 3 then
							ingredient.ingredient_color = User.getThumbnailColor(defines.thumbnail_color.names.ingredient_overflow)
						else
							ingredient.ingredient_color = User.getThumbnailColor(defines.thumbnail_color.names.ingredient_default)
						end
						
						ingredient.is_pivot = false
						if not(block_by_product) and block.pivot ~= nil  then
							local pivot = block.pivot
							if ingredient_prototype:match(pivot) then
								ingredient.is_pivot = true
							end
						end

						ingredient.contraint_type = constraint
						ingredient.control_info = ConstraintView.hint(parent.solver, ingredient.button_action)

						table.insert(all_ingredients, ingredient)
						max_count = math.max(max_count, ingredient.count)
					end
				end

				local threshold = ConstraintView.rowThreshold(block.count, skip_hidden_products, display_hidden_products_mode, display_hidden_products, max_count)
				for index, ingredient in pairs(all_ingredients) do
					if ConstraintView.showCell(ingredient, threshold) then
							GuiElement.add(cell_ingredients, GuiCellElement(self.classname, ingredient.button_action, model.id, ingredient.parent_id, block.id, ingredient.name):element(ingredient):byLimit(by_limit)
							:tooltip(ingredient.button_tooltip):color(ingredient.ingredient_color):index(index):contraintIcon(ingredient.contraint_type):isPivot(ingredient.is_pivot):controlInfo(ingredient.control_info))
					else
						table.insert(hidden_ingredients, ingredient)
					end
				end

				if #hidden_ingredients > 0 then
					local product_color = User.getThumbnailColor(defines.thumbnail_color.names.ingredient_default)
					GuiElement.add(cell_ingredients, GuiCellHiddenElement(self.classname, "show-hidden-block-ingredients", model.id, parent.id, block.id):element(hidden_ingredients):tooltip("tooltip.add-recipe")
						:color(product_color))
				end
			end
		end
	end
	return cell_recipe
end

---@alias PanelToolbarHandler fun(event:LuaEvent, model:ModelData)
---@class PanelToolbarHandlers
---@field location PanelToolbarHandler
---@field logistics PanelToolbarHandler
---@field item PanelToolbarHandler
---@field fluid PanelToolbarHandler

---@type PanelToolbarHandlers
local panelHandlers = {
	location = function(event, model)
		model.location = Player.getHMLocations()[event.element.selected_index]
	end,
	logistics = function()
		local setting = BlockToolbar.setting.logistics
		User.setParameter(setting, not User.getParameter(setting))
	end,
	item = function(event)
		User.setParameter(BlockToolbar.setting.item, defines.constant.logistic_list_for_item[event.element.selected_index])
	end,
	fluid = function(event)
		User.setParameter(BlockToolbar.setting.fluid, defines.constant.logistic_list_for_fluid[event.element.selected_index])
	end,
}
local panelToolbar = BlockToolbar.bind(panelHandlers)

---@alias ScopedToolbarHandler fun(model:ModelData, block:BlockData, event:LuaEvent, classname:string)
---@class ScopedToolbarHandlers
---@field deep ScopedToolbarHandler
---@field limit ScopedToolbarHandler
---@field reset ScopedToolbarHandler

---@type ScopedToolbarHandlers
local blockHandlers = {
	deep = function(_, _, event, classname)
		local setting = BlockToolbar.setting.deep
		User.setParameter(setting, not User.getParameter(setting))
		Controller:send(defines.mod.events.on_gui_update, event, classname)
	end,
	limit = function(model, block, event)
		if not User.isWriter(model) then return end
		ProductionBlockMode.setLimit(block, not block.by_limit)
		ModelCompute.update(model)
		Controller:send(defines.mod.events.on_gui_update, event)
	end,
	reset = function(model, block, event, classname)
		if not User.isWriter(model) then return end
		ModelBuilder.updateBlockChildrenProduction(block, 1)
		ModelCompute.update(model)
		Controller:send(defines.mod.events.on_gui_update, event, classname)
	end,
}
local blockToolbar = BlockToolbar.bind(blockHandlers)

-------------------------------------------------------------------------------
---On event
---@param event LuaEvent
function ProductionPanel:onEvent(event)
	local model, block, _ = self:getParameterObjects()

	if block == nil then
		block = model.blocks[event.item2]
	end
	local panelEdit = BlockToolbar.decodePanel(event)
	if panelEdit then
		panelToolbar[panelEdit.action](event, model)
		Controller:send(defines.mod.events.on_gui_update, event)
		return
	end
	local blockEdit = BlockToolbar.decodeBlock(event)
	if blockEdit then
		if block and blockEdit.model_id == model.id and blockEdit.block_id == block.id then
			blockToolbar[blockEdit.action](model, block, event, self.classname)
		end
		return
	end
	local header = BlockHeader.decode(event)
	if header ~= nil then
		if block ~= nil and header.model_id == model.id and header.block_id == block.id then
			self:onHeaderEdit(header, event, model)
		end
		return
	end
	local mode = BlockMode.decode(event)
	if mode ~= nil and block ~= nil then
		self:onBlockModeClick(event, mode, model, block)
		return
	end
	---***************************
	---access for all
	---***************************
	self:onEventAccessAll(event, model, block)

	---***************************
	---access admin or owner
	---***************************

	if User.isReader(model) then
		self:onEventAccessRead(event, model, block)
	end

	---*******************************
	---access admin or owner or write
	---*******************************

	if User.isWriter(model) then
		self:onEventAccessWrite(event, model, block)
	end

	---********************************
	---access admin or owner or delete
	---********************************

	if User.isDeleter(model) then
		self:onEventAccessDelete(event, model, block)
	end

	---*******************************
	---access admin only
	---*******************************

	if User.isAdmin() then
		self:onEventAccessAdmin(event, model, block)
	end
end

---@param edit BlockHeaderEdit
---@param event LuaEvent
---@param model ModelData
function ProductionPanel:onHeaderEdit(edit, event, model)
	local setting
	if edit.action == "block-all-ingredient-visible" then
		setting = BlockHeader.setting.ingredients
	elseif edit.action == "block-all-product-visible" then
		setting = BlockHeader.setting.products
	else
		---@type ClearBlockInputs
		local clear = edit
		if not User.isWriter(model) then return end
		ModelCompute.clearBlockInputs(model.blocks[clear.block_id] or model.block_root)
		ModelCompute.update(model)
		Controller:send(defines.mod.events.on_gui_update, event)
		return
	end
	User.setParameter(setting, not User.getParameter(setting))
	Controller:send(defines.mod.events.on_gui_update, event, self.classname)
end

---@param event LuaEvent
---@param click BlockModeClick
---@param model ModelData
---@param selected BlockData
function ProductionPanel:onBlockModeClick(event, click, model, selected)
	if click.model_id ~= model.id then return end
	local block = selected
	---@type ProductionBlockModeOption
	local option
	if click.action == "row-block-mode" then
		block = model.blocks[click.block_id]
		if block == nil or selected.children[click.block_id] ~= block then return end
		local left = event.button == defines.mouse_button_type.left
		if left and event.control and not event.shift then
			option = ProductionBlockMode.option.consumer
		elseif left and event.shift and not event.control then
			option = ProductionBlockMode.option.input
		else
			Controller:closeEditionOrSelector()
			Controller:send("on_gui_open", event, self.classname)
			return
		end
	elseif click.action == "block-consumer" then
		if click.block_id ~= selected.id then return end
		option = ProductionBlockMode.option.consumer
	else
		---@type ToggleInput
		local input = click
		if input.block_id ~= selected.id then return end
		option = ProductionBlockMode.option.input
	end
	if not User.isWriter(model) then return end
	ProductionBlockMode.toggle(block, option)
	ModelCompute.update(model)
	Controller:send(defines.mod.events.on_gui_update, event)
end

-------------------------------------------------------------------------------
---On event
---@param event LuaEvent
---@param model table
---@param block table
function ProductionPanel:onEventAccessAll(event, model, block)
	if event.action == "refresh-model" then
		ModelCompute.update(model)
		Controller:send("on_gui_update", event)
	end

	if event.action == "change-model" then
		Controller:send("on_gui_open", event, self.classname)
	end

	if event.action == "new-model" then
		Model.newModel()
		Controller:send("on_gui_open", event, self.classname)
	end

	if event.action == "new-block" then
		Controller:send("on_gui_open", event, "HMRecipeSelector")
	end

	-- used in navigation menu
	if event.action == "change-block" then
		Controller:closeEditionOrSelector()
		Controller:send("on_gui_open", event, self.classname)
	end

	-- used in row of blocks
	if event.action == "row-change-block" then
		Controller:closeEditionOrSelector()
		Controller:send("on_gui_open", event, self.classname)
	end

	if event.action == "block-combinator-solids" then
		local items = ProductionPanel.get_elements(block, event.item3, "item")
		if #items > 0 then
			Player.setSmartToolItemListConstantCombinator(items)
			Controller:send("on_gui_close", event, self.classname)
		end
	end

	if event.action == "block-combinator-fluids" then
		local items = ProductionPanel.get_elements(block, event.item3, "fluid")
		if #items > 0 then
			Player.setSmartToolItemListConstantCombinator(items)
			Controller:send("on_gui_close", event, self.classname)
		end
	end

	if event.action == "block-combinator-pick" then
		local combinator_select_mode = User.getParameter("combinator_select_mode")
		if  combinator_select_mode ~= nil then
			self:toggleCombinatorSelection(block, combinator_select_mode, event.item)
			Controller:send("on_gui_update", event, self.classname)
		end
	end

	if event.action == "block-combinator-select" then
		if User.getParameter("combinator_select_mode") ~= nil then
			---turning off: generate from the current selection (skip if nothing picked)
			local items = {}
			for _, item in pairs(User.getParameter("combinator_selection") or {}) do
				table.insert(items, item)
			end
			User.setParameter("combinator_select_mode", nil)
			User.setParameter("combinator_selection", {})
			if #items > 0 then
				Player.setSmartToolItemListConstantCombinator(items)
				Controller:send("on_gui_close", event, self.classname)
			end
		else
			User.setParameter("combinator_selection", {})
			User.setParameter("combinator_select_mode", event.item3)
		end
		Controller:send("on_gui_update", event, self.classname)
	end

	if event.action == "block-expand-or-collapse" then
		local child_block = model.blocks[event.item2]
		local is_expanded = Model.isExpandBlock(child_block)
		Model.setExpandBlock(child_block, not(is_expanded))
		Controller:send("on_gui_update", event, self.classname)
	end

end

-------------------------------------------------------------------------------
---On event
---@param event LuaEvent
---@param model ModelData
---@param block table
function ProductionPanel:onEventAccessRead(event, model, block)
	if event.action == "copy-block" then
		if block ~= nil then
			if not SheetPlanner.finishModel(model.id) then
				Player.print({"helmod_common.solver-failed"})
				return
			end
			local data = Converter.write(block)
			User.setParameter("copy_past", data)
		end
	end

	if event.action == "factory-action" then
		local recipe = block.children[event.item3]
		if event.control == true then
			if recipe ~= nil and recipe.factory ~= nil then
				local factory = recipe.factory
				Player.beginCrafting(factory.name, factory.count)
			end
		else
			event.action = "OPEN"
			Controller:send("on_gui_open", event, "HMRecipeEdition")
		end
	end

	if event.action == "beacon-action" then
		if event.control == true then
			local recipe = block.children[event.item3]
			local index = tonumber(event.item4)
			if recipe ~= nil and recipe.beacons ~= nil and recipe.beacons[index] ~= nil then
				local beacon = recipe.beacons[index]
				Player.beginCrafting(beacon.name, beacon.count)
			end
		else
			event.action = "OPEN"
			Controller:send("on_gui_open", event, "HMRecipeEdition")
		end
	end

	if event.action == "building-constant" then
		Player.setSmartToolBuildingConstantCombinator(block)
	end

	if event.action == "show-hidden-recipe-products" then
		User.setParameter("show_hidden_recipe_products", event.item3)
		Controller:send("on_gui_update", event, self.classname)
	end
	
	if event.action == "show-hidden-recipe-ingredients" then
		User.setParameter("show_hidden_recipe_ingredients", event.item3)
		Controller:send("on_gui_update", event, self.classname)
	end
	
	if event.action == "show-hidden-block-products" then
		User.setParameter("show_hidden_block_products", event.item3)
		Controller:send("on_gui_update", event, self.classname)
	end
	
	if event.action == "show-hidden-block-ingredients" then
		User.setParameter("show_hidden_block_ingredients", event.item3)
		Controller:send("on_gui_update", event, self.classname)
	end

	if event.action == "show-hidden-input-products" then
		User.setParameter("show_hidden_input_products", true)
		Controller:send("on_gui_update", event, self.classname)
	end

	if event.action == "show-hidden-output-products" then
		User.setParameter("show_hidden_output_products", true)
		Controller:send("on_gui_update", event, self.classname)
	end
	
	if event.action == "block-pipette" then
		local items = ProductionPanel.get_elements(block, event.item3)
		Player.setSmartToolItemListConstantCombinator(items)
		Controller:send("on_gui_close", event, self.classname)
	end
end

function ProductionPanel.get_elements(block, type, filter)
	
	local elements = nil
	if type == "products" then
		elements = block.products
	else
		elements = block.ingredients
	end
	local items = {}
	for index, lua_product in spairs(elements, User.getProductSorter()) do
		if (lua_product.amount or 0) > ModelCompute.waste_value and (filter == nil or lua_product.type == filter) then
			local product = ProductionPanel.get_element(block, lua_product)
			table.insert(items, product)
		end
	end
	return items
end

function ProductionPanel.get_element(block, lua_product)
	local item_mode = User.getPreferenceSetting("combinator_item_quantity_mode")
    local fluid_mode = User.getPreferenceSetting("combinator_fluid_quantity_mode")
    local item_value = User.getPreferenceSetting("combinator_default_item_value")
    local fluid_value = User.getPreferenceSetting("combinator_default_fluid_value")
    local fluid_stack = User.getPreferenceSetting("combinator_default_fluid_stack")
	local product = Product(lua_product):clone()
	product.count = product.amount
	if block.by_limit then
		product.count = lua_product.amount * (block.count_limit or 0)
	end
	product.count = math.ceil(product.count)
	if product.type == "item" then
		if item_mode == "amount" then
			product.count = item_value * product.count
		else
			local stack_size = ItemPrototype(product.name):stackSize()
			product.count = item_value * (stack_size or 0)
		end
	else
		if fluid_mode == "amount" then
			product.count = fluid_value * product.count
		else
			product.count = fluid_value * (fluid_stack or 0)
		end
	end
	return product
end
-------------------------------------------------------------------------------
---On event
---@param event LuaEvent
---@param model table
---@param block table
function ProductionPanel:onEventAccessWrite(event, model, block)
	local selector_name = "HMRecipeSelector"
	

	if event.action == "solver_switch" then
		local index = event.element.selected_index
		local i_solver = 1
		for _, value in pairs(defines.constant.solvers) do
			if index == i_solver then
				User.setParameter("solver_selected", value)
				break
			end
			i_solver = i_solver + 1
		end
		ModelCompute.update(model)
		Controller:send("on_gui_update", event, self.classname)
	end

	if event.action == "model-index-up" and model ~= nil then
		if model.owner == Player.native().name then
			local models = Model.getModelsOwner()
			table.up_indexed_list(models, model.index, 1)
			self:updateIndexPanel(model)
		end
	end

	if event.action == "model-index-down" and model ~= nil then
		if model.owner == Player.native().name then
			local models = Model.getModelsOwner()
			table.down_indexed_list(models, model.index, 1)
			self:updateIndexPanel(model)
		end
	end

	if event.action == "change-boolean-option" and block ~= nil then
		ModelBuilder.updateProductionBlockOption(block, event.item1, not (block[event.item1]))
		ModelCompute.update(model)
		Controller:send("on_gui_update", event)
	end

	if event.action == "change-number-option" and block ~= nil then
		local value = GuiElement.getInputNumber(event.element)
		ModelBuilder.updateProductionBlockOption(block, event.item1, value)
		ModelCompute.update(model)
		Controller:send("on_gui_update", event)
	end

	if event.action == "change-time" then
		local index = event.element.selected_index
		model.time = defines.constant.base_times[index].value or 1
		ModelCompute.update(model)
		Controller:send("on_gui_update", event)
		Controller:send("on_gui_close", event, "HMProductEdition")
	end

	if event.action == "product-selected" then
		if event.button == defines.mouse_button_type.right then
			-- Set Parameter Target for the selector return
			User.setParameter("HMRecipeSelector_target", self.classname)
			Controller:send("on_gui_open", event, "HMRecipeSelector")
		end
	end

	if event.action == ConstraintView.action.edition then
		if event.button == defines.mouse_button_type.right then
			-- Set Parameter Target for the selector return
			User.setParameter("HMRecipeSelector_target", self.classname)
			Controller:send("on_gui_open", event, selector_name)
		else
			if event.control == true and event.item5 ~= ConstraintView.noTarget then
				if block.products_linked == nil then block.products_linked = {} end
				block.products_linked[event.item5] = not (block.products_linked[event.item5])
				ModelCompute.update(model)
				Controller:send("on_gui_update", event)
			else
				Controller:send("on_gui_open", event, "HMProductEdition")
			end
		end
	end

	if block ~= nil and event.action == "product-info" then
		if block.products_linked == nil then block.products_linked = {} end
		if event.control == true and event.item5 ~= ConstraintView.noTarget then
			block.products_linked[event.item5] = not (block.products_linked[event.item5])
			ModelCompute.update(model)
			Controller:send("on_gui_update", event)
		end
	end

	local treeEdit = TreeAction.decode(event)
	if treeEdit ~= nil then
		if treeEdit.action == TreeAction.name.toggleLink then
			ModelBuilder.blockUnlink(model.blocks[treeEdit.block_id])
		elseif TreeAction.toParent(treeEdit.action) then
			ModelBuilder.updateTreeChildDown(model, block, block.children[treeEdit.child_id], event.control)
		else
			ModelBuilder.updateTreeChildUp(model, block, block.children[treeEdit.child_id], event.control)
		end
		ModelCompute.update(model)
		Controller:send(defines.mod.events.on_gui_update, event)
	end

	if event.action == "past-block" then
		local data_string = User.getParameter("copy_past")
		local from_data = Converter.read(data_string)
		if from_data ~= nil then
			ModelBuilder.pastModel(model, block, from_data)
			ModelCompute.update(model)
			Controller:send("on_gui_update", event)
		end
	end

	if event.action == "change-computing" then
		local index = event.element.selected_index
		if index == 3 then
			ModelBuilder.updateProductionBlockOption(block, "by_factory", false)
			ModelBuilder.updateProductionBlockOption(block, "solver", true)
		elseif index == 2 then
			ModelBuilder.updateProductionBlockOption(block, "by_factory", true)
			ModelBuilder.updateProductionBlockOption(block, "solver", false)
		else
			ModelBuilder.updateProductionBlockOption(block, "by_factory", false)
			ModelBuilder.updateProductionBlockOption(block, "solver", false)
		end
		ModelCompute.update(model)
		Controller:send("on_gui_update", event)
	end

	if event.action == "block-child-up" then
		local step = 1
		if event.shift then step = User.getModSetting("row_move_step") end
		if event.control then step = 1000 end
		local child = block.children[event.item3]
		ModelBuilder.blockChildUp(block, child, step)
		ModelCompute.update(model)
		User.setParameter("scroll_element", child.id)
		Controller:send("on_gui_update", event)
	end

	if event.action == "block-child-down" then
		local step = 1
		if event.shift then step = User.getModSetting("row_move_step") end
		if event.control then step = 1000 end
		local child = block.children[event.item3]
		ModelBuilder.blockChildDown(block, child, step)
		ModelCompute.update(model)
		User.setParameter("scroll_element", child.id)
		Controller:send("on_gui_update", event)
	end

	if event.button == defines.mouse_button_type.left and block then
		local supply, enabled = MatrixSupply.headerEdit(event)
		if supply and supply.model_id == model.id and supply.block_id == block.id then
			if MatrixSupplies.set(block, supply.material, enabled) then
				ModelCompute.update(model, block)
				Controller:send("on_gui_refresh", event)
			end
			return
		end
	end

	local edit = ConstraintView.edit(event)
	if edit ~= nil and block ~= nil then
		ModelBuilder.updateChildContraint(block.children[edit.child_id], {type=edit.kind, item=event.item})
		ModelCompute.update(model)
		Controller:send(defines.mod.events.on_gui_update, event)
		return
	end

	if event.action == ConstraintView.action.product then
		if event.control == false and event.shift == false then
			if event.button == defines.mouse_button_type.right then
				-- Set Parameter Target for the selector return
				User.setParameter("HMRecipeSelector_target", self.classname)
				Controller:send("on_gui_open", event, selector_name)
			else
				local recipes = Player.searchRecipe(event.item4, true)
				if #recipes == 1 then
					local recipe = recipes[1]
					local _, new_recipe = ModelBuilder.addRecipeIntoProductionBlock(model, block, recipe.name, recipe.type, 0)
					new_recipe.quality = event.item.quality
					ModelCompute.update(model)
					User.setParameter("scroll_element", new_recipe.id)
					Controller:send("on_gui_update", event)
				else
					-- Set Parameter Target for the selector return
					User.setParameter("HMRecipeSelector_target", self.classname)
					---pour ouvrir avec le filtre ingredient
					event.button = defines.mouse_button_type.right
					Controller:send("on_gui_open", event, selector_name)
				end
			end
		end
	end

	if event.action == ConstraintView.action.ingredient then
		if event.control == false and event.shift == false then
			if event.button == defines.mouse_button_type.right then
				-- Set Parameter Target for the selector return
				User.setParameter("HMRecipeSelector_target", self.classname)
				Controller:send("on_gui_open", event, selector_name)
			else
				local recipes = Player.searchRecipe(event.item4)
				if #recipes == 1 then
					local recipe = recipes[1]
					local _, new_recipe = ModelBuilder.addRecipeIntoProductionBlock(model, block, recipe.name, recipe.type)
					new_recipe.quality = event.item.quality
					ModelCompute.update(model)
					User.setParameter("scroll_element", new_recipe.id)
					Controller:send("on_gui_update", event)
				else
					-- Set Parameter Target for the selector return
					User.setParameter("HMRecipeSelector_target", self.classname)
					Controller:send("on_gui_open", event, selector_name)
				end
			end
		end
	end

	if event.action == "update-factory-number" then
		local text = event.element.text
		local ok, err = pcall(function()
			local value = formula(text) or 0
			local recipe = block.children[event.item3]
			ModelBuilder.updateFactoryNumber(recipe, value)
			ModelCompute.update(model)
			Controller:send("on_gui_update", event)
		end)
		if not (ok) then
			Player.print("Formula is not valid!")
		end
	end

	if event.action == "update-factory-limit" then
		local text = event.element.text
		local ok, err = pcall(function()
			local value = formula(text) or 0
			local recipe = block.children[event.item3]
			ModelBuilder.updateFactoryLimit(recipe, value)
			ModelCompute.update(model)
			Controller:send("on_gui_update", event)
		end)
		if not (ok) then
			Player.print("Formula is not valid!")
		end
	end

	if event.action == "block-switch-unlink" then
		local switch_state = event.element.switch_state == "left"
		ModelBuilder.updateProductionBlockOption(block, "unlinked", switch_state)
		ModelCompute.update(model)
		Controller:send("on_gui_update", event)
	end

	if event.action == "block-switch-element" then
		local switch_state = event.element.switch_state == "left"
		ModelBuilder.updateProductionBlockOption(block, "by_product", switch_state)
		ModelCompute.update(model)
		Controller:send("on_gui_update", event)
	end

	if event.action == "block-switch-factory" then
		local switch_state = not (event.element.switch_state == "left")
		ModelBuilder.updateProductionBlockOption(block, "by_factory", switch_state)
		ModelCompute.update(model)
		Controller:send("on_gui_update", event)
	end

	if event.action == "block-switch-solver" then
		local switch_state = event.element.switch_state == "right"
		ModelBuilder.updateProductionBlockOption(block, "solver", switch_state)
		ModelCompute.update(model)
		Controller:send("on_gui_update", event)
	end

	if event.action == "block-switch-limit" then
		local switch_state = event.element.switch_state == "left"
		ProductionBlockMode.setLimit(block, switch_state)
		ModelCompute.update(model)
		Controller:send("on_gui_update", event)
	end
	

	if event.action == "recipe-copy" then
		local child = block.children[event.item3]
		local mode = 0
		if event.control then
			mode = 1
		elseif event.shift then
			mode = 2
		end
		ModelBuilder.addRecipeCopyIntoProductionBlock(model, block, child, mode)
		ModelCompute.update(model)
		Controller:send("on_gui_update", event)
	end
end

-------------------------------------------------------------------------------
---On event
---@param event LuaEvent
---@param model ModelData
---@param block BlockData
function ProductionPanel:onEventAccessDelete(event, model, block)
	local header = BlockRemoval.decode(event)
	if header ~= nil then
		self:onBlockRemoval(header, event, model, block)
		return
	end

	local removal = ChildRemoval.decode(event)
	if removal ~= nil then
		self:onChildRemoval(removal, model, block)
		Controller:send("on_gui_update", event, self.classname)
	end
end

---@param removal BlockRemovalAction
---@param event LuaEvent
---@param model ModelData
---@param block BlockData
function ProductionPanel:onBlockRemoval(removal, event, model, block)
	if removal.action == "block-remove" then
		User.setParameter("block_remove_confirm", block.id)
		Controller:send("on_gui_update", event, self.classname)
		return
	end
	if removal.action == "block-remove-canceled" then
		Controller:send("on_gui_update", event, self.classname)
		return
	end

	---@type ConfirmBlockRemoval
	local confirmation = removal
	if block.parent_id == nil then
		ModelBuilder.rebuildParentBlockOfModel(model)
	end
	if block.parent_id == model.id then
		ModelBuilder.removeModel(model.id)
		event.item1, event.item2 = nil, nil
	else
		local parent = model.blocks[block.parent_id] or model.block_root
		ModelBuilder.blockChildRemove(model, parent, block)
		ModelCompute.update(model)
		event.item1, event.item2 = confirmation.model_id, block.parent_id
	end
	Controller:send("on_gui_open", event, self.classname)
end

---@param removal ChildRemovalAction
---@param model ModelData
---@param block BlockData
function ProductionPanel:onChildRemoval(removal, model, block)
	if removal.action == "block-child-remove-canceled" then return end
	local child
	if removal.action == "block-child-remove" then
		child = block.children[removal.child_id]
		if Model.isBlock(child) then
			User.setParameter("block_child_remove_confirm", child.id)
			return
		end
	else
		---@type ConfirmChildRemoval
		local confirmation = removal
		child = block.children[confirmation.child_id]
	end
	ModelBuilder.blockChildRemove(model, block, child)
	ModelCompute.update(model)
end

-------------------------------------------------------------------------------
---On event
---@param event LuaEvent
---@param removal ChildRemovalAction?
function ProductionPanel:onEventAutoCancel(event, removal)
    local header = BlockRemoval.tag(event.action)
    if header == nil or header == "block-remove-canceled" then
        User.setParameter("block_remove_confirm", nil)
    end
    if removal == nil or removal.action == "block-child-remove-canceled" then
        User.setParameter("block_child_remove_confirm", nil)
    end
end
-------------------------------------------------------------------------------
---On event
---@param event LuaEvent
---@param model table
---@param block table
function ProductionPanel:onEventAccessAdmin(event, model, block)
	if event.action == "game-pause" then
		if not (game.is_multiplayer()) then
			SheetPlanner.finishPending()
			User.setParameter("auto-pause", true)
			game.tick_paused = true
			Controller:send("on_gui_pause", event)
		end
	end

	if event.action == "game-play" then
		User.setParameter("auto-pause", false)
		game.tick_paused = false
		Controller:send("on_gui_pause", event)
	end
end