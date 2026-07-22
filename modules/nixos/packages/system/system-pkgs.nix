{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    curl
    git
    openssh
    pciutils
    usbutils
  ];
}
