local static = require("codesnap.static")
local table_utils = require("codesnap.utils.table")
local module = require("codesnap.module")
local config_module = require("codesnap.config")
local modal = require("codesnap.modal")
local platform_utils = require("codesnap.utils.platform")
local path_utils = require("codesnap.utils.path")

local main = {
  cwd = static.cwd,
  highlight_mode_config = nil,
}

-- Lazy load generator after config is set
local generator_cache = nil
local function get_generator()
  if generator_cache == nil then
    generator_cache = module.load_generator(static.config.debug)
  end
  return generator_cache
end

function main.setup(config)
  static.config = table_utils.merge_config(static.config, config == nil and {} or config)
  -- Reset generator cache when config changes to reload with new debug setting
  generator_cache = nil
end

-- Save snapshot to specified save_path
--- @param save_path string
function main.save(save_path)
  if save_path == nil then
    error("Save path is not specified", 0)
  end

  local matched_extension = string.match(static.config.save_path, "%.(.+)$")

  if matched_extension ~= "png" and matched_extension ~= nil then
    error("The extension of save_path should be .png", 0)
  end

  require("generator").save_snapshot(config)
  ---@diagnostic disable-next-line: need-check-nil
  vim.notify("Save snapshot in " .. config.save_path .. " successfully")
end

-- Copy snapshot into clipboard
function main.copy()
  local config = config_module.get_config()
  get_generator().copy(config)
  vim.cmd("delmarks <>")
  vim.notify("The snapshot is copied into clipboard successfully!")
end

-- Generate ASCII code snapshot and copy it into clipboard
function main.copy_ascii()
  -- Note: ASCII clipboard copy uses direct method since Rust doesn't expose save_ascii yet
  -- If freeze occurs on Wayland, we'd need to add save_ascii to generator/src/lib.rs
  get_generator().copy_ascii(config_module.get_config())
  vim.cmd("delmarks <>")
  vim.notify("The ASCII code snapshot is copied into clipboard successfully!")
end

function main.copy_highlight()
  -- Get the originally selected text
  local original_config = config_module.get_config()
  if not original_config or not original_config.content or not original_config.content.content then
    vim.notify("No code is selected", vim.log.levels.ERROR)
    return
  end

  local selected_text = original_config.content.content
  -- Get the current buffer's filetype for syntax highlighting
  local filetype = vim.bo.filetype

  -- Pop up the modal and handle the result in the callback
  modal.pop_modal(selected_text, filetype, function(selection)
    if not selection then
      vim.notify("Selection cancelled", vim.log.levels.INFO)
      return
    end

    -- Extract the selected lines from the original text
    local lines = vim.split(selected_text, "\n", { plain = true })
    local start_line, end_line = selection[1], selection[2]

    -- Validate line numbers
    if start_line < 1 or end_line > #lines or start_line > end_line then
      vim.notify("Invalid selection range", vim.log.levels.ERROR)
      return
    end

    local config = config_module.get_config()

    if not config or not config.content then
      vim.notify("Failed to get configuration", vim.log.levels.ERROR)
      return
    end

    config.content.highlight_lines = {
      { start_line, end_line, static.config.highlight_color },
    }

    get_generator().copy(config)
    vim.cmd("delmarks <>")
    vim.notify("The snapshot is copied into clipboard successfully!")
  end)
end

function main.save_highlight() end

return main
