{ pkgs
, lib
, runCommand
, makeWrapper

# NOTE: only works with vanilla `2.24` nix
, nix ? pkgs.nixVersions.latest
, nix-plugins ? pkgs.nix-plugins.overrideAttrs (oldAttrs: {
    # Only override `nix`
    buildInputs = lib.pipe oldAttrs.buildInputs [
      (lib.filter
        (drv: drv.pname != "nix"))
      (buildInputs: [ nix ] ++ buildInputs)
    ];
  })

, plugin-files ? "${nix-plugins}/lib/nix/plugins"
, # NOTE: purposefully sending the whole `rage-import-encrypted` directory
  #       to the `/nix/store`, bringing `rage-decrypt-and-cache.sh` with it
  extra-builtins-file ? "${./rage-import-encrypted}/default.nix"
, # TODO: list/attrset for easier `--prefix` instead of `--set` for `NIX_CONFIG`
  nix-config ? ''
    extra-experimental-features = nix-command flakes
    plugin-files = ${plugin-files}
    extra-builtins-file = ${extra-builtins-file}
  ''
, ...
}:
runCommand "nix-enraged" {
  buildInputs = [ makeWrapper ];
} ''
  mkdir -p $out/bin
  ln -s ${lib.getExe nix} $out/bin/nix
  wrapProgram $out/bin/nix --set NIX_CONFIG ${lib.escapeShellArg nix-config}
''
