{
  lib,
  stdenvNoCC,
  runCommand,
  makeWrapper,
  nixVersions,
  rage,
  zig_0_16,
  cacheMode ? "volatile",
  nixImplementation ? "cppnix",
  nixPackage ? nixVersions.nix_2_35,
  nixExprC ? nixPackage.passthru.libs.nix-expr-c,
  nixCIncludeDirs ? [ "${nixPackage.dev}/include" ],
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
  nix = nixPackage;
  so = "libnix-enraged-zig${stdenvNoCC.hostPlatform.extensions.sharedLibrary}";
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
    pname = "nix-enraged-zig";
    version = "0.1.0";
    src = source;
    fetchAll = true;
    hash = "sha256-oJD45T6cOHDNmuabh7mnf2iVTSxv7dXaIQYnQX8lgpE=";
  };

  plugin = stdenvNoCC.mkDerivation {
    pname = "nix-enraged-zig-plugin-${nixImplementation}-${cacheMode}";
    version = "0.1.0";
    src = source;

    nativeBuildInputs = [ zig_0_16 ];

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
runCommand "nix-enraged-zig-${nixImplementation}-${cacheMode}-${nix.version}"
  {
    nativeBuildInputs = [ makeWrapper ];
    inherit (nix) version;
    pname = "nix-enraged-zig";
    passthru = {
      inherit
        cacheMode
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
    wrapProgram "$out/bin/nix" \
      --suffix NIX_CONFIG $'\n' ${lib.escapeShellArg nixConfig}
  ''
