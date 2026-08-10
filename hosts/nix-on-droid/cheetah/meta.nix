{
  system = "aarch64-linux";
  # HACK: newer versions fail to allocate `PTY`s in `NoD`
  nixpkgs = "88d3861acdd3d2f0e361767018218e51810df8a1";
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
      "8022"
    ];
    remoteBuild = true;
  };
}
