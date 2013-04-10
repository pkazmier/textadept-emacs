local I = {}

-- Interactive Support:

-- Wouldn't it be great to be able to assign non-interactive functions
-- to key bindings without having to write a wrapper to prompt the
-- user for the correct arguments? For example, why should we define
-- gui.switch_buffer if we could bind view.goto_buffer directly to a
-- key binding?  Or, how about binding buffer.search_next directly?
-- Here are my bindings (on my ctl-t key chain).
--
-- keys['ct'] = {
--   b = function() I.wrap(view.goto_buffer, view, I.BUFFERN) end,
--   s = function() I.wrap(buffer.search_next, 0, I.PROMPT('Search for:')) end,
-- }
--
-- In the above example, I.wrap is a function that wraps functions
-- that were not meant to be bound directly to keys because they
-- require arguments that must be obtained one way or the other. The
-- first argument to I.wrap is the function you are wrapping. The rest
-- of the arguments will be passed directly to the wrapped function
-- when I.wrap is invoked with the two following notable exceptions.
--
-- First, I.BUFFERN argument instructs I.wrap to prompt the user for a
-- buffer which is then converted to the index of the buffer (there is
-- a I.BUFFER which returns a reference to the buffer directly).
-- Second, I.PROMPT(label) instructs I.wrap to prompt for user for a
-- string using label in the dialog box. Cool right??
--
-- Even better, wouldn't it be awesome, if you are a keyboard junkie
-- like me, to be able to execute a command an arbitrary number of
-- times based on the clever use of key chaining? Let's assume ctl-u
-- is a magical binding that let's us specify a number as part of a
-- key sequence. For example:
--
-- keys['cu'] = I.numeric_prefix
-- keys['ct'] = {
--   d = function() I.wrap(gui.print, "Count:", I.NUMBER) end,
-- }
--
-- I.NUMBER is replaced with the number specified as part of that
-- magical ctl-u key sequence. For example:
--
-- ctl-u 5 ctl-t d      --> Prints 'Count: 5' in Messages buffer
-- ctl-u 1 0 ctl-t d    --> Prints 'Count: 10' in Messages buffer
-- ctl-u 2 0 0 ctl-t d  --> Prints 'Count: 200' in Messages buffer
--
-- Okay, neat, but who cares right? Well, now let's define a helper
-- function ntimes(fn) that returns a function that takes as its first
-- argument the number of times to invoke fn. Any additional arguments
-- are passed to fn. For example:
--
--   local fn = ntimes(buffer.line_up)
--   fn(3, buffer)    --> invokes buffer.line_up(buffer) three times
--   fn(10, buffer)   --> invokes buffer.line_up(buffer) ten times
--
-- With ntimes(fn), I.wrap, I.NUMBER, and our magical ctl-u numeric
-- key chainer, we can define the following:
--
-- keys['cu'] = I.numeric_prefix
-- keys['ct'] = {
--   p = function() I.wrap(I.ntimes(buffer.line_up)    , I.NUMBER, buffer) end,
--   n = function() I.wrap(I.ntimes(buffer.line_down)  , I.NUMBER, buffer) end,
--   k = function() I.wrap(I.ntimes(buffer.line_delete), I.NUMBER, buffer) end,
-- }
--
-- Now you can delete lines instantaneously with the following key
-- sequence using the bindings that we defined above:
--
-- ctl-t k             --> Deletes 1 line, no numeric prefix defined
-- cll-u ctl-t k       --> Deletes 1 line, no numeric prefix defined
-- ctl-u 3 ctl-t k     --> Deletes 3 lines, numeric prefix is 3
-- ctl-u 1 0 ctl-t k   --> Deletes 10 lines, numeric prefix is 10
--
-- Hopefully you get the idea. Below is the implementation.

-- -------------------------------------------------------------------
-- Helper GUI Functions:

-- Ideally, the next two functions should be added to textadept
-- proper's core/gui.lua as they provide a means to prompt the user
-- for input. For example, one could ask for an arbitrary string,
-- using gui.input_box, that might be used as a search
-- string. Alternatively, one might want to prompt for a buffer using
-- gui.select_buffer, which is based entirely on the existing
-- gui.switch_buffer.

-- Prompt the user for a string. Returns the string or nil.
function I.input_box(prompt, button, initial)
  button = button or 'Ok'
  initial = initial or ''
  local result = gui.dialog('inputbox',
                            '--text', initial,
                            '--informative-text', prompt,
                            '--button1', button)
  return result:match('%d\n(.*)\n')
end

-- Prompt the user for a buffer. Returns a reference to the buffer or nil.
function I.select_buffer(prompt)
  prompt = prompt or 'Select Buffer'
  local columns, items = {_L['Name'], _L['File']}, {}
  for _, buffer in ipairs(_BUFFERS) do
    local filename = buffer.filename or buffer._type or _L['Untitled']
    local basename = buffer.filename and filename:match('[^/\\]+$') or filename
    items[#items + 1] = (buffer.dirty and '*' or '')..basename
    items[#items + 1] = filename
  end
  local i = gui.filteredlist(_L[prompt], columns, items, true,
                             NCURSES and {'--width', gui.size[1] - 2} or '--')
  return i and _BUFFERS[i+1] or nil
end


-- -------------------------------------------------------------------
-- Emacs Interactive Implementation

-- Special Arguments Types for I.wrap. Each is a list where the first
-- element is simply a unique reference to the namespace table. I
-- needed a way to guarantee that these special arguments would never
-- clash with a valid argument the user might want to pass to the
-- wrapped function so these seemed like a simple solution. Plus,
-- using a table let me create a metatable with __call so the user
-- could pass additional parameters to these constants.  For example,
-- when using the I.PROMPT, I wanted a simple way to allow the user to
-- choose the prompt to be displayed.

-- I.BUFFER is replaced with a buffer reference selected by the
-- user. The buffer is selected via a pop up dialog box.
I.BUFFER = { I, function() I.select_buffer(I._BUFFER_PROMPT) end }
setmetatable(I.BUFFER, { __call = function(t, p)
  I._BUFFER_PROMPT = p
  return I.BUFFER
end })

-- I.BUFFERN is replaced with the index of the buffer selected by the
-- user. The buffer is selected via a pop up dialog box.
I.BUFFERN = { I, function() 
  local b = I.select_buffer(I._BUFFER_PROMPT)
  return b and _BUFFERS[b] or nil
end }
setmetatable(I.BUFFERN, { __call = function(t, p)
  I._BUFFER_PROMPT = p
  return I.BUFFERN
end })

-- I._BUFFER_PROMPT is used to store the prompt that the user wants
-- displayed in the dialog box. This is private and should not be
-- used. It is set when the user calls I.BUFFER('some prompt').
I._BUFFER_PROMPT = 'Select Buffer:'

-- I.NUMBER is replaced with the number specified using tha numeric
-- prefix key chaining trick. This allows a user to specify a number
-- using only key chaining.
I.NUMBER = { I, function()
  local n = tonumber(I._NUMBER)
  I._NUMBER = ''
  return n and n or 1
end }

-- I._NUMBER is used to store this numebr as we assemble during the
-- key chaining sequence. It is private and should not be used.
I._NUMBER = ''

-- I.PROMPT is replaced with a string that was specified by the user
-- in a pop up input box. I.PROMPT can be called with an optional
-- argument that specifies the label in the input box.
I.PROMPT = { I, function() return I.input_box(I._PROMPT) end }
setmetatable(I.PROMPT, { __call = function(t, p)
  I._PROMPT = p
  return I.PROMPT
end })

-- I._PROMPT is used to store the prompt that the user wants displayed
-- in the dialog box. This is private and should not be used.
I._PROMPT = 'Input:'

-- Invokes a function and its arguments but replaces any of the
-- special arguments defined above with values that were interactively
-- collected. This allows one to bind non-interactive functions to key
-- bindings.
function I.wrap(f, ...)
  local args = table.pack(...)
  for i=1, args.n do
    local arg = args[i]
    -- We check to see if any of the arguments is one of our specially
    -- defined argments by checking if its a table and the first entry
    -- in the table is the unique reference to the namespace. This
    -- guarantees that a user can pass any argument without worrying
    -- that we may inadvertantly treat it as one of our special args.
    if type(arg) == 'table' and arg[1] == I then
      args[i] = arg[2]()  -- Invoke the fn in our special arg definition
      if args[i] == nil then
        -- If the interactive function returns nothing, i.e. the user
        -- cancels a dialog box, then we return false so other lower
        -- priority bindings can have a crack at it.
        return false 
      end 
    end
  end
  f(table.unpack(args))  -- Execute the wrapped function 
  return true
end

-- -------------------------------------------------------------------
-- Helper functions to make it easy to use I.wrap.

-- Simple helper function to wrap a function so it returns a new
-- function that specifies as its first arugment how many times to
-- invoke the original function. Any number of other arguments can be
-- passed to the original function. For example:
--
--   local fn = ntimes(buffer.line_up)
--   fn(3, buffer)    --> invokes buffer.line_up(buffer) three times
--   fn(10, buffer)   --> invokes buffer.line_up(buffer) ten times
function I.ntimes(f)
  return function(n,...)
    for i=1, n do f(...) end
  end
end

-- Simple helper function to wrap a function so it returns a new
-- function that specifies as its first argument the buffer upon which
-- to switch to before invoking the original function. Any number of
-- other arguments can be passed to the original function. For
-- example:
--
--   local fn = with_buffer(buffer.close)
--   fn(buffer)   --> invokes buffer.close on buffer which might
--                    not be the active buffer
function I.with_buffer(f)
  return function(b,...)
    local orig = buffer
    view:goto_buffer(b)
    f(...)
    view:goto_buffer(_BUFFERS[orig])
  end
end

-- -------------------------------------------------------------------
-- Dynamic Key Chaining for Numeric Prefixes

-- The user should ONLY bind I.numeric_prefix to a key binding. The
-- internal _append flag is used to ensure that I._NUMBER is reset to
-- the empty string. This guarantees that everytime the user presses
-- the sequence to start collecting digits that we start fresh. If we
-- did not do this, we have no easy way to reset the collected digits
-- and each subsequent invocation of the key sequence would simply
-- keep appending.
I.numeric_prefix = { _append = false }

-- This is a similar table that will append digits to the I._NUMBER
-- variable that collects the digits entered thus far. Once we've
-- started entering digits, we need to be sure that we append them to
-- the I._NUMBER string so we have a record of what was pressed.
I.numeric_prefix_append = { _append = true }

-- This is the metatable used for both of the tables above.
I.numeric_prefix_mt = {}
setmetatable(I.numeric_prefix, I.numeric_prefix_mt)
setmetatable(I.numeric_prefix_append, I.numeric_prefix_mt)
I.numeric_prefix_mt.__index = function(t, k)
  if not t._append then I._NUMBER = '' end
  if tonumber(k) then
    I._NUMBER = I._NUMBER .. k
    -- Return the other table so we append digits now
    return I.numeric_prefix_append
  else
    -- After they stop entering digits, look up key sequence in
    -- regular key bindings.
    return keys[k]
  end
end


return I
