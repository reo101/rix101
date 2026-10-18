{ aspects, ... }:
{
  system = "aarch64-linux";

  users.reo101.aspects = with aspects; [ standardEnvironment wayland ];

  pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHoPr13i+vYcyUqoJocd5UNyNXJjpWzMHQJZC7oWwKE/ root@nixos";

  deploy = {
    hostname = "localhost";
    sshUser = "reo101";
    user = "root";
    sudo = "sudo -u";
    sshOpts = [
      "-p"
      "8222"
    ];
    fastConnection = false;
    autoRollback = true;
    magicRollback = true;
    tempPath = "/tmp";
    remoteBuild = true;
  };
}
