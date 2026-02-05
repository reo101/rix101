{
  pkgs,
  ...
}:
{
  nix = {
    package = pkgs.nixVersions.latest;

    settings = {
      trusted-users = [
        "root"
          "reo101"
      ];

      experimental-features = [
        "nix-command"
          "flakes"
      ];
    };
  };
}
