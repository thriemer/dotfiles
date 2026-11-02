{
  config,
  pkgs,
  inputs,
  ...
}: let
  pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };
in {
  imports = [
    # Include the results of the hardware scan
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
    syncthing = {
      enable = true;
      user = "private";
      group = "users";
      configDir = "/home/private/.config/syncthing";
      databaseDir = "/home/private/.local/state/syncthing";
      openDefaultPorts = true;
      overrideDevices = false; # devices are paired via the web ui
      overrideFolders = false;
      settings.devices."raspberrypi" = {
        id = "A4QATJD-XX4FM6V-A4UAVZ6-KKBXIWQ-34IR5XI-ACHJDOA-6GDU5RF-OFGRAAH";
        addresses = ["tcp://raspberrypi.bangus-firefighter.ts.net:22000"];
      };
      # one folder per device, so devices only push to the pi and never sync with each other
      settings.folders."activitywatch-${config.networking.hostName}" = {
        id = "activitywatch-${config.networking.hostName}";
        path = "/home/private/.local/share/activitywatch/sync/${config.networking.hostName}";
        type = "sendonly";
        devices = ["raspberrypi"];
      };
    };
  };

  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # don't create ~/Sync

  # ActivityWatch for user private
  systemd.user = let
    awSyncDir = "/home/private/.local/share/activitywatch/sync";
    # aw-sync daemon only syncs window and afk buckets, this syncs all of them
    awSync = pkgs.writeShellApplication {
      name = "aw-sync-all";
      runtimeInputs = with pkgs; [aw-server-rust curl jq coreutils];
      text = ''
        shopt -s nullglob
        root="$AW_SYNC_DIR"
        api="http://127.0.0.1:5600/api/0"
        host=$(curl -fsS "$api/info" | jq -r .hostname)

        # pull from other hosts, layout is <root>/<host>/<device-id>/*.db
        for dir in "$root"/*/; do
          h=$(basename "$dir")
          [ "$h" = "$host" ] && continue
          aw-sync --sync-dir "''${dir%/}" sync-advanced --mode pull || echo "pull from $h failed" >&2
        done

        # push all own buckets, skip the ones imported from other hosts
        buckets=$(curl -fsS "$api/buckets/" | jq -r 'keys | map(select(contains("-synced-from-") | not)) | join(",")')
        aw-sync --sync-dir "$root/$host" sync-advanced --mode push --buckets "$buckets"
      '';
    };
    awService = description: execStart: extra:
      {
        inherit description;
        unitConfig.ConditionUser = "private";
        wantedBy = ["graphical-session.target"];
        partOf = ["graphical-session.target"];
        after = ["graphical-session.target"];
        serviceConfig = {
          ExecStart = execStart;
          Restart = "on-failure";
          RestartSec = 5;
        };
      }
      // extra;
    afterServer = {
      after = ["graphical-session.target" "activitywatch-server.service"];
      requires = ["activitywatch-server.service"];
    };
  in {
    services = {
      activitywatch-server =
        awService "ActivityWatch server" "${pkgs.aw-server-rust}/bin/aw-server" {};
      # awatcher tracks windows and afk on hyprland
      activitywatch-awatcher =
        awService "ActivityWatch window and afk watcher" "${pkgs.awatcher}/bin/awatcher" afterServer;
      activitywatch-sync = {
        description = "ActivityWatch sync";
        unitConfig.ConditionUser = "private";
        inherit (afterServer) after requires;
        environment.AW_SYNC_DIR = awSyncDir;
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${awSync}/bin/aw-sync-all";
        };
      };
    };
    timers.activitywatch-sync = {
      description = "Periodic ActivityWatch sync";
      unitConfig.ConditionUser = "private";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "5min";
      };
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
        aw-server-rust # activitywatch server + aw-sync
        awatcher # wayland window and afk watcher for activitywatch
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
      pkgs-unstable.claude-code
      pkgs-unstable.pi-coding-agent
      nodejs
      python3
      gcc
      git
      git-credential-manager
      # jetbrains.idea
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
    firefox = {
      enable = true;
      policies.ExtensionSettings."{ef87d84c-2127-493f-b952-5b4e744245bc}" = {
        # aw-watcher-web for activitywatch
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/aw-watcher-web/latest.xpi";
      };
    };
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
