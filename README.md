https://user-images.githubusercontent.com/11632726/136155585-6f1c0047-c7cb-463e-8ef4-bd82ddbfbd5b.mp4

Visually inspect and interactively execute batch commands using xplr.
It's like [xargs.xplr](https://github.com/sayanarijit/xargs.xplr) but better.

## Requirements

None

## Installation

### Install manually

- Add the following line in `~/.config/xplr/init.lua`

  ```lua
  package.path = os.getenv("HOME") .. '/.config/xplr/plugins/?/src/init.lua'
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
    placeholder = "{}"
  }

  -- Type `Ms` to map files to a single command as arguments.
  -- Type `Mm` to map files to as arguments to multiple commands in separate
  -- lines.
  ```

## Features

- All the great features from [xargs.xplr](https://github.com/sayanarijit/xargs.xplr).
- File paths will be auto quoted.
- Press `tab` to easily switch map mode without losing any context.
- Visually inspect and interactively edit commands.
