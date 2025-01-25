{ lib, lua51Packages }:

lua51Packages.lua.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [
    # Credits to <http://lua-users.org/lists/lua-l/2006-01/msg00652.html>
    ./coroutine_clone.patch
  ];
})
