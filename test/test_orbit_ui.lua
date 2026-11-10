local FusionControl = require "gui.controls.FusionControl"
local BlockHeader = require "gui.controls.BlockHeader"
local ConstraintView = require "gui.controls.ConstraintView"
local MatrixSupply = require "gui.controls.MatrixSupply"
local recycling = require "test_recycling_balance"
local function find_element(element, predicate)
 if predicate(element) then return element end
 for _, child in pairs(element.children) do
  local result = find_element(child, predicate)
  if result then return result end
 end
end
local function click(element, player)
 assert(element, "GUI control exists")
 EventController.onGuiClickButton{player_index=player.index, element=element, button=defines.mouse_button_type.left}
 assert(not Player.getLastError(), "Helmod GUI event failed")
 game.tick_paused=false
end

local function checkSiloPartPicker(player)
 local model = Model.newModel()
 local block, recipe = ModelBuilder.addRecipeIntoProductionBlock(model, model.block_root, "iron-plate", "orbit")
 Model.setFactory(recipe, "rocket-silo")
 ModelCompute.updateNow(model)
 local function open()
  Controller:send("on_gui_open", {name="OPEN",item1=model.id,item2=block.id,item3=recipe.id}, "HMRecipeEdition")
 end
 local function picker()
  return find_element(player.gui.screen.HMRecipeEdition, function(el)
   return el.name:find("silo-part-recipe-select", 1, true)
  end)
 end
 open()
 assert(not picker(), "fixed silos have no part recipe picker")
 click(find_element(player.gui.screen.HMRecipeEdition, function(el)
  return el.name:find("factory-select", 1, true) and el.tags.name == "test-selectable-silo"
 end), player)
 local dropdown = assert(picker(), "selectable silo has a part recipe picker")
 assert(dropdown.tags.recipes[dropdown.selected_index] == "rocket-part")
 local selected
 for index, name in ipairs(dropdown.tags.recipes) do
  if name == "test-copper-rocket-part" then selected = index end
 end
 dropdown.selected_index = assert(selected)
 EventController.onGuiClick{player_index=player.index, element=dropdown}
 assert(not Player.getLastError() and recipe.factory.rocket_part_recipe == "test-copper-rocket-part")
 assert(block.ingredients["copper-plate"].amount > 0 and not block.ingredients["processing-unit"])
 Controller:getView("HMRecipeEdition"):close()
 open()
 dropdown = picker()
 assert(dropdown.tags.recipes[dropdown.selected_index] == recipe.factory.rocket_part_recipe, "retain the selection on reopen")
 Controller:getView("HMRecipeEdition"):close()
 game.tick_paused = false
end

local function checkFusionControls(player)
 local model = Model.newModel()
 local block, reactor = ModelBuilder.addRecipeIntoProductionBlock(model, model.block_root, "fusion-reactor", "energy")
 local _, generator = ModelBuilder.addRecipeIntoProductionBlock(model, block, "fusion-generator", "energy")
 ModelCompute.updateNow(model)
 local function open(row)
  Controller:send("on_gui_open", {name="OPEN",item1=model.id,item2=block.id,item3=row.id}, "HMRecipeEdition")
 end
 local function field(action)
  return assert(find_element(player.gui.screen.HMRecipeEdition, function(el) return el.name:find(action, 1, true) end))
 end
 local function enter(action, text)
  local input = field(action)
  input.text = text
  EventController.onGuiClick{player_index=player.index, element=input}
  assert(not Player.getLastError(), "fusion editor update")
 end
 open(reactor)
 assert(field(FusionControl.neighbours).text == "0")
 enter(FusionControl.neighbours, "1")
 assert(reactor.factory.fusion_neighbours == 1)
 Controller:getView("HMRecipeEdition"):close()
 open(reactor)
 assert(field(FusionControl.neighbours).text == "1")
 Controller:getView("HMRecipeEdition"):close()
 open(generator)
 enter(FusionControl.inlet, "2000000")
 assert(generator.factory.fusion_inlet_temperature == 2e6)
 enter(FusionControl.inlet, "")
 assert(generator.factory.fusion_inlet_temperature == nil)
 Controller:getView("HMRecipeEdition"):close()
 game.tick_paused=false
end

local function checkReactorSettings(player)
 local model = Model.newModel()
 local block = model.block_root
 for _, name in ipairs({"heating-tower", "nuclear-reactor"}) do
  local _, recipe = ModelBuilder.addRecipeIntoProductionBlock(model, block, name, "energy")
  recipe.factory.neighbour_bonus = "∞"
  ModelCompute.update(model)
  Controller:send("on_gui_open", {name="OPEN",item1=model.id,item2=block.id,item3=recipe.id}, "HMRecipeEdition")
  assert(not find_element(player.gui.screen.HMRecipeEdition, function(el)
   return el.name:find("boiler-inlet-update", 1, true)
  end), "reactors have no boiler inlet temperature control")
  local dropdown = find_element(player.gui.screen.HMRecipeEdition, function(el)
   return el.name:find("neighbour-bonus-update", 1, true)
  end)
  if name == "heating-tower" then
   assert(not dropdown, "heating tower has no neighbour bonus to configure")
  else
   assert(dropdown and dropdown.selected_index == 5, "saved reactor layout is selected")
   local caption = dropdown.items[5]
   assert(helpers.table_to_json(caption[4]) == helpers.table_to_json(prototypes.entity[name].localised_name))
   dropdown.selected_index = 3
   EventController.onGuiClick{player_index=player.index, element=dropdown}
   assert(recipe.factory.neighbour_bonus == 4, "reactor selection preserves stored layout values")
  end
  Controller:getView("HMRecipeEdition"):close()
 end
 game.tick_paused = false
end

local function checkBoilerInlet(player)
 local model = Model.newModel()
 local block = model.block_root
 local _, recipe = ModelBuilder.addRecipeIntoProductionBlock(model, block, "water->steam#165", "boiler")
 ModelCompute.update(model)
 Controller:send("on_gui_open", {name="OPEN",item1=model.id,item2=block.id,item3=recipe.id}, "HMRecipeEdition")
 local function field()
  return assert(find_element(player.gui.screen.HMRecipeEdition, function(el)
   return el.name:find("boiler-inlet-update", 1, true)
  end), "boiler editor has an inlet temperature field")
 end
 local function enter(value)
  local element = field()
  element.text = value
  EventController.onGuiClick{player_index=player.index, element=element}
  assert(not Player.getLastError(), "boiler inlet edit failed")
 end
 assert(field().text == "", "a newly added boiler uses the automatic temperature")
 local status = find_element(player.gui.screen.HMRecipeEdition, function(el) return el.name == "boiler-inlet-status" end)
 assert(status and status.caption[1] == "helmod_label.boiler-inlet-auto" and tonumber(status.caption[2]) == 15)
 enter("57.5")
 assert(recipe.factory.boiler_inlet_temperature == 57.5 and field().text == "57.5", "confirm a mixed inlet temperature")
 enter("5000")
 assert(recipe.factory.boiler_inlet_temperature == 57.5, "an out-of-range temperature leaves the applied inlet alone")
 enter("")
 assert(recipe.factory.boiler_inlet_temperature == nil and field().text == "", "clearing the inlet restores automatic detection")
 Controller:getView("HMRecipeEdition"):close()
 game.tick_paused = false
end

local function inputFilter(panel)
 return assert(find_element(panel, function(el)
  return el.name:find(BlockHeader.action.ingredients, 1, true)
 end))
end

local function openInputs(player, sheet)
 ModelCompute.update(sheet)
 Controller:send("on_gui_open",{name="OPEN",item1=sheet.id,item2=sheet.block_root.id},"HMProductionPanel")
 local panel = player.gui.screen.HMProductionPanel
 assert(helpers.table_to_json(inputFilter(panel).tooltip):find(MatrixSupply.tooltip.filter, 1, true))
 if not User.getParameter(BlockHeader.setting.ingredients) then click(inputFilter(panel), player) end
 return panel
end

local function input(panel, name, quality)
 return assert(find_element(panel, function(el)
  return el.name:find(ConstraintView.action.ingredient, 1, true)
     and el.name:find("=" .. ConstraintView.noTarget .. "=", 1, true)
     and el.tags.name == name and el.tags.quality == quality
 end), "missing Input button for " .. name .. " (" .. quality .. ")")
end

local function clickInput(player, panel, material, control, shift)
 EventController.onGuiClickButton{player_index=player.index, element=input(panel, material, "normal"),
  button=defines.mouse_button_type.left, control=control, shift=shift}
 assert(not Player.getLastError(), "input header raised a GUI error")
end

local function marked(panel, material, quality)
 local plus = GuiElement.getSprite(defines.sprite_info.master)
 local icons = input(panel, material, quality).mask_infos
 return icons ~= nil and icons[plus] ~= nil
end

script.on_nth_tick(60, function(event)
 local player = game.players[1]
 if not player then return end
 Player.set(player)
 Controller:getViews()
 if not storage.orbit_ui_step then
  local model=Model.newModel()
  local block,recipe=ModelBuilder.addRecipeIntoProductionBlock(model,model.block_root,"automation-science-pack","orbit")
  ModelCompute.update(model)
  block.products["orbit/automation-science-pack#normal"].input=60
  ModelCompute.update(model)
  settings.global.helmod_incremental_percentages = {value=true}
  User.setParameterObjects("HMProductionPanel",model.id,block.id,recipe.id)
  Controller:send("on_gui_open",{name="OPEN",item1=model.id,item2=block.id},"HMProductionPanel")
  game.tick_paused=false
  storage.orbit_ui_step=1
  storage.orbit_ui_model=model.id
  storage.orbit_ui_block=block.id
 elseif storage.orbit_ui_step==1 then
  game.take_screenshot{player=player,resolution={1600,1000},show_gui=true,path="orbit-panel.png"}
  storage.orbit_ui_step=2
 elseif storage.orbit_ui_step==2 then
  click(find_element(player.gui.screen, function(element)
   return element.name:find("HMOrbitSelector", 1, true) and element.name:find("OPEN", 1, true)
  end), player)
  game.tick_paused=false
  storage.orbit_ui_step=3
 elseif storage.orbit_ui_step==3 then
  game.take_screenshot{player=player,resolution={1600,1000},show_gui=true,path="orbit-selector.png"}
  assert(player.gui.screen.HMOrbitSelector, "orbit selector exists")
  assert(not Player.getLastError(), "Helmod GUI error")
  local panel = Controller:getView("HMProductionPanel")
  local _, _, scroll = panel:getDataPanel()
  local list = assert(scroll["list-data"])
  local status = panel:getInfoPanel2().parent["block-heading"]["solver-status"]
  assert(status.visible and status.sprite == "utility/status_working")
  click(find_element(player.gui.screen.HMOrbitSelector, function(element)
   return element.name:find("element-select",1,true) and element.tags.name == "firearm-magazine"
  end), player)
  local model=storage.models[storage.orbit_ui_model]
  local found=false
  for _, recipe in pairs(model.block_root.children) do
   if recipe.name=="firearm-magazine" and recipe.type=="orbit" then found=true end
  end
  assert(found, "selector added orbital recipe")
  assert(list.valid and #list.children > list.column_count, "existing rows disappeared during selector refresh")
  assert(status.valid and status.sprite == "utility/status_yellow")
  Controller:getView("HMOrbitSelector"):close()
  storage.orbit_ui_step=4
 elseif storage.orbit_ui_step==4 then
  game.take_screenshot{player=player,resolution={1600,1000},show_gui=true,path="orbit-selected.png"}
  local panel = Controller:getView("HMProductionPanel")
  assert(panel:getInfoPanel2().parent["block-heading"]["solver-status"].sprite == "utility/status_working")
  settings.global.helmod_incremental_percentages = {value=false}
  for _, element in pairs(player.gui.screen.children) do
   local control=find_element(element, function(child)
    return child.name:find("HMRecipeEdition",1,true) and child.name:find("OPEN",1,true)
   end)
   if control then click(control,player) break end
  end
  storage.orbit_ui_step=5
 elseif storage.orbit_ui_step==5 then
  game.take_screenshot{player=player,resolution={1600,1000},show_gui=true,path="orbit-edition.png"}
  assert(not Player.getLastError(), "Helmod GUI error")
  assert(player.gui.screen.HMRecipeEdition, "recipe editor exists")
  local target=find_element(player.gui.screen.HMRecipeEdition, function(element) return element.name=="orbit-value=speed-required" end)
  assert(target and target.caption=="5.57 (+456.59%)", "target bonus uses normal silo base speed")
  click(find_element(player.gui.screen.HMRecipeEdition, function(element)
   return element.name:find("factory-quality-select",1,true) and element.name:find("legendary",1,true)
  end), player)
  click(find_element(player.gui.screen.HMRecipeEdition, function(element)
   return element.name:find("factory-module-select",1,true) and element.tags.name=="productivity-module-3"
  end), player)
  storage.orbit_ui_step=6
 elseif storage.orbit_ui_step==6 then
  game.take_screenshot{player=player,resolution={1600,1000},show_gui=true,path="orbit-configured.png"}
  local model=storage.models[storage.orbit_ui_model]
  local recipe=model.block_root.children.R1
  assert(recipe.factory.quality=="legendary", "quality click updates silo")
  assert(recipe.factory.effects.productivity>0, "module click updates silo")
  assert(not Player.getLastError(), "Helmod GUI error")
  assert(not find_element(player.gui.screen.HMRecipeEdition, function(element) return element.name=="orbit-launch-limit" end), "no success indicator below target")
  model.parameters.effects.speed=10
  ModelCompute.update(model)
  Controller:send("on_gui_update",{item1=model.id,item2=storage.orbit_ui_block,item3=recipe.id},"HMRecipeEdition")
  game.tick_paused=false
  storage.orbit_ui_step=7
 elseif storage.orbit_ui_step==7 then
  local success=find_element(player.gui.screen.HMRecipeEdition, function(element) return element.name=="orbit-launch-limit" end)
  assert(success and success.sprite=="utility/check_mark_green", "success indicator at launch limit")
  assert(success.tooltip[1]=="helmod_orbit.target-reached", "success explanation")
  local target=find_element(player.gui.screen.HMRecipeEdition, function(element) return element.name=="orbit-value=speed-required" end)
  assert(target and target.caption=="7.46 (+198.33%)", "target bonus uses legendary silo base speed")
  game.take_screenshot{player=player,resolution={1600,1000},show_gui=true,path="orbit-target-reached.png"}
  storage.orbit_ui_step=8
 elseif storage.orbit_ui_step==8 then
  local model=storage.models[storage.orbit_ui_model]
  model.parameters.effects.speed=0
  ModelCompute.update(model)
  Controller:send("on_gui_update",{item1=model.id,item2=storage.orbit_ui_block,item3="R1"},"HMRecipeEdition")
  game.tick_paused=false
  assert(not find_element(player.gui.screen.HMRecipeEdition, function(element) return element.name=="orbit-launch-limit" end), "success indicator clears below target")
  assert(not Player.getLastError(), "Helmod GUI error")
  Controller:getView("HMRecipeEdition"):close()
  local loop = recycling.buildLoop()
  local block = loop.block_root
  local panel = openInputs(player, loop)
  for _, selected in ipairs({true, false, true}) do
   clickInput(player, panel, "copper-plate", true, false)
   assert(marked(panel, "copper-plate", "normal") == selected)
   assert(not marked(panel, "copper-plate", "uncommon"))
   if selected then recycling.checkBalances(block) end
  end
  game.take_screenshot{player=player,resolution={1600,1000},show_gui=true,path="copper-external-supply.png"}
  storage.orbit_ui_step=9
 elseif storage.orbit_ui_step==9 then
  local loop = recycling.buildCircuitLoop()
  local block = loop.block_root
  local panel = openInputs(player, loop)
  clickInput(player, panel, "iron-plate", true, false)
  assert(not marked(panel, "copper-cable", "normal"))
  clickInput(player, panel, "copper-cable", true, false)
  clickInput(player, panel, "iron-plate", false, true)
  assert(marked(panel, "iron-plate", "normal"), "Shift-click cleared a supply")
  clickInput(player, panel, "iron-plate", true, true)
  assert(marked(panel, "iron-plate", "normal"), "Ctrl+Shift-click cleared a supply")
  recycling.checkCircuitBalances(block)
  clickInput(player, panel, "iron-plate", true, false)
  assert(not marked(panel, "iron-plate", "normal") and marked(panel, "copper-cable", "normal"))
  clickInput(player, panel, "iron-plate", true, false)
  click(inputFilter(panel), player)
  assert(not User.getParameter(BlockHeader.setting.ingredients))
  assert(marked(panel, "iron-plate", "normal") and marked(panel, "copper-cable", "normal"))
  recycling.checkCircuitBalances(block)
  game.take_screenshot{player=player,resolution={2200,1100},show_gui=true,path="circuit-external-supplies.png"}
  checkFusionControls(player)
  checkReactorSettings(player)
  checkBoilerInlet(player)
  checkSiloPartPicker(player)
  log("ORBIT UI SMOKE PASSED")
  storage.orbit_ui_step=10
 end
end)
