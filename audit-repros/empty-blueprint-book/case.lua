local function find(parent,text)
 if parent.name:find(text,1,true) then return parent end
 for _,child in pairs(parent.children) do local result=find(child,text) if result then return result end end
end
local function click(player,text)
 EventController.onGuiClickButton{player_index=player.index,element=assert(find(player.gui.screen,text),text),button=defines.mouse_button_type.left}
end
return {
 setup=function(player)
  local model=Model.newModel()
  ModelCompute.update(model)
  User.setParameterObjects('HMProductionPanel',model.id,model.block_root.id)
  Controller:send('on_gui_open',{name='OPEN',item1=model.id,item2=model.block_root.id},'HMProductionPanel')
  click(player,'HMAdminPanel=OPEN')
  local tab=assert(find(player.gui.screen,'HMAdminPanel=change-tab'))
  for i,entry in pairs(tab.tabs) do if entry.tab.name=='conversion-tab-panel' then tab.selected_tab_index=i end end
  EventController.onGuiClick{player_index=player.index,element=tab}
  player.clear_cursor()
  player.cursor_stack.set_stack{name='blueprint-book',count=1}
  local encoded=player.cursor_stack.export_stack()
  helpers.write_file('empty-book.txt',encoded)
  assert(find(player.gui.screen.HMAdminPanel,'encoded-text')).parent['encoded-text'].text=encoded
  assert(not Player.getLastError(),'setup error')
 end,
 trigger=function(player) click(player,'HMAdminPanel=string-decode') end
}
