{ pkgs, ... }:

{
  services.k3s = {
    enable = true;
    role = "server";

    extraFlags = [ "--node-name=agartha" ];
  };

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  environment.systemPackages = with pkgs; [ kubectl ];
}
