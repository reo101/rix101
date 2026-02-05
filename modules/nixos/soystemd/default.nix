{ pkgs, lib, ... }:

{
  environment.systemPackages = [
    (pkgs.runCommandLocal "soystemd" { } ''
      mkdir -p $out/bin
      ${lib.getExe' pkgs.findutils "find"} ${pkgs.systemd}/bin -executable -name "sys*" -exec \
        sh -c 'ln -s "{}" "$out/bin/$(basename "{}" | sed '"'"'s/^sys/soys/; t; q 1'"'"')"' ';'
    '')
  ];
}
