{ lib, ... }:

let
  inherit (lib) mapAttrs;
  inherit (lib.attrsets) filterAttrs;
in
rec {
  recurseDir = dir:
    mapAttrs
      (file: type:
        if type == "directory"
        then recurseDir "${dir}/${file}"
        else type
      )
      (builtins.readDir dir);

  # VVV - Implying `attrs` is the output of `recurseDir` - VVV

  hasFiles = files: attrs:
    builtins.all
      (b: b)
      (builtins.map
        (file:
          builtins.hasAttr file attrs &&
          builtins.getAttr file attrs == "regular")
        files);

  hasDirectories = directories: attrs:
    builtins.all
      (b: b)
      (builtins.map
        (directory:
          builtins.hasAttr directory attrs &&
          builtins.getAttr directory attrs == "set")
        directories);
}
