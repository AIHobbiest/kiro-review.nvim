-- kiro-review.nvim public API.
--
-- Submodules are required lazily so that merely loading the plugin stays cheap.

local M = {}

---@class KiroOptions
---@field chat_width? integer Width of the vertical split (default 65)
---@field agent? string Kiro agent to use (default 'nvim-reviewer')
---@field mappings? boolean Install default key mappings (default true)

--- Optional. Call it to override the defaults / g:kiro_* variables.
---@param opts? KiroOptions
function M.setup(opts)
  require('kiro.config').setup(opts)
  require('kiro.mappings').apply()
end

--- Resolved configuration (setup() opts > g:kiro_* > defaults).
function M.config()
  return require('kiro.config').all()
end

-- Terminal lifecycle ---------------------------------------------------------

--- Open or focus the persistent Kiro chat.
---@return boolean ok
function M.open()
  return require('kiro.terminal').open()
end

--- Hide the Kiro window (process and chat keep running).
function M.close()
  require('kiro.terminal').close()
end

function M.toggle()
  require('kiro.terminal').toggle()
end

--- Stop Kiro completely (the saved conversation can be resumed later).
function M.stop()
  require('kiro.terminal').stop()
end

-- Chat -----------------------------------------------------------------------

--- Send text to the running conversation (opens the window if needed).
---@param text string
function M.send_text(text)
  require('kiro.terminal').send_text(text)
end

--- Prompt for a question and send it.
function M.ask()
  vim.fn.inputsave()
  local question = vim.fn.input('Kiro> ')
  vim.fn.inputrestore()

  question = vim.trim(question)
  if question == '' then
    require('kiro.util').echo('Kiro question cancelled')
    return
  end

  require('kiro.terminal').send_text(question)
end

--- Start a new conversation in the same Kiro process.
function M.new_chat()
  require('kiro.terminal').new_chat()
end

--- Open the saved-session picker.
function M.resume_picker()
  require('kiro.terminal').resume_picker()
end

--- Review the current (saved) file in read-only advisory mode.
function M.review()
  local util = require('kiro.util')
  local filename = vim.fn.expand('%:p')

  if filename == '' then
    util.warn('The current buffer does not have a filename')
    return
  end

  if vim.bo.modified then
    util.warn('Save the file before asking Kiro to review it')
    return
  end

  local prompt = 'Review the following file in read-only advisory mode. '
    .. 'Do not modify files or execute commands. '
    .. 'Report findings and proposed changes in the chat only. '
    .. 'File: '
    .. filename

  require('kiro.terminal').send_text(prompt)
end

-- Visual selection -----------------------------------------------------------

--- Action menu for the last Visual selection.
function M.selection_menu()
  require('kiro.selection').menu()
end

--- Ask a custom question about the last Visual selection.
function M.ask_selection()
  require('kiro.selection').ask()
end

-- Process management ---------------------------------------------------------

--- Kill every running kiro-cli chat process.
function M.kill_all()
  require('kiro.process').kill_all()
  require('kiro.terminal').reset_state()
end

function M.status()
  require('kiro.process').status(require('kiro.terminal').info())
end

return M
