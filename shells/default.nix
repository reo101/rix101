# If pkgs is not defined, instanciate nixpkgs from locked commit
{ pkgs ? (import ../nixpkgs.nix) { }
, inputs
, ...
}: {
  default = import ./default { inherit pkgs inputs; };
}
