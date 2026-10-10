# Shell integration

`rix101.shell.shells` selects Nu and/or Zsh. It must be nonempty. The first
package sets `$SHELL`; account login-shell selection remains the OS configuration's
responsibility. Rebuild defaults use `meta.configurationType` and `meta.hostname`,
not CPU architecture or `meta.deploy.hostname`. Override `rebuildBackend` and
`rebuildTarget` when needed; standalone use without metadata defaults to
Home Manager with no selector. `rebuild` accepts an action first, then arguments,
for example `rebuild test --show-trace`.

## Why some integration remains custom

Compared against Home Manager revision `f53f3267f5d009dd8f99443505e609389d7ff267`:

| Integration | Choice | Reason |
| --- | --- | --- |
| Zsh Atuin, Carapace, direnv, Starship, zoxide | Generated, syntax-checked and compiled in the store | HM still executes these init generators at startup. Avoid five generator launches and repeated parsing. |
| Nu integrations | HM-generated store files and native hooks | No custom Atuin init cache or startup regeneration. |
| Zsh completion | Profile/fpath identity fingerprint, reduced stdlib fpath, XDG environment refresh | Store timestamps cannot detect profile target changes; direnv adds completion directories after startup. Site/vendor completions remain. |
| Autosuggestions and fast highlighting | Native HM integration | Direct store-file sourcing already avoids generators. |
| vi-mode and nix-shell plugins | nixpkgs packages | No separate source pins. Rebind autosuggestions after lazy vi-mode setup. |
| GPG terminal update | Export TTY, then background update | Avoid blocking startup; retain HM's forwarding-aware SSH socket selection. |

Actual prompt rendering, Atuin UUID generation/index preparation, direnv
exports, and GPG SSH-socket lookup still run when needed. This is not a
zero-process startup claim. Direnv's slow-load warning is deliberately suppressed.

An isolated warm benchmark of the five init snippets measured 46.2 ms for
compiled store sourcing versus 80.5 ms for runtime generation, ten measured runs
per variant after two warmups. These are **init-only**, not full shell-startup or
cold-filesystem measurements; no caches were evicted.

Completion cache hits intentionally skip a repeated security audit. Changed
profile symlink targets invalidate automatically. After changing completions or
permissions in place at an unchanged path, delete the relevant
`$XDG_CACHE_HOME/zsh/zcompdump-*.paths` marker (fallback: `$HOME/.cache/zsh`) and
restart Zsh. Misses use `compinit -i`, excluding insecure directories.

With direnv enabled, a late `precmd` hook discovers `zsh/site-functions`,
versioned `zsh/$ZSH_VERSION/functions`, and `zsh/vendor-completions` under
`XDG_DATA_DIRS`. Entering, rebuilding, and leaving a devshell reindex completion
only when that variable changes. Unchanged prompts do no directory scanning or
reindexing. The integration removes only paths it added, unloads stale environment
function bodies, removes obsolete command mappings, and restores profile
completions on exit. Carapace definitions and autosuggestion widget bindings are
reapplied after refresh, including failed initialization. Failed attempts are not
retried on unchanged prompts; change the environment or restart Zsh to retry.
No per-command loader, copied completion file, or
additional plugin is required. `mkShell` already exports package share directories;
non-Nix direnv environments must export their data directories themselves.

Carapace's `nix` completer is excluded with `CARAPACE_EXCLUDES=nix`: it assumes
legacy channel `programs.sqlite` databases even for `nixpkgs#...` references.
Zsh retains native Nix completion where available; Nu has no Carapace Nix-specific
suggestions. Other completers and runtime bridges remain enabled.

## Prompt and agent policy

Starship is pinned to upstream revision
`131bf9552d7e927607e155ea3a9b8c8a170a0356`: nixpkgs' released 1.26.0 lacks
native jj modules. The pin supplies native jj-first `$vcs` discovery, including
colocated repositories, with Git fallback. No custom VCS helper. The wrapper
supplies jj and generated init references the wrapper itself.

Native Zsh characters and Nu-owned indicators retain vi-mode arrows. Nu uses a
static variant of the same configuration with Starship's character disabled.
Empty right prompts do not launch another renderer. Username comes from the
runtime account; the clock uses the system timezone. Directory substitutions
match whole components, not fragments such as `doom-project`. Upstream regex
substitutions replace the first matching occurrence of each component.

When this module enables GPG, default and maximum GPG/SSH cache TTLs are all
7200 seconds. Independently configured agents retain their host-local cache
policy. Explicitly enabling HM's native terminal integration suppresses the
custom hook for that shell. Background startup-TTY updates remain best-effort;
multiple terminals share an agent. The PC/SC `disable-ccid` workaround is retained.

## Manual state migration

No activation hook copies history or Atuin databases. `migrate-shell-state` is
installed only for configured nondefault destinations. **Migrate before starting
shells or daemons with the new paths**, otherwise they can populate the destination
and the command will refuse it.

Build the pending command without activating it, for example for Jeeves's
`jeeves` account (run from the repository root):

```nu
let migration = (nix build --impure --no-link --print-out-paths --expr 'let f = builtins.getFlake (toString ./.); in builtins.head (builtins.filter (package: package.name == "migrate-shell-state") f.nixosConfigurations.jeeves.config.home-manager.users.jeeves.home.packages)' | str trim)
^($migration | path join bin/migrate-shell-state) --dry-run
```

Provision private destination parents with the correct owner first if necessary;
Jeeves's `shell-state.nix` specifies their ownership. Stop old interactive shells,
Atuin daemons and other writers. From an unconfigured shell, run the same command
with `--confirm-quiescent` instead of `--dry-run`, as the state owner. Then activate
the new configuration. No live migration is part of the regression tests.

- Dry-run validates paths/types/overlap; it does not read-test SQLite contents.
- Every component is staged before any publication. SQLite backup snapshots are
  consistent per database, not across databases. WAL data is included through
  SQLite; sidecars are not blindly copied.
- Atuin accepts an absent or precreated empty destination, publishes by rename
  with mode `0700`, and refuses populated/partial destinations.
- History publishes without overwriting an existing file and has mode `0600`.
- Sources remain. Ordinary symlinks are preserved; inspect them before removing
  old paths. Database symlinks are rejected.
- Components publish separately. If the second fails, the first can already be
  published. Explicit source/destination pairs disable the packaged defaults,
  allowing a retry for only the remaining component. Argument abbreviations are
  not accepted. Parent directories created during staging may remain after failure.

## Privacy, helpers and deployment

Atuin's secret-pattern filter stays enabled. Leading-space exclusion is configured
for Atuin, Zsh and Nu. Native histories remain separate plaintext stores, and
Atuin's filter is heuristic, not a guarantee. Existing history is not rewritten;
clipboard contents, terminal logs and backups are outside this policy.

`git generate gitignore Python Rust` is an existing manual Nu helper. It downloads
templates and refuses an existing destination unless `--force` is given. Failed
fetches/writes preserve the original. Publication uses pinned GNU mv with a
file-only destination and no cross-filesystem copy fallback. Completion fetches
are retried after HTTP failure. Alt-C copies the raw command through OSC 52;
Alt-Shift-C copies highlighted text in an `ansi` Markdown fence. Terminal OSC 52
policy determines whether clipboard access works.

The Atuin client now uses `https://atuin.jeeves.reo101.xyz`. Server registration is
closed; existing-account login/sync remains enabled. Nginx uses the existing
`*.jeeves.reo101.xyz` wildcard certificate and proxies to `127.0.0.1:8888`.
Ensure the hostname resolves for clients and validate HTTPS on the server before
switching clients. No DNS changes or deployment are performed by these edits.

## Regression checks

Run from the repository root with the flake's pinned packages:

```nu
nu --no-config-file modules/home-manager/rix101-shell/tests/completion.nu
nix shell --inputs-from . nixpkgs#zsh nixpkgs#coreutils --command zsh -f modules/home-manager/rix101-shell/tests/completion-environment.zsh modules/home-manager/rix101-shell/zsh/completion-init.zsh
nix shell --inputs-from . nixpkgs#coreutils --command nu --no-config-file modules/home-manager/rix101-shell/tests/gitignore.nu
nu --no-config-file modules/home-manager/rix101-shell/tests/clipboard.nu
nix shell --inputs-from . nixpkgs#python3 --command python3 modules/home-manager/rix101-shell/tests/migration.py
nix eval --impure --json --file modules/home-manager/rix101-shell/tests/configuration.nix
nix build --impure --no-link --builders '' --file modules/home-manager/rix101-shell/tests/completion-generated.nix
let generated = (nix build --impure --no-link --print-out-paths --file modules/home-manager/rix101-shell/tests/generated.nix | str trim)
nix shell --inputs-from . nixpkgs#python3 --command python3 modules/home-manager/rix101-shell/tests/integration.py $generated
```

`--inputs-from .` resolves nixpkgs from this flake's inputs.
The generated-config test builds files/init snippets, not an activation package.
Integration checks use temporary homes and jj/Git fixtures, disable Atuin sync,
capture terminal output, and replace the GPG agent command with a test executable.
Add `--benchmark` to repeat the warm init-only comparison. Darwin and Droid are
evaluated but runtime/PTY checks currently run on Linux.
