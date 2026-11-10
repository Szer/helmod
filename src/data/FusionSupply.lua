local FusionSupply = {}

---@class PlasmaSource
---@field child RecipeData|BlockData
---@field product ProductData
---@field temperature number

---@class PlasmaOutput
---@field sources PlasmaSource[]
---@field temperatures table<number,boolean>

---Track the temperature carried by an existing fluid output without changing its material key.
---@param block BlockData
---@param keys table<string,boolean>
---@return table<string,PlasmaOutput>
function FusionSupply.collect(block, keys)
    local outputs = {}
    if not next(keys) then return outputs end
    for key in pairs(keys) do outputs[key] = {sources={}, temperatures={}} end
    for _, child in pairs(block.children) do
        local products = child.products
        if child.class ~= "Block" then products = RecipePrototype(child):getQualityProducts(child.factory, child.quality) end
        for _, product in pairs(products) do
            local output = outputs[product.name]
            if output and product.type == "fluid" and Product(product):getTableKey() == product.name then
                local temperature = product.fusion_temperature or Player.getFluidPrototype(product.name).default_temperature
                output.temperatures[temperature] = true
                table.insert(output.sources, {child=child, product=product, temperature=temperature})
            end
        end
    end
    return outputs
end

---@param block BlockData
---@param outputs table<string,PlasmaOutput>
function FusionSupply.publish(block, outputs)
    for key, output in pairs(outputs) do
        local volume, heat = 0, 0
        for _, source in ipairs(output.sources) do
            local child = source.child
            if child.count and child.count > 0 then
                local amount
                if child.class == "Block" then amount = source.product.amount * child.count
                else amount = Product(source.product):countProduct(child) end
                volume = volume + amount
                heat = heat + amount * source.temperature
            end
        end
        if volume > 0 then block.products[key].fusion_temperature = heat / volume end
    end
end

return FusionSupply
