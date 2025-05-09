{ inputs, lib, pkgs, config, ... }:

let
  protocol = "https";
  domain = "cloud.jeeves.reo101.xyz";

  cfg = config.services.opencloud;
in
{
  # NOTE: for mounting `OpenCloud`'s `Space`s
  services.davfs2 = {
    enable = true;
    settings = {
      globalSection = {
        use_locks = false;
        delay_upload = 0;
        cache_size = 0;
      };
    };
  };

  services.opencloud = {
    enable = true;

    stateDir = "/data/opencloud";

    url = "${protocol}://${domain}";
    port = 9200;

    settings = {
      proxy = {
        # NOTE: handled by `nginx`
        tls = false;
        # NOTE: for WebDAV
        enable_basic_auth = true;
      };
      csp = {
        directives = {
          child-src = [
            "'self'"
          ];
          connect-src = [
            "'self'"
            "blob:"
            "https://raw.githubusercontent.com/opencloud-eu/awesome-apps/"
            "https://update.opencloud.eu/"
          ];
          default-src = [
            "'none'"
          ];
          font-src = [
            "'self'"
          ];
          frame-ancestors = [
            "'self'"
          ];
          frame-src = [
            "'self'"
            "blob:"
            "https://embed.diagrams.net/"
            "https://docs.opencloud.eu"
          ];
          img-src = [
            "'self'"
            "data:"
            "blob:"
            "https://raw.githubusercontent.com/opencloud-eu/awesome-apps/"
            "https://tile.openstreetmap.org/"
          ];
          manifest-src = [
            "'self'"
          ];
          media-src = [
            "'self'"
          ];
          object-src = [
            "'self'"
            "blob:"
          ];
          script-src = [
            "'self'"
            "'unsafe-inline'"
          ];
          style-src = [
            "'self'"
            "'unsafe-inline'"
          ];
        };
      };
    };
    environment = {
      OC_DOMAIN = "${domain}";

      # Trust reverse proxy headers
      PROXY_TRUSTED_PROXIES = "127.0.0.1";

      # NOTE: initial only
      IDM_ADMIN_PASSWORD = "banicabanica";

      # More logs
      OC_LOG_LEVEL = "info";
      OC_LOG_COLOR = "true";
      # OC_LOG_PRETTY = "true";

      # Skip update checks
      FRONTEND_CHECK_FOR_UPDATES = "false";
    };
  };

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    useACMEHost = "jeeves.reo101.xyz";
    locations."/" = {
      proxyPass = "${protocol}://${cfg.address}:${builtins.toString cfg.port}";
      proxyWebsockets = true;
      extraConfig = /* nginx */ ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Increase max upload size (required for Tus — without this, uploads over 1 MB fail)
        client_max_body_size 100G;
        client_body_buffer_size 400M;

        # Disable buffering - essential for SSE
        proxy_buffering off;
        proxy_request_buffering off;

        # Extend timeouts for long connections
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        keepalive_timeout 3600s;

        # Prevent nginx from trying other upstreams
        proxy_next_upstream off;
      '';
    };
  };
}
