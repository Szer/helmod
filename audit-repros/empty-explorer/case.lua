local function find(parent,text)
 if parent.name:find(text,1,true) then return parent end
 for _,child in pairs(parent.children) do local result=find(child,text) if result then return result end end
end
local function click(player,text)
 EventController.onGuiClickButton{player_index=player.index,element=assert(find(player.gui.screen,text),text),button=defines.mouse_button_type.left}
 game.tick_paused=false
end
return {
 setup=function(player)
  Player.set(player)
  Controller:getViews()
  local model=Model.newModel()
  ModelCompute.update(model)
  User.setParameterObjects('HMProductionPanel',model.id,model.block_root.id)
  Controller:send('on_gui_open',{name='OPEN',item1=model.id,item2=model.block_root.id},'HMProductionPanel')
  click(player,'HMRecipeExplorer=OPEN')
  assert(not Player.getLastError(),'setup error')
 end,
 trigger=function(player) click(player,'HMRecipeExplorer=generate-block') end
}
