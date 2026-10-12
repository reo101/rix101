{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:
let
  # Generate/rekey the environment file and configure router/DNS access before deploying.
  # Back up the master key with /var/lib/knot; losing it breaks repository identity.
  enable = true;
  owner = "did:plc:i5u7p3zlhkq62yxjrn7i5lvq";
  knotDomain = "knot.jeeves.reo101.xyz";
  spindleDomain = "spindle.jeeves.reo101.xyz";
  publicHttpsPort = 9443;
  image = inputs.tangled.packages.${pkgs.stdenv.hostPlatform.system}.spindle-nixos-image;
in
{
  imports = [
    inputs.tangled.nixosModules.knot-rs
    inputs.tangled.nixosModules.spindle
  ];

  assertions = [
    {
      assertion = enable -> owner != "did:plc:REPLACE_WITH_YOUR_DID";
      message = "Replace the Tangled owner DID before enabling the services.";
    }
  ];

  age.secrets."tangled.master-key" = {
    intermediary = true;
    rekeyFile = lib.custom.repoSecret "home/jeeves/tangled/master-key.age";
    generator.script =
      { pkgs, ... }:
      /* bash */ ''printf '%s' "$(${lib.getExe pkgs.openssl} rand -base64 32)"'';
  };

  age.secrets."tangled.master-key-env" = lib.mkIf enable {
    rekeyFile = lib.custom.repoSecret "home/jeeves/tangled/master-key.env.age";
    generator = {
      dependencies = {
        inherit (config.age.secrets) "tangled.master-key";
      };
      script = { decrypt, deps, ... }: /* bash */ ''
        master_key="$(${decrypt} ${lib.escapeShellArg deps."tangled.master-key".file})" || exit "$?"
        printf 'KNOT_MASTER_KEY=%s\n' "$master_key"
      '';
    };
  };

  services.tangled.knot-rs = {
    inherit enable;
    environmentFile = lib.mkIf enable config.age.secrets."tangled.master-key-env".path;
    settings = {
      server = {
        hostname = knotDomain;
        admins = [ owner ];
        ssh_listen_addr = "[::]:2222"; # Keep Jeeves's administrative SSH on 22.
      };
      atproto.plc_directory = "https://plc.directory";
      xrpc = {
        trusted_proxy_header = "x-forwarded-for";
        trusted_proxies = [ "127.0.0.1" ];
      };
    };
  };

  services.tangled.spindle = {
    inherit enable;
    server = {
      hostname = spindleDomain;
      inherit owner;
      listenAddr = "127.0.0.1:6555";
      metricsListenAddr = "127.0.0.1:6556";
      maxJobCount = 2;
    };
    mill.artifactStore = "disk";
    artifactStores.disk.dir = "/var/lib/spindle/artifacts";
    pipelines.microvm = {
      imageDir = "/var/lib/spindle/images";
      defaultImage = "nixos-x86_64";
      overlayDir = "/var/cache/spindle/overlays";
      cgroup.enable = true;
      limits = {
        workflow = {
          vcpus = 4;
          memoryMiB = 8192;
          diskMiB = 32768;
        };
        total = {
          vcpus = 8;
          memoryMiB = 16384;
          diskMiB = 65536;
        };
      };
    };
  };

  systemd.services.spindle.serviceConfig.StateDirectoryMode = lib.mkIf enable (lib.mkForce "0700");

  # The upstream spindle module enables Docker even for microVM-only workflows.
  # Keep Jeeves's existing Podman deployment instead.
  virtualisation.docker.enable = lib.mkIf enable (lib.mkForce false);

  systemd.tmpfiles.settings."tangled-spindle" = lib.mkIf enable {
    "/var/cache/spindle/overlays".d = {
      mode = "0700";
      user = "root";
      group = "root";
    };
    "/var/lib/spindle/images".d = {
      mode = "0755";
      user = "root";
      group = "root";
    };
    "/var/lib/spindle/images/nixos-x86_64"."L+" = {
      argument = "${image}";
    };
  };

  networking.firewall.allowedTCPPorts = lib.mkIf enable [ publicHttpsPort ];

  services.nginx.virtualHosts = lib.mkIf enable {
    "${knotDomain}" = {
      forceSSL = true;
      useACMEHost = "jeeves.reo101.xyz";
      extraConfig = ''
        listen 0.0.0.0:${builtins.toString publicHttpsPort} ssl;
      '';
      locations."/" = {
        proxyPass = "http://${builtins.toString config.services.tangled.knot-rs.settings.server.listen_addr}";
        proxyWebsockets = true;
        extraConfig = ''
          client_max_body_size 300M;
          proxy_read_timeout 600s;
        '';
      };
    };
    "${spindleDomain}" = {
      forceSSL = true;
      useACMEHost = "jeeves.reo101.xyz";
      extraConfig = ''
        listen 0.0.0.0:${builtins.toString publicHttpsPort} ssl;
      '';
      locations."/" = {
        proxyPass = "http://${builtins.toString config.services.tangled.spindle.server.listenAddr}";
        proxyWebsockets = true;
      };
    };
  };
}
