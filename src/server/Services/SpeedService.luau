-- Treadmills: each player's treadmill sits just in front of their base. Running on it earns Speed XP;
-- every Speed Level makes the player permanently faster. Buying a better treadmill replaces the old one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local SpeedService = {}

-- One model per tier lives in ReplicatedStorage.Assets.Treadmills (named "1".."7", edit them in Studio).
-- Each has a Belt part and a Slats folder (the client scrolls the slats). Model pivot = TreadmillSpot,
-- running toward -Z. The old block treadmills are backed up in ServerStorage.TreadmillBackup_Old.

-- The client says when it is held on the belt and running (Remotes.TreadmillRunning). XP only flows while
-- running, and the treadmill's "Running" attribute tells every client to scroll that belt.
local running: { [Player]: boolean } = {}
local function spawnTreadmill(player: Player, tier: number)
	local plot = PlotService.GetPlot(player)
	local spot = plot and plot:FindFirstChild("TreadmillSpot") :: BasePart?
	if not (plot and spot) then
		return
	end
	local old = plot:FindFirstChild("Treadmill")
	if old then
		old:Destroy()
	end
	local info = Config.Treadmills[tier] or Config.Treadmills[1]

	local templates = ReplicatedStorage.Assets:FindFirstChild("Treadmills")
	local template = templates and (templates:FindFirstChild(tostring(tier)) or templates:FindFirstChild("1"))
	if not template then
		warn("No treadmill models in ReplicatedStorage.Assets.Treadmills")
		return
	end
	local model = template:Clone() :: Model
	model.Name = "Treadmill"
	model:PivotTo(spot.CFrame) -- LookVector points the way you run
	local belt = model:FindFirstChild("Belt") :: BasePart

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, model:GetAttribute("LabelHeight") or 9, 0)
	gui.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.TextColor3 = Color3.fromRGB(120, 220, 255)
	label.Text = string.format("%s\n+%d Speed XP/s (move or jump to step off)", info.Name, info.XpPerSecond)
	label.Parent = gui
	gui.Parent = belt

	model:SetAttribute("Running", running[player] == true)
	model.Parent = plot
end

local function isOnBelt(belt: BasePart, root: BasePart): boolean
	local offset = belt.CFrame:PointToObjectSpace(root.Position)
	return math.abs(offset.X) <= belt.Size.X / 2 and math.abs(offset.Z) <= belt.Size.Z / 2 + 0.5 and offset.Y > 0 and offset.Y < 6
end

local function giveXp(player: Player, amount: number)
	local levelsGained = 0
	DataService.Update(player, function(d)
		if d.SpeedLevel >= Config.MaxSpeedLevel then
			d.SpeedXp = 0
			return
		end
		d.SpeedXp += amount
		while d.SpeedLevel < Config.MaxSpeedLevel and d.SpeedXp >= Config.XpToNext(d.SpeedLevel) do
			d.SpeedXp -= Config.XpToNext(d.SpeedLevel)
			d.SpeedLevel += 1
			levelsGained += 1
		end
	end)
	if levelsGained > 0 then
		local data = DataService.Get(player)
		if data then
			Remotes.Notify:FireClient(player, string.format("Speed Level %d! Your max speed is now %s.", data.SpeedLevel, Config.FormatSpeed(Config.WalkSpeedFor(data.SpeedLevel))), Color3.fromRGB(120, 220, 255))
		end
	end
end

-- The equipped trail shows as a glowing streak behind the character.
local function applyTrail(player: Player, trailIndex: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	for _, name in { "SpeedTrail", "TrailTop", "TrailBottom" } do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local info = Config.Trails[trailIndex]
	if not info then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 1.2, 0.3)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -1.8, 0.3)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "SpeedTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(info.Color, info.Color:Lerp(Color3.new(0, 0, 0), 0.6))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.35 + trailIndex * 0.08
	trail.LightEmission = 0.8
	trail.FaceCamera = true
	trail.Parent = root
end

function SpeedService.Start()
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart")
			local d = DataService.WaitFor(player)
			if d then
				applyTrail(player, d.Trail)
			end
		end)
		local data = DataService.WaitFor(player)
		if data then
			spawnTreadmill(player, data.Treadmill)
			applyTrail(player, data.Trail)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	local lastTier: { [Player]: number } = {}
	local lastTrail: { [Player]: number } = {}
	DataService.OnChanged(function(player, data)
		if lastTrail[player] ~= data.Trail then
			lastTrail[player] = data.Trail
			applyTrail(player, data.Trail)
		end
		if lastTier[player] ~= data.Treadmill then
			lastTier[player] = data.Treadmill
			spawnTreadmill(player, data.Treadmill)
		end
	end)
	Remotes.TreadmillRunning.OnServerEvent:Connect(function(player, isRunning)
		running[player] = isRunning == true
		local plot = PlotService.GetPlot(player)
		local treadmill = plot and plot:FindFirstChild("Treadmill")
		if treadmill then
			treadmill:SetAttribute("Running", running[player])
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		running[player] = nil
		lastTier[player] = nil
		lastTrail[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(Config.TreadmillTick)
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				local plot = PlotService.GetPlot(player)
				local treadmill = plot and plot:FindFirstChild("Treadmill")
				local belt = treadmill and treadmill:FindFirstChild("Belt") :: BasePart?
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if data and belt and root and running[player] and not player:GetAttribute("CarryingEgg") and isOnBelt(belt, root) then
					local info = Config.Treadmills[data.Treadmill] or Config.Treadmills[1]
					giveXp(player, info.XpPerSecond * Config.TreadmillTick * Config.XpMultiplier(data.Rebirths) * Config.TrailMultiplier(data.Trail))
				end
			end
		end
	end)
end

return SpeedService
