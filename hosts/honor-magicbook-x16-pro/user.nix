{ pkgs }:
let
  sshKeys = (import ./env.ssh).authorizedKeys;
  
  # Import initial hashed password if file exists, otherwise null
  initialHashedPassword = 
    if builtins.pathExists ./env.hpasswd
    then builtins.readFile ./env.hpasswd
    else null;
in
{
  name = "wkubearnament";
  description = "Primary user";
  homeDirectory = "/home/wkubearnament";
  shellPackage = pkgs.fish;
  extraGroups = [ "wheel" "networkmanager" "libvirtd" ];
  sshAuthorizedKeys = sshKeys;
  inherit initialHashedPassword;

  homeStateVersion = "26.05";
  sessionVariables = {
    EDITOR = "nano";
  };
}
