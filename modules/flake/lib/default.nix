{ lib, config, self, ... }:

{
  imports = [
    ./things.nix
  ];

  options = let
    inherit (lib)
      types
      ;
  in {
    lib = lib.mkOption {
      internal = true;
      type = types.unspecified;
    };
  };

  config.lib = rec {
    # Boolean helpers
    and = lib.all lib.id;
    or = lib.any lib.id;
    eq = x: y: x == y;

    # Directory walking helpers
    recurseDir = dir:
      lib.mapAttrs
        (file: type:
          if type == "directory"
          then recurseDir "${dir}/${file}"
          else type)
        (builtins.readDir dir);

    allSatisfy = predicate: attrs: attrset:
      lib.all
      (attr:
        and [
          (builtins.hasAttr attr attrset)
          (predicate (builtins.getAttr attr attrset))
        ])
      attrs;

    # NOTE: Implying last argument is the output of `recurseDir`
    hasFiles = allSatisfy (eq "regular");

    # NOTE: Implying last argument is the output of `recurseDir`
    hasDirectories = allSatisfy lib.isAttrs;

    camelToKebab =
      lib.stringAsChars
        (c: if c == lib.toUpper c then "-${lib.toLower c}" else c);

    # NOTE: adapted from Tweag's Nix Hour 76 - <https://github.com/tweag/nix-hour/blob/c4fd0f2fc3059f057571bbfd74f3c5e4021f526c/code/76/default.nix#L4-L22>
    mutFirstChar =
      f: s:
      let
        firstChar = f (lib.substring 0 1 s);
        rest = lib.substring 1 (-1) s;
      in firstChar + rest;

    kebabToCamel = lib.flip lib.pipe [
      (lib.splitString "-")
      (lib.concatMapStrings
        (mutFirstChar lib.toUpper))
      (mutFirstChar lib.toLower)
    ];
    # s:
    # mutFirstChar
    #   lib.toLower
    #     (lib.concatMapStrings
    #       (mutFirstChar lib.toUpper)
    #       (lib.splitString "-" s));
  };
}
