#!/usr/bin/env nu

def process-identities [identities: list<string>] -> list<string> {
    let primary_identity = ($env.AGENIX_REKEY_PRIMARY_IDENTITY? | default "")
    let primary_only = ($env.AGENIX_REKEY_PRIMARY_IDENTITY_ONLY? | default "false")

    if $primary_only == "true" {
        if $primary_identity == "" {
            error make {
                msg: "AGENIX_REKEY_PRIMARY_IDENTITY_ONLY is true, but AGENIX_REKEY_PRIMARY_IDENTITY is not set"
            }
        }
        return [$primary_identity]
    } else {
        if $primary_identity != "" {
            # Check if primary identity is not already in the list
            let is_unique = ($identities | find $primary_identity | is-empty)

            if $is_unique {
                return ([$primary_identity] | append $identities)
            }
        }

        return $identities
    }
}

def calculate-output-path [input_file: path] -> path {
    let hash = (
        open --raw $input_file
        | hash sha512
        | str substring 0..32
    )

    let basename = (
        $input_file
        | path basename
        | str replace ".age$" ""
        | str replace "/" "%"
    )

    let output_dir = (
        $env.TMPDIR?
        | default "/tmp"
        | path join "nix-import-encrypted"
        | path join ($env.USER? | default "unknown")
    )

    # Ensure directory exists
    mkdir $output_dir

    $output_dir | path join $"($hash)-($basename)"
}

def decrypt-file [
    input_file: path,
    identities: list<path>,
    output_path: path
] {
    if not ($output_path | path exists) {
        let identity_args = (
            $identities
            | each { |id| ["-i", $id] }
            | flatten
        )

        try {
            rage -d ...$identity_args -o $output_path $input_file
        } catch {
            error make { msg: "Decryption failed for file: $input_file" }
        }
    }
}

def main [
    --print-out-path (-p)
    input_file: path
    ...identities: path
] {
    let processed_identities = (process-identities $identities)
    let output_path = (calculate-output-path $input_file)

    decrypt-file $input_file $processed_identities $output_path

    if $print_out_path {
        echo $output_path
    } else {
        open $output_path
    }
}

main ...$argv
