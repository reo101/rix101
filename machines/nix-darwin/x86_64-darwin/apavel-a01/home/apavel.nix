{ inputs, outputs, lib, pkgs, config, ... }:

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
    inputs.zls-overlay.packages.x86_64-darwin.default
  ];

  programs.git = {
    enable = true;
    userName = "apavel";
    userEmail = "apavel@vmware.com";
    signing = {
      signByDefault = true;
      key = "0x52F3E1D376F692C0";
    };
  };

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
