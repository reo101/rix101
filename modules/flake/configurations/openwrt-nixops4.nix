# NixOps4 whole-router reconciliation for OpenWrt hosts.
#
# Discovers hosts with `meta.openwrt` set, maps their public module
# `sections` plus runtime-encrypted secret documents into a `uci_router`
# resource.
{
  inputs,
  self,
  lib,
  config,
  ...}:

let
  inherit (lib) mkOption mkEnableOption mkIf types mapAttrsToList filterAttrs concatLists;

  openwrtHosts = filterAttrs (_: host:
    let
      ow = host.meta.openwrt or null;
    in
    ow != null && ow.secretFile or null != null
  ) config.auto.configurations.configurationTypes.openwrt.result;

  mkRouterInputs =
    {
      lib,
      self,
      secretsConfig,
      hostDir,
      meta,
    }:
    let
      moduleNames = builtins.attrNames (
        lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".nix" name)
          (builtins.readDir hostDir)
      );
      sections = concatLists (
        map (
          moduleName:
          let
            module = import (hostDir + "/${moduleName}") { inherit lib; };
          in
          module.sections or [ ]
        ) moduleNames
      );
    in
    {
      inherit (meta)
        host
        port
        dryRun
        rollbackTimeout
        pruneOrphans
        reloadServices
        ;
      secretFlake = toString self.outPath;
      secretFile = toString (
        builtins.path {
          name = "openwrt-router-config.nix.age";
          path = self + "/${meta.secretFile}";
        }
      );
      secretIdentityFiles = map (entry: toString entry.identity) secretsConfig.masterIdentities;
      configs = lib.mapAttrsToList (configName: secs: {
        name = configName;
        sections = map (section: {
          id = section.id;
          sectionType = section.type;
          name = section.name or null;
          match = section.match or { };
          authoritative = section.authoritative or true;
          weight = section.weight or 0;
          options = section.options or { };
          lists = section.lists or { };
        }) secs;
      }) (lib.groupBy (s: s.config or (throw "openwrt section '${s.id}' is missing `config`")) sections);
    };

in
{
  imports = [
    inputs.nixops4.modules.flake.default
  ];
  flake-file.inputs = {
    nixops4 = {
      url = "github:nixops4/nixops4";
      inputs = {
        flake-parts.follows = "flake-parts";
        nixpkgs.follows = "nixpkgs";
        nix.inputs.flake-parts.follows = "flake-parts";
        nix.inputs.flake-compat.follows = "flake-compat";
        nix-cargo-integration.inputs.parts.follows = "flake-parts";
        nix-cargo-integration.inputs.dream2nix.follows = "dream2nix";
        nix-cargo-integration.inputs.crane.follows = "crane";
        nix-bindings-rust.inputs.nix.inputs.flake-parts.follows = "flake-parts";
        nix-bindings-rust.inputs.nix.inputs.flake-compat.follows =
          "flake-compat";
        nix-bindings-rust.inputs.nix.inputs.nixpkgs-23-11.follows =
          "nixops4/nix/nixpkgs-23-11";
        nix-bindings-rust.inputs.nix.inputs.nixpkgs-regression.follows =
          "nixops4/nix/nixpkgs-regression";
      };
    };
    nixops4-openwrt = {
      url = "github:reo101/nixops4-openwrt";
      inputs = {
        flake-file.follows = "flake-file";
        flake-parts.follows = "flake-parts";
        nixops4.follows = "nixops4";
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
      };
    };
  };

  perSystem =
    { inputs', ... }:
    {
      devShells.openwrt-nixops4 =
        let
          pkgs = inputs'.nixpkgs.legacyPackages;
        in
        pkgs.mkShell {
          packages = [ inputs'.nixops4.packages.default ];
        };
    };

  nixops4 =
    { providers, ... }:
    {
      providers.openwrt = inputs.nixops4-openwrt.modules.nixops4Provider.openwrt;
      members = lib.concatMapAttrs (hostName: hostCfg:
        {
          "${hostName}-router" = {
            type = providers.openwrt.uci_router;
            inputs = mkRouterInputs {
              inherit lib;
              secretsConfig = config.flake.secretsConfig;
              hostDir = "${self}/hosts/openwrt/${hostName}/modules";
              meta = hostCfg.meta.openwrt;
              inherit self;
            };
          };
        }
      ) openwrtHosts;
    };
}
