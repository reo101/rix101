{
  lib,
  writeShellApplication,
  dumbpipe,
  zellij,
  coreutils,
}:

writeShellApplication {
  name = "zellij-iroh";
  runtimeInputs = [
    coreutils
    dumbpipe
    zellij
  ];

  text = builtins.readFile ./zellij-iroh.sh;

  meta = {
    description = "Share Zellij over iroh/dumbpipe";
    homepage = "https://github.com/n0-computer/dumbpipe";
    license = lib.licenses.mit;
    mainProgram = "zellij-iroh";
    maintainers = [ lib.maintainers.reo101 ];
  };
}
