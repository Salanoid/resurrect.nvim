local M = {}

-- Default configuration
M.config = {
	ignore_filetypes = { "gitcommit", "gitrebase", "hgcommit", "svn", "xxd" }, -- Filetypes to ignore
	ignore_buftypes = { "help", "nofile", "quickfix" }, -- Buftypes to ignore
	open_folds = true, -- Automatically open folds around the cursor
	project_file = ".nvim_resurrect", -- File to store the last opened file in the project
}

--- Check if the plugin should run for the current buffer
---@return boolean
local function can_run()
	local buftype = vim.bo.buftype
	local filetype = vim.bo.filetype
	local filepath = vim.fn.expand("%")

	-- Ignore configured buftypes or filetypes
	if vim.tbl_contains(M.config.ignore_buftypes, buftype) or vim.tbl_contains(M.config.ignore_filetypes, filetype) then
		return false
	end

	-- Ignore empty or non-existent files
	if filepath == "" or vim.fn.filereadable(filepath) == 0 then
		return false
	end

	return true
end

--- Jump to the last cursor position in the buffer
local function jump_to_last_position()
	if not can_run() then
		return
	end

	local last_pos = vim.fn.line("'\"")
	local last_line = vim.fn.line("$")

	if last_pos > 0 and last_pos <= last_line then
		local window_start = vim.fn.line("w0")
		local window_end = vim.fn.line("w$")
		local visible_lines = window_end - window_start

		if window_end == last_line then
			-- If at the end of the file, jump directly
			vim.cmd('normal! g`"')
		elseif last_line - last_pos > visible_lines / 2 - 1 then
			-- Center the cursor if there's enough room
			vim.cmd('normal! g`"zz')
		else
			-- Show as much context as possible near the end of the file
			vim.cmd('keepjumps normal! G`"<C-e>')
		end
	end
end

--- Open folds containing the last cursor position
local function open_folds()
	if not can_run() then
		return
	end

	if M.config.open_folds and vim.fn.foldclosed(".") ~= -1 then
		vim.cmd("normal! zvzz") -- Open folds and center the cursor
	end
end

--- Save the current file path to the project file
local function save_last_file()
	local filepath = vim.fn.expand("%:p")
	if filepath == "" then
		return
	end

	-- Locate the project root or use the current working directory
	local project_root = vim.fn.getcwd()
	local project_file = project_root .. "/" .. M.config.project_file

	-- Write the last file path to the project file
	local file = io.open(project_file, "w")
	if file then
		file:write(filepath)
		file:close()
	end
end

--- Open the last file in the project
local function open_last_file()
	-- Locate the project root or use the current working directory
	local project_root = vim.fn.getcwd()
	local project_file = project_root .. "/" .. M.config.project_file

	-- Read the last file path from the project file
	local file = io.open(project_file, "r")
	if file then
		local filepath = file:read("*line")
		file:close()
		if filepath and vim.fn.filereadable(filepath) == 1 then
			vim.cmd("edit " .. filepath)
		end
	end
end

--- Setup the plugin with optional user configuration
---@param opts table: User-defined configuration
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Create an augroup for managing autocommands
	vim.api.nvim_create_augroup("Resurrect", { clear = true })

	-- Restore cursor position and folds
	vim.api.nvim_create_autocmd({ "BufRead", "BufWinEnter" }, {
		group = "Resurrect",
		callback = function()
			jump_to_last_position()
			open_folds()
		end,
	})

	-- Save the last opened file on exit
	vim.api.nvim_create_autocmd("BufLeave", {
		group = "Resurrect",
		callback = save_last_file,
	})

	-- Open the last file in the project on startup
	vim.api.nvim_create_autocmd("VimEnter", {
		group = "Resurrect",
		callback = open_last_file,
	})
end

return M
