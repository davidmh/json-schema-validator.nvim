# json-schema-validator.nvim

A Neovim plugin for validating JSON Schemas.

When working with JSON Schemas, I find myself having to go back and forth
between Neovim an one of the multiple online services that validate JSON
Schemas. This plugin aims to solve that problem by providing a simple way to
validate JSON Schemas directly in Neovim.

## Installation

With lazy.nvim:

```lua
{
  "davidmh/json-schema-validator.nvim",
  opts = {},
  ft = { "json" },
}
```

## Usage

Run the command `:JsonSchemaValidate` while editing a JSON Schema file.

## Dependencies

This plugin assumes you have the `ajv` command line tool installed. You can install it
using npm:

```shell
npm install -g ajv-cli
```

### TODO

- [ ] Tests and linting with GitHub Actions
- [ ] Provide alternative ways to deal with the command output
- [ ] Provide an option to parse the JSON Schema file, e.g. neovim doesn't support jsonc
