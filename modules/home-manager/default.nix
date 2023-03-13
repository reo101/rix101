# Add your reusable home-manager modules to this directory, on their own file (https://nixos.wiki/wiki/Module).
# These should be stuff you would like to share with others, not your personal configurations.

{
  # List your module files here
  # my-module = import ./my-module.nix;
  reo101-shell = import ./reo101-shell.nix;
  reo101-river = import ./reo101-river;
  reo101-wezterm = import ./reo101-wezterm;
}
