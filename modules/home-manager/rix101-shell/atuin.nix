{
  lib,
  dataDir ? null,
  keyPath,
}:

{
  key_path = keyPath;
  auto_sync = true;
  update_check = false;
  sync_address = "https://atuin.jeeves.reo101.xyz";
  sync_frequency = "1m";
  filter_mode = "global";
  secrets_filter = true;
  history_filter = [ "^ " ];
}
// lib.optionalAttrs (dataDir != null) {
  data_dir = dataDir;
}
