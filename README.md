# 😱 Развёртываем NixOS в Hyper-V: minimal Gnome, zRAM, DNS-over-HTTPS, Wireguard 👻

#linux #nix #nixos #hyperv

<img src="article-assets/frankenstein.jpg" alt="nixOS" title="Знаю, немного опоздал с хелоуинской тематикой =)" style="margin-bottom: 15px;" />

Хочу поделиться опытом развёртывания NixOS. В отличии от традиционных дистрибутивов, NixOS позволяет получить полностью кастомную операционную систему. Конфигурация системы описывается в виде кода. Этот подход обеспечивает предсказуемую, повторяемую сборку.

Из других преимуществ системы могу выделить immutable дизайн, атомарные обновления, автоматические снапшоты с возможностью откатиться на предыдущее состояние, независимый (изолированный) набор приложений для каждого пользователя. С точки зрения технологий это последний писк в мире операционных систем.

NixOS набирает популярность среди DevOps, но я хочу рассмотреть систему с пользовательской точки зрения.

Архитектурно NixOS сильно отличается от тех же Windows, Ubuntu или Fedora, но в чём преимущество для конечного пользователя? Классические дистрибутивы инертные - изменения должны быть совместимы с существующими инсталяциями. К тому же за прошедшие десятилетия в стремлении удовлетворить потребности как можно более широкой аудитории, эти системы превратились в комбаины с кучей легаси и предустановленного хлама. Ещё одна проблема в том, что для монетизации пользовательской базы некоторые вендоры злоуптребляют телеметрией, предустанавливают "проплаченные" приложения вроде Facebook, Amazone и прочее. Этот хлам занимает место на диске, в оперативной памяти, в фоне собирает ваши персональные данные с неизвестной целью.

Ещё одна проблема заключается в том, что чем больше приложений установлено, тем выше вероятность наличия в системе уязвимостей, больше простор для потенциальных злоумышленников (attack surface). Яркой иллюстрацией тому стала ситуация с xz
https://www.phoronix.com/news/XZ-CVE-2024-3094

С развитием облачных сервисов и Power Web Applications для многих пользователей единственным используемым приложением на их компьютере стал браузер. Появились системы, которые полностью построены вокруг взаимодействия пользователя с браузером. Например, ChromiumOS.

Если вы зададитесь целью избавиться от неиспользуемых приложений, то в классическом случае вы устанавливаете систему, затем пытаетесь удалить всё ненужное.

NixOS предлагает другой подход. Список устанавливаемых пакетов и настройки конечной системы описываются в конфигурационном файле. Что-то вроде terraform для персонального компьютера. В Сети вы можете найти готовые конфигурационные файлы для различных систем. В этой статье я приведу пример конфигурационного файла минимальной системы, развёртываемой в Hyper-V.

## Manual Installation <sup>[[doc]](https://nixos.org/manual/nixos/stable/#sec-installation-manual)</sup>
### 1. Obtaining NixOS <sup>[[doc]](https://nixos.org/manual/nixos/stable/#sec-obtaining)</sup>
Скачаем установочный образ с [официального сайта](https://nixos.org/download/). В моём случае это [latest-nixos-minimal-x86_64-linux.iso](https://channels.nixos.org/nixos-24.05/latest-nixos-minimal-x86_64-linux.iso).

### 2. Создание виртуальной машины Hyper-V
Создадим в Hyper-V новую виртуальную машину: Hyper-V Manager -> Action -> New -> Virtual Machine. В разделе "Specify Generation" выберите Generation 2. Далее задайте размер оперативной памяти, я указал 1512 MB. В разделе "Configure Networking" выберете Default Switch. При необходимости вы можете создать виртуальный switch, например:

```powershell
New-VMSwitch -Name 'LAN' -SwitchType Internal
New-VMSwitch -Name 'WAN' -NetAdapterName 'WiFi' -AllowManagementOS 0
```
Далее укажите размер нового виртуального жесткого диска, я выбрал 12ГБ. В разделе "Installation Options" выберете образ, который вы скачали на шаге 1.

### 3. Log in
Включите созданную виртуальную машину. По умолчанию вы будете авторизованы под пользователем nixos с пустым паролем. Чтобы подключиться к машине по SSH вам необходимо изменить пароль:
```bash
sudo -i
passwd nixos
```
Теперь вы можете подключиться к виртуальной машине по SSH под пользователем nixos. Чтобы узнать IP-адрес выполните в виртуальной машине команду `ipconfig`

### 4. Enable zRAM <sup>[[doc]](https://wiki.archlinux.org/title/Zram#Manually)</sup>
Если объём оперативной памяти ограничен рекомендую активировать zRAM:
```bash
modprobe zram
zramctl /dev/zram0 --algorithm lzo-rle --size "$(($(grep -Po 'MemTotal:\s*\K\d+' /proc/meminfo)))KiB"
mkswap -U clear /dev/zram0
swapon --priority 100 /dev/zram0
```

### 5. Partitioning<sup>[[doc]](https://nixos.org/manual/nixos/stable/#sec-installation-manual-partitioning-UEFI)</sup>

В своей системе я использую zRAM вместо выделенного раздела для swap, поэтому здесь мои шаги отличаются от официальной инструкции.

```bash
parted /dev/sda -- mklabel gpt
parted /dev/sda -- mkpart root ext4 512MB -0GB
parted /dev/sda -- mkpart ESP fat32 1MB 512MB
parted /dev/sda -- set 2 esp on
parted --list
mkfs.ext4 -L nixos /dev/sda1
mkfs.fat -F 32 -n boot /dev/sda2
```

### 6. Installing <sup>[[doc]](https://nixos.org/manual/nixos/stable/#sec-installation-manual-installing)</sup>

```bash
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/boot /mnt/boot
```

Сгенерируем начальный конфигурационный файл:
```bash
nixos-generate-config --root /mnt
```
На выходе получим два файла:
```bash
ls -lah /mnt/etc/nixos/*.nix
-rw-r--r-- 1 root root 7.1K Nov  7 18:29 /mnt/etc/nixos/configuration.nix
-rw-r--r-- 1 root root 1.3K Nov  7 11:19 /mnt/etc/nixos/hardware-configuration.nix
```

В Сети по запросу "nixos hyper-v" множество примеров устаревших конфигураций с различными workaround, которые больше не актуальны. NixOS автоматически определит виртуальную машину Hyper-V, вы можете убедиться в этом по наличию строки `virtualisation.hypervGuest.enable = true;` в файле `/etc/nixos/hardware-configuration.nix`

### 7. Customising configuration.nix <sup>[[doc]](https://nixos.org/manual/nixos/stable/#ch-configuration)</sup>
Модифицируем `/mnt/etc/nixos/configuration.nix`
```bash
nano /mnt/etc/nixos/configuration.nix
```

#### 7.1. Automatic Upgrades <sup>[[doc]](https://nixos.org/manual/nixos/stable/#sec-upgrading-automatic)</sup>

https://github.com/ruslanbay/nixos-hyperv/blob/main/configuration.nix?plain=1#L17

```nix
# Enable auto upgrades
system.autoUpgrade.enable = true;
system.autoUpgrade.channel = "https://channels.nixos.org/nixos-24.05";
```

#### 7.2. Enable zRAM <sup>[[doc]](https://search.nixos.org/options?channel=24.05&from=0&size=50&sort=relevance&type=packages&query=zramSwap)</sup>

https://github.com/ruslanbay/nixos-hyperv/blob/main/configuration.nix?plain=1#L29

```nix
# Enable zRAM
zramSwap = {
  enable = true;
  priority = 100;
  algorithm = "lzo-rle";
  memoryPercent = 100;
};
```

#### 7.3. Enabling GNOME <sup>[[1]](https://nixos.org/manual/nixos/stable/#chap-gnome)  [[2]](https://wiki.nixos.org/wiki/GNOME)</sup>

https://github.com/ruslanbay/nixos-hyperv/blob/main/configuration.nix?plain=1#L58

```nix
services.xserver.enable = true;
# Enable Gnome
services.xserver.desktopManager = {
  gnome.enable = true;
};
services.xserver.displayManager = {
  gdm.enable = true;
  gdm.wayland = true;
};
programs.xwayland.enable = false;
  
# Debloat
documentation.nixos.enable = false;
services.xserver.excludePackages = [ pkgs.xterm ];
services.gnome.core-utilities.enable = false;
environment.gnome.excludePackages = (with pkgs; [
  gnome.gnome-shell-extensions
  gnome-tour
  gnome-browser-connector
  gnome.gnome-shell
]);
```

#### 7.4. Enabling PipeWire <sup>[[doc]](https://wiki.nixos.org/wiki/PipeWire)</sup>

https://github.com/ruslanbay/nixos-hyperv/blob/main/configuration.nix?plain=1#L88

```nix
# Enable sound.
hardware.pulseaudio.enable = false;
security.rtkit.enable = true;
services.pipewire = {
  enable = true;
  alsa.enable = true;
  alsa.support32Bit = true;
  pulse.enable = true;
};
```

#### 7.5. Define a user account

Создадим двух пользователей: admin и user. Пароль я указал только в качестве примера. В нормальном сценарии после завершения установки системы пользователь входит в систему и задаёт пароль с помощью `passwd`. Пользователь admin имеет повышенные привелегии, так как находится в группе wheel.

Одно из преимуществ NixOS - возможность установить приложения изолированно для каждого пользовтеля. Например, вы можете создать отдельного пользователя для банковских приложений, для Steam и так далее.

Для поиска приложений воспользуйтесь https://search.nixos.org/packages

https://github.com/ruslanbay/nixos-hyperv/blob/main/configuration.nix?plain=1#L101

```nix
# Define a user account. Don't forget to set a password with ‘passwd’.
users.users.admin = {
  password = "<admin-password>"; # This option should only be used for public accounts!
  openssh.authorizedKeys.keys = [ "ssh-ed25519 <openssh-public-key> user" ];
  isNormalUser = true;
  extraGroups = [ "wheel" "video" ];
  packages = with pkgs; [
  #  vim
  ];
};

users.users.user = {
  password = "<user-password>"; # This option should only be used for public accounts!
  isNormalUser = true;
  extraGroups = [ "video" ];
  packages = with pkgs; [
  # gnome.nautilus
    gnome-console
    firefox-unwrapped
  ];
};
```

Для корректной работы gdm необходимо добавить gdm и всех созданных пользователей в группу video:

```nix
users.users.gdm = {
  extraGroups = [ "video" ];
};
```

#### 7.6. List packages installed in system profile

Перечислим системные компоненты. Я добавлю wireguard-tools:

https://github.com/ruslanbay/nixos-hyperv/blob/main/configuration.nix?plain=1#L130

```nix
# List packages installed in system profile. To search, run:
# $ nix search wget
environment.systemPackages = with pkgs; [
  wireguard-tools
];
```

#### 7.7. Enable the OpenSSH daemon <sup>[[doc]](https://wiki.nixos.org/wiki/SSH_public_key_authentication#SSH_server_config)</sup>

https://github.com/ruslanbay/nixos-hyperv/blob/main/configuration.nix?plain=1#L144

```nix
# Enable the OpenSSH daemon.
services.openssh = {
  enable = true;
  ports = [ 22 ];
  settings = {
    PasswordAuthentication = false;
    PermitRootLogin = "no"; # do not allow to login as root user
    KbdInteractiveAuthentication = false;
  };
};
```

Публичный ключ добавьте в `openssh.authorizedKeys.keys`
```nix
users.users.admin = {
  password = "<admin-password>"; # This option should only be used for public accounts!
  openssh.authorizedKeys.keys = [ "ssh-ed25519 <openssh-public-key> user" ];
  isNormalUser = true;
  extraGroups = [ "wheel" "video" ];
  packages = with pkgs; [
  #  vim
  ];
};
```

Пример команды PowerShell для генерации пары ключей OpenSSH без passphrase:
```powershell
ssh-keygen -t ed25519 -f .ssh/nixos_admin -P '""'
```

Пример команды для подключения:
```powershell
ssh admin@<ip-address> -p 22 -i .ssh/nixos-admin
```

#### 7.8 Firewall settings <sup>[[doc]](https://wiki.nixos.org/wiki/Firewall)</sup>

https://github.com/ruslanbay/nixos-hyperv/blob/main/configuration.nix?plain=1#L155

```nix
# Open ports in the firewall.
# networking.firewall.enable = true;
# networking.firewall.allowedTCPPorts = [  ];
# networking.firewall.allowedUDPPorts = [  ];
networking.enableIPv6 = false;
```

#### 7.9 DNS-over-HTTPS <sup>[[doc]](https://wiki.nixos.org/wiki/Encrypted_DNS)</sup>

Настроим DNS-over-HTTPS. В качестве резолвера будем использовать сервера Quad9 DNS (9.9.9.9).

https://github.com/ruslanbay/nixos-hyperv/blob/main/configuration.nix?plain=1#L161

```nix
# Setup DNS-over-HTTPS using dnscrypt-proxy
# Make sure you don't have services.resolved.enable on.
services.resolved.enable = false;

networking = {
  nameservers = [ "127.0.0.1" "::1" ];
  # If using dhcpcd:
  # dhcpcd.extraConfig = "nohook resolv.conf";
  # If using NetworkManager:
  # networkmanager.dns = "none";
};

services.dnscrypt-proxy2.enable = true;
services.dnscrypt-proxy2.settings = {
  ipv6_servers = false;
  server_names = [
    "quad9-dnscrypt-ip4-filter-pri"
    "quad9-dnscrypt-ip4-filter-ecs-pri"
  ];
  sources.public-resolvers = {
    urls = [ "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md" ];
    cache_file = "/var/lib/dnscrypt-proxy/public-resolvers.md";
    minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
    refresh_delay = 72;
    prefix = "";
  };
};
systemd.services.dnscrypt-proxy2.serviceConfig = {
  StateDirectory = "dnscrypt-proxy";
  # If you're trying to set up persistence with dnscrypt-proxy2 and it isn't working
  # because of permission issues, try the following:
  # StateDirectory = lib.mkForce "";
  # ReadWritePaths = "/var/lib/dnscrypt-proxy"; # Cache directory for dnscrypt-proxy2, persist this
};
```

#### 7.10. ProtonVPN via Wireguard <sup>[[1]](https://wiki.nixos.org/wiki/WireGuard#Client_setup_2)</sup>

Скачайте конфигурационный файл для Wireguard. Инструкция: https://protonvpn.com/support/wireguard-configurations

Из конфигурационного файла скопируйте приватный ключ и сохраните его в файл `/etc/wireguard/private-keys/wg-private.key` Ограничим права доступа к приватному ключу <sup>[[1]](https://wiki.archlinux.org/title/WireGuard)</sup>:
```bash
mkdir -p /etc/wireguard/private-keys/

chown root:systemd-network /etc/wireguard/private-keys/wg-private.key
chmod 0640 /etc/wireguard/private-keys/wg-private.key

chown root:systemd-network /etc/wireguard/private-keys/
chmod 0640 /etc/wireguard/private-keys/

chown root:systemd-network /etc/wireguard/
chmod 0640 /etc/wireguard/
```

Добавим настройки в configuration.nix:

https://github.com/ruslanbay/nixos-hyperv/blob/main/configuration.nix?plain=1#L130

```nix
# List packages installed in system profile. To search, run:
# $ nix search wget
environment.systemPackages = with pkgs; [
  wireguard-tools
];
```

https://github.com/ruslanbay/nixos-hyperv/blob/main/configuration.nix?plain=1#L196

```nix
# ProtonVPN via Wireguard
networking.wg-quick.interfaces = {
  wg0 = {
    address = [ "10.2.0.2/32" ];
    dns = [ "10.2.0.1" ];
    privateKeyFile = "/etc/wireguard/private-keys/wg-private.key";
    peers = [
      {
        publicKey = "<wg-public-key>";
        allowedIPs = [ "0.0.0.0/0" ];
        endpoint = "<ip-address>:51820";
        persistentKeepalive = 25;
      }
    ];
  };
};
```

### 8. Применим изменения и завершим установку <sup>[[doc]](https://nixos.org/manual/nixos/stable/#sec-installation-manual-installing)</sup>

Применим изменения и завершим установку:
```bash
nixos-install
reboot
```
Вы можете в любой момент внести изменения в `/etc/nixos/configuration.nix`. Чтобы их применить вы полните следующую команду:

```bash
sudo nixos-rebuild switch -I nixos-config=/etc/nixos/configuration.nix
reboot
```

Посмотреть список снапшотов (generations):
```nix
nix --extra-experimental-features nix-command profile history --profile /nix/var/nix/profiles/system
```
Удалить снапшоты, созданные более 14 дней назад:
```nix
sudo nix --extra-experimental-features nix-command profile wipe-history --profile /nix/var/nix/profiles/system --older-than 14d

sudo nix --extra-experimental-features nix-command store gc
```


<img src="article-assets/itsalive.jpg" />

## Ссылки
 - [NixOS Manual](https://nixos.org/manual/nixos/stable/)
 - [NixOS Wiki](https://wiki.nixos.org/wiki/NixOS_Wiki)
 - [Packages search](https://search.nixos.org/packages)
 - [Options search](https://search.nixos.org/options)
 - [Github](https://github.com/NixOS/nix)
 - [nix.dev](https://nix.dev/)
