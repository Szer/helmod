local Case = require 'audit_case'
local started = false
script.on_init(function()
  EventController.onInit()
  if remote.interfaces.freeplay then
    remote.call('freeplay','set_skip_intro',true)
    remote.call('freeplay','set_disable_crashsite',true)
  end
end)
script.on_nth_tick(60,function()
  local player=game.players[1]
  if not player then return end
  Player.set(player)
  Controller:getViews()
  local ok,err=xpcall(function()
    if not started then
      started=true
      if storage.audit_phase==7 then
        if Case.verify then Player.getStorageDebug()[player.index]=nil;Case.verify(player) end
        storage.audit_phase=8
      end
      if storage.audit_phase==2 and Case.reload then storage.audit_phase=3 end
    end
    local phase=storage.audit_phase or 0
    if phase==0 then
      Player.getStorageDebug()[player.index]=nil
      Case.setup(player)
      storage.audit_phase=1
      game.take_screenshot{player=player,resolution={1600,1000},show_gui=true,path='audit-before.png'}
      log('AUDIT SETUP OK')
    elseif phase==1 then
      storage.audit_phase=2
      game.auto_save('audit-repro')
      log('AUDIT SAVE READY')
    elseif phase==2 then
      if not Case.reload then storage.audit_phase=3 end
    elseif phase==3 then
      Case.trigger(player)
      log('AUDIT ERROR '..tostring(Player.getLastError()))
      storage.audit_phase=4
    elseif phase==8 then
      storage.audit_phase=4
    elseif phase==4 then
      Controller:send('on_gui_open',{name='OPEN'},'HMBugReportPanel')
      local function expand(e)
        if e.name=='bug_repport' then e.style.height=600;e.style.width=1000;e.select(1,1) end
        for _,c in pairs(e.children) do expand(c) end
      end
      expand(player.gui.screen.HMBugReportPanel)
      player.gui.screen.HMBugReportPanel.location={x=40,y=40}
      storage.audit_phase=5
    elseif phase==5 then
      game.take_screenshot{player=player,resolution={1600,1000},show_gui=true,path='audit-error.png'}
      storage.audit_phase=6
      log('AUDIT SCREENSHOT READY')
    elseif phase==6 then
      storage.audit_phase=7
      game.auto_save('audit-after')
      log('AUDIT COMPLETE')
    end
    game.tick_paused=false
  end,debug.traceback)
  if not ok then log('AUDIT HARNESS FAILURE '..err);script.on_nth_tick(60,nil) end
end)
