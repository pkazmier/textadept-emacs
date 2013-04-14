local I = require 'emacs.interactive'
local M = {}

M.state = {
  mark = nil,
  yank = {}
}

function M.set_mark()
  gui.statusbar_text = 'Mark set'
  M.state.mark = buffer.current_pos
end

function M.save_mark(move_f)
  M.set_mark()
  move_f()
end

function M.exchange_caret_and_mark()
  buffer.current_pos, M.state.mark = M.state.mark, buffer.current_pos
  buffer:goto_pos(buffer.current_pos)
end

function M.line_end()
  buffer:line_down()
  buffer:home()
end

-- We'll need our own versions of cut and copy to support a kill
-- ring buffer. Plus, these take explicit start and end positions
-- which means they work well with interactive's I.RANGE argument.

function M.cut(beg, end_)
  buffer:set_sel(beg, end_)
  buffer:cut()
end

function M.copy(beg, end_)
  buffer:set_sel(beg, end_)
  buffer:copy()
end

-- Interactive functions

-- We don't define this as part of interactive as it depends on
-- M.state and I want the interactive module to be reusable by
-- anyone even if they don't use other parts of the emacs module.
M.RANGE = { I, function() return M.state.mark, buffer.current_pos end }

function M.with_region(f,...)
  local args = table.pack(...)
  return function()
    I.wrap(f, M.RANGE, table.unpack(args))
  end
end

function M.move_cut(move_f)
  return function()
    M.save_mark(move_f)
    M.cut(M.state.mark, buffer.current_pos)
  end
end


return M
