# `nb` - the rebuild entry point for this host, plus the /etc/nixos symlink
# that keeps a bare `nixos-rebuild` from ever building a stale second copy of
# the system.
{ config, pkgs, ... }:

{
  systemd.tmpfiles.rules = [
    "L+ /etc/nixos - - - - /home/turbo/nix"
  ];

  # Replaces the old alias `sudo nixos-rebuild switch --flake ~/nix#$(hostname)`,
  # which got two things wrong:
  #
  #   1. `~/nix` sits inside the git repo at /home/turbo, so nix resolved it to
  #      `git+file:///home/turbo?dir=nix` and copied the *entire* home repo into
  #      the store on every build. `path:` pins it to the 88K dir instead.
  #   2. A switch that restarts dbus leaves PID 1 with a dead bus connection,
  #      after which `reboot` silently does nothing. `daemon-reexec` fixes that.
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "nb";
      runtimeInputs = with pkgs; [
        nixos-rebuild
        systemd
        nvd
        nix
      ];
      text = ''
        FLAKE_DIR=/home/turbo/nix
        FLAKE="path:$FLAKE_DIR#${config.networking.hostName}"

        usage() {
            echo "nb - rebuild NixOS from $FLAKE_DIR"
            echo
            echo "  nb [switch]   build + activate now, and set as boot default"
            echo "  nb boot       build + set as boot default, do not activate"
            echo "  nb test       build + activate now, do NOT touch the bootloader"
            echo "  nb dry        show what activating would change, change nothing"
            echo "  nb update     update flake inputs, then switch"
            echo "  nb rollback   activate the previous generation"
            echo "  nb diff       diff the working tree against the running system"
            echo "  nb gc         delete generations older than 14 days"
        }

        cmd="''${1:-switch}"
        shift || true

        case "$cmd" in
            -h|--help|help) usage; exit 0 ;;
        esac

        if [ "$(id -u)" -ne 0 ]; then
            exec sudo -- "$0" "$cmd" "$@"
        fi

        before="$(readlink -f /run/current-system)"

        # Re-exec PID 1 so it reconnects to a possibly-restarted bus, then
        # report anything that did not survive activation.
        post_activate() {
            echo
            echo ":: re-execing systemd (keeps reboot/systemctl working)"
            systemctl daemon-reexec

            after="$(readlink -f /run/current-system)"
            if [ "$before" != "$after" ]; then
                echo
                echo ":: changes"
                nvd diff "$before" "$after" || true
            fi

            echo
            echo ":: service check"
            for unit in tailscaled sshd dbus; do
                if systemctl is-active --quiet "$unit"; then
                    echo "   ok    $unit"
                else
                    echo "   DOWN  $unit"
                fi
            done

            if systemctl --failed --no-legend --plain | grep -q .; then
                echo
                echo ":: FAILED UNITS"
                systemctl --failed --no-legend --plain
            else
                echo "   ok    no failed units"
            fi
        }

        case "$cmd" in
            switch|test)
                nixos-rebuild "$cmd" --flake "$FLAKE" "$@"
                post_activate
                ;;
            boot)
                nixos-rebuild boot --flake "$FLAKE" "$@"
                echo
                echo ":: staged for next boot, nothing activated now"
                ;;
            dry)
                nixos-rebuild dry-activate --flake "$FLAKE" "$@"
                ;;
            update)
                nix flake update --flake "path:$FLAKE_DIR"
                nixos-rebuild switch --flake "$FLAKE" "$@"
                post_activate
                ;;
            rollback)
                nixos-rebuild switch --rollback
                post_activate
                ;;
            diff)
                built="$(nix build --no-link --print-out-paths \
                    "path:$FLAKE_DIR#nixosConfigurations.${config.networking.hostName}.config.system.build.toplevel")"
                nvd diff /run/current-system "$built"
                ;;
            gc)
                nix-collect-garbage --delete-older-than 14d
                nixos-rebuild boot --flake "$FLAKE"
                ;;
            *)
                echo "nb: unknown command '$cmd'" >&2
                echo >&2
                usage >&2
                exit 1
                ;;
        esac
      '';
    })
  ];
}
