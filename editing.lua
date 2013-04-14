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

function M.pos_until_char(p,forward,pos)
  pos = pos or buffer.current_pos
  local c = buffer.char_at[pos]
  if not c or p(c) then return pos end
  return M.pos_until_char(p, forward, forward and pos+1 or pos-1)
end

local function is_whitespace(c) return c == 9 or c == 32 end
local function not_whitespace(c) return not is_whitespace(c) end

function M.just_one_space()
  buffer.target_start = M.pos_until_char(not_whitespace,false)+1
  buffer.target_end = M.pos_until_char(not_whitespace,true)-1
  local extra= buffer.target_end - buffer.target_start
  if extra > 0 then
    buffer:replace_target('')
  end
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
