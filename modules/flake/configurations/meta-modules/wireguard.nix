{ config, lib, ... }:

let
  inherit (lib) types;
  metaConfig = config;
  wgKey = types.strMatching "[A-Za-z0-9+/]{43}=";
  readPubkey =
    host:
    let
      path = lib.custom.repoSecret "home/${host}/wireguard/key.pub";
    in
    if builtins.pathExists path then
      lib.trim (builtins.readFile path)
    else
      builtins.throw "No WireGuard public key for '${host}' at ${toString path}; either generate the key or set `publicKey` explicitly";
in
{
  options = {
    wireguardServer = lib.mkOption {
      description = "WireGuard server peer configuration";
      default = null;
      type = types.nullOr (
        types.submodule (
          { config, options, ... }:
          {
            options = {
              cidr = lib.mkOption {
                type = types.net.cidrv4;
                description = "Network CIDR for the WireGuard mesh";
                default = "10.100.0.0/24";
              };
              publicKey = lib.mkOption {
                type = wgKey;
                default = readPubkey metaConfig.hostname;
                defaultText = lib.literalExpression "readPubkey config.hostname";
                description = "WireGuard public key of the server. Defaults to reading home/<hostname>/wireguard/key.pub from repo secrets.";
              };
              ip = lib.mkOption {
                type = types.net.ipv4;
                readOnly = true;
                default = config.peers.self.ip;
                defaultText = lib.literalExpression "config.peers.self.ip";
                description = "Resolved IP address of the server (sugar for peers.self.ip)";
              };
              endpoint = lib.mkOption {
                type = types.str;
                description = "Server endpoint (host:port)";
              };
              peers = lib.mkOption {
                type = types.attrsOf (
                  types.submodule (
                    { name, ... }:
                    {
                      options = {
                        publicKey = lib.mkOption {
                          type = wgKey;
                          default = readPubkey name;
                          defaultText = lib.literalExpression "readPubkey <peerName>";
                          description = "WireGuard public key of the peer. Defaults to reading home/<peerName>/wireguard/key.pub from repo secrets.";
                        };
                        hostIndex = lib.mkOption {
                          type = types.nullOr types.int;
                          default = null;
                          description = "Static host index in the CIDR (e.g. 5 for .5). null = auto-assign.";
                        };
                      };
                    }
                  )
                );
                default = { };
                description = "Mapping of hostname to peer configuration";
                apply =
                  peers:
                  assert lib.assertMsg (!(peers ? self)) (
                    let
                      selfDefs = lib.filter (def: def.value ? self) options.peers.definitionsWithLocations;
                    in
                    "wireguardServer.peers: 'self' is a reserved peer name; it is injected automatically for the server"
                    + lib.concatMapStrings (def: "\n  - defined in `${def.file}`") selfDefs
                  );
                  let
                    blocks = lib.mapAttrs (
                      _host: peer:
                      if peer.hostIndex != null then
                        {
                          start = peer.hostIndex;
                          length = 1;
                        }
                      else
                        { length = 1; }
                    ) peers;
                    capacity = lib.net.cidr.capacity config.cidr;
                    firstPeerIndex = 2; # `.0` -> network, `.1` -> server
                    allocated = lib.alloc firstPeerIndex (capacity - firstPeerIndex) blocks;
                    autoAllocated = lib.filterAttrs (host: _: !(blocks.${host} ? start)) allocated;
                    autoAllocatedWarning =
                      "wireguardServer.peers: auto-allocated WireGuard `hostIndex` values for `${metaConfig.hostname}`: "
                      + lib.pipe autoAllocated [
                        (lib.mapAttrsToList (
                          host: block: "${host}=${toString block.start} (${lib.net.cidr.host block.start config.cidr})"
                        ))
                        (lib.concatStringsSep ", ")
                      ]
                      + ". Add explicit `hostIndex` values for these peers to the static `meta.nix` to keep assignments stable.";
                    resolvedPeers =
                      lib.mapAttrs (
                        host: peer:
                        let
                          index = allocated.${host}.start;
                        in
                        peer
                        // {
                          hostIndex = index;
                          ip = lib.net.cidr.host index config.cidr;
                        }
                      ) peers
                      // {
                        self = {
                          publicKey = config.publicKey;
                          hostIndex = 1;
                          ip = lib.net.cidr.host 1 config.cidr;
                        };
                      };
                  in
                  lib.warnIf (autoAllocated != { }) autoAllocatedWarning resolvedPeers;
              };
            };
          }
        )
      );
    };
  };
}
