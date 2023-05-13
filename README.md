# map.xplr

Visually inspect and interactively execute batch commands using [xplr](https://xplr.dev)

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
    mode = "default",  -- or `xplr.config.modes.builtin.default`
    key = "M",
    editor = os.getenv("EDITOR") or "vim",
    editor_key = "ctrl-o",
    prefer_multi_map = false,
    placeholder = "{}",
    spacer = "{_}",
    custom_placeholders = map.placeholders,
  }

  -- Type `M` to switch to single map mode.
  -- Then press `tab` to switch between single and multi map modes.
  -- Press `ctrl-o` to edit the command using your editor.
  ```

## Placeholders

Apart from `{}`, the primary placeholder and `{_}`, the spacer, you can also use the following placeholders:

- `{idx}`: 0-based index of the node.
- `{0idx}`: 0-padded, 0-based index of the node.
- `{num}`: 1-based index of the node.
- `{0num}`: 0-padded, 1-based index of the node.
- `{total}`: Total number of nodes.
- `{abs}`: Absolute path of the node.
- `{rel}`: Relative path of the node.
- `{name}`: Name of the node.
- `{ext}`: Extension of the node.
- `{mime}`: Mime essence of the node.
- `{size}`: Size of the node.
- `{perm}`: Permissions of the node in octal.
- `{rwx}`: Permissions of the node in rwx.
- `{dir}`: Parent directory of the node.
- `{uid}`: User ID of the node.
- `{gid}`: Group ID of the node.
- `{cdate}`: Creation date of the node in YYYY-MM-DD.
- `{ctime}`: Creation time of the node in HH:MM:SS.
- `{mdate}`: Last modification date of the node in YYYY-MM-DD.
- `{mtime}`: Last modification time of the node in HH:MM:SS.

## Custom Placeholders

You can add new custom placeholders, or modify the existing ones via the `placeholders` table.

It is just a function `function(node, meta)` that takes the following arguments and returns a string.

- [node](#node)
- [meta](#meta)

### node

See [the official documentation](https://xplr.dev/en/lua-function-calls#node).

### meta

It contains the following fields:

- `total`: Total count of the nodes being operated on (used in `{total}`).
- `index`: 0-based index of the node (used in `{idx}` and `{0idx}`).
- `number`: 1-based index of the node (used in `{num}` and `{0num}`).

### Example

```lua
local map = require("map")

-- Add custom placeholders
map.placeholders["{created}"] = function(node, meta)
  return xplr.util.shell_quote(os.date("%Y-%m-%d@%H:%M:%S", node.created / 1000000000))
end

-- Alternatively, compose existing placeholders
map.placeholders["{modified}"] = function(node, meta)
  local d = map.placeholders["{mdate}"](node, meta)
  local t = map.placeholders["{mtime}"](node, meta)
  return d .. "@" .. t
end
```

## Features

- All the great features from [xargs.xplr](https://github.com/sayanarijit/xargs.xplr).
- File paths will be auto quoted.
- Press `tab` to easily switch map mode without losing any context.
- Press `ctrl-o` to open the command in your editor.
- Visually inspect and interactively edit commands.
- Use placeholder `{}` and spacer `{_}` to format commands in multi map mode.
- Use custom placeholders for custom file properties.
