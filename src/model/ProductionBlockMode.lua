local ProductionBlockMode = {}

---@enum ProductionBlockModeOption
ProductionBlockMode.option = {
    consumer = "consumer",
    input = "by_product",
}

---@param block BlockData
---@param option ProductionBlockModeOption
function ProductionBlockMode.toggle(block, option)
    local enabled
    if option == ProductionBlockMode.option.consumer then
        enabled = not block.consumer
    else
        enabled = block.by_product == false
    end
    ModelBuilder.updateProductionBlockOption(block, option, enabled)
end

return ProductionBlockMode
