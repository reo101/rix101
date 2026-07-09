#!/usr/bin/env nu

def usage [] {
    print -e "usage: rage-decrypt-and-cache [--print-out-path] <file.nix.age> [identity ...]"
    exit 64
}

def die [message: string] {
    error make { msg: $"rage-decrypt-and-cache: ($message)" }
}

def is-true [value: string]: nothing -> bool {
    match ($value | str downcase) {
        "1" | "true" | "yes" | "on" => true,
        _ => false,
    }
}

def is-false [value: string]: nothing -> bool {
    match ($value | str downcase) {
        "" | "0" | "false" | "no" | "off" => true,
        _ => false,
    }
}

def process-identities [identities: list<string>]: nothing -> list<string> {
    let primary_identity = ($env.AGENIX_REKEY_PRIMARY_IDENTITY? | default "")
    let primary_only = ($env.AGENIX_REKEY_PRIMARY_IDENTITY_ONLY? | default "")

    if not (is-true $primary_only) and not (is-false $primary_only) {
        die "AGENIX_REKEY_PRIMARY_IDENTITY_ONLY must be one of: true, false, 1, 0, yes, no, on, off"
    }

    if (is-true $primary_only) {
        if $primary_identity == "" {
            die "AGENIX_REKEY_PRIMARY_IDENTITY_ONLY is true, but AGENIX_REKEY_PRIMARY_IDENTITY is not set"
        }
        return [$primary_identity]
    }

    if $primary_identity != "" {
        let already_present = ($identities | any { |identity| $identity == $primary_identity })

        if not $already_present {
            return ([$primary_identity] | append $identities)
        }
    }

    $identities
}

def needs-interactive-input [identities: list<path>]: nothing -> bool {
    $identities | any { |identity|
        if not ($identity | path exists) {
            false
        } else {
            let contents = (open --raw $identity)
            ($contents | str contains "AGE-PLUGIN-YUBIKEY-") or ($contents | str contains "-> scrypt ")
        }
    }
}

def usable-dir [dir: path]: nothing -> bool {
    if not ($dir | path exists) {
        return false
    }

    if ($dir | path type) != "dir" {
        return false
    }

    ((^test -w $dir | complete).exit_code == 0) and ((^test -x $dir | complete).exit_code == 0)
}

def cache-root []: nothing -> path {
    let uid = ($env.UID? | default (^id -u | str trim))

    if ($env.NIX_ENRAGED_CACHE_DIR? | default "") != "" {
        return $env.NIX_ENRAGED_CACHE_DIR
    }

    let xdg_runtime_dir = ($env.XDG_RUNTIME_DIR? | default "")
    if $xdg_runtime_dir != "" and (usable-dir $xdg_runtime_dir) {
        return ($xdg_runtime_dir | path join "nix-import-encrypted" $uid)
    }

    ($env.TMPDIR? | default "/tmp" | path join "nix-import-encrypted" $uid)
}

def cache-basename [input_file: path]: nothing -> string {
    let file = ($input_file | into string)
    mut basename = ($file | str replace --regex '\.age$' '')

    if ($file | str starts-with "/nix/store/") {
        $basename = ($basename | str replace --regex '^/nix/store/[^-]+-' '')
    }

    if ($file | str starts-with "./") {
        $basename = ($basename | str replace --regex '^\./' '')
    }

    $basename | str replace --all "/" "%"
}

def calculate-output-path [input_file: path]: nothing -> path {
    let hash = (^sha512sum $input_file | split row " " | get 0 | str substring 0..<32)
    let basename = (cache-basename $input_file)
    let output_dir = (cache-root)

    $output_dir | path join $"($hash)-($basename)"
}

def lock-wait-timeout []: nothing -> int {
    let raw = ($env.NIX_ENRAGED_LOCK_WAIT_TIMEOUT? | default "300")
    if not ($raw =~ '^\d+$') {
        die "NIX_ENRAGED_LOCK_WAIT_TIMEOUT must be seconds"
    }
    $raw | into int
}

def failure-cache-timeout []: nothing -> int {
    let raw = ($env.NIX_ENRAGED_FAILURE_CACHE_TIMEOUT? | default "30")
    if not ($raw =~ '^\d+$') {
        die "NIX_ENRAGED_FAILURE_CACHE_TIMEOUT must be seconds"
    }
    $raw | into int
}

def decrypt-file [
    input_file: path,
    identities: list<path>,
    output_path: path
] {
    if ((^test -s $output_path | complete).exit_code == 0) {
        return
    }

    if (needs-interactive-input $identities) and ((^test -t 0 | complete).exit_code != 0) {
        die "cached plaintext is missing, but an identity requires interactive input and stdin is not a terminal"
    }

    let output_dir = ($output_path | path dirname)
    # Keep this pathname: unlinking it while waiters exist can split `flock` domains.
    let lock_file = $"($output_path).lock"
    let failure_file = $"($output_path).failed"
    mkdir $output_dir
    ^chmod 700 $output_dir | complete | ignore

    let identity_args = (
        $identities
        | each { |identity| ["-i", $identity] }
        | flatten
    )
    let critical = '
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
                printf "rage-decrypt-and-cache: previous decrypt failed; retrying in %ss (remove %s to retry now)\n" \
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
            printf "rage-decrypt-and-cache: rage produced empty decrypted output\n" >&2
            rc=1
        else
            rc=$?
        fi

        printf "%s %s\n" "$(date +%s)" "$rc" > "$failure_file"
        exit "$rc"
    '

    let result = (
        ^flock -E 75 -x -w (lock-wait-timeout) $lock_file bash -euo pipefail -c $critical rage-decrypt-and-cache $output_path $input_file $failure_file (failure-cache-timeout) ...$identity_args
        | complete
    )

    if $result.exit_code == 75 {
        die $"timed out waiting for decrypt cache lock: ($lock_file)"
    }

    if $result.exit_code != 0 {
        if $result.stderr != "" {
            print -e $result.stderr
        }
        exit $result.exit_code
    }
}

def main [
    --print-out-path (-p)
    input_file?: path
    ...identities: path
] {
    if $input_file == null {
        usage
    }

    if not ($input_file | path exists) {
        die $"encrypted file does not exist: ($input_file)"
    }

    let processed_identities = (process-identities $identities)
    let output_path = (calculate-output-path $input_file)

    decrypt-file $input_file $processed_identities $output_path

    if $print_out_path {
        echo $output_path
    } else {
        open --raw $output_path
    }
}
