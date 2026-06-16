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
lock_file="${out}.lock"
wait_timeout="${NIX_ENRAGED_LOCK_WAIT_TIMEOUT:-300}"
[[ "${wait_timeout}" =~ ^[0-9]+$ ]] || die "NIX_ENRAGED_LOCK_WAIT_TIMEOUT must be seconds"
tmp_out=""

cleanup() {
    if [[ -n "${tmp_out}" && -e "${tmp_out}" ]]; then
        rm -f -- "${tmp_out}"
    fi
}
trap cleanup EXIT

mkdir -p -- "${cache_dir}"
chmod 700 -- "${cache_dir}" 2>/dev/null || true

# Decrypt only if necessary. `flock` avoids stale-lock hangs: kernel locks die with the process.
if [[ ! -e "${out}" ]]; then
    args=()
    for i in "${identities[@]}"; do
        args+=("-i" "$i")
    done

    tmp_out="$(mktemp "${out}.tmp.XXXXXXXXXX")"
    set +e
    # shellcheck disable=SC2016 # expanded by the inner bash, not this script
    flock -E 75 -x -w "${wait_timeout}" "${lock_file}" \
        bash -euo pipefail -c '
            out=$1
            tmp=$2
            file=$3
            shift 3

            if [ ! -e "$out" ]; then
                rage -d "$@" -o "$tmp" "$file"
                chmod 600 -- "$tmp"
                mv -f -- "$tmp" "$out"
            fi
        ' rage-decrypt-and-cache "${out}" "${tmp_out}" "${file}" "${args[@]}"
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
