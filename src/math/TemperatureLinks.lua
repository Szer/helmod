local TemperatureSupply = require "math.balance.TemperatureSupply"
local TemperatureLinks = {recipeName="helmod-temperature-convert"}

---@param output MatrixHeader
---@param input MatrixHeader
---@param byProduct boolean?
---@return boolean
local function compatible(output, input, byProduct)
    if output.key == input.key then return false end
    if byProduct == false then return TemperatureSupply.compatible(input.product, output.product) end
    return TemperatureSupply.compatible(output.product, input.product)
end

---@param matrix Matrix
---@param from MatrixHeader
---@param to MatrixHeader
---@param ingredient boolean
---@return MatrixRowParameters
local function addTransfer(matrix, from, to, ingredient)
    local row = MatrixRow("recipe", TemperatureLinks.recipeName, "")
    row.header.is_ingredient = ingredient
    row.header.primary, row.header.secondary = from.product, to.product
    row:add_value(from, -1)
    row:add_value(to, 1)
    local parameters = MatrixRowParameters()
    matrix:add_row(row, parameters)
    return parameters
end

---@class TemperatureDemandGroup
---@field input MatrixHeader
---@field outputs MatrixHeader[]
---@field yields table<integer,number>
---@field choices integer
---@field order integer

---@param linked Matrix
---@param row MatrixRow
---@param outputs table<string,MatrixHeader>
---@param previousInputs table<string,table<string,MatrixHeader>>
---@param byProduct boolean?
local function addSupplyTransfers(linked, row, outputs, previousInputs, byProduct)
    ---@type table<MatrixHeader,TemperatureDemandGroup>
    local byInput = {}
    ---@type TemperatureDemandGroup[]
    local groups = {}
    for _, output in pairs(outputs) do
        for _, input in pairs(previousInputs[output.product.name] or {}) do
            if compatible(output, input, byProduct) then
                local group = byInput[input]
                if not group then
                    group = {input=input, outputs={}, yields={}, order=#groups + 1, choices=0}
                    byInput[input] = group
                    table.insert(groups, group)
                    local direct = row:get_value(input)
                    if direct > 0 then
                        group.yields[linked:get_column_index(input)] = direct
                        group.choices = 1
                    end
                end
                table.insert(group.outputs, output)
                group.yields[linked:get_column_index(output)] = row:get_value(output)
                group.choices = group.choices + 1
            end
        end
    end
    -- Reserve the limited temperatures first when the same row also supplies a wider range.
    if #groups > 1 then
        table.sort(groups, function(left, right)
            if left.choices == right.choices then return left.order < right.order end
            return left.choices < right.choices
        end)
    end
    for _, group in ipairs(groups) do
        for _, output in ipairs(group.outputs) do
            local parameters = addTransfer(linked, output, group.input, false)
            if group.choices > 1 then
                parameters.temperature_transfer = {output=linked:get_column_index(output), yields=group.yields}
            end
        end
    end
end

---@param matrix Matrix
---@param byProduct boolean?
---@param ordered boolean Use forward and return transfers around an ordered supplier row
---@return Matrix
function TemperatureLinks.build(matrix, byProduct, ordered)
    local linked = Matrix()
    linked.column_sum = matrix.column_sum
    local previousInputs, previousOutputs = {}, {}
    for index, values in ipairs(matrix.rows) do
        local header = matrix.headers[index]
        local original = MatrixRow(header.type, header.name, header.quality, header.tooltip)
        original.header = header
        original.columns, original.columnIndex, original.values = matrix.columns, matrix.columnIndex, values

        local inputs, outputs = {}, {}
        for col, header in ipairs(matrix.columns) do
            local value = values[col] or 0
            local fluid = header.product
            if header.key and fluid.type == "fluid" then
                if value > 0 then
                    outputs[header.key] = header
                    previousOutputs[fluid.name] = previousOutputs[fluid.name] or {}
                    previousOutputs[fluid.name][header.key] = header
                elseif value < 0 then
                    inputs[header.key] = header
                end
            end
        end

        addSupplyTransfers(linked, original, outputs, previousInputs, byProduct)
        linked:add_row(original, matrix.parameters[index])
        if ordered then
            for _, output in pairs(outputs) do
                for _, input in pairs(previousInputs[output.product.name] or {}) do
                    if compatible(output, input, byProduct) then addTransfer(linked, input, output, false) end
                end
            end
        end
        for _, input in pairs(inputs) do
            local name = input.product.name
            previousInputs[name] = previousInputs[name] or {}
            previousInputs[name][input.key] = input
            for _, output in pairs(previousOutputs[name] or {}) do
                if compatible(output, input, byProduct) then
                    addTransfer(linked, output, input, true)
                    if ordered then addTransfer(linked, input, output, true) end
                end
            end
        end
    end
    return linked
end

return TemperatureLinks
