local config = require 'typst-preview.config'
local manager = require 'typst-preview.manager'
local utils = require 'typst-preview.utils'

---Whether lsp handlers have been registered
local lsp_handlers_registered = false

local M = {}

---@param method string
---@param handler fun(result)
local function register_lsp_handler(method, handler)
  vim.lsp.handlers[method] = function(err, result, ctx)
    utils.debug(
      'Received event from server: ',
      ctx.method,
      ', err = ',
      err,
      ', result = ',
      result
    )

    if err ~= nil then
      return
    end

    handler(result)
  end ---@type lsp.Handler
end

function M.ensure_registered()
  if lsp_handlers_registered then
    return
  end

  local id = vim.api.nvim_create_augroup('typst-preview-autocmds', {})
  -- TODO: check if detach is from the file we care about
  vim.api.nvim_create_autocmd('LspDetach', {
    group = id,
    callback = function(ev)
      local path = utils.get_main_file(ev.buf)
      manager.remove(
        { client = ev.data.client, path = path },
        'server detached'
      )
    end,
  })

  vim.api.nvim_create_autocmd('CursorMoved', {
    pattern = '*.typ',
    callback = function(ev)
      utils.debug('received CursorMoved in file ', ev.file)
      if config.get_follow_cursor() then
        manager.scroll_preview()
      end
    end,
  })

  register_lsp_handler('tinymist/preview/dispose', function(result)
    local task_id = result['taskId']

    manager.remove({ task_id = task_id }, 'received dispose from server')
  end)

  lsp_handlers_registered = true
end

return M
