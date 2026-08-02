{ pkgs, ... }:
{
  home.packages = with pkgs; [
    qemu
    spice-gtk
    virt-manager
    virt-viewer
    virglrenderer
  ];

  dconf.settings = {
    "org/virt-manager/virt-manager/connections" = {
      autoconnect = [ "qemu:///system" ];
      uris = [ "qemu:///system" ];
    };

    "org/virt-manager/virt-manager/details" = {
      show-toolbar = true;
    };
  };
}
