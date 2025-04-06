{
  system = "aarch64-linux";

  pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJZFRF6sDONR9q7Hx+11ARCOaJ8b/7WvOclm4GxK79Nk";

  deploy = {
    hostname = "gomi.lan";
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
