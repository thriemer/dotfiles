return {
	"simrat39/rust-tools.nvim",
	ft = "rust",

	config = function() -- This is the function that runs, AFTER loading
		local builtin = require("rust-tools")
		local mason_registry = require("mason-registry")
		local codelldb = mason_registry.get_package("codelldb")
		local extension_path = codelldb:get_install_path() .. "/extension/"
		local codelldb_path = extension_path .. "adapter/codelldb"
		local liblldb_path = extension_path .. "lldb/lib/liblldb.dylib"
		builtin.setup({
			dap = {
				adapter = require("rust-tools.dap").get_codelldb_adapter(codelldb_path, liblldb_path),
			},
			server = {
				capabilities = require("cmp_nvim_lsp").default_capabilities(),
				on_attach = function(_, bufnr)
					vim.keymap.set(
						"n",
						"<Leader>k",
						builtin.hover_actions.hover_actions,
						{ buffer = bufnr, desc = "Code hover actions" }
					)
					vim.keymap.set(
						"n",
						"<Leader>a",
						builtin.node_action_group.code_action_group,
						{ buffer = bufnr, desc = "Code action group" }
					)
				end,
			},
			tools = {
				hover_actions = {
					auto_focus = true,
				},
			},
		})
	end,
}
