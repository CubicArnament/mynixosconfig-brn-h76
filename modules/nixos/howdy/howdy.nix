{ lib, config, cameraDevicePath ? "/dev/video0", ... }:
let
  cfg = config.machine;
  # Howdy не нужен в VM (нет вебкамеры) и когда включён fprint
  # (два биометрических метода в одном PAM стеке — источник конфликтов).
  # Если хочешь оба — раскомментируй ниже и тщательно проверь PAM порядок.
  enableHowdy = !cfg.isVm && !cfg.fprint.enable;
in
{
  security.pam = {
    howdy = lib.mkIf enableHowdy {
      enable = true;
      control = "sufficient";
    };

    services = lib.mkIf enableHowdy {
      # Face auth for run0. Password remains available as fallback.
      systemd-run0 = {
        howdy.enable = true;
        howdy.control = "sufficient";
      };

      # Face auth for GDM/login. Password remains available as fallback.
      login = {
        howdy.enable = true;
        howdy.control = "sufficient";
      };

      # Face auth for GUI privilege elevation dialogs.
      polkit-1 = {
        howdy.enable = true;
        howdy.control = "sufficient";
      };
    };
  };

  services = {
    howdy = lib.mkIf enableHowdy {
      enable = true;
      control = "sufficient";
      settings = {
        core = {
          abort_if_lid_closed = cfg.isLaptop;
          abort_if_ssh = true;
          detection_notice = false;
          disabled = false;
          no_confirmation = false;
          suppress_unknown = false;
          timeout_notice = true;
          use_cnn = false;
          workaround = "off";
        };

        video = {
          device_path = cameraDevicePath;
          device_format = "v4l2";
          recording_plugin = "opencv";
          timeout = 4;
          certainty = 4.0;
          dark_threshold = 50;
          max_height = 320;
          frame_width = -1;
          frame_height = -1;
          device_fps = -1;
          exposure = -1;
          force_mjpeg = false;
          rotate = 0;
          warn_no_device = true;
        };

        snapshots = {
          save_failed = false;
          save_successful = false;
        };
      };
    };

    gnome.gnome-keyring.enable = true;
  };
}
