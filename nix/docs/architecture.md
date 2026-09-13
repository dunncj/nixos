# How this repo works

One flake builds three machines and a portable environment. This document
describes the parts and, where a decision was not obvious, why it was made
that way. For the step-by-step of joining a machine to the mesh, see
[adding-a-node.md](adding-a-node.md).

## The shape in one paragraph

`nodes.nix` is a registry of machines. Two modules read it — `modules/mesh.nix`
on NixOS, `modules/mesh-darwin.nix` on macOS — and derive everything about who
can reach whom: authorized keys, pinned host keys, name resolution, ssh client
aliases, firewall isolation, and which machines can decrypt secrets. Secrets
are encrypted with sops to each node's **ssh host key**, so a machine already
in the tailnet needs no bootstrap credential. Every host builds itself from the
default branch on GitHub, on a timer, so no machine's working tree decides what
another machine runs.

## The registry

`nodes.nix` is the single source of truth. Nothing downstream is hand-edited.

```nix
myosis = {
  description = "Cameron's workstation. ...";  # appears as a comment in ssh_config
  aliases = [ "myo" ];                          # extra names, everywhere a name is used
  trusted = true;                               # the one flag that drives all of it
  system = "x86_64-linux";                      # used by `mesh deploy` to pick a rebuild tool
  addresses = [ "100.64.0.4" "fd7a:115c:a1e0::4" ];
  hostKey = "ssh-ed25519 AAAA...";              # pinned in known_hosts
  age = "age1yglm8...";                         # derived from hostKey; the sops recipient
};
```

`hostKey` and `age` are public by construction — a stranger gets the first from
`ssh-keyscan` and the second is derived from it — so this file is safe in a
public repo. The only private key in the system is the shared mesh identity,
encrypted in `secrets/secrets.yaml`.

### What `trusted` drives

One flag, six outputs, no second place a node can be half-trusted:

| output | trusted node | untrusted node |
|---|---|---|
| `authorized_keys` | mesh key + admin keys | admin keys only |
| `known_hosts` | pinned | pinned |
| `/etc/hosts` | written | written |
| ssh client alias | with identity | named only, no identity offered |
| firewall | — | port 22 rejected, both directions |
| sops recipient | yes | no |

Resolving and verifying a machine is orthogonal to being allowed to log into
it, which is why untrusted nodes still get names and pinned host keys. `teyos`
(the headscale control plane) and `tunnel` (the WireGuard VPS) are both
`trusted = false`: they are internet-facing, and the tailnet depending on
teyos is a reason to pin it, not a reason to trust it.

### Aliases

Each node has short aliases (`sam`, `myo`, `ama`, `tey`, `tun`). They are
spelled out per node rather than derived from a prefix, because a derived rule
gives shambhala `sha` and the wanted name is `sam` — a rule with an exception
in it is worse than a list.

They are real names everywhere, not a shell shortcut: the ssh client config,
`/etc/hosts`, *and* the pinned `known_hosts` entry. That last one is the reason
this lives in nix rather than `~/.ssh/config` — an alias that resolves but is
absent from the pinned host names produces a host-key verification failure,
which looks exactly like an attack and trains you to ignore the warning that
matters.

### What the check enforces

`modules/registry-check.nix` runs as a flake check, so it needs no machine:

- a node with a missing or malformed `hostKey`/`age`/`addresses`
- an address claimed by more than one node
- an alias claimed by more than one node, or shadowing a node's name
- **`.sops.yaml` drifting from `trusted`**, in both directions — a trusted node
  missing from it silently loses ssh at its next rebuild; an untrusted node
  present in it can decrypt the mesh key, which is the thing `trusted = false`
  exists to prevent
- zero trusted nodes

Run it with `mesh check`, which is `nix flake check` against the working tree.

## Secrets

sops-nix, with each node decrypting using its own **ssh host key**
(`/etc/ssh/ssh_host_ed25519_key`, converted to an age identity). That is what
makes adding a node cheap: a machine already in the tailnet already holds the
credential it needs, so there is no bootstrap key to hand-carry.

- `.sops.yaml` lists recipients: the admin age key plus every trusted node.
- `secrets/secrets.yaml` holds the shared mesh private key and shambhala's
  WireGuard key. It is committed, encrypted.
- The admin key is at `~/.config/sops/age/keys.txt`, **outside the repo**. It
  exists so secrets can be edited from a checkout without root on any
  particular machine.

### The mesh key, and why it is shared

One key that every trusted node authorises and holds, rather than one key per
node. The mesh is all-trust-all by design, so per-node keys would not shrink
the blast radius of a compromise — they would only mean that adding the (N+1)th
node requires rebuilding the other N before it can talk to any of them. With
one key, a new node decrypts and is immediately reachable both ways.

The cost is that revocation is all-or-nothing. `mesh rotate` generates a new
key, re-encrypts, and tells you to deploy everywhere **before** the old key
stops being accepted. The admin keys in `nodes.nix` stay valid throughout and
are the anti-lockout floor; the mesh module asserts that list is never empty.

## Hosts

`mkLinuxHost` in `flake.nix` gives every NixOS host the same base: `base.nix`,
`rebuild.nix`, `autoupgrade.nix`, sops, `mesh.nix` with `mesh.self` set, and
the `turbo` module. A host config then holds only what is true of that machine,
and `flake.nix` lists the optional modules it opts into.

| | shambhala | myosis | amarout |
|---|---|---|---|
| platform | NixOS | NixOS | nix-darwin |
| mesh | `mesh.nix` | `mesh.nix` | `mesh-darwin.nix` |
| desktop | yes (headless, for Sunshine capture) | yes | n/a |
| extra | k3s, sunshine, power, wireguard | nvidia, wireguard | — |
| self-upgrades | yes, nightly | yes, nightly | **no** — see below |

### What macOS cannot do

`mesh-darwin.nix` is the nix-darwin counterpart and covers authorized keys,
pinned host keys, the client config and sshd hardening. Four things it
deliberately does not carry, each for a reason recorded in its header:

- **`/etc/hosts`** — nix-darwin has no `networking.hosts`. The client aliases
  dial addresses directly, so `ssh myo` works without it; only a bare `ping
  myo` needs MagicDNS.
- **firewall isolation** — no iptables. The credential half still holds:
  untrusted nodes have no key the Mac accepts.
- **the sops mesh key** — not needed to dial out. The Mac's own key is in
  `adminKeys`, so every node already accepts it, and decrypting the shared key
  onto `~/.ssh/id_ed25519` would overwrite the Mac's own identity.
- **`system.autoUpgrade`** — nix-darwin has no equivalent, so amarout does not
  self-converge and must be rebuilt by hand.

One line in it looks alarming and is correct: `AuthorizedKeysFile none`
alongside `PasswordAuthentication no`. nix-darwin delivers keys through
`AuthorizedKeysCommand /bin/cat /etc/ssh/nix_authorized_keys.d/%u`, not through
a file, so the two do not collide — and the effect is the same as NixOS's
`authorizedKeysFiles = mkForce [...]`: the registry becomes the only place a
key can come from.

## Deploying

Three paths, all building the same source:

```
nb                 build this host from the local working tree, and switch
nb pull            build this host from the default branch on GitHub, and switch
mesh deploy        tell every trusted NixOS node to do `nb pull`, then do it here
```

`nb` reads `turbo.flakePath` and `turbo.hostName`, so the same module is
correct on every host. It uses `path:` rather than a bare `~/nix` — see [Repo
scope](#repo-scope) — and re-execs systemd afterwards, because a switch that
restarts dbus otherwise leaves PID 1 with a dead bus connection and `reboot`
silently doing nothing.

`mesh deploy` does **not** copy closures between machines. It did once, via
`nixos-rebuild --target-host`, and that requires the receiving daemon to accept
store paths from a user in `trusted-users` — which is root-equivalent. Each
node builds the default branch itself instead: nothing new is trusted anywhere,
and the source is the default branch rather than any machine's working tree,
including that of whoever typed the command. Each remote switch runs detached
under `systemd-run`, because it restarts sshd and tailscaled and the connection
carrying it may not survive.

`mesh deploy` skips darwin nodes and prints the `darwin-rebuild` command
instead: sudo on macOS asks for a password, so it cannot be driven
non-interactively.

### Unattended

`modules/autoupgrade.nix` points `system.autoUpgrade` at
`github:dunncj/nixos?dir=nix#<host>` — the flake reference, not a checkout, so
a stale or dirty working tree on a machine cannot change what it deploys.
04:00 with 45 minutes of jitter, `persistent` so a machine that was off catches
up rather than skipping a day.

`allowReboot = false`: a kernel or initrd change waits for a reboot someone
chose. `operation = "switch"`, so a bad deploy breaks while the previous
generation is still the boot default and `nb rollback` is one command.

The trade is real and worth stating: anything pushed to the default branch
reaches every Linux host within a day without anyone deciding to deploy it.

## The turbo environment

`turbo/` is the account, the tools and the editor, kept free of anything
host-specific. It reaches three kinds of machine:

| target | how |
|---|---|
| NixOS | `nixosModules.turbo` — the account, the package, zsh |
| nix-darwin | the package in `environment.systemPackages` + `turbo/shell.nix` |
| anything with nix | `nix profile install github:dunncj/nixos?dir=nix#turbo` |

Built for `x86_64-linux`, `aarch64-linux`, `x86_64-darwin` and
`aarch64-darwin` — an output that does not exist for a machine's architecture
is not portable in any useful sense.

### Why wrappers instead of dotfiles

`programs.git`, `programs.tmux`, `programs.starship` and `programs.direnv` all
push their package into `environment.systemPackages`, which would put them on
root's PATH. Wrapping them keeps them in turbo's profile only, and makes them
portable: `git` gets `GIT_CONFIG_SYSTEM` (so a personal `~/.gitconfig` still
layers on top), `tmux` gets `-f`, `starship` gets `STARSHIP_CONFIG`.

### The shell, on three platforms

zsh was the one thing a derivation could not deliver: a login shell reads
`~/.zshrc` or `/etc/zshrc`, and a package may write neither. So the shell
config lived in the NixOS module — which meant the one kind of machine the
portable package exists for was the one kind that could not have it.

`turbo/shell-init.nix` holds the text as plain strings, deliberately **not** a
module, because a NixOS module cannot be imported by a Debian box with nix
installed. Three consumers:

```
NixOS        turbo/shell.nix  -> programs.zsh          (/etc/zshrc)
nix-darwin   turbo/shell.nix  -> programs.zsh          (/etc/zshrc)
anything     turbo/package.nix -> share/turbo/zshrc    (sourced from ~/.zshrc)
             else                and `turbo-shell-init`
```

What stays NixOS-only is what has no nix-darwin equivalent: `histSize`,
`setOptions`, autosuggestions, syntax highlighting.

## WireGuard

`modules/wireguard.nix` is shared; each host sets `tunnel.address`, and there
is no default because a silent default would be an address collision that
looks like packet loss rather than a config error.

`tunnel.privateKeySecret` names a sops secret, or is `null` to fall back to
`/etc/wireguard/private.key` placed by hand. The choice is deliberately not
defaulted — shambhala's key was previously at that path, mode `0644`, readable
by every user on the box. Keys are per-host: two peers sharing one private key
share a public key, and the VPS cannot tell them apart.

## Repo scope

This repository is rooted at `$HOME`, and `.gitignore` ignores everything then
re-includes only `nix/` and `archive/`. Without it, `git add -A` sweeps in
Minecraft saves, Steam blobs, shell histories, `.ssh/` and `.kube/config`.

Two consequences worth knowing, because both have cost real time:

**Flakes see only git-tracked files.** A file that exists on disk but is
untracked is invisible to the flake. This has bitten twice: a host with a
present-but-untracked `hardware-configuration.nix` silently did not exist as a
`nixosConfiguration`, and a finished `mesh-darwin.nix` sat untracked in a
working tree while the machine it configured ran it and GitHub had never heard
of it. **`git add` is part of making a change, not part of finishing it.**

**A bare `.#` inside `~/nix` resolves to `git+file:///home/turbo?dir=nix`** —
the whole tracked home tree, not the flake directory. That copies all of
`~/archive` into the store to evaluate a config that references none of it, and
reports the tree "dirty" whenever anything anywhere in the repo is uncommitted.
`nb` uses `path:` to avoid it, a `nixos` registry alias gives every other nix
command the same, and `warn-dirty` is off because with `path:` builds the flag
is not describing what is being built.

## Formatting

```
nix run nixpkgs#nixfmt -- $(find nix -name '*.nix' -not -name 'hardware-configuration.nix')
```
