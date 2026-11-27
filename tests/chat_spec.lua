local helpers = require('helpers')
local kiro = require('kiro')
local terminal = require('kiro.terminal')

local function wait_for_text(text)
  return vim.wait(3000, function()
    local info = terminal.info()
    return info.exists and helpers.buffer_text(info.buffer):find(text, 1, true) ~= nil
  end, 20)
end

describe('chat commands', function()
  local sent

  before_each(function()
    sent = {}
  end)

  after_each(function()
    helpers.cleanup()
  end)

  it('send_text delivers text to the terminal', function()
    kiro.send_text('hello from the test')
    assert.is_true(wait_for_text('hello from the test'))
  end)

  it('send_text ignores empty text', function()
    kiro.send_text('   ')
    kiro.send_text('')
    assert.is_false(terminal.info().exists)
  end)

  it('new_chat sends /chat new', function()
    kiro.new_chat()
    assert.is_true(wait_for_text('/chat new'))
  end)

  it('resume_picker restarts the terminal with the picker', function()
    kiro.open()
    local first = terminal.info()
    kiro.resume_picker()
    local second = terminal.info()
    assert.is_true(second.running)
    assert.are_not.equal(first.job, second.job)
  end)

  describe('review', function()
    local original

    before_each(function()
      original = terminal.send_text
      terminal.send_text = function(text)
        sent[#sent + 1] = text
      end
    end)

    after_each(function()
      terminal.send_text = original
    end)

    it('sends the advisory prompt for a saved file', function()
      local path = vim.fn.tempname() .. '.lua'
      vim.fn.writefile({ 'print(1)' }, path)
      vim.cmd('edit ' .. path)
      kiro.review()
      assert.are.same({
        'Review the following file in read-only advisory mode. '
          .. 'Do not modify files or execute commands. '
          .. 'Report findings and proposed changes in the chat only. '
          .. 'File: '
          .. vim.fn.fnamemodify(path, ':p'),
      }, sent)
    end)

    it('rejects an unnamed buffer', function()
      vim.cmd('enew')
      local messages, restore = helpers.capture_echo()
      kiro.review()
      restore()
      assert.are.same({}, sent)
      assert.are.equal('The current buffer does not have a filename', messages[1].text)
    end)

    it('rejects a modified buffer', function()
      local path = vim.fn.tempname()
      vim.fn.writefile({ 'x' }, path)
      vim.cmd('edit ' .. path)
      vim.api.nvim_buf_set_lines(0, 0, -1, false, { 'changed' })
      local messages, restore = helpers.capture_echo()
      kiro.review()
      restore()
      assert.are.same({}, sent)
      assert.are.equal('Save the file before asking Kiro to review it', messages[1].text)
    end)
  end)

  it('ask sends the typed question and cancels on empty input', function()
    local original_input = vim.fn.input
    local original_send = terminal.send_text
    terminal.send_text = function(text)
      sent[#sent + 1] = text
    end

    vim.fn.input = function()
      return '  what is this?  '
    end
    kiro.ask()
    vim.fn.input = function()
      return '   '
    end
    kiro.ask()

    vim.fn.input = original_input
    terminal.send_text = original_send
    assert.are.same({ 'what is this?' }, sent)
  end)
end)
