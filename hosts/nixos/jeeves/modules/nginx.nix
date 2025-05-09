{ inputs, lib, pkgs, config, ... }:

{
  environment.systemPackages = [
  ];

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;
    package = pkgs.openresty;
  };

  age.secrets."epik.api.secrets" = {
    rekeyFile = lib.repoSecret "epik/api/secrets.env.age";
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
}
