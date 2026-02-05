{ lib, stdenv, ... }:
!(stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isx86_64)
