script.on_init(function()
 EventController.onInit()
 Player.set{name="Audit",index=1,force=game.forces.player,mod_settings=settings.global,admin=true,print=function(message) end}
 local count,failed=0,0
 local function check(name,kind)
  local model
  local ok,err=xpcall(function()
   model=Model.newModel()
   local block,recipe=ModelBuilder.addRecipeIntoProductionBlock(model,model.block_root,name,kind)
   ModelCompute.update(model)
  end,debug.traceback)
  count=count+1
  if not ok then failed=failed+1; log("AUDIT FAILURE "..kind.." "..name.."\n"..tostring(err)) end
  if model then storage.models[model.id]=nil end
 end
 for name in pairs(prototypes.recipe) do check(name,"recipe") end
 for name in pairs(prototypes.technology) do check(name,"technology") end
 for name,entity in pairs(prototypes.get_entity_filtered{{filter="type",type="resource"}}) do check(name,"resource") end
 log("AUDIT SWEEP COMPLETE count="..count.." failed="..failed)
end)
