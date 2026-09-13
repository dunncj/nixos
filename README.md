# nixos

One repo for every machine. Three hosts:

| host | what it is |
|---|---|
| **shambhala** | headless box: a Plasma session for Sunshine/Moonlight streaming, a single-node k3s server, and a Minecraft server. Never sat in front of. |
| **myosis** | Cameron's workstation. Intel + NVIDIA, one 4K144 panel, dual-boots Windows. Desktop only — none of shambhala's server modules. |
| **amarout** | Cameron's MacBook, via nix-darwin. |

Both Linux hosts share `modules/base.nix`, the `nb` rebuild command and the
`turbo` environment; everything else is per-host and listed in `flake.nix`.

## Layout

```
nix/
  flake.nix                        inputs + every host, via mkLinuxHost
  hosts/shambhala/
    configuration.nix              autologin, networking, wireguard, steam, docker
    hardware-configuration.nix     generated; do not hand-edit
  hosts/myosis/
    configuration.nix              ESP limit, audio, printing, locale
    hardware-configuration.nix     generated; do not hand-edit
  hosts/amarout/
    configuration.nix              the darwin host
  modules/
    base.nix                       what every NixOS host here gets
    desktop.nix                    Plasma 6 on Wayland; opt-in per host
    rebuild.nix                    the `nb` command and the /etc/nixos symlink
    nvidia.nix                     proprietary driver, for 4K144 (myosis)
    k3s.nix                        single-node k3s server (shambhala)
    sunshine.nix                   synthetic EDID so headless capture works (shambhala)
    power.nix                      forbids sleep and display blanking (shambhala)
  turbo/tools.nix                  plain CLI tools
  turbo/wrappers.nix               git/tmux/starship with config baked in
  turbo/neovim.nix                 the editor as one derivation
  turbo/package.nix                all of it as one buildEnv
  turbo/system.nix                 NixOS module: account + that package + zsh
  turbo/nvim/                      neovim config, as real .lua files
  k3s/, services/                  workload manifests, applied by hand

archive/titan/                     previous host's config; not built by anything
```

## Layering

A host config holds only what is true of that host. Anything both Linux hosts
set to the same value lives in `modules/base.nix`; anything optional but shared
is its own module a host opts into (`desktop.nix`, `nvidia.nix`). The
`mkLinuxHost` helper in `flake.nix` gives every NixOS host `base.nix`,
`rebuild.nix` and the `turbo` module, so a new machine is a hostname, a hardware
config and a short module list.

The system config stays as minimal as it can be. Root gets no conveniences -
no git, no editor, no tmux, no starship. Everything turbo works with lives in
the `turbo` profile, installed through `users.users.turbo.packages`, so it
lands in `/etc/profiles/per-user/turbo` and never on root's PATH.

There is no home-manager. Anything with config carries it inside its own
wrapper (see below), so nothing needs writing into `$HOME`. The single
exception is zsh: a login shell reads `/etc/zshrc`, which only the NixOS zsh
module can supply, and that module is also what lets zsh be turbo's shell at
all.

So: new packages go in `turbo/tools.nix`; anything with config gets a wrapper
in `turbo/wrappers.nix`. The system layer gets something only when it
genuinely cannot work otherwise.

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

`nb` builds whichever host it is installed on — it reads `turbo.flakePath` and
`turbo.hostName`, so the same module is correct everywhere. It used to hardcode
`shambhala`, which on a second host would have quietly rebuilt the wrong
machine.

`nb` wraps `nixos-rebuild` for two reasons: it uses `path:` rather than a bare
`~/nix` so nix does not copy this whole repo into the store on every build, and
it re-execs systemd afterwards so a dbus restart cannot leave `reboot` silently
doing nothing.

## myosis and the 4K144 panel

The monitor is an Acer XB273K V6 on HDMI. It will do 3840x2160@144, but only on
the proprietary NVIDIA driver, and the reason is worth writing down because the
symptom looks like a monitor or cable fault rather than a driver one.

The panel's DisplayID block advertises 4K@144 at a **1278.72 MHz** pixel clock
(and a 4K@160 overclock mode at 1395.99 MHz). HDMI 2.0 TMDS tops out at 600 MHz,
so those modes are reachable only over HDMI 2.1 FRL with DSC. The EDID confirms
the sink supports both — its HDMI Forum VSDB reports `Supports VESA DSC 1.2a`
and FRL up to 12 Gbps on 4 lanes.

nouveau implements neither FRL nor DSC. So on nouveau the highest 4K mode the
kernel will even enumerate is VIC 97, 3840x2160@60 at 594 MHz — which is exactly
the 60 Hz ceiling you see. Nothing is wrong with the cable or the display.
`modules/nvidia.nix` is what lifts it.

`hardware.nvidia.open = true` in that module is mandatory rather than a
preference: this is a Blackwell card (RTX 50-series, GB2xx) and the closed kernel
module has no support for those chips at all.

One wart: the *chosen* mode is not declarative. KWin stores it per-output under
`~/.local/share/kscreen/`, and there is no home-manager here to own that file.
Set it once and Plasma remembers:

```
kscreen-doctor output.HDMI-A-1.mode.3840x2160@144
kscreen-doctor output.HDMI-A-1.scale.1.5     # 4K at 1.5 => a 2560x1440 desktop
```

## The turbo environment

`turbo/` is built to be reusable on other machines, so it is kept free of
anything specific to this host:

```
turbo/tools.nix     plain CLI tools, no config of their own
turbo/wrappers.nix  git, tmux and starship, each with its config baked in
turbo/neovim.nix    the editor - plugins, lua tree and language servers,
                    all inside the wrapper
turbo/nvim/         the lua, as ordinary files
turbo/package.nix   all of the above as one buildEnv
turbo/system.nix    the NixOS module: the account, that package, and zsh
```

Two ways to consume it:

| output | for |
|---|---|
| `nixosModules.turbo` | another NixOS machine: `imports = [ inputs.shambhala.nixosModules.turbo ];` |
| `packages.x86_64-linux.turbo` | any machine with nix: `nix profile install github:dunncj/nixos?dir=nix#turbo` |

`turbo.flakePath`, `turbo.hostName` and `turbo.extraGroups` are the only
host-dependent options. The first two tell nixd which flake to evaluate for
NixOS option completion; leave them null elsewhere and nixd still runs.

### Why wrappers instead of dotfiles

`programs.git`, `programs.tmux`, `programs.starship` and `programs.direnv` all
push their package into `environment.systemPackages`, which would put them on
root's PATH. Wrapping them here keeps them in turbo's profile only.

It also makes them portable. `git` gets `GIT_CONFIG_SYSTEM` (so a personal
`~/.gitconfig` still layers on top and `git config --global` keeps working),
`tmux` gets `-f`, and `starship` gets `STARSHIP_CONFIG`. All three behave the
same whether they arrive via the NixOS module or a bare `nix profile install`
on a machine that has never seen this repo - verified running with an empty
`$HOME` and nothing but the package on `PATH`.

direnv is the exception: its config is a shell hook, so it is a plain package
and `turbo/system.nix` installs the hook into zsh.

## Neovim

Ported from `github.com/dunncj/nvim`, with lazy.nvim and mason removed - nix
installs the plugins and the language servers, so there is no lock file to
drift and no downloaded binaries (mason ships dynamically-linked ones that do
not run on NixOS).

The lua lives in `nix/turbo/nvim` as ordinary files. `neovim.nix` bakes the
tree into the editor's wrapper, so `~/.config/nvim` is not consulted at all -
edit `nix/turbo/nvim/**` and run `nb`.

```
nvim/init.lua                 require("turbo")
nvim/lua/turbo/options.lua    editor options
nvim/lua/turbo/remap.lua      keymaps that are not plugin-specific
nvim/lua/turbo/plugins/       one file per plugin, each just its setup call
nvim/.luarc.json              root marker, see below
```

Leader is `<Space>`. `<leader>ff` find files, `<leader>gf` git files,
`<leader>fg` grep word under cursor, `<leader>ps` grep prompt, `<leader>vh`
help. On an LSP buffer: `gd` definition, `gr` references, `K` hover,
`<leader>rn` rename, `<leader>ca` code action, `<leader>lf` format, `[d`/`]d`
diagnostics. Completion is `C-n`/`C-p` to move, `C-y` to accept, `C-Space` to
summon.

`nvim/.luarc.json` is load-bearing. Because this repo is rooted at `$HOME`,
a language server that falls back to a `.git` root marker resolves to
`/home/turbo` and tries to index every file under it - lua_ls refuses outright.
The marker gives it a nearer root. Any other server that hits this needs the
same treatment.

## Repo scope

This repository is rooted at `$HOME`, but `.gitignore` ignores everything and
re-includes only `nix/` and `archive/`. That is deliberate: without it, `git add
-A` sweeps in Minecraft world saves, Steam blobs, shell histories, `.ssh/`, and
`.kube/config`.

Secrets are never committed. The WireGuard key is deployed out of band and read
from `/etc/wireguard/private.key`; only the peer's public key appears here.

## Formatting

All `.nix` files are formatted with `nixfmt` (the RFC 166 style):

```
nix run nixpkgs#nixfmt -- $(find nix -name '*.nix' -not -name 'hardware-configuration.nix')
```
