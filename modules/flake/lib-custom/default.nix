{
  inputs,
  self,
  lib,
  config,
  ...
}:

{
  key = "rix101.modules.flake.lib-custom";

  imports = [
    ../lib
  ];

  config.flake-file.inputs = {
    nix-lib-net = {
      url = "github:reo101/nix-lib-net";
    };

    yants = {
      url = "git+https://code.tvl.fyi/depot.git:/nix/yants.git";
      flake = false;
    };

    contracts = {
      url = "github:yvan-sraka/contracts";
      # WARN: is technically a flake, exposing the `default.nix` under `nixosModules.default`
      flake = false;
    };

    infuse = {
      url = "git+https://codeberg.org/amjoseph/infuse.nix";
      flake = false;
    };

    alloc = {
      url = "github:Aleksanaa/alloc.nix";
      flake = false;
    };

    htnl = {
      url = "github:molybdenumsoftware/htnl";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.systems.follows = "systems";
      inputs.flake-parts.follows = "flake-parts";
      inputs.dedupe_flake-compat.follows = "flake-compat";
      inputs.git-hooks.inputs.flake-compat.follows = "flake-compat";
      inputs.git-hooks.inputs.gitignore.follows = "gitignore";
      inputs.treefmt-nix.follows = "treefmt-nix";
    };

    nix-optics = {
      url = "github:reo101/nix-optics?ref=feat/indexed";
    };
  };

  config.lib-overlays = [
    inputs.nix-lib-net.overlays.raw
    # Yants
    (final: prev: {
      yants = import "${inputs.yants.outPath}/default.nix" { lib = prev; };
    })
    # Contracts
    (final: prev: {
      contracts = import "${inputs.contracts.outPath}/default.nix" { enable = true; };
    })
    # Infuse
    (
      final: prev:
      let
        infuse = (
          import "${inputs.infuse.outPath}/default.nix" {
            lib = prev;
            sugars =
              infuse.v1.default-sugars
              ++ lib.attrsToList {
                __concatStringsSep =
                  path: infusion: target:
                  lib.strings.concatStringsSep infusion target;
                __filter =
                  path: infusion: target:
                  builtins.filter infusion target;
                __map =
                  path: infusion: target:
                  lib.map infusion target;
                __swapOutPackage =
                  path: infusion: target:
                  let
                    # TODO: more validation
                    infusion-name = infusion.pname or infusion.name or "";
                  in
                  lib.map (
                    pkg:
                    let
                      pkg-name = pkg.pname or pkg.name or "";
                      nonempty = pkg-name != "";
                    in
                    if nonempty && pkg-name == infusion-name then infusion else pkg
                  ) target;
              };
          }
        );
      in
      {
        inherit (infuse.v1) infuse;
      }
    )
    # Alloc
    (final: prev: {
      alloc = import "${inputs.alloc.outPath}/default.nix" { lib = prev; };
    })
    # Htnl
    (final: prev: {
      htnl =
        let
          base = import "${inputs.htnl.outPath}/default.nix" { inherit lib; };
        in
        base
        // {
          bundle =
            pkgs:
            pkgs.callPackage "${inputs.htnl.outPath}/bare/bundle.nix" {
              htnl = base;
            };
        };
    })
    # Optics
    (final: prev: {
      optics = import "${inputs.nix-optics.outPath}/default.nix";
    })
  ];

  config.lib =
    let
      cs = config.lib.contracts;

      recurseDirContracts = rec {
        NixFileEntry = cs.declare { name = "NixFileEntry"; } {
          _type = x: x == "nix";
          path = cs.Str;
          content = cs.Any;
        };

        DirectoryEntry = cs.declare { name = "DirectoryEntry"; } {
          _type = x: x == "directory";
          content = cs.setOf RecurseDirEntry;
        };

        OtherFileEntry = cs.declare { name = "OtherFileEntry"; } {
          _type = cs.Str;
          content = cs.Str;
        };

        RecurseDirEntry = cs.declare { name = "RecurseDirEntry"; } (
          e:
          let
            handler =
              {
                "nix" = NixFileEntry;
                "directory" = DirectoryEntry;
              }
              .${e._type} or OtherFileEntry;
          in
          handler e
        );

        RecurseDirResult = cs.setOf RecurseDirEntry;

        ConfigurationArgs = cs.declare { name = "ConfigurationArgs"; } {
          meta = cs.Set;
          configurationFiles = cs.Set;
        };

        ExtractedNixFile = cs.declare { name = "ExtractedNixFile"; } {
          path = cs.Str;
          content = cs.Any;
        };
      };
    in
    rec {
      # Secrets Helpers
      repoSecret = lib.path.append ../../../secrets/master;

      # Boolean helpers
      and = lib.all lib.id;
      eq = x: y: x == y;

      # Directory walking helpers
      inherit recurseDirContracts;

      recurseDir =
        dir:
        lib.pipe dir [
          builtins.readDir
          (lib.mapAttrs (
            file: type:
            let
              # Causes individual files to be sent to the store
              # newPath = lib.path.append dir file;
              newPath = "${dir}/${file}";
            in
            if
              and [
                (type == "directory")
              ]
            then
              cs.is recurseDirContracts.DirectoryEntry {
                _type = "directory";
                content = recurseDir newPath;
              }
            else if
              and [
                (type == "regular")
                (lib.strings.hasSuffix ".nix" file)
              ]
            then
              cs.is recurseDirContracts.NixFileEntry {
                _type = "nix";
                path = newPath;
                content = import newPath;
              }
            else
              cs.is recurseDirContracts.OtherFileEntry {
                _type = type;
                content = newPath;
              }
          ))
        ];

      allSatisfy =
        predicate: attrs: attrset:
        lib.all (
          attr:
          and [
            (builtins.hasAttr attr attrset)
            (predicate (builtins.getAttr attr attrset))
          ]
        ) attrs;

      # NOTE: Implying last argument is the output of `recurseDir`
      hasNixFiles = allSatisfy (file: file._type == "nix");

      # NOTE: Implying last argument is the output of `recurseDir`
      hasDirectories = allSatisfy (file: file._type == "directory");

      # NOTE: Implying `files` is the output of `recurseDir`
      extract =
        {
          files,
          path,
          pred,
          default ? null,
          transform ? file: { inherit (file) content; },
        }:
        lib.pipe files [
          (lib.attrByPath
            (lib.intersperse "content"
              # NOTE: turn single strings into a path list
              (lib.toList path)
            )
            # ~FIXME~: `null` may be be `content` of a real Nix file
            null
          )
          # Now is either a { _type = "..."; ... } or a null
          (file: if file == null || !(pred file) then default else transform file)
          # Same, but now always a nix file if not null
        ];

      extractNixFile =
        files: path:
        let
          result = extract {
            inherit files path;
            pred = file: file._type == "nix";
            transform = file: { inherit (file) path content; };
          };
        in
        cs.contract { name = "extractNixFile result"; } (cs.enum [
          recurseDirContracts.ExtractedNixFile
          cs.Null
        ]) result;

      extractDirectory =
        files: path:
        let
          result = extract {
            inherit files path;
            pred = file: file._type == "directory";
            default = { };
            transform = dir: dir.content;
          };
        in
        cs.contract { name = "extractDirectory result"; } cs.Set result;

      camelToKebab = lib.stringAsChars (c: if c == lib.toUpper c then "-${lib.toLower c}" else c);

      # NOTE: adapted from Tweag's Nix Hour 76 - <https://github.com/tweag/nix-hour/blob/c4fd0f2fc3059f057571bbfd74f3c5e4021f526c/code/76/default.nix#L4-L22>
      mutFirstChar =
        f: s:
        let
          firstChar = f (lib.substring 0 1 s);
          rest = lib.substring 1 (-1) s;
        in
        firstChar + rest;

      kebabToCamel = lib.flip lib.pipe [
        (lib.splitString "-")
        (lib.concatMapStrings (mutFirstChar lib.toUpper))
        (mutFirstChar lib.toLower)
      ];
      # s:
      # mutFirstChar
      #   lib.toLower
      #     (lib.concatMapStrings
      #       (mutFirstChar lib.toUpper)
      #       (lib.splitString "-" s));

      uci = lib.makeExtensible (self: {
        escape = value: lib.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] (toString value);

        quote = value: "\"${self.escape value}\"";

        set = key: value: "set ${key}=${self.quote value}";

        setRaw = key: value: "set ${key}=${toString value}";

        delete = key: "delete ${key}";

        addList = key: value: "add_list ${key}=${self.quote value}";

        commit = package: "commit ${package}";

        renderBatch = lines: lib.concatStringsSep "\n" lines;
      });

      # OpenWrt imagebuilder glue shared by every `hosts/openwrt` host.
      # Takes `pkgs` (hosts get it at their per-system level); everything else
      # comes from the global `lib` (via `uci` above).
      openwrt =
        pkgs:
        let
          inherit (uci)
            set
            setRaw
            delete
            addList
            commit
            renderBatch
            ;

          sshAuthorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL5ibKzd+V2eR1vmvBAfSWcZmPB8zUYFMAN3FS6xY9ma"
          ];
        in
        {
          inherit sshAuthorizedKeys;

          defaultPackages = [
            "luci" # https://github.com/astro/nix-openwrt-imagebuilder/issues/53
            "luci-ssl"
          ];

          # Baseline system/ntp/dropbear/uhttpd lines shared by all hosts
          baselineLines =
            {
              hostname ? "OpenWrt",
              timezone ? "Europe/Sofia",
              redirect_https ? "0",
            }:
            [
              # System
              (set "system.@system[0].hostname" hostname)
              (set "system.@system[0].timezone" "EET-2EEST,M3.5.0/3,M10.5.0/4")
              (set "system.@system[0].zonename" timezone)
              (set "system.@system[0].log_proto" "udp")
              (set "system.@system[0].conloglevel" "8")
              (set "system.@system[0].cronloglevel" "5")
              (delete "system.ntp.server")
            ]
            # NTP pool
            ++ lib.genList (n: addList "system.ntp.server" "${builtins.toString n}.openwrt.pool.ntp.org") 4
            ++ [
              (set "uhttpd.main.redirect_https" redirect_https)
            ];

          # dropbear hardening: applied on top of whatever secret config exists
          dropbearBaseline = {
            PasswordAuth = "off";
            RootPasswordAuth = "off";
          };

          dropbearLines = dropbearConfig:
            lib.mapAttrsToList
              (key: value: set "dropbear.@dropbear[0].${key}" value)
              dropbearConfig;

          # Given a set of hostname-keyed UCI sections, emit `set <pkg>.<prefix><name> <type>`
          # plus one `set` per attribute. Attribute values are strings.
          buildNamedSectionLines =
            {
              package,
              sectionType,
              entries,
              prefix ? "",
            }:
            lib.concatMap
              (name: let
                sectionName = "${prefix}${name}";
              in
              [
                (setRaw "${package}.${sectionName}" sectionType)
              ]
              ++ lib.mapAttrsToList
                (key: value: set "${package}.${sectionName}.${key}" (toString value))
                (entries.${name} or { }))
              (builtins.attrNames entries);

          # Primary radio + default_<radio> iface pairs
          wirelessPrimaryLines = wirelessNetworks:
            lib.concatMap
              (radio: let
                cfg = wirelessNetworks.${radio};
              in
              (lib.mapAttrsToList
                (key: value: set "wireless.${radio}.${key}" value)
                (cfg.radio or { }))
              ++ (lib.mapAttrsToList
                (key: value: set "wireless.default_${radio}.${key}" value)
                (cfg.iface or { })))
              (builtins.attrNames wirelessNetworks);

          # Extra named wifi-iface sections: `__type` selects the section type
          wirelessExtraIfaceLines = wirelessExtraIfaces:
            lib.concatMap
              (ifaceName: let
                ifaceConfig = wirelessExtraIfaces.${ifaceName};
                sectionType = ifaceConfig.__type or "wifi-iface";
                attrs = lib.removeAttrs ifaceConfig [ "__type" ];
              in
              [
                (setRaw "wireless.${ifaceName}" sectionType)
              ]
              ++ lib.mapAttrsToList
                (key: value: set "wireless.${ifaceName}.${key}" value)
                attrs)
              (builtins.attrNames wirelessExtraIfaces);

          # Commit the managed packages
          commitLines = packages: lib.map (commit) packages;

          # Image `files`: dropbear authorized_keys + first-boot uci-defaults script
          mkImageFiles =
            {
              uciBatchLines,
              extraImageCommands ? "",
            }:
            pkgs.runCommand "image-files" { } ''
              mkdir -p $out/etc/dropbear
              echo "${lib.concatStringsSep "\n" sshAuthorizedKeys}" > $out/etc/dropbear/authorized_keys

              mkdir -p $out/etc/uci-defaults
              cat > $out/etc/uci-defaults/99-custom <<'SCRIPT'
              #!/usr/bin/env ash
              set -eu

              uci -q batch <<'UCI'
              ${renderBatch uciBatchLines}
              UCI

              ${extraImageCommands}
              SCRIPT
              chmod +x $out/etc/uci-defaults/99-custom
            '';
        };

      timestampIso =
        let
          # HACK: want to use `lib` directly
          inherit (config.lib) optics;
          to = lib.flip lib.pipe [
            (builtins.match (
              let
                digit = "[[:digit:]]";
                non-digit = "[^[:digit:]]";
                sep = "${non-digit}?";
                times =
                  what: n: more:
                  let
                    sn = builtins.toString n;
                  in
                  "${what}{${sn},${lib.optionalString (!more) sn}}";
              in
              lib.concatStrings [
                # year
                "(${times digit 1 true})"
                # year-month sep
                "(${sep})"
                # month
                "(${times digit 2 false})"
                # month-day sep
                "(${sep})"
                # day
                "(${times digit 2 false})"
                # date-time sep
                "(${sep})"
                # hour
                "(${times digit 2 false})"
                # hour-minute sep
                "(${sep})"
                # minute
                "(${times digit 2 false})"
                # minute-second sep
                "(${sep})"
                # second
                "(${times digit 2 false})"
              ]
            ))
            (lib.mapNullable (
              m:
              let
                parseInt =
                  s: lib.mapNullable (n: builtins.fromJSON (builtins.head n)) (builtins.match "0*([[:digit:]]+)" s);
                # NOTE: parse all numbers, at even positions
                pm = optics.over (optics.compose [
                  optics.ieach
                  (optics.ifiltered (i: _: lib.mod i 2 == 0))
                ]) parseInt m;
                year = builtins.elemAt pm 0;
                sep1 = builtins.elemAt pm 1;
                month = builtins.elemAt pm 2;
                sep2 = builtins.elemAt pm 3;
                day = builtins.elemAt pm 4;
                sep3 = builtins.elemAt pm 5;
                hour = builtins.elemAt pm 6;
                sep4 = builtins.elemAt pm 7;
                minute = builtins.elemAt pm 8;
                sep5 = builtins.elemAt pm 9;
                second = builtins.elemAt pm 10;
              in
              {
                date = {
                  inherit
                    year
                    month
                    day
                    ;
                };
                time = {
                  inherit
                    hour
                    minute
                    second
                    ;
                };
                # NOTE: as per RFC3339, Section 5.6
                separators = {
                  date =
                    assert sep1 == sep2;
                    sep1;
                  date-time = sep3;
                  time =
                    assert sep4 == sep5;
                    sep4;
                };
              }
            ))
          ];
          from =
            self:
            let
              # NOTE: stringify all numbers
              dt = optics.iover (optics.compose [
                optics.ieach
                (optics.ifiltered (class: _: class != "separators"))
                optics.ieach
              ]) (key: if key == "year" then builtins.toString else lib.fixedWidthNumber 2) self;
            in
            lib.concatStringsSep dt.separators.date-time [
              (lib.concatStringsSep dt.separators.date [
                dt.date.year
                dt.date.month
                dt.date.day
              ])
              (lib.concatStringsSep dt.separators.time [
                dt.time.hour
                dt.time.minute
                dt.time.second
              ])
            ];
        in
        optics.iso to from;
    };
}
