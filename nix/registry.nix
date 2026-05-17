{
  lib,
  inputs,
  prefix ? "rix101",
}:

let
  inherit (lib) nameValuePair;

  pathRefFor =
    flake:
    {
      type = "path";
      path = flake.outPath;
    }
    // lib.filterAttrs (
      name: _value:
      builtins.elem name [
        "lastModified"
        "narHash"
        "rev"
        "revCount"
      ]
    ) flake;

  flakeInputs = lib.filterAttrs (
    name: input: name != "self" && (input._type or null) == "flake" && input ? outPath
  ) inputs;
in
builtins.listToAttrs (
  [
    (nameValuePair prefix {
      from = {
        type = "indirect";
        id = prefix;
      };
      to = pathRefFor inputs.self;
    })
  ]
  ++ lib.mapAttrsToList (
    name: input:
    nameValuePair "${prefix}/${name}" {
      from = {
        type = "indirect";
        id = prefix;
        ref = name;
      };
      to = pathRefFor input;
    }
  ) flakeInputs
)
