local config = require("json-schema-validator.config")
local utils = require("json-schema-validator.utils")

local M = {}

---@type table<string, JsonSchemaValidatorState>
local state_by_buffer_id = {}

---@param args vim.api.keyset.create_autocmd.callback_args
local on_text_changed = utils.debounce(function(args)
    vim.schedule(function()
        local state = state_by_buffer_id[args.buf]

        -- update hidden test file with the contents of the scratch buffer
        local lines = vim.api.nvim_buf_get_lines(args.buf, 0, -1, false)
        vim.fn.writefile(lines, state.hidden_test_file_path)

        utils.run_validation(state)
    end)
end, 600)

---@param opts JSONSchemaValidatorOptions
function M.setup(opts)
    config = vim.tbl_deep_extend("force", config, opts or {})

    -- TODO: Can this command be limited to only JSON files?
    vim.api.nvim_create_user_command("JsonSchemaValidate", function()
        local source_file_path = vim.fn.expand("%:p")
        local hidden_test_file_path = vim.fn.tempname() .. ".json"

        -- Initialize a hidden file to pass to the command with the same contents as the scratch buffer
        vim.fn.writefile({}, hidden_test_file_path)

        local scratch_buffer_id = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(scratch_buffer_id, "[Scratch Buffer] JSON Schema Validator")
        vim.api.nvim_buf_set_option(scratch_buffer_id, "filetype", "json")
        vim.api.nvim_open_win(scratch_buffer_id, true, { split = "right" })

        ---@type JsonSchemaValidatorState
        local state = {
            source_file_path = source_file_path,
            hidden_test_file_path = hidden_test_file_path,
            winid = vim.api.nvim_get_current_win(),
            bufnr = scratch_buffer_id,
        }

        state_by_buffer_id[scratch_buffer_id] = state

        vim.api.nvim_create_autocmd("TextChanged", {
            buffer = scratch_buffer_id,
            callback = on_text_changed,
        })
        vim.api.nvim_create_autocmd("TextChangedI", {
            buffer = scratch_buffer_id,
            callback = on_text_changed,
        })

        -- Delete buffer and file on window close
        vim.api.nvim_create_autocmd("BufWinLeave", {
            buffer = scratch_buffer_id,
            callback = function(ev)
                state_by_buffer_id[ev.buf] = nil
                os.remove(state.hidden_test_file_path)
                vim.schedule(function()
                    vim.api.nvim_buf_delete(ev.buf, {})
                end)
                return true
            end,
        })
    end, { desc = "Validate JSON schema" })
end

return M
