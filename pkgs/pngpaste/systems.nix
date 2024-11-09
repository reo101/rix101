{ lib, hostPlatform, buildPlatform, targetPlatform, ... }:
hostPlatform.isDarwin && hostPlatform.isAarch64 &&
buildPlatform.isDarwin && buildPlatform.isAarch64
