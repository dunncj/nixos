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
