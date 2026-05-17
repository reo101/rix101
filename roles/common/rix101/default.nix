{
  description = "Common rix101 modules for Nix, shell, and source-control tooling";

  nixos.modules = [
    "default-editor"
    "nix-general"
  ];

  nix-darwin.modules = [
    "nix-general"
  ];

  nix-on-droid.modules = [
    "nix-general"
  ];

  home-manager.modules = [
    "nix-general"
    "rix101-shell"
    "rix101-scm"
    "rix101-firefox"
  ];
}
