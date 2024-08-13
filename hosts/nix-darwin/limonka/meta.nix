{
  system = "aarch64-darwin";
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
