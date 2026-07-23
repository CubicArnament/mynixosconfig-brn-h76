{ pkgs, ... }:
{
  gtk = {
    enable = true;
    theme = {
      package = pkgs.nordic;
      name = "Nordic-darker";
    };
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = "Papirus-Dark";
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
    };
    colorScheme = "dark";
  };

  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "Nordic-darker";
        icon-theme = "Papirus-Dark";
        cursor-theme = "Bibata-Modern-Ice";
        show-battery-percentage = true;
        clock-show-weekday = true;
        clock-show-date = true;
        enable-hot-corners = false;
      };

      "org/gnome/desktop/background" = {
        picture-uri = "file://${pkgs.nixos-artwork.wallpapers.gnome-dark.gnomeFilePath}";
        picture-uri-dark = "file://${pkgs.nixos-artwork.wallpapers.gnome-dark.gnomeFilePath}";
        picture-options = "zoom";
      };

      "org/gnome/desktop/screensaver" = {
        picture-uri = "file://${pkgs.nixos-artwork.wallpapers.gnome-dark.gnomeFilePath}";
        picture-options = "zoom";
      };

      "org/gnome/desktop/peripherals/touchpad" = {
        # Базовые настройки
        tap-to-click = true;
        tap-and-drag = true;           # drag через tap, как на macOS
        tap-and-drag-lock = false;
        natural-scroll = true;         # "контентное" направление прокрутки, как на macOS
        two-finger-scrolling-enabled = true;
        edge-scrolling-enabled = false;
        click-method = "fingers";      # два пальца = правый клик, как на macOS
        disable-while-typing = true;
        send-events = "enabled";
        speed = 0.2;                   # чуть ниже для точности, как на macOS
      };

      # Жесты тачпада — macOS-style через Mutter
      # 3 пальца вверх  → Activities Overview (как Exposé / Mission Control)
      # 3 пальца влево/вправо → переключение окон (как Mission Control swipe)
      # 4 пальца влево/вправо → переключение рабочих столов (как Space switching)
      "org/gnome/mutter/gestures" = {
        touch-points = 3;
      };

      "org/gnome/desktop/wm/preferences" = {
        button-layout = "appmenu:minimize,maximize,close";
        theme = "Nordic-darker";
      };

      "org/gnome/mutter" = {
        dynamic-workspaces = true;
        edge-tiling = true;
        workspaces-only-on-primary = false;
        # Включаем нативные жесты Mutter на Wayland
        # 3 пальца вверх → Activities, влево/вправо → смена окон
        # 4 пальца влево/вправо → смена рабочих столов
        experimental-features = [ "scale-monitor-framebuffer" ];
      };

      "org/gnome/settings-daemon/plugins/power" = {
        power-button-action = "suspend";
        sleep-inactive-ac-type = "nothing";
        sleep-inactive-battery-type = "suspend";

        # Автоматически включать power-saver при низком заряде батареи.
        # GNOME + power-profiles-daemon: при заряде < PercentageLow (по умолчанию 20%
        # в /etc/UPower/UPower.conf) профиль автоматически переключится на power-saver.
        # Этот ключ появился в GNOME 41+ (gsettings-desktop-schemas >= 41).
        power-saver-profile-on-low-battery = true;
      };

      "org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = [
          "appindicatorsupport@rgcjonas.gmail.com"
          "blur-my-shell@aunetx"
          "caffeine@patapon.info"
          "clipboard-indicator@tudmotu.com"
          "dash-to-dock@micxgx.gmail.com"
          "just-perfection-desktop@just-perfection"
          "Vitals@CoreCoding.com"
          "user-theme@gnome-shell-extensions.gcampax.github.com"
          "touchpad-gesture-customization@coooolapps.com"
        ];
        favorite-apps = [
          "org.gnome.Nautilus.desktop"
          "org.gnome.Console.desktop"
          "org.gnome.Settings.desktop"
        ];
      };

      "org/gnome/shell/extensions/user-theme" = {
        name = "Nordic-darker";
      };

      "org/gnome/shell/keybindings" = {
        screenshot = [ "Print" ];
        screenshot-window = [ "<Alt>Print" ];
        show-screenshot-ui = [ "<Shift>Print" ];
      };

      "org/gnome/settings-daemon/plugins/media-keys" = {
        home = [ "<Super>e" ];
        www = [ "<Super>b" ];
        calculator = [ "<Super>c" ];
        search = [ "<Super>space" ];
        control-center = [ "<Super>i" ];
        screensaver = [ "<Super>l" ];
      };

      "org/gnome/desktop/wm/keybindings" = {
        close = [ "<Super>q" ];
        toggle-maximized = [ "<Super>Up" ];
        unmaximize = [ "<Super>Down" ];
        switch-windows = [ "<Super>Tab" ];
        switch-applications = [ "<Alt>Tab" ];
        move-to-monitor-left = [ "<Super><Shift>Left" ];
        move-to-monitor-right = [ "<Super><Shift>Right" ];
      };

      "org/gnome/shell/window-switcher" = {
        current-workspace-only = false;
      };

      "org/gnome/shell/app-switcher" = {
        current-workspace-only = false;
      };

      "org/gnome/shell/extensions/dash-to-dock" = {
        dock-position = "BOTTOM";
        dock-fixed = false;
        extend-height = false;
        intellihide = true;
        show-mounts = false;
        show-trash = false;
        click-action = "focus-minimize-or-previews";
        scroll-action = "switch-workspace";
        dash-max-icon-size = 40;
        transparency-mode = "DYNAMIC";
        running-indicator-style = "DOTS";
        show-show-apps-button = true;
      };

      "org/gnome/shell/extensions/caffeine" = {
        show-indicator = "always";
      };
    };
  };
}
