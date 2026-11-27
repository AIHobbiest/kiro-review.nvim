local M = {}

--- Capture everything printed through util.echo/warn/error.
function M.capture_echo()
  local messages = {}
  local original = vim.api.nvim_echo
  vim.api.nvim_echo = function(chunks)
    local parts = {}
    for _, chunk in ipairs(chunks) do
      parts[#parts + 1] = chunk[1]
    end
    messages[#messages + 1] = { text = table.concat(parts), hl = chunks[1] and chunks[1][2] }
  end
  return messages, function()
    vim.api.nvim_echo = original
  end
end

--- Return to a clean editor state between tests.
function M.cleanup()
  require('kiro.terminal').stop()
  vim.cmd('silent! only')
  vim.cmd('silent! %bwipeout!')
  require('kiro.config').reset()
  vim.g.kiro_chat_width = nil
  vim.g.kiro_agent = nil
end

function M.buffer_text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
end

return M
