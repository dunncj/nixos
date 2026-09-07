# nixos

NixOS configuration for **agartha** — a headless box that runs a Plasma session
for Sunshine/Moonlight streaming, a single-node k3s server, and a Minecraft
server.

## Layout

```
nix/
  flake.nix                        inputs + the agartha system
  hosts/agartha/
    configuration.nix              boot, desktop, networking, wireguard
    hardware-configuration.nix     generated; do not hand-edit
  modules/
    rebuild.nix                    the `nb` command and the /etc/nixos symlink
    turbo.nix                      the turbo account, tmux, neovim
    k3s.nix                        single-node k3s server
    sunshine.nix                   synthetic EDID so headless capture works
    power.nix                      forbids sleep and display blanking
  turbo/home.nix                   home-manager: shell, git, starship, direnv
  k3s/, services/                  workload manifests, applied by hand

archive/titan/                     previous host's config; not built by anything
```

## Rebuilding

```
nb            build + activate now, and set as boot default
nb boot       build + set as boot default, do not activate
nb test       build + activate now, do NOT touch the bootloader
nb dry        show what activating would change, change nothing
nb update     update flake inputs, then switch
nb rollback   activate the previous generation
nb diff       diff the working tree against the running system
nb gc         delete generations older than 14 days
```

`nb` wraps `nixos-rebuild` for two reasons: it uses `path:` rather than a bare
`~/nix` so nix does not copy this whole repo into the store on every build, and
it re-execs systemd afterwards so a dbus restart cannot leave `reboot` silently
doing nothing.

## Repo scope

This repository is rooted at `$HOME`, but `.gitignore` ignores everything and
re-includes only `nix/` and `archive/`. That is deliberate: without it, `git add
-A` sweeps in Minecraft world saves, Steam blobs, shell histories, `.ssh/`, and
`.kube/config`.

Secrets are never committed. The WireGuard key is deployed out of band and read
from `/etc/wireguard/private.key`; only the peer's public key appears here.

## Formatting

All `.nix` files are formatted with `nixfmt-rfc-style`:

```
nix run nixpkgs#nixfmt-rfc-style -- $(find nix -name '*.nix' -not -name 'hardware-configuration.nix')
```
