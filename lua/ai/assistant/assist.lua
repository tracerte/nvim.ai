local lustache = require("ai.lustache")
local Prompts = require("ai.assistant.prompts")

M = {}

--- Get the filetype of the current buffer
-- @param bufnr number The buffer number
-- @return string|nil The filetype of the buffer, or nil if not determined
-- @return string|nil Error message if the buffer number is invalid
local function get_buffer_filetype()
  local bufnr = vim.api.nvim_get_current_buf()
  -- Ensure the buffer number is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil, "Invalid buffer number"
  end

  -- Get the filetype of the buffer
  local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype')

  -- If filetype is an empty string, it might mean it's not set
  if filetype == "" then
    -- Try to get the filetype from the buffer name
    local bufname = vim.api.nvim_buf_get_name(bufnr)
    if bufname ~= "" then
      filetype = vim.filetype.match({ filename = bufname })
    end
  end

  -- If still empty, return "unknown"
  if filetype == "" then
    filetype = nil
  end

  return filetype
end

--- Read the content of multiple buffers into a single string
-- @param buffer_numbers table A list of buffer numbers
-- @return string The concatenated content of all specified buffers
local function build_document(buffer_numbers)
  local contents = {}
  for _, bufnr in ipairs(buffer_numbers) do
    if vim.api.nvim_buf_is_valid(bufnr) then
      -- get the file name without parent directory
      local full_path = vim.api.nvim_buf_get_name(bufnr)
      local filename = vim.fn.fnamemodify(full_path, ":t")

      -- get the file type, or empty string if not available
      local filetype = vim.api.nvim_buf_get_option(bufnr, 'filetype') or ''

      -- get buffer content
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local buffer_content = table.concat(lines, "\n")

      -- format the content
      local formatted_content = string.format("%s\n```%s\n%s\n```", filename, filetype, buffer_content)

      table.insert(contents, formatted_content)
    end
  end
  return table.concat(contents, "\n\n")
end

local function get_prefix_block_suffix(start_line, end_line)
  -- Get the current buffer number
  local bufnr = vim.api.nvim_get_current_buf()

  -- Get the total number of lines in the buffer
  local total_lines = vim.api.nvim_buf_line_count(bufnr)

  -- Get the prefix (lines before the cursor)
  local prefix = {}
  for i = 1, start_line - 1 do
    table.insert(prefix, vim.api.nvim_buf_get_lines(bufnr, i - 1, i, true)[1])
  end

  -- Get the block (lines between start_line and end_line, inclusive)
  local block = {}
  if start_line < end_line then
    for i = start_line, end_line do
      table.insert(block, vim.api.nvim_buf_get_lines(bufnr, i - 1, i, true)[1])
    end
  end

  -- Get the suffix (lines after the cursor)
  local suffix = {}
  for i = end_line + 1, total_lines do
    table.insert(suffix, vim.api.nvim_buf_get_lines(bufnr, i - 1, i, true)[1])
  end

  return table.concat(prefix, "\n"), table.concat(block, "\n"), table.concat(suffix, "\n")
end

local function build_inline_document(is_insert, start_line, end_line)
  local prefix, block, suffix = get_prefix_block_suffix(start_line, end_line)

  if is_insert then
    -- Add '<insert_here>' in the middle
    return table.concat({
      prefix,
      "<insert_here></insert_here>",
      suffix
    }, "\n\n")
  else
    -- TODO: rewrite section
    return table.concat({
      prefix,
      "<rewrite_this>",
      block,
      "</rewrite_this>",
      suffix
    }, "\n\n")
  end
end

-- @param input_string string The raw input string containing user prompt and slash commands
-- @param language_name string|nil The name of the programming language (optional)
-- @param is_insert boolean Whether the operation is an insert operation
-- @return table A table containing parsed information:
--   - buffers: list of buffer numbers extracted from /buf commands
--   - user_prompt: the user's prompt text
--   - language_name: the determined language name
--   - content_type: "text" or "code" based on the language
--   - is_insert: boolean indicating if it's an insert operation
--   - rewrite_section: nil (TODO)
--   - is_truncated: nil (TODO)
local function build_inline_context(user_prompt, language_name, is_insert, start_line, end_line)
  -- TODO: rewrite section
  -- Get the current cursor line number
  local cur_line = vim.fn.line(".")

  local document = build_inline_document(is_insert, start_line, end_line)

  if language_name == nil then
    language_name = get_buffer_filetype()
  end

  local content_type = language_name == nil or language_name == "text" or language_name == "markdown" and "text" or
      "code"

  local result = {
    document_content = document,
    user_prompt = user_prompt,
    language_name = language_name,
    content_type = content_type,
    is_insert = is_insert, -- TODO: assist inline
    rewrite_section = nil, -- TODO: Rewrite section
    is_truncated = nil,    -- TODO: The code length could be larger than the context
  }
  return result
end

-- TODO: How to implement the feature: `apply the change` in zed ai?
-- Zed caches all the messages in the assistant panel.
-- Zed builds prompt for the current buffer.
-- Then append the prompt in the end of messages.
M.parse_inline_assist_prompt = function(raw_prompt, language_name, is_insert, start_line, end_line)
  local context = build_inline_context(raw_prompt, language_name, is_insert, start_line, end_line)
  local prompt_template = Prompts.CONTENT_PROMPT
  local prompt = lustache:render(prompt_template, context)
  return prompt
end

M.parse_user_message = function(lines)
  local buffers = {}
  local user_prompt_lines = {}
  -- parse slash commands
  for _, line in ipairs(lines) do
    local buf_match = line:match("^/buf%s+(%d+)")
    if buf_match then
      table.insert(buffers, tonumber(buf_match))
    else
      table.insert(user_prompt_lines, line)
    end
  end

  local user_prompt = table.concat(user_prompt_lines, "\n"):gsub("^%s*(.-)%s*$", "%1")
  local prompt
  if #buffers > 0 then
    local document = build_document(buffers)
    prompt = "<document>\n" .. document .. "\n</document>\n\n" .. user_prompt
  else
    prompt = user_prompt
  end
  return prompt
end

return M
