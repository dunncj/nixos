# The wg0 tunnel to the VPS at 178.156.205.76.
#
# Everything except this host's own address is identical on every peer, so the
# shared parts live here and each host sets `tunnel.address`. There is no
# default: a silent default would be an address collision, and two hosts sharing
# a tunnel IP fails in a way that looks like packet loss rather than like a
# config error.
#
# The private key is per-host and never in this repo -- the nix store is world
# readable, so a key committed here is a key published. Where it comes from is
# `tunnel.privateKeySecret`, which is deliberately explicit rather than
# defaulted: the two sources have very different properties and picking one by
# accident is how shambhala's key ended up mode 0644 in the first place.
{
  config,
  lib,
  ...
}:

let
  cfg = config.tunnel;
in
{
  options.tunnel = {
    address = lib.mkOption {
      type = lib.types.str;
      example = "10.100.0.2/24";
      description = ''
        This host's address on the wg0 tunnel, with prefix length. Must be unique
        across peers.
      '';
    };

    privateKeySecret = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "wireguard/private_key";
      description = ''
        Name of the sops secret in ../secrets/secrets.yaml holding this host's
        wg private key. It is decrypted at activation with the host's own ssh
        host key and lives only under /run/secrets.

        null means fall back to /etc/wireguard/private.key, placed by hand and
        root-only. That is the bootstrap path for a host whose key has not been
        generated and added to sops yet; it is not the destination.

        The key is per-host: two peers sharing one private key share a public
        key, and the VPS cannot then tell them apart.
      '';
    };
  };

  config = {
    # Decrypted before wireguard-wg0 starts; restartUnits makes the interface
    # pick up a rotated key without a reboot.
    sops.secrets = lib.mkIf (cfg.privateKeySecret != null) {
      ${cfg.privateKeySecret} = {
        restartUnits = [ "wireguard-wg0.service" ];
      };
    };

    networking.wireguard.enable = true;
    networking.wireguard.interfaces.wg0 = {
      ips = [ cfg.address ];

      privateKeyFile =
        if cfg.privateKeySecret != null then
          config.sops.secrets.${cfg.privateKeySecret}.path
        else
          "/etc/wireguard/private.key";

      peers = [
        {
          publicKey = "WYcYdP/27F0HEAGYWEqvoHfbnWkROfcQ4nqZ4ecMDQQ=";
          endpoint = "178.156.205.76:51820";
          persistentKeepalive = 25;
          allowedIPs = [ "10.100.0.0/24" ];
        }
      ];
    };
  };
}
