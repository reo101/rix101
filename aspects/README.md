# Aspect composition

An aspect groups configuration for one feature across module classes. A class is a module family, such as `nixos` or `homeManager`.

A provider defines an aspect and its dependencies. A profile combines aspects through `includes`.

`flake-aspects` supplies provider types, dependency resolution, and cross-class forwarding. This configuration does not use Den. Composition does not select package sets, create hosts, configure deployment, or decrypt secrets.

## Select host and user profiles

Host metadata receives the aspect catalog as a module argument:

```nix
{ aspects, ... }:
{
  system = "x86_64-linux";

  aspects = [ aspects.batteryNotification ];
  users.reo101.aspects = [ aspects.workstation aspects.mpdSatellite ];
}
```

Host selections supply system configuration. Each user selection supplies system requirements and that user's Home Manager configuration. Home Manager features do not enter `sharedModules`.

Each selected user must have a matching `home/<name>.nix` file. Unselected users do not receive feature modules. A Nix-on-Droid configuration has one `home.nix` file and requires exactly one named user binding. The binding name must match `home.username`.

Standalone Home Manager configurations select providers through `aspects`, without `users`. Liminix resolves the `liminix` class. OpenWrt image configurations do not accept aspect selections because their configuration is not a Nix module.

## Define features and profiles

Definitions live in `default.nix`:

```nix
composition.aspects = { aspects, ... }: {
  firefox.homeManager.imports = [ modules.homeManager.rix101-firefox ];
  workstation.includes = [ aspects.standardEnvironment aspects.wayland aspects.firefox ];
};
```

Use `includes` for dependencies and profiles. The current catalog imports reusable modules without changing their enable options. Host and user configuration still controls activation.

Module identity identifies repeated imports of one module. Keep reusable configuration in native module files. Native paths retain module identity across dependency branches. Anonymous inline modules do not receive automatic graph-wide deduplication. Parameterized instances must not share a module key when their configuration differs.

Keep dependencies acyclic. The library resolver does not detect cycles.

## Module and provider exports

Reusable modules use these default exports:

- `modules.nixos`
- `modules.darwin`
- `modules.homeManager`
- `modules.nixOnDroid`
- `modules.flake`

The default legacy exports are `nixosModules`, `darwinModules`, `homeManagerModules`, `nixOnDroidModules`, and `flakeModules`. The role registry is removed. External inputs retain their own export conventions.

`auto.modules.classes.<name>.modulesName` controls public export names. Entry names follow the module directories. The `class` option selects the internal module class.

```nix
auto.modules.classes.home-manager.modulesName = {
  old = "homeManagerModules";
  new = "homeManager";
};
```

`old` names a top-level export. `new` names a group under `modules`. If either name is `null`, that export is disabled. A string sets only the legacy export name. Omitted fields in an explicit attribute set default to `null`.

Aspect composition reads the internal class-indexed registry at `auto.modules.result`, not the public exports. Renaming or disabling an export does not change aspect resolution. If you rename an export, update direct imports of that public name.

Providers are exported through `aspects`. The private `composition` namespace (named aspect registry) separates provider definitions from reusable module exports. The library also supports a transposed catalog (providers grouped by class). Resolve an includes-only profile directly, rather than looking for a transposed class export:

```nix
self.lib.composition.resolveModules "homeManager" [ self.aspects.workstation ]
```

Module discovery preserves native paths. The module system supplies ordinary module arguments at evaluation. If you import modules outside the host constructors, supply their required module arguments.

Two-level definitions receive flake arguments before their consumer arguments. `lib.custom.defaultThingHandle` applies the first level only when a consumer selects it. With `raw = false`, it changes only the named definition and preserves the other fields. `createThings` leaves functions unchanged by default.

Overlays select this handler for all discovered definitions. Packages select it when [`meta.nix`](../pkgs/README.md) sets `curried = true`. Modules retain native paths. Use explicit `lib.modules.importApply` for a two-level module.

## Validation

`checks.<system>.aspect-composition` checks dependency resolution, native module identity, class selection, public export names, and named-user forwarding. Its assertions also run when CI evaluates the check with `nix flake check --no-build`.
