# Shell for bootstrapping flake-enabled nix and other tooling
{ config # flake-parts `perSystem` config
, inputs
, pkgs
, ...
}: pkgs.mkShellNoCC {
  nativeBuildInputs = with pkgs; [
    # lix-monitored
    nix-enraged
    home-manager
    git
    wireguard-tools
    deploy-rs
    # inputs.agenix.packages.${pkgs.hostPlatform.system}.agenix
    # inputs.ragenix.packages.${pkgs.hostPlatform.system}.ragenix
    rage
    config.agenix-rekey.package
    age-plugin-yubikey
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    # "${inputs.nix-darwin.outPath}/pkgs/nix-tools/default.nix" |> import |> (p: pkgs.callPackage p {}) |> builtins.getAttr "darwin-rebuild"
    (lib.pipe inputs.nix-darwin.outPath [
      (f: "${f}/pkgs/nix-tools/default.nix")
      import
      (p: pkgs.callPackage p {
        nixPackage = (nix-enraged.override { monitored = false; });
      })
      (builtins.getAttr "darwin-rebuild")
    ])
  ];

  env = {
    # NOTE: Always add affected files to git after agenix operations
    AGENIX_REKEY_ADD_TO_GIT = "always";
  } // lib.optionalAttrs (let platform = pkgs.hostPlatform; in platform.isLinux && platform.isAarch64) {
    # TODO: refer through `inputs`
    AGENIX_REKEY_PRIMARY_IDENTITY = "age1m23jgdtkfh6gqnxge88q03yy9exckajmlmx8sw2z9t3t5gpr0c4qxgdtwr";
    AGENIX_REKEY_PRIMARY_IDENTITY_ONLY = true;
  };
}
