" ==========================================================
" Kiro Integration for Neovim
" Persistent read-only vertical terminal buffer
" ==========================================================

if exists('g:loaded_kiro_nvim_integration')
  finish
endif

let g:loaded_kiro_nvim_integration = 1

" ==========================================================
" Kiro Integration for Neovim
" Persistent read-only vertical terminal buffer
" ==========================================================

let g:kiro_chat_buffer = -1
let g:kiro_chat_job = -1
let g:kiro_chat_width = 65
let g:kiro_agent = 'nvim-reviewer'

" ----------------------------------------------------------
" Create a full-height vertical split on the right
" ----------------------------------------------------------
function! s:KiroCreateVerticalSplit(width) abort
  execute 'botright ' . a:width . 'vnew'

  " Move the Kiro window to the far right and make it span
  " the complete tab height.
  wincmd L

  execute 'vertical resize ' . a:width
  setlocal winfixwidth
endfunction

" ----------------------------------------------------------
" Configure the Kiro terminal buffer and window
" ----------------------------------------------------------
function! s:KiroConfigureWindow() abort
  " Preserve the terminal process when the window is hidden.
  setlocal bufhidden=hide

  setlocal nobuflisted
  setlocal nonumber
  setlocal norelativenumber
  setlocal signcolumn=no
  setlocal foldcolumn=0
  setlocal nospell
  setlocal nowrap
  setlocal winfixwidth
endfunction

" ----------------------------------------------------------
" Retrieve the current Kiro terminal job
" ----------------------------------------------------------
function! s:KiroJobId() abort
  if !bufexists(g:kiro_chat_buffer)
    return -1
  endif

  let l:buffer_job = getbufvar(
        \ g:kiro_chat_buffer,
        \ 'terminal_job_id',
        \ -1
        \ )

  if l:buffer_job > 0
    return l:buffer_job
  endif

  return g:kiro_chat_job
endfunction

" ----------------------------------------------------------
" Check whether the Kiro process is running
" ----------------------------------------------------------
function! s:KiroJobRunning() abort
  let l:job_id = s:KiroJobId()

  if l:job_id <= 0
    return 0
  endif

  let l:status = jobwait([l:job_id], 0)

  return !empty(l:status) && l:status[0] == -1
endfunction

" ----------------------------------------------------------
" Handle Kiro terminal exit
" ----------------------------------------------------------
function! s:KiroOnExit(job_id, exit_code, event) abort
  " Ignore delayed callbacks belonging to an older process.
  if a:job_id != g:kiro_chat_job
    return
  endif

  let g:kiro_chat_job = -1

  " Keep the exited terminal buffer available for inspection.
  " KiroChatWindow() removes it before starting another chat.
endfunction

" ----------------------------------------------------------
" Remove an exited Kiro terminal buffer
" ----------------------------------------------------------
function! s:KiroRemoveDeadBuffer() abort
  if !bufexists(g:kiro_chat_buffer)
    let g:kiro_chat_buffer = -1
    let g:kiro_chat_job = -1
    return
  endif

  let l:dead_buffer = g:kiro_chat_buffer

  let g:kiro_chat_buffer = -1
  let g:kiro_chat_job = -1

  execute 'silent! bdelete! ' . l:dead_buffer
endfunction

" ----------------------------------------------------------
" Check if Kiro CLI is already running in another instance
" ----------------------------------------------------------
function! s:KiroIsRunningElsewhere() abort
  " Check if there's a kiro-cli process already running
  let l:kiro_procs = systemlist('pgrep -f "kiro-cli chat"')
  
  " If we have our own job ID and it's in the list, that's fine
  let l:our_job = s:KiroJobId()
  
  if !empty(l:kiro_procs) && l:our_job <= 0
    " There's a Kiro running, but it's not ours
    return 1
  endif
  
  return 0
endfunction

" ----------------------------------------------------------
" Offer to kill existing Kiro before starting new one
" ----------------------------------------------------------
function! s:KiroHandleExisting() abort
  echohl WarningMsg
  echo 'Kiro is already running in another window/session'
  echohl None
  echo ''
  echo 'Options:'
  echo '  1. Kill the existing Kiro and start fresh here'
  echo '  2. Cancel and use the existing Kiro instance'
  echo '  0. Cancel'
  echo ''
  
  let l:choice = input('Choose option (1/2/0): ')
  
  if l:choice == '1'
    echo ''
    echo 'Stopping existing Kiro processes...'
    
    " Kill all kiro-cli processes
    call system('pkill -f "kiro-cli chat"')
    call system('pkill -f "kiro.*agent"')
    
    " Wait a moment
    sleep 1
    
    " Force kill if needed
    call system('pkill -9 -f "kiro-cli chat"')
    
    echo 'Existing Kiro stopped. Starting new instance...'
    return 1  " Proceed with starting new Kiro
  else
    echo ''
    echo 'Cancelled. Use the existing Kiro instance instead.'
    return 0  " Don't start new Kiro
  endif
endfunction

" ----------------------------------------------------------
" Start Kiro and resume the project conversation
" ----------------------------------------------------------
function! s:KiroStartTerminal() abort
  " Check if Kiro is running elsewhere
  if s:KiroIsRunningElsewhere()
    if !s:KiroHandleExisting()
      " User cancelled
      return 0
    endif
  endif
  
  call s:KiroCreateVerticalSplit(g:kiro_chat_width)

  let l:command = [
        \ 'kiro-cli',
        \ 'chat',
        \ '--resume',
        \ '--agent',
        \ g:kiro_agent
        \ ]

  let l:job_id = termopen(
        \ l:command,
        \ {
        \   'cwd': getcwd(),
        \   'on_exit': function('s:KiroOnExit')
        \ }
        \ )

  if l:job_id <= 0
    echohl ErrorMsg
    echo 'Unable to start Kiro CLI'
    echohl None

    if winnr('$') > 1
      close
    endif

    return 0
  endif

  let g:kiro_chat_buffer = bufnr('%')
  let g:kiro_chat_job = l:job_id

  execute 'silent! file KiroChat'

  call s:KiroConfigureWindow()

  startinsert
  return 1
endfunction

" ----------------------------------------------------------
" Open or focus the persistent Kiro terminal
" ----------------------------------------------------------
function! KiroChatWindow() abort
  " Remove an old terminal buffer if its process has exited.
  if bufexists(g:kiro_chat_buffer) && !s:KiroJobRunning()
    call s:KiroRemoveDeadBuffer()
  endif

  if bufexists(g:kiro_chat_buffer)
    let l:kiro_window = bufwinid(g:kiro_chat_buffer)

    " Kiro is already visible.
    if l:kiro_window != -1
      call win_gotoid(l:kiro_window)

      wincmd L
      execute 'vertical resize ' . g:kiro_chat_width

      call s:KiroConfigureWindow()

      normal! G
      startinsert
      return 1
    endif

    " Kiro is running, but its window is hidden.
    call s:KiroCreateVerticalSplit(g:kiro_chat_width)

    execute 'buffer ' . g:kiro_chat_buffer

    call s:KiroConfigureWindow()

    normal! G
    startinsert
    return 1
  endif

  return s:KiroStartTerminal()
endfunction

" ----------------------------------------------------------
" Hide Kiro but preserve the chat process and context
" ----------------------------------------------------------
function! KiroCloseWindow() abort
  if !bufexists(g:kiro_chat_buffer)
    echo 'Kiro chat is not running'
    return
  endif

  let l:kiro_window = bufwinid(g:kiro_chat_buffer)

  if l:kiro_window == -1
    echo 'Kiro chat is already hidden'
    return
  endif

  if winnr('$') == 1
    echohl WarningMsg
    echo 'Cannot hide Kiro because it is the only window'
    echohl None
    return
  endif

  call win_gotoid(l:kiro_window)

  " Close only the window. Keep the terminal buffer and
  " Kiro process running.
  hide
endfunction

" ----------------------------------------------------------
" Toggle the Kiro window
" ----------------------------------------------------------
function! KiroToggleWindow() abort
  if bufexists(g:kiro_chat_buffer)
    let l:kiro_window = bufwinid(g:kiro_chat_buffer)

    if l:kiro_window != -1
      call KiroCloseWindow()
      return
    endif
  endif

  call KiroChatWindow()
endfunction

" ----------------------------------------------------------
" Stop Kiro completely
" ----------------------------------------------------------
function! KiroStop() abort
  if !bufexists(g:kiro_chat_buffer)
    let g:kiro_chat_buffer = -1
    let g:kiro_chat_job = -1

    echo 'Kiro chat is not running'
    return
  endif

  let l:kiro_buffer = g:kiro_chat_buffer
  let l:job_id = s:KiroJobId()

  " Clear globals before stopping the job so the exit callback
  " cannot interfere with a newly started process.
  let g:kiro_chat_buffer = -1
  let g:kiro_chat_job = -1

  if l:job_id > 0
    let l:status = jobwait([l:job_id], 0)

    if !empty(l:status) && l:status[0] == -1
      call jobstop(l:job_id)
    endif
  endif

  if bufexists(l:kiro_buffer)
    execute 'silent! bdelete! ' . l:kiro_buffer
  endif

  echo 'Kiro stopped. The saved conversation can be resumed later.'
endfunction

" ----------------------------------------------------------
" Send text to the persistent conversation
" ----------------------------------------------------------
function! KiroSendText(text) abort
  if empty(trim(a:text))
    return
  endif

  if !KiroChatWindow()
    return
  endif

  let l:job_id = s:KiroJobId()

  if l:job_id <= 0 || !s:KiroJobRunning()
    echohl ErrorMsg
    echo 'Kiro terminal process is not running'
    echohl None
    return
  endif

  " Carriage return submits the prompt to the terminal UI.
  call chansend(l:job_id, a:text . "\r")

  let l:kiro_window = bufwinid(g:kiro_chat_buffer)

  if l:kiro_window != -1
    call win_gotoid(l:kiro_window)
    normal! G
    startinsert
  endif
endfunction

" ----------------------------------------------------------
" Ask a general follow-up question
" ----------------------------------------------------------
function! KiroAsk() abort
  call inputsave()
  let l:question = input('Kiro> ')
  call inputrestore()

  let l:question = trim(l:question)

  if empty(l:question)
    echo 'Kiro question cancelled'
    return
  endif

  call KiroSendText(l:question)
endfunction

" ----------------------------------------------------------
" Start a new conversation in the same Kiro process
" ----------------------------------------------------------
function! KiroNewChat() abort
  if !KiroChatWindow()
    return
  endif

  let l:job_id = s:KiroJobId()

  if l:job_id <= 0
    echohl ErrorMsg
    echo 'Kiro terminal is not running'
    echohl None
    return
  endif

  call chansend(l:job_id, "/chat new\r")
  startinsert
endfunction

" ----------------------------------------------------------
" Open the saved-session picker
" ----------------------------------------------------------
function! KiroResumePicker() abort
  call KiroStop()

  call s:KiroCreateVerticalSplit(g:kiro_chat_width)

  let l:command = [
        \ 'kiro-cli',
        \ 'chat',
        \ '--resume-picker',
        \ '--agent',
        \ g:kiro_agent
        \ ]

  let l:job_id = termopen(
        \ l:command,
        \ {
        \   'cwd': getcwd(),
        \   'on_exit': function('s:KiroOnExit')
        \ }
        \ )

  if l:job_id <= 0
    echohl ErrorMsg
    echo 'Unable to open the Kiro session picker'
    echohl None

    if winnr('$') > 1
      close
    endif

    return
  endif

  let g:kiro_chat_buffer = bufnr('%')
  let g:kiro_chat_job = l:job_id

  execute 'silent! file KiroChat'

  call s:KiroConfigureWindow()
  startinsert
endfunction

" ----------------------------------------------------------
" Review current file in read-only advisory mode
" ----------------------------------------------------------
function! KiroReviewCurrentFile() abort
  let l:filename = expand('%:p')

  if empty(l:filename)
    echohl WarningMsg
    echo 'The current buffer does not have a filename'
    echohl None
    return
  endif

  if &modified
    echohl WarningMsg
    echo 'Save the file before asking Kiro to review it'
    echohl None
    return
  endif

  let l:prompt =
        \ 'Review the following file in read-only advisory mode. ' .
        \ 'Do not modify files or execute commands. ' .
        \ 'Report findings and proposed changes in the chat only. ' .
        \ 'File: ' .
        \ l:filename

  call KiroSendText(l:prompt)
endfunction

" ==========================================================
" Visual selection support
" ==========================================================

" ----------------------------------------------------------
" Capture an exact Visual-mode selection
"
" Returns:
" {
"   text:           selected text,
"   filename:       absolute filename or placeholder,
"   filetype:       Neovim file type,
"   start_line:     first selected line,
"   end_line:       last selected line,
"   selection_type: character-wise, line-wise or block-wise
" }
" ----------------------------------------------------------
function! s:KiroCaptureSelection() abort
  let l:source_buffer = bufnr('%')
  let l:filename = expand('%:p')
  let l:filetype = empty(&filetype) ? 'text' : &filetype
  let l:visual_type = visualmode()

  let l:start_position = getpos("'<")
  let l:end_position = getpos("'>")

  let l:start_line = l:start_position[1]
  let l:start_column = l:start_position[2]
  let l:end_line = l:end_position[1]
  let l:end_column = l:end_position[2]

  if l:start_line <= 0 || l:end_line <= 0
    return {}
  endif

  " Normalize reversed selections.
  if l:start_line > l:end_line ||
        \ (l:start_line == l:end_line &&
        \ l:start_column > l:end_column)

    let [l:start_line, l:end_line] =
          \ [l:end_line, l:start_line]

    let [l:start_column, l:end_column] =
          \ [l:end_column, l:start_column]
  endif

  let l:lines = getbufline(
        \ l:source_buffer,
        \ l:start_line,
        \ l:end_line
        \ )

  if empty(l:lines)
    return {}
  endif

  if l:visual_type ==# 'v'
    " Character-wise selection.
    if len(l:lines) == 1
      let l:lines[0] = strpart(
            \ l:lines[0],
            \ l:start_column - 1,
            \ l:end_column - l:start_column + 1
            \ )
    else
      let l:lines[0] = strpart(
            \ l:lines[0],
            \ l:start_column - 1
            \ )

      let l:lines[-1] = strpart(
            \ l:lines[-1],
            \ 0,
            \ l:end_column
            \ )
    endif

    let l:selection_type = 'character-wise'

  elseif l:visual_type ==# "\<C-v>"
    " Block-wise selection.
    let l:block_start = min([
          \ l:start_column,
          \ l:end_column
          \ ])

    let l:block_end = max([
          \ l:start_column,
          \ l:end_column
          \ ])

    let l:block_width =
          \ l:block_end - l:block_start + 1

    let l:block_lines = []

    for l:line in l:lines
      call add(
            \ l:block_lines,
            \ strpart(
            \   l:line,
            \   l:block_start - 1,
            \   l:block_width
            \ )
            \ )
    endfor

    let l:lines = l:block_lines
    let l:selection_type = 'block-wise'

  else
    let l:selection_type = 'line-wise'
  endif

  let l:selected_text = join(l:lines, "\n")

  if empty(trim(l:selected_text))
    return {}
  endif

  return {
        \ 'text': l:selected_text,
        \ 'filename': empty(l:filename)
        \   ? '[unnamed Neovim buffer]'
        \   : l:filename,
        \ 'filetype': l:filetype,
        \ 'start_line': l:start_line,
        \ 'end_line': l:end_line,
        \ 'selection_type': l:selection_type
        \ }
endfunction

" ----------------------------------------------------------
" Display the action menu
" ----------------------------------------------------------
function! s:KiroSelectAction() abort
  let l:options = [
        \ 'Kiro action for selected text:',
        \ '1. Review',
        \ '2. Explain',
        \ '3. Improve',
        \ '4. Propose implementation',
        \ '5. Find bugs',
        \ '6. Generate tests',
        \ '7. Analyze performance',
        \ '8. Analyze security',
        \ '9. Ask a custom question',
        \ '0. Cancel'
        \ ]

  return inputlist(l:options)
endfunction

" ----------------------------------------------------------
" Convert a selected action into a prompt
" ----------------------------------------------------------
function! s:KiroActionPrompt(action) abort
  if a:action == 1
    return
          \ 'Review the selected code for correctness, clarity, ' .
          \ 'maintainability, testability and design quality.'

  elseif a:action == 2
    return
          \ 'Explain the selected code in detail, including its ' .
          \ 'purpose, control flow, data flow and important assumptions.'

  elseif a:action == 3
    return
          \ 'Suggest improvements for the selected code. Focus on ' .
          \ 'clarity, correctness, maintainability and modern practices.'

  elseif a:action == 4
    return
          \ 'Propose an implementation for the selected code or requirement. ' .
          \ 'Provide the implementation in the chat only. Do not modify files.'

  elseif a:action == 5
    return
          \ 'Find bugs, undefined behavior, race conditions, memory issues, ' .
          \ 'error-handling problems and important edge cases.'

  elseif a:action == 6
    return
          \ 'Propose comprehensive unit tests for the selected code, ' .
          \ 'including normal, boundary, negative and failure cases.'

  elseif a:action == 7
    return
          \ 'Analyze the selected code for performance problems, ' .
          \ 'unnecessary allocations, excessive copying and scalability risks.'

  elseif a:action == 8
    return
          \ 'Analyze the selected code for security weaknesses, unsafe input, ' .
          \ 'boundary errors, injection risks and misuse of sensitive data.'

  elseif a:action == 9
    call inputsave()
    let l:question = input('Ask Kiro about the selection: ')
    call inputrestore()

    return trim(l:question)
  endif

  return ''
endfunction

" ----------------------------------------------------------
" Submit selected code through the action menu
" ----------------------------------------------------------
function! KiroSelectionMenu() abort
  " Capture the Visual selection before displaying the menu or
  " opening the Kiro terminal.
  let l:selection = s:KiroCaptureSelection()

  if empty(l:selection)
    echohl WarningMsg
    echo 'No valid Visual selection is available'
    echohl None
    return
  endif

  let l:action = s:KiroSelectAction()

  if l:action <= 0 || l:action > 9
    echo 'Kiro action cancelled'
    return
  endif

  let l:request = s:KiroActionPrompt(l:action)

  if empty(l:request)
    echo 'Kiro action cancelled'
    return
  endif

  if l:selection.start_line == l:selection.end_line
    let l:location =
          \ 'line ' . l:selection.start_line
  else
    let l:location =
          \ 'lines ' .
          \ l:selection.start_line .
          \ '-' .
          \ l:selection.end_line
  endif

  " Prevent the selected text from accidentally terminating
  " the outer Markdown code fence.
  let l:fence =
        \ l:selection.text =~# '```'
        \ ? '````'
        \ : '```'

  let l:payload =
        \ l:request .
        \ "\n\n" .
        \ "Consider the relevant context from our existing conversation." .
        \ "\n\nSource information:" .
        \ "\n- File: " . l:selection.filename .
        \ "\n- Location: " . l:location .
        \ "\n- File type: " . l:selection.filetype .
        \ "\n- Selection type: " . l:selection.selection_type .
        \ "\n\nResponse requirements:" .
        \ "\n1. Address the requested action first." .
        \ "\n2. Explain assumptions, risks and important edge cases." .
        \ "\n3. Provide proposed code or a diff when useful." .
        \ "\n4. Do not modify, create, rename or delete files." .
        \ "\n5. Do not execute shell commands." .
        \ "\n6. Do not apply changes directly." .
        \ "\n\n" .
        \ l:fence . l:selection.filetype . "\n" .
        \ l:selection.text .
        \ "\n" . l:fence

  call KiroSendText(l:payload)
endfunction

" ----------------------------------------------------------
" Ask a custom question directly about selected text
" ----------------------------------------------------------
function! KiroAskSelection() abort
  let l:selection = s:KiroCaptureSelection()

  if empty(l:selection)
    echohl WarningMsg
    echo 'No valid Visual selection is available'
    echohl None
    return
  endif

  call inputsave()
  let l:question = input('Ask Kiro about the selection: ')
  call inputrestore()

  let l:question = trim(l:question)

  if empty(l:question)
    echo 'Kiro question cancelled'
    return
  endif

  let l:fence =
        \ l:selection.text =~# '```'
        \ ? '````'
        \ : '```'

  let l:payload =
        \ l:question .
        \ "\n\n" .
        \ "Use the context of our existing conversation when relevant." .
        \ "\n\nSource information:" .
        \ "\n- File: " . l:selection.filename .
        \ "\n- Lines: " .
        \ l:selection.start_line .
        \ '-' .
        \ l:selection.end_line .
        \ "\n- File type: " . l:selection.filetype .
        \ "\n- Selection type: " . l:selection.selection_type .
        \ "\n\nDo not modify files or execute commands. " .
        \ "Return proposed changes in the chat only." .
        \ "\n\n" .
        \ l:fence . l:selection.filetype . "\n" .
        \ l:selection.text .
        \ "\n" . l:fence

  call KiroSendText(l:payload)
endfunction

" ----------------------------------------------------------
" Kill all running Kiro instances
" ----------------------------------------------------------
function! KiroKillAll() abort
  echo 'Stopping all Kiro instances...'
  
  call system('pkill -f "kiro-cli chat"')
  call system('pkill -f "kiro.*agent"')
  
  sleep 1
  
  call system('pkill -9 -f "kiro-cli chat"')
  
  " Clear our tracked buffer and job
  let g:kiro_chat_buffer = -1
  let g:kiro_chat_job = -1
  
  echo 'All Kiro instances stopped'
endfunction

" ----------------------------------------------------------
" Check Kiro status
" ----------------------------------------------------------
function! KiroStatus() abort
  echo '=== Kiro Status ==='
  echo ''
  
  " Check our buffer
  if bufexists(g:kiro_chat_buffer)
    let l:our_job = s:KiroJobId()
    let l:running = s:KiroJobRunning()
    
    echo 'Our Kiro buffer: exists (ID: ' . g:kiro_chat_buffer . ')'
    echo 'Our Kiro job: ' . (l:our_job > 0 ? 'ID ' . l:our_job : 'none')
    echo 'Status: ' . (l:running ? 'running' : 'stopped')
  else
    echo 'Our Kiro buffer: none'
  endif
  
  echo ''
  
  " Check for other Kiro processes
  let l:kiro_procs = systemlist('pgrep -f "kiro-cli chat"')
  
  if !empty(l:kiro_procs)
    echo 'Running Kiro processes (PIDs): ' . join(l:kiro_procs, ', ')
  else
    echo 'No Kiro processes found'
  endif
endfunction

" ----------------------------------------------------------
" Commands
" ----------------------------------------------------------
command! KiroOpen         call KiroChatWindow()
command! KiroClose        call KiroCloseWindow()
command! KiroToggle       call KiroToggleWindow()
command! KiroStop         call KiroStop()
command! KiroNew          call KiroNewChat()
command! KiroResumePicker call KiroResumePicker()
command! KiroAsk          call KiroAsk()
command! KiroReview       call KiroReviewCurrentFile()
command! KiroSelection    call KiroSelectionMenu()
command! KiroAskSelection call KiroAskSelection()
command! KiroKillAll      call KiroKillAll()
command! KiroStatus       call KiroStatus()

" ----------------------------------------------------------
" Normal-mode mappings
" ----------------------------------------------------------

" Open or focus the persistent Kiro chat.
nnoremap <silent> <leader>kc :call KiroChatWindow()<CR>

" Toggle the right-side Kiro window.
nnoremap <silent> <leader>ko :call KiroToggleWindow()<CR>

" Hide Kiro while preserving its process and current chat.
nnoremap <silent> <leader>kh :call KiroCloseWindow()<CR>

" Ask a normal follow-up question in the current conversation.
nnoremap <silent> <leader>kq :call KiroAsk()<CR>

" Review the current saved file.
nnoremap <silent> <leader>kr :call KiroReviewCurrentFile()<CR>

" Start a new conversation.
nnoremap <silent> <leader>kn :call KiroNewChat()<CR>

" Select an older saved conversation.
nnoremap <silent> <leader>kl :call KiroResumePicker()<CR>

" Stop the current Kiro process.
nnoremap <silent> <leader>ks :call KiroStop()<CR>

" ----------------------------------------------------------
" Visual-mode mappings
" ----------------------------------------------------------

" Display the Review, Explain, Improve, Implement and other
" actions for the selected text.
xnoremap <silent> <leader>ka <Esc>:call KiroSelectionMenu()<CR>

" Ask a custom question directly about the selected text.
xnoremap <silent> <leader>kq <Esc>:call KiroAskSelection()<CR>

" ----------------------------------------------------------
" Terminal-mode mappings
" ----------------------------------------------------------

" Leave terminal mode.
" Remove this line if the same mapping already exists globally.
tnoremap <Esc><Esc> <C-\><C-n>

" Hide the Kiro window while keeping its chat alive.
tnoremap <silent> <C-q> <C-\><C-n>:call KiroCloseWindow()<CR>

if exists('g:loaded_kiro_nvim_integration')
  finish
endif
" ==========================================================
" End Kiro Integration
" ==========================================================


