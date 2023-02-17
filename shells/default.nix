# If pkgs is not defined, instanciate nixpkgs from locked commit
{ pkgs ? (import ../nixpkgs.nix) { }
, ...
}: {
  default = import ./default { inherit pkgs; };
}
