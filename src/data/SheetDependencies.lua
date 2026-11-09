local Dependencies = {}

---@class SheetEnvironment
---@field time number
---@field parameters ParametersData
---@field force uint
---@field solver string?
---@field one boolean?
---@field mining number
---@field lab number
---@field lab_productivity number
---@field day number[]
---@field debug boolean

---@class RecipeDependency
---@field productivity number
---@field technology? number[]
---@field custom? table

---@class BlockDependencies
---@field blocks table<string,BlockDependencies>
---@field recipes table<string,RecipeDependency>

---@class SheetContext
---@field blocks table<string,BlockDependencies>
---@field environment SheetEnvironment
---@field dependencies table<string,RecipeDependency>
---@field freshBlocks table<string,boolean>
---@field freshRecipes table<string,boolean>

-- Track force bonuses and mutable recipe definitions per dependency subtree.
---@param model ModelData
---@param scope BlockData
---@return SheetContext
function Dependencies.capture(model, scope)
    local force = Player.getForce()
    ---@type SheetContext
    local ctx = {
        environment={
            time=model.time, parameters=model.parameters, force=force.index,
            solver=User.getParameter("solver_selected"), one=User.getPreferenceSetting("one_block_factor_enable"),
            mining=force.mining_drill_productivity_bonus, lab=force.laboratory_speed_modifier,
            lab_productivity=force.laboratory_productivity_bonus, day={Player.getGameDay()},
            debug=User.getModGlobalSetting("debug_solver"),
        },
        dependencies={}, blocks={}, freshBlocks={}, freshRecipes={},
    }
    local custom = Player.getCustomizedRecipes()
    local function visit(block)
        local deps = {blocks={}, recipes={}}
        ctx.blocks[block.id] = deps
        for _, child in pairs(block.children) do
            if Model.isBlock(child) then
                deps.blocks[child.id] = visit(child)
                if ctx.freshBlocks[child.id] then ctx.freshBlocks[block.id] = true end
            else
                local key = ModelCompute.productivityRecipe(child)
                local dependency = {productivity=Player.getRecipeProductivityBonus(key), custom=custom[child.name]}
                ctx.dependencies[child.id] = dependency
                deps.recipes[child.id] = dependency
                if child.type == "technology" then
                    local tech = force.technologies[child.name]
                    if tech then dependency.technology = {tech.level, tech.research_unit_count} end
                elseif (child.type ~= "recipe" or not prototypes.recipe[child.name] or custom[child.name])
                    and child.type ~= "fluid" and child.type ~= "boiler" then
                    ctx.freshBlocks[block.id] = true
                    ctx.freshRecipes[child.id] = true
                end
            end
        end
        return deps
    end
    visit(scope)
    return ctx
end

return Dependencies
