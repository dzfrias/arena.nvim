# arena.nvim

`arena.nvim` is a **frecency**-based buffer switcher that allows you to hop between
files as fast as you can think! If you're tired of:

- Using a fuzzy-finder every time you want to switch to a file
- Persistent marks that you have to maintain yourself
- Feeling completely lost in projects with a lot of files

then the arena the perfect solution!

<img width="987" alt="The arena window" src="https://github.com/dzfrias/arena.nvim/assets/96022404/625c0b11-81c5-4336-bc82-84b2247ebc2b">
<sub>The arena window. You can jump to your most frecent files!</sub>

## Getting Started

TODO

## Configuration

`arena.nvim` has plenty of configuration options to suit your needs! Below are
all the configuration options along with their default values.

```lua
{
  -- Maxiumum number of files that the arena window can contain, or `nil` for
  -- an unlimited amount
  max_items = 5,
  -- Always show the enclosing folder for these paths
  always_context = { "mod.rs", "init.lua" },
  -- When set, ignores the current buffer when listing files in the window.
  ignore_current = false,
  -- Options to apply to the arena buffer.
  -- Format should be `["<OPTION>"] = <VALUE>`
  buf_opts = {
    -- Example. Uncomment to add to your config!
    -- ["relativenumber"] = false,
  },

  window = {
    width = 60,
    height = 10,
    border = "rounded",

    -- Options to apply to the arena window.
    opts = {},
  },

  -- Keybinds for the arena window.
  keybinds = {
      -- Example. Uncomment to add to your config!
      -- ["e"] = function()
      --   vim.cmd("echo \"Hello from the arena!\"")
      -- end
  },

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

Toggles the arena window.

```lua
require("arena").toggle()
```

### Open

Opens the arena window.

```lua
require("arena").open()
```

### Close

Closes the arena window, if it exists.

```lua
require("arena").close()
```

### Action

Useful in the `keybinds` key of [the config](#configuration). Wraps a function
that should do something with the currently selected file in the arena window.

The function is passed a number, which represents the buffer number of the
currently selected file. It can also accept a second argument, which is
the output of `getbufinfo()`.

```lua
-- Equivalent to the <C-v> keybind in the arena window
require("arena").action(function(bufnr, info)
  vim.cmd({
    cmd = "split",
    args = { vim.fn.bufname(bufnr) },
    mods = { vertical = true },
  })
  vim.fn.cursor(info.lnum, 0)
end)
```

## License

The plugin falls under the [MIT License](./LICENSE).
