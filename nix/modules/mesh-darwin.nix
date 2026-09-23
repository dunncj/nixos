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

    users.users.turbo.openssh.authorizedKeys.keys =
      adminKeys ++ lib.optional (trusted ? ${cfg.self}) meshPublicKey;

    programs.ssh.knownHosts = lib.mapAttrs (name: node: {
      hostNames = namesOf name node;
      publicKey = node.hostKey;
    }) registry.nodes;

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

    services.openssh = {
      enable = true;

      extraConfig = ''
        PasswordAuthentication no
        KbdInteractiveAuthentication no
        PermitRootLogin no
        AuthorizedKeysFile none
      '';
    };
  };
}
