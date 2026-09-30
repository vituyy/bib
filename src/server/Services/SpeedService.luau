-- Treadmills: each player's treadmill sits just in front of their base. Running on it earns Speed XP;
-- every Speed Level makes the player permanently faster. Buying a better treadmill replaces the old one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local SpeedService = {}

local BELT_W, BELT_L = 8, 16

local function part(props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Inlet
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

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

	local model = Instance.new("Model")
	model.Name = "Treadmill"
	local cf = spot.CFrame -- LookVector points the way you run
	part({ Name = "Frame", Size = Vector3.new(BELT_W + 2, 1, BELT_L + 2), CFrame = cf * CFrame.new(0, 0, 0), Color = info.Color, Parent = model })
	local belt = part({
		Name = "Belt",
		Size = Vector3.new(BELT_W, 0.4, BELT_L),
		CFrame = cf * CFrame.new(0, 0.7, 0),
		Color = Color3.fromRGB(30, 30, 35),
		TopSurface = Enum.SurfaceType.Smooth,
		Material = Enum.Material.DiamondPlate,
		Parent = model,
	})
	-- Anchored parts with a velocity act as a conveyor: stop running and you slide off the back.
	belt.AssemblyLinearVelocity = -cf.LookVector * Config.TreadmillBeltSpeed
	-- Console at the front, rails on the sides
	part({ Name = "Console", Size = Vector3.new(BELT_W + 2, 6, 1), CFrame = cf * CFrame.new(0, 3.5, -(BELT_L / 2 + 0.5)), Color = info.Color, Parent = model })
	for _, x in { -(BELT_W / 2 + 0.5), BELT_W / 2 + 0.5 } do
		part({ Name = "Rail", Size = Vector3.new(1, 4, BELT_L), CFrame = cf * CFrame.new(x, 2.5, 0), Color = info.Color, Parent = model })
	end

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0
	label.TextColor3 = Color3.fromRGB(120, 220, 255)
	label.Text = string.format("%s\n+%d Speed XP/s (jump to get off)", info.Name, info.XpPerSecond)
	label.Parent = gui
	gui.Parent = belt

	-- Optional art: put a treadmill model from the Toolbox at ReplicatedStorage.Assets.Treadmill (front facing -Z)
	-- and it is shown here instead of the block treadmill. The invisible belt, console and rails still do the work.
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("Treadmill")
	if template and template:IsA("Model") then
		local art = template:Clone()
		art.Name = "Art"
		for _, d in art:GetDescendants() do
			if d:IsA("BaseScript") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		local _, size = art:GetBoundingBox()
		art:ScaleTo(art:GetScale() * (BELT_L + 2) / math.max(size.Z, 0.1))
		local boxCf, scaledSize = art:GetBoundingBox()
		local boxOffset = art:GetPivot():ToObjectSpace(boxCf)
		art:PivotTo(cf * CFrame.new(0, scaledSize.Y / 2 - 0.5, 0) * boxOffset:Inverse())
		art.Parent = model
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p.Transparency = 1
			end
		end
	end

	model.PrimaryPart = belt
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
			Remotes.Notify:FireClient(player, string.format("Speed Level %d! Your speed is now %d.", data.SpeedLevel, Config.WalkSpeedFor(data.SpeedLevel)), Color3.fromRGB(120, 220, 255))
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
	Players.PlayerRemoving:Connect(function(player)
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
				if data and belt and root and not player:GetAttribute("CarryingEgg") and isOnBelt(belt, root) then
					local info = Config.Treadmills[data.Treadmill] or Config.Treadmills[1]
					giveXp(player, info.XpPerSecond * Config.TreadmillTick * Config.XpMultiplier(data.Rebirths) * Config.TrailMultiplier(data.Trail))
				end
			end
		end
	end)
end

return SpeedService
