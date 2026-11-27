# kiro-review.nvim

> A Neovim plugin for persistent Kiro CLI integration with code review and advisory workflows

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

`kiro-review.nvim` integrates [Kiro CLI](https://www.kiro.ai/) directly into Neovim with a persistent, full-height terminal interface. Unlike other Kiro plugins, this one focuses on **code review workflows** with structured visual selection menus, read-only advisory mode, and session persistence.

## Features

- **Persistent Terminal Interface**: Full-height vertical split that preserves chat context
- **Visual Selection Actions**: Interactive menu for code review, explanation, improvement, and more
- **Read-Only Advisory Mode**: Review files without automatic modifications
- **Session Management**: Resume previous conversations with built-in picker
- **Comprehensive Keybindings**: Both normal and visual mode mappings
- **Custom Agent Support**: Configure specific Kiro agents for your workflow
- **Smart Code Context**: Automatically includes file location, type, and selection metadata

### Visual Selection Actions

When you select code in visual mode and trigger the action menu (`<leader>ka`), you get:

1. **Review** - Code quality, maintainability, and design analysis
2. **Explain** - Detailed explanation of purpose and flow
3. **Improve** - Suggestions for better code practices
4. **Propose Implementation** - Implementation suggestions (chat only, no file modifications)
5. **Find Bugs** - Bug detection, race conditions, edge cases
6. **Generate Tests** - Comprehensive test proposals
7. **Analyze Performance** - Performance bottlenecks and optimization
8. **Analyze Security** - Security vulnerability assessment
9. **Ask Custom Question** - Your own question about the selection

## Requirements

- **Neovim** 0.8.0 or higher
- **[Kiro CLI](https://www.kiro.ai/)** installed and configured
- Terminal with proper ANSI color support (recommended)

## Installation

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'AIHobbiest/kiro-review.nvim'
```

No further setup is needed.

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use 'AIHobbiest/kiro-review.nvim'
```

### Using [lazy.nvim](https://github.com/folke/lazy.nvim) / LazyVim

```lua
{
  'AIHobbiest/kiro-review.nvim',
  -- Lazy-load on first use. The plugin creates the mappings itself;
  -- these entries only tell lazy.nvim when to load it.
  cmd = { 'KiroOpen', 'KiroToggle', 'KiroReview', 'KiroSelection' },
  keys = {
    { '<leader>kc', desc = 'Kiro: open chat' },
    { '<leader>ko', desc = 'Kiro: toggle window' },
    { '<leader>kr', desc = 'Kiro: review current file' },
    { '<leader>ka', mode = 'x', desc = 'Kiro: selection actions' },
  },
  opts = {}, -- passed to require('kiro').setup(opts); see Configuration
}
```

In LazyVim, put this in `lua/plugins/kiro.lua` (return the table inside another
table: `return { { 'AIHobbiest/kiro-review.nvim', ... } }`). To get a `<leader>k`
group in which-key:

```lua
{ 'folke/which-key.nvim', opts = { spec = { { '<leader>k', group = 'kiro' } } } }
```

### Manual Installation

```bash
# For Unix/Linux/macOS
mkdir -p ~/.local/share/nvim/site/pack/local/start
cd ~/.local/share/nvim/site/pack/local/start
git clone https://github.com/AIHobbiest/kiro-review.nvim.git
```

## Configuration

Configuration is optional: the plugin works out of the box. Priority, highest
first: `setup()` options, `g:kiro_*` variables, built-in defaults. Values are read
when used, so a later `setup()` call still applies.

| Option | Variable | Default | Description |
|--------|----------|---------|-------------|
| `chat_width` | `g:kiro_chat_width` | `65` | Width of the vertical split |
| `agent` | `g:kiro_agent` | `'nvim-reviewer'` | Kiro agent to use |
| `mappings` | `g:kiro_no_mappings` (set to `1` to disable) | `true` | Install the default key mappings |

### init.lua

```lua
require('kiro').setup({
  chat_width = 80,
  agent = 'kiro_default',
  mappings = true,
})
```

### init.vim

```vim
let g:kiro_chat_width = 80
let g:kiro_agent = 'kiro_default'
let g:kiro_no_mappings = 1   " optional: skip the default mappings
```

Set the variables before the plugin loads. From init.vim you can also call
`lua require('kiro').setup({ chat_width = 80 })`.

### lazy.nvim / LazyVim

Use `opts = { chat_width = 80, agent = 'kiro_default' }` (see Installation).

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:KiroOpen` | Open or focus the persistent Kiro chat window |
| `:KiroClose` | Hide Kiro window (preserves process and chat) |
| `:KiroToggle` | Toggle Kiro window visibility |
| `:KiroStop` | Stop Kiro completely (saves session for later) |
| `:KiroNew` | Start a new conversation in the same process |
| `:KiroResumePicker` | Open session picker to resume a saved conversation |
| `:KiroAsk` | Ask a follow-up question in current conversation |
| `:KiroReview` | Review the current file in advisory mode |
| `:KiroSelection` | Open action menu for visual selection |
| `:KiroAskSelection` | Ask custom question about visual selection |

### Normal Mode Keybindings

| Key | Command | Description |
|-----|---------|-------------|
| `<leader>kc` | `:KiroOpen` | Open or focus Kiro chat |
| `<leader>ko` | `:KiroToggle` | Toggle Kiro window |
| `<leader>kh` | `:KiroClose` | Hide Kiro window |
| `<leader>kq` | `:KiroAsk` | Ask a question |
| `<leader>kr` | `:KiroReview` | Review current file |
| `<leader>kn` | `:KiroNew` | New conversation |
| `<leader>kl` | `:KiroResumePicker` | Load saved session |
| `<leader>ks` | `:KiroStop` | Stop Kiro |

### Visual Mode Keybindings

| Key | Command | Description |
|-----|---------|-------------|
| `<leader>ka` | `:KiroSelection` | Open action menu |
| `<leader>kq` | `:KiroAskSelection` | Ask about selection |

### Terminal Mode Keybindings

| Key | Description |
|-----|-------------|
| `<Esc><Esc>` | Exit terminal mode |
| `<C-q>` | Hide Kiro window |

## Workflow Examples

### 1. Code Review Workflow

```vim
" 1. Open a file you want reviewed
:e src/my-code.js

" 2. Review the entire file
<leader>kr

" 3. Or select specific code in visual mode
V5j
<leader>ka
" Choose: 1 (Review)
```

### 2. Debug and Improve Code

```vim
" 1. Select problematic code in visual mode
vjj
<leader>ka
" Choose: 5 (Find bugs)

" 2. After reviewing bugs, ask for improvements
<leader>ka
" Choose: 3 (Improve)
```

### 3. Learn from Existing Code

```vim
" 1. Select complex code
v}
<leader>ka
" Choose: 2 (Explain)

" 2. Ask follow-up questions
<leader>kq
" Type your question
```

### 4. Session Management

```vim
" Start working on a feature
<leader>kc

" Later, when you need to switch tasks
<leader>ks  " Stops and saves the session

" Resume your previous work
<leader>kl  " Opens session picker
```

## How It Works

### Persistent Terminal

The plugin creates a persistent terminal buffer that:
- Runs `kiro-cli chat --resume --agent nvim-reviewer`
- Maintains chat history across window hide/show operations
- Survives window closes (until you explicitly stop it)
- Automatically resumes your project-specific conversation

### Read-Only Advisory Mode

When you use `:KiroReview` or the visual selection menu, the plugin:
1. Sends your code with explicit instructions **not to modify files**
2. Includes context: filename, line numbers, file type, selection type
3. Requests responses in chat only with proposed changes as diffs
4. You maintain full control over which changes to apply

### Visual Selection Context

Every visual selection sent to Kiro includes:
- **File information**: Absolute path and file type
- **Location**: Line numbers (start and end)
- **Selection type**: Character-wise, line-wise, or block-wise
- **The code itself**: Properly formatted in a code fence

## Customizing Keybindings

The default mappings overwrite existing mappings with the same keys. To use your
own, disable the defaults (`mappings = false` or `let g:kiro_no_mappings = 1`) and
map the commands, the Lua API, or the Vimscript functions.

### Lua

```lua
require('kiro').setup({ mappings = false })

vim.keymap.set('n', '<leader>ai', require('kiro').open, { desc = 'Kiro: open' })
vim.keymap.set('n', '<leader>at', require('kiro').toggle, { desc = 'Kiro: toggle' })
-- Leave Visual mode first so the '< and '> marks are set.
vim.keymap.set('x', '<leader>as', '<Esc><Cmd>KiroSelection<CR>', { desc = 'Kiro: selection' })
```

### Vimscript

```vim
let g:kiro_no_mappings = 1

nnoremap <leader>ai :call KiroChatWindow()<CR>
nnoremap <leader>at :call KiroToggleWindow()<CR>
xnoremap <leader>as <Esc>:call KiroSelectionMenu()<CR>
```

### Lua API

`open`, `close`, `toggle`, `stop`, `new_chat`, `resume_picker`, `ask`, `review`,
`selection_menu`, `ask_selection`, `kill_all`, `status`, `send_text(text)` and
`config()`, all on `require('kiro')`.

## Troubleshooting

### Kiro won't start

**Problem**: `Unable to start Kiro CLI` error

**Solution**:
- Ensure `kiro-cli` is installed: `which kiro-cli`
- Verify it works in terminal: `kiro-cli chat --help`
- Check your PATH in Neovim: `:echo $PATH`

### Terminal appears blank

**Problem**: Terminal window is empty or frozen

**Solution**:
- Press `i` to enter insert mode
- Check if the process is running: `:KiroStop` then `:KiroOpen`
- Restart Neovim

### Session not resuming

**Problem**: Previous conversation doesn't load

**Solution**:
- Kiro CLI manages sessions per directory
- Make sure you're in the same working directory: `:pwd`
- Try the session picker: `:KiroResumePicker`

### Visual selection not working

**Problem**: Selection menu doesn't capture code

**Solution**:
- Ensure you're in visual mode (`v`, `V`, or `<C-v>`)
- Make sure you have an active selection before pressing `<leader>ka`
- Check that the buffer has content

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

### Development Setup

```bash
git clone https://github.com/AIHobbiest/kiro-review.nvim.git
cd kiro-review.nvim

# Try it in a clean Neovim
nvim -u NONE -c "set runtimepath+=." -c "runtime plugin/kiro.lua"

# Run the test-suite (needs plenary.nvim; set PLENARY_DIR if it is not in
# ~/.local/share/nvim/lazy/plenary.nvim). Tests use a stub kiro-cli.
tests/run.sh
```

## License

MIT License - see [LICENSE](LICENSE) file for details

## Acknowledgments

- Built for the [Kiro CLI](https://www.kiro.ai/) ecosystem
- Inspired by the need for structured code review workflows in Neovim

## Related Projects

- [seagoj/kiro.nvim](https://github.com/seagoj/kiro.nvim) - Lua-based with LSP integration
- [ynnekF/nvim-kiro](https://github.com/ynnekF/nvim-kiro) - Automatic context passing
- [sriram-mv/kiro.nvim](https://github.com/sriram-mv/kiro.nvim) - Tmux popup integration

---
