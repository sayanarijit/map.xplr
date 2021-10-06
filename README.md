xplr plugin template
====================

Use this template to [write your own xplr plugin](https://arijitbasu.in/xplr/en/writing-plugins.html).


Requirements
------------

- Some tool


Installation
------------

### Install manually

- Add the following line in `~/.config/xplr/init.lua`

  ```lua
  package.path = os.getenv("HOME") .. '/.config/xplr/plugins/?/src/init.lua'
  ```

- Clone the plugin

  ```bash
  mkdir -p ~/.config/xplr/plugins

  git clone https://github.com/me/{plugin}.xplr ~/.config/xplr/plugins/{plugin}
  ```

- Require the module in `~/.config/xplr/init.lua`

  ```lua
  require("{plugin}").setup()
  
  -- Or
  
  require("{plugin}").setup{
    mode = "action",
    key = ":",
  }

  -- Type `::` and enjoy.
  ```


Features
--------

- Some cool feature
