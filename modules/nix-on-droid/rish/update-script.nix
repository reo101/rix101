{ lib
, writeShellScript
, coreutils
, bash
, curl
, jq
, gnugrep
, gnused
, nix
}:

writeShellScript "update-shizuku" ''
  set -euo pipefail

  # Get the latest release information from GitHub API
  latest_release=$(${lib.getExe' curl "curl"} -s https://api.github.com/repos/RikkaApps/Shizuku/releases/latest)

  # Extract version
  version=$(echo "$latest_release" | ${lib.getExe' jq "jq"} -r '.tag_name' | ${lib.getExe' gnused "sed"} 's/^v//')

  # Find the APK asset URL
  apk_url=$(echo "$latest_release" | \
    ${lib.getExe' jq "jq"} -r '.assets[] | select(.name | endswith(".apk")) | .browser_download_url')

  # Download the APK to get its hash
  hash=$(${lib.getExe' nix "nix-prefetch-url"} "$apk_url" 2>/dev/null)

  # Update the package expression
  sed_script="
    s|version = \"[0-9.]*\"|version = \"$version\"|
    s|url = \".*\"|url = \"$apk_url\"|
    s|hash = \".*\"|hash = \"$hash\"|
  "

  # Path to the package expression
  expr_file="default.nix"

  if [ -f "$expr_file" ]; then
    ${lib.getExe' gnused "sed"} -i "$sed_script" "$expr_file"
    echo "Updated $expr_file to version $version"
    echo "New URL: $apk_url"
    echo "New hash: $hash"
  else
    echo "Error: Could not find package expression at $expr_file"
    exit 1
  fi
''
