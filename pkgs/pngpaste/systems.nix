{ lib, stdenv, ... }:
stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isAarch64 &&
stdenv.buildPlatform.isDarwin && stdenv.buildPlatform.isAarch64
