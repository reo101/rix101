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
      jeeves = removebg {
        image = pkgs.fetchurl {
          url = "https://www.fractal-design.com/app/uploads/2019/06/Define-R2-XL_BK_2-1440x1440.jpg";
          hash = "sha256-x0kxRVTZT6xBxEtClCyQGxvS/Rs3/iXkbJEl6VHdtdU=";
        };
        fuzz = 1;
      };
      homix = removebg {
        image = pkgs.fetchurl {
          name = "homix.jpg";
          url = "https://pcbuild.bg/assets/products/000/000/209/000000209949--kutiya-nzxt-h510-flow-matte-black.jpeg";
          hash = "sha256-elyj+/MDwoRHVg8usFzQEwuUwRC/0/lY6+f3a50TP+g=";
        };
        fuzz = 10;
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
            connections = [
              (mkConnection "router2" "wan")
              (mkConnection "cheetah" "wwan")
            ];
          } // {
            interfaces."*".network = "internet";
          };
          networks.internet = {
            name = "internet";
            style = {
              primaryColor = "#b87f0d";
              secondaryColor = null;
              pattern = "dashed";
            };
          };

          nodes.router1 = mkSwitch "router1" {
            info = "TP-Link TL-WR740N";
            image = images.TL-WR740N;
            interfaceGroups = [
              ["wan"]
              ["eth1" "eth2" "eth3" "eth4" "wlan"]
            ];
            interfaces.eth1 = {
              addresses = ["192.168.1.150"];
              network = "router2";
              physicalConnections = [(mkConnectionRev "router2" "lan2")];
            };
          };
          # networks.router1 = {
          #   name = "router1";
          #   cidrv4 = "192.168.0.0/24";
          #   style = {
          #     primaryColor = "#b87f0d";
          #     secondaryColor = null;
          #     # one of "solid", "dashed", "dotted"
          #     pattern = "solid";
          #   };
          # };

          nodes.router2 = mkRouter "router2" {
            info = "Zbtlink ZBT-WR8305RT";
            image = images.ZBT-WR8305RT;
            interfaceGroups = [
              ["wan"]
              ["wwan"]
              ["lan1" "lan2" "lan3" "lan4" "wlan"]
            ];
            interfaces.wan = {
              addresses = ["*"];
              network = "internet";
              physicalConnections = [(mkConnectionRev "internet" "*")];
            };
            interfaces.wwan = {
              addresses = ["192.168.33.176"];
              network = "cheetah";
              physicalConnections = [(mkConnectionRev "cheetah" "ap_br_wlan2")];
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
            hardware = {
              image = images.jeeves;
            };
            interfaces.eth0 = {
              addresses = ["192.168.1.210"];
              network = "router2";
              physicalConnections = [(mkConnectionRev "router1" "eth3")];
            };
            interfaces.wlan0 = {
              icon = "interfaces.wifi";
              addresses = ["192.168.1.123"];
              network = "router2";
              physicalConnections = [(mkConnectionRev "router2" "wlan")];
            };
          };
          networks.wg0 = {
            name = "wg0";
            cidrv4 = "10.100.0.0/24";
            style = {
              primaryColor = "#ff0000";
              secondaryColor = null;
              pattern = "dotted";
            };
          };

          nodes.homix = {
            hardware = {
              info = "Gaming PC";
              image = images.homix;
            };
            interfaces.eth0 = {
              addresses = ["192.168.1.141"];
              network = "router2";
              physicalConnections = [(mkConnectionRev "router1" "eth4")];
            };
          };

          nodes.cheetah = {
            deviceType = "device";
            hardware = {
              info = "Google Pixel 7 Pro (cheetah)";
              image = images.cheetah;
            };
            interfaces.wlan1 = {
              icon = "interfaces.wifi";
              addresses = ["192.168.1.240"];
              network = "router2";
              physicalConnections = [(mkConnectionRev "router2" "wlan")];
            };
            interfaces.jeeves = {
              addresses = ["10.100.0.2"];
              network = "wg0";
              physicalConnections = [(mkConnectionRev "jeeves" "wg0")];
            };
            interfaces.wwan = {
              addresses = ["*"];
              network = "internet";
              physicalConnections = [(mkConnectionRev "internet" "*")];
            };
            interfaces.ap_br_wlan2 = {
              addresses = ["192.168.33.254"];
              network = "cheetah";
            };
          };
          networks.cheetah = {
            name = "cheetah";
            cidrv4 = "192.168.33.254/24";
            style = {
              primaryColor = "#fcf403";
              secondaryColor = null;
              pattern = "dashed";
            };
          };
        })
      ];
    };
  };
}
