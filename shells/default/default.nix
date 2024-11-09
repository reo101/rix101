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
  ];
}
