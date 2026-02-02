{ inputs, lib, ... }:

final: prev:
lib.infuse prev {
  lib.maintainers.reo101.__assign = {
    name = "Pavel Atanasov";
    email = "pavel.atanasov2001@gmail.com";
    github = "reo101";
    githubId = "37866329";
    keys = [
      # YubiKey 1 (Green)
      { fingerprint = "49B8 3918 36E2 4FEC BC68  7504 7DA9 78E6 383E 5885"; }
      # Old GPG
      { fingerprint = "8A29 0250 C775 7813 1DD1  DC57 7275 0ABE E181 26D0"; }
    ];
  };

  nix-monitored.__assign = inputs.nix-monitored.packages.${prev.stdenv.hostPlatform.system}.default.override {
    nix = prev.nix;
    nix-output-monitor = prev.nix-output-monitor;
  };

  lix-monitored.__assign = inputs.nix-monitored.packages.${prev.stdenv.hostPlatform.system}.default.override {
    nix = prev.lix;
    nix-output-monitor = prev.nix-output-monitor;
  };

  nixVersions.monitored.__assign =
    lib.flip lib.concatMapAttrs prev.nixVersions (version: package:
      let
        # Check if package evaluates and is a derivation
        evalResult = builtins.tryEval (lib.isDerivation package);
        isValidDerivation = evalResult.success && evalResult.value;
      in
      lib.optionalAttrs isValidDerivation {
        # NOTE: `lib.getBin` is needed, otherwise the `-dev` output is chosen
        "${version}" = lib.getBin (inputs.nix-monitored.packages.${final.stdenv.hostPlatform.system}.default.override {
          nix = package;
          nix-output-monitor = prev.nix-output-monitor;
        });
      }
    );

  # FIXME: <https://github.com/NixOS/nixpkgs/issues/442652>
  ceph.__assign = inputs.nixpkgs-stable.legacyPackages.${prev.stdenv.hostPlatform.system}.ceph;

  river-classic.__output.xwaylandSupport.__assign = true;

  discord.__input = {
    withOpenASAR.__assign = true;
    withVencord.__assign = true;
  };

  legcord.__output.postInstallPhase.__assign = /* bash */ ''
    mv $out/legcord $out/legcord_broken_ime
    makeShellWrapper "$out/legcord_broken_ime" "$out/legcord" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--wayland-text-input-version=3}}"
  '';

  prismlauncher.__output.patches.__append = [
    ./offline-mode-prism-launcher.diff
  ];
}
