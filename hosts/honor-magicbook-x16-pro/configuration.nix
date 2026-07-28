{ inputs, lib, hostName, ... }:
{
  imports = [
    ./hardware.nix
    "${inputs.self}/modules/nixos"
    (import "${inputs.self}/dev/development.nix").nixosModule
    # "${inputs.self}/modules/nixos/fprint/fprint.nix"
    # machine.fprint.enable = lib.mkForce true;  # включи вместе с fprint.nix
  ];

  # Honor MagicBook X16 Pro — физический AMD ноутбук.
  # machine.* автодетектируются из hardware.nix (boot.kernelModules).
  # При необходимости переопредели через lib.mkForce:
  #   machine.isVm     = lib.mkForce false;
  #   machine.cpuVendor = lib.mkForce "amd";
  #   machine.gpuVendor = lib.mkForce "amd";
  #   machine.isLaptop  = lib.mkForce true;  # если battery/ac built-in в ядре

  networking.hostName = hostName;
  time.timeZone = lib.mkForce "Europe/Moscow";

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_ROOT";
    fsType = "ext4";
  };

  system.stateVersion = "26.05";
}
