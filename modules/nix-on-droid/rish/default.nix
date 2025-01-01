{ lib, pkgs, config, ... }:

let
  cfg = config.rish;

  dex = pkgs.stdenv.mkDerivation {
    name = "rish-shizuku.dex";

    src = pkgs.fetchurl {
      url = "https://github.com/RikkaApps/Shizuku/releases/download/v13.5.4/shizuku-v13.5.4.r1049.0e53409-release.apk";
      hash = "sha256-oFgyzjcWr7H8zPRvNIAG0qKWynd+H/PSI3l9x00Gsx8=";
    };

    unpackPhase = ''
      ${lib.getExe pkgs.unzip} -j $src "assets/rish_shizuku.dex"
    '';

    installPhase = ''
      cp rish_shizuku.dex $out
      chmod 400 $out
    '';

    passthru.updateScript = pkgs.callPackage ./update-script.nix { };
  };
  rish = pkgs.writeShellScriptBin "rish" ''
    #!/bin/sh
    DEX="${dex.outPath}"

    # Clear `LD_PRELOAD` (could have `/nix/store` paths)
    export LD_PRELOAD=

    if [ ! -f "$DEX" ]; then
      echo "Cannot find $DEX, please check the tutorial in Shizuku app"
      exit 1
    fi

    # NOTE: already done in `dex` derivarion
    # if [ $(/system/bin/getprop ro.build.version.sdk) -ge 34 ]; then
    #   if [ -w $DEX ]; then
    #     echo "On Android 14+, app_process cannot load writable dex."
    #     echo "Attempting to remove the write permission..."
    #     chmod 400 $DEX
    #   fi
    #   if [ -w $DEX ]; then
    #     echo "Cannot remove the write permission of $DEX."
    #     echo "You can copy to file to terminal app's private directory (/data/data/<package>, so that remove write permission is possible"
    #     exit 1
    #   fi
    # fi

    export RISH_APPLICATION_ID="${cfg.applicationId}"

    # Restrict `PATH` to root-only binaries
    export PATH="/bin:/system/bin"

    # TODO: mimic `tsu` more (custom `$HOME`, maybe running `login`)

    /system/bin/app_process \
      -Djava.class.path="$DEX" \
      /system/bin \
      --nice-name=rish \
      rikka.shizuku.shell.ShizukuShellLoader \
      "$@"
  '';

  su = pkgs.writeShellScriptBin "su" ''
    ${lib.getExe rish}
  '';
  sudo = pkgs.writeShellScriptBin "sudo" ''
    ${lib.getExe rish} -c "''${*}"
  '';
in
{
  options.rish = {
    enable = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to enable `su`/`sudo` wrappers of Shizuku's `rish`";
      default = true;
    };

    applicationId = lib.mkOption {
      type = lib.types.str;
      description = "Android ID of the target application";
      default = "com.termux.nix";
    };
  };

  config = lib.mkIf config.rish.enable {
    environment.packages = [
      su
      sudo
    ];
  };
}
