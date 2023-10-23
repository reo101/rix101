# Shell for bootstrapping flake-enabled nix and other tooling
{ pkgs
, inputs
, outputs
, ...
}: pkgs.mkShell {
  NIX_CONFIG = ''
    extra-experimental-features = nix-command flakes repl-flake
  '';
  nativeBuildInputs = with pkgs; [
    nix
    home-manager
    git
    deploy-rs
    # inputs.agenix.packages.${pkgs.system}.agenix
    inputs.ragenix.packages.${pkgs.system}.ragenix
    wireguard-tools
    rage
  ];
}
