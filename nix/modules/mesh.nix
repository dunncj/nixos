# The mesh: every trusted node reaches every other trusted node over ssh, by
# name, with no per-machine hand-editing and no key material in the repo.
#
# Everything here is derived from ../nodes.nix. That file is the only thing
# you edit; this one turns it into:
#
#   authorized_keys   the shared mesh key + the admin keys, on trusted nodes
#   known_hosts       every node's host key, pinned, under every name it has
#   /etc/hosts        every node's names, so lookups survive headscale being
#                     down (MagicDNS is still accepted, it is just not relied on)
#   ssh client config `ssh myosis` works as turbo, with the right identity
#   firewall          untrusted nodes blocked on port 22, both directions
#   sops              the mesh private key, decrypted per-node to ~/.ssh
#
# The shape to keep in mind: trust is a property of the *node*, declared once
# in the registry, and every one of those six outputs reads that same flag.
# There is no second place where a node can be half-trusted.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.mesh;
  registry = import ../nodes.nix;

  inherit (registry) domain meshPublicKey adminKeys;

  # Only nodes that opted in. `trusted = false` nodes stay in `registry.nodes`
  # -- their host keys and names are still useful -- but they are absent from
  # every trust decision below.
  trusted = lib.filterAttrs (_: n: n.trusted) registry.nodes;
  untrusted = lib.filterAttrs (_: n: !n.trusted) registry.nodes;

  # Every name a node answers to: bare hostname first (what you type), then
  # the MagicDNS FQDN, then the raw addresses.
  namesOf = name: node: [ name "${name}.${domain}" ] ++ node.addresses;

  isIPv6 = addr: lib.hasInfix ":" addr;
in
{
  options.mesh = {
    enable = lib.mkEnableOption "turbo's ssh mesh" // {
      default = true;
    };

    flakePath = lib.mkOption {
      type = lib.types.str;
      default = "/home/turbo/nix";
      description = "Where this flake lives on the node, for the `mesh` command to edit.";
    };

    self = lib.mkOption {
      type = lib.types.str;
      example = "shambhala";
      description = ''
        This node's key in ../nodes.nix. Determines whether the node receives
        the mesh private key: a node that is not itself trusted gets the
        known_hosts and /etc/hosts entries but no credentials.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = registry.nodes ? ${cfg.self};
        message = "mesh.self = \"${cfg.self}\" is not a node in nix/nodes.nix.";
      }
      {
        # The registry comment says never let this reach zero; enforce it,
        # because the failure mode is a headless box nobody can log into.
        assertion = adminKeys != [ ];
        message = "nix/nodes.nix: adminKeys is empty, which would leave every node reachable only by the mesh key. Refusing to build.";
      }
    ];

    # --- identity -----------------------------------------------------------
    #
    # Trusted nodes authorise the one shared mesh key, plus the admin keys as
    # the floor. Untrusted nodes get the admin keys only, so `trusted = false`
    # genuinely removes a machine's ability to log in anywhere -- it has no
    # mesh key on disk to present.
    users.users.turbo.openssh.authorizedKeys.keys =
      adminKeys ++ lib.optional (trusted ? ${cfg.self}) meshPublicKey;

    # --- names --------------------------------------------------------------
    #
    # Written for every node, trusted or not: being able to resolve and verify
    # teyos is orthogonal to being allowed to log into it.
    networking.hosts = lib.mkMerge (
      lib.mapAttrsToList (
        name: node:
        lib.listToAttrs (
          map (addr: lib.nameValuePair addr [
            name
            "${name}.${domain}"
          ]) node.addresses
        )
      ) registry.nodes
    );

    # Host key pinning, so a rebuilt node produces a loud, correct error
    # instead of the interactive "REMOTE HOST IDENTIFICATION HAS CHANGED"
    # prompt that trains you to delete known_hosts lines without reading them.
    programs.ssh.knownHosts = lib.mapAttrs (name: node: {
      hostNames = namesOf name node;
      publicKey = node.hostKey;
    }) registry.nodes;

    # --- client config ------------------------------------------------------
    programs.ssh.extraConfig = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: node: ''
        # ${node.description}
        Host ${name} ${name}.${domain}
          HostName ${lib.head node.addresses}
          User turbo
          IdentityFile /home/turbo/.ssh/id_ed25519
          IdentitiesOnly yes
      '') trusted
      ++ lib.mapAttrsToList (name: node: ''
        # ${node.description}
        # Untrusted: named for convenience, but ../nodes.nix marks it outside
        # the mesh and the firewall below blocks port 22 to it.
        Host ${name} ${name}.${domain}
          HostName ${lib.head node.addresses}
      '') untrusted
    );

    # --- secrets ------------------------------------------------------------
    #
    # Each node decrypts with its own ssh host key, so there is no bootstrap
    # key to copy around: a machine that is in the tailnet already has the
    # identity it needs. Adding a node is `mesh add-node`, which appends its
    # host key as a recipient and re-encrypts.
    sops = {
      defaultSopsFile = ../secrets/secrets.yaml;
      age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

      secrets = lib.mkIf (trusted ? ${cfg.self}) {
        "mesh/id_ed25519" = {
          owner = "turbo";
          group = "users";
          mode = "0600";
          path = "/home/turbo/.ssh/id_ed25519";
        };
      };
    };

    # sops writes the key as a symlink into this directory; ssh will not use an
    # identity whose directory is group- or world-writable.
    systemd.tmpfiles.rules = [
      "d /home/turbo/.ssh 0700 turbo users -"
    ];

    # The public half is not a secret and does not need decrypting, so it is
    # written directly. ssh-copy-id and `ssh -i` both want it present.
    environment.etc."ssh/mesh_id_ed25519.pub".text = meshPublicKey + "\n";

    # --- isolation ----------------------------------------------------------
    #
    # The registry already denies untrusted nodes any usable credential, so
    # this is defence in depth rather than the primary control: it means a
    # stolen mesh key on teyos still does not open a session, and it stops
    # this node from being talked into dialling out to one of them.
    #
    # Inserted at the head of nixos-fw so it precedes the accept rules the
    # openssh module adds.
    networking.firewall.extraCommands = lib.concatStringsSep "\n" (
      lib.flatten (
        lib.mapAttrsToList (
          name: node:
          map (addr: let ipt = if isIPv6 addr then "ip6tables" else "iptables"; in ''
            # ${name}: outside the mesh (nix/nodes.nix)
            ${ipt} -I nixos-fw 1 -p tcp --dport 22 -s ${addr} -j nixos-fw-refuse
            ${ipt} -I OUTPUT 1 -p tcp --dport 22 -d ${addr} -j REJECT
          '') node.addresses
        ) untrusted
      )
    );

    networking.firewall.extraStopCommands = lib.concatStringsSep "\n" (
      lib.flatten (
        lib.mapAttrsToList (
          name: node:
          map (addr: let ipt = if isIPv6 addr then "ip6tables" else "iptables"; in ''
            ${ipt} -D nixos-fw -p tcp --dport 22 -s ${addr} -j nixos-fw-refuse 2>/dev/null || true
            ${ipt} -D OUTPUT -p tcp --dport 22 -d ${addr} -j REJECT 2>/dev/null || true
          '') node.addresses
        ) untrusted
      )
    );

    # The registry is only as good as the tool that maintains it; ship them
    # together so a node can never have one without the other.
    environment.systemPackages = [
      (pkgs.callPackage ./mesh-cli.nix { inherit (cfg) flakePath; })
    ];

    # --- sshd ---------------------------------------------------------------
    services.openssh = {
      enable = true;
      # The registry is the ONLY source of authorised keys. By default sshd
      # also reads ~/.ssh/authorized_keys, which is untracked and gitignored --
      # and which on shambhala still contained root@agartha-tunnel long after
      # it was removed from the repo. Narrowing this to the managed path is
      # what makes `trusted = false` in ../nodes.nix actually mean something:
      # otherwise a key can outlive every declaration of it.
      authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];

      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    # MagicDNS is accepted so short names keep working for nodes that are in
    # the tailnet but not yet in the registry. /etc/hosts above is what makes
    # the registry's own names independent of it.
    services.tailscale.extraUpFlags = [ "--accept-dns=true" ];
  };
}
