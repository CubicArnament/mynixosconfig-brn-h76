{ pkgs }:
{
  name = "wkubearnament";
  description = "Primary user";
  homeDirectory = "/home/wkubearnament";
  shellPackage = pkgs.fish;
  extraGroups = [ "wheel" "networkmanager" "libvirtd" ];

  homeStateVersion = "26.05";
  sessionVariables = {
    EDITOR = "nano";
  };
}
