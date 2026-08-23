{ lib, config, cameraDevicePath ? "", isInstaller ? false, ... }:
let
  cfg = config.machine;
  enableHowdy = !isInstaller && !cfg.isVm && !cfg.fprint.enable && cameraDevicePath != "";
in
{
  security.pam = {
    howdy = lib.mkIf enableHowdy {
      enable = true;
      control = "sufficient";
    };

    services = lib.mkIf enableHowdy {
      systemd-run0 = {
        howdy.enable = true;
        howdy.control = "sufficient";
      };

      login = {
        howdy.enable = true;
        howdy.control = "sufficient";
      };

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

    gnome.gnome-keyring.enable = lib.mkIf (!isInstaller) true;
  };
}
