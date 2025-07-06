{
  config,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];
  nix.settings.experimental-features = ["nix-command" "flakes"];
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = ["ntfs"];

  networking.hostName = "linus-x1"; # Define your hostname.

  # Enable networking
  networking = {
    networkmanager.enable = true;
    wireless.iwd.enable = true;
    networkmanager.wifi.backend = "iwd";
    wireguard.enable = true;
    firewall.checkReversePath = false; #so that the wireguard vpn works
  };
  # Set your time zone.
  time.timeZone = "Europe/Berlin";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "de_DE.UTF-8";
    LC_IDENTIFICATION = "de_DE.UTF-8";
    LC_MEASUREMENT = "de_DE.UTF-8";
    LC_MONETARY = "de_DE.UTF-8";
    LC_NAME = "de_DE.UTF-8";
    LC_NUMERIC = "de_DE.UTF-8";
    LC_PAPER = "de_DE.UTF-8";
    LC_TELEPHONE = "de_DE.UTF-8";
    LC_TIME = "de_DE.UTF-8";
  };

  # Enable OpenGL
  hardware = {
    graphics = {
      enable = true;
    };
    nvidia = {
      modesetting.enable = true;
      open = true;
      nvidiaSettings = true;
      powerManagement.enable = false;
      prime = {
        sync.enable = true; #offload gpu heavy tasks to nvidia, the dedicated gpu is never really sleeping
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";
      };
    };
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
  };

  services = {
    displayManager = {
      defaultSession = "hyprland-uwsm";
      sddm.enable = true;
    };

    # Configure graphics
    xserver = {
      enable = true;
      videoDrivers = ["displaylink" "modesetting" "nvidia"];
      xkb = {
        layout = "de";
        variant = "";
      };
    };
    printing.enable = true;
    envfs.enable = true; # enable bash for scripts that assume hard coded shebang
    gvfs.enable = true;
    udisks2.enable = true;
    blueman.enable = true;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    openssh = {
      enable = true;
      settings.PasswordAuthentication = false;
    };
  };

  # Configure console keymap
  console.keyMap = "de";
  virtualisation.docker.enable = true;
  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  # Enable CUPS to print documents.
  boot.initrd.kernelModules = ["nvidia" "evdi"];
  boot.extraModulePackages = [config.boot.kernelPackages.nvidia_x11 config.boot.kernelPackages.evdi];

  # Enable sound with pipewire.

  security.rtkit.enable = true;
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    mutableUsers = true;
    users.work = {
      isNormalUser = true;
      description = "Linus";
      extraGroups = ["networkmanager" "wheel" "netdev"];
      packages = with pkgs; [
        slack
        kubectl
        kubelogin
        lens
        zoom-us
        graphviz
        databricks-cli
        awscli
        (pkgs.callPackage /home/work/mercedes/idp/idpcli.nix {})
      ];
    };

    users.private = {
      uid = 1030;
      isNormalUser = true;
      home = "/home/private";
      description = "Private Linus";
      extraGroups = ["wheel" "networkmanager" "netdev"];
      packages = with pkgs; [
        zathura
        dbeaver-bin
        # inkscape
        # visualvm
      ];
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 15d";
  };
  system = {
    copySystemConfiguration = true; # copies that generations config to /run/current-system/configuration.nix
    autoUpgrade = {
      enable = true;
      dates = "06:00";
    };
  };

  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
    displaylink
    firefox
    thunderbird
    keepassxc
    ffmpeg
    gimp
    openconnect
    kdePackages.dolphin

    # hyprland
    wofi
    kitty
    waybar
    networkmanagerapplet
    dunst
    hyprpaper
    playerctl
    pavucontrol

    # Development
    pyenv
    gcc
    git
    jetbrains.idea-ultimate
    jetbrains.rust-rover
    unzip
    gzip
    wget
    docker-compose

    # Misc
    alejandra # formatting nix files
    libnotify
    stow
    tmux
    lazygit

    # Vim
    vscodium
    tree-sitter
    stylua
    ripgrep
    luarocks
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
  ];

  programs = {
    hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };
    fish.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
    };
    ssh.startAgent = true; #remeber private keys so that i dont have to type them in again
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
