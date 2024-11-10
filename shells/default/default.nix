# Shell for bootstrapping flake-enabled nix and other tooling
{ inputs
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
    inputs.agenix-rekey.packages.${pkgs.hostPlatform.system}.agenix-rekey
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
}
