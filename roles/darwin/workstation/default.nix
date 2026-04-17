{
  description = "Shared nix-darwin modules for the author's workstation setup";

  nix-darwin.modules = [
    "system"
    "brew"
    "yabai"
  ];
}
