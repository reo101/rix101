# If pkgs is not defined, instanciate nixpkgs from locked commit
{ pkgs ? (import ../nixpkgs.nix) { }
, inputs
, outputs
, ...
}: {
  default = import ./default { inherit pkgs inputs outputs; };
}
