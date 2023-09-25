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

`arena.nvim` has plenty of configuration options to suit your needs!

```lua
{
  -- Maxiumum number of files that the arena window can contain.
  max_items = 5,
  -- Always show the enclosing folder for these paths
  always_context = { "mod.rs", "init.lua" },
  -- When set, ignores the current buffer when listing files in the window.
  ignore_current = false,
  -- Options to apply to the arena buffer.
  -- Format should be `["<OPTION>"] = <VALUE>`
  buf_opts = {},

  window = {
    width = 60,
    height = 10,
    border = "rounded",

    -- Options to apply to the arena window.
    opts = {},
  },

  -- Keybinds for the arena window. Format should be
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

### Opener

Useful in the `keybinds` key of [the config](#configuration). Wraps a function
that should open the currently selected file in the arena window.

The function may also return `false` to cancel opening the file.

```lua
-- Equivalent to the <C-v> keybind in the arena window
require("arena").opener(function(bufnr)
  vim.cmd({
    cmd = "split",
    args = { vim.fn.bufname(bufnr) },
    mods = { vertical = true },
  })
end)
```

## License

The plugin falls under the [MIT License](./LICENSE).
