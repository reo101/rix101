{ pkgs, ... }:
{
  services.printing = {
    enable = true;
    drivers = [
      pkgs.hplipWithPlugin
    ];
  };

  services.avahi = {
    enable = true;
    openFirewall = true;
    nssmdns4 = true;
  };

  hardware.printers = {
    ensureDefaultPrinter = "HP_LaserJet_M110";
    ensurePrinters = [
      {
        name = "HP_LaserJet_M110";
        description = "HP LaserJet M110";
        location = "Home";
        deviceUri = "ipp://printer.lan/ipp/print";
        model = "everywhere";
        ppdOptions = {
          PageSize = "A4";
        };
      }
    ];
  };

  # CUPS printer queue state, PPD cache, and job history
  environment.persistence."/persist".directories = [
    "/var/lib/cups"
  ];
}
