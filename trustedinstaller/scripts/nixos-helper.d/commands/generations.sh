#!/usr/bin/env bash
set -euo pipefail
nix profile history --profile /nix/var/nix/profiles/system | tail -20
