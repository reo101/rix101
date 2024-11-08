{
  system = "aarch64-linux";
  uid = 10459;
  gid = 10459;
  deploy = {
    hostname = "cheetah.lan";
    sshUser = "nix-on-droid";
    user = "nix-on-droid";
    magicRollback = true;
    sshOpts = [ "-p" " 8022" ];
  };
}
