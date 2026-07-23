{ ... }:
{
  boot.kernelParams = [
    # Убирает зависание на инициализации несуществующих legacy COM-портов
    # после resume на части современных ноутбуков.
    "8250.nr_uarts=0"

    # Смягчает AMD-Vi / NVMe resume-проблемы на Phoenix/Rembrandt-подобных платформах.
    "iommu=pt"

    # Запрещает глубокие APST power states у NVMe, которые часто дают
    # reset контроллера и медленный выход из сна.
    "nvme_core.default_ps_max_latency_us=0"

    # Для Phoenix-ноутбуков обычно актуален именно s2idle, а не legacy S3.
    "mem_sleep_default=s2idle"

    # Уменьшает ложные wake events от embedded controller во время s2idle.
    "acpi.ec_no_wakeup=1"
  ];

  # Do not force-load huawei_wmi on unrelated hardware or in VMs.
  # If the Honor/Huawei platform device exists, the module can still autoload
  # and will pick up this parameter.
  boot.extraModprobeConfig = ''
    options huawei_wmi report_brightness=1
  '';

  systemd.sleep.extraConfig = ''
    [Sleep]
    AllowSuspend=yes
    AllowHibernation=no
    AllowSuspendThenHibernate=no
    AllowHybridSleep=no
    SuspendState=mem
    MemorySleepMode=s2idle
  '';
}
