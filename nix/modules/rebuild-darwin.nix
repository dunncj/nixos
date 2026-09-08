# `nb` - the rebuild entry point for amarout, mirroring ./rebuild.nix's
# shambhala wrapper. Uses `path:` so nix does not copy this whole
# $HOME-rooted repo into the store on every build.
#
# darwin-rebuild itself handles sudo elevation for activation, so unlike the
# NixOS version this does not need to re-exec as root.
{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "nb";
      runtimeInputs = [ pkgs.nix ];
      text = ''
        FLAKE_DIR="$HOME/nix"
        FLAKE="path:$FLAKE_DIR#amarout"

        usage() {
            echo "nb - rebuild amarout from $FLAKE_DIR"
            echo
            echo "  nb [switch]   build + activate now"
            echo "  nb build      build only, do not activate"
            echo "  nb check      build + run flake checks, do not activate"
            echo "  nb update     update flake inputs, then switch"
            echo "  nb rollback   activate the previous generation"
            echo "  nb diff       diff the built system against the running one"
        }

        cmd="''${1:-switch}"
        shift || true

        case "$cmd" in
            -h|--help|help) usage; exit 0 ;;
        esac

        case "$cmd" in
            switch|build|check)
                darwin-rebuild "$cmd" --flake "$FLAKE" "$@"
                ;;
            update)
                nix flake update --flake "path:$FLAKE_DIR"
                darwin-rebuild switch --flake "$FLAKE" "$@"
                ;;
            rollback)
                darwin-rebuild rollback "$@"
                ;;
            diff)
                built="$(nix build --no-link --print-out-paths \
                    "path:$FLAKE_DIR#darwinConfigurations.amarout.system")"
                echo "built:   $built"
                echo "running: $(readlink -f /run/current-system)"
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
