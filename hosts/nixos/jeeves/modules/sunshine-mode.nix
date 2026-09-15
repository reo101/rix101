{ lib, pkgs, niriMsg, sunshineUser, virtualDisplayPort }:

pkgs.writeShellScript "sunshine-mode" ''
  set -eu
  width="''${SUNSHINE_CLIENT_WIDTH:-1920}"
  height="''${SUNSHINE_CLIENT_HEIGHT:-1080}"
  refresh="''${SUNSHINE_CLIENT_FPS:-144}"

  case "$width:$height:$refresh" in
    *[!0-9:]* | :* | *: | *::* | *:*:*:*) width=1920; height=1080; refresh=144 ;;
    *) ;;
  esac
  case "$width:$height:$refresh" in
    0:* | *:0:* | *:*:0) width=1920; height=1080; refresh=144 ;;
  esac

  # Apply per-game fixes before launching Steam.
  ${lib.getExe pkgs.nushell} --no-config-file ${./game-fixes.nu} "$width" "$height" \
    "/home/${sunshineUser}/.local/share/SlayTheSpire2"

  mode_file="/run/user/$(id -u)/sunshine-client-mode"
  umask 077
  printf 'width=%s\nheight=%s\nrefresh=%s\n' "$width" "$height" "$refresh" > "$mode_file"
  ${niriMsg} output ${virtualDisplayPort} on
  ${niriMsg} output ${virtualDisplayPort} custom-mode "''${width}x''${height}@''${refresh}"
  ${niriMsg} output ${virtualDisplayPort} scale 1
''
