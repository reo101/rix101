{ aspects, ... }:
{
  system = "x86_64-linux";

  aspects = [ aspects.jellyfin ];
  users.reo101.aspects = [ aspects.riverWorkstation ];
}
