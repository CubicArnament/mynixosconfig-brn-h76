#!/usr/bin/env sh
# scripts/vm-install-mount.sh
#
# Скрипт для установки nixos-vm конфига в виртуальной машине.
# Запускать внутри live-среды (NixOS ISO, Arch ISO и т.п.) от root.
#
# Что делает:
#   1. Находит подходящий раздел для установки (ext4 или btrfs, не swap, не vfat)
#   2. При однозначной ситуации монтирует автоматически
#   3. При нескольких кандидатах — показывает меню, выбираешь цифрой
#   4. Если есть отдельный EFI/boot раздел — монтирует его тоже
#   5. Генерирует hardware-configuration.nix
#   6. Запускает nixos-install --flake .#nixos-vm
#
# Использование:
#   run0 sh ./scripts/vm-install-mount.sh
#   run0 sh ./scripts/vm-install-mount.sh --dry-run   # показать что нашлось без монтирования
#
# Требования: lsblk, findmnt, mktemp, blkid, nixos-install, nixos-generate-config

set -eu

DRY_RUN=0
if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

# ─── Вспомогательные функции ──────────────────────────────────────────────────

# Вывод с цветом если терминал поддерживает
info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[1;32m[OK]\033[0m    %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
die()   { printf '\033[1;31m[ERR]\033[0m   %s\n' "$*" >&2; exit 1; }
prompt(){ printf '\033[1;36m[?]\033[0m     %s' "$*"; }

# Проверка root
if [ "$(id -u)" -ne 0 ]; then
  die "Запусти скрипт от root: run0 sh ./scripts/vm-install-mount.sh"
fi

# ─── Собрать список разделов-кандидатов ──────────────────────────────────────
#
# Кандидат: раздел с fstype ext4 или btrfs, не смонтированный, не swap, не vfat.

info "Сканирую разделы..."

# Получаем список всех разделов (path + fstype + size + mountpoint).
# PARTTYPENAME не читаем через этот вывод — там могут быть пробелы ("EFI System").
# EFI определяем отдельно: vfat-раздел на том же диске что и системный раздел.
PARTS_RAW=$(lsblk -rno PATH,FSTYPE,SIZE,MOUNTPOINT,TYPE 2>/dev/null || true)

if [ -z "$PARTS_RAW" ]; then
  die "lsblk не вернул данных. Убедись что запущен от root и lsblk доступен."
fi

CANDIDATES=""
EFI_PART=""

while IFS=" " read -r path fstype size mountpoint type; do
  # Нужен именно part или lvm, не disk/loop
  case "$type" in
    part|lvm) ;;
    *) continue ;;
  esac

  case "$fstype" in
    vfat)
      # Запоминаем первый vfat-раздел как кандидат на EFI (если не смонтирован)
      case "${mountpoint:-}" in
        ""|none)
          [ -z "$EFI_PART" ] && EFI_PART="$path"
          ;;
      esac
      continue
      ;;
    swap|""|iso9660|squashfs|tmpfs|devtmpfs|proc|sysfs|cgroup*|overlay)
      continue
      ;;
    ext4|btrfs)
      ;;  # кандидат
    *)
      continue
      ;;
  esac

  # Уже смонтирован — пропускаем (кроме /mnt)
  case "${mountpoint:-}" in
    /mnt|/mnt/*) ;;  # уже в /mnt — всё равно показываем как кандидат
    ""|none)     ;;  # не смонтирован — кандидат
    *)           continue ;;  # смонтирован куда-то ещё
  esac

  CANDIDATES="${CANDIDATES}${path} ${fstype} ${size} ${mountpoint:-none}
"
done << EOF
$PARTS_RAW
EOF

CANDIDATES=$(printf "%s" "$CANDIDATES" | grep -v '^[[:space:]]*$' || true)

if [ -z "$CANDIDATES" ]; then
  printf '\n'
  warn "Не найдено ни одного подходящего раздела (ext4/btrfs)."
  printf '\n'
  info "Похоже диск ещё не размечен или все разделы уже заняты."
  info "Разметь диск вручную:"
  printf '\n'
  printf '  1. Посмотри доступные диски:\n'
  printf '       lsblk\n'
  printf '\n'
  printf '  2. Запусти разметку (заменит всё на диске!):\n'
  printf '       cfdisk /dev/vda     # или /dev/sda — смотри lsblk\n'
  printf '\n'
  printf '  3. Создай разделы:\n'
  printf '       - 1G   тип: EFI System  (для /boot)\n'
  printf '       - остаток  тип: Linux filesystem  (для /)\n'
  printf '\n'
  printf '  4. Отформатируй:\n'
  printf '       mkfs.vfat -F 32 /dev/vda1\n'
  printf '       mkfs.ext4 /dev/vda2           # или: mkfs.btrfs /dev/vda2\n'
  printf '\n'
  printf '  5. Запусти этот скрипт снова:\n'
  printf '       run0 sh ./scripts/vm-install-mount.sh\n'
  printf '\n'
  exit 1
fi

# ─── Подсчёт кандидатов ───────────────────────────────────────────────────────

CAND_COUNT=$(printf "%s\n" "$CANDIDATES" | grep -c '.' || true)

printf '\n'
info "Найдено разделов-кандидатов: $CAND_COUNT"
printf '\n'

# Покажем всё что нашлось.
# Используем awk а не while+pipe: pipe создаёт subshell и счётчик N
# в родительском процессе не инкрементируется — список всегда показывал бы [1].
printf "%s\n" "$CANDIDATES" | awk '{
  printf "  [%d]  %-14s  |  fstype=%-5s  |  size=%-8s  |  mount=%s\n",
    NR, $1, $2, $3, $4
}'
printf '\n'

if [ -n "$EFI_PART" ]; then
  info "EFI/boot раздел: $EFI_PART (будет смонтирован в /mnt/boot)"
  printf '\n'
fi

[ "$DRY_RUN" -eq 1 ] && { info "Dry-run режим, выхожу."; exit 0; }

# ─── Выбор раздела ────────────────────────────────────────────────────────────

CHOSEN_PART=""
CHOSEN_FSTYPE=""

if [ "$CAND_COUNT" -eq 1 ]; then
  # Единственный кандидат — берём без вопросов
  CHOSEN_PART=$(printf "%s\n" "$CANDIDATES" | awk 'NR==1 {print $1}')
  CHOSEN_FSTYPE=$(printf "%s\n" "$CANDIDATES" | awk 'NR==1 {print $2}')
  [ -n "$CHOSEN_PART" ] || die "Не удалось определить раздел из списка кандидатов"
  ok "Единственный кандидат — выбираю автоматически: $CHOSEN_PART ($CHOSEN_FSTYPE)"
else
  # Несколько кандидатов — спрашиваем
  while true; do
    prompt "Выбери раздел для установки [1-$CAND_COUNT]: "
    read -r CHOICE < /dev/tty

    # Проверяем что введено число в допустимом диапазоне
    case "$CHOICE" in
      ''|*[!0-9]*)
        warn "Введи число от 1 до $CAND_COUNT"
        continue
        ;;
    esac

    if [ "$CHOICE" -lt 1 ] || [ "$CHOICE" -gt "$CAND_COUNT" ]; then
      warn "Число должно быть от 1 до $CAND_COUNT"
      continue
    fi

    CHOSEN_PART=$(printf "%s\n" "$CANDIDATES" | awk -v n="$CHOICE" 'NR==n {print $1}')
    CHOSEN_FSTYPE=$(printf "%s\n" "$CANDIDATES" | awk -v n="$CHOICE" 'NR==n {print $2}')
    # Проверка: awk мог вернуть пустую строку если CHOICE вышло за границу
    [ -n "$CHOSEN_PART" ] || { warn "Неверный номер, попробуй ещё раз"; continue; }
    break
  done
  ok "Выбран раздел: $CHOSEN_PART ($CHOSEN_FSTYPE)"
fi

printf '\n'

# ─── Автопоиск EFI если не нашли по типу ────────────────────────────────────

if [ -z "$EFI_PART" ]; then
  # Пробуем найти vfat раздел на том же диске.
  # Используем -rno без -p: флаг -p выводит полный путь /dev/vda,
  # и "/dev/$PARENT_DISK" давало бы /dev//dev/vda.
  PARENT_DISK=$(lsblk -rno PKNAME "$CHOSEN_PART" 2>/dev/null | head -n 1 || true)
  if [ -n "$PARENT_DISK" ]; then
    EFI_PART=$(lsblk -rno PATH,FSTYPE,MOUNTPOINT "/dev/$PARENT_DISK" 2>/dev/null | \
      awk '$2 == "vfat" && ($3 == "" || $3 == "none") {print $1; exit}' || true)
    if [ -n "$EFI_PART" ]; then
      info "Найден vfat раздел на том же диске: $EFI_PART → /mnt/boot"
    fi
  fi
fi

# ─── Монтирование ─────────────────────────────────────────────────────────────

# Проверяем не смонтирован ли уже
ALREADY_MOUNTED=$(findmnt -n -o TARGET "$CHOSEN_PART" 2>/dev/null || true)
if [ -n "$ALREADY_MOUNTED" ] && [ "$ALREADY_MOUNTED" != "/mnt" ]; then
  warn "Раздел $CHOSEN_PART уже смонтирован в $ALREADY_MOUNTED"
  prompt "Отмонтировать и перемонтировать в /mnt? [y/N]: "
  read -r UNMOUNT_REPLY < /dev/tty
  case "$UNMOUNT_REPLY" in
    y|Y|yes|YES) umount "$CHOSEN_PART" || die "Не удалось отмонтировать $CHOSEN_PART" ;;
    *) die "Прерываю. Отмонтируй раздел вручную: umount $CHOSEN_PART" ;;
  esac
fi

info "Монтирую $CHOSEN_PART → /mnt..."
mkdir -p /mnt
if [ "$CHOSEN_FSTYPE" = "btrfs" ]; then
  # Для btrfs монтируем корневой subvolume если он существует
  mount -t btrfs -o subvol=/ "$CHOSEN_PART" /mnt 2>/dev/null || \
  mount "$CHOSEN_PART" /mnt || die "Не удалось смонтировать $CHOSEN_PART в /mnt"
else
  mount "$CHOSEN_PART" /mnt || die "Не удалось смонтировать $CHOSEN_PART в /mnt"
fi
ok "Смонтировано: $CHOSEN_PART → /mnt"

if [ -n "$EFI_PART" ]; then
  info "Монтирую EFI $EFI_PART → /mnt/boot..."
  mkdir -p /mnt/boot
  mount "$EFI_PART" /mnt/boot || warn "Не удалось смонтировать $EFI_PART в /mnt/boot — продолжаю без него"
  ok "Смонтировано: $EFI_PART → /mnt/boot"
fi

printf '\n'

# ─── hardware-configuration.nix ──────────────────────────────────────────────

info "Генерирую hardware-configuration.nix..."
nixos-generate-config --root /mnt || die "nixos-generate-config завершился с ошибкой"

printf '\n'
info "Сгенерировано:"
printf '  /mnt/etc/nixos/hardware-configuration.nix\n'
printf '\n'
warn "Не забудь скопировать flake-конфиг в /mnt если нужно:"
printf '  cp -r /path/to/nixos-flake /mnt/etc/nixos/\n'
printf '\n'

# ─── nixos-install ────────────────────────────────────────────────────────────

info "Запускаю nixos-install --flake .#nixos-vm --root /mnt"
printf '\n'

# Определяем где лежит flake
FLAKE_DIR=""
if [ -f "./flake.nix" ]; then
  FLAKE_DIR="."
elif [ -f "/mnt/etc/nixos/flake.nix" ]; then
  FLAKE_DIR="/mnt/etc/nixos"
else
  warn "flake.nix не найден ни в текущем каталоге, ни в /mnt/etc/nixos/"
  info "Укажи путь к flake вручную:"
  prompt "Путь к flake (или Enter чтобы пропустить nixos-install): "
  read -r FLAKE_DIR < /dev/tty
  [ -z "$FLAKE_DIR" ] && { info "nixos-install пропущен. Смонтировано в /mnt, конфиг сгенерирован."; exit 0; }
fi

nixos-install \
  --flake "${FLAKE_DIR}#nixos-vm" \
  --root /mnt \
  --no-root-passwd \
  && ok "nixos-install завершился успешно!" \
  || die "nixos-install завершился с ошибкой"

printf '\n'
ok "Готово. Перезагружайся: reboot"
