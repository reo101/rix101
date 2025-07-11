{ inputs }:
{ pkgs
, lib
, runCommand
, makeWrapper
, writeShellApplication

# NOTE: normally only works with vanilla `2.24` nix
#       using a patched `nix-plugins` here
, nix' ? pkgs.nixVersions.nix_2_29
, nix-monitored' ? inputs.nix-monitored.packages.${pkgs.hostPlatform.system}.default.override {
    nix = nix';
    nix-output-monitor = pkgs.nix-output-monitor;
  }
, monitored ? false
, nix-plugins' ? pkgs.nix-plugins.overrideAttrs (oldAttrs: {
    # Only override `nix`
    buildInputs = lib.pipe (oldAttrs.buildInputs or []) [
      (lib.filter (drv: drv.pname != "nix"))
      (buildInputs: [ nix' ] ++ buildInputs)
    ];

    patches = (oldAttrs.patches or []) ++ [
      ./fix.patch
    ];
  })
, coreutils
, rage
, ...
}:

let
  # Create a wrapped version of the decrypt script with all required runtime dependencies
  # TODO: rewrite the script in another language
  rage-decrypt-and-cache = writeShellApplication {
    name = "rage-decrypt-and-cache";
    runtimeInputs = [ coreutils rage ];
    text = builtins.readFile ./rage-import-encrypted/rage-decrypt-and-cache.sh;
  };

  # Create a modified version of the `extra-builtins` file that uses the wrapped script
  extra-builtins = runCommand "extra-builtins.nix" {} ''
    substitute ${./rage-import-encrypted/default.nix} $out \
      --replace "./rage-decrypt-and-cache.sh" ${lib.getExe rage-decrypt-and-cache}
  '';

  # Helper function to convert attrset to Nix config string
  makeNixConfig = cfg: lib.pipe cfg [
    (lib.mapAttrsToList (k: v: "${k} = ${toString v}"))
    (lib.concatStringsSep "\n")
  ];

  # Default Nix configuration
  defaultNixConfig = makeNixConfig {
    "extra-experimental-features" = lib.concatStringsSep " " [
      "nix-command"
      "flakes"
      "pipe-operators"
    ];
    "plugin-files" = "${nix-plugins'}/lib/nix/plugins";
    "extra-builtins-file" = "${extra-builtins}";
  };
  suffix = if monitored then "-monitored" else "";
  drv = runCommand "nix-enraged${suffix}" {
    buildInputs = [ makeWrapper ];
  } ''
    mkdir $out
    cp -r ${if monitored then nix-monitored' else nix'}/* $out/
    chmod +w $out/bin
    # chmod +w $out/bin/nix${suffix}

    wrapProgram $out/bin/nix${suffix} \
      --prefix NIX_CONFIG $'\n' ${lib.escapeShellArg defaultNixConfig}
  '';
in drv // {
  out = drv.out // {
    inherit (nix') version;
    passthru =  drv.out.passthru // {
      inherit (nix') version;
    };
  };
  passthru = {
    inherit nix';
  };
  inherit (nix') dev;
  inherit (nix') version;
}
