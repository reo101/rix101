{
  description = "Common rix101 Home Manager modules for shell and source-control tooling";

  nixos.modules = [
    "default-editor"
  ];

  home-manager.modules = [
    "rix101-shell"
    "rix101-scm"
  ];
}
