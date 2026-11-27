local M = {}

-- Print a message (not added to :messages history, like `:echo`).
function M.echo(text, hl)
  vim.api.nvim_echo({ { text, hl } }, false, {})
end

function M.warn(text)
  M.echo(text, 'WarningMsg')
end

function M.error(text)
  M.echo(text, 'ErrorMsg')
end

return M
