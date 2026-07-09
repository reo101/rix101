#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat >&2 <<'EOF'
usage: rage-decrypt-and-cache [--print-out-path] <file.nix.age> [identity ...]
EOF
}

die() {
    echo "rage-decrypt-and-cache: $*" >&2
    exit 1
}

is_true() {
    case "${1,,}" in
        1 | true | yes | on) return 0 ;;
        *) return 1 ;;
    esac
}

is_false() {
    case "${1,,}" in
        "" | 0 | false | no | off) return 0 ;;
        *) return 1 ;;
    esac
}

print_out_path=false
case "${1:-}" in
    --print-out-path)
        print_out_path=true
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
esac

if [[ $# -lt 1 ]]; then
    usage
    exit 64
fi

file="${1}"
shift

[[ -e "${file}" ]] || die "encrypted file does not exist: ${file}"

# Function to process identities based on environment variables
process_identities() {
    local -n ref_identities=$1
    local primary_identity="${AGENIX_REKEY_PRIMARY_IDENTITY:-}"
    local primary_only="${AGENIX_REKEY_PRIMARY_IDENTITY_ONLY:-}"

    if ! is_true "${primary_only}" && ! is_false "${primary_only}"; then
        die "AGENIX_REKEY_PRIMARY_IDENTITY_ONLY must be one of: true, false, 1, 0, yes, no, on, off"
    fi

    # If primary_only is true, replace the entire identities array with the primary identity.
    if is_true "${primary_only}"; then
        if [[ -z "${primary_identity}" ]]; then
            die "AGENIX_REKEY_PRIMARY_IDENTITY_ONLY is true, but AGENIX_REKEY_PRIMARY_IDENTITY is not set"
        fi
        ref_identities=("${primary_identity}")
    else
        # If a primary identity is set, prepend it to the identities array
        if [[ -n "${primary_identity}" ]]; then
            # Check if the primary identity is already in the array to avoid duplicates
            local found=false
            for id in "${ref_identities[@]}"; do
                if [[ "${id}" == "${primary_identity}" ]]; then
                    found=true
                    break
                fi
            done

            if [[ "${found}" == "false" ]]; then
                ref_identities=("${primary_identity}" "${ref_identities[@]}")
            fi
        fi
    fi
}

# Declare identities array
identities=("$@")
process_identities identities

needs_interactive_input() {
    local identity line
    for identity in "$@"; do
        [[ -r "${identity}" ]] || continue
        while IFS= read -r line; do
            case "${line}" in
                AGE-PLUGIN-YUBIKEY-* | "-> scrypt "*) return 0 ;;
            esac
        done < "${identity}"
    done
    return 1
}

cache_root() {
    if [[ -n "${NIX_ENRAGED_CACHE_DIR:-}" ]]; then
        printf '%s\n' "${NIX_ENRAGED_CACHE_DIR}"
    elif [[ -n "${XDG_RUNTIME_DIR:-}" && -d "${XDG_RUNTIME_DIR}" && -w "${XDG_RUNTIME_DIR}" && -x "${XDG_RUNTIME_DIR}" ]]; then
        printf '%s\n' "${XDG_RUNTIME_DIR%/}/nix-import-encrypted/${UID}"
    else
        printf '%s\n' "${TMPDIR:-/tmp}/nix-import-encrypted/${UID}"
    fi
}

# Strip .age suffix, and store path prefix or ./ if applicable
basename="${file%".age"}"
[[ "${file}" == "/nix/store/"* ]] && basename="${basename#*"-"}"
[[ "${file}" == "./"* ]] && basename="${basename#"./"}"

# Calculate a unique content-based identifier (relocations of
# the source file in the nix store should not affect caching)
read -r file_hash _ < <(sha512sum "${file}")
new_name="${file_hash:0:32}-${basename//"/"/"%"}"

# Derive the path where the decrypted file will be stored
umask 077
cache_dir="$(cache_root)"
out="${cache_dir%/}/${new_name}"
# Keep this pathname: unlinking it while waiters exist can split `flock` domains.
lock_file="${out}.lock"
failure_file="${out}.failed"
wait_timeout="${NIX_ENRAGED_LOCK_WAIT_TIMEOUT:-300}"
failure_timeout="${NIX_ENRAGED_FAILURE_CACHE_TIMEOUT:-30}"
[[ "${wait_timeout}" =~ ^[0-9]+$ ]] || die "NIX_ENRAGED_LOCK_WAIT_TIMEOUT must be seconds"
[[ "${failure_timeout}" =~ ^[0-9]+$ ]] || die "NIX_ENRAGED_FAILURE_CACHE_TIMEOUT must be seconds"

mkdir -p -- "${cache_dir}"
chmod 700 -- "${cache_dir}" 2>/dev/null || true

# Decrypt only if necessary. `flock` avoids stale-lock hangs: kernel locks die with the process.
if [[ ! -s "${out}" ]]; then
    if needs_interactive_input "${identities[@]}" && [[ ! -t 0 ]]; then
        die "cached plaintext is missing, but an identity requires interactive input and stdin is not a terminal"
    fi

    args=()
    for i in "${identities[@]}"; do
        args+=("-i" "$i")
    done

    set +e
    # shellcheck disable=SC2016 # expanded by the inner bash, not this script
    flock -E 75 -x -w "${wait_timeout}" "${lock_file}" \
        bash -euo pipefail -c '
            out=$1
            file=$2
            failure_file=$3
            failure_timeout=$4
            shift 4
            tmp=""

            cleanup() {
                [ -z "$tmp" ] || rm -f -- "$tmp"
            }
            trap cleanup EXIT

            if [ -s "$out" ]; then
                rm -f -- "$failure_file"
                exit 0
            fi

            if [ -f "$failure_file" ]; then
                now="$(date +%s)"
                if read -r failed_at failed_rc < "$failure_file" &&
                    [[ "$failed_at" =~ ^[0-9]+$ && "$failed_rc" =~ ^[1-9][0-9]*$ ]] &&
                    (( now >= failed_at && now - failed_at < failure_timeout )); then
                    printf "rage-decrypt-and-cache: previous decrypt failed; retrying in %ss (remove %s to retry now)\\n" \
                        "$((failure_timeout - (now - failed_at)))" "$failure_file" >&2
                    exit "$failed_rc"
                fi
                rm -f -- "$failure_file"
            fi

            rm -f -- "$out"
            tmp="$(mktemp "${out}.tmp.XXXXXXXXXX")"
            if rage -d "$@" -o "$tmp" "$file"; then
                if [ -s "$tmp" ]; then
                    chmod 600 -- "$tmp"
                    mv -f -- "$tmp" "$out"
                    rm -f -- "$failure_file"
                    exit 0
                fi
                printf "rage-decrypt-and-cache: rage produced empty decrypted output\\n" >&2
                rc=1
            else
                rc=$?
            fi

            printf "%s %s\\n" "$(date +%s)" "$rc" > "$failure_file"
            exit "$rc"
        ' rage-decrypt-and-cache "${out}" "${file}" "${failure_file}" "${failure_timeout}" "${args[@]}"
    rc=$?
    set -e

    case "${rc}" in
        0) ;;
        75) die "timed out waiting for decrypt cache lock: ${lock_file}" ;;
        *) exit "${rc}" ;;
    esac
fi

# Print out path or decrypted content
if [[ "${print_out_path}" == true ]]; then
    echo "${out}"
else
    cat -- "${out}"
fi
