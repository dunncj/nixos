# The node registry: who is in turbo's mesh, what they are called, and how
# they are identified. This file is the single source of truth. Everything
# else -- authorized_keys, known_hosts, /etc/hosts, ssh client aliases, the
# firewall's isolation rules and the sops recipient list -- is derived from
# it by ./modules/mesh.nix. Nothing downstream is edited by hand.
#
# Adding a node is one attrset here plus `mesh add-node`, which fills the
# attrset in for you. See ./modules/mesh.nix for what each field drives.
#
# Only public material lives here. Host keys and age recipients are public by
# construction -- they are what a stranger gets from `ssh-keyscan` -- so this
# file is safe in a public repo. The one private key in the system is the
# shared mesh identity, which lives encrypted in ./secrets/secrets.yaml.
{
  # Each node's `aliases` are extra names it answers to: short forms for
  # typing. They are spelled out per node rather than derived from a prefix of
  # the hostname, because a derived rule would give shambhala "sha" and the
  # name that is actually wanted is "sam". A rule with an exception in it is
  # worse than a list.
  #
  # Aliases are real names everywhere, not a shell-level shortcut: ../modules/
  # mesh.nix puts them in the ssh client config, in /etc/hosts and in the
  # pinned known_hosts entry, so `ssh sam`, `ping sam` and host-key
  # verification all agree. ../modules/registry-check.nix fails the build if
  # two nodes claim the same one, or if an alias collides with a node's name.

  # The tailnet's MagicDNS suffix. Used to build the FQDN aliases, but nothing
  # depends on MagicDNS actually resolving: ./modules/mesh.nix also writes
  # every name into /etc/hosts, so `ssh myosis` keeps working when headscale
  # is unreachable.
  domain = "headscale.agartha.sh";

  # Public half of the shared mesh identity. Every trusted node authorises
  # this one key, and every trusted node holds its private half (decrypted
  # from sops to ~turbo/.ssh/id_ed25519).
  #
  # One shared key rather than N per-node keys is a deliberate trade. The
  # mesh is all-trust-all by definition -- the ask was that every node reach
  # every other freely -- so per-node keys would not shrink the blast radius
  # of a compromise, they would only mean that adding the (N+1)th node
  # requires rebuilding the other N before it can talk to any of them. With
  # one key, a new node decrypts and is immediately reachable both ways, and
  # no existing machine has to be touched. The cost is that revocation is
  # all-or-nothing: see `mesh rotate`.
  meshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO4z91t1gzX4xzFbh2t52hvvREDJiQjBneu5PLZ/YuI2 turbo@mesh";

  # Human keys that are authorised on every trusted node regardless of the
  # mesh key. These are the anti-lockout floor: if the mesh key is ever lost,
  # rotated badly, or not yet deployed to a machine, these still get you in.
  # Never let this list reach zero.
  adminKeys = [
    # Cameron's MacBook -- the day-to-day way in.
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMPZ/zuXWvni75yWM7lyCpdAPIguxBc46PCzq+6TGnYt camerondunn@Camerons-MacBook-Pro-3811"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPx+ga2HMIrdfP+qbCYWEyWHWtXCTtX46aibp9iOt8dA turbo25037@gmail.com"
  ];

  nodes = {
    shambhala = {
      description = "Headless Plasma box: Sunshine host, k3s server, Minecraft server.";
      aliases = [ "sam" ];
      trusted = true;
      system = "x86_64-linux";
      addresses = [
        "100.64.0.3"
        "fd7a:115c:a1e0::3"
      ];
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ3twpYYdfDgDT131BK8PT5BFhXO9iu7VvjkXj1yaizW";
      age = "age1slavqyrel6x6hnhuv7yc3th0thxwzc9ex9l8hnpujta6za3pkglq2cr8y2";
    };

    myosis = {
      description = "Cameron's workstation. Intel i7-13700K, NVIDIA RTX 50-series, dual-boots Windows.";
      aliases = [ "myo" ];
      trusted = true;
      system = "x86_64-linux";
      addresses = [
        "100.64.0.4"
        "fd7a:115c:a1e0::4"
      ];
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC6muyagl/WHCnFZ3b0P+RLDtgZ3JHDDxq4dtvHVi9X5";
      age = "age1yglm8xdr2ylrqsql6w4wnw5m3ucynpckn69lk4nhfpmvk89feusqguv9x9";
    };

    amarout = {
      description = "Cameron's MacBook Pro. nix-darwin, not NixOS -- its half of the mesh is modules/mesh-darwin.nix.";
      aliases = [ "ama" ];
      trusted = true;
      system = "aarch64-darwin";
      addresses = [
        "100.64.0.2"
        "fd7a:115c:a1e0::2"
      ];
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB0TQYH9PWFYSb74HZiugB/0TzoLJT8Ei4LTshX2uLkW";
      age = "age1n26p4eephjfktel06h8a6uwwz2wppww22tna3wrgca3jw70p9ajqtugae0";
    };

    # --- untrusted: reachable on the wire, deliberately outside the mesh ---
    #
    # Both of these are public, internet-facing boxes. They are listed so that
    # their host keys are pinned and their names resolve, and so the firewall
    # knows which addresses to isolate -- not so they can be logged into.
    # `trusted = false` means: no mesh key in their authorized_keys, no mesh
    # key on disk for them to use, no sops secret encrypted to them, and an
    # explicit two-way block on port 22 in ./modules/mesh.nix.

    teyos = {
      description = "Headscale control plane and exit node. The tailnet depends on it; it is not part of the mesh.";
      aliases = [ "tey" ];
      trusted = false;
      system = "x86_64-linux";
      addresses = [
        "100.64.0.1"
        "fd7a:115c:a1e0::1"
      ];
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF/PwOEzjVWI1gTtMGXfG3qZfDcLsCAUJxPKXrdGf2Z1";
      age = "age10x5r3ru6052ngqqaup3lp2lv8ak92gwfa2xc3ed03920qnxnmvjsqmqut3";
    };

    tunnel = {
      description = "WireGuard tunnel VPS (wg0 peer 10.100.0.1). Separate host from teyos, despite both living under agartha.sh.";
      aliases = [ "tun" ];
      trusted = false;
      system = "x86_64-linux";
      addresses = [
        "10.100.0.1"
        "178.156.205.76"
      ];
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIew735nzw9j9829Tr7VAue51yRNAn4X+L7zFikQ4N6W";
      age = "age13fm5gezfp6aadsk8m63zhrw3tdcz0nam5wa0lfh3qj7u8pajs9ss3k09t3";
    };
  };
}
