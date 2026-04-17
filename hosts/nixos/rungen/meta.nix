{
  system = "x86_64-linux";

  roles = [
    "common/rix101"
    "desktop/wayland"
  ];

  pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN2SviyDaz+wZpQpn9PwYnz/Jl4C4MsxiK6A2NmfRKY2 root@rungen";

  gui = true;

  deploy = {
    hostname = "rungen";
    sshUser = "reo101";
    user = "root";
    sudo = "sudo -u";
    sshOpts = [
      "-p"
      "22"
    ];
    fastConnection = false;
    autoRollback = true;
    magicRollback = true;
    tempPath = "/tmp";
    remoteBuild = true;
  };
}
