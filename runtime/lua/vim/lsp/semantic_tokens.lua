local M = {}
local util = require "vim.lsp.util"
local ns = vim.api.nvim_create_namespace("lsp-semantic-tokens")

local semantic_tokens = {}

local function modifiers_from_number(x, modifiers_table)
  local function get_bit(n, k)
    -- Based on/from https://stackoverflow.com/a/26230537
    -- (n >> k) & 1
    return bit.band(bit.rshift(n, k), 1)
  end

  local modifiers = {}
  for i = 0, #modifiers_table - 1 do
    local bit = get_bit(x, i)
    if bit == 1 then
      table.insert(modifiers, 1, modifiers_table[i + 1])
    end
  end

  return modifiers
end

M.token_map = {
  type = "Type"
}

M.modifiers_map = {
  deprecated = "LspDeprecated",
  globalScope = "semshiGlobal"
}

local function highlight(buf, token, hl)
  vim.highlight.range(buf, ns, hl, {token.line, token.start_char}, {token.line, token.start_char + token.length})
  --vim.api.nvim_buf_set_extmark(
  --buf,
  --ns,
  --token.line,
  --token.start_char,
  --{
  --end_line = token.line,
  --end_col = token.start_char + token.length,
  --hl_group = hl,
  ----ephemeral = true,
  --priority = 105 -- A little higher than tree-sitter
  --}
  --)
end

function M.highlight_token(buf, token)
  local ft = vim.api.nvim_buf_get_option(buf, "filetype")
  local hl = M.token_map[ft .. token.type] or M.token_map[token.type]
  if hl then
    highlight(buf, token, hl)
  end
  for _, m in pairs(token.modifiers) do
    local hl =
      M.modifiers_map[ft .. token.type .. m] or M.modifiers_map[token.type .. m] or M.modifiers_map[ft .. m] or
      M.modifiers_map[m]
    if hl then
      highlight(buf, token, hl)
    end
  end
end

function M._handle_full(client_id, bufnr, response)
  local client = vim.lsp.get_client_by_id(client_id)
  if not client then
    return
  end
  local legend = client.server_capabilities.semanticTokensProvider.legend
  local token_types = legend.tokenTypes
  local token_modifiers = legend.tokenModifiers
  local data = response.data

  local tokens = {}
  local line, start_char = nil, 0
  for i = 1, #data, 5 do
    local delta_line = data[i]
    line = line and line + delta_line or delta_line
    local delta_start = data[i + 1]
    start_char = delta_line == 0 and start_char + delta_start or delta_start

    -- data[i+3] +1 because Lua tables are 1-indexed
    local token_type = token_types[data[i + 3] + 1]
    local modifiers = modifiers_from_number(data[i + 4], token_modifiers)

    local token = {
      line = line,
      start_char = start_char,
      length = data[i + 2],
      type = token_type,
      modifiers = modifiers
    }
    tokens[line + 1] = tokens[line + 1] or {}
    table.insert(tokens[line + 1], token)

    if token_type then
      M.highlight_token(bufnr, token)
    end
  end

  if semantic_tokens[client_id] then
    semantic_tokens[client_id][bufnr] = tokens
  else
    semantic_tokens[client_id] = {[bufnr] = tokens}
  end
  --vim.api.nvim__buf_redraw_range(bufnr, start_row, start_row + new_end + 1)
end

function M.on_refresh(client_id)
  local bufnr = vim.fn.bufnr()
  local params = {textDocument = util.make_text_document_params()}
  vim.lsp.buf_request(bufnr, "textDocument/semanticTokens/full", params, M._handle_response)
end

function M.get(client_id, bufnr)
  return semantic_tokens[client_id][bufnr or vim.fn.bufnr()]
end

return M
