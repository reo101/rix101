{ lib, config, self, inputs, ... }:

{
  key = "rix101.modules.flake.templates";

  imports = [
    ../lib
    ../things
  ];

  options = let
    inherit (lib)
      types
      ;
    inherit (config.lib.custom)
      createThings
      ;

    createTemplates = baseDir:
      createThings {
        inherit baseDir;
        thingType = "path";
        raw = false;
        filter = name: type:
          type == "directory"
          && builtins.pathExists "${baseDir}/${name}/flake.nix";
        isThing = { type, thingDir, ... }:
          type == "directory"
          && builtins.pathExists "${thingDir}/flake.nix";
        mkThing = { thingDir, ... }: thingDir;
        extras = {
          description.default = null;
          welcomeText.default = null;
        };
        handle = name: template:
          lib.filterAttrs (_: value: value != null) {
            inherit (template) path;
            description =
              if template.description != null
              then template.description
              else name;
            inherit (template) welcomeText;
          };
      };
  in {
    auto.templates = lib.mkOption {
      description = ''
        Automagically generate flake templates from directories containing `flake.nix`
      '';
      type = types.submodule {
        options = {
          enable = lib.mkEnableOption "Automatic templates extraction";
          dir = lib.mkOption {
            description = ''
              Base directory of the contained templates
            '';
            type = types.path;
            default = "${self}/templates";
            defaultText = ''''${self}/templates'';
          };
          result = lib.mkOption {
            description = ''
              The resulting automatic templates
            '';
            type = types.attrsOf types.unspecified;
            readOnly = true;
            internal = true;
            default =
              lib.optionalAttrs
                config.auto.templates.enable
                (createTemplates config.auto.templates.dir);
          };
        };
      };
      default = {};
    };
  };

  config.flake.templates = config.auto.templates.result;
}
