{
  description = "shambhala + amarout - NixOS/nix-darwin configuration, and turbo's portable environment";

  # No home-manager. The only thing it still did here was write dotfiles into
  # $HOME; those are now system programs writing /etc, which is inert for root
  # because root has none of the binaries that read them. See turbo/system.nix.
  inputs = {
    # Pinned to the exact rev already running on amarout (see
    # /etc/nix-darwin/flake.lock there) rather than floating on
    # nixos-unstable: newer nixos-render-docs (nixpkgs' doc-rendering tool)
    # dropped a --sidebar-depth flag that nix-darwin/master's manual-html
    # builder still passes, breaking any darwinConfigurations build. Bump
    # nixpkgs and nix-darwin together once upstream fixes the mismatch.
    nixpkgs.url = "github:NixOS/nixpkgs/be5afa0fcb31f0a96bf9ecba05a516c66fcd8114";
    nix-darwin.url = "github:nix-darwin/nix-darwin/8b720b9662d4dd19048664b7e4216ce530591adc";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { self, nixpkgs, nix-darwin }:
    let
      linuxSystem = "x86_64-linux";
      darwinSystem = "aarch64-darwin";

      shambhala = {
        flakePath = "/home/turbo/nix";
        hostName = "shambhala";
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
          turbo = import ./turbo/package.nix { inherit pkgs; inherit (host) flakePath hostName; };
        in
        {
          inherit turbo;
          neovim = pkgs.callPackage ./turbo/neovim.nix { inherit (host) flakePath hostName; };
          default = turbo;
        };
    in
    {
      # The portable unit. On another NixOS machine:
      #   imports = [ inputs.shambhala.nixosModules.turbo ];
      # Nothing in it is specific to this host; set turbo.flakePath,
      # turbo.hostName and turbo.extraGroups there.
      nixosModules.turbo = ./turbo/system.nix;

      packages.${linuxSystem} = turboPackages linuxSystem shambhala;
      packages.${darwinSystem} = turboPackages darwinSystem amarout;

      nixosConfigurations.${shambhala.hostName} = nixpkgs.lib.nixosSystem {
        system = linuxSystem;

        modules = [
          # hardware-configuration.nix is imported by configuration.nix, so it
          # is deliberately not listed again here.
          ./hosts/shambhala/configuration.nix

          ./modules/rebuild.nix
          ./modules/k3s.nix
          ./modules/sunshine.nix
          ./modules/power.nix

          self.nixosModules.turbo
          {
            turbo = {
              inherit (shambhala) flakePath hostName;
              extraGroups = [ "docker" ];
            };
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
