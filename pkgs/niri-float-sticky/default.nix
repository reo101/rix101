{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule {
  pname = "niri-float-sticky";
  version = "0.0.8";

  src = fetchFromGitHub {
    owner = "probeldev";
    repo = "niri-float-sticky";
    rev = "v0.0.8";
    hash = "sha256-iNd10SZgO+DY+VSqTfDYx19SU2styiG7AC+yLwb9yj8=";
  };

  vendorHash = "sha256-GqbY3qkPjMxyW9RTsN9hkgM3Bda6A8rb2kR4YQW1nFI=";

  ldflags = [ "-s" "-w" ];

  meta = {
    description = "Make floating windows sticky across niri workspaces";
    homepage = "https://github.com/probeldev/niri-float-sticky";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.reo101 ];
    mainProgram = "niri-float-sticky";
    platforms = lib.platforms.linux;
  };
}
