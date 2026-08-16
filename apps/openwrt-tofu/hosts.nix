# Render every tofu-managed OpenWrt host into the JSON consumed by this app:
#
#   nix run .#openwrt-tofu -- .#asus_tuf-ax4200 plan
{
  terranix,
  lib,
  pkgs,
  ...
}:
let
  terranixCore = import "${terranix}/core";

  # /etc/config/system in UCI file format, from a small attrset.
  # `ntp` = null omits the timeserver block entirely (e.g. APs).
  renderSystemUci =
    {
      hostname,
      timezone,
      zonename,
      ntp,
      logProto ? "udp",
      conlogLevel ? "8",
      cronlogLevel ? "5",
      ttylogin ? "0",
      logSize ? "64",
    }:
    lib.concatStringsSep "\n" ([
      "config system"
      "\toption hostname '${hostname}'"
      "\toption timezone '${timezone}'"
      "\toption ttylogin '${ttylogin}'"
      "\toption log_size '${logSize}'"
      "\toption urandom_seed '0'"
      "\toption zonename '${zonename}'"
      "\toption log_proto '${logProto}'"
      "\toption conloglevel '${conlogLevel}'"
      "\toption cronloglevel '${cronlogLevel}'"
    ]
    ++ lib.optional (ntp != null) (
      "\n\nconfig timeserver 'ntp'\n"
      + "\toption enabled '1'\n"
      + "\toption enable_server '0'\n"
      + lib.concatStringsSep "\n" (map (s: "\tlist server '${s}'") ntp)
    ));

  # terraform JSON for one host (rendered as a string, embedded in the file)
  renderTfJson = hostCfg:
    let
      tfConfig = terranixCore {
        inherit pkgs;
        modules = [
          (
            { ... }:
            {
              terraform.required_providers.openwrt = {
                source = "registry.terraform.io/foxboron/openwrt";
              };
              provider.openwrt = {
                user = hostCfg.user or "root";
                remote = hostCfg.remote;
              };
              resource.openwrt_configfile.system = {
                name = "system";
                content = renderSystemUci hostCfg.system;
              };
            }
          )
        ];
      };
    in
    builtins.toJSON tfConfig.config;

  hostsDir = ../../hosts/openwrt;
  hosts =
    lib.pipe (builtins.readDir hostsDir) [
      lib.attrNames
      (map (
        name:
        let
          meta = lib.optionalAttrs (lib.pathExists (hostsDir + "/${name}/meta.nix")) (import (hostsDir + "/${name}/meta.nix"));
        in
        {
          inherit name;
          openwrt = meta.openwrt or null;
        }
      ))
      (lib.filter (h: h.openwrt != null))
      (map (
        h:
        lib.nameValuePair h.name {
          remote = h.openwrt.remote;
          user = h.openwrt.user or "root";
          # repoSecret deliberately errors at eval when the age file
          # isn't staged yet — the error is the reminder to commit it
          secret = lib.custom.repoSecret h.openwrt.secret;
          content = renderTfJson h.openwrt;
        }
      ))
      lib.listToAttrs
    ];
in
pkgs.writeText "openwrt-hosts.json" (builtins.toJSON hosts)