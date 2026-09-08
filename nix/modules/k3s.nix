# Single-node k3s server. Workload manifests live in ../k3s and ../services and
# are applied by hand, not by this module.
{ pkgs, ... }:

{
  services.k3s = {
    enable = true;
    role = "server";

    # Pinned, and deliberately NOT the hostname. The host was renamed from
    # agartha to shambhala, but k3s derives the node name from the hostname by
    # default, and the local-path PVs for the Minecraft world and Jellyfin
    # config/cache carry an immutable nodeAffinity of [agartha]. Letting the
    # node be renamed would register a second node and strand those volumes,
    # with no way to patch them - PV spec.nodeAffinity cannot be changed.
    #
    # Migrating properly means flipping each PV to reclaimPolicy Retain,
    # recreating it against the new node, and rebinding the claims. Worth doing
    # deliberately, not as a side effect of a rename.
    extraFlags = [ "--node-name=agartha" ];
  };

  # Root-only (0600), so this is really only useful for root shells and sudo.
  # As turbo, reach the cluster through the `k` alias in ../turbo/system.nix.
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  environment.systemPackages = with pkgs; [ kubectl ];
}
