local helpers = require('helpers')
local selection = require('kiro.selection')
local terminal = require('kiro.terminal')

local function buffer_with(lines, ft)
  vim.cmd('enew!')
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.bo.filetype = ft or 'lua'
end

local function keys(seq)
  vim.cmd('exe "normal! ' .. seq .. '\\<Esc>"')
end

describe('selection capture', function()
  before_each(function()
    buffer_with({ 'local a = 1', 'local b = 2', 'return a + b' })
  end)
  after_each(helpers.cleanup)

  it('captures a single-line character-wise selection', function()
    keys('ggwve')
    local s = selection.capture()
    assert.are.equal('a =', s.text)
    assert.are.equal('character-wise', s.selection_type)
    assert.are.equal(1, s.start_line)
    assert.are.equal(1, s.end_line)
    assert.are.equal('lua', s.filetype)
    assert.are.equal('[unnamed Neovim buffer]', s.filename)
  end)

  it('captures a multi-line character-wise selection', function()
    keys('gg4lvj')
    local s = selection.capture()
    assert.are.equal('l a = 1\nlocal', s.text)
    assert.are.equal(2, s.end_line)
  end)

  it('captures a line-wise selection', function()
    keys('ggVj')
    local s = selection.capture()
    assert.are.equal('line-wise', s.selection_type)
    assert.are.equal('local a = 1\nlocal b = 2', s.text)
  end)

  it('captures a block-wise selection', function()
    keys('gg0\\<C-v>jj2l')
    local s = selection.capture()
    assert.are.equal('block-wise', s.selection_type)
    assert.are.equal('loc\nloc\nret', s.text)
  end)

  it('normalises a reversed selection', function()
    keys('2G$vgg0')
    local s = selection.capture()
    assert.are.equal(1, s.start_line)
    assert.are.equal(2, s.end_line)
    assert.are.equal('local a = 1\nlocal b = 2', s.text)
  end)

  it('uses the real file name and defaults the file type to text', function()
    local path = vim.fn.tempname()
    vim.fn.writefile({ 'x = 1' }, path)
    vim.cmd('edit ' .. path)
    vim.bo.filetype = ''
    keys('V')
    local s = selection.capture()
    assert.are.equal(vim.fn.fnamemodify(path, ':p'), s.filename)
    assert.are.equal('text', s.filetype)
  end)

  it('handles multibyte text before the end of the selection', function()
    buffer_with({ 'héllo wörld' })
    keys('gg0viw')
    assert.are.equal('héllo', selection.capture().text)
  end)

  it('returns nil without a selection or for blank text', function()
    vim.cmd('enew!')
    assert.is_nil(selection.capture())
    buffer_with({ '    ', 'x' })
    keys('ggV')
    assert.is_nil(selection.capture())
  end)
end)

describe('selection payloads', function()
  local base = {
    text = 'print(1)',
    filename = '/tmp/a.lua',
    filetype = 'lua',
    start_line = 3,
    end_line = 3,
    selection_type = 'line-wise',
  }

  it('builds the menu payload (single line)', function()
    local payload = selection.menu_payload(base, 'REQ')
    assert.are.equal(
      'REQ\n\n'
        .. 'Consider the relevant context from our existing conversation.'
        .. '\n\nSource information:'
        .. '\n- File: /tmp/a.lua'
        .. '\n- Location: line 3'
        .. '\n- File type: lua'
        .. '\n- Selection type: line-wise'
        .. '\n\nResponse requirements:'
        .. '\n1. Address the requested action first.'
        .. '\n2. Explain assumptions, risks and important edge cases.'
        .. '\n3. Provide proposed code or a diff when useful.'
        .. '\n4. Do not modify, create, rename or delete files.'
        .. '\n5. Do not execute shell commands.'
        .. '\n6. Do not apply changes directly.'
        .. '\n\n```lua\nprint(1)\n```',
      payload
    )
  end)

  it('uses a line range for multi-line selections', function()
    local s = vim.tbl_extend('force', base, { start_line = 2, end_line = 5 })
    assert.is_truthy(selection.menu_payload(s, 'REQ'):find('- Location: lines 2-5', 1, true))
  end)

  it('uses a four-backtick fence when the text contains one', function()
    local s = vim.tbl_extend('force', base, { text = '```lua\nx\n```' })
    local payload = selection.menu_payload(s, 'REQ')
    assert.is_truthy(payload:find('\n\n````lua\n```lua\nx\n```\n````', 1, true))
    assert.is_truthy(selection.ask_payload(s, 'Q'):find('````lua\n', 1, true))
  end)

  it('builds the ask payload', function()
    local s = vim.tbl_extend('force', base, { start_line = 2, end_line = 4 })
    assert.are.equal(
      'Q\n\n'
        .. 'Use the context of our existing conversation when relevant.'
        .. '\n\nSource information:'
        .. '\n- File: /tmp/a.lua'
        .. '\n- Lines: 2-4'
        .. '\n- File type: lua'
        .. '\n- Selection type: line-wise'
        .. '\n\nDo not modify files or execute commands. '
        .. 'Return proposed changes in the chat only.'
        .. '\n\n```lua\nprint(1)\n```',
      selection.ask_payload(s, 'Q')
    )
  end)

  it('maps actions 1-8 to prompts and action 9 to the user question', function()
    for action = 1, 8 do
      assert.is_true(#selection.action_prompt(action) > 20)
    end
    assert.are.equal(
      'Review the selected code for correctness, clarity, '
        .. 'maintainability, testability and design quality.',
      selection.action_prompt(1)
    )
    assert.is_truthy(selection.action_prompt(4):find('Do not modify files.', 1, true))

    local original = selection.ui.input
    selection.ui.input = function()
      return '  why?  '
    end
    assert.are.equal('why?', selection.action_prompt(9))
    selection.ui.input = original

    assert.are.equal('', selection.action_prompt(0))
    assert.are.equal('', selection.action_prompt(10))
  end)
end)

describe('selection menu flow', function()
  local sent, original_ui, original_send

  before_each(function()
    sent = {}
    original_ui = selection.ui
    original_send = terminal.send_text
    terminal.send_text = function(text)
      sent[#sent + 1] = text
    end
    vim.cmd('enew!')
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'foo()', 'bar()' })
    vim.bo.filetype = 'lua'
    keys('ggVj')
  end)

  after_each(function()
    selection.ui = original_ui
    terminal.send_text = original_send
    helpers.cleanup()
  end)

  it('sends the payload for the chosen action', function()
    selection.ui = {
      inputlist = function(options)
        assert.are.equal('Kiro action for selected text:', options[1])
        assert.are.equal('0. Cancel', options[#options])
        return 5
      end,
    }
    require('kiro').selection_menu()
    assert.are.equal(1, #sent)
    assert.is_truthy(sent[1]:find('Find bugs', 1, true))
    assert.is_truthy(sent[1]:find('```lua\nfoo()\nbar()\n```', 1, true))
  end)

  it('cancels on 0, out-of-range and empty custom question', function()
    local messages, restore = helpers.capture_echo()
    for _, choice in ipairs({ 0, 10 }) do
      selection.ui = {
        inputlist = function()
          return choice
        end,
      }
      require('kiro').selection_menu()
    end
    selection.ui = {
      inputlist = function()
        return 9
      end,
      input = function()
        return ''
      end,
    }
    require('kiro').selection_menu()
    restore()
    assert.are.same({}, sent)
    assert.are.equal('Kiro action cancelled', messages[1].text)
    assert.are.equal('Kiro action cancelled', messages[3].text)
  end)

  it('ask_selection sends the question', function()
    selection.ui = {
      input = function()
        return 'what does this do?'
      end,
    }
    require('kiro').ask_selection()
    assert.are.equal(1, #sent)
    assert.are.equal('what does this do?\n\n', sent[1]:sub(1, 20))
    assert.is_truthy(sent[1]:find('- Lines: 1-2', 1, true))
  end)

  it('ask_selection cancels on an empty question', function()
    selection.ui = {
      input = function()
        return '  '
      end,
    }
    local messages, restore = helpers.capture_echo()
    require('kiro').ask_selection()
    restore()
    assert.are.same({}, sent)
    assert.are.equal('Kiro question cancelled', messages[1].text)
  end)

  it('warns when there is no valid selection', function()
    vim.cmd('enew!')
    local messages, restore = helpers.capture_echo()
    require('kiro').selection_menu()
    require('kiro').ask_selection()
    restore()
    assert.are.same({}, sent)
    assert.are.equal('No valid Visual selection is available', messages[1].text)
    assert.are.equal('No valid Visual selection is available', messages[2].text)
  end)
end)
