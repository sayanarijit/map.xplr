---@diagnostic disable
local xplr = xplr
---@diagnostic enable

local lines = {}

local Mode = {
  SINGLE = "single",
  MULTI = "multi",
}

local function toggle(mode)
  if mode == Mode.SINGLE then
    return Mode.MULTI
  elseif mode == Mode.MULTI then
    return Mode.SINGLE
  end
end

local function map_single(input, files)
  lines = {}
  if #files == 1 then
    table.insert(lines, input .. " '" .. files[1] .. "'")
  else
    table.insert(lines, input .. " \\")

    for i, file in ipairs(files) do
      if i == #files then
        table.insert(lines, "  '" .. file .. "'")
      else
        table.insert(lines, "  '" .. file .. "' \\")
      end
    end
  end
end

local function map_multi(input, files, placeholder)
  lines = {}
  for _, file in ipairs(files) do
    local cmd = string.gsub(input, placeholder, "'" .. file .. "'")
    table.insert(lines, cmd)
  end
end

local function map(mode, app, placeholder)
  local files = {}
  for _, node in ipairs(app.selection) do
    table.insert(files, node.absolute_path)
  end

  if #files == 0 and app.focused_node then
    table.insert(files, app.focused_node.absolute_path)
  end

  if mode == Mode.SINGLE then
    map_single(app.input_buffer or "", files)
  elseif mode == Mode.MULTI then
    map_multi(app.input_buffer or "", files, placeholder)
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

  if args.prefer_multi_map == nil then
    args.prefer_multi_map = false
  end

  if args.editor == nil then
    args.editor = os.getenv("EDITOR") or "vim"
  end

  return args
end

local function create_map_mode(custom, mode, editor)
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
        ["ctrl-e"] = {
          help = "edit in " .. editor,
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

  if args.prefer_multi_map then
    xplr.config.modes.builtin[args.mode].key_bindings.on_key[args.key] = {
      help = "map to multiple commands",
      messages = {
        "PopMode",
        { SetInputBuffer = "" },
        { CallLuaSilently = "custom.map.update_" .. Mode.MULTI },
        { SwitchModeCustomKeepingInputBuffer = "map_" .. Mode.MULTI },
      },
    }
  else
    xplr.config.modes.builtin[args.mode].key_bindings.on_key[args.key] = {
      help = "map to single command",
      messages = {
        "PopMode",
        { SetInputBuffer = "" },
        { CallLuaSilently = "custom.map.update_" .. Mode.SINGLE },
        { SwitchModeCustomKeepingInputBuffer = "map_" .. Mode.SINGLE },
      },
    }
  end

  create_map_mode(xplr.config.modes.custom, Mode.SINGLE, args.editor)
  create_map_mode(xplr.config.modes.custom, Mode.MULTI, args.editor)

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
    return map(Mode.SINGLE, app, args.placeholder)
  end

  xplr.fn.custom.map.update_multi = function(app)
    return map(Mode.MULTI, app, args.placeholder)
  end
end

return { setup = setup }
