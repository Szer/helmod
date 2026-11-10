local FusionControl = {neighbours="fusion-neighbours-update", inlet="fusion-inlet-update"}

FusionControl.element = {
    neighboursLabel = "label-fusion-neighbours",
    neighboursRow = "fusion-neighbours",
    plasmaTemperature = "fusion-plasma-temperature",
    inletLabel = "label-fusion-inlet",
    inletRow = "fusion-inlet",
    inletStatus = "fusion-inlet-status",
}
FusionControl.caption = {
    neighbours = "helmod_label.fusion-neighbours",
    plasmaTemperature = "helmod_label.fusion-temperature",
    ratedOutput = "helmod_label.fusion-inlet-nominal",
    ambiguousInlet = "helmod_label.fusion-inlet-ambiguous",
    invalidInlet = "helmod_label.fusion-inlet-invalid",
}
FusionControl.tooltip = {
    neighbours = "tooltip.fusion-neighbours",
    inlet = "tooltip.fusion-inlet",
}

---@class FusionNeighboursEdit
---@field action "fusion-neighbours-update"
---@field model_id string
---@field block_id string
---@field recipe_id string

---@class FusionInletEdit
---@field action "fusion-inlet-update"
---@field model_id string
---@field block_id string
---@field recipe_id string

---@alias FusionEdit FusionNeighboursEdit|FusionInletEdit

---@param edit FusionEdit
---@return string action, string model_id, string block_id, string recipe_id
function FusionControl.buttonArgs(edit)
    return edit.action, edit.model_id, edit.block_id, edit.recipe_id
end

---@param event {action?:string,item1?:string,item2?:string,item3?:string}
---@return FusionEdit?
function FusionControl.decode(event)
    if not event.item1 or not event.item2 or not event.item3 then return end
    if event.action == FusionControl.neighbours or event.action == FusionControl.inlet then
        return {action=event.action, model_id=event.item1, block_id=event.item2, recipe_id=event.item3}
    end
end

---@param text string
---@param minimum number
---@param maximum number
---@return boolean valid, number? value Empty text restores the default.
function FusionControl.parse(text, minimum, maximum)
    if text == "" then return true, nil end
    local value = tonumber(text)
    if value and value >= minimum and value <= maximum and value < math.huge then return true, value end
    return false, nil
end

return FusionControl
