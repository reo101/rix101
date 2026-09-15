{ inputs', ... }:
{
  imports = [
    inputs'.self.packages.septabee.nixosModule
  ];

  programs.septabee.enable = true;
}
