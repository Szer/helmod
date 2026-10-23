local function find(parent,text)
 if parent.name:find(text,1,true) then return parent end
 for _,child in pairs(parent.children) do local result=find(child,text) if result then return result end end
end
return {
 setup=function(player)
  local model=Model.newModel()
  ModelCompute.update(model)
  User.setParameterObjects('HMProductionPanel',model.id,model.block_root.id)
  Controller:send('on_gui_open',{name='OPEN',item1=model.id,item2=model.block_root.id},'HMProductionPanel')
  local button=assert(find(player.gui.screen,'HMDownload=OPEN='..model.id..'=download'))
  EventController.onGuiClickButton{player_index=player.index,element=button,button=defines.mouse_button_type.left}
  assert(find(player.gui.screen.HMDownload,'data-text')).text='do local'
  assert(not Player.getLastError(),'setup error')
 end,
 trigger=function(player)
  local button=assert(find(player.gui.screen.HMDownload,'HMDownload=download-model'))
  EventController.onGuiClickButton{player_index=player.index,element=button,button=defines.mouse_button_type.left}
 end
}
