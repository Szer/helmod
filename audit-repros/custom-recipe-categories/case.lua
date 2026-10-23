local function find(parent, text)
 if parent.name:find(text,1,true) then return parent end
 for _,child in pairs(parent.children) do local result=find(child,text) if result then return result end end
end
local function click(player, text)
 local e=assert(find(player.gui.screen,text),text)
 EventController.onGuiClickButton{player_index=player.index,element=e,button=defines.mouse_button_type.left}
 game.tick_paused=false
end
local function choose(player, text, value)
 local e=assert(find(player.gui.screen,text),text)
 e.elem_value=value
 EventController.onGuiClick{player_index=player.index,element=e}
 game.tick_paused=false
end
return {
 verify=function(player)
  Controller:getView("HMBugReportPanel"):close()
  Controller:getView("HMRecipeCustomization"):close()
  click(player,"HMRecipeCustomization=OPEN")
  if not Player.getLastError() then click(player,"HMRecipeCustomization=recipe-select") end
  assert(Player.getLastError(),"expected persisted custom recipe failure")
  log("AUDIT RELOAD VERIFIED "..Player.getLastError())
 end,
 setup=function(player)
  Player.set(player)
  Controller:getViews()
  local model=Model.newModel()
  ModelCompute.update(model)
  User.setParameterObjects('HMProductionPanel',model.id,model.block_root.id)
  Controller:send('on_gui_open',{name='OPEN',item1=model.id,item2=model.block_root.id},'HMProductionPanel')
  click(player,'HMRecipeCustomization=OPEN')
  choose(player,'HMRecipeCustomization=element-add=products=item',{name='iron-gear-wheel',quality='normal'})
  assert(not Player.getLastError(),'setup error')
 end,
 trigger=function(player)
  click(player,'HMRecipeCustomization=recipe-save')
 end
}
