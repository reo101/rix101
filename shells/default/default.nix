# Shell for bootstrapping flake-enabled nix and other tooling
{ pkgs
, inputs
, ...
}: pkgs.mkShellNoCC {
  NIX_CONFIG = ''
    extra-experimental-features = nix-command flakes
  '';
  nativeBuildInputs = with pkgs; [
    nixVersions.monitored.latest
    home-manager
    git
    wireguard-tools
    deploy-rs
    # inputs.agenix.packages.${pkgs.system}.agenix
    # inputs.ragenix.packages.${pkgs.system}.ragenix
    rage
    inputs.agenix-rekey.packages.${pkgs.system}.agenix-rekey
  ];
}
