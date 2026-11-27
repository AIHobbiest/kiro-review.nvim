-- Default key mappings. apply() is idempotent: it first removes the mappings
-- it created earlier, then installs them again only if mappings are enabled
-- (setup({ mappings = false }) or g:kiro_no_mappings = 1 disables them).

local config = require('kiro.config')

local M = {}

local function call(fn)
  return ':lua require("kiro").' .. fn .. '()<CR>'
end

local function definitions()
  return {
    -- Normal mode
    { 'n', '<leader>kc', call('open'), 'Kiro: open chat' },
    { 'n', '<leader>ko', call('toggle'), 'Kiro: toggle window' },
    { 'n', '<leader>kh', call('close'), 'Kiro: hide window' },
    { 'n', '<leader>kq', call('ask'), 'Kiro: ask a question' },
    { 'n', '<leader>kr', call('review'), 'Kiro: review current file' },
    { 'n', '<leader>kn', call('new_chat'), 'Kiro: new conversation' },
    { 'n', '<leader>kl', call('resume_picker'), 'Kiro: load saved session' },
    { 'n', '<leader>ks', call('stop'), 'Kiro: stop' },
    -- Visual mode: <Esc> first so the '< and '> marks are set.
    { 'x', '<leader>ka', '<Esc>' .. call('selection_menu'), 'Kiro: selection actions' },
    { 'x', '<leader>kq', '<Esc>' .. call('ask_selection'), 'Kiro: ask about selection' },
    -- Terminal mode
    { 't', '<Esc><Esc>', [[<C-\><C-n>]], 'Kiro: leave terminal mode' },
    { 't', '<C-q>', [[<C-\><C-n>]] .. call('close'), 'Kiro: hide window' },
  }
end

local installed = {}

local function remove()
  for _, map in ipairs(installed) do
    pcall(vim.keymap.del, map[1], map[2])
  end
  installed = {}
end

function M.apply()
  remove()

  if not config.get('mappings') then
    return
  end

  for _, map in ipairs(definitions()) do
    vim.keymap.set(map[1], map[2], map[3], { silent = true, desc = map[4] })
    installed[#installed + 1] = { map[1], map[2] }
  end
end

return M
