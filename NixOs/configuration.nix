{
  config,
  pkgs,
  ...
}: let
  nixvim = import (builtins.fetchGit {
    url = "https://github.com/nix-community/nixvim";
    # If you are not running an unstable channel of nixpkgs, select the corresponding branch of nixvim.
    # ref = "nixos-25.05";
  });
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    nixvim.nixosModules.nixvim
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
      powerManagement.enable = true;
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
        zoom-us
        graphviz
        databricks-cli
        awscli
        (pkgs.callPackage /home/work/software/idp/idpcli.nix {})
        (pkgs.callPackage /home/work/software/insomnium.nix {})
        (pkgs.callPackage /home/work/software/freelens.nix {})
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
    hyprlock
    hypridle
    playerctl
    pavucontrol
    wlogout
    copyq

    # Development
    gcc
    git
    jetbrains.idea-ultimate
    jetbrains.rust-rover
    jetbrains.pycharm-professional
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

    nixvim = {
      enable = true;

      plugins = {
        oil.enable = true;

        which-key = {
          enable = false;
          registrations = {
            "<leader>fg" = "Find Git files with telescope";
            "<leader>fw" = "Find text with telescope";
            "<leader>ff" = "Find files with telescope";
          };
        };

        render-markdown = {
          enable = true;
        };

        image = {
          enable = true;
          backend = "kitty";
          hijackFilePatterns = [
            "*.png"
            "*.jpg"
            "*.jpeg"
            "*.gif"
            "*.webp"
          ];
          maxHeightWindowPercentage = 25;
          tmuxShowOnlyInActiveWindow = true;
          settings = {
            markdown = {
              enabled = true;
              downloadRemoteImages = true;
              filetypes = [
                "markdown"
                "vimwiki"
                "mdx"
              ];
            };
          };
        };

        none-ls = {
          enable = true;
          settings = {
            cmd = ["bash -c nvim"];
            debug = true;
          };
          sources = {
            code_actions = {
              statix.enable = true;
              gitsigns.enable = true;
            };
            diagnostics = {
              statix.enable = true;
              deadnix.enable = true;
              pylint.enable = true;
              checkstyle.enable = true;
            };
            formatting = {
              alejandra.enable = true;
              stylua.enable = true;
              shfmt.enable = true;
              nixpkgs_fmt.enable = true;
              google_java_format.enable = false;
              prettier = {
                enable = true;
                disableTsServerFormatter = true;
              };
              black = {
                enable = true;
                settings = ''
                  {
                    extra_args = { "--fast" },
                  }
                '';
              };
            };
            completion = {
              luasnip.enable = true;
              spell.enable = true;
            };
          };
        };
        dap = {
          enable = true;
          signs = {
            dapBreakpoint = {
              text = "●";
              texthl = "DapBreakpoint";
            };
            dapBreakpointCondition = {
              text = "●";
              texthl = "DapBreakpointCondition";
            };
            dapLogPoint = {
              text = "◆";
              texthl = "DapLogPoint";
            };
          };
          extensions = {
            dap-python = {
              enable = true;
            };
            dap-ui = {
              enable = true;
              floating.mappings = {
                close = ["<ESC>" "q"];
              };
            };
            dap-virtual-text = {
              enable = true;
            };
          };
          configurations = {
            java = [
              {
                type = "java";
                request = "launch";
                name = "Debug (Attach) - Remote";
                hostName = "127.0.0.1";
                port = 5005;
              }
            ];
          };
        };

        # Git signs in code
        gitsigns = {
          enable = true;
          settings.current_line_blame = true;
        };
        telescope = {
          enable = true;
          extensions = {
            fzf-native = {
              enable = true;
            };
          };
        };
        lsp-format.enable = true;
        lsp = {
          enable = true;
          inlayHints = true;
          servers = {
            rust_analyzer = {
              enable = true;
              installRustc = true;
              installCargo = true;
            };
            pyright.enable = true; # Python
            nil_ls.enable = true; # Nix
            dockerls.enable = true; # Docker
            bashls.enable = true; # Bash
          };
        };
      };
      keymaps = [
        # Neo-tree bindings
        {
          action = "<cmd>Neotree toggle<CR>";
          key = "<leader>e";
        }

        # Undotree
        {
          mode = "n";
          key = "<leader>ut";
          action = "<cmd>UndotreeToggle<CR>";
          options = {
            desc = "Undotree";
          };
        }

        # Lazygit
        {
          mode = "n";
          key = "<leader>gg";
          action = "<cmd>LazyGit<CR>";
          options = {
            desc = "LazyGit (root dir)";
          };
        }

        # Commentary bindings
        {
          action = "<cmd>Commentary<CR>";
          key = "<leader>/";
        }

        # Telescope bindings

        {
          action = "<cmd>Telescope live_grep<CR>";
          key = "<leader>fw";
        }
        {
          action = "<cmd>Telescope find_files<CR>";
          key = "<leader>ff";
        }
        {
          action = "<cmd>Telescope git_commits<CR>";
          key = "<leader>fg";
        }
        {
          action = "<cmd>Telescope oldfiles<CR>";
          key = "<leader>fh";
        }
        {
          action = "<cmd>Telescope colorscheme<CR>";
          key = "<leader>ch";
        }
        {
          action = "<cmd>Telescope man_pages<CR>";
          key = "<leader>fm";
        }

        # Notify bindings

        {
          mode = "n";
          key = "<leader>un";
          action = ''
            <cmd>lua require("notify").dismiss({ silent = true, pending = true })<cr>
          '';
          options = {
            desc = "Dismiss All Notifications";
          };
        }

        # Bufferline bindings

        {
          mode = "n";
          key = "<Tab>";
          action = "<cmd>BufferLineCycleNext<cr>";
          options = {
            desc = "Cycle to next buffer";
          };
        }

        {
          mode = "n";
          key = "<S-Tab>";
          action = "<cmd>BufferLineCyclePrev<cr>";
          options = {
            desc = "Cycle to previous buffer";
          };
        }

        {
          mode = "n";
          key = "<S-l>";
          action = "<cmd>BufferLineCycleNext<cr>";
          options = {
            desc = "Cycle to next buffer";
          };
        }

        {
          mode = "n";
          key = "<S-h>";
          action = "<cmd>BufferLineCyclePrev<cr>";
          options = {
            desc = "Cycle to previous buffer";
          };
        }

        {
          mode = "n";
          key = "<leader>bd";
          action = "<cmd>bdelete<cr>";
          options = {
            desc = "Delete buffer";
          };
        }
      ];
      clipboard.providers.wl-copy.enable = true;
      colorschemes.catppuccin.enable = true;
      plugins.lualine.enable = true;
      defaultEditor = true;
    };
    ssh.startAgent = true; #remeber private keys so that i dont have to type them in again
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
