{ system, overlays, ... }:

let
  final = builtins.foldl' (previous: overlay: previous // overlay final previous) {
    stdenv.hostPlatform = {
      isLinux = builtins.match ".*-linux" system != null;
      isDarwin = builtins.match ".*-darwin" system != null;
    };
    inputs = "ordinary";
    callPackage = package: arguments: final.lib.callPackageWith final package arguments;
  } overlays;
in
final
