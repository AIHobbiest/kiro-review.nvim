-- Configuration resolution.
--
-- Priority (highest first):
--   1. values passed to require('kiro').setup(opts)
--   2. legacy global variables (g:kiro_chat_width, g:kiro_agent,
--      g:kiro_no_mappings)
--   3. built-in defaults
--
-- Values are resolved when read, so a late setup() or a late `let g:...`
-- still takes effect.

local M = {}

M.defaults = {
  chat_width = 65,
  agent = 'nvim-reviewer',
  mappings = true,
}

local options = {}

local function truthy(value)
  return value ~= nil and value ~= false and value ~= 0 and value ~= vim.NIL
end

function M.setup(opts)
  if opts == nil then
    return
  end
  assert(type(opts) == 'table', 'kiro.setup(): opts must be a table')
  options = vim.tbl_extend('force', options, opts)
end

-- Forget everything passed to setup() (used by tests).
function M.reset()
  options = {}
end

function M.get(key)
  if options[key] ~= nil then
    return options[key]
  end

  if key == 'chat_width' then
    local width = tonumber(vim.g.kiro_chat_width)
    return width and math.floor(width) or M.defaults.chat_width
  elseif key == 'agent' then
    local agent = vim.g.kiro_agent
    if type(agent) == 'string' and agent ~= '' then
      return agent
    end
    return M.defaults.agent
  elseif key == 'mappings' then
    if truthy(vim.g.kiro_no_mappings) then
      return false
    end
    return M.defaults.mappings
  end

  return M.defaults[key]
end

-- Snapshot of the resolved configuration.
function M.all()
  return {
    chat_width = M.get('chat_width'),
    agent = M.get('agent'),
    mappings = M.get('mappings'),
  }
end

return M
