{ inputs, ... }:
{ lib, pkgs, config, ... }:

{
  imports = [ ];

  options = { };

  config = {
    home.activation = lib.mkIf pkgs.stdenv.isDarwin {
      trampolineApps =
        let
          mac-app-util = inputs.mac-app-util.packages.${pkgs.stdenv.system}.default;
        in
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          fromDir="$HOME/Applications/Home Manager Apps"
          toDir="$HOME/Applications/Home Manager Trampolines"
          ${mac-app-util}/bin/mac-app-util sync-trampolines "$fromDir" "$toDir"
        '';
    };
  };
}
