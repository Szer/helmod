script.on_init(function()
 EventController.onInit()
 Player.set{name='Audit',index=1,force=game.forces.player,mod_settings=settings.global,admin=true,print=function() end}
 local count,failed=0,0
 local function check(name,kind)
  local model,stage
  local ok,err=xpcall(function()
   model=Model.newModel()
   stage='default'
   local block,recipe=ModelBuilder.addRecipeIntoProductionBlock(model,model.block_root,name,kind)
   assert(recipe,'recipe not added')
   ModelCompute.update(model);count=count+1
   local proto=RecipePrototype(name,kind)
   if proto:isSupportFactory() then
    for _,factory in pairs(proto:getAllowedMachines()) do
     if factory.type~='character' then
      for _,quality in pairs({'normal','legendary'}) do
       stage=factory.name..'/'..quality
       Model.setFactory(recipe,factory.name,quality)
       ModelCompute.update(model);count=count+1
       for _,module in pairs({'speed-module-3','productivity-module-3','quality-module-3'}) do
        stage=factory.name..'/'..quality..'/'..module
        ModelBuilder.setFactoryModulePriority(recipe,{})
        ModelBuilder.addFactoryModule(recipe,module,quality,true)
        ModelCompute.update(model);count=count+1
       end
       ModelBuilder.setFactoryModulePriority(recipe,{})
      end
     end
    end
   end
   for _,by_product in pairs({true,false}) do
    for _,solver in pairs({false,true}) do
     block.by_product=by_product; block.solver=solver
     stage='solver '..tostring(solver)..' by_product '..tostring(by_product)
     ModelCompute.update(model);count=count+1
    end
   end
  end,debug.traceback)
  if not ok then failed=failed+1; log('AUDIT VARIANT FAILURE '..kind..' '..name..' '..tostring(stage)..'\n'..tostring(err)) end
  if model then storage.models[model.id]=nil end
 end
 local sets={recipe=Player.getRecipes(),technology=Player.getTechnologies(),resource=Player.getResourceRecipes(),fluid=Player.getFluidRecipes(),boiler=Player.getBoilerRecipes(),rocket=Player.getRocketRecipes(),energy=Player.getEnergyMachines(),agricultural=Player.getAgriculturalRecipes(),spoiling=Player.getSpoilableRecipes()}
 for kind,list in pairs(sets) do for _,recipe in pairs(list) do check(recipe.name,kind) end end
 log('AUDIT VARIANTS COMPLETE computations='..count..' failures='..failed)
end)
