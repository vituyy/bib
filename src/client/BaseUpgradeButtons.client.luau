-- World-space click/tap buttons must live in PlayerGui with their board as Adornee.
local Players = game:GetService("Players")
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local plots = workspace:WaitForChild("Map"):WaitForChild("Plots")
local mounted = {}
local busy = false

local function unmount(board)
	local record = mounted[board]
	if not record then return end
	mounted[board] = nil
	record.connection:Disconnect()
	record.gui:Destroy()
	if record.source.Parent then record.source.Enabled = true end
end

local function mount(source)
	if not source:IsA("SurfaceGui") or source.Name ~= "UpgradeSurface" then return end
	local board = source.Parent
	if not (board and board:IsA("BasePart")) or mounted[board] then return end
	local kind = board:GetAttribute("UpgradeKind")
	if kind ~= "Pets" and kind ~= "Pads" then return end
	local plot = board
	while plot and plot.Parent ~= plots do plot = plot.Parent end
	if not plot or plot.Name ~= player:GetAttribute("Plot") then return end
	local gui = source:Clone()
	gui.Name = "BaseUpgrade_" .. kind
	gui.Adornee = board
	gui.Enabled = true
	gui.Active = true
	gui.ResetOnSpawn = false
	gui.Parent = playerGui
	source.Enabled = false
	local button = gui:FindFirstChild("BuyButton")
	local connection = button.Activated:Connect(function()
		if busy or not board.Parent or not board:GetAttribute("CanUpgrade") then return end
		busy = true
		local oldText = button.Text
		button.Text = "..."
		button.Active = false
		local sent, ok = pcall(function()
			return Remotes.UpgradeBase:InvokeServer(kind)
		end)
		busy = false
		if button.Parent then
			button.Text = if sent then oldText else "TRY AGAIN"
			button.Active = board:GetAttribute("CanUpgrade") == true
		end
		if not sent then warn("[BaseUpgradeButtons] Upgrade request failed:", ok) end
	end)
	mounted[board] = {gui=gui,source=source,connection=connection}
end

local function rescan()
	local stale = {}
	for board in mounted do table.insert(stale, board) end
	for _,board in stale do unmount(board) end
	for _,d in plots:GetDescendants() do mount(d) end
end
plots.DescendantAdded:Connect(function(d)
	if d:IsA("SurfaceGui") and d.Name == "UpgradeSurface" then
		task.defer(mount, d)
	end
end)
plots.DescendantRemoving:Connect(function(d)
	if mounted[d] then unmount(d) end
end)
player:GetAttributeChangedSignal("Plot"):Connect(rescan)
rescan()
