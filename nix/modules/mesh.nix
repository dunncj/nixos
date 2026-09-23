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

  trusted = lib.filterAttrs (_: n: n.trusted) registry.nodes;
  untrusted = lib.filterAttrs (_: n: !n.trusted) registry.nodes;

  aliasesOf = node: node.aliases or [ ];

  namesOf = name: node: [ name ] ++ aliasesOf node ++ [ "${name}.${domain}" ] ++ node.addresses;

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

    flakeUrl = lib.mkOption {
      type = lib.types.str;
      default = "github:dunncj/nixos?dir=nix";
      description = ''
        Where this flake lives upstream. `mesh deploy` tells each node to
        switch to this reference, so every host builds the same commit and no
        machine's working tree -- including the one running the command --
        decides what the others get.
      '';
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
        assertion = adminKeys != [ ];
        message = "nix/nodes.nix: adminKeys is empty, which would leave every node reachable only by the mesh key. Refusing to build.";
      }
    ];

    users.users.turbo.openssh.authorizedKeys.keys =
      adminKeys ++ lib.optional (trusted ? ${cfg.self}) meshPublicKey;

    networking.hosts = lib.mkMerge (
      lib.mapAttrsToList (
        name: node:
        lib.listToAttrs (
          map (
            addr:
            lib.nameValuePair addr (
              [ name ] ++ aliasesOf node ++ [ "${name}.${domain}" ]
            )
          ) node.addresses
        )
      ) registry.nodes
    );

    programs.ssh.knownHosts = lib.mapAttrs (name: node: {
      hostNames = namesOf name node;
      publicKey = node.hostKey;
    }) registry.nodes;

    programs.ssh.extraConfig = lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: node: ''
        # ${node.description}
        Host ${lib.concatStringsSep " " ([ name ] ++ aliasesOf node)} ${name}.${domain}
          HostName ${lib.head node.addresses}
          User turbo
          IdentityFile /home/turbo/.ssh/id_ed25519
          IdentitiesOnly yes
      '') trusted
      ++ lib.mapAttrsToList (name: node: ''
        # ${node.description}
        # Untrusted: named for convenience, but ../nodes.nix marks it outside
        # the mesh and the firewall below blocks port 22 to it.
        Host ${lib.concatStringsSep " " ([ name ] ++ aliasesOf node)} ${name}.${domain}
          HostName ${lib.head node.addresses}
      '') untrusted
    );

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

    systemd.tmpfiles.rules = [
      "d /home/turbo/.ssh 0700 turbo users -"
    ];

    environment.etc."ssh/mesh_id_ed25519.pub".text = meshPublicKey + "\n";

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

    environment.systemPackages = [
      (pkgs.callPackage ./mesh-cli.nix { inherit (cfg) flakePath flakeUrl; })
    ];

    services.openssh = {
      enable = true;
      authorizedKeysFiles = lib.mkForce [ "/etc/ssh/authorized_keys.d/%u" ];

      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    services.tailscale.extraUpFlags = [ "--accept-dns=true" ];
  };
}
