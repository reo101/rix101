# NixOps4 deployment wiring for OpenWrt hosts.
#
# Discovers all OpenWrt hosts with `meta.openwrt` set, maps their public
# module `sections` plus runtime-encrypted secret docs into a whole-router
# resource per host.
{
  inputs,
  self,
  lib,
  config,
  withSystem,
  ...
}:

let
  cfg = config.openwrt-nixops4;
  inherit (lib) mkOption types;

  mkRouterDeployment =
    hostName: hostMeta:
    let
      hostDir = "${self}/hosts/openwrt/${hostName}";
      meta = hostMeta.openwrt;
      moduleNames = builtins.attrNames (
        lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name)
          (builtins.readDir (hostDir + "/modules"))
      );
      sections = lib.concatLists (
        map (
          moduleName:
          let
            module = import (hostDir + "/modules/${moduleName}") { inherit lib; };
          in
          module.sections or [ ]
        ) moduleNames
      );
    in
    {
      providers.openwrt = inputs.nixops4-openwrt.modules.nixops4Provider.openwrt;
      members.router = {
        type = "providers.openwrt.uci_router";
        inputs = {
          inherit (meta)
            host
            port
            dryRun
            rollbackTimeout
            ;
          secretFlake = toString self.outPath;
          secretFile = toString (builtins.path {
            name = "openwrt-router-config.nix.age";
            path = inputs.self + "/${meta.secretFile}";
          });
          secretIdentityFiles = map (
            entry: toString entry.identity
          ) config.flake.secretsConfig.masterIdentities;
          configs = lib.mapAttrsToList (configName: secs: {
            name = configName;
            sections = map (section: {
              inherit (section) name options lists;
              sectionType = section.type;
              inherit (section) match authoritative;
            }) secs;
          }) (lib.groupBy (s: s.config) sections);
        };
      };
    };
in
{
  options.openwrt-nixops4 = {
    enable = lib.mkEnableOption "NixOps4 whole-router reconciliation for OpenWrt hosts";
    hosts = mkOption {
      description = "OpenWrt host names to manage via NixOps4";
      type = types.listOf types.str;
      default = lib.mapAttrsToList (
        name: host: name
      ) (
        lib.filterAttrs (_: host: host.meta.openwrt or null != null)
          config.auto.configurations.configurationTypes.openwrt.result
      );
    };
  };

  config = lib.mkIf cfg.enable {
    flake-file.inputs = {
      nixops4 = {
        url = "github:nixops4/nixops4";
        inputs.flake-parts.follows = "flake-parts";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      nixops4-openwrt = {
        url = "github:reo101/nixops4-openwrt";
        inputs.nixops4.follows = "nixops4";
        inputs.flake-file.follows = "flake-file";
        inputs.flake-parts.follows = "flake-parts";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.systems.follows = "systems";
      };
    };

    perSystem = { pkgs, inputs', ... }: {
      devShells.openwrt-nixops4 = pkgs.mkShell {
        packages = [ inputs'.nixops4.packages.default ];
      };
    };
  };
}
