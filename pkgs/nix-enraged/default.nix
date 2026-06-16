{ inputs }:
{
  pkgs,
  lib,
  runCommand,
  makeWrapper,
  writeShellApplication,
  capnproto,
  bash,

  targetSystem ? pkgs.stdenv.hostPlatform.system,
  nix' ? pkgs.nixVersions.nix_2_34,
  # , nix' ? inputs.nix.packages.${targetSystem}.nix
  nix-monitored' ? inputs.nix-monitored.packages.${targetSystem}.default.override {
    nix = nix';
    nix-output-monitor = pkgs.nix-output-monitor;
  },
  monitored ? false,
  script ? "sh",
  nix-plugins' ? pkgs.nix-plugins.overrideAttrs (
    oldAttrs:
    let
      isLix = (nix'.pname or null) == "lix";

      nixComponentPnames = [
        "nix"
        "nix-cmd"
        "nix-expr"
        "nix-fetchers"
        "nix-flake"
        "nix-main"
        "nix-store"
        "nix-util"
      ];
    in
    {
      buildInputs = lib.pipe (oldAttrs.buildInputs or [ ]) [
        (lib.filter (drv: !(lib.elem (drv.pname or null) nixComponentPnames)))
        (buildInputs: [ nix' ] ++ lib.optionals isLix [ capnproto ] ++ buildInputs)
      ];
      patches = (oldAttrs.patches or [ ]) ++ [
        (
          if isLix then
            ./nix-plugins-lix.patch
          else
            # NOTE: based on patch from <https://github.com/shlevy/nix-plugins/pull/25>
            ./nix-plugins-nix-2.34.patch
        )
      ];
    }
  ),
  coreutils,
  nushell ? pkgs.nushell,
  rage,
  util-linux,
  ...
}:

let
  isLix = (nix'.pname or null) == "lix";
  script' =
    if lib.elem script [
      "sh"
      "nu"
    ] then
      script
    else
      throw "nix-enraged: script must be one of: sh, nu";

  # Create a wrapped version of the decrypt script with all required runtime dependencies
  rage-decrypt-and-cache =
    if script' == "nu" then
      writeShellApplication {
        name = "rage-decrypt-and-cache";
        runtimeInputs = [
          bash
          coreutils
          nushell
          rage
          util-linux
        ];
        text = ''
          exec nu -n ${./rage-import-encrypted/rage-decrypt-and-cache.nu} "$@"
        '';
      }
    else
      writeShellApplication {
        name = "rage-decrypt-and-cache";
        runtimeInputs = [
          bash
          coreutils
          rage
          util-linux
        ];
        text = builtins.readFile ./rage-import-encrypted/rage-decrypt-and-cache.sh;
      };

  # Create a modified version of the `extra-builtins` file that uses the wrapped script
  extra-builtins = runCommand "extra-builtins.nix" { } ''
    substitute ${./rage-import-encrypted/default.nix} $out \
      --replace-fail "./rage-decrypt-and-cache.sh" ${lib.getExe rage-decrypt-and-cache}
  '';

  # Helper function to convert attrset to Nix config string
  makeNixConfig =
    cfg:
    lib.pipe cfg [
      (lib.mapAttrsToList (k: v: "${k} = ${toString v}"))
      (lib.concatStringsSep "\n")
    ];

  # Default Nix configuration
  defaultNixConfig = makeNixConfig {
    "extra-experimental-features" = lib.concatStringsSep " " (
      [
        "nix-command"
        "flakes"
      ]
      ++ lib.optionals (!isLix) [
        "pipe-operators"
      ]
    );
    "plugin-files" = "${nix-plugins'}/lib/nix/plugins";
    "extra-builtins-file" = "${extra-builtins}";
  };
  suffix = if monitored then "-monitored" else "";
  drv =
    runCommand "nix-enraged${suffix}"
      {
        buildInputs = [ makeWrapper ];
      }
      ''
        mkdir $out
        cp -r ${if monitored then nix-monitored' else nix'}/* $out/
        chmod +w $out/bin
        # chmod +w $out/bin/nix${suffix}

        wrapProgram $out/bin/nix${suffix} \
          --suffix NIX_CONFIG $'\n' ${lib.escapeShellArg defaultNixConfig}
      '';
in
builtins.addErrorContext
  "while evaluating nix-enraged (nix' = ${nix'.name or "???"}, pname = ${nix'.pname or "???"})"
  (
    drv
    // {
      # name = "nix-enraged";
      out = drv.out // {
        inherit (nix') pname version;
        passthru = drv.out.passthru // {
          inherit (nix') pname version;
        };
      };
      passthru = {
        nix = nix';
        nixPlugins = nix-plugins';
        extraBuiltins = extra-builtins;
        rageDecryptAndCache = rage-decrypt-and-cache;
        script = script';

        inherit
          defaultNixConfig
          extra-builtins
          nix'
          nix-plugins'
          rage-decrypt-and-cache
          ;
      };
      inherit (nix') dev;
      inherit (nix') pname version;
    }
  )
