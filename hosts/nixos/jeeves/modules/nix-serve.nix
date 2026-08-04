{ lib, pkgs, config, ... }:

let
  domain = "cache.jeeves.reo101.xyz";
  secret = "nix-serve.key";
in
{
  age.secrets.${secret} = {
    rekeyFile = lib.custom.repoSecret "home/jeeves/nix-serve/key.age";
    generator.script =
      { file, ... }:
      let
        nix = lib.getExe pkgs.nix;
      in
      /* bash */ ''
        key="$(${nix} key generate-secret --key-name ${domain}-1)"
        ${nix} key convert-secret-to-public <<< "$key" > ${lib.escapeShellArg (lib.removeSuffix ".age" file + ".pub")}
        printf '%s\n' "$key"
      '';
  };

  services.nix-serve = {
    enable = true;
    bindAddress = "127.0.0.1";
    secretKeyFile = config.age.secrets.${secret}.path;
  };

  services.nginx.virtualHosts.${domain} = {
    forceSSL = true;
    useACMEHost = "jeeves.reo101.xyz";
    locations."/".proxyPass = "http://127.0.0.1:${builtins.toString config.services.nix-serve.port}";
  };

  systemd.services.nix-serve.restartTriggers = [ config.age.secrets.${secret}.file ];
}
