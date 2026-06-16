{
  lib,
  runCommand,
  aria2,
  tor,
  curl,
  ...
}:

program: url:
entry@{ file, outputHash }:
runCommand "${program}-${file}"
  {
    inherit outputHash;
    nativeBuildInputs = [
      tor.proxyHook
    ];
  }
  ''
    shopt -s extglob;
    '${lib.getExe aria2}' \
      --seed-time '0' \
      --select-file ${lib.escapeShellArg file} \
      --index-out ${lib.escapeShellArg file}="''${PWD//+([^\/])/..}$out" \
      --torrent-file <(${lib.getExe curl} ${lib.escapeShellArg url});
  ''
