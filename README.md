# Textadept Emacs Compatibility Module

[TextAdept][1] is an extensible cross-platform text editor for
programmers.  It has been written in C and [Lua][2] and is fully
extensible.  This module currently addes a handful of Emacs features
to TextAdept including the basic key bindings as well as interactive
function support.  More features will be added over time.

## Installation

In your `$HOME/.textadept/modules` directory, clone the repository:
```
$ git clone http://github.com/pkazmier/textadept-emacs.git emacs
```

Then in your `$HOME/.textadept/init.lua` file, add the following lines:
```lua
-- Load emacs compatibility mode
_M.emacs = require 'emacs'

-- Activate the emacs keybindings if desired
_M.emacs.keys.enable()
```

[1]: http://foicica.com/textadept/
[2]: http://lua.org/