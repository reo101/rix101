{ luajit, lib }:

lib.fix (
  patchedLuajit:
  (luajit.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or [ ]) ++ [
      ./coroutine_clone.patch
    ];
  })).override
    {
      self = patchedLuajit;
    }
)
