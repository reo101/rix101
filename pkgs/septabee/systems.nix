{ stdenv, ... }:

stdenv.hostPlatform.isLinux && stdenv.hostPlatform.isx86_64
