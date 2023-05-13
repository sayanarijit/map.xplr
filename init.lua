---@diagnostic disable
local xplr = xplr
---@diagnostic enable

local lines = {}

local Mode = {
  SINGLE = "single",
  MULTI = "multi",
}

local quote = nil

if xplr.util then
  quote = xplr.util.shell_quote
else
  quote = function(str)
    return "'" .. string.gsub(str, "'", [['"'"']]) .. "'"
  end
end

local function toggle(mode)
  if mode == Mode.SINGLE then
    return Mode.MULTI
  elseif mode == Mode.MULTI then
    return Mode.SINGLE
  end
end

local function split(str, delimiter)
  local result = {}
  local from = 1
  local delim_from, delim_to = string.find(str, delimiter, from)
  while delim_from do
    table.insert(result, string.sub(str, from, delim_from - 1))
    from = delim_to + 1
    delim_from, delim_to = string.find(str, delimiter, from)
  end
  table.insert(result, string.sub(str, from))
  return result
end

local placeholders = {
  ["{idx}"] = function(_, meta)
    return quote(meta.index)
  end,
  ["{0idx}"] = function(_, meta)
    local pad = string.rep("0", #tostring(meta.total) - #tostring(meta.index))
    return quote(pad .. meta.index)
  end,
  ["{num}"] = function(_, meta)
    return quote(meta.number)
  end,
  ["{0num}"] = function(_, meta)
    local pad = string.rep("0", #tostring(meta.total) - #tostring(meta.number))
    return quote(pad .. meta.number)
  end,
  ["{total}"] = function(_, meta)
    return quote(meta.total)
  end,
  ["{abs}"] = function(node)
    return quote(node.absolute_path)
  end,
  ["{rel}"] = function(node)
    return quote(node.relative_path)
  end,
  ["{name}"] = function(node)
    if #node.extension == 0 then
      return quote(node.relative_path)
    else
      return quote(node.relative_path:sub(1, -(#node.extension + 2)))
    end
  end,
  ["{ext}"] = function(node)
    return quote(node.extension)
  end,
  ["{mime}"] = function(node)
    return quote(node.mime_essence)
  end,
  ["{size}"] = function(node)
    return quote(node.size)
  end,
  ["{perm}"] = function(node)
    return quote(table.concat(xplr.util.permissions_octal(node.permissions), ""))
  end,
  ["{rwx}"] = function(node)
    return quote(xplr.util.permissions_rwx(node.permissions))
  end,
  ["{dir}"] = function(node)
    return quote(node.parent)
  end,
  ["{uid}"] = function(node)
    return quote(tostring(node.uid))
  end,
  ["{gid}"] = function(node)
    return quote(tostring(node.gid))
  end,
  ["{cdate}"] = function(node)
    return quote(os.date("%Y-%m-%d", node.created / 1000000000))
  end,
  ["{ctime}"] = function(node)
    return quote(os.date("%H:%M:%S", node.created / 1000000000))
  end,
  ["{mdate}"] = function(node)
    return quote(os.date("%Y-%m-%d", node.last_modified / 1000000000))
  end,
  ["{mtime}"] = function(node)
    return quote(os.date("%H:%M:%S", node.last_modified / 1000000000))
  end,
}

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

local function map_multi(input, nodes, placeholder, custom_placeholders, spacer)
  lines = {}
  local rows = {}
  local colwidths = {}
  local total = #nodes
  for number, node in ipairs(nodes) do
    local cmd = string.gsub(input, placeholder, quote(node.absolute_path))
    local meta = { index = number - 1, number = number, total = total }

    for p, fn in pairs(custom_placeholders) do
      cmd = string.gsub(cmd, p, fn(node, meta))
    end

    -- split cmd into columns
    local cols = {}
    for i, col in ipairs(split(cmd, spacer)) do
      table.insert(cols, col)

      if not colwidths[i] or #col > colwidths[i] then
        colwidths[i] = #col
      end
    end

    table.insert(rows, cols)
  end

  -- pad columns
  for i, cols in ipairs(rows) do
    for j, col in ipairs(cols) do
      rows[i][j] = col .. string.rep(" ", colwidths[j] - #col)
    end

    local line = table.concat(cols, " ")
    table.insert(lines, line)
  end
end

local function map(mode, app, placeholder, custom_placeholders, spacer)
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
    map_multi(app.input_buffer or "", nodes, placeholder, custom_placeholders, spacer)
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

  args.spacer = args.spacer or "{_}"

  args.custom_placeholders = args.custom_placeholders or placeholders

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

  xplr.fn.custom.map.render_single_mapping = function(ctx)
    local ui = { " " }
    for i, line in ipairs(lines) do
      if i == 1 then
        table.insert(ui, "❯ " .. line)
      else
        table.insert(ui, "  " .. line)
      end

      if i >= ctx.layout_size.height then
        break
      end
    end
    return ui
  end

  xplr.fn.custom.map.render_multi_mapping = function(ctx)
    local ui = { " " }
    for i, line in ipairs(lines) do
      table.insert(ui, "❯ " .. line)

      if i >= ctx.layout_size.height then
        break
      end
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
    return map(Mode.MULTI, app, args.placeholder, args.custom_placeholders, args.spacer)
  end
end

return { setup = setup, placeholders = placeholders }
