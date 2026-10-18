{ aspects, ... }:
{
  system = "x86_64-darwin";
  users.pavelatanasov.aspects = [ aspects.darwinWorkstation ];
  enable = false;
}
