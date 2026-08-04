{
  lib,
  runCommand,
  aria2,
  tor,
  curl,
  ...
}:

program: url:
{ file, outputHash }:
runCommand "${program}-${builtins.baseNameOf (builtins.dirOf url)}-file-${file}"
  {
    inherit outputHash;
    nativeBuildInputs = [
      tor.proxyHook
    ];
  }
  ''
    shopt -s extglob;
    torrent="$NIX_BUILD_TOP/${program}.torrent"
    '${lib.getExe curl}' \
      --fail \
      --location \
      --output "$torrent" \
      ${lib.escapeShellArg url}
    '${lib.getExe aria2}' \
      --seed-time '0' \
      --select-file ${lib.escapeShellArg file} \
      --index-out ${lib.escapeShellArg file}="''${PWD//+([^\/])/..}$out" \
      --torrent-file "$torrent";
  ''
