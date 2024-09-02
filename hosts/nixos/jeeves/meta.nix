{
  # The `system` of the host
  system = "x86_64-linux";

  # The host SSH key, used for encrypting agenix secrets
  pubkey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPopSTZ81UyKp9JSljCLp+Syk51zacjh9fLteqxQ6/aB";

  # `deploy-rs` configuration
  deploy = {
    # This is the hostname by which you'll refer to this machine using reploy-rs
    hostname = "jeeves.reo101.xyz";

    # This is the user that deploy-rs will use when connecting.
    # This will default to your own username if not specified anywhere
    sshUser = "jeeves";

    # This is the user that the profile will be deployed to (will use sudo if not the same as above).
    # If `sshUser` is specified, this will be the default (though it will _not_ default to your own username)
    user = "root";

    # Which sudo command to use. Must accept at least two arguments:
    # the user name to execute commands as and the rest is the command to execute
    # This will default to "sudo -u" if not specified anywhere.
    sudo = "sudo -u";

    # This is an optional list of arguments that will be passed to SSH.
    sshOpts = [ "-p" "727" ];

    # Fast connection to the node. If this is true, copy the whole closure instead of letting the node substitute.
    # This defaults to `false`
    fastConnection = false;

    # If the previous profile should be re-activated if activation fails.
    # This defaults to `true`
    autoRollback = true;

    # See the earlier section about Magic Rollback for more information.
    # This defaults to `true`
    magicRollback = true;

    # The path which deploy-rs will use for temporary files, this is currently only used by `magicRollback` to create an inotify watcher in for confirmations
    # If not specified, this will default to `/tmp`
    # (if `magicRollback` is in use, this _must_ be writable by `user`)
    tempPath = "/tmp";

    # Build the derivation on the target system
    # Will also fetch all external dependencies from the target system's substituters.
    # This default to `false`
    remoteBuild = true;
  };
}
