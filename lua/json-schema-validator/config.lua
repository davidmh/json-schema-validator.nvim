---@class JSONSchemaValidatorOptions
---@field command fun(state: JsonSchemaValidatorState): string[]
---@field namespace integer

---@class JsonSchemaValidatorState
---@field source_file_path string
---@field hidden_test_file_path string
---@field winid integer
---@field bufnr integer

local namespace = vim.api.nvim_create_namespace("json-schema-validator")

---@type JSONSchemaValidatorOptions
return {
    command = function(state)
        vim.validate({
            source_file_path = { state.source_file_path, "string" },
            hidden_test_file_path = { state.hidden_test_file_path, "string" },
        })
        return {
            "ajv",
            "validate",
            "-s",
            state.source_file_path,
            "-d",
            state.hidden_test_file_path,
            "--errors=json",
        }
    end,
    namespace = namespace,
}
