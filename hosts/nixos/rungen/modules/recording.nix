{
  pkgs,
  ...
}:
{
  programs.gpu-screen-recorder.enable = true;

  environment.systemPackages = [
    pkgs.gpu-screen-recorder-gtk
  ];
}
