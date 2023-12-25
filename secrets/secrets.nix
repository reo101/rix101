# This file is not imported into the NixOS/home-manager configurations.
# It is only used for the `agenix` CLI.
# `agenix` use the public keys defined in this file to encrypt the secrets.
# Users can decrypt the secrets by any of the corresponding private keys.

let
  # User's ssh public key:
  #     cat ~/.ssh/id_ed25519.pub
  # Generate using:
  #     ssh-keygen -t ed25519
  main = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBj8ZGcvI80WrJWV+dNy1a3L973ydSNqtwcVHzurDUaW";
  limonka = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDmO9YwsuPMstyLVElvam5mKZfr51qnNj6cIZN8cCu7f";
  limonka_age = "age1m23jgdtkfh6gqnxge88q03yy9exckajmlmx8sw2z9t3t5gpr0c4qxgdtwr";
  users = [ main limonka limonka_age ];

  # System's ssh public key:
  #    cat /etc/ssh/ssh_host_ed25519_key.pub
  # Generated automatically when running `sshd`
  jeeves_system = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPopSTZ81UyKp9JSljCLp+Syk51zacjh9fLteqxQ6/aB";
  limonka_system = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK2DM5F3nLKDiWoxqTwJw4bi5Q1RGZYtEPmTcLxTC7c9";
  systems = [ jeeves_system limonka_system ];
in
{
  "home/wifi/env.age".publicKeys = users ++ systems;
  "home/jeeves/user/password.age".publicKeys = users ++ [ jeeves_system ];
  "home/jeeves/wireguard/private.age".publicKeys = users ++ [ jeeves_system ];
}
