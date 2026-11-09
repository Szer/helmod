local MatrixSupply = {action = "matrix-external-supply"}

---@class MatrixSupplyEdit
---@field action "matrix-external-supply"
---@field model_id string
---@field block_id string
---@field material string

---@param edit MatrixSupplyEdit
---@return string, string, string, string
function MatrixSupply.buttonArgs(edit)
    return edit.action, edit.model_id, edit.block_id, edit.material
end

---@param event {action?:string,item1?:string,item2?:string,item3?:string}
---@return MatrixSupplyEdit?
function MatrixSupply.decode(event)
    if event.action == MatrixSupply.action and event.item1 and event.item2 and event.item3 then
        return {action=MatrixSupply.action, model_id=event.item1, block_id=event.item2, material=event.item3}
    end
end

---@param block {solver?:boolean, by_product?:boolean, by_factory?:boolean}
---@return boolean
function MatrixSupply.available(block)
    return block.solver == true and block.by_product ~= false and block.by_factory ~= true
end

return MatrixSupply
