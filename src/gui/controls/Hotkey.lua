---@enum HelmodHotkey
local Hotkey = {
    close = "helmod-close",
    openClose = "helmod-open-close",
    productionLine = "helmod-production-line-open",
    recipeSelector = "helmod-recipe-selector-open",
    recipeExplorer = "helmod-recipe-explorer-open",
    richText = "helmod-richtext-open",
    createOrWhereUsed = "helmod-create-or-where-used-open",
}

---@class HelmodHotkeyEvent
---@field input_name HelmodHotkey
---@field player_index integer

return Hotkey
