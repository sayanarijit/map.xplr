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
    layout = layout,
    key_bindings = {
      on_key = {
        enter = {
          help = "execute",
          messages = {
            { CallLua = func },
          },
        },
        backspace = {
          help = "remove last character",
          messages = { "RemoveInputBufferLastCharacter" },
        },
        tab = {
          help = "switch to " .. switch .. " mapping",
          messages = {
            "PopModeKeepingInputBuffer",
            { SwitchModeCustomKeepingInputBuffer = "map_" .. switch },
          },
        },
        ["ctrl-u"] = {
          help = "remove line",
          messages = {
            { SetInputBuffer = "" },
          },
        },
        ["ctrl-w"] = {
          help = "remove last word",
          messages = { "RemoveInputBufferLastWord" },
        },
        esc = {
          help = "cancel",
          messages = { "PopMode", "ClearSelection" },
        },
        ["ctrl-c"] = {
          help = "terminate",
          messages = { "Terminate" },
        },
      },
      default = {
        messages = { "BufferInputFromKey" },
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
    table.insert(lines, "  " .. cmd)
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

  xplr.config.modes.builtin[args.mode].key_bindings.on_key[args.key] = {
    help = "map",
    messages = {
      "PopMode",
      { SwitchModeCustom = "map" },
    },
  }

  xplr.config.modes.custom.map = {
    name = "map",
    key_bindings = {
      on_key = {
        s = {
          help = "single line",
          messages = {
            "PopMode",
            { SwitchMode = "map_single" },
            { SetInputBuffer = "" },
          },
        },
        m = {
          help = "multi line",
          messages = {
            "PopMode",
            { SwitchMode = "map_multi" },
            { SetInputBuffer = "" },
          },
        },
        esc = {
          help = "cancel",
          messages = { "PopMode" },
        },
        ["ctrl-c"] = {
          help = "terminate",
          messages = { "Terminate" },
        },
      },
    },
  }

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
    local cmd = map_single(ctx.app.input_buffer, files, count)
    local ui = { " ", "  ❯ " .. ctx.app.input_buffer .. "█", " " }

    for _, line in ipairs(cmd) do
      table.insert(ui, "    " .. line)
    end

    return ui
  end

  xplr.fn.custom.map.render_multi_mapping = function(ctx)
    local files, _ = get_result_files(ctx.app)
    local cmd = map_multi(ctx.app.input_buffer, files, args.placeholder)
    local ui = { " ", "  ❯ " .. ctx.app.input_buffer .. "█", " " }

    for _, line in ipairs(cmd) do
      table.insert(ui, "  " .. line)
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
