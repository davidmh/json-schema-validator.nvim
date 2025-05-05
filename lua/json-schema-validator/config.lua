---@class JsonSchemaValidatorState
---@field source_file_path string
---@field hidden_test_file_path string
---@field winid integer
---@field bufnr integer

---@class JSONSchemaValidatorOptions
---@field max_errors integer
---@field command fun(state: JsonSchemaValidatorState): string[]
---@field setup fun(opts: JSONSchemaValidatorOptions): void
local M = {
    max_errors = math.huge,
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
            "--strict=false",
        }
    end,
}

function M.setup(opts)
    if opts.command then
        M.command = opts.command
    end
    if opts.max_errors ~= nil then
        M.max_errors = opts.max_errors
    end
end

return M
