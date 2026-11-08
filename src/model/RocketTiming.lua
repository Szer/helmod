local Launch = require "model.launch.Launch"
local RocketTiming = {}

local function configuration(silo, quality)
  local mod_data = prototypes.mod_data["helmod-rocket-timing"]
  if mod_data == nil then
    return nil
  end
  local animation = mod_data.data[silo.name]
  if animation == nil or animation.front_arm_duration == nil or animation.back_arm_duration == nil
    or animation.back_arm_retract_duration == nil or animation.times_to_blink == nil
    or animation.back_arm_frames == nil or animation.back_arm_speed == nil then
    return nil
  end
  local rocket = prototypes.entity[animation.rocket_entity]
  if rocket == nil then
    return nil
  end
  local level = 0
  if type(quality) == "number" then
    level = quality
  elseif type(quality) == "string" then
    level = prototypes.quality[quality].level
  elseif type(quality) == "table" or type(quality) == "userdata" then
    level = quality.level
  end
  return Launch.stages(silo, rocket, animation, level)
end

---@param silo LuaEntityPrototype
---@param quality string|number|LuaQualityPrototype
---@return number?
function RocketTiming.getLaunchTicks(silo, quality)
  local stages = configuration(silo, quality)
  if stages == nil then
    return nil
  end
  return stages.fast_preparation + stages.launch
end

---@param silo LuaEntityPrototype
---@param quality string|number|LuaQualityPrototype
---@param craft_ticks number
---@return number?
function RocketTiming.getCycleTicks(silo, quality, craft_ticks)
  local stages = configuration(silo, quality)
  if stages == nil then
    return nil
  end
  return Launch.cycle(silo, stages, craft_ticks)
end

return RocketTiming
