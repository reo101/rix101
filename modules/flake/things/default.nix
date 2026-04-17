{
  lib,
  config,
  self,
  inputs,
  ...
}:

{
  key = "rix101.modules.flake.things";

  imports = [
    ../lib
  ];

  config.lib =
    let
      inherit (config.lib.custom)
        and
        eq
        recurseDir
        hasNixFiles
        ;
    in
    rec {
      # Try to passthru `inputs` by default
      defaultThingHandle =
        { raw, thingType }:
        name: result:
        let
          thing = if raw then result else result.${thingType};
          # NOTE: use `config.lib` to get the extended lib with custom functions
          passthru = {
            inherit inputs;
            inherit (config) lib;
          };
          thingArgs = lib.pipe thing [
            builtins.functionArgs
            builtins.attrNames
          ];
          handledThing =
            if
              and [
                (builtins.isFunction thing)
                # Check that all function's required arguments are present in passthru
                (lib.all (arg: builtins.hasAttr arg passthru) thingArgs)
              ]
            # { inputs, ... }: { foo, ... }: bar
            then
              thing (lib.getAttrs thingArgs passthru)
            # { foo, ... }: bar
            else
              thing;
          handledResult = if raw then handledThing else result // { ${thingType} = handledThing; };
        in
        handledResult;

      # TODO: make `passthru` more generic (maybe take `thing` as arg and decide itself what to do?)
      createThings =
        {
          baseDir,
          thingType ? "thing",
          filter ? (name: type: true),
          recursive ? false,
          isThing ? (
            {
              name,
              type,
              thingDir,
            }:
            if type == "directory" then
              hasNixFiles [ "default.nix" ] (recurseDir thingDir)
            else
              type == "regular" && lib.hasSuffix ".nix" name
          ),
          mkThing ? ({ thingDir, ... }: import thingDir),
          handle ? (defaultThingHandle { inherit raw thingType; }),
          raw ? true,
          extras ? { },
        }:
        assert raw -> extras == { };
        let
          mkThingResult =
            {
              relativeName,
              name,
              type,
              thingDir,
            }:
            let
              importedExtras = lib.pipe extras [
                (lib.mapAttrs (
                  name:
                  { default, ... }:
                  assert name != "default";
                  assert name != thingType;
                  let
                    extraPath = "${thingDir}/${name}.nix";
                  in
                  if builtins.pathExists extraPath then import extraPath else default
                ))
              ];
              thing = mkThing { inherit name type thingDir; };
              result =
                if raw then thing else lib.attrsets.unionOfDisjoint { ${thingType} = thing; } importedExtras;
            in
            lib.nameValuePair relativeName result;

          collectThings =
            prefix:
            let
              currentDir = if prefix == "" then baseDir else "${baseDir}/${prefix}";
            in
            lib.pipe currentDir [
              builtins.readDir
              (lib.filterAttrs filter)
              (lib.mapAttrsToList (
                name: type:
                let
                  relativeName = if prefix == "" then name else "${prefix}/${name}";
                  # BUG: cannot use `append` because of `${self}` (not a path)
                  # thingDir = lib.path.append baseDir relativeName;
                  thingDir = "${baseDir}/${relativeName}";
                in
                if
                  and [
                    (type == "directory")
                    (isThing { inherit name type thingDir; })
                  ]
                then
                  [
                    (mkThingResult {
                      inherit name type thingDir;
                      relativeName = relativeName;
                    })
                  ]
                else if
                  and [
                    (type == "regular")
                    (isThing { inherit name type thingDir; })
                  ]
                then
                  [
                    (mkThingResult {
                      inherit name type thingDir;
                      relativeName = lib.removeSuffix ".nix" relativeName;
                    })
                  ]
                else if recursive && type == "directory" then
                  lib.mapAttrsToList lib.nameValuePair (collectThings relativeName)
                else
                  [ ]
              ))
              lib.flatten
              builtins.listToAttrs
            ];
        in
        lib.pipe "" [
          collectThings
          (lib.mapAttrs handle)
        ];
    };
}
