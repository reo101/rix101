{ lib, config, self, inputs, ... }:

{
  config.lib = let
    inherit (config.lib)
      and
      eq
      hasFiles
      ;
  in rec {
    # Try to passthru `inputs` by default
    defaultThingHandle = { raw, thingType }: name: result: let
      thing =
        if raw
        then result
        else result.${thingType};
      passthru = {
        inherit inputs;
      };
      handledThing =
        if and [
          (builtins.isFunction
            thing)
          # FIXME: check for subset, not `eq`
          (eq
            (lib.pipe thing [ builtins.functionArgs builtins.attrNames ])
            (lib.pipe passthru [ builtins.attrNames ]))
        ]
        # { inputs, ... }: { foo, ... }: bar
        then thing passthru
        # { foo, ... }: bar
        else thing;
      handledResult =
        if raw
        then handledThing
        else result // { ${thingType} = handledThing; };
    in handledResult;

    # TODO: make `passthru` more generic (maybe take `thing` as arg and decide itself what to do?)
    createThings =
      { baseDir
      , thingType ? "thing"
      , filter ? (name: type: true)
      , handle ? (defaultThingHandle { inherit raw thingType; })
      , raw ? true
      , extras ? {}
      , ...
      }:
      assert raw -> extras == {};
      lib.pipe baseDir [
        # Read given directory
        builtins.readDir
        # Filter out unwanted things
        (lib.filterAttrs
          filter)
        # Map each entry to a thing
        (lib.mapAttrs'
          (name: type:
            let
              # BUG: cannot use `append` because of `${self}` (not a path)
              # thingDir = lib.path.append baseDir "${name}";
              thingDir = "${baseDir}/${name}";
              importedExtras = lib.pipe extras [
                (lib.mapAttrs (name: { default, ... }:
                  assert name != "default";
                  assert name != thingType;
                  let
                    extraPath = "${thingDir}/${name}.nix";
                  in
                    if builtins.pathExists extraPath
                    then import extraPath
                    else default))
              ];
              thing = import thingDir;
              result =
                if raw
                then thing
                else lib.attrsets.unionOfDisjoint
                       { ${thingType} = thing; }
                       importedExtras;
            in
            if and [
              (type == "directory")
              (hasFiles [ "default.nix" ] (builtins.readDir thingDir))
            ] then
              # Classic thing in a directory
              lib.nameValuePair
                name
                result
            else if and [
              (type == "regular")
              (lib.hasSuffix ".nix" name)
            ] then
              # Classic thing in a file
              lib.nameValuePair
                (lib.removeSuffix ".nix" name)
                result
            else
              # Invalid thing
              lib.nameValuePair
                name
                null))
        # Filter invalid things
        (lib.filterAttrs
          (thingName: thing:
            thing != null))
        # Handle if needed
        (lib.mapAttrs handle)
      ];
  };
}
