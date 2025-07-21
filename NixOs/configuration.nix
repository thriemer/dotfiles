{
  config,
  pkgs,
  ...
}: let
  nixvim = import (
    builtins.fetchGit {
      url = "https://github.com/nix-community/nixvim";
      # If you are not running an unstable channel of nixpkgs, select the corresponding branch of nixvim.
      # ref = "nixos-25.05";
    }
  );
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    nixvim.nixosModules.nixvim
  ];
  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 15d";
    };
  };
  nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1w"
  ];

  # Bootloader.
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    supportedFilesystems = ["ntfs"];
    initrd.kernelModules = [
      "nvidia"
      "evdi"
    ];
    extraModulePackages = [
      config.boot.kernelPackages.nvidia_x11
      config.boot.kernelPackages.evdi
    ];
  };

  networking.hostName = "linus-x1"; # Define your hostname.

  # Enable networking
  networking = {
    networkmanager = {
      enable = true;
      plugins = [
        pkgs.networkmanager-openconnect
        pkgs.networkmanager-openvpn
        pkgs.networkmanager-vpnc
        pkgs.networkmanager-l2tp
      ];
      enableStrongSwan = true;
    };
    wireguard.enable = true;
    firewall.enable = false; # so that the wireguard vpn works
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
        sync.enable = true; # offload gpu heavy tasks to nvidia, the dedicated gpu is never really sleeping
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

  security.rtkit.enable = true;
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    mutableUsers = true;
    users.work = {
      isNormalUser = true;
      description = "Linus";
      extraGroups = [
        "networkmanager"
        "wheel"
        "netdev"
      ];
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
      extraGroups = [
        "wheel"
        "networkmanager"
        "netdev"
      ];
      packages = with pkgs; [
        zathura
        dbeaver-bin
        anki-bin
        # inkscape
        # visualvm
      ];
    };
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  system = {
    copySystemConfiguration = true; # copies that generations config to /run/current-system/configuration.nix
  };

  environment = {
    stub-ld.enable = true;
    # List packages installed in system profile. To search, run:
    systemPackages = with pkgs; [
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
      temurin-bin-24
      jetbrains.rust-rover
      jetbrains.pycharm-professional
      unzip
      gzip
      wget
      docker-compose
      curl
      xz
      openssl

      # Misc
      alejandra # formatting nix files
      libnotify
      rustfmt
      stow
      tmux
      lazygit

      # Vim
      vscodium
      tree-sitter
      stylua
      ripgrep
      luarocks

      # insta 360
      wineWowPackages.stable
      bottles
    ];
  };

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.droid-sans-mono
  ];

  programs = {
    nix-ld = {
      enable = true;
      libraries = with pkgs; [
        openssl_1_1 # Provides libcrypto.so.1.1 and libssl.so.1.1
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
    fish.enable = true;

    nixvim = {
      enable = true;
      globals.mapleader = " ";
      opts = {
        # Line numbers
        number = true;
        relativenumber = true;

        # Enable more colors (24-bit)
        termguicolors = true;

        # Have a better completion experience
        completeopt = [
          "menuone"
          "noselect"
          "noinsert"
        ];

        # Always show the signcolumn, otherwise text would be shifted when displaying error icons
        signcolumn = "yes";

        # Enable mouse
        mouse = "a";

        # Search
        ignorecase = true;
        smartcase = true;

        # Configure how new splits should be opened
        splitright = true;
        splitbelow = true;

        list = true;
        listchars.__raw = "{ tab = '» ', trail = '·', nbsp = '␣' }";

        expandtab = true;
        # tabstop = 4;
        shiftwidth = 2;
        # softtabstop = 0;
        # smarttab = true;

        # Set encoding
        encoding = "utf-8";
        fileencoding = "utf-8";

        # Save undo history
        undofile = true;
        swapfile = true;
        backup = false;
        autoread = true;

        # Highlight the current line for cursor
        cursorline = true;

        # Show line and column when searching
        ruler = true;

        # Global substitution by default
        gdefault = true;

        # Start scrolling when the cursor is X lines away from the top/bottom
        scrolloff = 5;
      };
      # System clipboard support, needs xclip/wl-clipboard
      clipboard = {
        # Use system clipboard
        register = "unnamedplus";
        providers.wl-copy.enable = true;
      };

      diagnostics = {
        update_in_insert = true;
        severity_sort = true;
        float = {
          border = "rounded";
        };
        jump = {
          severity.__raw = "vim.diagnostic.severity.WARN";
        };
      };

      highlight = {
        Comment.fg = "#ff00ff";
        Comment.bg = "#000000";
        Comment.underline = true;
        Comment.bold = true;
      };

      plugins = {
        molten = {
          settings = {
            use_border_highlights = true;
            output_virt_lines = true;
            virt_lines_off_by_1 = true;
            image_provider = "image.nvim";
          };
          enable = true;
        };
        image = {
          settings = {
            backend = "kitty";
          };
          enable = true;
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
        quarto = {
          settings = {
            codeRunner = {
              default_method = "molten";
            };
          };
          enable = true;
        };
        jupytext = {
          settings = {
            style = "markdown";
            output_extension = "md";
            force_ft = "markdown";
          };
          enable = true;
          package = pkgs.vimUtils.buildVimPlugin {
            pname = "jupytext.nvim";
            version = "0.0.0";
            src = pkgs.fetchgit {
              url = "https://github.com/bkp5190/jupytext.nvim";
              branchName = "deprecated-healthcheck";
              rev = "695295069a3aac0cf9a1b768589216c5b837b6f1";
              sha256 = "sha256-W6fkL1w2dYSjpAYOtBTlYjd2CMYPB596NQzBylIVHrE=";
            };
          };
        };
        oil.enable = true;

        which-key = {
          enable = true;
        };

        render-markdown = {
          enable = true;
        };
        conform-nvim = {
          enable = true;
          settings = {
            format_on_save = {
              lspFallback = true;
              timeoutMs = 500;
            };
            notify_on_error = true;
            formatters_by_ft = {
              html = [
                [
                  "prettierd"
                  "prettier"
                ]
              ];
              css = [
                [
                  "prettierd"
                  "prettier"
                ]
              ];
              rust = [["rustfmt"]];
              javascript = [
                [
                  "prettierd"
                  "prettier"
                ]
              ];
              javascriptreact = [
                [
                  "prettierd"
                  "prettier"
                ]
              ];
              typescript = [
                [
                  "prettierd"
                  "prettier"
                ]
              ];
              typescriptreact = [
                [
                  "prettierd"
                  "prettier"
                ]
              ];
              python = ["black"];
              lua = ["stylua"];
              nix = ["nixfmt"];
              markdown = [
                [
                  "prettierd"
                  "prettier"
                ]
              ];
              yaml = [
                "yamllint"
                "yamlfmt"
              ];
              terragrunt = ["hcl"];
              bash = ["shfmt"];
              sh = ["shfmt"];
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
                close = [
                  "<ESC>"
                  "q"
                ];
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
            rust = [
              {
                name = "Rust debug";
                type = "codelldb";
                request = "launch";
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
        lspkind = {
          enable = true;

          cmp = {
            enable = true;
            menu = {
              nvim_lsp = "[LSP]";
              nvim_lua = "[api]";
              path = "[path]";
              luasnip = "[snip]";
              buffer = "[buffer]";
              neorg = "[neorg]";
              cmp_tabnine = "[TabNine]";
            };
          };
        };

        cmp = {
          enable = true;
          settings = {
            mapping = {
              "<C-d>" = "cmp.mapping.scroll_docs(-4)";
              "<C-f>" = "cmp.mapping.scroll_docs(4)";
              "<C-Space>" = "cmp.mapping.complete()";
              "<C-e>" = "cmp.mapping.close()";
              "<S-Tab>" = "cmp.mapping(cmp.mapping.select_prev_item(), {'i', 's'})";
              "<Tab>" = "cmp.mapping(cmp.mapping.select_next_item(), {'i', 's'})";
              "<CR>" = "cmp.mapping.confirm({ select = true })";
            };

            sources = [
              {name = "path";}
              {name = "nvim_lsp";}
              {name = "luasnip";}
              {
                name = "buffer";
                # Words from other open buffers can also be suggested.
                option.get_bufnrs.__raw = "vim.api.nvim_list_bufs";
              }
              {name = "neorg";}
            ];
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
            basedpyright.enable = true; # Python
            nil_ls.enable = true; # Nix
            dockerls.enable = true; # Docker
            bashls.enable = true; # Bash
          };
          keymaps = {
            silent = true;
            diagnostic = {
              # Navigate in diagnostics
              "grdp" = "goto_prev";
              "grdn" = "goto_next";
            };
          };
        };
      };
      autoCmd = [
        {
          event = "TextYankPost";
          pattern = "*";
          command = "lua vim.highlight.on_yank{timeout=250}";
        }
      ];
      keymaps = [
        {
          action = ":Oil<CR>";
          key = "<leader>e";
        }

        # Telescope bindings

        {
          action = "<cmd>Telescope live_grep<CR>";
          key = "<leader>sg";
        }
        {
          action = "<cmd>Telescope find_files<CR>";
          key = "<leader>sf";
        }

        {
          action = "<cmd>Telescope man_pages<CR>";
          key = "<leader>sm";
        }
        {
          action = "<cmd>Telescope quickfix<CR>";
          key = "<leader>sq";
          options.desc = "Search Quickfix";
        }
        {
          action = "<cmd>Telescope buffers<CR>";
          key = "<leader>sb";
          options.desc = "Search Buffer";
        }
        {
          action = "<cmd>Telescope current_buffer_fuzzy_find<CR>";
          key = "<leader>/";
          options.desc = "Search Buffer";
        }

        # Bufferline bindings

        {
          mode = "n";
          key = "<Tab>";
          action = "]b";
          options = {
            desc = "Cycle to next buffer";
          };
        }

        {
          mode = "n";
          key = "<S-Tab>";
          action = "[b";
          options = {
            desc = "Cycle to previous buffer";
          };
        }
        {
          mode = "n";
          key = "<S-h>";
          action = "<cmd>lua vim.diagnostic.open_float()<cr>";

          options = {
            desc = "Open diagonstics";
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
      colorschemes.catppuccin.enable = true;
      plugins.lualine.enable = true;
      defaultEditor = true;
    };
    ssh.startAgent = true; # remeber private keys so that i dont have to type them in again
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
