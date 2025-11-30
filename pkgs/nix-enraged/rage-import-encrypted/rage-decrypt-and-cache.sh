#!/usr/bin/env bash

set -euo pipefail

print_out_path=false
if [[ "${1}" == "--print-out-path" ]]; then
    print_out_path=true
    shift
fi

file="${1}"
shift

# Function to process identities based on environment variables
process_identities() {
    local -n ref_identities=$1
    local primary_identity="${AGENIX_REKEY_PRIMARY_IDENTITY:-}"
    local primary_only="${AGENIX_REKEY_PRIMARY_IDENTITY_ONLY:-}"

    # If primary_only is true, replace the entire identities array with the primary identity
    if [[ -n "${primary_only}" ]]; then
        if [[ -z "${primary_identity}" ]]; then
            echo "Error: AGENIX_REKEY_PRIMARY_IDENTITY_ONLY is true, but AGENIX_REKEY_PRIMARY_IDENTITY is not set" >&2
            exit 1
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

# Use mapfile to safely update identities
mapfile -t processed_identities < <(
    process_identities identities
    printf '%s\n' "${identities[@]}"
)

# Reassign processed identities
identities=("${processed_identities[@]}")

# Strip .age suffix, and store path prefix or ./ if applicable
basename="${file%".age"}"
[[ "${file}" == "/nix/store/"* ]] && basename="${basename#*"-"}"
[[ "${file}" == "./"* ]] && basename="${basename#"./"}"

# Calculate a unique content-based identifier (relocations of
# the source file in the nix store should not affect caching)
new_name="$(sha512sum "${file}")"
new_name="${new_name:0:32}-${basename//"/"/"%"}"

# Derive the path where the decrypted file will be stored
out="${TMPDIR:-/tmp}/nix-import-encrypted/${UID}/${new_name}"
umask 077
mkdir -p "$(dirname "${out}")"

# Decrypt only if necessary
if [[ ! -e "${out}" ]]; then
    args=()
    for i in "${identities[@]}"; do
        args+=("-i" "$i")
    done
    rage -d "${args[@]}" -o "${out}" "${file}"
fi

# Print out path or decrypted content
if [[ "${print_out_path}" == true ]]; then
  echo "${out}"
else
  cat "${out}"
fi
