---@diagnostic disable
local xplr = xplr
---@diagnostic enable

local lines = {}

local Mode = {
  SINGLE = "single",
  MULTI = "multi",
}

local function quote(str)
  return "'" .. string.gsub(str, "'", [['"'"']]) .. "'"
end

local function toggle(mode)
  if mode == Mode.SINGLE then
    return Mode.MULTI
  elseif mode == Mode.MULTI then
    return Mode.SINGLE
  end
end

local function map_single(input, nodes)
  lines = {}
  if #nodes == 1 then
    table.insert(lines, input .. " " .. quote(nodes[1].absolute_path))
  else
    table.insert(lines, input .. " \\")

    for i, node in ipairs(nodes) do
      if i == #nodes then
        table.insert(lines, "  " .. quote(node.absolute_path))
      else
        table.insert(lines, "  " .. quote(node.absolute_path) .. " \\")
      end
    end
  end
end

local function map_multi(input, nodes, placeholder, custom_placeholders)
  lines = {}
  for _, node in ipairs(nodes) do
    local cmd = string.gsub(input, placeholder, quote(node.absolute_path))

    for p, fn in pairs(custom_placeholders) do
      cmd = string.gsub(cmd, p, quote(fn(node)))
    end

    table.insert(lines, cmd)
  end
end

local function map(mode, app, placeholder, custom_placeholders)
  local nodes = {}
  for _, node in ipairs(app.selection) do
    table.insert(nodes, node)
  end

  if #nodes == 0 and app.focused_node then
    table.insert(nodes, app.focused_node)
  end

  if mode == Mode.SINGLE then
    map_single(app.input_buffer or "", nodes)
  elseif mode == Mode.MULTI then
    map_multi(app.input_buffer or "", nodes, placeholder, custom_placeholders)
  end
end

local function execute()
  local cmd = table.concat(lines, "\n")

  os.execute(cmd)
  io.write("\n[press ENTER to continue]")
  io.flush()
  _ = io.read()
end

local function edit(editor)
  local cmd = table.concat(lines, "\n")

  local tmpname = os.tmpname() .. ".sh"

  local tmpfile_w = assert(io.open(tmpname, "w"))
  tmpfile_w:write(cmd)
  tmpfile_w:close()

  os.execute(string.format("%s %q", editor, tmpname))

  lines = {}
  for line in io.lines(tmpname) do
    table.insert(lines, line)
  end

  os.remove(tmpname)

  return {
    "ResetInputBuffer",
  }
end

local function parse_args(args)
  args = args or {}

  args.mode = args.mode or "default"

  args.key = args.key or "M"

  args.placeholder = args.placeholder or "{}"

  args.custom_placeholders = args.custom_placeholders
    or {
      ["{abs}"] = function(node)
        return node.absolute_path
      end,

      ["{rel}"] = function(node)
        return node.relative_path
      end,

      ["{name}"] = function(node)
        if #node.extension == 0 then
          return node.relative_path
        else
          return node.relative_path:sub(1, -(#node.extension + 2))
        end
      end,

      ["{ext}"] = function(node)
        return node.extension
      end,

      ["{mime}"] = function(node)
        return node.mime_essence
      end,

      ["{size}"] = function(node)
        return node.size
      end,
    }

  if args.prefer_multi_map == nil then
    args.prefer_multi_map = false
  end

  if args.editor == nil then
    args.editor = os.getenv("EDITOR") or "vim"
  end

  if args.editor_key == nil then
    args.editor_key = "ctrl-o"
  end

  return args
end

local function create_map_mode(custom, mode, editor, editor_key)
  custom["map_" .. mode] = {
    name = "map " .. mode,
    layout = {
      Vertical = {
        config = {
          constraints = {
            { Min = 1 },
            { Length = 3 },
          },
        },
        splits = {
          {
            CustomContent = {
              title = "visual " .. mode .. " mapping",
              body = {
                DynamicList = { render = "custom.map.render_" .. mode .. "_mapping" },
              },
            },
          },
          "InputAndLogs",
        },
      },
    },
    key_bindings = {
      on_key = {
        enter = {
          help = "execute",
          messages = {
            { CallLua = "custom.map.execute" },
          },
        },
        [editor_key] = {
          help = "open in " .. editor,
          messages = {
            { CallLua = "custom.map.edit" },
          },
        },
        tab = {
          help = "map " .. toggle(mode),
          messages = {
            "PopModeKeepingInputBuffer",
            { SwitchModeCustomKeepingInputBuffer = "map_" .. toggle(mode) },
            { CallLuaSilently = "custom.map.update_" .. toggle(mode) },
          },
        },
        esc = {
          help = "cancel",
          messages = {
            "PopMode",
            "ClearSelection",
            "ExplorePwd",
          },
        },
        ["ctrl-c"] = {
          help = "terminate",
          messages = { "Terminate" },
        },
      },
      default = {
        messages = {
          "UpdateInputBufferFromKey",
          { CallLuaSilently = "custom.map.update_" .. mode },
        },
      },
    },
  }
end

local function setup(args)
  args = parse_args(args)

  local mode = args.mode

  if type(mode) == "string" then
    mode = xplr.config.modes.builtin[mode]
  end

  if args.prefer_multi_map then
    mode.key_bindings.on_key[args.key] = {
      help = "map to multiple commands",
      messages = {
        "PopMode",
        { SetInputBuffer = "" },
        { CallLuaSilently = "custom.map.update_" .. Mode.MULTI },
        { SwitchModeCustomKeepingInputBuffer = "map_" .. Mode.MULTI },
      },
    }
  else
    mode.key_bindings.on_key[args.key] = {
      help = "map to single command",
      messages = {
        "PopMode",
        { SetInputBuffer = "" },
        { CallLuaSilently = "custom.map.update_" .. Mode.SINGLE },
        { SwitchModeCustomKeepingInputBuffer = "map_" .. Mode.SINGLE },
      },
    }
  end

  create_map_mode(xplr.config.modes.custom, Mode.SINGLE, args.editor, args.editor_key)
  create_map_mode(xplr.config.modes.custom, Mode.MULTI, args.editor, args.editor_key)

  xplr.fn.custom.map = {}

  xplr.fn.custom.map.render_single_mapping = function(_)
    local ui = { " " }
    for i, line in ipairs(lines) do
      if i == 1 then
        table.insert(ui, "❯ " .. line)
      else
        table.insert(ui, "  " .. line)
      end
    end
    return ui
  end

  xplr.fn.custom.map.render_multi_mapping = function(_)
    local ui = { " " }
    for _, line in ipairs(lines) do
      table.insert(ui, "❯ " .. line)
    end
    return ui
  end

  xplr.fn.custom.map.execute = function(_)
    return execute()
  end

  xplr.fn.custom.map.edit = function(_)
    return edit(args.editor)
  end

  xplr.fn.custom.map.update_single = function(app)
    return map(Mode.SINGLE, app, args.placeholder, args.custom_placeholders)
  end

  xplr.fn.custom.map.update_multi = function(app)
    return map(Mode.MULTI, app, args.placeholder, args.custom_placeholders)
  end
end

return { setup = setup }
