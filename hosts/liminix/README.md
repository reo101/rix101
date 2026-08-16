# Liminix hosts

Hosts under `./hosts/liminix/...` build whole-device firmware from
NixOS-style modules ([Liminix]); artifacts live under
`.#configurations.liminix.<host>.<output>` (e.g. `rootfs`, `uimage`,
`manifest`).

[Liminix]: https://github.com/telent/liminix