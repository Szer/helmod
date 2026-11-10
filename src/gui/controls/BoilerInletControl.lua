local BoilerInletControl = {action = "boiler-inlet-update"}

BoilerInletControl.caption = {
    inlet = "helmod_label.boiler-inlet",
    automatic = "helmod_label.boiler-inlet-auto",
}

---@class BoilerInletEdit
---@field action "boiler-inlet-update"
---@field model_id string
---@field block_id string
---@field recipe_id string

---@param edit BoilerInletEdit
---@return string action, string model_id, string block_id, string recipe_id
function BoilerInletControl.buttonArgs(edit)
    return edit.action, edit.model_id, edit.block_id, edit.recipe_id
end

---@param event {action?:string,item1?:string,item2?:string,item3?:string}
---@return BoilerInletEdit?
function BoilerInletControl.decode(event)
    if event.action == BoilerInletControl.action and event.item1 and event.item2 and event.item3 then
        return {action=BoilerInletControl.action, model_id=event.item1, block_id=event.item2, recipe_id=event.item3}
    end
end

---@param text string
---@param minimum number Inclusive inlet limit in °C.
---@param maximum number Inclusive inlet limit in °C.
---@param target number Outlet temperature in °C.
---@return boolean valid, number? temperature Empty text selects automatic detection.
function BoilerInletControl.parse(text, minimum, maximum, target)
    if text == "" then return true, nil end
    local temperature = tonumber(text)
    if temperature and temperature >= minimum and temperature <= maximum and temperature < target then
        return true, temperature
    end
    return false, nil
end

return BoilerInletControl
