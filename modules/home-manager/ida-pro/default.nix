{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

let
in
{
  imports = [
    inputs.ida-pro.modules.homeManager.default
    (lib.rageImportEncryptedOrDefault ./ida-pro-infusion.nix.age { })
  ];

  programs.ida-pro = {
    enable = (lib.tryEval config.programs.ida-pro.package).success;
    plugins = lib.getAttr "allPlugins";
    settings = {
      AutoUseLumina = 1;
      Lumina.Primary = "guest@ida.int.mov:1234";
    };
  };

  home.file.".idapro/hexrays-ida-int-mov.crt".source =
    pkgs.runCommand "hexrays.ida-int.mov.crt"
      {
        buildInputs = [ pkgs.openssl ];
        outputHash = "sha256-ij28uSqxxid2R/4quFNrXJgqu/2x8d9XKOAbkGq6lTo=";
      }
      ''
        openssl s_client \
          -showcerts \
          -connect 'ida.int.mov:1234' \
        0< /dev/null \
        2> /dev/null \
        | awk -F':' '/ s:/{s=$2}/ i:/{p=s==$2}p&&/BEGIN/,/END/' \
        1> "$out"
      '';
}
