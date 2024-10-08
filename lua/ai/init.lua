local Config = require("ai.config")
local Assistant = require('ai.assistant')
local ChatDialog = require("ai.chat_dialog")
local Providers = require("ai.providers")
local CmpSource = require("ai.cmp_source")

local M = {}

local function setup_cmp()
  local ok, cmp = pcall(require, 'cmp')
  if not ok then
    -- cmp is not installed, so we don't set it up
    return
  end

  -- cmp is available, so we can set it up
  cmp.register_source('nvimai_cmp_source', CmpSource.new())
end

M.setup_keymaps = function()
  -- Global keymaps
  local keymaps = Config.get('keymaps')
  vim.keymap.set({ "n", "v" }, keymaps.toggle, ChatDialog.toggle, { noremap = true, silent = true })
  vim.keymap.set({ "n", "v" }, keymaps.inline_assist, Assistant.inline, { noremap = true, silent = true })
  -- Buffer-specific keymaps for ChatDialog
  local function set_chat_dialog_keymaps()
    local opts = { noremap = true, silent = true, buffer = true }
    vim.keymap.set('n', keymaps.close, ChatDialog.close, opts)
    vim.keymap.set("n", keymaps.send, ChatDialog.send, opts)
    vim.keymap.set("n", keymaps.clear, ChatDialog.clear, opts)
  end

  -- Create an autocommand to set ChatDialog keymaps when entering the chat-dialog buffer
  vim.api.nvim_create_autocmd("FileType", {
    pattern = Config.FILE_TYPE,
    callback = set_chat_dialog_keymaps
  })
  -- automatically setup Avante filetype to markdown
  vim.treesitter.language.register("markdown", Config.FILE_TYPE)
end
--
-- Setup function to initialize the plugin
M.setup = function(opts)
  Config.setup(opts)
  -- Load the plugin's configuration
  ChatDialog:setup()
  Providers.setup()
  setup_cmp()

  -- create commands
  local cmds = require("ai.cmds")
  for _, cmd in ipairs(cmds) do
    vim.api.nvim_create_user_command(cmd.cmd, cmd.callback, cmd.opts)
  end
  M.setup_keymaps()
end

return M
