# OpenWrt hosts

Router firmware hosts under `./hosts/openwrt/...` are built with
[nix-openwrt-imagebuilder]: packages plus a first-boot `uci-defaults` script
generated from Nix; build with `nix build .#configurations.openwrt.<host>`.

## Live reconciliation

All public modules expose a `sections` DSL; they are merged with the encrypted
runtime document `secrets/master/home/openwrt/router-config.nix.age` (decrypted
by the provider at runtime, never during Nix evaluation) into one whole-router
NixOps4 resource with rollback-armed applies. Inspect the semantic diff with:

```console
nix develop .#openwrt-nixops4 -c nixops4 apply
```

Run it from an interactive terminal: decryption touches the YubiKey (PIN +
touch). `openwrt.dryRun = true` keeps it read-only. Live mode arms a 60s
rollback window and confirms only after re-reading converged state. Services
listed in `openwrt.reloadServices` (e.g. `dnsmasq`) restart automatically after
any confirmed apply — including wireless-only changes.

Anonymous sections are created in declaration order; give a section an
explicit `weight` when its on-router position is semantic (firewall rules).
Equal weights keep module declaration order.

Covered configs: `network`, `wireless`, `dhcp`, `firewall`, `system`,
`dropbear`. Firmware images now carry public bootstrap config only.

[nix-openwrt-imagebuilder]: https://github.com/astro/nix-openwrt-imagebuilder