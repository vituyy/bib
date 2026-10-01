-- Gives each player a base plot, shows their pets and incubating eggs on it, hatches eggs when their timer
-- runs out, and pays out pet income.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Art = require(ReplicatedStorage.Shared.Art)
local DataService = require(script.Parent.DataService)
local BaseBuilder = require(script.Parent.BaseBuilder)

local PlotService = {}

local plotsFolder: Instance
local plotOwners: { [Instance]: Player } = {}
local playerPlots: { [Player]: Instance } = {}

local function setSign(plot: Instance, text: string)
	local base = plot:FindFirstChild("Base")
	local sign = base and base:FindFirstChild("OwnerSign")
	local label = sign and sign:FindFirstChildWhichIsA("TextLabel")
	if label then
		label.Text = text
	end
end

-- 1500 -> "1.5K", 2000000 -> "2M" (for the labels above pets)
local function shortNumber(n: number): string
	for _, unit in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= unit[1] then
			return (string.format("%.1f", n / unit[1]):gsub("%.0$", "")) .. unit[2]
		end
	end
	return tostring(math.floor(n))
end

local function petIncome(data): number
	local total = 0
	for _, petId in data.Pets do
		local pet = Config.Pets[petId]
		if pet then
			total += pet.MoneyPerSecond
		end
	end
	return total
end
PlotService.PetIncome = petIncome

-- Friend boost: +Config.FriendBoostPercent% pet Money for every friend in the same server.
-- Stored as the player's "FriendBoost" attribute (a percentage) so the HUD can show it.
local friendCache: { [string]: boolean } = {}
local function areFriends(a: Player, b: Player): boolean
	local key = math.min(a.UserId, b.UserId) .. "|" .. math.max(a.UserId, b.UserId)
	if friendCache[key] == nil then
		local ok, result = pcall(a.IsFriendsWith, a, b.UserId)
		if not ok then
			return false -- web call failed; try again next time someone joins or leaves
		end
		friendCache[key] = result
	end
	return friendCache[key]
end

local function refreshFriendBoosts(leaving: Player?)
	local players = Players:GetPlayers()
	for _, player in players do
		if player ~= leaving then
			local friends = 0
			for _, other in players do
				if other ~= player and other ~= leaving and areFriends(player, other) then
					friends += 1
				end
			end
			player:SetAttribute("FriendBoost", friends * Config.FriendBoostPercent)
		end
	end
end

function PlotService.RollPet(eggId: string): string
	local egg = Config.Eggs[eggId]
	local total = 0
	for _, entry in egg.Pool do
		total += entry.Weight
	end
	local roll = math.random() * total
	for _, entry in egg.Pool do
		roll -= entry.Weight
		if roll <= 0 then
			return entry.Pet
		end
	end
	return egg.Pool[#egg.Pool].Pet
end

local function studs(p: BasePart)
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Inlet
end

local function label(parent: Instance, text: string, color: Color3, offsetY: number, name: string?): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 36)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 40
	local l = Instance.new("TextLabel")
	l.Name = name or "Label"
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextStrokeTransparency = 0
	l.TextColor3 = color
	l.Text = text
	l.Parent = gui
	gui.Parent = parent
	return l
end

-- Wandering pets: each pet walks to random spots inside its owner's base, idles a moment, then moves on.
type Wanderer = { Model: Model, Pos: Vector3, Target: Vector3, Idle: number, Height: number, Phase: number }
local wanderers: { [Player]: { Wanderer } } = {}
local PET_SPEED = 4 -- studs per second
local BASE_MARGIN = 4

local function randomSpot(base: BasePart): Vector3
	base = (base.Parent and base.Parent:FindFirstChild("PetArea") :: BasePart?) or base
	local half = base.Size / 2 - Vector3.new(BASE_MARGIN, 0, BASE_MARGIN)
	local offset = Vector3.new((math.random() * 2 - 1) * half.X, 0, (math.random() * 2 - 1) * half.Z)
	return (base.CFrame * CFrame.new(offset)).Position + Vector3.new(0, base.Size.Y / 2, 0)
end

local function renderPets(player: Player, data)
	local plot = playerPlots[player]
	local base = plot and plot:FindFirstChild("Base") :: BasePart?
	if not (plot and base) then
		return
	end

	local visuals = plot:FindFirstChild("PetVisuals")
	if visuals then
		visuals:Destroy()
	end
	visuals = Instance.new("Folder")
	visuals.Name = "PetVisuals"
	visuals.Parent = plot
	local list = {}
	wanderers[player] = list

	for _, petId in data.Pets do
		local pet = Config.Pets[petId]
		if pet then
			local rarity = Config.Rarities[pet.Rarity]
			local size = 2.2 * (1 + rarity.Order * 0.12) * (pet.Scale or 1) -- Big, Huge and Gigantic pets are bigger
			local model = Art.Clone("Pets", petId, size * 1.6)
			local height = size
			if model then
				height = model:GetAttribute("ArtHeight") or size
			else
				-- No art for this pet yet: a studded block in the pet's colour.
				model = Instance.new("Model")
				local body = Instance.new("Part")
				body.Name = "Body"
				body.Size = Vector3.new(size, size, size)
				body.Color = pet.Color
				studs(body)
				if rarity.Order >= 6 then
					body.Material = Enum.Material.Neon
				end
				body.Anchored = true
				body.CanCollide = false
				body.Parent = model
				model.PrimaryPart = body
			end
			model.Name = petId
			Art.MaterialLook(model, model.PrimaryPart :: BasePart, pet.Material)
			local start = randomSpot(base)
			model:PivotTo(CFrame.new(start + Vector3.new(0, height / 2, 0)))
			model.Parent = visuals
			label(model.PrimaryPart :: BasePart, string.format("%s\n$%s/s", pet.Name, shortNumber(pet.MoneyPerSecond)), rarity.Color, height / 2 + 1.5)
			-- Winged models (WingL/WingR, each with a Hinge part) flap and hover.
			local wings = {}
			local root = model.PrimaryPart :: BasePart
			for _, side in { "WingL", "WingR" } do
				local wing = model:FindFirstChild(side)
				local hinge = wing and wing:FindFirstChild("Hinge") :: BasePart?
				if hinge then
					local hingeCf = CFrame.new(root.CFrame:PointToObjectSpace(hinge.Position))
					local frame = root.CFrame * hingeCf
					local parts, rels = {}, {}
					for _, p in wing:GetDescendants() do
						if p:IsA("BasePart") then
							table.insert(parts, p)
							table.insert(rels, frame:ToObjectSpace(p.CFrame))
						end
					end
					table.insert(wings, { Hinge = hingeCf, Side = math.sign(hingeCf.X), Parts = parts, Rels = rels })
				end
			end
			table.insert(list, { Model = model, Pos = start, Target = randomSpot(base), Idle = math.random() * 2, Height = height, Phase = math.random() * 6, Wings = wings, Float = if #wings > 0 then 1 else 0 })
		end
	end
end

local function stepWanderers(dt: number)
	for player, list in wanderers do
		local plot = playerPlots[player]
		local base = plot and plot:FindFirstChild("Base") :: BasePart?
		if not base then
			continue
		end
		for _, w in list do
			if not w.Model.Parent then
				continue
			end
			w.Phase += dt
			local toTarget = w.Target - w.Pos
			local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
			local hop = 0
			if w.Idle > 0 then
				w.Idle -= dt
			elseif flat.Magnitude < 0.5 then
				w.Idle = 1 + math.random() * 3
				w.Target = randomSpot(base)
			else
				local stepLen = math.min(PET_SPEED * dt, flat.Magnitude)
				w.Pos += flat.Unit * stepLen
				hop = math.abs(math.sin(w.Phase * 8)) * 0.6 -- little hops while walking
			end
			local look = if flat.Magnitude > 0.05 then flat.Unit else w.Model:GetPivot().LookVector
			local at = w.Pos + Vector3.new(0, w.Height / 2 + hop + w.Float, 0)
			w.Model:PivotTo(CFrame.lookAt(at, at + Vector3.new(look.X, 0, look.Z)))
			if #w.Wings > 0 then
				local root = w.Model.PrimaryPart :: BasePart
				local angle = math.sin(w.Phase * 9) * math.rad(22)
				for _, wing in w.Wings do
					local frame = root.CFrame * wing.Hinge * CFrame.Angles(0, 0, wing.Side * angle)
					local cfs = table.create(#wing.Parts)
					for i, rel in wing.Rels do
						cfs[i] = frame * rel
					end
					workspace:BulkMoveTo(wing.Parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
				end
			end
		end
	end
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 60 then
		return string.format("%d:%02d", seconds // 60, seconds % 60)
	end
	return seconds .. "s"
end

local incubatorLabels: { [Player]: { [number]: TextLabel } } = {}

local function renderIncubators(player: Player, data)
	local plot = playerPlots[player]
	local pads = plot and plot:FindFirstChild("Incubators")
	if not (plot and pads) then
		return
	end
	local visuals = plot:FindFirstChild("IncubatorVisuals")
	if visuals then
		visuals:Destroy()
	end
	visuals = Instance.new("Folder")
	visuals.Name = "IncubatorVisuals"
	visuals.Parent = plot
	incubatorLabels[player] = {}

	for n = 1, Config.IncubatorsFor(data.BaseLevel) do
		local pad = pads:FindFirstChild("Incubator" .. n) :: BasePart?
		local entry = data.Incubators[n]
		if pad then
			if entry and Config.Eggs[entry.Egg] then
				local egg = Config.Eggs[entry.Egg]
				local eggModel = Art.Egg(entry.Egg, entry.Pet, true)
				eggModel.Name = "IncubatingEgg"
				eggModel:PivotTo(pad.CFrame + Vector3.new(0, pad.Size.Y / 2, 0))
				eggModel.Parent = visuals
				local height = eggModel:GetAttribute("EggHeight") or egg.Size
				incubatorLabels[player][n] = label(eggModel.PrimaryPart :: BasePart, "", Color3.fromRGB(255, 220, 140), height / 2 + 1.5)

			else
				local empty = Instance.new("Part")
				empty.Name = "EmptyMarker"
				empty.Size = Vector3.new(0.2, 0.2, 0.2)
				empty.Transparency = 1
				empty.Anchored = true
				empty.CanCollide = false
				empty.CanQuery = false
				empty.CFrame = pad.CFrame
				empty.Parent = visuals
				label(empty, "Empty incubator", Color3.fromRGB(200, 200, 200), 2.5)
			end
		end
	end
end

local function claimPlot(player: Player)
	for i = 1, #plotsFolder:GetChildren() do
		local plot = plotsFolder:FindFirstChild("Plot" .. i)
		if plot and not plotOwners[plot] then
			plotOwners[plot] = player
			playerPlots[player] = plot
			player:SetAttribute("Plot", plot.Name) -- the client uses this to find its own treadmill
			setSign(plot, player.DisplayName .. "'s Base")
			return plot
		end
	end
	warn("[PlotService] No free plot for", player.Name)
	return nil
end

local function releasePlot(player: Player)
	local plot = playerPlots[player]
	if not plot then
		return
	end
	plotOwners[plot] = nil
	playerPlots[player] = nil
	incubatorLabels[player] = nil
	wanderers[player] = nil
	for _, name in { "PetVisuals", "IncubatorVisuals", "Treadmill" } do
		local visuals = plot:FindFirstChild(name)
		if visuals then
			visuals:Destroy()
		end
	end
	BaseBuilder.Build(plot, 0)
	setSign(plot, "Empty Plot")
end

-- Rebuilds the owner's base at their upgrade level, then redraws their pets and eggs on it.
local builtLevel: { [Player]: number } = {}
local function refreshBase(player: Player, data)
	local plot = playerPlots[player]
	if not plot or builtLevel[player] == data.BaseLevel then
		return
	end
	builtLevel[player] = data.BaseLevel
	BaseBuilder.Build(plot, data.BaseLevel)
	setSign(plot, player.DisplayName .. "'s Base")
	renderPets(player, data)
	renderIncubators(player, data)
end

local function buyUpgrade(player: Player, plot: Instance): (boolean, string)
	if playerPlots[player] ~= plot then
		return false, "You can only upgrade your own base"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Not ready yet"
	end
	local upgrade = Config.BaseUpgrades[data.BaseLevel + 1]
	if not upgrade then
		return false, "Your base is fully upgraded!"
	end
	if data.Money < upgrade.Price then
		return false, "You need " .. BaseBuilder.UpgradeText(data.BaseLevel):match("%$[%d,]+")
	end
	DataService.Update(player, function(d)
		d.Money -= upgrade.Price
		d.BaseLevel += 1
	end)
	return true, string.format("Base upgraded to level %d! %d pet slots, %d hatching pedestals.", data.BaseLevel + 1, Config.PetSlotsFor(data.BaseLevel), Config.IncubatorsFor(data.BaseLevel))
end

function PlotService.GetPlot(player: Player): Instance?
	return playerPlots[player]
end

-- True when the player is standing on (or just above) their own base.
function PlotService.IsOnOwnBase(player: Player): boolean
	local plot = playerPlots[player]
	local base = plot and plot:FindFirstChild("Base") :: BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (base and root) then
		return false
	end
	local offset = base.CFrame:PointToObjectSpace(root.Position)
	return math.abs(offset.X) <= base.Size.X / 2 + 1 and math.abs(offset.Z) <= base.Size.Z / 2 + 1 and offset.Y > -2 and offset.Y < 15
end

function PlotService.TeleportHome(player: Player)
	local plot = playerPlots[player]
	local character = player.Character
	if not (plot and character) then
		return
	end
	local spawnPart = plot:FindFirstChild("PlayerSpawn") or plot:FindFirstChild("Base")
	if spawnPart and spawnPart:IsA("BasePart") then
		character:PivotTo(spawnPart.CFrame + Vector3.new(0, 3, 0))
	end
end

local function hatchReady(player: Player, data)
	-- Hatched pets go on the base while it has room, then into the inventory; when both are full the egg waits.
	local now = os.time()
	local hatched = {}
	local onBase, stored = #data.Pets, #data.Storage
	for n = #data.Incubators, 1, -1 do
		local entry = data.Incubators[n]
		if entry.EndsAt <= now then
			local toBase = onBase < Config.PetSlotsFor(data.BaseLevel)
			if toBase or stored < Config.MaxPetsStored then
				table.insert(hatched, { Index = n, Pet = entry.Pet or PlotService.RollPet(entry.Egg), ToBase = toBase })
				if toBase then
					onBase += 1
				else
					stored += 1
				end
			end
		end
	end
	if #hatched == 0 then
		return
	end
	DataService.Update(player, function(d)
		for _, h in hatched do
			table.remove(d.Incubators, h.Index)
			table.insert(if h.ToBase then d.Pets else d.Storage, h.Pet)
			local baseId = Config.SplitPet(h.Pet) -- the Index counts plain pets, not their Big or Golden versions
			if not table.find(d.Discovered, baseId) then
				table.insert(d.Discovered, baseId)
			end
		end
	end)
	for _, h in hatched do
		local pet = Config.Pets[h.Pet]
		local text = string.format("Your egg hatched into a %s %s!", pet.Rarity, pet.Name)
		if pet.Size or pet.Material then
			text = string.format("WOW! Your egg hatched into a %s %s! It earns $%s/s!", pet.Rarity, pet.Name, shortNumber(pet.MoneyPerSecond))
		end
		if not h.ToBase then
			text ..= " (base full: it's in your Pets inventory)"
		end
		Remotes.Notify:FireClient(player, text, Config.Rarities[pet.Rarity].Color)
	end
end

function PlotService.Start(map: Instance)
	plotsFolder = map:WaitForChild("Plots")
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("Origin") then
			BaseBuilder.Build(plot, 0)
		end
	end

	-- Studio-only test helper: ServerStorage.DevBuyUpgrade:Invoke(player) buys the next upgrade like the sign does.
	if game:GetService("RunService"):IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "DevBuyUpgrade"
		dev.OnInvoke = function(player: Player)
			return buyUpgrade(player, playerPlots[player])
		end
		dev.Parent = game:GetService("ServerStorage")
	end

	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, player)
		if not prompt:GetAttribute("UpgradeBase") then
			return
		end
		-- Players can fire prompts from anywhere with cheats, so check they are really standing at the sign.
		local signPart = prompt.Parent
		local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not (signPart and signPart:IsA("BasePart") and playerRoot and (playerRoot.Position - signPart.Position).Magnitude <= prompt.MaxActivationDistance + 15) then
			return
		end
		local plot = prompt
		while plot and plot.Parent ~= plotsFolder do
			plot = plot.Parent
		end
		if plot then
			local ok, message = buyUpgrade(player, plot)
			Remotes.Notify:FireClient(player, message, if ok then Color3.fromRGB(120, 255, 120) else Color3.fromRGB(255, 90, 90))
		end
	end)

	local function onPlayerAdded(player: Player)
		claimPlot(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart")
			task.wait() -- let the default spawn finish first
			PlotService.TeleportHome(player)
		end)
		if player.Character then
			PlotService.TeleportHome(player)
		end
		local data = DataService.WaitFor(player)
		if data and playerPlots[player] then
			refreshBase(player, data)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(releasePlot)

	Players.PlayerAdded:Connect(function()
		refreshFriendBoosts()
	end)
	Players.PlayerRemoving:Connect(function(player)
		refreshFriendBoosts(player)
	end)
	task.spawn(refreshFriendBoosts)

	-- Re-draw pets and incubators only when they actually change.
	local lastPetKey: { [Player]: string } = {}
	local lastIncubatorKey: { [Player]: string } = {}
	DataService.OnChanged(function(player, data)
		if not playerPlots[player] then
			return
		end
		refreshBase(player, data)
		local petKey = table.concat(data.Pets, ",")
		if lastPetKey[player] ~= petKey then
			lastPetKey[player] = petKey
			renderPets(player, data)
		end
		local parts = {}
		for _, entry in data.Incubators do
			table.insert(parts, entry.Egg .. "@" .. entry.EndsAt)
		end
		local incubatorKey = table.concat(parts, ",")
		if lastIncubatorKey[player] ~= incubatorKey then
			lastIncubatorKey[player] = incubatorKey
			renderIncubators(player, data)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPetKey[player] = nil
		lastIncubatorKey[player] = nil
		builtLevel[player] = nil
	end)

	game:GetService("RunService").Heartbeat:Connect(stepWanderers)

	-- Every second: pay income, tick incubator countdowns, hatch finished eggs.
	task.spawn(function()
		while true do
			task.wait(Config.IncomeTickSeconds)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if data then
					local boost = 1 + (player:GetAttribute("FriendBoost") or 0) / 100
					local income = petIncome(data) * boost * Config.IncomeTickSeconds
					if income > 0 then
						DataService.Update(player, function(d)
							d.Money += income
						end)
					end
					local labels = incubatorLabels[player]
					if labels then
						for n, entry in data.Incubators do
							local l = labels[n]
							local egg = Config.Eggs[entry.Egg]
							if l and egg then
								local left = entry.EndsAt - now
								l.Text = if left > 0
									then egg.Name .. "\n" .. formatTime(left)
									elseif #data.Pets >= Config.PetSlotsFor(data.BaseLevel) and #data.Storage >= Config.MaxPetsStored then egg.Name .. "\nPets full!"
									else egg.Name .. "\nHatching!"
							end
						end
					end
					hatchReady(player, data)
				end
			end
		end
	end)
end

return PlotService
