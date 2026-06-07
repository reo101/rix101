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

  deploy-rs-with-nix-enraged-monitored = pkgs.symlinkJoin {
    name = "deploy-rs-with-nix-enraged";
    paths = [ pkgs.deploy-rs ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/${pkgs.deploy-rs.meta.mainProgram}" \
        --prefix PATH : ${lib.makeBinPath [ nix-enraged-monitored ]}
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
    config.agenix-rekey.package
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
