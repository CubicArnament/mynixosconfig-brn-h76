{ pkgs, ... }:
{
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      swtpm.enable = true;
      vhostUserPackages = [ pkgs.virtiofsd ];
      verbatimConfig = ''
        namespaces = []
        gl = 1
      '';
    };
  };

  virtualisation.spiceUSBRedirection.enable = true;

  environment.systemPackages = with pkgs; [
    dnsmasq
  ];

  services.k3s = {
    enable = true;
    role = "server";
  };

  networking.firewall = {
    trustedInterfaces = [ "virbr0" ];
    allowedTCPPorts = [ 6443 ];
  };
}
