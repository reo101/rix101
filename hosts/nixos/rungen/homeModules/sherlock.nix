{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (import "${dirs.machines}/desktop/pavel-atanasov-001/flakes.nix")
    rix101
    sherlock
    neovim-nightly-overlay
    ;
in
{
  imports = [
    sherlock.homeManagerModules.default
    rix101.homeManagerModules.reo101-sherlock
  ];
}
