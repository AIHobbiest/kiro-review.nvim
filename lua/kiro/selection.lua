-- Visual selection support: capture, action menu, prompt/payload builders.
-- Capture logic is a direct port of the original Vimscript (byte-based
-- columns via strpart, same normalisation of reversed selections).

local util = require('kiro.util')

local M = {}

---@class KiroSelection
---@field text string
---@field filename string
---@field filetype string
---@field start_line integer
---@field end_line integer
---@field selection_type string 'character-wise' | 'line-wise' | 'block-wise'

--- Capture the last Visual selection of the current buffer. Call it after
--- leaving Visual mode so the '< and '> marks are set.
---@return KiroSelection|nil
function M.capture()
  local source_buffer = vim.fn.bufnr('%')
  local filename = vim.fn.expand('%:p')
  local filetype = vim.bo.filetype
  if filetype == '' then
    filetype = 'text'
  end
  local visual_type = vim.fn.visualmode()

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")

  local start_line, start_col = start_pos[2], start_pos[3]
  local end_line, end_col = end_pos[2], end_pos[3]

  if start_line <= 0 or end_line <= 0 then
    return nil
  end

  -- Normalise reversed selections.
  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  local lines = vim.fn.getbufline(source_buffer, start_line, end_line)
  if #lines == 0 then
    return nil
  end

  local selection_type

  if visual_type == 'v' then
    if #lines == 1 then
      lines[1] = vim.fn.strpart(lines[1], start_col - 1, end_col - start_col + 1)
    else
      lines[1] = vim.fn.strpart(lines[1], start_col - 1)
      lines[#lines] = vim.fn.strpart(lines[#lines], 0, end_col)
    end
    selection_type = 'character-wise'
  elseif visual_type == '\22' then -- CTRL-V
    local block_start = math.min(start_col, end_col)
    local block_end = math.max(start_col, end_col)
    local block_width = block_end - block_start + 1

    local block_lines = {}
    for _, line in ipairs(lines) do
      block_lines[#block_lines + 1] = vim.fn.strpart(line, block_start - 1, block_width)
    end
    lines = block_lines
    selection_type = 'block-wise'
  else
    selection_type = 'line-wise'
  end

  local text = table.concat(lines, '\n')
  if vim.trim(text) == '' then
    return nil
  end

  return {
    text = text,
    filename = filename == '' and '[unnamed Neovim buffer]' or filename,
    filetype = filetype,
    start_line = start_line,
    end_line = end_line,
    selection_type = selection_type,
  }
end

local ACTION_PROMPTS = {
  [1] = 'Review the selected code for correctness, clarity, '
    .. 'maintainability, testability and design quality.',
  [2] = 'Explain the selected code in detail, including its '
    .. 'purpose, control flow, data flow and important assumptions.',
  [3] = 'Suggest improvements for the selected code. Focus on '
    .. 'clarity, correctness, maintainability and modern practices.',
  [4] = 'Propose an implementation for the selected code or requirement. '
    .. 'Provide the implementation in the chat only. Do not modify files.',
  [5] = 'Find bugs, undefined behavior, race conditions, memory issues, '
    .. 'error-handling problems and important edge cases.',
  [6] = 'Propose comprehensive unit tests for the selected code, '
    .. 'including normal, boundary, negative and failure cases.',
  [7] = 'Analyze the selected code for performance problems, '
    .. 'unnecessary allocations, excessive copying and scalability risks.',
  [8] = 'Analyze the selected code for security weaknesses, unsafe input, '
    .. 'boundary errors, injection risks and misuse of sensitive data.',
}

local MENU = {
  'Kiro action for selected text:',
  '1. Review',
  '2. Explain',
  '3. Improve',
  '4. Propose implementation',
  '5. Find bugs',
  '6. Generate tests',
  '7. Analyze performance',
  '8. Analyze security',
  '9. Ask a custom question',
  '0. Cancel',
}

-- Replaceable in tests.
M.ui = {
  inputlist = function(options)
    return vim.fn.inputlist(options)
  end,
  input = function(prompt)
    vim.fn.inputsave()
    local answer = vim.fn.input(prompt)
    vim.fn.inputrestore()
    return answer
  end,
}

--- Prompt text for an action number (1-9). Action 9 asks the user.
---@return string
function M.action_prompt(action)
  if ACTION_PROMPTS[action] then
    return ACTION_PROMPTS[action]
  elseif action == 9 then
    return vim.trim(M.ui.input('Ask Kiro about the selection: '))
  end
  return ''
end

local function fence_for(text)
  return text:find('```', 1, true) and '````' or '```'
end

--- Payload for the action menu.
---@param selection KiroSelection
---@param request string
function M.menu_payload(selection, request)
  local location
  if selection.start_line == selection.end_line then
    location = 'line ' .. selection.start_line
  else
    location = 'lines ' .. selection.start_line .. '-' .. selection.end_line
  end

  -- Prevent the selected text from terminating the outer code fence.
  local fence = fence_for(selection.text)

  return request
    .. '\n\n'
    .. 'Consider the relevant context from our existing conversation.'
    .. '\n\nSource information:'
    .. '\n- File: ' .. selection.filename
    .. '\n- Location: ' .. location
    .. '\n- File type: ' .. selection.filetype
    .. '\n- Selection type: ' .. selection.selection_type
    .. '\n\nResponse requirements:'
    .. '\n1. Address the requested action first.'
    .. '\n2. Explain assumptions, risks and important edge cases.'
    .. '\n3. Provide proposed code or a diff when useful.'
    .. '\n4. Do not modify, create, rename or delete files.'
    .. '\n5. Do not execute shell commands.'
    .. '\n6. Do not apply changes directly.'
    .. '\n\n'
    .. fence .. selection.filetype .. '\n'
    .. selection.text
    .. '\n' .. fence
end

--- Payload for a free-form question about the selection.
---@param selection KiroSelection
---@param question string
function M.ask_payload(selection, question)
  local fence = fence_for(selection.text)

  return question
    .. '\n\n'
    .. 'Use the context of our existing conversation when relevant.'
    .. '\n\nSource information:'
    .. '\n- File: ' .. selection.filename
    .. '\n- Lines: ' .. selection.start_line .. '-' .. selection.end_line
    .. '\n- File type: ' .. selection.filetype
    .. '\n- Selection type: ' .. selection.selection_type
    .. '\n\nDo not modify files or execute commands. '
    .. 'Return proposed changes in the chat only.'
    .. '\n\n'
    .. fence .. selection.filetype .. '\n'
    .. selection.text
    .. '\n' .. fence
end

-- Action menu for the current Visual selection.
function M.menu()
  local selection = M.capture()
  if not selection then
    util.warn('No valid Visual selection is available')
    return
  end

  local action = tonumber(M.ui.inputlist(MENU)) or 0
  if action <= 0 or action > 9 then
    util.echo('Kiro action cancelled')
    return
  end

  local request = M.action_prompt(action)
  if request == '' then
    util.echo('Kiro action cancelled')
    return
  end

  require('kiro.terminal').send_text(M.menu_payload(selection, request))
end

-- Ask a custom question about the current Visual selection.
function M.ask()
  local selection = M.capture()
  if not selection then
    util.warn('No valid Visual selection is available')
    return
  end

  local question = vim.trim(M.ui.input('Ask Kiro about the selection: '))
  if question == '' then
    util.echo('Kiro question cancelled')
    return
  end

  require('kiro.terminal').send_text(M.ask_payload(selection, question))
end

return M
