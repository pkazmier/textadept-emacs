local M = {}
local I = require 'emacs.interactive'
local F = require 'emacs.find'

function M.enable()
  keys['cu'] = I.numeric_prefix
  keys['cmf'] = F.find_incremental
  keys['ct'] = {
    b = function() I.wrap(view.goto_buffer, view, I.BUFFERN) end,
    d = function() I.wrap(gui.print, "DEBUG: Count" , I.NUMBER) end,
    p = function() I.wrap(I.ntimes(buffer.line_up)  , I.NUMBER, buffer) end,
    n = function() I.wrap(I.ntimes(buffer.line_down), I.NUMBER, buffer) end,
    k = function() I.wrap(I.ntimes(buffer.line_delete), I.NUMBER, buffer) end,
    s = function() I.wrap(buffer.search_next, 0, I.PROMPT('Search for:')) end,
    x = function() I.wrap(I.with_buffer(buffer.close), I.BUFFERN) end,
  }
end

return M
