{ inputs, lib, hostName, ... }:
{
  imports = [
    ./hardware.nix
    "${inputs.self}/modules/nixos"
    (import "${inputs.self}/dev/development.nix").nixosModule
  ];

  machine = {
    isVm = lib.mkForce false;
    cpuVendor = lib.mkForce "amd";
    gpuVendor = lib.mkForce "amd";
    isLaptop = lib.mkForce true;
  };

  networking.hostName = hostName;
  time.timeZone = lib.mkForce "Europe/Moscow";

  services.zapret2 = {
    enable = true;
    presets = [ "youtube" "discord" "general" ];
    defaultPreset = "youtube";
    firewall.ports.udp = [ "443" "50000-65535" ];
  };

  system.stateVersion = "26.05";
}
