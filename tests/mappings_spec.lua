local helpers = require('helpers')
local kiro = require('kiro')

local NORMAL = { 'kc', 'ko', 'kh', 'kq', 'kr', 'kn', 'kl', 'ks' }

local function mapped(mode, lhs)
  return vim.fn.maparg(lhs, mode) ~= ''
end

local function count_leader_maps(mode)
  local n = 0
  for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
    if map.lhs:find('k', 1, true) and map.desc and map.desc:find('^Kiro') then
      n = n + 1
    end
  end
  return n
end

describe('mappings', function()
  after_each(function()
    vim.g.kiro_no_mappings = nil
    helpers.cleanup()
    kiro.setup({})
  end)

  it('are installed by default in normal, visual and terminal mode', function()
    for _, key in ipairs(NORMAL) do
      assert.is_true(mapped('n', '<leader>' .. key), key)
    end
    assert.is_true(mapped('x', '<leader>ka'))
    assert.is_true(mapped('x', '<leader>kq'))
    assert.is_true(mapped('t', '<Esc><Esc>'))
    assert.is_true(mapped('t', '<C-q>'))
  end)

  it('are removed by setup({ mappings = false })', function()
    kiro.setup({ mappings = false })
    for _, key in ipairs(NORMAL) do
      assert.is_false(mapped('n', '<leader>' .. key), key)
    end
    assert.is_false(mapped('x', '<leader>ka'))
    assert.is_false(mapped('t', '<C-q>'))
  end)

  it('are restored by setup({ mappings = true })', function()
    kiro.setup({ mappings = false })
    kiro.setup({ mappings = true })
    assert.is_true(mapped('n', '<leader>kc'))
  end)

  it('are skipped when g:kiro_no_mappings is set', function()
    vim.g.kiro_no_mappings = 1
    kiro.setup({})
    assert.is_false(mapped('n', '<leader>kc'))
  end)

  it('are not duplicated when applied repeatedly', function()
    local before = count_leader_maps('n')
    kiro.setup({})
    kiro.setup({})
    assert.are.equal(before, count_leader_maps('n'))
    assert.are.equal(8, before)
  end)

  it('the normal-mode mapping really opens Kiro', function()
    vim.api.nvim_feedkeys(vim.keycode('<leader>kc'), 'x', false)
    assert.is_true(require('kiro.terminal').info().running)
  end)
end)

describe('commands and vimscript wrappers', function()
  after_each(helpers.cleanup)

  it('defines all :Kiro* commands', function()
    for _, name in ipairs({
      'KiroOpen', 'KiroClose', 'KiroToggle', 'KiroStop', 'KiroNew', 'KiroResumePicker',
      'KiroAsk', 'KiroReview', 'KiroSelection', 'KiroAskSelection', 'KiroKillAll', 'KiroStatus',
    }) do
      assert.are.equal(2, vim.fn.exists(':' .. name), name)
    end
  end)

  it('defines all global functions', function()
    for _, name in ipairs({
      'KiroChatWindow', 'KiroCloseWindow', 'KiroToggleWindow', 'KiroStop', 'KiroSendText',
      'KiroAsk', 'KiroNewChat', 'KiroResumePicker', 'KiroReviewCurrentFile',
      'KiroSelectionMenu', 'KiroAskSelection', 'KiroKillAll', 'KiroStatus',
    }) do
      assert.are.equal(1, vim.fn.exists('*' .. name), name)
    end
  end)

  it(':call KiroChatWindow() / KiroToggleWindow() / KiroStop() work', function()
    vim.cmd('call KiroChatWindow()')
    assert.is_true(require('kiro.terminal').info().running)
    vim.cmd('call KiroToggleWindow()')
    assert.are.equal(-1, vim.fn.bufwinid(require('kiro.terminal').info().buffer))
    vim.cmd('call KiroStop()')
    assert.is_false(require('kiro.terminal').info().exists)
  end)

  it('KiroChatWindow() returns a truthy value', function()
    assert.is_truthy(vim.fn.KiroChatWindow())
  end)

  it('KiroSendText() delivers text', function()
    vim.fn.KiroSendText('via vimscript')
    local buf = require('kiro.terminal').info().buffer
    assert.is_true(vim.wait(3000, function()
      return helpers.buffer_text(buf):find('via vimscript', 1, true) ~= nil
    end, 20))
  end)

  it('KiroStatus works', function()
    local _, restore = helpers.capture_echo()
    vim.cmd('KiroStatus')
    restore()
  end)

  it('the load guard prevents loading twice', function()
    assert.are.equal(1, vim.g.loaded_kiro_nvim_integration)
    assert.has_no.errors(function()
      vim.cmd('runtime plugin/kiro.lua')
    end)
  end)
end)
