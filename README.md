![nix](https://socialify.git.ci/reo101/rix101/image?description=1&font=Source%20Code%20Pro&forks=1&issues=1&logo=https%3A%2F%2Fpablo.tools%2Fnixoscolorful.svg&owner=1&pattern=Circuit%20Board&pulls=1&stargazers=1&theme=Dark)

<!-- <div align="center">
    <p>
        <a href="https://github.com/NixOS">
            <img src="https://img.shields.io/badge/NixOS?style=flat-square&logo=nix" alt="NixOS"/>
        </a>
        <a href="https://github.com/t184256/nix-on-droid">
            <img src="https://img.shields.io/badge/nix%2Don%2Ddroid?style=flat-square&logo=nix" alt="nix-on-droid"/>
        </a>
        <a href="https://github.com/LnL7/nix-darwin">
            <img src="https://img.shields.io/badge/nix%2Ddarwin?style=flat-square&logo=nix" alt="nix-darwin"/>
        </a>
    </p>
    <p>
        <a href="https://nixos.org/">
            <img src="https://img.shields.io/badge/Made%20with%20Nix-lightblue.svg?style=for-the-badge&logo=nix" alt="Nix"/>
        </a>
        <a href="https://github.com/reo101/rix101/blob/main/LICENSE">
            <img src="https://img.shields.io/github/license/reo101/rix101?style=flat-square&logo=MIT&label=License" alt="License"/>
        </a>
        <a href="https://github.com/reo101/rix101/pulse">
            <img alt="Last Commit" src="https://img.shields.io/github/last-commit/reo101/rix101"/>
        </a>
    </p>
</div> -->

<!-- ```
      ___         ___             ___      
     /  /\       /  /\           /__/|     
    /  /::\     /  /:/          |  |:|     
   /  /:/\:\   /__/::\          |  |:|     
  /  /:/~/:/   \__\/\:\       __|__|:|     
 /__/:/ /:/___    \  \:\     /__/::::\____ 
 \  \:\/:::::/     \  \:\__     ~\~~\::::/ 
  \  \::/~~~~       \  \:\/\     |~~|:|~~  
   \  \:\            \__\::/     |  |:|    
    \  \:\           /__/:/      |  |:|    
     \__\/           \__\/       |__|/     
``` -->

<div align="center">
    Based on <a href="https://github.com/Misterio77/nix-starter-configs">nix-starter-configs</a>
</div>

---

# Secrets

```bash
# To put `agenix` and friends in `$PATH`
nix develop
cd secrets
```

## Make new key

```bash
rage-keygen -o key
```

## Edit secret

```bash
agenix -i key -e sub/dir/secret_file.age
```

## Rekey all secrets

```bash
agenix -i key --rekey
```

# NixOS setup

```bash
# Initial setup
nix run nixpkgs#nixos-anywhere -- --flake .#${HOSTNAME} --build-on-remote --ssh-port 22 root@${HOSTNAME} --no-reboott

# Deploy
deploy .#${HOSTNAME} --skip-checks
```

---

# Mac (silicon) setup

```sh
# Setup system tools
softwareupdate --install-rosetta --agree-to-license
sudo xcodebuild -license

# Install nix
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Apply configuration
git clone https://www.github.com/reo101/rix101 ~/.config/rix101
cd ~/.config/rix101
nix build ".#darwinConfigurations.${HOSTNAME}.system"
./result/sw/bin/darwin-rebuild switch --flake .

# System setup for `yabai` (in system recovery)
csrutil enable --without fs --without debug --without nvram
```
