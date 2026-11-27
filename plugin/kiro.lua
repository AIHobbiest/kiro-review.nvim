-- kiro-review.nvim: persistent Kiro CLI integration.
-- Kept lightweight on purpose: the heavy modules are required only when a
-- command, mapping or function is actually used.

if vim.g.loaded_kiro_nvim_integration then
  return
end

if vim.fn.has('nvim-0.8') == 0 then
  vim.api.nvim_echo({ { 'kiro-review.nvim requires Neovim 0.8 or newer', 'WarningMsg' } }, true, {})
  return
end

vim.g.loaded_kiro_nvim_integration = 1

-- Commands -------------------------------------------------------------------

local commands = {
  KiroOpen = 'open',
  KiroClose = 'close',
  KiroToggle = 'toggle',
  KiroStop = 'stop',
  KiroNew = 'new_chat',
  KiroResumePicker = 'resume_picker',
  KiroAsk = 'ask',
  KiroReview = 'review',
  KiroSelection = 'selection_menu',
  KiroAskSelection = 'ask_selection',
  KiroKillAll = 'kill_all',
  KiroStatus = 'status',
}

for name, fn in pairs(commands) do
  vim.api.nvim_create_user_command(name, function()
    require('kiro')[fn]()
  end, { desc = 'kiro-review.nvim: ' .. fn })
end

-- Vimscript compatibility ----------------------------------------------------
-- Keeps `:call KiroChatWindow()` etc. working for init.vim users.

local functions = {
  KiroChatWindow = 'open',
  KiroCloseWindow = 'close',
  KiroToggleWindow = 'toggle',
  KiroStop = 'stop',
  KiroAsk = 'ask',
  KiroNewChat = 'new_chat',
  KiroResumePicker = 'resume_picker',
  KiroReviewCurrentFile = 'review',
  KiroSelectionMenu = 'selection_menu',
  KiroAskSelection = 'ask_selection',
  KiroKillAll = 'kill_all',
  KiroStatus = 'status',
}

for name, fn in pairs(functions) do
  -- `return` keeps the boolean result of KiroChatWindow() available.
  vim.cmd(string.format(
    [[
    function! %s() abort
      return v:lua.require'kiro'.%s()
    endfunction
  ]],
    name,
    fn
  ))
end

vim.cmd([[
  function! KiroSendText(text) abort
    return v:lua.require'kiro'.send_text(a:text)
  endfunction
]])

-- Default mappings (disable with setup({ mappings = false }) or
-- `let g:kiro_no_mappings = 1`).
require('kiro.mappings').apply()
