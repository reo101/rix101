{
  system = "x86_64-linux";

  roles = [
    "common/rix101"
  ];

  pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJiAv6yRFbJIaAPk+/L/PvtswKLo6MDeFQmRBsEPZ+xc";

  deploy = {
    hostname = "192.168.1.223";
    sshUser = "reo101";
    user = "root";
    sudo = "sudo -u";
    fastConnection = false;
    autoRollback = true;
    magicRollback = true;
    tempPath = "/tmp";
    remoteBuild = true;
  };
}
