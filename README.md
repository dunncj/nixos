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
    turbo.nix                      the turbo account, and nothing else
    k3s.nix                        single-node k3s server
    sunshine.nix                   synthetic EDID so headless capture works
    power.nix                      forbids sleep and display blanking
  turbo/tools.nix                  shared CLI tool list
  turbo/neovim.nix                 the editor as one derivation
  turbo/home.nix                   home-manager module (tools + dotfiles)
  turbo/package.nix                the same, as a standalone package
  turbo/nvim/                      neovim config, as real .lua files
  k3s/, services/                  workload manifests, applied by hand

archive/titan/                     previous host's config; not built by anything
```

## Layering

The system config stays as minimal as it can be. Root gets no conveniences -
no git, no editor, no tmux. Everything this user works with lives in the
`turbo` home-manager profile at `nix/turbo/home.nix`, because that profile is
what makes a machine turbo's and it has to be the single place that defines
that environment.

So: new packages and program config go in `turbo/home.nix`. The system layer
gets something only when it genuinely cannot work otherwise - a service, a
hardware option, or `programs.zsh.enable`, which NixOS requires before zsh can
be a login shell.

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
anything specific to agartha. Three files are shared by every consumer, which
is what stops the module and the package from drifting apart:

```
turbo/tools.nix     the CLI tool list
turbo/neovim.nix    the editor as one derivation - plugins, lua tree and
                    language servers all baked into the wrapper
turbo/nvim/         the lua, as ordinary files
turbo/home.nix      home-manager module: the above, plus the dotfiles
turbo/package.nix   the above, minus the dotfiles, as a single package
```

The flake exposes four ways to consume it:

| output | for |
|---|---|
| `nixosConfigurations.agartha` | this box; `nb` |
| `homeModules.turbo` | another NixOS machine: `home-manager.users.turbo = inputs.agartha.homeModules.turbo;` |
| `homeConfigurations.turbo` | a Linux box that is not NixOS: `home-manager switch --flake .#turbo` |
| `packages.x86_64-linux.turbo` | any machine with nix: `nix profile install github:dunncj/nixos?dir=nix#turbo` |

`turbo.flakePath` and `turbo.hostName` are the only host-dependent options.
They tell nixd which flake to evaluate for NixOS and home-manager option
completion; leave them null on a machine this repo does not build and nixd
still runs without it.

### What the package can and cannot do

The editor is complete: it carries its plugins, lua and language servers
inside the wrapper, needs nothing in `$HOME`, and ignores `~/.config/nvim`
entirely. It is byte-identical whether it arrives via the module or the
package - the same store path either way.

The shell dotfiles are not in the package. zsh, git and tmux read their config
from `$HOME`, and writing to `$HOME` is an activation step, which is not
something a derivation may do. That is the one job home-manager is actually
needed for; everything else here would work without it.

## Neovim

Ported from `github.com/dunncj/nvim`, with lazy.nvim and mason removed - nix
installs the plugins and the language servers, so there is no lock file to
drift and no downloaded binaries (mason ships dynamically-linked ones that do
not run on NixOS).

The lua lives in `nix/turbo/nvim` as ordinary files. `home-manager` writes
`init.lua` to `~/.config/nvim/init.lua` and symlinks the `lua/` tree beside
it, so edit `nix/turbo/nvim/**` and run `nb`.

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
