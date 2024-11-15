{
  system = "aarch64-darwin";
  pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK2DM5F3nLKDiWoxqTwJw4bi5Q1RGZYtEPmTcLxTC7c9";
  deploy = {
    hostname = "localhost";
    sshUser = "pavelatanasov";
    user = "pavelatanasov";
    sudo = "sudo -u";
    sshOpts = [ ];
    fastConnection = false;
    autoRollback = true;
    magicRollback = true;
    tempPath = "/Users/pavelatanasov/.deploy-rs";
    remoteBuild = true;
  };
}
