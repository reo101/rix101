{ inputs, lib, config, self, ... }:

{
  imports = [
    ../lib
  ];

  config.lib-overlays =  [
    inputs.nix-lib-net.overlays.raw
    # Yants
    (final: prev: {
      yants = import "${inputs.yants.outPath}/default.nix" { lib = prev; };
    })
    # Infuse
    (final: prev: let
      infuse = (import "${inputs.infuse.outPath}/default.nix" {
        lib = prev;
        sugars = infuse.v1.default-sugars ++ lib.attrsToList {
          __concatStringsSep =
            path: infusion: target:
              lib.strings.concatStringsSep infusion target;
          __filter =
            path: infusion: target:
              builtins.filter infusion target;
          __map =
            path: infusion: target:
              builtins.map infusion target;
          __swapOutPackage =
            path: infusion: target: let
              # TODO: more validation
              infusion-name = infusion.pname or infusion.name or "";
            in builtins.map
              (pkg: let
                pkg-name = pkg.pname or pkg.name or "";
                nonempty = pkg-name != "";
              in if nonempty && pkg-name == infusion-name
                 then infusion
                 else pkg)
              target;
        };
      });
    in {
      inherit (infuse.v1) infuse;
    })
    # Alloc
    (final: prev: {
      alloc = import "${inputs.alloc.outPath}/default.nix" { lib = prev; };
    })
  ];

  config.lib = rec {
    # Secrets Helpers
    repoSecret = lib.path.append ../../../secrets/master;

    # Boolean helpers
    and = lib.all lib.id;
    eq = x: y: x == y;

    # Directory walking helpers
    recurseDir = dir: lib.pipe dir [
      builtins.readDir
      (lib.mapAttrs
        (file: type:
          let
            # Causes individual files to be sent to the store
            # newPath = lib.path.append dir file;
            newPath = "${dir}/${file}";
          in
          if and [
            (type == "directory")
          ] then
            {
              _type = "directory";
              content = recurseDir newPath;
            }
          else if and [
            (type == "regular")
            (lib.strings.hasSuffix ".nix" file)
          ] then
            {
              _type = "nix";
              content = import newPath;
            }
          else
            {
              _type = type;
              content = newPath;
            }))
    ];

    allSatisfy = predicate: attrs: attrset:
      lib.all
        (attr:
          and [
            (builtins.hasAttr attr attrset)
            (predicate (builtins.getAttr attr attrset))
          ])
        attrs;

    # NOTE: Implying last argument is the output of `recurseDir`
    hasNixFiles = allSatisfy (file: file._type == "nix");

    # NOTE: Implying last argument is the output of `recurseDir`
    hasDirectories = allSatisfy (file: file._type == "directory");

    # NOTE: Implying `files` is the output of `recurseDir`
    extract = {
      files,
      path,
      pred,
      default ? null,
      transform ? file: { inherit (file) content; },
    }:
      lib.pipe files [
        (lib.attrByPath
          (lib.intersperse "content"
            # NOTE: turn single strings into a path list
            (lib.toList path))
          # ~FIXME~: `null` may be be `content` of a real Nix file
          null)
        # Now is either a { _type = "..."; ... } or a null
        (file: if file == null || !(pred file) then
          default
        else
          transform file)
        # Same, but now always a nix file if not null
      ];
    extractNixFile = files: path: extract {
      inherit files path;
      pred = file: file._type == "nix";
      # transform = file: { inherit (file) content; };
    };
    extractDirectory = files: path: extract {
      inherit files path;
      pred = file: file._type == "directory";
      default = {};
      transform = dir: dir.content;
    };

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
