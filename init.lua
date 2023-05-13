---@diagnostic disable
local xplr = xplr
---@diagnostic enable

local state = {
  lines = {},
  available_placeholders = {},
  suggested_placeholders = {},
  highlighted_placeholder = 1,
  partial_match = 0,
}

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

local function render_title(count)
  local title = " " .. tostring(count)
  if count == 1 then
    title = title .. " node selected "
  else
    title = title .. " nodes selected "
  end

  return title
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
    return quote(meta.index + 1)
  end,
  ["{0num}"] = function(_, meta)
    local num = meta.index + 1
    local pad = string.rep("0", #tostring(meta.total) - #tostring(num))
    return quote(pad .. num)
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
  state.lines = {}
  if #nodes == 0 then
    return
  elseif #nodes == 1 then
    table.insert(state.lines, input .. " " .. quote(nodes[1].absolute_path))
  else
    table.insert(state.lines, input .. " \\")

    for i, node in ipairs(nodes) do
      if i == #nodes then
        table.insert(state.lines, "  " .. quote(node.absolute_path))
      else
        table.insert(state.lines, "  " .. quote(node.absolute_path) .. " \\")
      end
    end
  end
end

local function map_multi(input, nodes, placeholder, custom_placeholders, spacer)
  state.lines = {}
  local rows = {}
  local colwidths = {}
  local total = #nodes
  for num, node in ipairs(nodes) do
    local cmd = string.gsub(input, placeholder, quote(node.absolute_path))
    local meta = { index = num - 1, total = total }

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
    table.insert(state.lines, line)
  end

  -- suggest placeholders
  state.suggested_placeholders = {}
  state.partial_match = 0
  for _, ph in ipairs(state.available_placeholders) do
    for i = #ph - 1, 1, -1 do
      local partial = string.sub(ph, 1, i)
      if string.sub(input, -#partial) == partial then
        state.partial_match = i
        table.insert(state.suggested_placeholders, ph)
        break
      end
    end
  end

  if #state.suggested_placeholders ~= 0 then
    state.highlighted_placeholder = 1
    table.sort(state.suggested_placeholders, function(a, b)
      return #a < #b
    end)
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
  local cmd = table.concat(state.lines, "\n")

  os.execute(cmd)
  io.write("\n[press ENTER to continue]")
  io.flush()
  _ = io.read()
end

local function edit(editor)
  local cmd = table.concat(state.lines, "\n")

  local tmpname = os.tmpname() .. ".sh"

  local tmpfile_w = assert(io.open(tmpname, "w"))
  tmpfile_w:write(cmd)
  tmpfile_w:close()

  os.execute(string.format("%s %q", editor, tmpname))

  state.lines = {}
  for line in io.lines(tmpname) do
    table.insert(state.lines, line)
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

  args.editor = args.editor or os.getenv("EDITOR") or "vim"

  args.editor_key = args.editor_key or "ctrl-o"

  return args
end

local function create_map_mode(custom, mode, editor, editor_key)
  local modename = "map_" .. mode
  custom[modename] = {
    name = "map " .. mode,
    layout = {
      Horizontal = {
        config = {
          constraints = {
            { Percentage = 70 },
            { Percentage = 30 },
          },
        },
        splits = {
          {
            Vertical = {
              config = {
                constraints = {
                  { Min = 1 },
                  { Length = 3 },
                },
              },
              splits = {
                { Dynamic = "custom.map.render_" .. mode .. "_mapping" },
                "InputAndLogs",
              },
            },
          },
          "HelpMenu",
        },
      },
    },
    key_bindings = {
      on_key = {
        enter = {
          help = "submit",
          messages = {
            { CallLua = "custom.map.submit" },
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

  if mode == Mode.MULTI then
    custom[modename].key_bindings.on_key["up"] = {
      help = "prev placeholder",
      messages = {
        { CallLuaSilently = "custom.map.prev_placeholder" },
      },
    }

    custom[modename].key_bindings.on_key["down"] = {
      help = "next placeholder",
      messages = {
        { CallLuaSilently = "custom.map.next_placeholder" },
      },
    }

    custom[modename].key_bindings.on_key["ctrl-p"] =
      custom[modename].key_bindings.on_key["up"]
    custom[modename].key_bindings.on_key["ctrl-n"] =
      custom[modename].key_bindings.on_key["down"]
  end
end

local function setup(args)
  args = parse_args(args)

  state.available_placeholders = { args.placeholder, args.spacer }
  for p, _ in pairs(args.custom_placeholders) do
    table.insert(state.available_placeholders, p)
  end

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
    local count = #state.lines

    if count == 0 then
      return {
        CustomParagraph = {
          body = xplr.util.paint("\n No node selected...", { fg = "Yellow" }),
        },
      }
    elseif count > 1 then
      count = count - 1
    end

    local title = render_title(count)
    local body = { " " }
    for i, line in ipairs(state.lines) do
      if i == 1 then
        table.insert(body, "❯ " .. line)
      else
        table.insert(body, "  " .. line)
      end

      if i >= ctx.layout_size.height then
        break
      end
    end

    return {
      CustomList = {
        ui = { title = { format = title } },
        body = body,
      },
    }
  end

  xplr.fn.custom.map.render_multi_mapping = function(ctx)
    local count = #state.lines
    if count == 0 then
      return {
        CustomParagraph = {
          body = xplr.util.paint("\n No node selected...", { fg = "Yellow" }),
        },
      }
    end

    if #state.suggested_placeholders ~= 0 then
      local title = " suggested placeholders ("
        .. tostring(state.highlighted_placeholder)
        .. "/"
        .. tostring(#state.suggested_placeholders)
        .. "/"
        .. tostring(#state.available_placeholders)
        .. ") "

      local body = { " " }
      local top = state.highlighted_placeholder
        - (state.highlighted_placeholder % (ctx.layout_size.height - 3))
      local bottom = top + ctx.layout_size.height - 3
      for i, placeholder in ipairs(state.suggested_placeholders) do
        if i >= top then
          if i >= bottom then
            break
          else
            if i == state.highlighted_placeholder then
              placeholder =
                xplr.util.paint(placeholder, { add_modifiers = { "Reversed" } })
            end
            table.insert(body, " " .. placeholder)
          end
        end
      end

      return {
        CustomList = {
          ui = { title = { format = title } },
          body = body,
        },
      }
    end

    local title = render_title(count)
    local body = { " " }
    for i, line in ipairs(state.lines) do
      table.insert(body, "❯ " .. line)
      if i >= ctx.layout_size.height then
        break
      end
    end

    return {
      CustomList = {
        ui = { title = { format = title } },
        body = body,
      },
    }
  end

  xplr.fn.custom.map.submit = function(app)
    if #state.suggested_placeholders ~= 0 then
      local placeholder = state.suggested_placeholders[state.highlighted_placeholder]
      if placeholder then
        local input = string.sub(app.input_buffer, 1, -state.partial_match - 1)
        return {
          { SetInputBuffer = input .. placeholder },
          { CallLuaSilently = "custom.map.update_multi" },
        }
      end
    else
      return execute()
    end
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

  xplr.fn.custom.map.next_placeholder = function(_)
    if #state.suggested_placeholders == 0 then
      state.suggested_placeholders = state.available_placeholders
      state.highlighted_placeholder = 1
    elseif state.highlighted_placeholder == #state.suggested_placeholders then
      state.highlighted_placeholder = 1
    else
      state.highlighted_placeholder = state.highlighted_placeholder + 1
    end
  end

  xplr.fn.custom.map.prev_placeholder = function(_)
    if #state.suggested_placeholders == 0 then
      state.suggested_placeholders = state.available_placeholders
      state.highlighted_placeholder = #state.suggested_placeholders
    elseif state.highlighted_placeholder == 1 then
      state.highlighted_placeholder = #state.suggested_placeholders
    else
      state.highlighted_placeholder = state.highlighted_placeholder - 1
    end
  end
end

return { setup = setup, placeholders = placeholders }
