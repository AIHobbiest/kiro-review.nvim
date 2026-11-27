-- Persistent Kiro terminal: window, job and buffer lifecycle.

local config = require('kiro.config')
local process = require('kiro.process')
local util = require('kiro.util')

local M = {}

-- Private state (formerly g:kiro_chat_buffer / g:kiro_chat_job).
local state = { buffer = -1, job = -1 }

local function buffer_exists()
  return state.buffer > 0 and vim.fn.bufexists(state.buffer) == 1
end

local function reset_state()
  state.buffer = -1
  state.job = -1
end

M.reset_state = reset_state

-- Full-height vertical split on the far right.
local function create_vertical_split(width)
  vim.cmd('botright ' .. width .. 'vnew')
  vim.cmd('wincmd L')
  vim.cmd('vertical resize ' .. width)
  vim.cmd('setlocal winfixwidth')
end

local function configure_window()
  vim.cmd([[
    setlocal bufhidden=hide
    setlocal nobuflisted
    setlocal nonumber
    setlocal norelativenumber
    setlocal signcolumn=no
    setlocal foldcolumn=0
    setlocal nospell
    setlocal nowrap
    setlocal winfixwidth
  ]])
end

local function job_id()
  if not buffer_exists() then
    return -1
  end

  local buffer_job = vim.fn.getbufvar(state.buffer, 'terminal_job_id', -1)
  if type(buffer_job) == 'number' and buffer_job > 0 then
    return buffer_job
  end

  return state.job
end

local function job_running()
  local id = job_id()
  if id <= 0 then
    return false
  end

  local status = vim.fn.jobwait({ id }, 0)
  return #status > 0 and status[1] == -1
end

local function on_exit(id)
  -- Ignore delayed callbacks that belong to an older process.
  if id ~= state.job then
    return
  end
  state.job = -1
  -- The exited buffer stays available for inspection; open() removes it
  -- before starting another chat.
end

local function remove_dead_buffer()
  if not buffer_exists() then
    reset_state()
    return
  end

  local dead = state.buffer
  reset_state()
  vim.cmd('silent! bdelete! ' .. dead)
end

local function start_job(cmd)
  local opts = { cwd = vim.fn.getcwd(), on_exit = on_exit }

  -- termopen() is deprecated on Neovim 0.11+.
  if vim.fn.has('nvim-0.11') == 1 then
    opts.term = true
    return vim.fn.jobstart(cmd, opts)
  end

  return vim.fn.termopen(cmd, opts)
end

-- Open the split and run `kiro-cli chat <mode_flag> --agent <agent>` in it.
---@return boolean started
local function spawn(mode_flag, failure_message)
  create_vertical_split(config.get('chat_width'))

  local cmd = { 'kiro-cli', 'chat', mode_flag, '--agent', config.get('agent') }
  local ok, id = pcall(start_job, cmd)
  if not ok then
    id = 0
  end

  if id <= 0 then
    util.error(failure_message)
    if vim.fn.winnr('$') > 1 then
      vim.cmd('close')
    end
    return false
  end

  state.buffer = vim.fn.bufnr('%')
  state.job = id

  vim.cmd('silent! file KiroChat')
  configure_window()
  vim.cmd('startinsert')
  return true
end

local function start_terminal()
  if process.is_running_elsewhere(job_id()) then
    if not process.handle_existing() then
      return false
    end
  end

  return spawn('--resume', 'Unable to start Kiro CLI')
end

local function focus_end()
  vim.cmd('normal! G')
  vim.cmd('startinsert')
end

-- Open or focus the persistent Kiro terminal.
---@return boolean ok
function M.open()
  -- Remove an old terminal buffer if its process has exited.
  if buffer_exists() and not job_running() then
    remove_dead_buffer()
  end

  if buffer_exists() then
    local win = vim.fn.bufwinid(state.buffer)
    local width = config.get('chat_width')

    if win ~= -1 then
      vim.fn.win_gotoid(win)
      vim.cmd('wincmd L')
      vim.cmd('vertical resize ' .. width)
      configure_window()
      focus_end()
      return true
    end

    -- Running, but hidden.
    create_vertical_split(width)
    vim.cmd('buffer ' .. state.buffer)
    configure_window()
    focus_end()
    return true
  end

  return start_terminal()
end

-- Hide the window but keep the process and the chat alive.
function M.close()
  if not buffer_exists() then
    util.echo('Kiro chat is not running')
    return
  end

  local win = vim.fn.bufwinid(state.buffer)
  if win == -1 then
    util.echo('Kiro chat is already hidden')
    return
  end

  if vim.fn.winnr('$') == 1 then
    util.warn('Cannot hide Kiro because it is the only window')
    return
  end

  vim.fn.win_gotoid(win)
  vim.cmd('hide')
end

function M.toggle()
  if buffer_exists() and vim.fn.bufwinid(state.buffer) ~= -1 then
    M.close()
    return
  end

  M.open()
end

-- Stop Kiro completely.
function M.stop()
  if not buffer_exists() then
    reset_state()
    util.echo('Kiro chat is not running')
    return
  end

  local buffer = state.buffer
  local id = job_id()

  -- Clear state first so the exit callback cannot interfere with a newly
  -- started process.
  reset_state()

  if id > 0 then
    local status = vim.fn.jobwait({ id }, 0)
    if #status > 0 and status[1] == -1 then
      vim.fn.jobstop(id)
    end
  end

  if vim.fn.bufexists(buffer) == 1 then
    vim.cmd('silent! bdelete! ' .. buffer)
  end

  util.echo('Kiro stopped. The saved conversation can be resumed later.')
end

-- Send text to the persistent conversation.
function M.send_text(text)
  if vim.trim(text or '') == '' then
    return
  end

  if not M.open() then
    return
  end

  local id = job_id()
  if id <= 0 or not job_running() then
    util.error('Kiro terminal process is not running')
    return
  end

  -- A carriage return submits the prompt to the terminal UI.
  vim.fn.chansend(id, text .. '\r')

  local win = vim.fn.bufwinid(state.buffer)
  if win ~= -1 then
    vim.fn.win_gotoid(win)
    focus_end()
  end
end

-- Start a new conversation in the same Kiro process.
function M.new_chat()
  if not M.open() then
    return
  end

  local id = job_id()
  if id <= 0 then
    util.error('Kiro terminal is not running')
    return
  end

  vim.fn.chansend(id, '/chat new\r')
  vim.cmd('startinsert')
end

-- Replace the current chat with the saved-session picker.
function M.resume_picker()
  M.stop()
  spawn('--resume-picker', 'Unable to open the Kiro session picker')
end

-- Snapshot for :KiroStatus and tests.
function M.info()
  return {
    exists = buffer_exists(),
    buffer = state.buffer,
    job = job_id(),
    running = buffer_exists() and job_running() or false,
  }
end

return M
