local SiloPartControl = {action="silo-part-recipe-select"}

---@class SiloPartPicker
---@field action "silo-part-recipe-select"
---@field model_id string
---@field block_id string
---@field recipe_id string
---@field silo string

---@param picker SiloPartPicker
---@return string, string, string, string, string
function SiloPartControl.buttonArgs(picker)
    return picker.action, picker.model_id, picker.block_id, picker.recipe_id, picker.silo
end

---@param event {action?:string,item1?:string,item2?:string,item3?:string,item4?:string}
---@return SiloPartPicker?
function SiloPartControl.decode(event)
    if event.action == SiloPartControl.action and event.item1 and event.item2 and event.item3 and event.item4 then
        return {action=SiloPartControl.action, model_id=event.item1, block_id=event.item2, recipe_id=event.item3, silo=event.item4}
    end
end

return SiloPartControl
