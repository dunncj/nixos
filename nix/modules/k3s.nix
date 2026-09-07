# Single-node k3s server. Workload manifests live in ../k3s and ../services and
# are applied by hand, not by this module.
{ pkgs, ... }:

{
  services.k3s = {
    enable = true;
    role = "server";
  };

  # Root-only (0600), so this is really only useful for root shells and sudo.
  # As turbo, reach the cluster through the `k` alias in ../turbo/home.nix.
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  environment.systemPackages = with pkgs; [ kubectl ];
}
