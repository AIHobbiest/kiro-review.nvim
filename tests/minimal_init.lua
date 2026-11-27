-- Minimal init used by the test-suite:
--   nvim --headless -u tests/minimal_init.lua \
--     -c "PlenaryBustedDirectory tests/ { minimal_init = 'tests/minimal_init.lua', sequential = true }"

local root = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h:h')

vim.opt.runtimepath:prepend(root)
package.path = root .. '/tests/?.lua;' .. package.path

local plenary = vim.env.PLENARY_DIR
if not plenary or plenary == '' then
  plenary = vim.fn.stdpath('data') .. '/lazy/plenary.nvim'
end
vim.opt.runtimepath:append(plenary)

-- The stub kiro-cli must win over any real installation.
vim.env.PATH = root .. '/tests/bin:' .. vim.env.PATH

vim.opt.swapfile = false
vim.opt.hidden = true
vim.g.mapleader = ' '

vim.cmd('runtime plugin/plenary.vim')
vim.cmd('runtime plugin/kiro.lua')

-- Never look at (or kill) real kiro-cli processes of the machine running the
-- tests.
require('kiro.process').runner.systemlist = function()
  return {}
end
require('kiro.process').runner.system = function()
  return ''
end
