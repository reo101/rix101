{ inputs, config, lib, ... }:
let
  enable = true;
  domain = "pds.jeeves.reo101.xyz";
  dataDirectory = "/data/pds";
  publicHttpsPort = 9443;
  virtualHost = {
    forceSSL = true;
    useACMEHost = domain;
    extraConfig = ''
      listen 0.0.0.0:${builtins.toString publicHttpsPort} ssl;
    '';
    locations."/" = {
      proxyPass = "http://${config.services.tranquil-pds.settings.server.host}:${builtins.toString config.services.tranquil-pds.settings.server.port}";
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 300M;
        proxy_read_timeout 600s;
      '';
    };
  };
in
{
  imports = [ inputs.tranquil.nixosModules.default ];

  age.secrets."pds.jwt-secret" = {
    intermediary = true;
    rekeyFile = lib.custom.repoSecret "home/jeeves/pds/jwt-secret.age";
    generator.script = { pkgs, ... }: /* bash */ ''
      ${lib.getExe pkgs.openssl} rand --hex 64
    '';
  };

  age.secrets."pds.dpop-secret" = {
    intermediary = true;
    rekeyFile = lib.custom.repoSecret "home/jeeves/pds/dpop-secret.age";
    generator.script = { pkgs, ... }: /* bash */ ''
      ${lib.getExe pkgs.openssl} rand -base64 48
    '';
  };

  # Back up this key with the database; it protects stored account keys.
  age.secrets."pds.master-key" = {
    intermediary = true;
    rekeyFile = lib.custom.repoSecret "home/jeeves/pds/master-key.age";
    generator.script = { pkgs, ... }: /* bash */ ''
      ${lib.getExe pkgs.openssl} rand -base64 48
    '';
  };

  age.secrets."pds.environment" = {
    rekeyFile = lib.custom.repoSecret "home/jeeves/pds/tranquil.environment.age";
    generator = {
      dependencies = {
        inherit (config.age.secrets)
          "pds.jwt-secret"
          "pds.dpop-secret"
          "pds.master-key"
          ;
      };
      script = { decrypt, deps, ... }: /* bash */ ''
        jwt_secret="$(${decrypt} ${lib.escapeShellArg deps."pds.jwt-secret".file})" || exit "$?"
        dpop_secret="$(${decrypt} ${lib.escapeShellArg deps."pds.dpop-secret".file})" || exit "$?"
        master_key="$(${decrypt} ${lib.escapeShellArg deps."pds.master-key".file})" || exit "$?"
        printf 'JWT_SECRET=%s\n' "$jwt_secret"
        printf 'DPOP_SECRET=%s\n' "$dpop_secret"
        printf 'MASTER_KEY=%s\n' "$master_key"
      '';
    };
  };

  services.tranquil-pds = {
    inherit enable;
    dataDir = dataDirectory;
    database.createLocally = true;
    environmentFiles = [ config.age.secrets."pds.environment".path ];
    settings.server = {
      hostname = domain;
      host = "127.0.0.1";
      max_blob_size = 314572800;
      invite_code_required = true;
    };
  };

  systemd.services.tranquil-pds = lib.mkIf config.services.tranquil-pds.enable {
    unitConfig.RequiresMountsFor = [ dataDirectory ];
    serviceConfig = {
      StateDirectory = lib.mkForce [ ];
      ReadWritePaths = [ dataDirectory ];
    };
  };

  networking.firewall.allowedTCPPorts = lib.mkIf config.services.tranquil-pds.enable [ publicHttpsPort ];

  security.acme.certs.${domain} = lib.mkIf config.services.tranquil-pds.enable {
    dnsProvider = "epik";
    environmentFile = config.age.secrets."epik.api.secrets".path;
    extraDomainNames = [ "*.${domain}" ];
    webroot = null;
  };

  services.nginx.virtualHosts = lib.mkIf config.services.tranquil-pds.enable {
    "pds-public-default" = {
      default = true;
      rejectSSL = true;
      listen = [
        {
          addr = "0.0.0.0";
          port = publicHttpsPort;
          ssl = true;
        }
      ];
    };
    "${domain}" = virtualHost;
    "*.${domain}" = virtualHost;
  };
}
