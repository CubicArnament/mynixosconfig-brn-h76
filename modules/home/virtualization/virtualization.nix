{ pkgs, ... }:
{
  home.packages = with pkgs; [
    helm
    kubectl
    quickemu
    qemu
    spice-gtk
    virtio-win
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
