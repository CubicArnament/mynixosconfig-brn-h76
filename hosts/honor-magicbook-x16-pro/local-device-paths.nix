{
  # Сгенерируй реальные значения командой:
  #   nix run .#fetch-target-device-paths -- localhost        (с live-ISO)
  #   nix run .#fetch-target-device-paths -- user@<host>     (удалённо)
  #
  # После генерации запусти чтобы git не трекал локальные изменения:
  #   git update-index --skip-worktree hosts/honor-magicbook-x16-pro/local-device-paths.nix
  diskDevice = "/dev/disk/by-id/CONFIGURE-ME-run-fetch-target-device-paths";
  cameraDevicePath = "";
}
