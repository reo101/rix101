# kibo

NixOS-WSL host running on the Windows machine at `192.168.1.223` (mirrored
networking mode, so it shares the Windows IP). Deployed with deploy-rs,
building on the target (`remoteBuild`).

## Bootstrap (inside WSL, once)

The WSL image already runs NixOS; take it over with this flake:

```bash
# get the repo into WSL (clone/copy), then:
cd rix101
sudo nixos-rebuild switch --flake .#kibo
```

Then restart the distro so `wsl.conf`/systemd changes apply cleanly:

```powershell
wsl --shutdown
wsl ~ -d <distro-name>
```

If `stateVersion` in `configuration.nix` doesn't match the version the image
was bootstrapped with, adjust it to that.

## Make it reachable on the LAN (Windows side)

Requires Windows 11 22H2+ and a recent WSL (`wsl --update`).

1. `%UserProfile%\.wslconfig`:

   ```ini
   [wsl2]
   networkingMode=mirrored
   ```

2. Admin PowerShell — allow inbound SSH through Windows firewall:

   ```powershell
   New-NetFirewallRule -DisplayName "kibo ssh" `
     -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22
   ```

3. `wsl --shutdown`, start the distro again.

Verify from any machine on the LAN:

```bash
ssh reo101@192.168.1.223
```

Fallback if mirrored mode isn't available: keep NAT and forward a port:

```powershell
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=22 `
  connectaddress=<wsl-ip> connectport=22
New-NetFirewallRule -DisplayName "kibo ssh" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22
```

(the portproxy must be refreshed whenever the WSL NAT IP changes)

## Deploy

```bash
nix run github:serokell/deploy-rs -- .#kibo
```

Remote build means the x86_64 closure is built on kibo itself; accept the
substituter prompt for `rix101.cachix.org` there once if asked.

## TODO

- Set `pubkey` in `meta.nix` from `/etc/ssh/ssh_host_ed25519_key.pub` after
  first boot to enable agenix-rekey secrets.
