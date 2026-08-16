# nix-enraged Zig plugin

`build.zig` uses the external `ziglang/translate-c` package in C23 mode to
translate `src/c_api.h` into the plugin's `c_api` module. The plugin must be
built against the exact Nix implementation that will load it; these shared
objects are not portable between Nix builds.

## Build options

```console
zig build \
  -Dbackend=cppnix \
  -Dcache-mode=volatile \
  -Dnix-include-dir=/path/to/nix/include \
  -Dnix-lib-dir=/path/to/nix/lib \
  -Drage-exe=/path/to/rage
```

`-Dbackend` accepts `cppnix` (the default) or `detsys`. Include and library
options may be repeated. Both backends currently use the same public Nix C API,
but selecting the backend records the intended ABI and keeps package outputs
distinct. `translate-c` 1.0.0 is pinned from its Zig 0.16 branch, avoiding the
built-in translator's fixed C17 mode. Nix prefetches its sources with
`zig.fetchDeps`; direct Zig builds fetch them through `build.zig.zon`.

For Determinate Nix, override `nixImplementation`, `nixPackage`, `nixExprC`,
and `nixCIncludeDirs` in `default.nix` with packages from the same Determinate
Nix release.

## Cache policy

`-Dcache-mode` and the Nix `cacheMode` argument accept:

- `stable`: cache plaintext under `$XDG_CACHE_HOME/nix-enraged`, falling back to
  `$HOME/.cache/nix-enraged`. It remains there until explicitly removed.
- `volatile` (default): cache under `$XDG_RUNTIME_DIR/nix-enraged`, falling back
  to `/run/user/$UID/nix-enraged` (or `/run/nix-enraged` for root). When no
  usable runtime directory exists (e.g. macOS, containers without
  `XDG_RUNTIME_DIR`), it degrades to the `stable` cache root so decryption keeps
  working; `/tmp` is never an implicit fallback.
- `off`: stream Rage output through a pipe and keep no plaintext cache or
  temporary plaintext file. Cache-path code is compile-time unreachable and is
  removed from release builds.

`NIX_ENRAGED_CACHE_DIR` remains an explicit root override for `stable` and
`volatile` builds. It is absent from `off` builds.

## Tuning

Two more environment variables tune the cache (parsed as whole seconds):

- `NIX_ENRAGED_LOCK_WAIT_TIMEOUT` (default `300`): how long to wait for a cache
  entry's lock before failing. `0` fails immediately if the lock is held, like
  `flock -w 0`. Protects concurrent `nix` invocations from blocking forever on
  a wedged holder (e.g. a stuck YubiKey prompt).
- `NIX_ENRAGED_FAILURE_CACHE_TIMEOUT` (default `30`): debounces repeated decrypt
  failures for the same entry. When a decrypt fails, `<hash>.failed` records the
  failure; concurrent waiters within the window fail fast instead of each
  re-running Rage and re-triggering a YubiKey/passphrase prompt. `0` disables
  the debounce.

## Lix

CppNix still labels its `nix_api_*` API experimental, while stating that a stable
external C API is the goal. Lix does not ship that API, and has no announced plan
or tracking issue to add it. Its `nix_plugin_entry` support is explicitly a small
partial backport; primops still use Lix's unstable C++ `PluginPrimOps` API and
must be rebuilt against the exact Lix and nixpkgs versions.

If Lix support becomes necessary, the smallest maintainable route is:

1. move decryption and caching into an evaluator-independent Zig module;
2. expose one narrow C ABI from that module; and
3. add a version-matched C++ Lix adapter for value conversion, evaluation, and
   `PluginPrimOps::add` registration.

Do not emulate the whole Nix C API or link CppNix libraries into Lix. Lix's
planned versioned plugin work may eventually make the adapter less fragile, but
it is not a C ABI today.

Relevant upstream context:

- <https://github.com/NixOS/nix/blob/master/src/external-api-docs/README.md>
- <https://git.lix.systems/lix-project/lix/issues/279>
- <https://git.lix.systems/lix-project/lix/issues/359>
- <https://git.lix.systems/lix-project/lix/issues/1144>
- <https://gerrit.lix.systems/c/lix/+/2826>
- <https://lix.systems/blog/2026-03-25-lix-2.95-release/>
