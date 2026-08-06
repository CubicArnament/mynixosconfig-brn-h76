_:
let
  flatpakPackages = [
    "com.usebottles.bottles"
    "org.telegram.desktop"
  ];
in
{
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
