local M = {}
local find = gui.find

-- Events.
local events, events_connect = events, events.connect
events.FIND_WRAPPED = 'find_wrapped'

-- Text escape sequences with their associated characters.
-- @class table
-- @name escapes
local escapes = {
  ['\\a'] = '\a', ['\\b'] = '\b', ['\\f'] = '\f', ['\\n'] = '\n',
  ['\\r'] = '\r', ['\\t'] = '\t', ['\\v'] = '\v', ['\\\\'] = '\\'
}

local c = _SCINTILLA.constants

-- Finds and selects text in the current buffer.
-- @param text The text to find.
-- @param next Flag indicating whether or not the search direction is forward.
-- @param flags Search flags. This is a number mask of 4 flags: match case (2),
--   whole word (4), Lua pattern (8), and in files (16) joined with binary OR.
--   If `nil`, this is determined based on the checkboxes in the find box.
-- @param nowrap Flag indicating whether or not the search will not wrap.
-- @param wrapped Utility flag indicating whether or not the search has wrapped
--   for displaying useful statusbar information. This flag is used and set
--   internally, and should not be set otherwise.
-- @return position of the found text or `-1`
local function find_(text, next, flags, nowrap, wrapped)
  if text == '' then return end
  local buffer = buffer
  local first_visible_line = buffer.first_visible_line -- for 'no results found'

  local increment
  if buffer.current_pos == buffer.anchor then
    increment = 0
  elseif not wrapped then
    increment = next and 1 or -1
  end

  if not flags then
    flags = 0
    if find.match_case then flags = flags + c.SCFIND_MATCHCASE end
    if find.whole_word then flags = flags + c.SCFIND_WHOLEWORD end
    if find.lua then flags = flags + 8 end
    if find.in_files then flags = flags + 16 end
  end

  local result
  find.captures = nil

  if flags < 8 then
    buffer:goto_pos(buffer[next and 'current_pos' or 'anchor'] + increment)
    buffer:search_anchor()
    result = buffer['search_'..(next and 'next' or 'prev')](buffer, flags, text)
    buffer:scroll_range(buffer.anchor, buffer.current_pos)
  elseif flags < 16 then -- lua pattern search (forward search only)
    text = text:gsub('\\[abfnrtv\\]', escapes)
    local buffer_text = buffer:get_text(buffer.length)
    local results = {buffer_text:find(text, buffer.anchor + increment + 1)}
    if #results > 0 then
      find.captures = {table.unpack(results, 3)}
      buffer:set_sel(results[2], results[1] - 1)
    end
    result = results[1] or -1
  else -- find in files
    find.find_in_files()
    return
  end

  if result == -1 and not nowrap and not wrapped then -- wrap the search
    local anchor, pos = buffer.anchor, buffer.current_pos
    buffer:goto_pos((next or flags >= 8) and 0 or buffer.length)
    gui.statusbar_text = _L['Search wrapped']
    events.emit(events.FIND_WRAPPED)
    result = find_(text, next, flags, true, true)
    if result == -1 then
      gui.statusbar_text = _L['No results found']
      buffer:line_scroll(0, first_visible_line)
      buffer:goto_pos(anchor)
    end
    return result
  elseif result ~= -1 and not wrapped then
    gui.statusbar_text = ''
  end

  return result
end
events_connect(events.FIND, find_)

-- Finds and selects text incrementally in the current buffer from a start
-- point.
-- Flags other than `SCFIND_MATCHCASE` are ignored.
-- @param text The text to find.
local function find_incremental(text, next)
  if next == nil then next = true end
  local flags = find.match_case and c.SCFIND_MATCHCASE or 0
  buffer:goto_pos(M.incremental_start or 0)
  find_(text, next, flags)
end

---
-- Begins an incremental find using the command entry.
-- Only the `match_case` find option is recognized. Normal command entry
-- functionality will be unavailable until the search is finished by pressing
-- `Esc` (`⎋` on Mac OSX | `Esc` in curses).
-- @name find_incremental
function M.find_incremental()
  M.incremental, M.incremental_start = true, buffer.current_pos
  gui.command_entry.entry_text = ''
  gui.command_entry.focus()
end

events_connect(events.COMMAND_ENTRY_KEYPRESS, function(code, shift, control, alt, meta)
  if not M.incremental then return end
  --gui.print('"'..code..'"')
  if keys.KEYSYMS[code] == 'esc' then
    M.incremental = nil
  elseif keys.KEYSYMS[code] == '\b' then
    find_incremental(gui.command_entry.entry_text:sub(1, -2))
  elseif control and code == 115 then -- Ctl-S
    M.incremental_start = buffer.current_pos + 1
    find_incremental(gui.command_entry.entry_text)
    return true
  elseif control and code == 114 then -- Ctl-R
    M.incremental_start = buffer.current_pos + 1
    find_incremental(gui.command_entry.entry_text, false)
    return true
  elseif code < 256 then
    find_incremental(gui.command_entry.entry_text..string.char(code))
  end
end, 1) -- place before command_entry.lua's handler (if necessary)

-- "Find next" for incremental search.
events_connect(events.COMMAND_ENTRY_COMMAND, function(text)
  if M.incremental then
    M.incremental = nil
    return false
  end
end, 1) -- place before command_entry.lua's handler (if necessary)

return M
