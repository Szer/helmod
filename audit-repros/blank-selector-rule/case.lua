local function find(parent,text)
 if parent.name:find(text,1,true) then return parent end
 for _,child in pairs(parent.children) do local result=find(child,text) if result then return result end end
end
local function click(player,text)
 EventController.onGuiClickButton{player_index=player.index,element=assert(find(player.gui.screen,text),text),button=defines.mouse_button_type.left}
 game.tick_paused=false
end
local function select(player,text,value)
 local control=assert(find(player.gui.screen,text),text)
 for index,item in pairs(control.items) do if item==value then control.selected_index=index end end
 EventController.onGuiClick{player_index=player.index,element=control}
 game.tick_paused=false
end
return {
 verify=function(player)
  Controller:getView("HMBugReportPanel"):close()
  Controller:getView("HMRecipeSelector"):close()
  click(player,"HMRecipeSelector=OPEN")
 end,
 setup=function(player)
  Player.set(player)
  Controller:getViews()
  local model=Model.newModel()
  ModelCompute.update(model)
  User.setParameterObjects('HMProductionPanel',model.id,model.block_root.id)
  Controller:send('on_gui_open',{name='OPEN',item1=model.id,item2=model.block_root.id},'HMProductionPanel')
  click(player,'HMAdminPanel=OPEN')
  local tab=assert(find(player.gui.screen,'HMAdminPanel=change-tab'))
  tab.selected_tab_index=2
  EventController.onGuiClick{player_index=player.index,element=tab}
  click(player,'HMRuleEdition=OPEN')
  select(player,'HMRuleEdition=dropdown=mod','base')
  select(player,'HMRuleEdition=dropdown=name','selector-filter')
  assert(not Player.getLastError(),'setup error')
 end,
 trigger=function(player)
  click(player,'HMRuleEdition=save')
  Controller:getView('HMAdminPanel'):close()
  click(player,'HMRecipeSelector=OPEN')
 end
}
