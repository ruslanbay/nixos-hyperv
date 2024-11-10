# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Enable auto upgrades
  system.autoUpgrade.enable = true;
  system.autoUpgrade.channel = "https://channels.nixos.org/nixos-24.05";

  # To make GDM work add:
  # users.users.gdm = {
  #  extraGroups = [ "video" ];
  # };
  # 
  # OR use the following workaround:
  # boot.kernelParams = [ "nomodeset" ];

  # Enable zRAM
  zramSwap = {
    enable = true;
    priority = 100;
    algorithm = "lzo-rle";
    memoryPercent = 100;
  };

  networking.hostName = "compucter"; # Define your hostname.
  # Pick only one of the below networking options.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.
  # networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  #   useXkbConfig = true; # use xkb.options in tty.
  # };

  # Enable the X11 windowing system.
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

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.admin = {
    password = "<admin-password>"; # This option should only be used for public accounts!
    openssh.authorizedKeys.keys = [ "ssh-ed25519 <openssh-public-key> user" ];
    isNormalUser = true;
    extraGroups = [ "wheel" "video" ];
    packages = with pkgs; [
    # vim
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

  users.users.gdm = {
    extraGroups = [ "video" ];
  };
  
  # Allow unfree packages
  nixpkgs.config.allowUnfree = false;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

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

  # Open ports in the firewall.
  # networking.firewall.enable = true;
  # networking.firewall.allowedTCPPorts = [  ];
  # networking.firewall.allowedUDPPorts = [  ];
  networking.enableIPv6 = false;

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

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This option defines the first version of NixOS you have installed on this particular machine,
  # and is used to maintain compatibility with application data (e.g. databases) created on older NixOS versions.
  #
  # Most users should NEVER change this value after the initial install, for any reason,
  # even if you've upgraded your system to a new NixOS release.
  #
  # This value does NOT affect the Nixpkgs version your packages and OS are pulled from,
  # so changing it will NOT upgrade your system - see https://nixos.org/manual/nixos/stable/#sec-upgrading for how
  # to actually do that.
  #
  # This value being lower than the current NixOS release does NOT mean your system is
  # out of date, out of support, or vulnerable.
  #
  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?

}