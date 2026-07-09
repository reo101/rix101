# Shell for bootstrapping flake-enabled nix and other tooling
{ config # flake-parts `perSystem` config
, inputs
, pkgs
, lib
, ...
}:
let
  nix-enraged-monitored = lib.infuse pkgs.custom.nix-enraged {
    __input.monitored.__assign = true;
  };

  # `nix` stays enraged. `agenix` uses ordinary Nix so encrypted imports
  # take their defaults; `agenix-enraged` explicitly evaluates them.
  agenix-package = config.agenix-rekey.package.overrideAttrs (old: {
    text = lib.replaceStrings
      [ ''PASS_THRU_ARGS+=("$1" "--preview")'' ]
      [ ''PASS_THRU_ARGS+=("$1")'' ]
      old.text;
  });

  agenixWith = name: nix: pkgs.writeShellApplication {
    inherit name;
    runtimeInputs = [ pkgs.coreutils pkgs.git ];
    text = ''
      export PATH=${lib.makeBinPath [ nix ]}:$PATH
      exec ${lib.getExe agenix-package} "$@"
    '';
  };

  agenix = agenixWith "agenix" pkgs.nix;
  agenix-enraged = agenixWith "agenix-enraged" nix-enraged-monitored;

  deploy-rs-with-nix-enraged-monitored = pkgs.writeShellApplication {
    name = pkgs.deploy-rs.meta.mainProgram;
    runtimeInputs = [ nix-enraged-monitored ];
    text = ''
      die() {
        echo "deploy: $*" >&2
        exit 2
      }

      args=("$@")
      target=""
      extra_build_args=()

      for ((i = 0; i < ''${#args[@]}; i++)); do
        arg="''${args[$i]}"
        case "$arg" in
          -h|--help|-V|--version)
            exec ${lib.getExe pkgs.deploy-rs} "$@"
            ;;
          --targets|--targets=*|-f|--file|--file=*)
            die "target-only checks require one flake target, for example '.#jeeves'"
            ;;
          --)
            extra_build_args=("''${args[@]:i + 1}")
            break
            ;;
          --log-dir|-r|--result-path|--ssh-user|--profile-user|--ssh-opts|--fast-connection|--auto-rollback|--hostname|--magic-rollback|--confirm-timeout|--activation-timeout|--temp-path|--rollback-succeeded|--sudo|--interactive-sudo)
            ((i += 1))
            ((i < ''${#args[@]})) || die "$arg requires a value"
            ;;
          --*=*|-*)
            ;;
          *)
            [[ -z "$target" ]] || die "target-only checks support one target"
            target="$arg"
            ;;
        esac
      done

      [[ -n "$target" ]] || die "specify one target, for example '.#jeeves'"
      [[ "$target" == *#* ]] || die "target must select a node, for example '.#jeeves'"

      repo="''${target%%#*}"
      selector="''${target#*#}"
      node="''${selector%%.*}"

      [[ -n "$repo" ]] || repo="."
      [[ "$node" =~ ^[A-Za-z_][A-Za-z0-9_-]*$ ]] \
        || die "cannot derive a simple node name from '$target'"

      check_prefix="$repo#deployChecks.${pkgs.system}.\"$node\""
      ${lib.getExe' nix-enraged-monitored "nix"} build --no-link \
        "$check_prefix.deploy-schema" \
        "$check_prefix.deploy-activate" \
        "''${extra_build_args[@]}"

      exec ${lib.getExe pkgs.deploy-rs} --skip-checks "$@"
    '';
  };
in
pkgs.mkShellNoCC {
  nativeBuildInputs = with pkgs; [
    nix-enraged-monitored
    # (nixd.override { nix = nix-enraged-monitored; })
    home-manager
    git
    wireguard-tools
    deploy-rs-with-nix-enraged-monitored
    # inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.agenix
    # inputs.ragenix.packages.${pkgs.stdenv.hostPlatform.system}.ragenix
    rage
    agenix
    agenix-enraged
    age-plugin-yubikey
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    (inputs.nix-darwin.packages.aarch64-darwin.darwin-rebuild.overrideAttrs (drv: {
      path = lib.makeBinPath [ nix-enraged-monitored ] + ":" + drv.path;
    }))
  ];

  env = {
    # NOTE: Always add affected files to git after agenix operations
    AGENIX_REKEY_ADD_TO_GIT = "always";
  } // lib.optionalAttrs (let platform = pkgs.stdenv.hostPlatform; in platform.isLinux && platform.isAarch64) {
    # TODO: refer through `inputs`
    # TODO: move to `cheetah` config
    AGENIX_REKEY_PRIMARY_IDENTITY = "${inputs.self.outPath}/secrets/identities/03-age-backup.age";
    AGENIX_REKEY_PRIMARY_IDENTITY_ONLY = true;
  };
}
