{ inputs, lib, pkgs, config, ... }:

{
  home = {
    # username = "apavel";
    # homeDirectory = "/Users/apavel";
    stateVersion = "22.05";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # Dhall
    dhall
    # dhall-lsp-server

    # Nix
    nil

    # Zig
    zigpkgs.master
    # inputs.zls-overlay.packages.x86_64-darwin.default
  ];

  # services.gpg-agent = {
  #   enable = true;
  #   defaultCacheTtl = 1800;
  #   enableSshSupport = true;
  # };

  # home.file.".stack/config.yaml".text = lib.generators.toYAML {} {
  #   templates = {
  #     scm-init = "git";
  #     params = with config.programs.git; {
  #       author-name = userName;
  #       author-email = userEmail;
  #       github-username = userName;
  #     };
  #   };
  #   nix.enable = true;
  # };
}
