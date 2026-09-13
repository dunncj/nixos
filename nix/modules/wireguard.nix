# The wg0 tunnel to the VPS at 178.156.205.76.
#
# Everything except this host's own address is identical on every peer, so the
# shared parts live here and each host sets `tunnel.address`. There is no
# default: a silent default would be an address collision, and two hosts sharing
# a tunnel IP fails in a way that looks like packet loss rather than like a
# config error.
#
# The private key is deployed out of band and read from
# /etc/wireguard/private.key, root-only. Never put a key in this repo: the whole
# world-readable nix store would get a copy. Only the peer's public key belongs
# here.
{
  config,
  lib,
  ...
}:

let
  cfg = config.tunnel;
in
{
  options.tunnel.address = lib.mkOption {
    type = lib.types.str;
    example = "10.100.0.2/24";
    description = ''
      This host's address on the wg0 tunnel, with prefix length. Must be unique
      across peers.
    '';
  };

  config = {
    networking.wireguard.enable = true;
    networking.wireguard.interfaces.wg0 = {
      ips = [ cfg.address ];

      privateKeyFile = "/etc/wireguard/private.key";

      peers = [
        {
          publicKey = "WYcYdP/27F0HEAGYWEqvoHfbnWkROfcQ4nqZ4ecMDQQ=";
          endpoint = "178.156.205.76:51820";
          persistentKeepalive = 25;
          allowedIPs = [ "10.100.0.1/32" ];
        }
      ];
    };
  };
}
