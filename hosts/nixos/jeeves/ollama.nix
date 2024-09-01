{ inputs, lib, pkgs, config, ... }:
{
  # NOTE: no need now (nginx)
  # networking.firewall.allowedTCPPorts = [11434];

  services.ollama = {
    enable = true;
    host = "0.0.0.0";
    port = 11434;
    acceleration = "rocm";
    environmentVariables = {
      # NOTE: no need now (nginx), should be only `127.0.0.1`
      # OLLAMA_ORIGINS = "*";
    };
  };

  services.nginx.virtualHosts."ollama.jeeves.local" = {
    enableACME = false;
    forceSSL = false;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString config.services.ollama.port}";
      proxyWebsockets = true;
    };
  };

  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 3000;
    environment = {
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      TRANSFORMERS_CACHE = "${config.services.open-webui.stateDir}/cache";
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
      # Disable authentication
      WEBUI_AUTH = "False";
    };
    # NOTE: no need now (nginx)
    # openFirewall = true;
  };

  services.nginx.virtualHosts."openwebui.jeeves.local" = {
    enableACME = false;
    forceSSL = false;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString config.services.open-webui.port}";
      proxyWebsockets = true;
    };
  };
}
