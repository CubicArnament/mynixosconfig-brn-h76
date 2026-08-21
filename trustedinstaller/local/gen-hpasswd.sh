#!/usr/bin/env bash
set -euo pipefail

OUT="${1:-env.hpasswd}"
umask 077

if [[ ! -c /dev/tty || ! -r /dev/tty || ! -w /dev/tty ]] || ! (: < /dev/tty) 2>/dev/null; then
  printf "ERROR: Interactive TTY required for password generation\n" >&2
  exit 2
fi

printf "\n==> Generating initial hashed password\n" > /dev/tty
printf "This password will be used ONLY for the first login after installation.\n" > /dev/tty
printf "You MUST change it immediately after first login using: run0 passwd wkubearnament\n\n" > /dev/tty

if ! command -v mkpasswd >/dev/null 2>&1; then
  printf "ERROR: mkpasswd not found. Install whois package: nix-shell -p whois\n" >&2
  exit 2
fi

printf "Enter initial password (will not echo): " > /dev/tty
IFS= read -rs PASSWORD1 < /dev/tty || {
  printf "\nPassword input failed\n" >&2
  exit 2
}
printf "\n" > /dev/tty

printf "Confirm initial password: " > /dev/tty
IFS= read -rs PASSWORD2 < /dev/tty || {
  printf "\nPassword input failed\n" >&2
  exit 2
}
printf "\n" > /dev/tty

if [[ "$PASSWORD1" != "$PASSWORD2" ]]; then
  printf "ERROR: Passwords do not match\n" >&2
  exit 2
fi

if [[ -z "$PASSWORD1" ]]; then
  printf "ERROR: Password cannot be empty\n" >&2
  exit 2
fi

if [[ ${#PASSWORD1} -lt 8 ]]; then
  printf "WARNING: Password is shorter than 8 characters (not recommended)\n" > /dev/tty
fi

printf "Generating yescrypt hash...\n" > /dev/tty
HASH=$(printf "%s\n" "$PASSWORD1" | mkpasswd -m yescrypt -s) || {
  printf "ERROR: Hash generation failed\n" >&2
  exit 1
}
unset PASSWORD1 PASSWORD2

mkdir -p "$(dirname "$OUT")"
TEMP_OUT=$(mktemp "${OUT}.tmp.XXXXXX")
trap 'rm -f "$TEMP_OUT"' EXIT
printf "%s\n" "$HASH" > "$TEMP_OUT"
chmod 600 "$TEMP_OUT"
mv -f "$TEMP_OUT" "$OUT"
trap - EXIT

printf "\nWrote hashed password to: %s\n" "$OUT"
printf "File permissions: 600 (owner read/write only)\n"
printf "\nREMINDER: Change this password immediately after first login:\n"
printf "  run0 passwd wkubearnament\n\n"
