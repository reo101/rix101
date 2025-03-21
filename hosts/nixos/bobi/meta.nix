{
  system = "x86_64-linux";

  pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDuz5UNpLdIfzSyDEbban+2A23ir7Xu4G9O7QfzkQtrp";

  deploy = {
    hostname = "bobi.lan";
    sshUser = "reo101";
    user = "root";
    sudo = "sudo -u";
    sshOpts = [ "-p" "22" ];
    fastConnection = false;
    autoRollback = true;
    magicRollback = true;
    tempPath = "/tmp";
    remoteBuild = false;
  };
}
