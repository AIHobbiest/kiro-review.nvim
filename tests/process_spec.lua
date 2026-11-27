local helpers = require('helpers')
local process = require('kiro.process')

describe('process helpers', function()
  local original
  local calls
  local pids
  local answer

  before_each(function()
    original = process.runner
    calls = {}
    pids = {}
    answer = '0'
    process.runner = {
      systemlist = function(cmd)
        calls[#calls + 1] = cmd
        return pids
      end,
      system = function(cmd)
        calls[#calls + 1] = cmd
        return ''
      end,
      sleep = function()
        calls[#calls + 1] = 'sleep'
      end,
      input = function()
        return answer
      end,
    }
  end)

  after_each(function()
    process.runner = original
  end)

  it('is not "running elsewhere" when no process exists', function()
    assert.is_false(process.is_running_elsewhere(-1))
  end)

  it('is "running elsewhere" when a process exists and we have no job', function()
    pids = { '123' }
    assert.is_true(process.is_running_elsewhere(-1))
    assert.is_true(process.is_running_elsewhere(0))
  end)

  it('is fine when the process is our own job', function()
    pids = { '123' }
    assert.is_false(process.is_running_elsewhere(5))
  end)

  it('option 1 kills existing processes and proceeds', function()
    answer = '1'
    local _, restore = helpers.capture_echo()
    local proceed = process.handle_existing()
    restore()
    assert.is_true(proceed)
    assert.are.same({
      'pkill -f "kiro-cli chat"',
      'pkill -f "kiro.*agent"',
      'sleep',
      'pkill -9 -f "kiro-cli chat"',
    }, calls)
  end)

  it('options 2 and 0 cancel without killing', function()
    local _, restore = helpers.capture_echo()
    for _, choice in ipairs({ '2', '0', '', 'x' }) do
      answer = choice
      assert.is_false(process.handle_existing())
    end
    restore()
    assert.are.same({}, calls)
  end)

  it('kill_all runs the same kill sequence', function()
    local _, restore = helpers.capture_echo()
    process.kill_all()
    restore()
    assert.are.same({
      'pkill -f "kiro-cli chat"',
      'pkill -f "kiro.*agent"',
      'sleep',
      'pkill -9 -f "kiro-cli chat"',
    }, calls)
  end)

  it('status prints buffer, job and PIDs', function()
    pids = { '11', '22' }
    local messages, restore = helpers.capture_echo()
    process.status({ exists = true, buffer = 4, job = 9, running = true })
    restore()
    local texts = vim.tbl_map(function(m)
      return m.text
    end, messages)
    assert.are.same({
      '=== Kiro Status ===',
      '',
      'Our Kiro buffer: exists (ID: 4)',
      'Our Kiro job: ID 9',
      'Status: running',
      '',
      'Running Kiro processes (PIDs): 11, 22',
    }, texts)
  end)

  it('status without buffer or processes', function()
    local messages, restore = helpers.capture_echo()
    process.status({ exists = false, buffer = -1, job = -1, running = false })
    restore()
    assert.are.equal('Our Kiro buffer: none', messages[3].text)
    assert.are.equal('No Kiro processes found', messages[#messages].text)
  end)

  it('starting Kiro while another instance runs prompts and honours "cancel"', function()
    pids = { '999' }
    answer = '2'
    local _, restore = helpers.capture_echo()
    local ok = require('kiro').open()
    restore()
    assert.is_false(ok)
    assert.is_false(require('kiro.terminal').info().exists)
  end)

  it('starting Kiro while another instance runs honours "kill and start"', function()
    pids = { '999' }
    answer = '1'
    local _, restore = helpers.capture_echo()
    local ok = require('kiro').open()
    restore()
    assert.is_true(ok)
    helpers.cleanup()
  end)
end)
