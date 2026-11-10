local OffshoreFluids = {}

---@class OffshoreFluidSource
---@field pumps table<string, boolean>
---@field hidden boolean

---@param sources table<string, OffshoreFluidSource>
---@param fluid string
---@param pump string
---@param hidden boolean
local function add(sources, fluid, pump, hidden)
    local source = sources[fluid]
    if source == nil then
        source = {pumps={}, hidden=true}
        sources[fluid] = source
    end
    source.pumps[pump] = true
    if not hidden then source.hidden = false end
end

---@param tiles table<string, {fluid?: {name:string}, hidden:boolean}>
---@param pumps table<string, {fluidbox_prototypes: {filter?: {name:string}}[], hidden:boolean}>
---@return table<string, OffshoreFluidSource>
function OffshoreFluids.index(tiles, pumps)
    local tile_fluids = {}
    for _, tile in pairs(tiles) do
        if tile.fluid then
            local name = tile.fluid.name
            tile_fluids[name] = tile_fluids[name] == true or not tile.hidden
        end
    end

    local sources = {}
    for name, pump in pairs(pumps) do
        local filter = pump.fluidbox_prototypes[1].filter
        if filter then
            add(sources, filter.name, name, pump.hidden)
        else
            for fluid, visible in pairs(tile_fluids) do
                add(sources, fluid, name, pump.hidden or not visible)
            end
        end
    end
    return sources
end

return OffshoreFluids
