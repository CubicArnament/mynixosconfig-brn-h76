{ pkgs, ... }:
{
  home.packages = with pkgs; [
    helm
    kubectl
    docker
    docker-compose-v2
    lazydocker
  ];
}
