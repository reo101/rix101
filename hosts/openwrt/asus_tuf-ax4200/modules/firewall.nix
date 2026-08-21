# Firewall site policy is secret-bearing and is supplied exclusively by the
# encrypted runtime router document. Base-image rules remain untouched until
# NixOps4 adopts the WAN zone and redirect sections.
{ ... }:

{
  opLines = [ ];
  sections = [ ];
}
