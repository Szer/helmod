local Unit = require "math.incremental.Unit"
local Planner = {}

Planner.setting = "incremental_percentages"

---@class PercentageUnit
---@field input BlockData
---@field result BlockData

---@class PercentageContext
---@field time number
---@field parameters ParametersData
---@field force uint
---@field solver string?
---@field one boolean?
---@field mining number
---@field lab number
---@field lab_productivity number
---@field day number[]
---@field bonuses table<string,number>
---@field technologies table<string,number[]>

---@class PercentageWork
---@field context PercentageContext
---@field source BlockData
---@field root BlockData
---@field order BlockData[]
---@field inputs table<string,BlockData>
---@field units table<string,PercentageUnit>
---@field wanted table<string,boolean>
---@field cursor integer
---@field finalized boolean
---@field preparation? UnitPreparation

---@class PercentageJob
---@field player uint
---@field edited string
---@field revision integer
---@field editedBlocks table<string,boolean>
---@field changed? table<string,boolean>
---@field retries integer
---@field work? PercentageWork

---@class PercentageState
---@field jobs table<string, PercentageJob>
---@field order string[]
---@field units table<string, {context:PercentageContext, units:table<string,PercentageUnit>}>
---@field notifications {model:string, player:uint, form:string, rows:table<string,boolean>?}[]
---@field revision integer
---@field servedNotice boolean?

---@return PercentageState
local function state()
    if not storage.percentage_planner then
        storage.percentage_planner = {jobs={}, order={}, units={}, notifications={}, revision=0}
    end
    return storage.percentage_planner
end

local function eachViewer(editor, callback)
    local previous = Player.native()
    for _, viewer in pairs(game.connected_players) do
        Player.set(viewer)
        callback(viewer)
    end
    local author = game.get_player(editor)
    if author and not author.connected then
        Player.set(author)
        callback(author)
    end
    Player.set(previous)
end

local viewNames = {"HMProductionPanel", "HMRecipeEdition", "HMPinPanel"}

local function queueViews(player, id, rows)
    local queue = state().notifications
    for _, name in ipairs(viewNames) do
        local form = Controller:getView(name)
        if form:isOpened() then
            local model = form:getParameterObjects()
            if model and (id == nil or id == model.id) then
                local queued = false
                for _, notice in ipairs(queue) do
                    if notice.player == player.index and notice.form == name then
                        notice.model = model.id
                        notice.rows = nil
                        queued = true
                        break
                    end
                end
                if not queued then table.insert(queue, {model=model.id, player=player.index, form=name, rows=rows}) end
            end
        end
    end
end

local function notify(id, editor, rows)
    eachViewer(editor, function(viewer) queueViews(viewer, id, rows) end)
end

function Planner.onJoin(player)
    if storage.percentage_planner then queueViews(player) end
end

---@param id string
function Planner.invalidate(id)
    local s = storage.percentage_planner
    if s then
        if s.jobs[id] then notify(id, s.jobs[id].player) end
        s.units[id], s.jobs[id] = nil, nil
        for i = #s.order, 1, -1 do
            if s.order[i] == id then table.remove(s.order, i) end
        end
    end
end

function Planner.reset()
    local s = storage.percentage_planner
    if not s then return end
    s.units = {}
    for _, job in pairs(s.jobs) do
        job.work = nil
    end
end

---@param id string
---@return boolean
function Planner.pending(id)
    local s = storage.percentage_planner
    return s ~= nil and s.jobs[id] ~= nil
end

---@param model ModelData
---@param block BlockData
---@param player uint
function Planner.enqueue(model, block, player)
    local s = state()
    if not s.jobs[model.id] then table.insert(s.order, model.id) end
    -- A replacement starts from all accepted inputs, including other writers' edits.
    s.revision = s.revision + 1
    local editedBlocks = s.jobs[model.id] and s.jobs[model.id].editedBlocks or {}
    editedBlocks[block.id] = true
    s.jobs[model.id] = {player=player, edited=block.id, editedBlocks=editedBlocks, revision=s.revision, retries=0}
    eachViewer(player, function()
        local panel = Controller:getView("HMProductionPanel")
        if panel:isOpened() then panel:updatePending(model) end
    end)
end

-- Synthetic recipes outside this set use the synchronous solver.
---@param model ModelData
---@return PercentageContext?
local function context(model)
    local force = Player.getForce()
    ---@type PercentageContext
    local ctx = {
        time=model.time, parameters=model.parameters, force=force.index,
        solver=User.getParameter("solver_selected"), one=User.getPreferenceSetting("one_block_factor_enable"),
        mining=force.mining_drill_productivity_bonus, lab=force.laboratory_speed_modifier,
        lab_productivity=force.laboratory_productivity_bonus, day={Player.getGameDay()}, bonuses={}, technologies={},
    }
    local function visit(block)
        for _, child in pairs(block.children) do
            if Model.isBlock(child) then
                if not visit(child) then return false end
            else
                if child.type == "technology" then
                    local tech = force.technologies[child.name]
                    if not tech then return false end
                    ctx.technologies[child.name] = {tech.level, tech.research_unit_count}
                elseif child.type == "recipe" then
                    if not prototypes.recipe[child.name] or RecipePrototype.isCustomized(child) then return false end
                elseif child.type ~= "fluid" and child.type ~= "boiler" then
                    return false
                end
                ctx.bonuses[child.name] = Player.getRecipeProductivityBonus(child.name)
            end
        end
        return true
    end
    if visit(model.block_root) then return ctx end
end

---@param s PercentageState
---@param job PercentageJob
---@param model ModelData
---@return PercentageWork?
local function start(s, job, model)
    Model.appendParameters(model)
    local ctx = context(model)
    if not ctx or User.getModGlobalSetting("debug_solver") then return nil end
    local source = table.deepcopy(model.block_root)
    ---@type PercentageWork
    local plan = {
        source=source, root=source, context=table.deepcopy(ctx), cursor=1, finalized=false,
        order={}, inputs={}, units={}, wanted={},
    }
    local cache = s.units[model.id]
    if cache and not Unit.equal(cache.context, ctx) then cache = nil end

    -- Retain disjoint sibling subtrees along the edited path.
    local function mark(block)
        local path
        for id, child in pairs(block.children) do
            if Model.isBlock(child) and mark(child) then path = id end
        end
        if path or block.id == job.edited then
            for id, child in pairs(block.children) do
                if id ~= path and Model.isBlock(child) then plan.wanted[id] = true end
            end
            return true
        end
    end
    mark(source)
    local function visit(input)
        plan.inputs[input.id] = input
        local old = cache and cache.units[input.id]
        if old and Unit.equal(input, old.input) then
            if plan.wanted[input.id] then plan.units[input.id] = old end
            return table.deepcopy(old.result)
        end
        local shell = {}
        for field, value in pairs(input) do
            if field ~= "children" then shell[field] = value end
        end
        local work = table.deepcopy(shell)
        work.children = {}
        for id, child in pairs(input.children) do
            if Model.isBlock(child) then
                work.children[id] = visit(child)
            else
                work.children[id] = table.deepcopy(child)
            end
        end
        table.insert(plan.order, work)
        return work
    end
    plan.root = visit(source)
    return plan
end

---@param model ModelData
---@param root BlockData
---@param edited table<string,boolean>
---@return table<string,boolean>
local function publish(model, root, edited)
    local changed = {}
    local function apply(live, solved)
        for key in pairs(live) do
            if solved[key] == nil then
                changed[live.id] = true
                live[key] = nil
            end
        end
        for key, value in pairs(solved) do
            if key ~= "children" then
                if not changed[live.id] and not Unit.equal(live[key], value) then changed[live.id] = true end
                live[key] = value
            end
        end
        for id, child in pairs(solved.children or {}) do
            if edited[live.id] then changed[id] = true end
            apply(live.children[id], child)
            if changed[id] then changed[live.id] = true end
        end
    end
    apply(model.block_root, root)
    model.version = Model.version
    return changed
end

-- One block solve, finalization, or publication per simulation tick.
---@param s PercentageState
---@param model ModelData
---@param job PercentageJob
---@return boolean
local function advance(s, model, job)
    if not User.getModGlobalSetting(Planner.setting) or job.retries >= 2 then
        ModelCompute.update(model)
        return true
    end
    local work = job.work
    if not work then
        job.work = start(s, job, model)
        if not job.work then
            ModelCompute.update(model)
            return true
        end
    elseif not Unit.equal(work.context, context(model)) or User.getModGlobalSetting("debug_solver") then
        job.work = nil
        job.retries = job.retries + 1
    elseif work.cursor <= #work.order then
        local block = work.order[work.cursor]
        work.preparation = ModelCompute.prepareUnit(model, block, work.preparation)
        if work.preparation then return false end
        ModelCompute.solveUnit(model, block)
        if work.wanted[block.id] then
            work.units[block.id] = {input=work.inputs[block.id], result=table.deepcopy(block)}
        end
        work.cursor = work.cursor + 1
    elseif not work.finalized then
        ModelCompute.finalizeBlock(work.root, 1)
        work.finalized = true
    else
        if not Unit.equal(work.source, model.block_root) then
            job.work = nil
            job.retries = job.retries + 1
            return false
        end
        if not s.jobs[model.id] or s.jobs[model.id].revision ~= job.revision then return false end
        job.changed = publish(model, work.root, job.editedBlocks)
        s.units[model.id] = {context=work.context, units=work.units}
        return true
    end
    return false
end

local function refresh(notification)
    local form = Controller:getView(notification.form)
    if not form:isOpened() then return end
    local model = form:getParameterObjects()
    if model and model.id == notification.model then
        if notification.form == "HMRecipeEdition" then
            form:refreshPercentage()
        else
            form:update({percentage_rows=notification.rows})
        end
    end
end

local function editorFor(job, model)
    local editor = game.get_player(job.player) or game.get_player(model.owner)
    if editor then return editor end
    for _, player in pairs(game.players) do return player end
end

function Planner.tick()
    local s = storage.percentage_planner
    if not s or (#s.order == 0 and #s.notifications == 0) then return end
    local previous = Player.native()
    local notice
    if #s.notifications > 0 and (#s.order == 0 or not s.servedNotice) then
        notice = table.remove(s.notifications, 1)
    end
    s.servedNotice = notice ~= nil
    if notice then
        local viewer = game.get_player(notice.player)
        if viewer then
            Player.set(viewer)
            refresh(notice)
        end
    else
        local id = table.remove(s.order, 1)
        if not id then return end
        local job, model = s.jobs[id], storage.models[id]
        if not model then
            Planner.invalidate(id)
        else
            local editor = editorFor(job, model)
            if editor then
                Player.set(editor)
                local ok, complete = pcall(advance, s, model, job)
                if not ok then
                    log("Background solver: " .. tostring(complete))
                    ModelCompute.update(model)
                    complete = true
                end
                if complete then
                    s.jobs[id] = nil
                    notify(id, editor.index, job.changed)
                else
                    table.insert(s.order, id)
                end
            else
                table.insert(s.order, id)
            end
        end
    end
    Player.set(previous)
end

-- Paused simulations cannot service queued ticks.
function Planner.finishPending()
    local s = storage.percentage_planner
    if not s then return end
    local previous = Player.native()
    while #s.order > 0 do
        local id = s.order[1]
        local job = s.jobs[id]
        local model = storage.models[id]
        local player = model and editorFor(job, model)
        Planner.invalidate(id)
        if player then
            Player.set(player)
            ModelCompute.update(model)
        end
    end
    while #s.notifications > 0 do Planner.tick() end
    Player.set(previous)
end

return Planner
