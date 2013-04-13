local M = {}

M.state = {
  mark = nil,
  yank = {}
}

function M.set_mark()
  gui.statusbar_text = 'Mark set'
  M.state.mark = buffer.current_pos
end

function M.exchange_caret_and_mark()
  buffer.current_pos, M.state.mark = M.state.mark, buffer.current_pos
  buffer:goto_pos(buffer.current_pos)
end

function M.line_end()
  buffer:line_down()
  buffer:home()
end

function M.with_region(f,...)
  local args = table.pack(...)
  return function()
    buffer:set_sel(M.state.mark, buffer.current_pos)
    f(table.unpack(args))
  end
end

function M.with_move(move_f,f,...)
  local args = table.pack(...)
  return function()
    M.set_mark()
    move_f()
    M.with_region(f,table.unpack(args))()
  end
end

function M.yank(move_f)
  return function()
    M.with_move(move_f, buffer.cut)()
  end
end

return M
