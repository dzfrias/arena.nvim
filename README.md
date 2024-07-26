# arena.nvim

`arena.nvim` is a [frecency](https://en.wikipedia.org/wiki/Frecency)-based
buffer switcher that allows you to hop between files _as fast as you can think_!
It sorts your buffers using two metrics: frequency and recency!

If you're tired of:

- Using a fuzzy-finder every time you want to switch to a file
- Persistent marks that you have to maintain yourself
- Feeling completely lost in projects with a lot of files

then the arena the perfect solution!

<img width="987" alt="The arena window" src="./doc/window.png">
<sub>The arena window. You can jump to your most frecent files!</sub>

## Getting Started

You can use your favorite package manager to get `arena.nvim` on your system.

For example, with [lazy](https://github.com/folke/lazy.nvim):

```lua
{
  "dzfrias/arena.nvim",
  event = "BufWinEnter",
  -- Calls `.setup()` automatically
  config = true,
}
```

Or with [packer](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "dzfrias/arena.nvim",
  config = function()
    require("arena").setup()
  end
}
```

To make sure everything is working, restart Neovim and run `:ArenaToggle`!

## Default Keybinds

`arena.nvim` comes with some default keybinds for buffer management!

| Key     | Description                        |
| ------- | ---------------------------------- |
| `<CR>`  | Open to file                       |
| `d`     | Delete the buffer under the cursor |
| `D`     | Delete all unpinned buffers        |
| `p`     | Pin the buffer under the cursor    |
| `<C-v>` | Open file (vsplit)                 |
| `<C-x>` | Open file (hsplit)                 |
| `<C-t>` | Open file (tab)                    |

If you'd like to unset any of these, set the value to `nil` in the keybinds
section of the [config](#configuration).

## Configuration

`arena.nvim` has plenty of configuration options to suit your needs! Below are
all the configuration options along with their default values.

```lua
{
  -- Maxiumum number of files that the arena window can contain, or `nil` for
  -- an unlimited amount
  max_items = 5,
  -- Always show the enclosing directory for these paths
  always_context = { "mod.rs", "init.lua" },
  -- When set, ignores the current buffer when listing files in the window.
  ignore_current = false,
  -- Options to apply to the arena buffer.
  buf_opts = {
    -- ["relativenumber"] = false,
  },
  -- Filter out buffers per the project they belong to.
  per_project = false,
  --- Add devicons (from nvim-web-devicons, if installed) to buffers
  devicons = false,


  window = {
    width = 60,
    height = 10,
    border = "rounded",

    -- Options to apply to the arena window.
    opts = {},
  },

  -- Keybinds for the arena window.
  keybinds = {
      -- ["e"] = function()
      --   vim.cmd("echo \"Hello from the arena!\"")
      -- end
  },

  -- Change the way the arena listing looks with custom rendering functions
  renderers = {}

  -- Config for frecency algorithm.
  algorithm = {
    -- Multiplies the recency by a factor. Must be greater than zero.
    -- A smaller number will mean less of an emphasis on recency!
    recency_factor = 0.5,
    -- Same as `recency_factor`, but for frequency!
    frequency_factor = 1,
  },
}
```

## API

`arena.nvim` has both a lua and vim API for more involved usages.

### Toggle

Toggles the arena window. `ArenaToggle` from vimscript.

```lua
require("arena").toggle()
```

### Open

Opens the arena window. `ArenaOpen` from vimscript.

```lua
require("arena").open()
```

### Close

Closes the arena window, if it exists. `ArenaClose` from vimscript.

```lua
require("arena").close()
```

### Keybinds

In the `keybinds` section of the config, the set functions take in the current
arena window as an argument, which
[has its own API](https://github.com/dzfrias/arena.nvim/blob/main/lua/arena/window.lua):

```lua
keybinds = {
  -- An example keybind that prints the linecount of the buffer of the
  -- current line in the window
  ["i"] = function(win)
    local current = win:current()
    local info = vim.fn.getbufinfo(current.bufnr)[1]
    print(info.linecount)
  end,
}
```

You can check out the
[source code](https://github.com/dzfrias/arena.nvim/blob/238885cae2a5dcc839ceeb20e595534563894cbb/lua/arena/init.lua#L24)
to see how the default arena keybinds are defined!

### Remove

Remove a buffer from the arena window, by buffer number.

```lua
-- Remove the 42nd buffer from the arena window
require("arena").remove(42)
```

### Pin

Pin a buffer to the top of the arena window.

```lua
-- Pin the 43rd buffer
require("arena").pin(43)
```

You may check if a buffer is pinned using the `is_pinned(buf)` function.

### Refresh

Refresh the arena window.

```lua
require("arena").refresh()
```

## License

The plugin falls under the [MIT License](./LICENSE).
