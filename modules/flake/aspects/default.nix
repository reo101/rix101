{
  inputs,
  lib,
  config,
  ...
}:

let
  aspectLibrary = inputs.flake-aspects.lib lib;
in
{
  key = "rix101.modules.flake.aspects";

  imports = [
    (aspectLibrary.new-scope "composition")
    ../../../aspects
  ];

  flake-file.inputs.flake-aspects.url = "github:denful/flake-aspects";

  flake.aspects = config.composition.aspects;
  lib.composition = import ./bindings.nix { inherit lib aspectLibrary; };

  perSystem =
    { pkgs, ... }:
    let
      tests = import ./tests.nix {
        inherit aspectLibrary;
        lib = config.lib;
      };
    in
    {
      checks.aspect-composition =
        assert lib.assertMsg tests.passed
          "Aspect composition checks failed: ${
            lib.concatStringsSep ", " (lib.attrNames (lib.filterAttrs (_: passed: !passed) tests.cases))
          }";
        pkgs.writeText "aspect-composition-results.json" (builtins.toJSON tests.cases);
    };
}
