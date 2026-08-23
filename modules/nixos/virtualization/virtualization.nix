{ pkgs, lib, config, isInstaller ? false, ... }:
let
  cfg = config.machine;
in
lib.mkIf (!isInstaller) {
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      swtpm.enable = true;
      vhostUserPackages = [ pkgs.virtiofsd ];
      verbatimConfig = lib.mkIf (!cfg.isVm) ''
        namespaces = []
        gl = 1
      '';
    };
  };

  virtualisation.spiceUSBRedirection.enable = true;

  environment.systemPackages = with pkgs; [
    dnsmasq
  ];

  networking.firewall = {
    trustedInterfaces = [ "virbr0" ];
  };
}
