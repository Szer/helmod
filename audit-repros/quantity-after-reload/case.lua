local function find(parent,text,kind)
 if parent.name:find(text,1,true) and (not kind or parent.type==kind) then return parent end
 for _,child in pairs(parent.children) do local result=find(child,text,kind) if result then return result end end
end
local function click(player,text)
 EventController.onGuiClickButton{player_index=player.index,element=assert(find(player.gui.screen,text,'button') or find(player.gui.screen,text),text),button=defines.mouse_button_type.left}
 game.tick_paused=false
end
return {
 reload=true,
 setup=function(player)
  Player.set(player)
  Controller:getViews()
  local model=Model.newModel()
  local block,recipe=ModelBuilder.addRecipeIntoProductionBlock(model,model.block_root,'iron-gear-wheel','recipe')
  ModelCompute.update(model)
  User.setParameterObjects('HMProductionPanel',model.id,block.id,recipe.id)
  Controller:send('on_gui_open',{name='OPEN',item1=model.id,item2=block.id},'HMProductionPanel')
  click(player,'HMProductionPanel=product-edition')
  assert(player.gui.screen.HMProductEdition,'quantity dialog opened')
  assert(not Player.getLastError(),'setup error')
 end,
 trigger=function(player)
  Player.set(player)
  Controller:getViews()
  local input=assert(find(player.gui.screen.HMProductEdition,'HMProductEdition=product-update','textfield'))
  input.text='10'
  EventController.onGuiClick{player_index=player.index,element=input}
  game.tick_paused=false
 end
}
