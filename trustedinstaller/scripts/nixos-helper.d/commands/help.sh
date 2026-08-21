#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
Usage: nix-hlp [command] [options]

Uses the configured host flake at /etc/nixos. System rebuilds also activate
the configured Home Manager user environment.

Commands:
  switch        Build and apply now. This is the default.
  boot          Build now, activate on the next boot.
  test          Build and activate until the next boot.
  build         Build without activating.
  home          Build and activate only Home Manager, without root.
  update        Update flake.lock in /etc/nixos.
  status        Show current generation and boot entry.
  generations   List recent system generations.
  rollback      Roll back to the previous generation.
  clean [days]  Remove old generations; defaults to 7 days.
  diff          Compare the current system with a new build.
  config-setup [directory]
                Link /etc/nixos to a userspace flake directory.
  fmt [path]    Format a project using the configured Nix formatter.
  create <template> [directory]
                Create project_flake, nix_shell, app_run, app_build, or btp.
  prefetch <url>
                Print a fetchurl SRI hash.
  set-password  Set the local password for the configured user.

Command-specific options are passed through.
EOF
