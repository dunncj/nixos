{
  description = "shambhala + myosis + amarout - NixOS/nix-darwin configuration, and turbo's portable environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-darwin,
      sops-nix,
    }:
    let
      linuxSystem = "x86_64-linux";
      darwinSystem = "aarch64-darwin";

      linuxPkgs = nixpkgs.legacyPackages.${linuxSystem};

      portableSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      genericHost = {
        flakePath = null;
        hostName = null;
      };

      registry = import ./nodes.nix;

      flakeUrl = "github:dunncj/nixos?dir=nix";

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

            ./modules/autoupgrade.nix

            sops-nix.nixosModules.sops
            ./modules/mesh.nix
            { mesh.self = host.hostName; }

            self.nixosModules.turbo
            {
              turbo = {
                inherit (host) flakePath hostName;
                inherit extraGroups flakeUrl;
              };
            }
          ]
          ++ modules;
        };
    in
    {
      nixosModules.turbo = ./turbo/system.nix;

      nixosModules.mesh = ./modules/mesh.nix;

      packages = nixpkgs.lib.genAttrs portableSystems (
        system:
        turboPackages system (
          if system == linuxSystem then
            shambhala
          else if system == darwinSystem then
            amarout
          else
            genericHost
        )
        // nixpkgs.lib.optionalAttrs (system == linuxSystem) {
          mesh = linuxPkgs.callPackage ./modules/mesh-cli.nix {
            inherit flakeUrl;
            inherit (shambhala) flakePath;
          };
        }
      );

      nixosConfigurations.${shambhala.hostName} = mkLinuxHost shambhala {
        modules = [
          ./hosts/shambhala/configuration.nix

          ./modules/desktop.nix
          ./modules/docker.nix
          ./modules/wireguard.nix

          ./modules/k3s.nix
          ./modules/sunshine.nix
          ./modules/power.nix
        ];
      };

      nixosConfigurations.${myosis.hostName} = mkLinuxHost myosis {
        modules = [
          ./hosts/myosis/configuration.nix

          ./modules/desktop.nix
          ./modules/docker.nix
          ./modules/wireguard.nix
          ./modules/nvidia.nix
        ];
      };

      darwinConfigurations.${amarout.hostName} = nix-darwin.lib.darwinSystem {
        system = darwinSystem;
        specialArgs = { inherit self; };

        modules = [
          ./hosts/amarout/configuration.nix
          ./modules/rebuild-darwin.nix

          ./modules/mesh-darwin.nix
          { mesh.self = amarout.hostName; }

          ./turbo/shell.nix

          {
            environment.systemPackages = [ self.packages.${darwinSystem}.turbo ];
          }
        ];
      };

      checks.${linuxSystem}.registry = linuxPkgs.callPackage ./modules/registry-check.nix {
        inherit registry;
        sopsConfig = ./.sops.yaml;
      };
    };
}
