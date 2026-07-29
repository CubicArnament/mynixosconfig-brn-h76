{ pkgs }:
let
  sshKeys = (import ./env.ssh).authorizedKeys;
in
{
  name = "wkubearnament";
  description = "Primary user";
  homeDirectory = "/home/wkubearnament";
  shellPackage = pkgs.fish;
  extraGroups = [ "wheel" "networkmanager" "libvirtd" ];
  sshAuthorizedKeys = sshKeys;

  homeStateVersion = "26.05";
  sessionVariables = {
    EDITOR = "nano";
  };
}
