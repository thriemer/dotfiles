-- Using `vim.cmd` instead of `vim.wo` because it is yet more reliable
vim.cmd("setlocal spell")
vim.cmd("setlocal wrap")

-- Insert the Latex shortcode in insert mode
vim.api.nvim_buf_set_keymap(0, "i", "TTT", "{{<tex >}}$${{</tex >}}<ESC>%hi", { noremap = true, silent = true })

-- Insert a link in insert mode

vim.api.nvim_buf_set_keymap(0, "i", "LLL", "[D]()<ESC>i", { noremap = true, silent = true })
