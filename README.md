# map.xplr

Visually inspect and interactively execute batch commands using xplr

### Basic Demo

https://user-images.githubusercontent.com/11632726/174024410-3fd75ca0-3ec8-4ef4-afcf-7ac002e5adbb.mp4

### Oraganize Files

https://user-images.githubusercontent.com/11632726/179403355-e1647635-e825-4db2-8b3c-71843a5d16f9.mp4

Visually inspect and interactively execute batch commands using xplr.
It's like [xargs.xplr](https://github.com/sayanarijit/xargs.xplr) but better.

**Tip:** This plugin can be used with [find.xplr](https://github.com/sayanarijit/find.xplr).

## Requirements

None

## Installation

### Install manually

- Add the following line in `~/.config/xplr/init.lua`

  ```lua
  local home = os.getenv("HOME")
  package.path = home
  .. "/.config/xplr/plugins/?/init.lua;"
  .. home
  .. "/.config/xplr/plugins/?.lua;"
  .. package.path
  ```

- Clone the plugin

  ```bash
  mkdir -p ~/.config/xplr/plugins

  git clone https://github.com/sayanarijit/map.xplr ~/.config/xplr/plugins/map
  ```

- Require the module in `~/.config/xplr/init.lua`

  ```lua
  require("map").setup()

  -- Or

  local map = require("map")

  map.setup{
    mode = "default"  -- or `xplr.config.modes.builtin.default`,
    key = "M",
    editor = os.getenv("EDITOR") or "vim",
    editor_key = "ctrl-o",
    prefer_multi_map = false,
    placeholder = "{}",
    custom_placeholders = {
      ["{ext}"] = function(node)
        -- See https://xplr.dev/en/lua-function-calls#node
        return node.extension
      end,

      ["{name}"] = map.placeholders["{name}"]
    },
  }

  -- Type `M` to switch to single map mode.
  -- Then press `tab` to switch between single and multi map modes.
  -- Press `ctrl-o` to edit the command using your editor.
  ```

## Features

- All the great features from [xargs.xplr](https://github.com/sayanarijit/xargs.xplr).
- File paths will be auto quoted.
- Use custom placeholders for custom file properties.
- Press `tab` to easily switch map mode without losing any context.
- Press `ctrl-o` to open the command in your editor.
- Visually inspect and interactively edit commands.
