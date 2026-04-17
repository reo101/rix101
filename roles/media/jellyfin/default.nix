{
  description = "Expose the shared Jellyfin NixOS module";

  nixos.modules = [
    "jellyfin"
  ];
}
