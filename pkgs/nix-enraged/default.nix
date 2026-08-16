{ inputs }:
{
  lib,
  stdenvNoCC,
  runCommand,
  makeWrapper,
  nixVersions,
  rage,
  util-linux,
  zig_0_16,
  nix-output-monitor,
  cacheMode ? "volatile",
  nixImplementation ? "cppnix",
  nixPackage ? nixVersions.nix_2_35,
  nixExprC ? nixPackage.passthru.libs.nix-expr-c,
  nixCIncludeDirs ? [ "${nixPackage.dev}/include" ],
  monitored ? false,
}:

assert lib.assertOneOf "nixImplementation" nixImplementation [
  "cppnix"
  "detsys"
];
assert lib.assertOneOf "cacheMode" cacheMode [
  "stable"
  "volatile"
  "off"
];
let
  nix =
    if monitored then
      inputs.nix-monitored.packages.${stdenvNoCC.hostPlatform.system}.default.override {
        nix = nixPackage;
        inherit nix-output-monitor;
      }
    else
      nixPackage;
  # Wraps `bin/nix-monitored` when monitored (that's the real ELF behind the
  # `bin/nix` symlink), mirroring how the old shell-based `nix-enraged` did so.
  mainExe = if monitored then "nix-monitored" else "nix";
  so = "libnix-enraged${stdenvNoCC.hostPlatform.extensions.sharedLibrary}";
  source = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./README.md
      ./build.zig
      ./build.zig.zon
      ./src
    ];
  };
  zigDeps = zig_0_16.fetchDeps {
    pname = "nix-enraged";
    version = "0.1.0";
    src = source;
    fetchAll = true;
    hash = "sha256-oJD45T6cOHDNmuabh7mnf2iVTSxv7dXaIQYnQX8lgpE=";
  };

  plugin = stdenvNoCC.mkDerivation {
    pname = "nix-enraged-plugin-${nixImplementation}-${cacheMode}";
    version = "0.1.0";
    src = source;

    nativeBuildInputs = [ zig_0_16 ];
    nativeCheckInputs = [ util-linux ];

    buildPhase = ''
      runHook preBuild

      mkdir -p "$TMPDIR/zig-global-cache"
      cp -rL ${zigDeps} "$TMPDIR/zig-global-cache/p"
      chmod -R u+w "$TMPDIR/zig-global-cache/p"

      nix_include_args=()
      for include_dir in ${lib.escapeShellArgs nixCIncludeDirs}; do
        nix_include_args+=("-Dnix-include-dir=$include_dir")
      done

      zig build \
        --cache-dir "$TMPDIR/zig-cache" \
        --global-cache-dir "$TMPDIR/zig-global-cache" \
        -Doptimize=ReleaseSafe \
        -Dbackend=${lib.escapeShellArg nixImplementation} \
        -Dcache-mode=${lib.escapeShellArg cacheMode} \
        "''${nix_include_args[@]}" \
        -Dnix-lib-dir=${nixExprC}/lib \
        -Drage-exe=${lib.getExe rage}

      runHook postBuild
    '';

    doCheck = true;
    checkPhase = ''
      runHook preCheck

      mkdir -m700 check "$TMPDIR/runtime" "$TMPDIR/cache-home" "$TMPDIR/home"
      ${lib.getExe' rage "rage-keygen"} -o check/identity >/dev/null
      public_key="$(${lib.getExe' rage "rage-keygen"} -y check/identity)"
      printf '{ answer = 42; }\n' | ${lib.getExe rage} -r "$public_key" -o check/secret.nix.age
      cat > check/check.nix <<'NIX'
      builtins.toString (builtins.extraBuiltins.rageImportEncrypted [ ./identity ] ./secret.nix.age).answer
      NIX

      run_nix() (
        cd check
        env -u NIX_ENRAGED_CACHE_DIR -u NIX_LOG_FD \
          HOME="$TMPDIR/home" \
          XDG_CACHE_HOME="$TMPDIR/cache-home" \
          XDG_RUNTIME_DIR="$TMPDIR/runtime" \
          ${lib.getExe nix} \
          --store "local?root=$TMPDIR/nix-root" \
          --extra-experimental-features nix-command \
          --option plugin-files "$PWD/../zig-out/lib/${so}" \
          "$@"
      )
      evaluate() {
        run_nix eval --raw --file ./check.nix
      }

      run_nix_cache() ( # $1 = explicit cache dir; rest = nix args
        local cache="$1"
        shift
        cd check
        env -u NIX_ENRAGED_CACHE_DIR -u NIX_LOG_FD \
          HOME="$TMPDIR/home" \
          XDG_CACHE_HOME="$TMPDIR/cache-home" \
          XDG_RUNTIME_DIR="$TMPDIR/runtime" \
          NIX_ENRAGED_CACHE_DIR="$cache" \
          ${lib.getExe nix} \
          --store "local?root=$TMPDIR/nix-root" \
          --extra-experimental-features nix-command \
          --option plugin-files "$PWD/../zig-out/lib/${so}" \
          "$@"
      )

      test "$(evaluate)" = 42
      ${lib.optionalString (cacheMode == "stable") /* bash */ ''
        test -d "$TMPDIR/cache-home/nix-enraged"
      ''}
      ${lib.optionalString (cacheMode == "volatile") /* bash */ ''
        test -d "$TMPDIR/runtime/nix-enraged"
      ''}
      ${lib.optionalString (cacheMode == "off") /* bash */ ''
        test ! -e "$TMPDIR/cache-home/nix-enraged"
        test ! -e "$TMPDIR/runtime/nix-enraged"
        test "$(evaluate)" = 42
        ! grep -aFq NIX_ENRAGED_CACHE_DIR "zig-out/lib/${so}"
        ! grep -aFq CachePlaintextFailed "zig-out/lib/${so}"
        ! grep -aFq /run/user/ "zig-out/lib/${so}"
      ''}
      ${lib.optionalString (cacheMode != "off") /* bash */ ''
        # -- failure debounce ------------------------------------------------
        # A fresh `.failed` marker must short-circuit even a *correct*
        # identity, and must be cleared once decryption succeeds.
        ${lib.getExe' rage "rage-keygen"} -o check/wrong-identity >/dev/null
        printf '{ answer = 42; }\n' | ${lib.getExe rage} -r "$public_key" -o check/debounce.nix.age
        cat > check/debounce.nix <<'NIX'
        builtins.toString (builtins.extraBuiltins.rageImportEncrypted [ ./identity ] ./debounce.nix.age).answer
        NIX
        cat > check/debounce-wrong.nix <<'NIX'
        builtins.toString (builtins.extraBuiltins.rageImportEncrypted [ ./wrong-identity ] ./debounce.nix.age).answer
        NIX
        hash="$(sha512sum check/debounce.nix.age | cut -c1-32)"
        ${lib.optionalString (cacheMode == "volatile") /* bash */ ''
          marker="$TMPDIR/runtime/nix-enraged/''${hash}.nix.failed"
        ''}
        ${lib.optionalString (cacheMode != "volatile") /* bash */ ''
          marker="$TMPDIR/cache-home/nix-enraged/''${hash}.nix.failed"
        ''}
        # wrong identity → decrypt fails → marker is written
        ! run_nix eval --raw --file ./debounce-wrong.nix
        test -s "$marker"
        # fresh marker short-circuits the correct identity too
        ! run_nix eval --raw --file ./debounce.nix
        # clearing the marker lets the correct identity through
        rm -f "$marker"
        test "$(run_nix eval --raw --file ./debounce.nix)" = 42

        # -- lock wait timeout -----------------------------------------------
        # Holding the entry lock must make eval fail fast (rc != 0, well
        # before the 30s holder gives up), not block until the lock frees.
        mkdir -m700 "$TMPDIR/lockcache"
        lockfile="$TMPDIR/lockcache/''${hash}.nix.lock"
        (
          ${lib.getExe' util-linux "flock"} -x 9
          touch "$TMPDIR/lockcache/held"
          sleep 30
        ) 9>"$lockfile" &
        holder=$!
        for _ in $(seq 1 100); do
          [ -e "$TMPDIR/lockcache/held" ] && break
          sleep 0.1
        done
        test -e "$TMPDIR/lockcache/held"
        start=$(date +%s)
        set +e
        NIX_ENRAGED_LOCK_WAIT_TIMEOUT=1 \
          run_nix_cache "$TMPDIR/lockcache" eval --raw --file ./debounce.nix \
          >/dev/null 2>&1
        rc=$?
        set -e
        elapsed=$(( $(date +%s) - start ))
        kill "$holder" 2>/dev/null || true
        wait "$holder" 2>/dev/null || true
        # must have failed, and failed fast (not waited out the 30s holder)
        [ "$rc" != 0 ]
        [ "$elapsed" -lt 10 ]
      ''}
      ${lib.optionalString (cacheMode != "off") /* bash */ ''
        printf 'AGE-PLUGIN-YUBIKEY-TEST\n' > check/identity
        test "$(evaluate)" = 42
      ''}

      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall

      install -Dm755 "zig-out/lib/${so}" "$out/lib/nix/plugins/${so}"

      runHook postInstall
    '';
  };

  nixConfig = ''
    extra-experimental-features = nix-command flakes pipe-operators
    plugin-files = ${plugin}/lib/nix/plugins/${so}
  '';
in
runCommand "nix-enraged-${nixImplementation}-${cacheMode}-${nix.version}"
  {
    nativeBuildInputs = [ makeWrapper ];
    inherit (nix) version;
    pname = "nix-enraged";
    passthru = {
      inherit
        cacheMode
        monitored
        nix
        nixConfig
        nixImplementation
        plugin
        ;
    };
    meta = nix.meta // {
      description = "Nix with native Zig rage-encrypted imports";
      mainProgram = "nix";
      outputsToInstall = [ "out" ];
      platforms = lib.platforms.linux ++ lib.platforms.darwin;
    };
  }
  ''
    mkdir -p "$out"
    cp -r ${nix}/* "$out/"
    chmod +w "$out/bin"
    wrapProgram "$out/bin/${mainExe}" \
      --suffix NIX_CONFIG $'\n' ${lib.escapeShellArg nixConfig}
  ''
