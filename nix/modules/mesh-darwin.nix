# The mesh, for a nix-darwin node. The same ../nodes.nix, the same trust flag,
# mapped onto what macOS and nix-darwin can actually express. See ./mesh.nix
# for the NixOS original; this file only records where the two differ.
#
#   authorized_keys   same: mesh key + admin keys, if this node is trusted
#   known_hosts       same: every node's host key, pinned, under every name
#   ssh client config same aliases, but with this Mac's own key (see below)
#   sshd              Remote Login on, keys only, registry is the only source
#
# What it does not do, and why:
#
#   /etc/hosts        nix-darwin has no networking.hosts. The client aliases
#                     below dial addresses directly, so `ssh myosis` does not
#                     need it; only bare `ping myosis` does, via MagicDNS.
#   firewall          no iptables. The credential side of isolation still
#                     holds: untrusted nodes have no key this Mac accepts.
#   sops mesh key     not needed to dial out. This Mac's own ~/.ssh/id_ed25519
#                     is in adminKeys, so every node already accepts it, and
#                     decrypting the shared key onto that same path would
#                     overwrite it.
#
# It replaces `mesh sync` / ~/.ssh/config.mesh for this machine: those were the
# stopgap for a node this flake did not build, and it builds this one now.
{
  config,
  lib,
  ...
}:

let
  cfg = config.mesh;
  registry = import ../nodes.nix;

  inherit (registry) domain meshPublicKey adminKeys;

  trusted = lib.filterAttrs (_: n: n.trusted) registry.nodes;
  untrusted = lib.filterAttrs (_: n: !n.trusted) registry.nodes;

  # Same naming as ./mesh.nix, aliases included, so `ssh sam` means the same
  # thing here as on the Linux boxes.
  aliasesOf = node: node.aliases or [ ];
  namesOf = name: node: [ name ] ++ aliasesOf node ++ [ "${name}.${domain}" ] ++ node.addresses;
  hostLine = name: node: lib.concatStringsSep " " ([ name ] ++ aliasesOf node ++ [ "${name}.${domain}" ]);
in
{
  options.mesh = {
    enable = lib.mkEnableOption "turbo's ssh mesh" // {
      default = true;
    };

    self = lib.mkOption {
      type = lib.types.str;
      example = "amarout";
      description = "This node's key in ../nodes.nix.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = registry.nodes ? ${cfg.self};
        message = "mesh.self = \"${cfg.self}\" is not a node in nix/nodes.nix.";
      }
      {
        assertion = adminKeys != [ ];
        message = "nix/nodes.nix: adminKeys is empty. Refusing to build.";
      }
    ];

    # --- identity -----------------------------------------------------------
    #
    # This is what the other nodes were missing: they present the shared mesh
    # key, and until now nothing on this Mac authorised it.
    users.users.turbo.openssh.authorizedKeys.keys =
      adminKeys ++ lib.optional (trusted ? ${cfg.self}) meshPublicKey;

    # --- names --------------------------------------------------------------
    programs.ssh.knownHosts = lib.mapAttrs (name: node: {
      hostNames = namesOf name node;
      publicKey = node.hostKey;
    }) registry.nodes;

    # --- client config ------------------------------------------------------
    programs.ssh.extraConfig = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: node: ''
        # ${node.description}
        Host ${hostLine name node}
          HostName ${lib.head node.addresses}
          User turbo
          IdentityFile ~/.ssh/id_ed25519
          IdentitiesOnly yes
      '') (lib.filterAttrs (name: _: name != cfg.self) trusted)
      ++ lib.mapAttrsToList (name: node: ''
        # ${node.description}
        # Untrusted in ../nodes.nix: named for convenience, no identity offered.
        Host ${hostLine name node}
          HostName ${lib.head node.addresses}
      '') untrusted
    );

    # --- sshd ---------------------------------------------------------------
    services.openssh = {
      # Remote Login, as the Sharing pane calls it.
      enable = true;

      # Drop-ins are read before the rest of sshd_config and the first value
      # wins, so these hold over Apple's defaults.
      #
      # AuthorizedKeysFile none is the darwin spelling of mesh.nix's
      # authorizedKeysFiles = mkForce [...]: the registry, via nix-darwin's
      # AuthorizedKeysCommand, is the only place a key can come from.
      extraConfig = ''
        PasswordAuthentication no
        KbdInteractiveAuthentication no
        PermitRootLogin no
        AuthorizedKeysFile none
      '';
    };
  };
}
