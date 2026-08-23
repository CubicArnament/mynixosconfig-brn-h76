{ lib, isInstaller ? false, ... }:
let
  flatpakPackages = [
    "com.usebottles.bottles"
    "org.telegram.desktop"
  ];
in
lib.mkIf (!isInstaller) {
  services.flatpak = {
    enable = true;

    remotes = [
      {
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }
    ];

    packages = flatpakPackages;



  };
}
