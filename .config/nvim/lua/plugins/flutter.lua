return {
	"nvim-flutter/flutter-tools.nvim",
	lazy = false,
	dependencies = {
		"rcarriga/nvim-dap-ui",
		"nvim-lua/plenary.nvim",
		"stevearc/dressing.nvim", -- optional for vim.ui.select
	},
	config = function()
		require("dapui").setup()

		local dap, dapui = require("dap"), require("dapui")

		dap.listeners.after.event_initialized["dapui_config"] = function()
			dapui.open()
		end
		dap.listeners.before.event_terminated["dapui_config"] = function()
			dapui.close()
		end
		dap.listeners.before.event_exited["dapui_config"] = function()
			dapui.close()
		end

		vim.keymap.set("n", "<Leader>dt", ":DapToggleBreakpoint<CR>", { desc = "Toggle Breakpoint" })
		vim.keymap.set("n", "<Leader>dx", ":DapTerminate<CR>", { desc = "Close debugging view" })
		vim.keymap.set("n", "<Leader>do", ":DapStepOver<CR>", { desc = "Step over" })
	end,
}
