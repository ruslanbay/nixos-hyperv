# 😱 Совсем не страшно 💀 Развёртываем NixOS в Hyper-V: minimal Gnome + zRAM + DNS-over-HTTPS 👻

#linux #nix #nixos #hyper-v

<figure style="float: left; margin-right: 15px; margin-left: 5px;">
    <img src="frankenstein.jpg" alt="nixOS" style="width: 340px; height: 415px; object-fit: cover; object-position: center;" />
    <figcaption style="font-size: 12px;"><i>Знаю, немного опоздал с хелоуинской тематикой =)</i></figcaption>
</figure>

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
Модифицируем полученный configuration.nix. 

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

#### 7.5. Define a user account <sup>[[doc]]()</sup>

Для каждого пользователя 

https://github.com/ruslanbay/nixos-hyperv/blob/main/configuration.nix?plain=1#L101

```nix
# Define a user account. Don't forget to set a password with ‘passwd’.
users.users.admin = {
  password = "admin"; # This option should only be used for public accounts!
  isNormalUser = true;
  extraGroups = [ "wheel" "video" ];
  packages = with pkgs; [
  #  vim
  ];
};
```

```nix
users.users.gdm = {
  extraGroups = [ "video" ];
};
```

Применим изменения из configuration.nix:
```bash
nixos-install
reboot
```


rm /mnt/etc/nixos/configuration.nix



В качестве примера я установил Gnome и Firefox.

В Fedora сначала устанавливал минимально возможный Custom Operating System

Зачем держать то, чем я не пользуюсь на диске, в оперативной памяти, обновлять?


Можно установить приложение для отдельного пользователя. В отличии, например, от Windows, где программы чаще всего устанавливается в систему и доступны всем пользователям.

Я хочу изолировать Steam от окружения, которое я использую, например, для доступа к банковским приложениям. NixOS поволяет разделить эти пространства.

https://nixos.org/manual/nixos/stable/#sec-installation-manual





```bash
nixos-generate-config --root /mnt
nano /mnt/etc/nixos/configuration.nix
nixos-install
reboot

# After modifying configuration.nix
sudo nixos-rebuild switch -I nixos-config=/etc/nixos/configuration.nix
```

### Gnome


### Активируем zRAM


### DNS-over-HTTPS (DoH)

Моя машина находится за Firewall, который блокирует подключение к любым портам кроме 443 (HTTPS).


## Ссылки
Wiki
..


___

Ещё один excuse, к которому некоторые прибегают, чтобы оправдать свою беспечность. Я не достаточно важен чтобы меня взламывать, у меня на компьютере нет никаких ценных данных. Проблема в том, что в последнее время стоимость совершения атаки значительно снизилась.

Identity theft (на русский термин можно перевести как "кража [цифровой] личности"). Набирает обороты. В самом простом случае это может быть создание фейковых профилей в социальных сетях с вашими данными. В худшем случае это может быть вывод средств с ваших банковских аккаунтов, оформление кредитов и прочий фрод.

Мы должны стремиться к развитию безопасных и приватных систем и сервисов.