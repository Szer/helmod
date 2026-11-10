local MaterialBalance = require "math.balance.MaterialBalance"
local TemperatureLinks = require "math.TemperatureLinks"
local RowFlows = require "math.balance.RowFlows"
-------------------------------------------------------------------------------
---Description of the module.
---@class SolverMatrix
SolverMatrix = newclass(function(base)
end)

-------------------------------------------------------------------------------
---Clone la matrice
---@param matrix Matrix
---@return Matrix
function SolverMatrix:clone(matrix)
    local matrix_clone = table.deepcopy(matrix)
    return matrix_clone
end

-------------------------------------------------------------------------------
---Prepare la matrice
---@param matrix Matrix
---@return Matrix
function SolverMatrix:prepare(matrix)
    local matrix_clone = self:clone(matrix)
    self:prepare_z_and_objectives(matrix_clone, false)
    return matrix_clone
end

-------------------------------------------------------------------------------
---Prepare Z et objectives
---@param matrix Matrix
---@param reverse boolean reverse objective sign
function SolverMatrix:prepare_z_and_objectives(matrix, reverse)
    local row = {}
    local objective_values = {}
    ---ajoute la ligne Z avec Z=-input
    for _, column in pairs(matrix.columns) do
        local objective = matrix.objectives[column.key]
        local objective_value = 0
        if objective ~= nil then
            objective_value = objective.value
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
function SolverMatrix:finalize(matrix)
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
function SolverMatrix:add_runtime(debug, runtime, name, matrix, pivot)
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
function SolverMatrix:apply_state(matrix)
    matrix.states = MaterialBalance.states(matrix.rows, #matrix.columns)
    return matrix
end

-------------------------------------------------------------------------------
---Abstract Resoud la matrice
---@param matrix_base Matrix
---@param debug boolean
---@param by_factory boolean
---@param time number
---@return Matrix, table
function SolverMatrix:solve_matrix(matrix_base, debug, by_factory, time)
end
-------------------------------------------------------------------------------
---Return a matrix of block
---@param block BlockData
---@param parameters ParametersData
---@param debug boolean
---@param factories_prepared boolean?
---@return BlockData
function SolverMatrix:solve(block, parameters, debug, factories_prepared)
    local mC, runtimes

    local ok, err = pcall(function()
        local mA = self:get_block_matrix(block, parameters, factories_prepared)
        if mA ~= nil then
            mC, runtimes = self:solve_matrix(mA, debug, block.by_factory, block.time)
        end
    end)
    if not (ok) then
        if block.solver == true and block.by_factory ~= true then
            Player.print("Matrix solver can not find solution!")
        else
            Player.print("Algebraic solver can not find solution!")
        end
        if debug then
            Player.print(err)
        end
    end
    if debug then
        block.runtimes = runtimes
    else
        block.runtimes = nil
    end

    if mC ~= nil then
        ---remove temperature convert lines
        ---necessary to retieve the right value
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

        ---calcul ordonnee sur les recipes du block
        local row_index = 1

        local children = block.children
        for _, child in spairs(children, sorter) do
            local is_block = Model.isBlock(child)
            local parameters = mC.parameters[row_index]
            if parameters ~= nil and parameters.recipe_count > 0 then
                child.count = parameters.recipe_count
                child.production = parameters.recipe_production
            else
                child.count = 0
            end
            row_index = row_index + 1
            
            if is_block then
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

        ---state = 0 => produit
        ---state = 1 => produit pilotant
        ---state = 2 => produit restant
        ---state = 3 => produit surplus

        ---finalisation du bloc
        for icol, state in pairs(mC.states) do
            if icol > 0 then
                local rows = mC.rows
                local zrow = rows[#mC.rows]
                local product_header = mC.columns[icol]
                local product_key = product_header.key
                local product = Product(product_header):clone()
                product.amount = MaterialBalance.amount(zrow[icol])
                product.state = state
                if block.by_product == false then
                    if state == 1 or state == 3 then
                        ---element produit
                        if block.ingredients[product_key] ~= nil then
                            block.ingredients[product_key].amount = block.ingredients[product_key].amount + product.amount
                            block.ingredients[product_key].state = state
                        end
                        if block.products[product_key] ~= nil then
                            block.products[product_key].state = 0
                        end
                    else
                        ---element ingredient
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
                        ---element produit
                        if block.products[product_key] ~= nil then
                            block.products[product_key].amount = block.products[product_key].amount + product.amount
                            block.products[product_key].state = state
                        end
                        if block.ingredients[product_key] ~= nil then
                            block.ingredients[product_key].state = 0
                        end
                    else
                        ---element ingredient
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

    return block
end

-------------------------------------------------------------------------------
---Return a matrix of block
---@param block BlockData
---@param parameters ParametersData
---@param factories_prepared boolean?
---@return table
function SolverMatrix:get_block_matrix(block, parameters, factories_prepared)
    local children = block.children
    if children ~= nil then
        local matrix = Matrix()
        matrix.column_sum = {}

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
            local row_factor = factor
            local child_name = nil
            local child_type = nil
            local child_tooltip = nil
            local child_products = nil
            local child_ingredients = nil
            local child_recipe_energy = 1
            local child_factory_count = 0
            local child_factory_speed = 1

            local row_valid = false
            -- prepare production %
            local production = 1
            if not (block.solver == true) and child.production ~= nil then production = child.production end

            if is_block then
                child_name = child.name
                child_type = child.type
                child_tooltip = child.name .. "\nBlock"

                --- TODO fix product by ingredient
                -- if child.by_product == false then
                --     child_products = child.ingredients
                --     child_ingredients = child.products
                -- else
                    child_products = child.products
                    child_ingredients = child.ingredients
                --end
            else
                local recipe = child
                -- check recipe doesn't exist
                local recipe_prototype = RecipePrototype(recipe)
                if recipe_prototype:native() == nil then return end

                child_name = recipe.name
                child_type = recipe.type
                child_tooltip = recipe.name .. "\nRecette"
                child_recipe_energy = recipe_prototype:getEnergy(recipe.factory)
                child_factory_count = recipe.factory and recipe.factory.input or 0

                if not factories_prepared then
                    ModelCompute.prepareRecipeFactory(recipe, block.time, parameters)
                end
                
                child_factory_speed = recipe.factory and recipe.factory.speed or 0
                if not ModelCompute.canRunRecipe(recipe) then
                    row_factor = 0
                    child_factory_count = 0
                end

                child_products = recipe_prototype:getQualityProducts(recipe.factory, recipe.quality)
                child_ingredients = recipe_prototype:getQualityIngredients(recipe.factory, recipe.quality)
            end

            

            local rowParameters = MatrixRowParameters()
            local row = MatrixRow(child_type, child_name, child.quality, child_tooltip)

            rowParameters.base = row.header
            if child.contraint ~= nil then
                rowParameters.contraint = { type = child.contraint.type, name = child.contraint.name }
            end
            rowParameters.factory_count = child_factory_count
            rowParameters.factory_speed = child_factory_speed
            rowParameters.recipe_count = 0
            rowParameters.recipe_production = production
            rowParameters.recipe_energy = child_recipe_energy
            rowParameters.coefficient = 0
            rowParameters.voider = 0
            rowParameters.by_product = 0
            if not (child.by_product == false) then
                rowParameters.by_product = 1
            end

            ---preparation
            local lua_products = {}
            local lua_ingredients = {}
            for i, lua_product in pairs(child_products) do
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
            for i, lua_ingredient in pairs(child_ingredients) do
                local ingredient = Product(lua_ingredient)
                local ingredient_key = ingredient:getTableKey()
                local ingredient_amount = 0
                if is_block then
                    ingredient_amount = lua_ingredient.amount or 0
                else
                    ingredient_amount = ingredient:getAmount()
                    ---si constant compte comme un produit (recipe rocket)
                    if lua_ingredient.constant then
                        ingredient_amount = ingredient:getAmount(child)
                    end
                end
                
                RowFlows.add(lua_ingredients, ingredient_key, lua_ingredient, ingredient_amount)
            end

            if not (block.by_product == false) then
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

                    local value = lua_product.amount * row_factor
                    local cell_value = value
                    row:add_value(col_header, cell_value)

                    matrix.column_sum[product_key] = ( matrix.column_sum[product_key] or 0 ) + value

                    if rowParameters.contraint ~= nil and rowParameters.contraint.name == name then
                        rowParameters.contraint.name = col_name
                    end

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
                        ---case of the equivalent value, we create a new element
                        if lua_products[ingredient_key].amount > 0 and lua_ingredients[ingredient_key].amount> 0 and
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
                    local value = - lua_ingredients[ingredient_key].amount * row_factor
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

                    local value = -lua_ingredient.amount * row_factor
                    local cell_value = value
                    row:add_value(col_header, cell_value)

                    matrix.column_sum[ingredient_key] = ( matrix.column_sum[ingredient_key] or 0 ) + value

                    if rowParameters.contraint ~= nil and rowParameters.contraint.name == name then
                        rowParameters.contraint.name = col_name
                    end
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

                    local value = lua_product.amount * row_factor
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

        ---end loop recipes

        matrix = TemperatureLinks.build(matrix, block)
        if block.by_product ~= false then matrix.external_supplies = block.matrix_supplies end
        matrix.objectives = block.objectives
        return matrix
    end
    return nil
end
