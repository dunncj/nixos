{

  domain = "headscale.agartha.sh";

  meshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO4z91t1gzX4xzFbh2t52hvvREDJiQjBneu5PLZ/YuI2 turbo@mesh";

  adminKeys = [
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
