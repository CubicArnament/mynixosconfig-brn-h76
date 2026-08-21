#!/usr/bin/env bash
set -euo pipefail

printf "Current generation: "
readlink /nix/var/nix/profiles/system | sed 's/.*system-//'
printf "Boot entry: "
readlink /run/booted-system | sed 's/.*system-//' || printf "not booted from NixOS\n"
