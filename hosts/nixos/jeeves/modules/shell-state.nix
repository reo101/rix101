{ ... }:

{
  systemd.tmpfiles.settings."rix101-shell-state" = {
    "/var/lib/rix101-shell".d = {
      mode = "0755";
    };
    "/var/lib/rix101-shell/jeeves".d = {
      user = "jeeves";
      group = "users";
      mode = "0700";
    };
    "/var/lib/rix101-shell/jeeves/atuin".d = {
      user = "jeeves";
      group = "users";
      mode = "0700";
    };
    "/var/lib/rix101-shell/jeeves/zsh".d = {
      user = "jeeves";
      group = "users";
      mode = "0700";
    };
  };
}
