---@alias ReactorLayout 1|2|4|8|"∞"

local ReactorNeighbour = {action="neighbour-bonus-update"}

---@type ReactorLayout[]
ReactorNeighbour.layouts = {1, 2, 4, 8, "∞"}

---@param prototype {type:string, neighbour_bonus?:number}?
---@return boolean
function ReactorNeighbour.available(prototype)
    return prototype ~= nil and prototype.type == "reactor" and (prototype.neighbour_bonus or 0) > 0
end

return ReactorNeighbour
