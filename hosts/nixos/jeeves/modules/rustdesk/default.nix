{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  ACMEHost = "jeeves.reo101.xyz";
  domain = "rustdesk.${ACMEHost}";
  idServer = "${domain}:21116";
  relayServer = "${domain}:21117";
  publicDir = "/var/lib/rustdesk-public";
  publicKeyPath = "/id_ed25519.pub";
  htnl = inputs.htnl.lib;
  inherit (htnl) bundle document raw;
  h = htnl.polymorphic.element;
  renderServerSetting =
    {
      label,
      value,
    }:
    h "li" [
      "${label}: "
      (h "code" value)
    ];
  serverSettingItems = builtins.map renderServerSetting [
    {
      label = "ID Server";
      value = idServer;
    }
    {
      label = "Relay Server";
      value = relayServer;
    }
    {
      label = "API Server";
      value = "leave blank";
    }
  ];
  site = bundle pkgs {
    name = "rustdesk-setup-site";
    htmlDocuments."index.html" = document (
      h "html" { lang = "en"; } [
        (h "head" [
          (h "meta" { charset = "utf-8"; })
          (h "meta" {
            name = "viewport";
            content = "width=device-width, initial-scale=1";
          })
          (h "title" "RustDesk on ${domain}")
          (h "style" (raw (builtins.readFile ./styles.css)))
        ])
        (h "body" [
          (h "main" [
            (h "section" { class = "hero"; } [
              (h "h1" "RustDesk server settings")
              (h "p" "Paste these values exactly into the RustDesk client network settings.")
            ])
            (h "section" { class = "body"; } [
              (h "ul" serverSettingItems)
              (h "p" [
                "Do not include "
                (h "code" "https://")
                " in the ID or Relay fields."
              ])
              (h "h2" "Public key")
              (h "div" { class = "card"; } [
                (h "pre" [ (h "code" { id = "public-key"; } "Loading...") ])
                (h "p" [
                  "Raw key: "
                  (h "a" { href = publicKeyPath; } publicKeyPath)
                ])
                (h "p" {
                  class = "status";
                  id = "public-key-status";
                } "Fetching current server key...")
              ])
              (h "script" (raw /* javascript */ ''
                const keyElement = document.getElementById("public-key")
                const statusElement = document.getElementById("public-key-status")

                fetch("${publicKeyPath}", { cache: "no-store" })
                  .then((response) => {
                    if (!response.ok) {
                      throw new Error(`HTTP ''${response.status}`)
                    }
                    return response.text()
                  })
                  .then((text) => {
                    keyElement.textContent = text.trim()
                    statusElement.textContent = "Loaded live from the RustDesk server key file."
                  })
                  .catch((error) => {
                    keyElement.textContent = "Key is not available yet. Try again in a moment."
                    statusElement.dataset.state = "error"
                    statusElement.textContent = `Unable to load the key right now (''${error.message}).`
                  })
              ''))
            ])
          ])
        ])
      ]
    );
  };
  publishSetupPage = pkgs.writeShellScript "rustdesk-publish-setup-page" ''
    set -eu

    key_src=/var/lib/rustdesk/id_ed25519.pub
    key_dst=${publicDir}/id_ed25519.pub

    ${lib.getExe' pkgs.coreutils "install"} -d -m 0755 ${publicDir}
    ${lib.getExe' pkgs.coreutils "cp"} -rf ${site}/. ${publicDir}/

    attempts=0
    while [ ! -s "$key_src" ] && [ "$attempts" -lt 60 ]; do
      sleep 1
      attempts=$((attempts + 1))
    done

    if [ ! -s "$key_src" ]; then
      echo "RustDesk public key was not generated at $key_src" >&2
      exit 1
    fi

    ${lib.getExe' pkgs.coreutils "install"} -m 0644 "$key_src" "$key_dst"
  '';
in
{
  services.rustdesk-server = {
    enable = true;
    openFirewall = true;

    signal.relayHosts = [ domain ];
  };

  systemd.services.rustdesk-publish-setup-page = {
    description = "Publish RustDesk setup page";
    wantedBy = [ "multi-user.target" ];
    wants = [ "rustdesk-signal.service" ];
    after = [ "rustdesk-signal.service" ];
    partOf = [ "rustdesk-signal.service" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = publishSetupPage;
    };
  };

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = ACMEHost;
    locations."/".extraConfig = /* nginx */ ''
      root ${publicDir};
      try_files $uri $uri/ /index.html;
    '';
  };
}
