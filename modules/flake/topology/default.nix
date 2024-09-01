{ lib, config, self, inputs, ... }:

{
  imports = [
    inputs.nix-topology.flakeModule
  ];

  perSystem = { lib, pkgs, system, ... }: let
    removebg = { image, fuzz ? 10, ... }:
      pkgs.runCommand "${image.name}.png" {
        buildInputs = [
          pkgs.imagemagick
        ];
      } ''
        magick ${image} \
          -monitor \
          -bordercolor white \
          -border 1x1 \
          -alpha set \
          -channel RGBA \
          -fuzz ${builtins.toString fuzz}% \
          -fill none \
          -floodfill +0+0 white \
          -shave 1x1 \
          $out
      '';
    images = {
      TL-WR740N = removebg {
        image = pkgs.fetchurl {
          name = "TL-WR740N.jpg";
          url = "https://static.tp-link.com/res/images/products/TL-WR740N_un_V6_1068_large_2_20150807163606.jpg";
          hash = "sha256-/NpnnDh2V015lc3TGzez9eS8rINFtzVbCdN7d85NOt4=";
        };
        fuzz = 15;
      };
      ZBT-WR8305RT = removebg {
        image = pkgs.fetchurl {
          name = "ZBT-WR8305RT.jpg";
          url = "https://vseplus.com/images/p/full/213140a.jpg";
          hash = "sha256-ftTuXaBm99n+y+6fpRf0i63ykDx6xoJgwsQFpu2fNy4=";
        };
        fuzz = 2;
      };
      cheetah = removebg {
        image = pkgs.fetchurl {
          name = "cheetah.jpg";
          url = "https://m.media-amazon.com/images/I/51OFxuD1GgL._AC_SL1000_.jpg";
          hash = "sha256-Lvylh1geh81FZpqK1shj108M217zobWRgR4mEfbvKrc=";
        };
        fuzz = 20;
      };
    };
  in {
    # NOTE: hide from `nix flake show`
    #       requires `allow-import-from-derivation`
    legacyPackages = {
      topology = self.topology.${system}.config.output;
    };

    topology = {
      # nixosConfigurations = {
      #   inherit (self.nixosConfigurations)
      #     jeeves;
      # };
      nixosConfigurations = self.nixosConfigurations;
      modules = [
        ({ config, ... }: let
          inherit (config.lib.topology)
            mkInternet
            mkRouter
            mkSwitch
            mkConnection
            mkConnectionRev
            ;
        in {
          nodes.internet = mkInternet {
            connections = mkConnection "router1" "eth1";
          };

          nodes.router1 = mkRouter "router1" {
            info = "TP-Link TL-WR740N";
            image = images.TL-WR740N;
            interfaceGroups = [
              ["eth1" "eth2" "eth3" "eth4"]
              ["wan1"]
            ];
          };
          networks.router1 = {
            name = "router1";
            cidrv4 = "192.168.0.0/24";
            style = {
              primaryColor = "#b87f0d";
              secondaryColor = null;
              # one of "solid", "dashed", "dotted"
              pattern = "solid";
            };
          };

          nodes.router2 = mkRouter "router2" {
            info = "Zbtlink ZBT-WR8305RT";
            image = images.ZBT-WR8305RT;
            interfaceGroups = [
              ["eth0"]
              ["lan1" "lan2" "lan3" "lan4"]
              ["wan"]
            ];
            interfaces.eth0 = {
              addresses = ["192.168.0.101"];
              network = "router1";
              physicalConnections = [(mkConnectionRev "router1" "eth2")];
            };
          };
          networks.router2 = {
            name = "router2";
            cidrv4 = "192.168.1.0/24";
            style = {
              primaryColor = "#0dd62e";
              secondaryColor = null;
              pattern = "solid";
            };
          };

          nodes.jeeves = {
            interfaces.eth0 = {
              addresses = ["192.168.1.210"];
              network = "router2";
              physicalConnections = [(mkConnectionRev "router2" "lan3")];
            };
            interfaces.wan0 = {
              icon = "interfaces.wifi";
              addresses = ["192.168.1.123"];
              network = "router2";
              physicalConnections = [(mkConnectionRev "router2" "wan")];
            };
          };
          networks.wg0 = {
            name = "wg0";
            cidrv4 = "10.100.0.0/24";
            style = {
              primaryColor = "#ff0000";
              secondaryColor = null;
              pattern = "solid";
            };
          };

          nodes.cheetah = {
            deviceType = "device";
            hardware = {
              info = "Google Pixel 7 Pro (cheetah)";
              image = images.cheetah;
            };
            interfaces.wlan0 = {
              icon = "interfaces.wifi";
              addresses = ["192.168.1.240"];
              network = "router2";
              physicalConnections = [(mkConnectionRev "router2" "wan")];
            };
            interfaces.jeeves = {
              addresses = ["10.100.0.2"];
              network = "wg0";
              physicalConnections = [(mkConnectionRev "jeeves" "wg0")];
            };
          };
        })
      ];
    };
  };
}
