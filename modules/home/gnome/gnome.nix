{ ... }:
{
  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        show-battery-percentage = true;
        clock-show-weekday = true;
        clock-show-date = true;
        enable-hot-corners = false;
      };

      "org/gnome/desktop/peripherals/touchpad" = {
        tap-to-click = true;
        two-finger-scrolling-enabled = true;
        click-method = "fingers";
      };

      "org/gnome/desktop/wm/preferences" = {
        button-layout = "appmenu:minimize,maximize,close";
      };

      "org/gnome/mutter" = {
        dynamic-workspaces = true;
        edge-tiling = true;
        workspaces-only-on-primary = false;
      };

      "org/gnome/settings-daemon/plugins/power" = {
        power-button-action = "suspend";
        sleep-inactive-ac-type = "nothing";
        sleep-inactive-battery-type = "suspend";
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
        ];
        favorite-apps = [
          "org.gnome.Nautilus.desktop"
          "org.gnome.Console.desktop"
          "org.gnome.Settings.desktop"
        ];
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

      "org/gnome/shell/extensions/dash-to-dock" = {
        dock-position = "BOTTOM";
        extend-height = false;
        intellihide = true;
        show-mounts = false;
        show-trash = false;
        click-action = "focus-minimize-or-previews";
        scroll-action = "switch-workspace";
      };

      "org/gnome/shell/extensions/caffeine" = {
        show-indicator = "always";
      };
    };
  };
}
