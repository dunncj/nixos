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
    k3s.nix                        single-node k3s server
    sunshine.nix                   synthetic EDID so headless capture works
    power.nix                      forbids sleep and display blanking
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

`nb` wraps `nixos-rebuild` for two reasons: it uses `path:` rather than a bare
`~/nix` so nix does not copy this whole repo into the store on every build, and
it re-execs systemd afterwards so a dbus restart cannot leave `reboot` silently
doing nothing.

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
