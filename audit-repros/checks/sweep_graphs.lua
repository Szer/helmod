script.on_init(function()
 EventController.onInit()
 Player.set{name='Audit',index=1,force=game.forces.player,mod_settings=settings.global,admin=true,print=function() end}
 local count,failed=0,0
 local chains={
  {'automation-science-pack','copper-cable','iron-gear-wheel','iron-plate','copper-plate'},
  {'processing-unit','advanced-circuit','electronic-circuit','copper-cable','plastic-bar','sulfuric-acid','sulfur','advanced-oil-processing','heavy-oil-cracking','light-oil-cracking'},
  {'rocket-part','rocket-fuel','low-density-structure','processing-unit'},
  {'iron-ore','iron-ore-recycling','iron-gear-wheel','iron-gear-wheel-recycling'},
  {'bioflux','yumako-processing','jellynut-processing','nutrients-from-bioflux'},
  {'ammonia-rocket-fuel','ammoniacal-solution-separation','ice-melting'}
 }
 for ci,names in ipairs(chains) do
  for _,nested in pairs({false,true}) do
   for _,solver_name in pairs({defines.constant.solvers.default,defines.constant.solvers.matrix}) do
    for _,simplex in pairs({false,true}) do
     for _,by_product in pairs({false,true}) do
      local ok,err=xpcall(function()
       local model=Model.newModel()
       User.setParameter('solver_selected',solver_name)
       local block=model.block_root
       if nested then
        block=Model.newBlock(model,{name='iron-gear-wheel',type='recipe'})
        model.blocks[block.id]=block;model.block_root.children[block.id]=block
       end
       block.solver=simplex;block.by_product=by_product
       for _,name in ipairs(names) do if prototypes.recipe[name] then ModelBuilder.addRecipeIntoProductionBlock(model,block,name,'recipe') end end
       ModelBuilder.rebuildParentBlockOfModel(model)
       ModelCompute.update(model)
       local copy=Model.newModel()
       local exported=Converter.write(model)
       ModelBuilder.copyModel(copy,Converter.read(exported))
       ModelBuilder.rebuildParentBlockOfModel(copy)
       ModelCompute.update(copy)
       for _,child in pairs(copy.block_root.children) do
        ModelBuilder.blockChildRemove(copy,copy.block_root,child)
        ModelCompute.update(copy)
        break
       end
       storage.models[model.id]=nil;storage.models[copy.id]=nil
      end,debug.traceback)
      count=count+1
      if not ok then failed=failed+1;log('AUDIT GRAPH FAILURE chain='..ci..' nested='..tostring(nested)..' solver='..tostring(solver_name)..' simplex='..tostring(simplex)..' by_product='..tostring(by_product)..'\n'..tostring(err)) end
     end
    end
   end
  end
 end
 log('AUDIT GRAPHS COMPLETE cases='..count..' failures='..failed)
end)
