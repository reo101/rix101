{ lib, luajitPackages }:

luajitPackages.lua.overrideAttrs (oldAttrs: {
  patches = (oldAttrs.patches or [ ]) ++ [
    ./coroutine_clone.patch
  ];
})
