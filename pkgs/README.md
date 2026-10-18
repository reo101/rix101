# Package collection metadata

A package directory contains `default.nix` and an optional `meta.nix`. The package definition stays in `default.nix`. The collector reads `meta.nix` to select platforms and argument handling.

Return a plain attribute set:

```nix
{
  curried = true;
  systems = { stdenv, ... }: stdenv.hostPlatform.isLinux;
}
```

If a field is omitted, the collector uses these defaults:

```nix
{
  curried = false;
  systems = _: true;
}
```

`systems` receives `lib` and `stdenv` from the selected package set. If it returns `false`, the collector excludes the package before it applies the definition.

`curried = true` marks a two-level definition:

```nix
{ inputs }:
{ stdenv, ... }:
inputs.nix-enraged.packages.${stdenv.hostPlatform.system}.default
```

The shared `lib.custom.defaultThingHandle` supplies the first level with the requested flake arguments, `inputs` and the repository's extended `lib`. The package consumer then evaluates the returned definition through `callPackage` or Dream2Nix. Ordinary definitions skip the first level. Argument names select supplied values, not the number of levels.

This metadata controls collection. It does not set the resulting derivation's `meta` attributes. Single-file package definitions use the defaults. If a package needs metadata, put its definition in a directory.

Package `systems.nix` sidecars are no longer read. Their predicates belong in `meta.nix` under `systems`.
