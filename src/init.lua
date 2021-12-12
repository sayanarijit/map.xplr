local function parse_args(args)
  if args == nil then
    args = {}
  end

  if args.mode == nil then
    args.mode = "default"
  end

  if args.key == nil then
    args.key = "B"
  end

  if args.placeholder == nil then
    args.placeholder = "{}"
  end

  if args.prefer_multi_map == nil then
    args.prefer_multi_map = false
  end

  return args
end

local function get_result_files(app)
  local files = {}
  local count = 0
  for i, node in ipairs(app.selection) do
    count = i
    table.insert(files, node.absolute_path)
  end

  if count == 0 and app.focused_node then
    table.insert(files, app.focused_node.absolute_path)
    count = 1
  end

  return files, count
end

local function create_map_mode(custom, mode, func, layout, switch)
  custom["map_" .. mode] = {
    name = "map " .. mode,
    layout = {
      Vertical = {
        config = {
          constraints = {
            { Length = 1 },
            { Min = 1 },
            { Length = 3 },
          },
        },
        splits = {
          "Nothing",
          layout,
          "InputAndLogs",
        },
      },
    },
    key_bindings = {
      on_key = {
        enter = {
          help = "execute",
          messages = {
            { CallLua = func },
          },
        },
        tab = {
          help = "switch to " .. switch .. " mapping",
          messages = {
            "PopModeKeepingInputBuffer",
            { SwitchModeCustomKeepingInputBuffer = "map_" .. switch },
          },
        },
        esc = {
          help = "cancel",
          messages = {
            "PopMode",
            "ClearSelection",
          },
        },
        ["ctrl-c"] = {
          help = "terminate",
          messages = { "Terminate" },
        },
      },
      default = {
        messages = { "UpdateInputBufferFromKey" },
      },
    },
  }
end

local function map_single(input, files, count)
  local cmd = {}
  if count == 1 then
    table.insert(cmd, input .. " '" .. files[1] .. "'")
  else
    table.insert(cmd, input .. " \\")

    for i, file in ipairs(files) do
      if i == count then
        table.insert(cmd, "  '" .. file .. "'")
      else
        table.insert(cmd, "  '" .. file .. "' \\")
      end
    end
  end

  return cmd
end

local function map_multi(input, files, placeholder)
  local lines = {}
  for _, file in ipairs(files) do
    local cmd = string.gsub(input, placeholder, "'" .. file .. "'")
    table.insert(lines, cmd)
  end

  return lines
end

local single_map_layout = {
  CustomContent = {
    title = "visual single mapping",
    body = { DynamicList = { render = "custom.map.render_single_mapping" } },
  },
}

local multi_map_layout = {
  CustomContent = {
    title = "visual multi mapping",
    body = { DynamicList = { render = "custom.map.render_multi_mapping" } },
  },
}

local function setup(args)
  local xplr = xplr

  args = parse_args(args)

  if args.prefer_multi_map then
    xplr.config.modes.builtin[args.mode].key_bindings.on_key[args.key] = {
      help = "map to multiple commands",
      messages = {
        "PopMode",
        { BufferInput = "" },
        { SwitchModeCustomKeepingInputBuffer = "map_multi" },
      },
    }
  else
    xplr.config.modes.builtin[args.mode].key_bindings.on_key[args.key] = {
      help = "map to single command",
      messages = {
        "PopMode",
        { BufferInput = "" },
        { SwitchModeCustomKeepingInputBuffer = "map_single" },
      },
    }
  end

  create_map_mode(
    xplr.config.modes.custom,
    "single",
    "custom.map.execute_single",
    single_map_layout,
    "multi"
  )

  create_map_mode(
    xplr.config.modes.custom,
    "multi",
    "custom.map.execute_multi",
    multi_map_layout,
    "single"
  )

  xplr.fn.custom.map = {}

  xplr.fn.custom.map.render_single_mapping = function(ctx)
    local files, count = get_result_files(ctx.app)
    local cmds = map_single(ctx.app.input_buffer, files, count)

    local ui = { " " }
    for i, cmd in ipairs(cmds) do
      if i == 1 then
        table.insert(ui, "❯ " .. cmd)
      else
        table.insert(ui, "  " .. cmd)
      end
    end
    return ui
  end

  xplr.fn.custom.map.render_multi_mapping = function(ctx)
    local files, _ = get_result_files(ctx.app)
    local cmds = map_multi(ctx.app.input_buffer, files, args.placeholder)

    local ui = { " " }
    for _, cmd in ipairs(cmds) do
      table.insert(ui, "❯ " .. cmd)
    end
    return ui
  end

  xplr.fn.custom.map.execute_single = function(app)
    if not app.input_buffer or app.input_buffer == "" then
      return {
        "PopMode",
        "ClearSelection",
      }
    end

    local files, count = get_result_files(app)
    local cmd = table.concat(map_single(app.input_buffer, files, count), "\n")

    os.execute(cmd)
    io.write("\n[press ENTER to continue]")
    io.flush()
    io.read()
  end

  xplr.fn.custom.map.execute_multi = function(app)
    if not app.input_buffer or app.input_buffer == "" then
      return {
        "PopMode",
        "ClearSelection",
      }
    end

    local files, _ = get_result_files(app)
    local cmd = table.concat(
      map_multi(app.input_buffer, files, args.placeholder),
      "\n"
    )

    os.execute(cmd)
    io.write("\n[press ENTER to continue]")
    io.flush()
    io.read()
  end
end

return { setup = setup }
