# shellcheck shell=bash
set -eu

usage() {
  cat <<EOF
usage:
  zellij-iroh host [SESSION]
  zellij-iroh join TICKET
EOF
}

shell_quote() {
  local quoted
  quoted=${1//\'/\'\\\'\'}
  printf "'%s'" "$quoted"
}

invite_ticket() {
  printf 'zellij-iroh-v1:%s:%s:%s' "$3" "$2" "$1"
}

print_invite() {
  local ticket ticket_quoted
  ticket="$(invite_ticket "$1" "$2" "$3")"
  ticket_quoted="$(shell_quote "$ticket")"
  cat <<EOF
Share this Zellij session:

  zellij-iroh join $ticket_quoted

Raw dumbpipe ticket (debug; not for join):
  $1

EOF
}

validate_session() {
  case "$1" in
    ''|*[!A-Za-z0-9._-]*)
      cat >&2 <<EOF
Invalid session name: '$1'
Use only letters, numbers, dot, underscore, and dash.
EOF
      exit 2
      ;;
  esac
}

validate_token() {
  case "$1" in
    ????????-????-????-????-????????????) ;;
    *) return 1 ;;
  esac
}

invite_shell() {
  local shell
  shell="${ZELLIJ_IROH_REAL_SHELL:-${SHELL:-sh}}"
  if ! mkdir "$ZELLIJ_IROH_INVITE_ONCE" 2>/dev/null; then
    unset ZELLIJ_IROH_INVITE_SHELL ZELLIJ_IROH_REAL_SHELL ZELLIJ_IROH_INVITE_ONCE
    export SHELL="$shell"
    exec "$shell"
  fi

  print_invite "$ZELLIJ_IROH_TICKET" "$ZELLIJ_IROH_TOKEN" "$ZELLIJ_IROH_SESSION"
  unset ZELLIJ_IROH_INVITE_SHELL ZELLIJ_IROH_REAL_SHELL ZELLIJ_IROH_INVITE_ONCE
  export SHELL="$shell"
  exec "$shell"
}

ticket_from_file() {
  local line
  while IFS= read -r line; do
    case "$line" in
      *" endpoint"*) printf '%s\n' "${line##* }"; return 0 ;;
    esac
  done < "$1"
  return 1
}

wait_for_ticket() {
  local file pid
  file="$1"
  pid="$2"
  for _ in $(seq 1 100); do
    [ -n "$(ticket_from_file "$file" || true)" ] && return 0
    kill -0 "$pid" 2>/dev/null || return 1
    sleep 0.1
  done
  return 1
}

wait_for_tcp() {
  local addr pid host port
  addr="$1"
  pid="$2"
  host="${addr%:*}"
  port="${addr##*:}"
  for _ in $(seq 1 100); do
    (: >"/dev/tcp/$host/$port") >/dev/null 2>&1 && return 0
    kill -0 "$pid" 2>/dev/null || return 1
    sleep 0.1
  done
  return 1
}

free_local_addr() {
  local port
  port="$1"
  while (: >"/dev/tcp/127.0.0.1/$port") >/dev/null 2>&1; do
    port=$((port + 1))
  done
  printf '127.0.0.1:%s\n' "$port"
}

cleanup() {
  [ "${web_port:-}" ] && zellij web --stop --port "$web_port" >/dev/null 2>&1 || true
  [ "${pipe_pid:-}" ] && kill "$pipe_pid" 2>/dev/null || true
  [ "${tmp:-}" ] && rm -rf "$tmp"
}

trap_exit() {
  local code
  code="$1"
  trap - EXIT INT TERM
  cleanup
  exit "$code"
}

if [ "${ZELLIJ_IROH_INVITE_SHELL:-}" = 1 ]; then
  invite_shell
fi

cmd="${1:-}"
case "$cmd" in
  host)
    if [ "$#" -gt 2 ]; then
      usage >&2
      exit 2
    fi
    session="${2:-iroh}"
    validate_session "$session"
    web_addr="$(free_local_addr "${ZELLIJ_IROH_WEB_PORT:-8082}")"
    web_port="${web_addr##*:}"
    tmp="$(mktemp -d)"
    trap cleanup EXIT
    trap 'trap_exit 130' INT
    trap 'trap_exit 143' TERM

    token_output="$(zellij web --create-token)"
    token="${token_output##*: }"
    if ! validate_token "$token"; then
      printf 'Could not parse Zellij auth token:\n%s\n' "$token_output" >&2
      exit 1
    fi

    zellij web --daemonize --ip "${web_addr%:*}" --port "$web_port" >/dev/null
    if ! wait_for_tcp "$web_addr" "$$"; then
      printf 'Timed out waiting for zellij web on %s\n' "$web_addr" >&2
      exit 1
    fi

    ticket_file="$tmp/ticket"
    dumbpipe listen-tcp --host "$web_addr" 2>"$ticket_file" &
    pipe_pid=$!
    if ! wait_for_ticket "$ticket_file" "$pipe_pid"; then
      cat "$ticket_file" >&2 || true
      exit 1
    fi
    ticket="$(ticket_from_file "$ticket_file")"

    case "$0" in
      */*) self="$(realpath "$0")" ;;
      *) self="$(command -v "$0")" ;;
    esac
    print_invite "$ticket" "$token" "$session"

    real_shell="${SHELL:-sh}"
    env \
      ZELLIJ_IROH_INVITE_SHELL=1 \
      ZELLIJ_IROH_SESSION="$session" \
      ZELLIJ_IROH_TICKET="$ticket" \
      ZELLIJ_IROH_TOKEN="$token" \
      ZELLIJ_IROH_REAL_SHELL="$real_shell" \
      ZELLIJ_IROH_INVITE_ONCE="$tmp/invite-shown" \
      SHELL="$self" \
      zellij --session "$session" options --web-sharing on
    ;;
  join)
    if [ "$#" -ne 2 ]; then
      usage >&2
      exit 2
    fi
    case "$2" in
      zellij-iroh-v1:*) ;;
      *)
        cat >&2 <<EOF
usage: zellij-iroh join TICKET

Use the full ticket printed by 'zellij-iroh host', not the raw dumbpipe ticket.
EOF
        exit 2
        ;;
    esac

    rest="${2#zellij-iroh-v1:}"
    session="${rest%%:*}"
    rest="${rest#*:}"
    token="${rest%%:*}"
    ticket="${rest#*:}"
    validate_session "$session"
    if ! validate_token "$token" || [ -z "$ticket" ] || [ "$ticket" = "$token" ]; then
      printf 'Invalid zellij-iroh ticket\n' >&2
      exit 2
    fi

    tmp="$(mktemp -d)"
    trap cleanup EXIT
    trap 'trap_exit 130' INT
    trap 'trap_exit 143' TERM

    addr="$(free_local_addr "${ZELLIJ_IROH_LOCAL_PORT:-18082}")"

    dumbpipe connect-tcp --addr "$addr" "$ticket" 2>"$tmp/dumbpipe.log" &
    pipe_pid=$!
    if ! wait_for_tcp "$addr" "$pipe_pid"; then
      cat "$tmp/dumbpipe.log" >&2 || true
      exit 1
    fi

    zellij attach --token "$token" "http://$addr/$session"
    ;;
  *)
    usage
    exit 2
    ;;
esac
