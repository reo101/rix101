{
  release,
  arch,
  sha256sumsHash,
  feedHashes,
}:

let
  baseUrl = "https://downloads.openwrt.org/releases/${release}/packages/${arch}/";
  mkSourceInfo = hash: url: { inherit hash url; };
  mkFeed = feed: hash: {
    baseUrl = "${baseUrl}${feed}/";
    sourceInfo = mkSourceInfo hash "${baseUrl}${feed}/packages.adb";
    # Keep `packages` present so nix-openwrt-imagebuilder can parse dynamically.
    packages = null;
  };
in {
  sha256sums = mkSourceInfo sha256sumsHash "${baseUrl}sha256sums";
  feeds = builtins.mapAttrs mkFeed feedHashes;
}
