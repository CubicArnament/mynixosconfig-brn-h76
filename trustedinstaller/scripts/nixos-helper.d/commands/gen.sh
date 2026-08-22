#!/usr/bin/env bash
set -euo pipefail

TEMPLATE="${1:-}"
shift || true
TARGET="$PWD"
LANGUAGE=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --lang)
      [[ "$#" -ge 2 ]] || { printf "--lang requires a value\n" >&2; exit 2; }
      LANGUAGE="$2"
      shift 2
      ;;
    --lang=*)
      LANGUAGE="${1#*=}"
      shift
      ;;
    -*)
      printf "Unknown option: %s\n" "$1" >&2
      exit 2
      ;;
    *)
      if [[ "$TARGET" != "$PWD" ]]; then
        printf "Only one target directory is allowed.\n" >&2
        exit 2
      fi
      TARGET="$1"
      shift
      ;;
  esac
done

if [[ -z "$TEMPLATE" ]]; then
  printf "Usage: nix-hlp gen <project_flake|nix_shell|app_run|app_build|btp> [directory] [--lang language]\n" >&2
  exit 2
fi

case "$TEMPLATE" in
  project_flake|nix_shell|app_run|app_build|btp) ;;
  *)
    printf "Unknown template: %s\n" "$TEMPLATE" >&2
    exit 2
    ;;
esac

mkdir -p "$TARGET"
TARGET=$(cd "$TARGET" && pwd)
if [[ -n "$LANGUAGE" ]]; then
  export NIX_HLP_LANGUAGE="$LANGUAGE"
fi
exec bash "$NIX_HLP_TEMPLATES_DIR/$TEMPLATE.sh" "$TARGET"
