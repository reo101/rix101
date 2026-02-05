{
  ...
}:
{
  boot.binfmt = {
    emulatedSystems = [
      "aarch64-linux"
      "armv7l-linux"
    ];

    preferStaticEmulators = true;
  };
}
