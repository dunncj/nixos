# `mesh` - the one command for running the node registry.
#
# Adding a machine is the workflow this exists for. There is an irreducible
# round trip in it -- a new node has to exist and be reachable before anyone
# can learn the host key that both pins it and lets it decrypt secrets -- so
# the goal here is not to remove the round trip but to make it one command
# that cannot be got subtly wrong:
#
#   mesh add-node myosis 100.64.0.4
#   nb                                  # on each machine, or `mesh deploy`
#
# Everything it writes goes into nix/nodes.nix and nix/.sops.yaml, which are
# reviewed and committed like any other change. Nothing is applied behind
# your back.
{
  lib,
  writeShellApplication,
  nixos-rebuild,
  openssh,
  ssh-to-age,
  sops,
  nix,
  gnused,
  gnugrep,
  gawk,
  coreutils,
  jq,
  flakePath,
  flakeUrl,
}:

writeShellApplication {
  name = "mesh";

  runtimeInputs = [
    nixos-rebuild
    openssh
    ssh-to-age
    sops
    nix
    gnused
    gnugrep
    gawk
    coreutils
    jq
  ];

  text = ''
    FLAKE_DIR=${flakePath}
    FLAKE_URL="${flakeUrl}"
    REGISTRY="$FLAKE_DIR/nodes.nix"
    SOPS_CONFIG="$FLAKE_DIR/.sops.yaml"
    SECRETS="$FLAKE_DIR/secrets/secrets.yaml"

    usage() {
        cat <<'USAGE'
    mesh - turbo's ssh mesh, driven by nix/nodes.nix

      mesh add-node <name> <address> [--untrusted]
                          scan the node's host key, derive its age recipient,
                          write both into nodes.nix, add it to .sops.yaml and
                          re-encrypt the secrets so it can decrypt them
      mesh list           show the registry: who is trusted, and by what key
      mesh check          re-run the flake's registry checks against the tree
      mesh sync <host>    install ~/.ssh/config.mesh and known_hosts.mesh on
                          a machine this flake does not build (the MacBook)
      mesh config         print that ssh config to stdout
      mesh known-hosts    print the registry's pinned host keys to stdout
      mesh rotate         generate a new mesh key, re-encrypt, and remind you
                          which machines must be rebuilt before which
      mesh deploy         tell every trusted NixOS node to switch to the
                          default branch now, then do the same here. Each node
                          builds it; nothing is copied between machines and no
                          machine's working tree is deployed

    Only public material is ever written to the repo. The mesh private key
    lives in nix/secrets/secrets.yaml, encrypted to the host keys listed in
    nix/.sops.yaml.
    USAGE
    }

    die() { echo "mesh: $*" >&2; exit 1; }

    # The registry is nix, so nix is what reads it. Emits one tab-separated row
    # per node:
    #
    #   name  trusted|untrusted  address  age  names  hostKey  system
    #
    # Every consumer below must name all seven fields even when it ignores
    # most of them. `read` puts the unconsumed remainder in the LAST variable,
    # so a loop that stops at hostKey would silently read "<key>\t<system>" as
    # the host key and write that into known_hosts.
    read_registry() {
        # builtins only, deliberately. This used to reach for nixpkgs' lib via
        # `import <nixpkgs> {}`, which made every subcommand depend on NIX_PATH
        # being set in the ambient environment. That is true in a login shell
        # and false almost everywhere else, so `mesh` worked when typed and
        # failed from a systemd unit, a timer or a non-interactive ssh with
        # nothing but "could not evaluate nodes.nix" to show for it. Nothing
        # here needs more than builtins.
        #
        # getAttr rather than r.nodes.<n>, because this whole script is a Nix
        # indented string and a literal dollar-brace would be interpolated by
        # Nix before the shell ever saw it.
        #
        # The trailing newline is load-bearing: nix eval --raw does not add
        # one, and the read loops below discard a final line that lacks it,
        # which silently drops whichever node sorts last.
        nix eval --impure --raw --expr "
          let
            r = import $REGISTRY;
            names = n: v: builtins.concatStringsSep \",\"
              ([ n (n + \".\" + r.domain) ] ++ v.addresses);
            row = n:
              let v = builtins.getAttr n r.nodes; in
              n + \"\t\" + (if v.trusted then \"trusted\" else \"untrusted\")
                + \"\t\" + (builtins.head v.addresses) + \"\t\" + v.age
                + \"\t\" + names n v + \"\t\" + v.hostKey
                + \"\t\" + v.system + \"\n\";
          in builtins.concatStringsSep \"\" (map row (builtins.attrNames r.nodes))
        " || die "could not evaluate $REGISTRY"
    }

    cmd_list() {
        printf '%-14s %-10s %-18s %s\n' NODE TRUST ADDRESS AGE-RECIPIENT
        read_registry | while IFS=$'\t' read -r name trust addr age _names _hk _sys; do
            printf '%-14s %-10s %-18s %s\n' "$name" "$trust" "$addr" "$age"
        done
    }

    cmd_add_node() {
        local name="''${1:-}" addr="''${2:-}" trusted=true
        [ -n "$name" ] && [ -n "$addr" ] || die "usage: mesh add-node <name> <address> [--untrusted]"
        [ "''${3:-}" = "--untrusted" ] && trusted=false

        grep -q "^    $name = {" "$REGISTRY" && die "$name is already in nodes.nix"

        echo ":: scanning $name at $addr"
        local hostkey
        hostkey=$(ssh-keyscan -t ed25519 -T 10 "$addr" 2>/dev/null | grep -v '^#' | head -1 | cut -d' ' -f2,3)
        [ -n "$hostkey" ] || die "no ed25519 host key from $addr -- is it up, and is sshd listening?"

        local age
        age=$(echo "$hostkey" | ssh-to-age) || die "could not derive an age recipient from that host key"

        echo "   host key  $hostkey"
        echo "   age       $age"

        # Built line by line with printf rather than a multi-line quoted
        # string: the shell body below is a Nix indented-string block, and a
        # closing quote at column 0 would set that block's minimum indentation
        # to zero. That silently switches off the dedent, which leaves
        # every heredoc terminator in this script indented, and therefore
        # inert.
        local entry
        entry=$(printf '%s\n' \
            "    $name = {" \
            "      description = \"Added by mesh add-node.\";" \
            "      trusted = $trusted;" \
            "      system = \"x86_64-linux\";" \
            "      addresses = [" \
            "        \"$addr\"" \
            "      ];" \
            "      hostKey = \"$hostkey\";" \
            "      age = \"$age\";" \
            "    };")

        # Trusted nodes go above the untrusted marker, untrusted ones below
        # it, so the file keeps saying at a glance which group a host is in.
        local anchor
        if [ "$trusted" = true ]; then
            anchor='^    # --- untrusted:'
        else
            anchor='^  };$'
        fi

        awk -v entry="$entry" -v anchor="$anchor" '
            $0 ~ anchor && !inserted { print entry; print ""; inserted = 1 }
            { print }
            END { if (!inserted) { print "mesh: anchor not found" > "/dev/stderr"; exit 1 } }
        ' "$REGISTRY" > "$REGISTRY.new" || die "could not place $name in nodes.nix"
        mv "$REGISTRY.new" "$REGISTRY"

        echo ":: wrote $name to nodes.nix"

        if [ "$trusted" = true ]; then
            # Both the anchor list and the creation rule need the recipient;
            # a node in only one of them fails in a confusing way later.
            sed -i "s|^  - \&admin |  - \&$name      $age\n  - \&admin |" "$SOPS_CONFIG"
            sed -i "0,/^          - \*admin$/s||          - *admin\n          - *$name|" "$SOPS_CONFIG"
            echo ":: added $name as a sops recipient"

            sops updatekeys --yes "$SECRETS" || die "sops updatekeys failed -- $name cannot decrypt yet"
            echo ":: re-encrypted secrets"
        else
            echo ":: $name is untrusted: no mesh key, no sops access, port 22 blocked both ways"
        fi

        cmd_check
        echo
        echo "next: review 'git -C $FLAKE_DIR diff', then rebuild the other nodes (mesh deploy)."
    }

    cmd_check() {
        echo ":: checking registry"
        nix flake check "path:$FLAKE_DIR" 2>&1 | grep -vE '^(warning|evaluating)' || true
    }

    cmd_sync() {
        local target="''${1:-}"
        local config known_hosts

        # Pinning every node's host key is the half that stops the
        # "REMOTE HOST IDENTIFICATION HAS CHANGED" prompts, so it travels with
        # the aliases rather than being left to first-use TOFU.
        known_hosts=$(cmd_known_hosts)

        config=$(
            echo "# Generated by 'mesh sync' from nix/nodes.nix. Do not edit."
            echo "# Host keys are pinned in known_hosts.mesh, alongside this file."
            echo
            read_registry | while IFS=$'\t' read -r name trust addr _g _names _hk _sys; do
                echo "Host $name"
                echo "  HostName $addr"
                echo "  UserKnownHostsFile ~/.ssh/known_hosts.mesh ~/.ssh/known_hosts"
                if [ "$trust" = trusted ]; then
                    echo "  User turbo"
                else
                    echo "  # untrusted in nodes.nix -- no mesh identity offered"
                fi
                echo
            done
        )

        # With no target, emit just the config: a machine this flake does not
        # build pulls the two halves separately over its own ssh session, so
        # each has to be usable verbatim as a file.
        #   ssh shambhala mesh config      > ~/.ssh/config.mesh
        #   ssh shambhala mesh known-hosts > ~/.ssh/known_hosts.mesh
        if [ -z "$target" ]; then
            printf '%s\n' "$config"
            return
        fi

        printf '%s\n' "$known_hosts" | ssh "$target" \
            'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat > ~/.ssh/known_hosts.mesh'
        printf '%s\n' "$config" | ssh "$target" 'cat > ~/.ssh/config.mesh'
        # shellcheck disable=SC2016
        ssh "$target" 'grep -q "^Include config.mesh" ~/.ssh/config 2>/dev/null || \
            { printf "Include config.mesh\n\n"; cat ~/.ssh/config 2>/dev/null; } > ~/.ssh/config.new && \
            mv ~/.ssh/config.new ~/.ssh/config'
        echo ":: wrote ~/.ssh/config.mesh and ~/.ssh/known_hosts.mesh on $target"
    }

    cmd_known_hosts() {
        read_registry | while IFS=$'\t' read -r _n _t _a _g names hostkey _sys; do
            echo "$names $hostkey"
        done
    }

    cmd_rotate() {
        echo "Rotating the mesh key invalidates every trusted node at once."
        echo "Order matters: rebuild all nodes BEFORE removing the old key, or"
        echo "a machine you have not reached yet becomes unreachable."
        echo
        read -r -p "continue? [y/N] " reply
        [ "$reply" = y ] || exit 1

        local tmp
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        ssh-keygen -t ed25519 -N ''' -C turbo@mesh -f "$tmp/id" >/dev/null

        sops set "$SECRETS" '["mesh"]["id_ed25519"]' "$(jq -Rs . < "$tmp/id")"
        sed -i "s|^  meshPublicKey = \".*\";|  meshPublicKey = \"$(cat "$tmp/id.pub")\";|" "$REGISTRY"

        echo ":: new mesh key written. Now: mesh deploy"
        echo "   the admin keys in nodes.nix remain valid throughout."
    }

    # Tell every node to build the default branch, and build it here too.
    #
    # This has now been wrong twice, so both failures are worth recording.
    #
    # It originally ran `nixos-rebuild --flake path:$FLAKE_DIR#$name` over ssh.
    # A path: is resolved where the command runs, so that deployed whatever the
    # remote happened to have checked out -- a deploy command that deploys a
    # different source per host.
    #
    # The fix for that was --target-host, building every host here and copying
    # the closures over. That fails on a live run:
    #
    #   error: cannot add path '...' because it lacks a signature by a
    #          trusted key
    #
    # The receiving daemon will not accept store paths from a user who is not
    # in trusted-users, and the ways to satisfy it are to grant turbo
    # root-equivalent nix trust on every host, to sign the closures, or to copy
    # as root -- which mesh.nix forbids with PermitRootLogin = "no".
    #
    # So: each node builds $FLAKE_URL itself. Every host compiles the same
    # commit rather than receiving it, nothing new is trusted anywhere, and the
    # source is the default branch rather than any machine's working tree --
    # including this one's. It is exactly what nixos-upgrade.timer does on each
    # host overnight, done now and in a known order.
    cmd_deploy() {
        local self
        self="$(hostname)"

        read_registry | while IFS=$'\t' read -r name trust addr _age _names _hk sys; do
            [ "$trust" = trusted ] || continue
            [ "$name" = "$self" ] && continue

            # nix-darwin is not nixos-rebuild's to drive, and an untrusted node
            # has no mesh key to let us in. Both are expected, so say so rather
            # than reporting a failure every single run.
            case "$sys" in
                *-linux) ;;
                *)
                    echo ":: $name -- skipped, $sys is not NixOS (see \`mesh sync\`)"
                    continue
                    ;;
            esac

            echo ":: $name"
            # Detached, because this switch restarts sshd and tailscaled and
            # the connection carrying it may not survive. Left attached, a
            # dropped link kills activation partway through. The PATH is load
            # bearing: nixos-rebuild shells out to coreutils and a transient
            # unit gets almost none.
            # shellcheck disable=SC2029
            ssh -n "turbo@$addr" "
                sudo systemctl reset-failed mesh-deploy 2>/dev/null || true
                sudo systemd-run --unit=mesh-deploy --service-type=oneshot \
                    --property=RemainAfterExit=yes \
                    --setenv=PATH=/run/wrappers/bin:/run/current-system/sw/bin \
                    --property=StandardOutput=journal \
                    --property=StandardError=journal \
                    /run/current-system/sw/bin/nixos-rebuild switch \
                        --flake '$FLAKE_URL#$name' --refresh
            " >/dev/null 2>&1 || true

            # systemd-run's own connection dies with the switch, so its exit
            # status says nothing. Ask the unit instead.
            #
            # Poll ActiveState, NOT `is-active`. RemainAfterExit=yes is what
            # makes the result readable after the switch finishes, and its
            # cost is that a succeeded oneshot stays "active" forever -- so
            # `while is-active` never terminates. The first version of this
            # did exactly that and hung after the first node, while the node
            # itself had finished in eighteen seconds.
            #
            # oneshot + RemainAfterExit gives three states worth distinguishing:
            # activating while it runs, active on success, failed on failure.
            # An unreachable host yields an empty string, which also ends the
            # loop rather than spinning forever on a machine that went away.
            while [ "$(ssh -n "turbo@$addr" 'systemctl show mesh-deploy -p ActiveState --value' 2>/dev/null)" = activating ]; do
                sleep 10
            done
            if ssh -n "turbo@$addr" 'systemctl is-failed --quiet mesh-deploy' 2>/dev/null; then
                echo "   FAILED -- ssh $name 'journalctl -u mesh-deploy -n 40'"
            else
                echo "   ok    $(ssh -n "turbo@$addr" 'readlink -f /run/current-system' 2>/dev/null | sed 's#.*-nixos-system-##')"
            fi
        done

        # Local last, so a broken deploy is noticed on the other machines
        # before it takes out the one running the command.
        echo ":: local"
        sudo nixos-rebuild switch --flake "$FLAKE_URL#$self" --refresh
    }

    case "''${1:-}" in
        add-node) shift; cmd_add_node "$@" ;;
        list)     cmd_list ;;
        check)    cmd_check ;;
        sync)         shift; cmd_sync "$@" ;;
        config)       cmd_sync ;;
        known-hosts)  cmd_known_hosts ;;
        rotate)   cmd_rotate ;;
        deploy)   cmd_deploy ;;
        -h|--help|help|"") usage ;;
        *) die "unknown subcommand '$1' (try: mesh help)" ;;
    esac
  '';

  meta.description = "Manage turbo's ssh mesh from nix/nodes.nix";
}
