{
  config,
  pkgs,
  inputs,
  ...
}: let
  pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    config.allowUnfree = true;
    overlays = [
      inputs.llama-cpp.overlays.default
    ];
  };
in {
  imports = [
    # Include the results of the hardware scan..
    ./hardware-configuration.nix
  ];

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      substituters = ["https://cache.nixos-cuda.org"];
      trusted-public-keys = [
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      ];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 15d";
    };
  };

  # Bootloader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = ["ntfs" "nfs"];
    initrd.kernelModules = [
      "nvidia"
      "evdi"
    ];
    extraModulePackages = [
      config.boot.kernelPackages.nvidia_x11
      config.boot.kernelPackages.evdi
    ];
    binfmt.emulatedSystems = ["aarch64-linux"];
  };

  networking.hostName = "linus-x1"; # Define your hostname.

  nixpkgs.config.allowUnfree = true;

  # Enable networking
  networking = {
    networkmanager = {
      enable = true;
      plugins = [
        pkgs.networkmanager-openconnect
        pkgs.networkmanager-openvpn
        pkgs.networkmanager-vpnc
        pkgs.networkmanager-l2tp
        pkgs.networkmanager-strongswan
      ];
    };
    wireguard.enable = true;
    firewall.enable = false; # so that the wireguard vpn works
  };
  # Set your time zone.
  time.timeZone = "Europe/Berlin";

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

  zramSwap = {
    enable = true;
    priority = 100;
    memoryPercent = 100;
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
      powerManagement.enable = true;
      prime = {
        sync.enable = true; # offload gpu heavy tasks to nvidia, the dedicated gpu is never really sleeping
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";
      };
    };
    bluetooth.enable = true;
    bluetooth.powerOnBoot = true;
  };

  services = {
    gnome.gnome-keyring.enable = true; # equivalent to gnome keyring
    displayManager = {
      defaultSession = "hyprland-uwsm";
      sddm.enable = true;
    };
    # Configure graphics
    xserver = {
      enable = true;
      videoDrivers = [
        "displaylink"
        "modesetting"
        "nvidia"
      ];
      xkb = {
        layout = "de";
        variant = "";
      };
    };
    printing = {
      enable = true;
      drivers = with pkgs; [
        cups-filters
        cups-browsed
      ];
    };
    envfs.enable = true; # enable bash for scripts that assume hard coded shebang
    gvfs.enable = true;
    udisks2.enable = true;
    blueman.enable = true;
    tailscale.enable = true;
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

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    mutableUsers = true;
    defaultUserShell = pkgs.zsh;
    users.work = {
      isNormalUser = true;
      description = "Linus";
      extraGroups = [
        "docker"
        "dialout"
        "networkmanager"
        "wheel"
        "netdev"
        "audio"
      ];
      packages = with pkgs; [
        slack
        mattermost
        onlyoffice-desktopeditors
        claude-code
        kubectl
        kubelogin
        zoom-us
        graphviz
        databricks-cli
        awscli2
        poetry
        #mongodb-compass
        #(pkgs.callPackage /home/work/software/idp/idpcli.nix {})
        #(pkgs.callPackage /home/work/software/insomnium.nix {})
        #(pkgs.callPackage /home/work/software/freelens.nix {})
      ];
    };

    users.private = {
      uid = 1030;
      isNormalUser = true;
      home = "/home/private";
      description = "Private Linus";
      extraGroups = [
        "docker"
        "dialout"
        "wheel"
        "networkmanager"
        "netdev"
        "audio"
      ];
      packages = with pkgs; [
        zathura
        dbeaver-bin
        anki-bin
        kdePackages.kdenlive
        signal-desktop
        gnucash
        # inkscape
        # visualvm
      ];
    };
  };

  fileSystems."/media/financialdata" = {
    device = "raspberrypi.bangus-firefighter.ts.net:/financedata";
    fsType = "nfs";
    options = [
      "users"
      "nfsvers=4.2" # Enforce NFSv4.2
      "noauto" # Do not mount at boot (optional)
      "x-systemd.automount" # Mount on-demand
      "x-systemd.idle-timeout=60"
    ];
  };

  fileSystems."/media/backup" = {
    device = "raspberrypi.bangus-firefighter.ts.net:/backup";
    fsType = "nfs";
    options = [
      "users"
      "nfsvers=4.2" # Enforce NFSv4.2
      "noauto" # Do not mount at boot (optional)
      "x-systemd.automount" # Mount on-demand
      "x-systemd.idle-timeout=60"
    ];
  };

  system = {
    copySystemConfiguration = true; # copies that generations config to /run/current-system/configuration.nix
  };

  environment = {
    stub-ld.enable = true;
    # List packages installed in system profile. To search, run:
    systemPackages = with pkgs; [
      sops
      displaylink
      firefox
      thunderbird
      keepassxc
      ffmpeg
      gimp
      openconnect
      kdePackages.ark
      kdePackages.dolphin
      vlc
      htop
      spotify-player

      # hyprland
      wofi
      kitty
      waybar
      networkmanagerapplet
      swaynotificationcenter
      hyprpaper
      hyprlock
      hypridle
      playerctl
      pwvucontrol
      brightnessctl
      wlogout
      copyq
      wl-clipboard
      # screenshot
      slurp
      grim

      # Development
      bubblewrap
      claude-code
      pkgs-unstable.pi-coding-agent
      nodejs
      python3
      gcc
      git
      git-credential-manager
      jetbrains.idea
      temurin-bin
      jetbrains.rust-rover
      #jetbrains.pycharm
      uv
      unzip
      gzip
      wget
      docker-compose
      curl
      xz
      openssl
      rustup
      vscode

      # Misc
      alejandra # formatting nix files
      libnotify
      stow
      tmux
      lazygit
      ydotool
      cifs-utils
      (pkgs-unstable.llama-cpp.override {useCuda = true;})

      # Vim
      # language servers
      lua-language-server
      rust-analyzer
      nil
      basedpyright
      vtsls

      # Uni
      typst
      typstyle
      tinymist
      harper # grammar and spell checking ls
      texliveFull

      # formatters
      rustfmt
      ruff
      prettierd
      stylua
      xmlformat
      shfmt

      # insta 360
      wineWow64Packages.stable
      bottles
      gnupg
    ];
  };

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
  ];

  programs = {
    direnv.enable = true;
    neovim = {
      enable = true;
      defaultEditor = true;
      #  package = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;
    };
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        curl # Provides libcurl.so.4
        xz # Provides liblzma.so.5
        # Include common dependencies to prevent future issues
        zlib
        glibc
        stdenv.cc.cc
      ];
    };

    kdeconnect.enable = true;
    hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };
    zsh.enable = true;
    appimage = {
      enable = true;
      binfmt = true;
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05"; # Did you read the comment?
}
