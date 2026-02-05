import os
import pathlib
import re
import subprocess
import sys

import requests


PACKAGE_FILE = pathlib.Path(os.environ.get("UPDATE_PACKAGE_FILE", "pkgs/lidarr-nightly/default.nix"))
UPDATE_URL = (
    "https://lidarr.servarr.com/v1/update/nightly"
    "?version={version}&includeMajorVersion=true&os=linux&runtime=netcore&arch=x64"
)


def replace_once(text: str, pattern: str, replacement: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        print(f"failed to replace pattern: {pattern}", file=sys.stderr)
        sys.exit(1)
    return updated


def main() -> None:
    text = PACKAGE_FILE.read_text()
    current_version_match = re.search(r'version = "([^"]+)";', text)
    if current_version_match is None:
        print("failed to find current version", file=sys.stderr)
        sys.exit(1)

    current_version = current_version_match.group(1)

    response = requests.get(UPDATE_URL.format(version=current_version), timeout=30)
    response.raise_for_status()
    payload = response.json()
    if not payload["available"]:
        sys.exit(0)

    package = payload["updatePackage"]
    version = package["version"]
    url = package["url"]
    # Azure artifact URLs have query strings; convert the API's published hash instead.
    hash_sri = subprocess.run(
        ["nix", "hash", "convert", "--hash-algo", "sha256", "--to", "sri", package["hash"]],
        stdout=subprocess.PIPE,
        text=True,
        check=True,
    ).stdout.strip()

    text = replace_once(text, r'version = "[^"]+";', f'version = "{version}";')
    text = replace_once(text, r'url = "[^"]+";', f'url = "{url}";')
    text = replace_once(text, r'hash = "sha256-[^"]+";', f'hash = "{hash_sri}";')
    PACKAGE_FILE.write_text(text)


if __name__ == "__main__":
    main()
