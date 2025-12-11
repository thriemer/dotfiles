vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Set to true if you have a Nerd Font installed
vim.g.have_nerd_font = true

-- [[ Setting options ]]
-- See `:help vim.opt`
-- NOTE: You can change these options as you wish!
--  For more options, you can see `:help option-list`

-- Make line numbers default
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.winborder = "rounded"

-- Enable mouse mode, can be useful for resizing splits for example!
vim.opt.mouse = "a"

-- Don't show the mode, since it's already in status line
vim.opt.showmode = false

--  See `:help 'clipboard'`
vim.opt.clipboard = "unnamedplus"

-- Enable break indent
vim.opt.breakindent = true

-- Save undo history
vim.opt.undofile = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep signcolumn on by default
vim.opt.signcolumn = "yes"

-- Decrease update time
vim.opt.updatetime = 250

-- Decrease mapped sequence wait time
-- Displays which-key popup sooner
vim.opt.timeoutlen = 300

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

-- Sets how neovim will display certain whitespace in the editor.
--  See `:help 'list'`
--  and `:help 'listchars'`
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Preview substitutions live, as you type!
vim.opt.inccommand = "split"

-- Show which line your cursor is on
vim.opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 15

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Move lines up/down
vim.keymap.set("n", "<A-j>", ":m .+1<CR>==", { desc = "Move line down" })
vim.keymap.set("n", "<A-k>", ":m .-2<CR>==", { desc = "Move line up" })
vim.keymap.set("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
vim.keymap.set("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Open the hover when jumping to diagnostics
vim.diagnostic.config({ jump = { float = true } })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- TIP: Disable arrow keys in normal mode
-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
vim.keymap.set("n", "<left>", '<cmd>echo "Use h to move!!"<CR>')
vim.keymap.set("n", "<right>", '<cmd>echo "Use l to move!!"<CR>')
vim.keymap.set("n", "<up>", '<cmd>echo "Use k to move!!"<CR>')
vim.keymap.set("n", "<down>", '<cmd>echo "Use j to move!!"<CR>')

--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus to the left window" })
vim.keymap.set("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus to the right window" })
vim.keymap.set("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus to the lower window" })
vim.keymap.set("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus to the upper window" })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.hl.on_yank()
	end,
})

vim.pack.add({
	-- Eye Candy
	{ src = "https://github.com/sphamba/smear-cursor.nvim" }, -- Nice animations
	{ src = "https://github.com/catppuccin/nvim" }, -- color theme
	{ src = "https://github.com/nvim-tree/nvim-web-devicons" }, -- nice icons
	{ src = "https://github.com/nvim-lualine/lualine.nvim" }, -- nicer status line
	{ src = "https://github.com/folke/which-key.nvim" }, -- Key help
	-- misc until now
	{ src = "https://github.com/stevearc/oil.nvim" }, -- File explorer
	{ src = "https://github.com/neovim/nvim-lspconfig" }, -- LSP
	{ src = "https://github.com/echasnovski/mini.nvim" },
	{ src = "https://github.com/stevearc/conform.nvim" }, -- formatting
	{ src = "https://github.com/chomosuke/typst-preview.nvim" }, -- typst file editing
	{ src = "https://github.com/Saecki/crates.nvim" }, -- rust cargo toml support
	{ src = "https://github.com/folke/flash.nvim" },
	-- completion
	{ src = "https://github.com/hrsh7th/nvim-cmp" }, -- The completion engine
	{ src = "https://github.com/hrsh7th/cmp-nvim-lsp" }, -- LSP as a completion source
	{ src = "https://github.com/hrsh7th/cmp-buffer" }, -- Suggests words from open buffers
	{ src = "https://github.com/hrsh7th/cmp-path" }, -- Suggests file system paths
	{ src = "https://github.com/L3MON4D3/LuaSnip" }, -- Snippet engine (optional but recommended)
	{ src = "https://github.com/saadparwaiz1/cmp_luasnip" }, -- Snippets as a completion source
})

vim.lsp.enable({
	"rust_analyzer",
	"lua_ls",
	"nil_ls",
	"tinymist",
	"basedpyright",
})

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		local capabilities = require("cmp_nvim_lsp").default_capabilities()
		client.server_capabilities = vim.tbl_deep_extend("force", client.server_capabilities, capabilities)
	end,
})

vim.cmd("set completeopt+=noselect")

require("oil").setup()
require("crates").setup()
require("smear_cursor").setup()
require("mini.pick").setup()
require("which-key").setup()
require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },
		javascript = { "prettierd" },
		css = { "prettierd" },
		markdown = { "prettierd" },
		nix = { "alejandra" },
		xml = { "xmlformat" },
		html = { "prettierd" },
		json = { "prettierd" },
		yaml = { "prettierd" },
		rust = { "rustfmt", lsp_format = "fallback" },
		sh = { "shfmt" },
		python = { "ruff" },
		typst = { "typstfmt" },
	},
	-- Customize formatters
	formatters = {
		shfmt = {
			prepend_args = { "-i", "2" },
		},
	},
})
require("lualine").setup()

local cmp = require("cmp")
local luasnip = require("luasnip")

cmp.setup({
	snippet = {
		expand = function(args)
			luasnip.lsp_expand(args.body)
		end,
	},
	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
	},
	mapping = cmp.mapping.preset.insert({
		["<C-n>"] = cmp.mapping.select_next_item(),
		["<C-p>"] = cmp.mapping.select_prev_item(),
		["<C-b>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.abort(),
		["<CR>"] = cmp.mapping.confirm({ select = false }), -- Set to `true` to auto-select first item
	}),
	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "luasnip" },
	}, {
		{ name = "buffer" },
		{ name = "path" },
	}),
})

vim.keymap.set("n", "<leader>f", function()
	require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format the buffer" })
vim.keymap.set("n", "<leader>e", ":Oil<CR>", { desc = "Open File [E]xplorer" })

vim.keymap.set("n", "<leader>sf", ":Pick files<CR>", { desc = "[S]earch [f]iles" })
vim.keymap.set("n", "<leader>sg", ":Pick grep_live<CR>", { desc = "[S]earch [G]rep" })
vim.keymap.set("n", "<leader><leader>", ":Pick buffers<CR>", { desc = "[S]earch [b]uffer" })
vim.keymap.set("n", "<leader>d", ":bd<CR>", { desc = "[D]elete Buffer" })

require("flash").setup({
	-- ENABLING WHOLE-DOCUMENT SEARCH (across windows)
	search = {
		multi_window = true, -- This allows searching across ALL windows, not just forward/backward in one.
		wrap = true, -- Wraps around the end/beginning of the document
	},
	-- (Optional) ENABLING JUMP LABELS FOR F/T MOTIONS
	-- This adds flash labels to standard f, F, t, T character motions.
	modes = { char = { jump_labels = true } },
})

-- Set up keybindings for flash.nvim
vim.keymap.set({ "n", "x", "o" }, "s", function()
	require("flash").jump()
end, { desc = "Flash jump (search across windows)" })

vim.keymap.set({ "n", "x", "o" }, "S", function()
	require("flash").treesitter()
end, { desc = "Flash Treesitter" })

-- REMOTE ACTION (highly useful for operating on text elsewhere)
-- This lets you yank/delete/change text in a different part of the file and return.
vim.keymap.set("o", "r", function()
	require("flash").remote()
end, { desc = "Remote Flash (operate at a distance)" })

vim.cmd("colorscheme catppuccin")
