{ pkgs }:
let
  # Import initial hashed password if file exists, otherwise null
  initialHashedPassword = 
    if builtins.pathExists ../../env.hpasswd
    then pkgs.lib.removeSuffix "\n" (builtins.readFile ../../env.hpasswd)
    else null;
in
{
  name = "wkubearnament";
  description = "Primary user";
  homeDirectory = "/home/wkubearnament";
  shellPackage = pkgs.fish;
  extraGroups = [ "wheel" "networkmanager" "libvirtd" "docker" ];
  inherit initialHashedPassword;

  homeStateVersion = "26.05";
  sessionVariables = {
    EDITOR = "nano";
  };
}
