{
  system = "aarch64-linux";
  roles = [
    "common/rix101"
  ];
  uid = 10578;
  gid = 10578;
  deploy = {
    hostname = "cheetah.lan";
    sshUser = "nix-on-droid";
    user = "nix-on-droid";
    magicRollback = true;
    sshOpts = [
      "-p"
      " 8022"
    ];
    remoteBuild = true;
  };
}
