{ pkgs, ... }:
{
  home.packages = with pkgs; [
    helm
    kubectl
  ];
}
