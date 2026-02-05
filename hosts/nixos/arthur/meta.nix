{
  system = "x86_64-linux";

  pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFhklR3PDLJ+V9yP5PIU7g7xQraBnnEIN6zJjfBedTuw root@arthur";

  gui = true;

  deploy = {
    hostname = "arthur";
    sshUser = "maria";
    user = "root";
    sudo = "sudo -u";
    sshOpts = [ "-p" "22" ];
    fastConnection = false;
    autoRollback = true;
    magicRollback = true;
    tempPath = "/tmp";
    remoteBuild = true;
  };
}
