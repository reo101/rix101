# Shell for bootstrapping flake-enabled nix and other tooling
{ pkgs ?
  # If pkgs is not defined, instanciate nixpkgs from locked commit
  (import ./nixpkgs.nix) { }
, ...
}: {
  default = pkgs.mkShell {
    NIX_CONFIG = ''
      extra-experimental-features = nix-command flakes repl-flake
    '';
    nativeBuildInputs = with pkgs; [
      nix
      home-manager
      git
    ];
  };
}
