{
  description = "shambhala + myosis + amarout - NixOS/nix-darwin configuration, and turbo's portable environment";

  # No home-manager. The only thing it still did here was write dotfiles into
  # $HOME; those are now system programs writing /etc, which is inert for root
  # because root has none of the binaries that read them. See turbo/system.nix.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
    }:
    let
      linuxSystem = "x86_64-linux";
      darwinSystem = "aarch64-darwin";

      # flakePath and hostName are the only host-dependent knobs the turbo
      # environment has; they tell nixd which flake and which host to evaluate
      # for NixOS option completion. Both Linux hosts share a flakePath because
      # this repo is rooted at $HOME on each of them.
      shambhala = {
        flakePath = "/home/turbo/nix";
        hostName = "shambhala";
      };

      myosis = {
        flakePath = "/home/turbo/nix";
        hostName = "myosis";
      };

      amarout = {
        flakePath = "/Users/turbo/nix";
        hostName = "amarout";
      };

      # turbo's environment as one derivation, for a machine that is not NixOS
      # at all:
      #   nix profile install github:dunncj/nixos?dir=nix#turbo
      # The editor carries its own config; the shell dotfiles do not travel
      # this way. See ./turbo/package.nix.
      turboPackages =
        system: host:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          turbo = import ./turbo/package.nix {
            inherit pkgs;
            inherit (host) flakePath hostName;
          };
        in
        {
          inherit turbo;
          neovim = pkgs.callPackage ./turbo/neovim.nix { inherit (host) flakePath hostName; };
          default = turbo;
        };

      # Everything every NixOS host here gets: the shared base, the `nb` rebuild
      # command, and turbo's account and environment. `modules` is what makes a
      # host that host.
      #
      # ./modules/desktop.nix is deliberately NOT in here - see its header.
      mkLinuxHost =
        host:
        {
          modules,
          extraGroups ? [ ],
        }:
        nixpkgs.lib.nixosSystem {
          system = linuxSystem;

          modules = [
            ./modules/base.nix
            ./modules/rebuild.nix

            self.nixosModules.turbo
            {
              turbo = {
                inherit (host) flakePath hostName;
                inherit extraGroups;
              };
            }
          ]
          ++ modules;
        };
    in
    {
      # The portable unit. On another NixOS machine:
      #   imports = [ inputs.shambhala.nixosModules.turbo ];
      # Nothing in it is specific to any host; set turbo.flakePath,
      # turbo.hostName and turbo.extraGroups there.
      nixosModules.turbo = ./turbo/system.nix;

      # One canonical host per platform, purely so these outputs have a
      # flakePath/hostName to bake in for nixd. shambhala stands for Linux the
      # same way amarout stands for darwin; a third machine consuming this does
      # not need its own output, it sets the turbo.* options instead.
      packages.${linuxSystem} = turboPackages linuxSystem shambhala;
      packages.${darwinSystem} = turboPackages darwinSystem amarout;

      nixosConfigurations.${shambhala.hostName} = mkLinuxHost shambhala {
        modules = [
          # hardware-configuration.nix is imported by configuration.nix, so it
          # is deliberately not listed again here.
          ./hosts/shambhala/configuration.nix

          ./modules/desktop.nix
          ./modules/docker.nix
          ./modules/wireguard.nix

          ./modules/k3s.nix
          ./modules/sunshine.nix
          ./modules/power.nix
        ];
      };

      # Cameron's workstation: Intel, NVIDIA, one 4K144 panel, dual-booting
      # Windows.
      #
      # It takes none of shambhala's server modules, and that is not an
      # oversight: k3s.nix pins the node name to `agartha` and owns that
      # cluster's volumes, power.nix forbids sleep on a machine that should be
      # allowed to sleep, and sunshine.nix exists only to fake a monitor for
      # headless capture - it hardcodes shambhala's AMD GPU at PCI 0000:03:00.0
      # and is meaningless where a real panel is plugged in.
      nixosConfigurations.${myosis.hostName} = mkLinuxHost myosis {
        modules = [
          ./hosts/myosis/configuration.nix

          ./modules/desktop.nix
          ./modules/docker.nix
          ./modules/wireguard.nix
          ./modules/nvidia.nix
        ];
      };

      # Cameron's workstation. Desktop and the turbo environment, none of
      # shambhala's server modules (k3s, sunshine, power) - see
      # hosts/myosis/configuration.nix for why.
      nixosConfigurations.${myosis.hostName} = nixpkgs.lib.nixosSystem {
        system = linuxSystem;

        modules = [
          ./hosts/myosis/configuration.nix

          ./modules/base.nix
          ./modules/desktop.nix
          ./modules/nvidia.nix
          ./modules/docker.nix
          ./modules/wireguard.nix
          ./modules/rebuild.nix

          self.nixosModules.turbo
          {
            turbo = { inherit (myosis) flakePath hostName; };
          }
        ];
      };

      # Cameron's MacBook. No NixOS-style users.users.turbo module here - it
      # is nix-darwin, so the portable unit is consumed as a plain package
      # instead of imported as a module. See hosts/amarout/configuration.nix.
      darwinConfigurations.${amarout.hostName} = nix-darwin.lib.darwinSystem {
        system = darwinSystem;
        specialArgs = { inherit self; };

        modules = [
          ./hosts/amarout/configuration.nix
          ./modules/rebuild-darwin.nix
          {
            environment.systemPackages = [ self.packages.${darwinSystem}.turbo ];
          }
        ];
      };
    };
}
