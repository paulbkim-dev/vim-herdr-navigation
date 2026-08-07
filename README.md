# vim-herdr-navigation

Navigate [herdr](https://herdr.dev) panes and Vim/Neovim splits as if they were
one app. `Ctrl+h/j/k/l` moves between Vim splits while you're in Vim, and falls
through to move between herdr panes when Vim hits an edge. The same keys move
between herdr panes everywhere else. It's
[`vim-tmux-navigator`](https://github.com/christoomey/vim-tmux-navigator),
ported to herdr's CLI. `Ctrl+h/j/k/l` is only the default — any chords work,
see [Custom keys](#custom-keys).

## How it works

Two cooperating sides, like `vim-tmux-navigator`:

- **herdr side** (`navigate.sh`): a herdr keybind binds `Ctrl+h/j/k/l` to a
  plugin action. On each press the action checks the focused pane's _foreground_
  process via `herdr pane process-info`. If it's Vim/Neovim it forwards the key
  into that pane with `herdr pane send-keys`; otherwise it moves herdr's focus
  with `herdr pane focus --direction`.
- **editor side** (`editor/nvim.lua`, `editor/vim.vim`): maps the same keys to
  `wincmd h/j/k/l`. If the window didn't change (Vim is at an edge), it calls
  `herdr pane focus --direction` to cross into the neighbouring herdr pane. Vim
  finds its own pane through the `$HERDR_PANE_ID` herdr injects into every pane.

## Requirements

- herdr `>= 0.7.0`
- `jq` (used by `navigate.sh` to detect Vim; without it the keys still move
  herdr panes, just without Vim awareness)
- Tested on Linux or macOS

## Install

```bash
herdr plugin link /path/to/vim-herdr-navigation   # local checkout
herdr plugin action list --plugin vim-herdr-navigation
```

### 1. Bind the keys in herdr

Add to `~/.config/herdr/config.toml`:

```toml
[[keys.command]]
key = "ctrl+h"
type = "plugin_action"
command = "vim-herdr-navigation.left"
description = "navigate left (vim/herdr)"

[[keys.command]]
key = "ctrl+j"
type = "plugin_action"
command = "vim-herdr-navigation.down"
description = "navigate down (vim/herdr)"

[[keys.command]]
key = "ctrl+k"
type = "plugin_action"
command = "vim-herdr-navigation.up"
description = "navigate up (vim/herdr)"

[[keys.command]]
key = "ctrl+l"
type = "plugin_action"
command = "vim-herdr-navigation.right"
description = "navigate right (vim/herdr)"
```

Reload herdr's config (`prefix+shift+r`) or restart.

### 2. Wire up your editor

**Neovim** — load `editor/nvim.lua` after your plugins so it wins over any other
`<C-h/j/k/l>` mapping. With lazy.nvim, fold it into the `vim-tmux-navigator`
spec (disable its mappings, then load this one — single source of truth):

```lua
{
  "christoomey/vim-tmux-navigator",
  lazy = false,
  init = function()
    vim.g.tmux_navigator_no_mappings = 1
  end,
  config = function()
    dofile(vim.fn.expand("~/src/personal/vim-herdr-navigation/editor/nvim.lua"))
  end,
}
```

No plugin manager? Drop it in `after/plugin` instead:
`cp editor/nvim.lua ~/.config/nvim/after/plugin/herdr_nav.lua`.

It falls back to tmux (if `$TMUX` is set) or plain `wincmd` when you're not in a
herdr pane, so an existing tmux setup keeps working — no need to remove
`vim-tmux-navigator`.

**Vim** — from your `vimrc`:

```vim
source /path/to/vim-herdr-navigation/editor/vim.vim
```

or, simply copy and pasta.

## Custom keys

`Ctrl+h/j/k/l` is only the default. Any chord herdr and your terminal can
deliver works. Three places must agree, one per hop:

1. **The herdr keybinds** — the `key = "..."` values in the `[[keys.command]]`
   entries above. This is what you physically press.
2. **The forwarded keys** — what `navigate.sh` sends into a Vim pane. Each
   direction has an env override, read where herdr runs; the defaults are the
   matching `ctrl+h/j/k/l`:
   `HERDR_NAV_KEY_LEFT`, `HERDR_NAV_KEY_DOWN`, `HERDR_NAV_KEY_UP`,
   `HERDR_NAV_KEY_RIGHT`.
3. **The editor maps** — set `g:herdr_nav_keys` before the editor file loads
   to replace any subset of the defaults (an empty string drops that
   direction). Or set `g:herdr_nav_no_mappings = 1` and bind the
   `<Plug>(HerdrNavigateLeft/Down/Up/Right)` mappings yourself.

Example — `Ctrl+arrow` navigation, which leaves `Ctrl+h/j/k/l` free for the
editor's own defaults (like `Ctrl+l` clear-and-redraw):

In `~/.config/herdr/config.toml`, bind the arrows to the plugin actions:

```toml
[[keys.command]]
key = "ctrl+left"
type = "plugin_action"
command = "vim-herdr-navigation.left"

# ...same for ctrl+down / ctrl+up / ctrl+right...
```

Where you launch herdr, forward the same chords:

```bash
export HERDR_NAV_KEY_LEFT='ctrl+left'
export HERDR_NAV_KEY_DOWN='ctrl+down'
export HERDR_NAV_KEY_UP='ctrl+up'
export HERDR_NAV_KEY_RIGHT='ctrl+right'
```

Neovim, before `editor/nvim.lua` loads:

```lua
vim.g.herdr_nav_keys =
  { left = "<C-Left>", down = "<C-Down>", up = "<C-Up>", right = "<C-Right>" }
```

Vim, before `editor/vim.vim` is sourced:

```vim
let g:herdr_nav_keys =
      \ {'left': '<C-Left>', 'down': '<C-Down>', 'up': '<C-Up>', 'right': '<C-Right>'}
```

## Notes & tradeoffs

- **Other TUIs that use `Ctrl+h/j/k/l`** ([vi-sql](https://github.com/kopecmaciej/vi-sql),
  `lazygit`, `k9s`). By default every non-Vim pane just moves herdr focus. To let
  one of these handle the chord itself, name it in `HERDR_NAV_PASSTHROUGH_RE` — a
  regex on the lower-cased process name, anchored (`^…$`) for an exact match. Set
  it where you launch herdr:

  ```bash
  export HERDR_NAV_PASSTHROUGH_RE='^(vi-sql|lazygit)$'
  ```

  Unlike Vim, these apps don't cross _out_ at an edge — use `prefix+h/j/k/l` to
  leave the pane.
- **`Ctrl+l` / `Ctrl+k` in shells.** Binding these globally shadows readline's
  `Ctrl+L` (clear screen) and `Ctrl+K` (kill line) inside non-Vim panes. This is
  the same tradeoff as `vim-tmux-navigator`. If you want them back, bind clear to
  something like `prefix+l`, or navigate with different chords entirely — see
  [Custom keys](#custom-keys).
- **`Ctrl+H` vs Backspace.** `Ctrl+H` and Backspace share a byte (`0x08`) unless
  the kitty keyboard protocol is active. Neovim ≥ 0.10 enables it automatically
  in herdr panes, keeping `<C-h>` distinct. On older Vim you may need to map
  `<BS>` separately if it starts navigating.
- The editor maps are normal-mode only. Add `t`/`i` modes yourself if you want
  to navigate out of terminal/insert mode.
