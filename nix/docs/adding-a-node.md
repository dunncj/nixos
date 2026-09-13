# Adding a node

How to get a new machine onto the tailnet, into the registry, and trusted by
every other machine. For what the pieces are and why, see
[architecture.md](architecture.md).

There is an irreducible round trip in this: a node has to exist and be
reachable **before** anyone can learn its ssh host key, and that host key is
both what pins it and what lets it decrypt secrets. The steps below do not
remove the round trip, they just make each half unambiguous.

Throughout, `<name>` is the name the node will have in `nodes.nix` (e.g.
`myosis`) and `<addr>` is its tailnet address (e.g. `100.64.0.4`).

---

## 0. Prerequisites on the new machine

Before it can be added, the machine must:

1. **be on the tailnet** and have a stable address. Join it to headscale first;
   `tailscale status` on an existing node should list it.
2. **be running sshd** with an ed25519 host key. Confirm from an existing node:

   ```sh
   ssh-keyscan -t ed25519 <addr>
   ```

   If that prints nothing, sshd is not up or not reachable and nothing below
   will work.
3. **have a hostname matching its registry name.** Not enforced, but the shell
   prompt and the tailnet node name both read the system hostname, and a
   machine that disagrees with the registry is confusing later. On macOS set
   all three — `computerName`, `hostName`, `localHostName` — because macOS
   keeps three and they drift apart otherwise.

---

## 1. Register it

From any machine with a checkout (run this in the repo, as turbo):

```sh
mesh add-node <name> <addr>          # trusted
mesh add-node <name> <addr> --untrusted
```

That one command:

- scans the node's ed25519 host key with `ssh-keyscan`
- derives its age recipient from that key with `ssh-to-age`
- writes the `<name> = { ... }` attrset into `nodes.nix`, above the untrusted
  marker if trusted, below it if not
- adds the recipient to `.sops.yaml` — both the anchor list and the creation
  rule, because a node in only one of them fails confusingly later
- re-encrypts `secrets/secrets.yaml` with `sops updatekeys`, so the new node
  can decrypt
- runs `mesh check`

It refuses if the node is already in `nodes.nix`, and dies rather than
half-finishing if the host key cannot be scanned or `sops updatekeys` fails.

**Then edit the generated attrset.** `add-node` fills in a placeholder
description and assumes `x86_64-linux`. Set at minimum:

```nix
description = "...";        # shows up as a comment in every ssh_config
aliases = [ "xyz" ];        # short name; must be unique and not a node's name
system = "aarch64-darwin";  # if it is not x86_64-linux
```

Add the second address by hand if the node has IPv6 — `add-node` records only
the one you gave it.

Re-run `mesh check` after editing. It will fail the build on a duplicate
address, a duplicate alias, an alias shadowing a node name, or `.sops.yaml`
drifting from `trusted`.

---

## 2. Commit and push

```sh
git -C ~ add nix
git -C ~ commit -m "Add <name> to the mesh"
git -C ~ push
```

**`git add` is not optional here.** Flakes see only git-tracked files, so an
untracked `nodes.nix` change or a new `hosts/<name>/` directory is invisible to
every build — including yours. This is the single most common way the steps
below appear to fail for no reason.

Push before deploying: every machine builds from the default branch, not from
your working tree.

---

## 3. Deploy to the existing nodes

The other machines need the new registry before they will accept the new node
or know its name.

```sh
mesh deploy
```

This tells every trusted NixOS node to switch to the default branch, then does
the same locally. Darwin nodes are skipped with the command to run there
printed — sudo on macOS asks for a password, so it cannot be automated:

```sh
ssh <darwin-node> 'sudo darwin-rebuild switch --flake github:dunncj/nixos?dir=nix#<name> --refresh'
```

You can also just wait: both Linux hosts pull and switch nightly at 04:00.

---

## 4. Bring up the new node

Pick the section that matches what it is.

### NixOS

The node needs a host entry before the flake will build it.

1. On the new machine, capture its hardware:

   ```sh
   sudo nixos-generate-config --show-hardware-config \
     > /home/turbo/nix/hosts/<name>/hardware-configuration.nix
   ```

2. Write `hosts/<name>/configuration.nix`. Keep it to what is true of that
   machine only — the account, tools, mesh and secrets all arrive from
   `mkLinuxHost`. Set `networking.hostName`, `time.timeZone`, and
   `system.stateVersion` **to the release the machine was installed from**
   (it is not a "which nixpkgs am I on" knob).

3. Add it to `flake.nix`:

   ```nix
   nixosConfigurations.<name> = mkLinuxHost <name> {
     modules = [
       ./hosts/<name>/configuration.nix
       ./modules/desktop.nix     # optional, opt in per host
     ];
   };
   ```

   with a matching `<name> = { flakePath = "/home/turbo/nix"; hostName = "<name>"; };`
   in the `let` block.

4. **Commit and push both files**, then on the new machine:

   ```sh
   sudo nixos-rebuild switch --flake github:dunncj/nixos?dir=nix#<name> --refresh
   ```

   No checkout needed. The first switch is what installs the mesh key, so until
   it completes the node cannot be reached *from* other nodes — that is
   expected, not a fault. It *can* decrypt on that first switch, because
   `secrets.yaml` is encrypted to its ssh host key, which it already has.

   If the machine is remote and you are driving it over ssh, run the switch
   detached — it restarts sshd and tailscaled, and a dropped connection
   otherwise leaves activation half-applied:

   ```sh
   sudo systemctl stop mesh-deploy 2>/dev/null; sudo systemctl reset-failed mesh-deploy 2>/dev/null
   sudo systemd-run --unit=mesh-deploy --no-block --service-type=oneshot \
     --property=RemainAfterExit=yes \
     --setenv=PATH=/run/wrappers/bin:/run/current-system/sw/bin \
     /run/current-system/sw/bin/nixos-rebuild switch \
       --flake 'github:dunncj/nixos?dir=nix#<name>' --refresh
   ```

   The `PATH` is load-bearing: `nixos-rebuild` shells out to coreutils and a
   transient unit gets almost none, failing with
   `[Errno 2] No such file or directory: 'test'`. Watch it with
   `systemctl show mesh-deploy -p ActiveState --value` — `activating` while it
   runs, `active` on success, `failed` on failure.

5. Afterwards, `nb` works on that machine like any other.

### macOS (nix-darwin)

1. Add a `hosts/<name>/configuration.nix` and a `darwinConfigurations.<name>`
   entry modelled on `amarout`, including `./modules/mesh-darwin.nix` and
   `{ mesh.self = "<name>"; }`.
2. Commit and push.
3. On the Mac:

   ```sh
   sudo darwin-rebuild switch --flake github:dunncj/nixos?dir=nix#<name> --refresh
   ```

Remote Login must be on for other nodes to reach it. Note that this machine
will **not** self-upgrade — nix-darwin has no `system.autoUpgrade`.

### Any other machine with nix (not NixOS, not nix-darwin)

You get the tools and the shell, but not the mesh — there is no module system
to apply it:

```sh
nix profile install github:dunncj/nixos?dir=nix#turbo
echo 'eval "$(turbo-shell-init)"' >> ~/.zshrc
```

For ssh aliases and pinned host keys on such a machine, from a node that has a
checkout:

```sh
mesh sync <host>          # writes both files and adds the Include
```

or pull the two halves yourself:

```sh
ssh shambhala mesh config      > ~/.ssh/config.mesh
ssh shambhala mesh known-hosts > ~/.ssh/known_hosts.mesh
# then, at the top of ~/.ssh/config:
Include config.mesh
```

To be reachable *from* the mesh, add the mesh public key (in `nodes.nix` as
`meshPublicKey`) to that machine's `~/.ssh/authorized_keys` by hand.

---

## 5. Verify

From an existing node:

```sh
mesh list                                  # the node appears, with the right trust
ssh <alias> hostname                        # reaches it, by short name
ssh <alias> 'systemctl --failed --no-legend --plain | wc -l'   # 0
```

From the new node, back the other way:

```sh
ssh sam hostname
```

That last one matters more than it looks: it proves the node holds the mesh
key, that its `known_hosts` pin accepts the alias, and that the other end
authorised it. On a trusted NixOS node also confirm the secret landed:

```sh
sudo ls -l /run/secrets/mesh/    # id_ed25519, 0600, owned by turbo
```

---

## Removing a node

Set `trusted = false` in `nodes.nix` and deploy. That removes the mesh key from
its `authorized_keys`, removes its sops recipient at the next
`sops updatekeys`, and adds a two-way port 22 block on every NixOS node — while
keeping its name and host key pinned, which is usually what you want for a
machine that still exists.

Deleting the attrset entirely also works, but then nothing resolves or verifies
it and you get first-use TOFU prompts instead.

**Neither revokes the key the node already holds.** A node that was trusted has
a copy of the shared mesh private key on disk. If the machine is lost rather
than merely demoted, rotate:

```sh
mesh rotate      # generates a new key, re-encrypts, prompts first
mesh deploy      # BEFORE the old key stops being accepted anywhere
```

Order matters: deploy everywhere while both keys still work, or a machine you
have not reached yet becomes unreachable. The admin keys in `nodes.nix` stay
valid throughout and are the way back in if this goes wrong — never let that
list reach zero, which the mesh module asserts.
