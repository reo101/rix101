#!/usr/bin/env bash

set -euo pipefail

case "${1:-sh}" in
    sh) helper=(bash "$(dirname "$0")/rage-decrypt-and-cache.sh") ;;
    nu) helper=(nu "$(dirname "$0")/rage-decrypt-and-cache.nu") ;;
    *) echo "usage: $0 [sh|nu]" >&2; exit 64 ;;
esac

tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin"
printf 'fixture\n' > "$tmp/secret.nix.age"

cat > "$tmp/bin/rage" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

out=""
while (($#)); do
    case "$1" in
        -d) shift ;;
        -i | -o)
            [[ "$1" == -o ]] && out="$2"
            shift 2
            ;;
        *) shift ;;
    esac
done

printf '.\n' >> "$RAGE_CALLS"
sleep 0.1
case "${RAGE_MODE:-success}" in
    success) printf '{ value = 1; }\n' > "$out" ;;
    empty) : > "$out" ;;
    fail) exit 42 ;;
esac
EOF
chmod +x "$tmp/bin/rage"
export PATH="$tmp/bin:$PATH" RAGE_CALLS="$tmp/calls"

run_parallel() {
    local cache="$1" mode="$2" expected="$3"
    local -a pids=()
    local status

    : > "$RAGE_CALLS"
    for _ in {1..8}; do
        NIX_ENRAGED_CACHE_DIR="$cache" RAGE_MODE="$mode" "${helper[@]}" --print-out-path "$tmp/secret.nix.age" >/dev/null 2>&1 &
        pids+=("$!")
    done
    for pid in "${pids[@]}"; do
        set +e
        wait "$pid"
        status=$?
        set -e
        [[ "$status" == "$expected" ]] || exit 1
    done
    [[ "$(wc -l < "$RAGE_CALLS")" == 1 ]] || exit 1
}

run_parallel "$tmp/success" success 0
[[ "$(find "$tmp/success" -name '*.tmp.*' | wc -l)" == 0 ]] || exit 1

run_parallel "$tmp/failure" fail 42
NIX_ENRAGED_CACHE_DIR="$tmp/failure" \
    NIX_ENRAGED_FAILURE_CACHE_TIMEOUT=0 \
    RAGE_MODE=success "${helper[@]}" "$tmp/secret.nix.age" >/dev/null
[[ "$(wc -l < "$RAGE_CALLS")" == 2 ]] || exit 1

set +e
NIX_ENRAGED_CACHE_DIR="$tmp/empty" RAGE_MODE=empty \
    "${helper[@]}" "$tmp/secret.nix.age" >/dev/null 2>&1
status=$?
set -e
[[ "$status" == 1 ]] || exit 1
[[ "$(find "$tmp/empty" -type f ! -name '*.lock' ! -name '*.failed' | wc -l)" == 0 ]] || exit 1

printf 'AGE-PLUGIN-YUBIKEY-test\n' > "$tmp/yubikey.identity"
: > "$RAGE_CALLS"
set +e
NIX_ENRAGED_CACHE_DIR="$tmp/noninteractive" \
    "${helper[@]}" "$tmp/secret.nix.age" "$tmp/yubikey.identity" \
    </dev/null >/dev/null 2>&1
status=$?
set -e
[[ "$status" == 1 ]] || exit 1
[[ "$(wc -l < "$RAGE_CALLS")" == 0 ]] || exit 1
