{ inputs, lib, hostName, ... }:
{
  imports = [
    ./hardware.nix
    "${inputs.self}/modules/nixos"
    (import "${inputs.self}/dev/development.nix").nixosModule
    # "${inputs.self}/modules/nixos/fprint/fprint.nix"
    # machine.fprint.enable = lib.mkForce true;  # включи вместе с fprint.nix
  ];

  # BRN-H76 is a physical AMD Phoenix laptop. Do not rely on module-list
  # detection: battery/AC support can be built into the kernel and be invisible
  # in boot.kernelModules.
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
  };

  system.stateVersion = "26.05";
}
