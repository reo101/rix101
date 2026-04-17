{
  description = "Expose the shared battery notification service module";

  nixos.modules = [
    "battery-notify"
  ];
}
