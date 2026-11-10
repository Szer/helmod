local TemperatureLinks = require "math.TemperatureLinks"
local RowFlows = require "math.balance.RowFlows"
local Profile = require "math.linked.Profile"
-------------------------------------------------------------------------------
---Description of the module.
---@class SolverLinkedMatrix
SolverLinkedMatrix = newclass(function(base)
end)

-------------------------------------------------------------------------------
---Clone la matrice
---@param matrix Matrix
---@return Matrix
function SolverLinkedMatrix:clone(matrix)
    local matrix_clone = table.deepcopy(matrix)
    return matrix_clone
end

-------------------------------------------------------------------------------
---Prepare la matrice
---@param matrix Matrix
---@return Matrix
function SolverLinkedMatrix:prepare(matrix)
    local matrix_clone = self:clone(matrix)
    self:prepare_z_and_objectives(matrix_clone, false)
    return matrix_clone
end

-------------------------------------------------------------------------------
---Prepare Z et objectives
---@param matrix Matrix
---@param reverse boolean reverse objective sign
function SolverLinkedMatrix:prepare_z_and_objectives(matrix, reverse)
    local row = {}
    local objective_values = {}
    ---ajoute la ligne Z avec Z=-input
    for _, column in pairs(matrix.columns) do
        local objective = matrix.objectives[column.key]
        local objective_value = 0
        if objective ~= nil and objective.used ~= true then
            objective_value = objective.value
            objective.used = true
        end
        if reverse then
            objective_value = -objective_value
        end
        local value = 0 - objective_value
        table.insert(row, value)
        table.insert(objective_values, objective_value)
    end
    matrix.objective_values = objective_values
    table.insert(matrix.rows, row)
end
-------------------------------------------------------------------------------
---Finalise la matrice
---@param matrix Matrix
---@return Matrix
function SolverLinkedMatrix:finalize(matrix)
    ---finalize la ligne Z reinject le input Z=Z+input
    local zrow = matrix.rows[#matrix.rows]
    for icol, column in pairs(matrix.columns) do
        local objective = matrix.objective_values[icol] or 0
        zrow[icol] = zrow[icol] + objective
    end
    return matrix
end

-------------------------------------------------------------------------------
---Add runtime
---@param debug boolean
---@param runtime table
---@param name string
---@param matrix Matrix
---@param pivot? table
function SolverLinkedMatrix:add_runtime(debug, runtime, name, matrix, pivot)
    if debug == true then
        local clone = table.deepcopy(matrix)
        table.insert(runtime, { name = name, matrix = clone, pivot = pivot })
    end
end

-------------------------------------------------------------------------------
---Ajoute la ligne State
---state = 0 => produit
---state = 1 => produit pilotant
---state = 2 => produit restant
---state = 3 => produit surplus
---@param matrix Matrix
---@return Matrix
function SolverLinkedMatrix:apply_state(matrix)
    local states = {}
    for irow, row in pairs(matrix.rows) do
        if irow < #matrix.rows then
            for icol, column in pairs(matrix.columns) do
                local cell_value = row[icol] or 0
                if states[icol] == nil then
                    table.insert(states, 0)
                end
                if cell_value < 0 then
                    states[icol] = 2
                end
                if cell_value > 0 and states[icol] ~= 2 then
                    states[icol] = 1
                end
            end
        end
    end
    local zrow = matrix.rows[#matrix.rows]
    for icol, cell in pairs(zrow) do
        if cell > 0 and states[icol] == 2 then
            states[icol] = 3
        end
    end
    matrix.states = states
    return matrix
end

-------------------------------------------------------------------------------
---Abstract Resoud la matrice
---@param matrix_base Matrix
---@param debug boolean
---@param by_factory boolean
---@param time number
---@return Matrix, table
function SolverLinkedMatrix:solve_matrix(matrix_base, debug, by_factory, time)
end
-------------------------------------------------------------------------------
---Return a matrix of block
---@param block BlockData
---@param parameters ParametersData
---@param debug boolean
---@param factories_prepared boolean?
---@return BlockData
function SolverLinkedMatrix:solve(block, parameters, debug, factories_prepared)
    block.blocks_linked = nil
    if block.products_linked ~= nil then
        local profiles = {}
        for key, enabled in pairs(block.products_linked) do
            if block.products[key] == nil then
                block.products_linked[key] = nil
            elseif enabled then
                local amount = self:linkedOutputAmount(block, key)
                if amount > 0 then
                    local profile = table.deepcopy(block)
                    profile.contraint = nil
                    profile.product_linked = profile.products[key]
                    profile.objectives = {[key]={key=key, value=amount}}
                    profiles[key] = self:solve_block(profile, parameters, debug, factories_prepared)
                end
            end
        end
        block.blocks_linked = profiles
    end
    return self:solve_block(block, parameters, debug, factories_prepared)
end
---@param block BlockData
---@param key string Product table key, including quality or temperature
---@return number Output supplied by one unit of the child recipe or block profile
function SolverLinkedMatrix:linkedOutputAmount(block, key)
    local sorter = defines.sorters.block.sort
    if block.by_product == false then sorter = defines.sorters.block.reverse end
    for _, child in spairs(block.children, sorter) do
        if Model.isBlock(child) then
            local output = child.products[key]
            if output and output.amount > 0 then return output.amount end
            local profile = child.blocks_linked and child.blocks_linked[key]
            local linked = profile and profile.products[key]
            if linked and linked.amount > 0 then return linked.amount end
        else
            local prototype = RecipePrototype(child)
            for _, output in pairs(prototype:getQualityProducts(child.factory, child.quality)) do
                local product = Product(output)
                if product:getTableKey() == key then
                    local amount = product:getAmount(child)
                    if amount > 0 then return amount end
                end
            end
        end
    end
    return 0
end

-------------------------------------------------------------------------------
---Return a matrix of block
---@param block BlockData
---@param parameters ParametersData
---@param debug boolean
---@param factories_prepared boolean?
---@return BlockData
function SolverLinkedMatrix:solve_block(block, parameters, debug, factories_prepared)
    local mC, runtimes

    local ok, err = pcall(function()
        local mA = self:get_block_matrix(block, parameters, factories_prepared)
        if mA ~= nil then
            mC, runtimes = self:solve_matrix(mA, debug, block.by_factory, block.time)
        end
    end)
    if not (ok) then
        Player.repportError(err)
    end
    block.runtimes = nil
    if debug then
        block.runtimes = runtimes
    end

    if mC ~= nil then
        -- remove temperature convert lines
        -- necessary to retieve the right value
        for i = #mC.headers, 1, -1 do
            if mC.headers[i].name == TemperatureLinks.recipeName then
                table.remove(mC.rows, i)
                table.remove(mC.headers, i)
                table.remove(mC.parameters, i)
            end
        end

        local sorter = defines.sorters.block.sort
        if block.by_product == false then
            sorter = defines.sorters.block.reverse
        end

        local primary_rows = {}
        local linked_rows = {}
        for index, header in ipairs(mC.headers) do
            local id = header.child_id
            if id ~= nil then
                if header.product_linked ~= nil then
                    local key = Product(header.product_linked):getTableKey()
                    linked_rows[id] = linked_rows[id] or {}
                    linked_rows[id][key] = index
                elseif primary_rows[id] == nil then
                    primary_rows[id] = index
                end
            end
        end

        local children = block.children
        for _, child in spairs(children, sorter) do
            local is_block = Model.isBlock(child)
            local row_index = primary_rows[child.id]
            local parameters = mC.parameters[row_index]
            -- retrieve pivot name
            if parameters ~= nil and parameters.pivot ~= nil then
                local xcol = parameters.pivot
                local colum_pivot = mC.columns[xcol]
                if colum_pivot ~= nil  then
                    child.pivot = {type=colum_pivot.product.type, name=colum_pivot.product.name, quality=colum_pivot.product.quality}
                else
                    child.pivot = nil       
                end
            end
            if is_block and block.by_factory == true then
                child.count = 1
            elseif parameters ~= nil and parameters.recipe_count > 0 then
                child.count = parameters.recipe_count
                child.production = parameters.recipe_production
            else
                child.count = 0
            end
            
            if is_block then
                self:solve_block_append(child, mC, linked_rows[child.id])
            else
                local recipe = child
                ---calcul dependant du recipe count
                if child.type == "energy" then
                    ModelCompute.computeEnergyFactory(recipe)
                else
                    ModelCompute.computeFactory(recipe)
                end
            end
        end

        
    end
    self:solve_block_finalize(block, mC)
    return block
end

---Append linked block values
---@param block BlockData
---@param matrix Matrix
---@param linked_rows table<string, integer>?
function SolverLinkedMatrix:solve_block_append(block, matrix, linked_rows)
    for key, row in pairs(linked_rows or {}) do
        local parameters = matrix.parameters[row]
        if parameters then Profile.append(block, block.blocks_linked[key], parameters.recipe_count) end
    end
end

---Finalize the block
---@param block any
---@param matrix any
function SolverLinkedMatrix:solve_block_finalize(block, matrix)
    if matrix == nil or matrix.states == nil then
        return
    end
    -- state = 0 => produit
    -- state = 1 => produit pilotant
    -- state = 2 => produit restant
    -- state = 3 => produit surplus
    for icol, state in pairs(matrix.states) do
        if icol > 0 then
            local rows = matrix.rows
            local zrow = rows[#matrix.rows]
            local Z = math.abs(zrow[icol])
            local product_header = matrix.columns[icol]
            local product_key = product_header.key
            local product = Product(product_header.product):clone()
            product.amount = Z
            if math.abs(product.amount) < 1e-10 then
                product.amount = 0
            end
            product.state = state
            if block.by_product == false then
                if state == 1 or state == 3 then
                    -- element produit
                    if block.ingredients[product_key] ~= nil then
                        block.ingredients[product_key].amount = block.ingredients[product_key].amount + product.amount
                        block.ingredients[product_key].state = state
                    end
                    if block.products[product_key] ~= nil then
                        block.products[product_key].state = 0
                    end
                else
                    -- element ingredient
                    if block.products[product_key] ~= nil then
                        block.products[product_key].amount = block.products[product_key].amount + product.amount
                        block.products[product_key].state = state
                    end
                    if block.ingredients[product_key] ~= nil then
                        block.ingredients[product_key].state = state
                    end
                end
            else
                if state == 1 or state == 3 then
                    -- element produit
                    if block.products[product_key] ~= nil then
                        block.products[product_key].amount = block.products[product_key].amount + product.amount
                        block.products[product_key].state = state
                    end
                    if block.ingredients[product_key] ~= nil then
                        block.ingredients[product_key].state = 0
                    end
                else
                    -- element ingredient
                    if block.ingredients[product_key] ~= nil then
                        block.ingredients[product_key].amount = block.ingredients[product_key].amount + product.amount
                        block.ingredients[product_key].state = state
                    end
                    if block.products[product_key] ~= nil then
                        block.products[product_key].state = state
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
---Return a matrix of block
---@param block BlockData
---@param parameters ParametersData
---@param factories_prepared boolean?
---@return table
function SolverLinkedMatrix:get_block_matrix(block, parameters, factories_prepared)
    local children = block.children
    if children ~= nil then
        local matrix = Matrix()
        matrix.column_sum = {}

        local linked_exports
        local col_index = {}
        local factor = 1
        local sorter = defines.sorters.block.sort
        if block.by_product == false then
            factor = -factor
            sorter = defines.sorters.block.reverse
        end

        ---begin loop children
        for _, child in spairs(children, sorter) do
            local is_block = Model.isBlock(child)
            local child_info = {}
            child_info.recipe_energy = 1
            child_info.factory_count = 0
            child_info.factory_speed = 1

            -- prepare production %
            local production = 1
            if not (block.solver == true) and child.production ~= nil then production = child.production end

            if is_block then
                child_info.name = child.name
                child_info.type = child.type
                child_info.tooltip = child.name .. "\nBlock"

                child_info.factory_count = 1

                child_info.products = child.products
                child_info.ingredients = child.ingredients
                child_info.consumer = child.consumer

                self:add_matrix_row(matrix, child, child_info, is_block, col_index, block.by_product, production, factor)

                if child.blocks_linked ~= nil then
                    -- add virtual row of linked blocks
                    for key, child_linked in pairs(child.blocks_linked) do
                        -- Reserve each linked export for its own profile when selecting a driving column.
                        local product = child_linked.products[key]
                        if block.by_product ~= false and not block.by_factory and not block.solver
                            and child.by_product ~= false and not child.consumer and not Model.isUnlinkedBlock(child)
                            and product and product.amount > 0 then
                            linked_exports = linked_exports or {}
                            linked_exports[child.id] = linked_exports[child.id] or {}
                            linked_exports[child.id][key] = true
                        end
                        local child_linked_info = {}
                        child_linked_info.name = child.name
                        child_linked_info.type = child.type
                        child_linked_info.tooltip = child.name .. "\nLinked Block"
                        child_linked_info.recipe_energy = 1
                        child_linked_info.factory_count = 1
                        child_linked_info.factory_speed = 1
                        child_linked_info.consumer = child.consumer

                        child_linked_info.products = child_linked.products
                        child_linked_info.ingredients = child_linked.ingredients
                        self:add_matrix_row(matrix, child_linked, child_linked_info, is_block, col_index, block.by_product, production, factor)
                    end
                end
            else
                local recipe = child
                -- check recipe doesn't exist
                local recipe_prototype = RecipePrototype(recipe)
                if recipe_prototype:native() == nil then return end

                child_info.name = recipe.name
                child_info.type = recipe.type
                child_info.quality = recipe.quality or "normal"
                child_info.tooltip = recipe.name .. "\nRecette"
                child_info.factory = recipe.factory
                child_info.recipe_energy = recipe_prototype:getEnergy(recipe.factory)
                child_info.factory_count = 0
                if recipe.factory ~= nil then
                    child_info.factory_count = recipe.factory.input or 0
                end
                child_info.consumer = recipe.consumer

                if not factories_prepared then
                    ModelCompute.prepareRecipeFactory(recipe, block.time, parameters)
                end
                
                child_info.factory_speed = 0
                if recipe.factory ~= nil then
                    child_info.factory_speed = recipe.factory.speed or 0
                end
                child_info.is_technology = recipe.type == "technology"

                child_info.products = recipe_prototype:getQualityProducts(recipe.factory, recipe.quality)
                child_info.ingredients = recipe_prototype:getQualityIngredients(recipe.factory, recipe.quality)
                local row_factor = factor
                if not ModelCompute.canRunRecipe(recipe) then
                    row_factor = 0
                    child_info.factory_count = 0
                end
                self:add_matrix_row(matrix, child, child_info, is_block, col_index, block.by_product, production, row_factor)
            end

        end

        ---end loop recipes

        matrix = TemperatureLinks.build(matrix, block)
        matrix.linked_exports = linked_exports
        if block.by_product ~= false then matrix.external_supplies = block.matrix_supplies end
        matrix.objectives = block.objectives
        return matrix
    end
    return nil
end

-------------------------------------------------------------------------------
---Add matrix row
---@param matrix table
---@param child table
---@param child_info table
---@param is_block boolean
---@param col_index table
---@param by_product boolean
---@param production number
---@param factor number
function SolverLinkedMatrix:add_matrix_row(matrix, child, child_info, is_block, col_index, by_product, production, factor)

    local row_valid = false
    local rowParameters = MatrixRowParameters()
    local row = MatrixRow(child_info.type, child_info.name, child_info.quality, child_info.tooltip)
    row.header.child_id = child.id
    if child.product_linked then
        row.header.product_linked = child.product_linked
    end

    rowParameters.base = row.header
    if child.contraints ~= nil then
        rowParameters.contraints = table.deepcopy(child.contraints)
    end
    rowParameters.name = child_info.name
    rowParameters.factory_count = child_info.factory_count
    rowParameters.factory_speed = child_info.factory_speed
    rowParameters.recipe_count = 0
    rowParameters.recipe_production = production
    rowParameters.recipe_energy = child_info.recipe_energy
    rowParameters.coefficient = 0
    rowParameters.voider = 0
    rowParameters.unlinked = 0
    rowParameters.consumer = 0
    if child_info.consumer == true then
        rowParameters.consumer = 1
    end
    if Model.isUnlinkedBlock(child) then
        rowParameters.unlinked = 1
    end
    rowParameters.by_product = 0
    if not (child.by_product == false) then
        rowParameters.by_product = 1
    end

    ---preparation
    local lua_products = {}
    local lua_ingredients = {}
    for i, lua_product in pairs(child_info.products) do
        local product = Product(lua_product)
        local product_key = product:getTableKey()
        local product_amount = 0
        if is_block then
            product_amount = lua_product.amount or 0
        else
            product_amount = product:getAmount(child)
        end
        RowFlows.add(lua_products, product_key, lua_product, product_amount)
    end
    for i, lua_ingredient in pairs(child_info.ingredients) do
        local ingredient = Product(lua_ingredient)
        local ingredient_key = ingredient:getTableKey()
        local ingredient_amount = 0
        if is_block then
            ingredient_amount = lua_ingredient.amount or 0
        elseif child.type == "technology" then
            ingredient_amount = ingredient:getDrainedAmount(child)
        else
            ingredient_amount = ingredient:getAmount()
            ---si constant compte comme un produit (recipe rocket)
            if lua_ingredient.constant then
                ingredient_amount = ingredient:getAmount(child)
            end
        end
        
        RowFlows.add(lua_ingredients, ingredient_key, lua_ingredient, ingredient_amount)
    end

    if not (by_product == false) then
        ---prepare header products
        for name, lua_product in pairs(lua_products) do
            local product = Product(lua_product)
            local product_key = product:getTableKey()
            local index = 1
            if col_index[product_key] ~= nil then
                index = col_index[product_key]
            end
            col_index[product_key] = index

            local col_name = product_key .. index

            local col_header = MatrixHeader()
            col_header.sysname = col_name
            col_header.tooltip = col_name .. "\nProduit"
            col_header.index = index
            col_header.key = product_key
            col_header.is_ingredient = false
            col_header.product = lua_product

            local value = lua_product.amount * factor
            local cell_value = value
            row:add_value(col_header, cell_value)

            matrix.column_sum[product_key] = ( matrix.column_sum[product_key] or 0 ) + value

            row_valid = true
        end
        ---prepare header ingredients
        for name, lua_ingredient in pairs(lua_ingredients) do
            local ingredient = Product(lua_ingredient)
            local ingredient_key = ingredient:getTableKey()
            local index = 1
            ---default case
            if col_index[ingredient_key] ~= nil and lua_products[ingredient_key] == nil then
                index = col_index[ingredient_key]
            end
            ---case where the ingredient exist in the product side
            if col_index[ingredient_key] ~= nil and lua_products[ingredient_key] ~= nil then
                local child_type = child_info.type
                ---case of the equivalent value, we create a new element
                if lua_products[ingredient_key].amount > 0 and lua_ingredients[ingredient_key].amount > 0 and 
                    lua_products[ingredient_key].amount == lua_ingredients[ingredient_key].amount or child_type == "resource" or child_type == "energy" then
                    index = col_index[ingredient_key] + 1
                else
                    index = col_index[ingredient_key]
                end
            end
            col_index[ingredient_key] = index

            local col_name = ingredient_key .. index

            local col_header = MatrixHeader()
            col_header.sysname = col_name
            col_header.tooltip = col_name .. "\nIngredient"
            col_header.index = index
            col_header.key = ingredient_key
            col_header.is_ingredient = true
            col_header.product = lua_ingredient

            local cell_value = row:get_value(col_header) or 0
            local value = - lua_ingredients[ingredient_key].amount * factor
            cell_value = cell_value + value
            row:add_value(col_header, cell_value)

            matrix.column_sum[ingredient_key] = ( matrix.column_sum[ingredient_key] or 0 ) + value

            row_valid = true
        end
        rowParameters:setVoider(row, child, is_block, lua_products, lua_ingredients)
    else
        ---prepare header ingredients
        for name, lua_ingredient in pairs(lua_ingredients) do
            local ingredient = Product(lua_ingredient)
            local ingredient_key = ingredient:getTableKey()
            local index = 1
            ---default case
            if col_index[ingredient_key] ~= nil then
                index = col_index[ingredient_key]
            end
            col_index[ingredient_key] = index

            local col_name = ingredient_key .. index

            local col_header = MatrixHeader()
            col_header.sysname = col_name
            col_header.tooltip = col_name .. "\nIngredient"
            col_header.index = index
            col_header.key = ingredient_key
            col_header.is_ingredient = true
            col_header.product = lua_ingredient

            local value = -lua_ingredient.amount * factor
            local cell_value = value
            row:add_value(col_header, cell_value)

            matrix.column_sum[ingredient_key] = ( matrix.column_sum[ingredient_key] or 0 ) + value

            row_valid = true
        end
        ---prepare header products
        for name, lua_product in pairs(lua_products) do
            local product = Product(lua_product)
            local product_key = product:getTableKey()
            local index = 1
            if col_index[product_key] ~= nil then
                index = col_index[product_key]
            end
            --- case where the product exist in the ingredient side
            if col_index[product_key] ~= nil and lua_ingredients[product_key] ~= nil then
                local child_type = child_info.type
                ---case of the equivalent value, we create a new element
                if lua_products[product_key].amount > 0 and lua_ingredients[product_key].amount > 0 and 
                    lua_products[product_key].amount == lua_ingredients[product_key].amount or child_type == "resource" or child_type == "energy" then
                    index = col_index[product_key] + 1
                else
                    index = col_index[product_key]
                end
            end
            col_index[product_key] = index

            local col_name = product_key .. index

            local col_header = MatrixHeader()
            col_header.sysname = col_name
            col_header.tooltip = col_name .. "\nProduit"
            col_header.index = index
            col_header.key = product_key
            col_header.is_ingredient = false
            col_header.product = lua_product

            local value = lua_product.amount * factor
            local cell_value = row:get_value(col_header) or 0
            cell_value = cell_value + value
            row:add_value(col_header, cell_value)

            matrix.column_sum[product_key] = ( matrix.column_sum[product_key] or 0 ) + value

            row_valid = true
        end
    end
    if row_valid then
        matrix:add_row(row, rowParameters)
    end
end
