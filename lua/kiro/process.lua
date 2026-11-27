-- System-process helpers (pgrep / pkill). Behaviour matches the original
-- Vimscript plugin. All commands are fixed strings: no user input is ever
-- interpolated into them.

local util = require('kiro.util')

local M = {}

-- Replaceable in tests.
M.runner = {
  systemlist = function(cmd)
    return vim.fn.systemlist(cmd)
  end,
  system = function(cmd)
    return vim.fn.system(cmd)
  end,
  sleep = function()
    vim.cmd('sleep 1')
  end,
  input = function(prompt)
    return vim.fn.input(prompt)
  end,
}

local PGREP = 'pgrep -f "kiro-cli chat"'

function M.pids()
  return M.runner.systemlist(PGREP)
end

-- True when a kiro-cli process exists that is not ours.
---@param our_job integer job id of our own terminal (<= 0 if none)
function M.is_running_elsewhere(our_job)
  local procs = M.pids()
  return #procs > 0 and our_job <= 0
end

local function kill_processes()
  M.runner.system('pkill -f "kiro-cli chat"')
  M.runner.system('pkill -f "kiro.*agent"')
  M.runner.sleep()
  M.runner.system('pkill -9 -f "kiro-cli chat"')
end

-- Ask the user what to do about an existing instance.
---@return boolean proceed true if a new Kiro may be started
function M.handle_existing()
  util.warn('Kiro is already running in another window/session')
  util.echo('')
  util.echo('Options:')
  util.echo('  1. Kill the existing Kiro and start fresh here')
  util.echo('  2. Cancel and use the existing Kiro instance')
  util.echo('  0. Cancel')
  util.echo('')

  local choice = M.runner.input('Choose option (1/2/0): ')

  if choice == '1' then
    util.echo('')
    util.echo('Stopping existing Kiro processes...')
    kill_processes()
    util.echo('Existing Kiro stopped. Starting new instance...')
    return true
  end

  util.echo('')
  util.echo('Cancelled. Use the existing Kiro instance instead.')
  return false
end

function M.kill_all()
  util.echo('Stopping all Kiro instances...')
  kill_processes()
  util.echo('All Kiro instances stopped')
end

---@param info { exists: boolean, buffer: integer, job: integer, running: boolean }
function M.status(info)
  util.echo('=== Kiro Status ===')
  util.echo('')

  if info.exists then
    util.echo('Our Kiro buffer: exists (ID: ' .. info.buffer .. ')')
    util.echo('Our Kiro job: ' .. (info.job > 0 and ('ID ' .. info.job) or 'none'))
    util.echo('Status: ' .. (info.running and 'running' or 'stopped'))
  else
    util.echo('Our Kiro buffer: none')
  end

  util.echo('')

  local procs = M.pids()
  if #procs > 0 then
    util.echo('Running Kiro processes (PIDs): ' .. table.concat(procs, ', '))
  else
    util.echo('No Kiro processes found')
  end
end

return M
