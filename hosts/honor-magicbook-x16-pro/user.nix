{ pkgs }:
let
  ssh = import ./ssh.env;
in
{
  name = "wkubearnament";
  description = "Primary user";
  homeDirectory = "/home/wkubearnament";
  shellPackage = pkgs.fish;
  extraGroups = [ "wheel" "networkmanager" "libvirtd" ];
  sshAuthorizedKeys = ssh.authorizedKeys;

  homeStateVersion = "26.05";
  sessionVariables = {
    EDITOR = "nano";
  };
}
