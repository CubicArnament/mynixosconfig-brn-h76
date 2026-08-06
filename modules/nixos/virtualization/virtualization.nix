{ pkgs, lib, config, ... }:
let
  cfg = config.machine;
in
{
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
