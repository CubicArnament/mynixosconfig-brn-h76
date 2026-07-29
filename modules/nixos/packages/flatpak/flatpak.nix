_:
let
  # Просто вписывай сюда Flatpak app IDs.
  # Примеры:
  # - Bottles: "com.usebottles.bottles"
  # - Flatseal: "com.github.tchx84.Flatseal"
  # - Telegram: "org.telegram.desktop"
  flatpakPackages = [
    "com.usebottles.bottles"
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

    # Если захочешь, можно сделать Flatpak полностью управляемым из Nix:
    # uninstallUnmanaged = true;

    # Можно включить обновление Flatpak'ов при активации системы:
    # update.onActivation = true;

    # Или периодические автообновления:
    # update.auto = {
    #   enable = true;
    #   onCalendar = "weekly";
    # };
  };
}
