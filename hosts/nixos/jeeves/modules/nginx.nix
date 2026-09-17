{ inputs, lib, pkgs, config, ... }:

{
  environment.systemPackages = [
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;
    package = pkgs.openresty;

    # NOTE: as per <https://github.com/dani-garcia/vaultwarden/wiki/Proxy-examples#nginx-nixos-by-tklitschi-samdoshi>
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    # NOTE: sets Host / X-Real-IP / X-Forwarded-For / X-Forwarded-Proto on every proxied location,
    #       so upstreams (e.g. vaultwarden) see real client IPs
    recommendedProxySettings = true;
    recommendedTlsSettings = true;

    # NOTE: baseline headers only; do NOT add CSP here, apps like vaultwarden manage their own
    #       <https://github.com/dani-garcia/vaultwarden/discussions/6344>
    commonHttpConfig = /* nginx */ ''
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
      add_header X-Content-Type-Options "nosniff" always;
      add_header Referrer-Policy "strict-origin-when-cross-origin" always;
      add_header X-Robots-Tag "noindex, nofollow" always;
    '';
  };

  age.secrets."epik.api.secrets" = {
    rekeyFile = lib.custom.repoSecret "epik/api/secrets.env.age";
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "${pkgs.lib.maintainers.reo101.email}";
      group = "nginx";
    };
    certs =
      let
        domain = "jeeves.reo101.xyz";
      in
      {
        "${domain}" = {
          domain = "${domain}";
          dnsProvider = "epik";
          environmentFile = config.age.secrets."epik.api.secrets".path;
          # NOTE: as per <https://go-acme.github.io/lego/dns/epik>
          # credentialFiles = {
          #   "EPIK_SIGNATURE" = "";
          # };
          extraDomainNames = [
            "*.${domain}"
          ];
          webroot = null;
        };
      };
  };

  services.nginx.virtualHosts."~^.*\.jeeves\.reo101\.xyz$" = {
    forceSSL = true;
    useACMEHost = "jeeves.reo101.xyz";
    locations."/" = {
      return = "404";
    };
  };
}
