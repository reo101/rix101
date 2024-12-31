{
  system = "aarch64-linux";
  uid = 10626;
  gid = 10626;
  deploy = {
    hostname = "cheetah.lan";
    sshUser = "nix-on-droid";
    user = "nix-on-droid";
    magicRollback = true;
    sshOpts = [ "-p" " 8022" ];
  };
}
