local config = require("json-schema-validator.config")

local namespace = vim.api.nvim_create_namespace("json-schema-validator")

local M = {}

---@class JSONSchemaValidatorResponseEntry
---@field instancePath string
---@field keyword string
---@field message string
---@field params table<string, table<string, string>>
---@field schemaPath string

--- Builds a tree-sitter query from the response entry, using the instancePath to determine a diagnostic target
---@param entry JSONSchemaValidatorResponseEntry
---@return string
function M.tree_sitter_query_from_response(entry)
    local path = vim.split(entry.instancePath:gsub("^/", ""), "/")
    local query = ""
    local conditions = {}

    -- Start building the query from the innermost element
    for i = #path, 1, -1 do
        local component = path[i]
        local column_name = string.format("column-%d", i)

        if query == "" then
            query =
                string.format("(pair key: (string (string_content) @%s) value: (_) @diagnostic-target)", column_name)
        else
            query = string.format("(pair key: (string (string_content) @%s) value: (object %s))", column_name, query)
        end
        table.insert(conditions, string.format('(#eq? @%s "%s")', column_name, component))
    end

    return string.format("(%s %s)", query, table.concat(conditions, " "))
end

--- Parses the error response from the ajv cli into tree-sitter queries to find
--- the exact locations for the properties referenced in the errors
---@param response_entries table<number, JSONSchemaValidatorResponseEntry>
---@param state JsonSchemaValidatorState
function M.set_diagnostics(response_entries, state)
    local diagnostics = {}

    local tree = vim.treesitter.get_parser(state.bufnr, "json")
    if not tree then
        vim.notify(
            "Could parse JSON with tree-sitter, have you installed the parser?",
            vim.log.levels.WARN,
            { title = "JSON Schema Validator" }
        )
        return
    end

    local root = tree:parse()[1]:root()

    for _, entry in ipairs(response_entries) do
        if entry.instancePath == "" then
            -- Insert the diagnostic at the root level
            table.insert(diagnostics, M.build_diagnostic(root, entry))
        else
            local node = M.find_diagnostic_target_node(entry, root)

            if node then
                table.insert(diagnostics, M.build_diagnostic(node, entry))
            else
                vim.notify(
                    string.format("Could not find node for\n%s", vim.inspect(entry)),
                    vim.log.levels.WARN,
                    { title = "JSON Schema Validator" }
                )
            end
        end
    end

    vim.diagnostic.set(namespace, state.bufnr, diagnostics)
end

--- Builds a diagnostic object from the node and entry
---@param node TSNode
---@param entry JSONSchemaValidatorResponseEntry
function M.build_diagnostic(node, entry)
    local start_row, start_col, end_row, end_col = node:range()
    return {
        lnum = start_row,
        col = start_col,
        end_lnum = end_row,
        end_col = end_col,
        severity = vim.diagnostic.severity.ERROR,
        message = string.format(
            "%s %s\n%s",
            string.gsub(entry.instancePath, "/", "."),
            entry.message,
            table.concat(
                M.dict_to_seq(entry.params, function(k, v)
                    return string.format("- %s: %s", k, vim.inspect(v))
                end),
                "\n"
            )
        ),
        source = "json-schema-validator",
    }
end

--- Finds the target node for a given diagnostic entry in the tree-sitter parse tree
--- by using the instancePath to build a query with two variants:
--- 1. The original instancePath
--- 2. The instancePath with the last component removed, in case the report is about a missing property
---@param entry JSONSchemaValidatorResponseEntry
---@param root TSNode
---@return TSNode|nil
function M.find_diagnostic_target_node(entry, root)
    local parent_path = vim.split(entry.instancePath, "/")
    table.remove(parent_path, #parent_path)

    local parent_entry = vim.tbl_extend("force", {}, entry, { instancePath = table.concat(parent_path, "/") })

    for _, entry_variant in ipairs({ entry, parent_entry }) do
        local query = M.tree_sitter_query_from_response(entry_variant)
        local parsed_query = vim.treesitter.query.parse("json", query)

        for id, node in parsed_query:iter_captures(root, 0, -1) do
            if parsed_query.captures[id] == "diagnostic-target" then
                return node
            end
        end
    end
end

---@param state JsonSchemaValidatorState
function M.run_validation(state)
    local command = config.command(state)

    vim.system(command, {
        text = true,
        stdout = function(_, data)
            if data then
                vim.schedule(function()
                    vim.diagnostic.reset(namespace, state.bufnr)
                end)
            end
        end,
        stderr = function(_, data)
            if data then
                vim.schedule(function()
                    local ok, response_entries = pcall(vim.json.decode, data)
                    if ok then
                        M.set_diagnostics(response_entries, state)
                    else
                        vim.diagnostic.reset(namespace, state.bufnr)
                        vim.diagnostic.set(namespace, state.bufnr, {
                            {
                                lnum = 0,
                                col = 0,
                                end_lnum = 0,
                                end_col = 0,
                                severity = vim.diagnostic.severity.ERROR,
                                message = data,
                                source = "json-schema-validator",
                            },
                        })
                    end
                end)
            end
        end,
    })
end

function M.debounce(fn, delay)
    local timer = vim.uv.new_timer()
    local last_call = 0

    return function(...)
        local args = { ... }
        local now = vim.uv.now()

        if now - last_call < delay then
            if timer then
                timer:stop()
            end
        end

        last_call = now

        if timer then
            timer:start(delay, 0, function()
                fn(unpack(args))
            end)
        end
    end
end

---@param tbl table<string, any>
---@param fn fun(key: string, value: any): any
function M.dict_to_seq(tbl, fn)
    local result = {}
    for k, v in pairs(tbl) do
        table.insert(result, fn(k, v))
    end
    return result
end

return M
