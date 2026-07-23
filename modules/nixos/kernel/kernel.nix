{ lib, config, ... }:
let
  cfg = config.machine;
in
{
  boot.kernelParams = [
    # Убирает зависание на инициализации несуществующих legacy COM-портов
    # после resume на части современных ноутбуков. Безвреден в VM.
    "8250.nr_uarts=0"

    # Смягчает AMD-Vi / NVMe resume-проблемы на Phoenix/Rembrandt-платформах.
    # В VM не влияет на поведение.
    "iommu=pt"

    # Запрещает глубокие APST power states у NVMe.
    # В VM NVMe виртуальный — параметр игнорируется гостем.
    "nvme_core.default_ps_max_latency_us=0"
  ] ++ lib.optionals (!cfg.isVm) [
    # s2idle актуален только на физическом железе.
    # В VM suspend обычно не работает или обрабатывается гипервизором.
    "mem_sleep_default=s2idle"

    # Уменьшает ложные wake events от EC во время s2idle.
    # В VM EC нет — параметр бесполезен.
    "acpi.ec_no_wakeup=1"
  ];

  # huawei_wmi параметр: autoload произойдёт только если платформа существует,
  # но в VM лучше не засорять modprobe конфиг лишним.
  boot.extraModprobeConfig = lib.mkIf (!cfg.isVm) ''
    options huawei_wmi report_brightness=1
  '';

  systemd.sleep.extraConfig = lib.mkIf (!cfg.isVm) ''
    [Sleep]
    AllowSuspend=yes
    AllowHibernation=no
    AllowSuspendThenHibernate=no
    AllowHybridSleep=no
    SuspendState=mem
    MemorySleepMode=s2idle
  '';
}
