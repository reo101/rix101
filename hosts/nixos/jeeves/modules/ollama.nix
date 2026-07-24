{ inputs, lib, pkgs, config, ... }:
{
  # NOTE: no need now (nginx)
  # networking.firewall.allowedTCPPorts = [11434];

  services.ollama = {
    enable = true;
    package = pkgs.ollama-rocm;
    user = "ollama";
    group = "ollama";
    home = "/data/.state/ollama";
    models = "/data/.state/ollama/models";
    host = "127.0.0.1";
    port = 11434;
    environmentVariables = {
      OLLAMA_ORIGINS = "https://openwebui.jeeves.reo101.xyz";
    };
  };

  services.nginx.virtualHosts."ollama.jeeves.reo101.xyz" = {
    forceSSL = true;
    useACMEHost = "jeeves.reo101.xyz";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString config.services.ollama.port}";
      proxyWebsockets = true;
    };
  };

  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 3000;
    environment = {
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
      TRANSFORMERS_CACHE = "${config.services.open-webui.stateDir}/cache";
      OLLAMA_API_BASE_URL = "http://127.0.0.1:${builtins.toString config.services.ollama.port}";
      WEBUI_AUTH = "True";
    };
    # NOTE: no need now (nginx)
    # openFirewall = true;
  };

  services.nginx.virtualHosts."openwebui.jeeves.reo101.xyz" = {
    forceSSL = true;
    useACMEHost = "jeeves.reo101.xyz";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${builtins.toString config.services.open-webui.port}";
      proxyWebsockets = true;
    };
  };
}
