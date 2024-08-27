{ lib, hostPlatform, targetPlatform, ... }:
hostPlatform.isDarwin && hostPlatform.isAarch64 &&
targetPlatform.isDarwin && targetPlatform.isAarch64
