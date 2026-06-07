{
  nixos = [
    "default-editor"
    "nix-general"
  ];

  nix-darwin = [
    "nix-general"
  ];

  nix-on-droid = [
    "nix-general"
  ];

  home-manager = [
    # TODO: have it leave the user `nix.conf` be extensible runtime (`cachix`, etc.)
    # "nix-general"
    "rix101-shell"
    "rix101-scm"
  ];
}
