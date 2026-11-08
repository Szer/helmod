local function addBlock(model, parent, firstRecipe)
    local block = Model.newBlock(model, {name=firstRecipe, type="recipe"})
    block.parent_id, block.index = parent.id, table_size(parent.children)
    parent.children[block.id], model.blocks[block.id] = block, block
    ModelBuilder.addRecipeIntoProductionBlock(model, block, firstRecipe, "recipe")
    return block
end

return function()
    local model = Model.newModel()
    local root = model.block_root
    local science = addBlock(model, root, "utility-science-pack")
    local frames = addBlock(model, science, "flying-robot-frame")
    local _, circuits = ModelBuilder.addRecipeIntoProductionBlock(model, frames, "electronic-circuit", "recipe")
    science.products_linked = {["electronic-circuit"]=true}
    frames.products_linked = {["electronic-circuit"]=true}
    ModelCompute.update(model)
    for _, demand in ipairs({{60,0}, {60,5}, {0,5}, {30,2}, {60,5}}) do
        local packs, extra = demand[1], demand[2]
        root.products["utility-science-pack"].input = packs
        root.products["electronic-circuit"].input = extra
        ModelCompute.update(model)
        assert(math.abs(root.products["utility-science-pack"].amount - packs) < 1e-8)
        assert(math.abs(root.products["electronic-circuit"].amount - extra) < 1e-8, "nested circuit export")
        assert(math.abs(frames.products["electronic-circuit"].amount * frames.count_deep - extra) < 1e-8)
        local gross = packs + extra
        assert(math.abs(circuits.count_deep - gross) < 1e-8, "nested circuit production")
        assert(math.abs(root.ingredients["copper-cable"].amount - 3 * gross) < 1e-8)
    end
    -- Both blocks have the same display name and can export the same product.
    local sibling = addBlock(model, root, "utility-science-pack")
    local _, other = ModelBuilder.addRecipeIntoProductionBlock(model, sibling, "electronic-circuit", "recipe")
    sibling.products_linked = {["electronic-circuit"]=true}
    ModelCompute.update(model)
    assert(math.abs(root.products["electronic-circuit"].amount - 5) < 1e-8)
    assert(math.abs(circuits.count_deep + other.count_deep - 65) < 1e-8, "each profile belongs to its own block")

    local _, uncommon = ModelBuilder.addRecipeIntoProductionBlock(model, frames, "electronic-circuit", "recipe")
    uncommon.quality = "uncommon"
    local key = "electronic-circuit#uncommon"
    frames.products_linked[key], science.products_linked[key] = true, true
    ModelCompute.update(model)
    frames.products["flying-robot-frame"].input = 1
    science.products["utility-science-pack"].input = 3
    root.products[key].input = 7
    ModelCompute.update(model)
    assert(math.abs(root.products[key].amount - 7) < 1e-8 and math.abs(uncommon.count_deep - 7) < 1e-8)
    assert(math.abs(root.products["electronic-circuit"].amount - 5) < 1e-8)
end
