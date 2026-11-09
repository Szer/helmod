local Dependencies = require "data.SheetDependencies"
local Unit = require "math.incremental.Unit"
local Planner = {}

Planner.setting = "incremental_percentages"

---@class SheetUnit
---@field input BlockData
---@field result BlockData

---@class RecipeUnit
---@field input RecipeData
---@field result RecipeData

---@class SheetWork
---@field context SheetContext
---@field source BlockData
---@field root BlockData
---@field order BlockData[]
---@field inputs table<string,BlockData>
---@field units table<string,SheetUnit>
---@field wanted table<string,boolean>
---@field previousRecipes? table<string,RecipeUnit>
---@field previousContext? SheetContext
---@field recipes table<string,RecipeUnit>
---@field cursor integer
---@field finalized boolean
---@field preparation? UnitPreparation

---@class SheetJob
---@field player uint
---@field edited string?
---@field fullView boolean?
---@field revision integer
---@field editedBlocks table<string,boolean>
---@field changed? table<string,boolean>
---@field work? SheetWork

---@class SheetState
---@field jobs table<string, SheetJob>
---@field order string[]
---@field units table<string, {context:SheetContext, units:table<string,SheetUnit>, recipes:table<string,RecipeUnit>}>
---@field notifications {model:string, player:uint, form:string, rows:table<string,boolean>?}[]
---@field revision integer
---@field errors? table<string,string>
---@field servedNotice boolean?

---@return SheetState
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

local productionView = "HMProductionPanel"
local recipeView = "HMRecipeEdition"
local viewNames = {productionView, recipeView, "HMPinPanel", "HMSummaryPanel", "HMModelDebug"}

---Keep calculated views on their last rendered revision while the next one is incomplete.
---@param form Form
---@param frame LuaGuiElement
---@param content LuaGuiElement
---@return boolean
function Planner.deferView(form, frame, content)
    if not User.getModGlobalSetting(Planner.setting) then return false end
    for _, name in ipairs(viewNames) do
        if name == form.classname then
            local model, block, recipe = form:getParameterObjects()
            if not model then return false end
            local selection = {model=model.id, block=block and block.id, recipe=recipe and recipe.id}
            local tags = frame.tags
            if Planner.pending(model.id) or Planner.failure(model.id) then
                if tags.solver_view and not Unit.equal(tags.solver_view, selection) then content.clear() end
                if name == productionView then form:updatePending(model) end
                return true
            end
            tags.solver_view = selection
            frame.tags = tags
            break
        end
    end
    return false
end

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
        if s.errors then s.errors[id] = nil end
        for i = #s.order, 1, -1 do
            if s.order[i] == id then table.remove(s.order, i) end
        end
    end
end

---@param id string
---@return string?
function Planner.failure(id)
    local s = storage.percentage_planner
    return s and s.errors and s.errors[id]
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

---@param id string
---@return boolean?
function Planner.pendingStructure(id)
    local s = storage.percentage_planner
    local job = s and s.jobs[id]
    return job and job.fullView
end

---@param model ModelData
---@param block BlockData?
---@param player uint
function Planner.enqueue(model, block, player)
    local s = state()
    if not s.jobs[model.id] then table.insert(s.order, model.id) end
    -- A replacement starts from all accepted inputs, including other writers' edits.
    s.revision = s.revision + 1
    local prior = s.jobs[model.id]
    local editedBlocks = prior and prior.editedBlocks or {}
    if block then editedBlocks[block.id] = true end
    s.jobs[model.id] = {
        player=player, edited=block and block.id, editedBlocks=editedBlocks, revision=s.revision,
        fullView=block == nil or (prior and prior.fullView),
    }
    if s.errors then s.errors[model.id] = nil end
    eachViewer(player, function()
        local panel = Controller:getView(productionView)
        if panel:isOpened() then panel:updatePending(model) end
    end)
end

---@param s SheetState
---@param job SheetJob
---@param model ModelData
---@param inline? boolean
---@return SheetWork
local function start(s, job, model, inline)
    Model.appendParameters(model)
    local ctx = Dependencies.capture(model, model.block_root)
    local source = table.deepcopy(model.block_root)
    ---@type SheetWork
    local plan = {
        source=source, root=source, context=table.deepcopy(ctx), cursor=1, finalized=false,
        order={}, inputs={}, units={}, wanted={}, recipes={},
    }
    local cache = s.units[model.id]
    if ctx.environment.debug then cache = nil end
    if cache and not Unit.equal(cache.context.environment, ctx.environment) then cache = nil end

    plan.previousRecipes = cache and cache.recipes
    plan.previousContext = cache and cache.context

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
    if not inline and not ctx.environment.debug then
        if job.edited then mark(source) else
            for id, child in pairs(source.children) do
                if Model.isBlock(child) then plan.wanted[id] = true end
            end
        end
    end
    local function visit(input)
        plan.inputs[input.id] = input
        local old = cache and not ctx.freshBlocks[input.id] and cache.units[input.id]
        if old and Unit.equal(cache.context.blocks[input.id], ctx.blocks[input.id]) and Unit.equal(input, old.input) then
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
---@param s SheetState
---@param model ModelData
---@param job SheetJob
---@return boolean
---@param inline? boolean
local function advance(s, model, job, inline)
    local work = job.work
    if not work then
        job.work = start(s, job, model, inline)
        return false
    end
    if not inline then
        local nextBlock = work.order[work.cursor]
        local scope = nextBlock and work.inputs[nextBlock.id] or work.source
        local current = Dependencies.capture(model, scope)
        if not Unit.equal(work.context.environment, current.environment)
            or not Unit.equal(work.context.blocks[scope.id], current.blocks[scope.id]) then
            job.work = nil
            return false
        end
    end
    if work.cursor <= #work.order then
        local block = work.order[work.cursor]
        local function prepare(recipe)
            local input = work.inputs[block.id].children[recipe.id]
            local reusable = not inline and not work.context.environment.debug and not work.context.freshRecipes[recipe.id]
            local old = reusable and work.previousRecipes and work.previousRecipes[recipe.id]
            if old and Unit.equal(work.previousContext.dependencies[recipe.id], work.context.dependencies[recipe.id])
                and Unit.equal(old.input, input) then
                work.recipes[recipe.id] = old
                return table.deepcopy(old.result)
            end
            ModelCompute.prepareRecipeFactory(recipe, model.time, model.parameters)
            if reusable and not work.wanted[block.id] and input.class ~= "Block" then
                work.recipes[recipe.id] = {input=input, result=table.deepcopy(recipe)}
            end
            return recipe
        end
        work.preparation = ModelCompute.prepareUnit(model, block, work.preparation, prepare)
        if work.preparation then return false end
        ModelCompute.solveUnit(model, block)
        if work.wanted[block.id] and not work.context.freshBlocks[block.id] then
            work.units[block.id] = {input=work.inputs[block.id], result=table.deepcopy(block)}
        end
        work.cursor = work.cursor + 1
    elseif not work.finalized then
        ModelCompute.finalizeBlock(work.root, 1)
        work.finalized = true
    else
        if not inline and not Unit.equal(work.source, model.block_root) then
            job.work = nil
            return false
        end
        if not s.jobs[model.id] or s.jobs[model.id].revision ~= job.revision then return false end
        job.changed = publish(model, work.root, job.editedBlocks)
        if job.fullView then job.changed = nil end
        if next(work.units) or next(work.recipes) then
            s.units[model.id] = {context=work.context, units=work.units, recipes=work.recipes}
        else
            s.units[model.id] = nil
        end
        return true
    end
    return false
end

---Run the same work units in a single event when simulation ticks are unavailable.
---@param model ModelData
function Planner.solveNow(model)
    local s = {jobs={}, units={}, order={}, notifications={}, revision=0}
    local job = {player=Player.native().index, revision=0, editedBlocks={}, fullView=true}
    s.jobs[model.id] = job
    while not advance(s, model, job, true) do end
end

local function refresh(notification)
    local form = Controller:getView(notification.form)
    if not form:isOpened() then return end
    local model = form:getParameterObjects()
    if model and model.id == notification.model then
        if notification.form == recipeView then
            form:refreshSolved()
        else
            form:update({changed_rows=notification.rows})
        end
    end
end

local function fail(s, id, message)
    log("Background solver: " .. tostring(message))
    s.errors = s.errors or {}
    s.errors[id] = tostring(message)
    s.units[id] = nil
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
        local job, model = s.jobs[id], storage.models and storage.models[id]
        if not model then
            Planner.invalidate(id)
        else
            local editor = editorFor(job, model)
            if editor then
                Player.set(editor)
                local ok, complete = pcall(advance, s, model, job)
                if not ok then
                    fail(s, id, complete)
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
        local model = storage.models and storage.models[id]
        local player = model and editorFor(job, model)
        Planner.invalidate(id)
        if player then
            Player.set(player)
            local ok, message = pcall(Planner.solveNow, model)
            if not ok then fail(s, id, message) end
        end
    end
    while #s.notifications > 0 do Planner.tick() end
    Player.set(previous)
end

return Planner
