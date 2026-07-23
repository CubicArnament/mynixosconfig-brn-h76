{ pkgs, ... }:
let
  nordicNixosGrubTheme = pkgs.runCommandLocal "grub-theme-nordic-nixos" { } ''
    mkdir -p "$out"

    cat > "$out/theme.txt" <<'EOF'
    title-text: ""
    desktop-image: "background.png"
    desktop-color: "#2E3440"
    message-font: "DejaVu Sans Bold 16"
    message-color: "#D8DEE9"
    terminal-font: "Unifont Regular"

    + progress_bar {
      id = "__timeout__"
      left = 20%
      top = 88%
      width = 60%
      height = 18
      fg_color = "#88C0D0"
      bg_color = "#3B4252"
      border_color = "#4C566A"
    }

    + boot_menu {
      left = 20%
      top = 24%
      width = 60%
      height = 54%
      item_font = "DejaVu Sans Bold 16"
      item_color = "#D8DEE9"
      item_height = 42
      item_spacing = 6
      item_padding = 8
      selected_item_font = "DejaVu Sans Bold 16"
      selected_item_color = "#88C0D0"
      scrollbar = true
      scrollbar_width = 8
    }
    EOF

    ln -s ${pkgs.nixos-artwork.wallpapers.simple-dark-gray-bootloader.gnomeFilePath} "$out/background.png"
  '';
in
{
  boot.supportedFilesystems = { btrfs = true; vfat = true; };

  boot.loader = {
    efi.canTouchEfiVariables = true;

    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      gfxmodeEfi = "1920x1080,auto";
      gfxpayloadEfi = "keep";
      timeout = 5;
      theme = nordicNixosGrubTheme;
      backgroundColor = "#2E3440";
    };
  };
}
