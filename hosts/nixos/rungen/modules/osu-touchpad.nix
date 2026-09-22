{ ... }:

{
  hardware.uinput.enable = true;
  users.users.reo101.extraGroups = [
    "input"
    "uinput"
  ];
}
