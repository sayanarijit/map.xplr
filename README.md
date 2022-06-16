https://user-images.githubusercontent.com/11632726/136155585-6f1c0047-c7cb-463e-8ef4-bd82ddbfbd5b.mp4

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

  require("map").setup{
    mode = "default",
    key = "M",
    editor = os.getenv("EDITOR") or "vim",
    placeholder = "{}"
    prefer_multi_map = false,
  }

  -- Type `M` to switch to single map mode.
  -- Then press `tab` to switch between single and multi map modes.
  -- Press `ctrl-e` to edit the command using your editor.
  ```

## Features

- All the great features from [xargs.xplr](https://github.com/sayanarijit/xargs.xplr).
- File paths will be auto quoted.
- Press `tab` to easily switch map mode without losing any context.
- Press `ctrl-e` to edit the commands using your editor.
- Visually inspect and interactively edit commands.
