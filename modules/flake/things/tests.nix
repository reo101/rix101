{ lib }:

let
  evaluated = lib.evalModules {
    specialArgs = {
      inherit lib;
      inputs.marker = "default-input";
    };
    modules = [
      ./default.nix
      {
        options.flake = lib.mkOption {
          type = lib.types.lazyAttrsOf lib.types.unspecified;
          default = { };
        };
        config.lib = {
          inherit (lib.custom)
            and
            eq
            recurseDir
            hasNixFiles
            kebabToCamel
            ;
          contextMarker = "configured";
        };
      }
    ];
  };
  thingLib = evaluated.config.lib;
  arguments = {
    inputs.marker = "selected";
    inherit lib;
    unused = true;
  };
  rawHandler = thingLib.custom.defaultThingHandle {
    raw = true;
    thingType = "thing";
    inherit arguments;
  };
  wrapped =
    (thingLib.custom.defaultThingHandle {
      raw = false;
      thingType = "thing";
      inherit arguments;
    })
      "sample"
      {
        thing = { inputs }: inputs.marker;
        meta.curried = true;
        systems = _: true;
      };
  raw = rawHandler "sample" ({ inputs }: inputs.marker);
  twoLevel = rawHandler "sample" ({ inputs }: { suffix }: inputs.marker + suffix);
  custom =
    (thingLib.custom.defaultThingHandle {
      raw = true;
      thingType = "thing";
      arguments.selection = "explicit";
    })
      "sample"
      ({ selection }: selection);
  defaults =
    (thingLib.custom.defaultThingHandle {
      raw = true;
      thingType = "thing";
    })
      "sample"
      ({ inputs, lib }: inputs.marker + "/" + lib.contextMarker);
  discovered = thingLib.custom.createThings {
    baseDir = ./tests/identity;
  };
in
{
  explicitThingArgumentsAreMatched = raw == "selected";
  wrappedThingPreservesExtras =
    wrapped.thing == "selected" && wrapped.meta.curried && wrapped.systems { };
  firstLevelApplicationRetainsSecondLevel =
    builtins.isFunction twoLevel && twoLevel { suffix = "-second"; } == "selected-second";
  customThingArgumentsAreSupported = custom == "explicit";
  defaultThingArgumentsUseConfiguredContext = defaults == "default-input/configured";
  discoveryDoesNotApplyFunctions = builtins.isFunction discovered.sample;
}
