-- Gives each player a base, pays pet income, and lets owners manually hatch ready eggs at their pads.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Art = require(ReplicatedStorage.Shared.Art)
local DataService = require(script.Parent.DataService)
local BaseBuilder = require(script.Parent.BaseBuilder)
local ShopService = require(script.Parent.ShopService)

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

local incubatorPrompts = {}
local hatchBusyUntil = {}
local hatchEgg -- defined below; prompts capture their egg to reject stale interactions

local function updateIncubators(player: Player, data)
	local now = os.time()
	local full = #data.Pets >= Config.PetSlotsFor(data.PetCapLevel) and #data.Storage >= Config.MaxPetsStored
	for n, entry in data.Incubators do
		local egg = Config.Eggs[entry.Egg]
		local l = incubatorLabels[player] and incubatorLabels[player][n]
		local prompt = incubatorPrompts[player] and incubatorPrompts[player][n]
		local left = entry.EndsAt - now
		if l and egg then
			l.Text = egg.Name .. "\n" .. (if left > 0 then formatTime(left) elseif full then "READY — Pets full!" else "READY — Hatch!")
			l.TextColor3 = if left > 0 then Color3.fromRGB(255, 220, 140) else Color3.fromRGB(140, 255, 165)
		end
		if prompt then
			prompt.Enabled = left <= 0 and not full and os.clock() >= (hatchBusyUntil[player] or 0)
		end
	end
end

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
	incubatorPrompts[player] = {}

	for n = 1, Config.IncubatorsFor(data.PadLevel) do
		local pad = pads:FindFirstChild("Incubator" .. n) :: BasePart?
		local entry = data.Incubators[n]
		if pad then
			if entry and Config.Eggs[entry.Egg] then
				local egg = Config.Eggs[entry.Egg]
				local eggModel = Art.Egg(entry.Egg, entry.Pet, true)
				-- Keep even Gigantic display eggs inside the pedestal and below the pavilion roof.
				-- This changes their base display only; their inventory variant and income stay intact.
				local _, bounds = eggModel:GetBoundingBox()
				local displayScale = math.min(1, 7.1 / math.max(bounds.X, bounds.Z), 8.3 / bounds.Y)
				if displayScale < 1 then
					eggModel:ScaleTo(eggModel:GetScale() * displayScale)
					eggModel:SetAttribute("EggHeight", (eggModel:GetAttribute("EggHeight") or egg.Size) * displayScale)
				end
				eggModel.Name = "IncubatingEgg"
				eggModel:SetAttribute("IncubatorIndex", n)
				eggModel:PivotTo(pad.CFrame + Vector3.new(0, pad.Size.Y / 2, 0))
				eggModel.Parent = visuals
				local prompt = Instance.new("ProximityPrompt")
				prompt.Name = "ManualHatch"
				prompt.ActionText = "Hatch!"
				prompt.ObjectText = egg.Name
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 10
				prompt.RequiresLineOfSight = false
				prompt.ClickablePrompt = true
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
				prompt.Enabled = false
				prompt:SetAttribute("OwnerUserId", player.UserId)
				prompt:SetAttribute("IncubatorIndex", n)
				prompt.Parent = eggModel.PrimaryPart
				incubatorPrompts[player][n] = prompt
				prompt.Triggered:Connect(function(actor)
					local ok, message = hatchEgg(actor, plot, n, entry)
					if not ok then
						Remotes.Notify:FireClient(actor, message, Color3.fromRGB(255, 110, 110))
					end
				end)
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
	updateIncubators(player, data)
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
	incubatorPrompts[player] = nil
	hatchBusyUntil[player] = nil
	wanderers[player] = nil
	for _, name in { "PetVisuals", "IncubatorVisuals", "Treadmill" } do
		local visuals = plot:FindFirstChild(name)
		if visuals then
			visuals:Destroy()
		end
	end
	BaseBuilder.Build(plot, 0, 0)
	setSign(plot, "Empty Plot")
end

-- Rebuilds the owner's base at their upgrade levels, then redraws their pets and eggs on it.
local builtLevel: { [Player]: string } = {}
local function refreshBase(player: Player, data)
	local plot = playerPlots[player]
	local key = data.PetCapLevel .. "," .. data.PadLevel
	if not plot or builtLevel[player] == key then
		return
	end
	builtLevel[player] = key
	BaseBuilder.Build(plot, data.PetCapLevel, data.PadLevel)
	setSign(plot, player.DisplayName .. "'s Base")
	renderPets(player, data)
	renderIncubators(player, data)
end

-- The two base upgrades are independent. kind "Pets" raises Pet Capacity, kind "Pads" raises Hatching Pads.
local function buyUpgrade(player: Player, plot: Instance, kind: string): (boolean, string)
	if playerPlots[player] ~= plot then
		return false, "You can only upgrade your own base"
	end
	local data = DataService.Get(player)
	if not data then
		return false, "Not ready yet"
	end
	local isPets = kind == "Pets"
	if not isPets and kind ~= "Pads" then
		return false, "Unknown upgrade"
	end
	local level = if isPets then data.PetCapLevel else data.PadLevel
	local upgrades = if isPets then Config.PetCapacityUpgrades else Config.HatchPadUpgrades
	local upgrade = upgrades[level + 1]
	if not upgrade then
		return false, if isPets then "Your pet capacity is already maxed!" else "You already have every hatching pad!"
	end
	if data.Money < upgrade.Price then
		return false, "You need " .. BaseBuilder.UpgradeText(kind, level):match("%$[%d,]+")
	end
	DataService.Update(player, function(d)
		d.Money -= upgrade.Price
		if isPets then
			d.PetCapLevel += 1
		else
			d.PadLevel += 1
		end
	end)
	if isPets then
		return true, string.format("Pet capacity upgraded! Your base now holds %d pets.", upgrade.Capacity)
	end
	return true, string.format("Hatching pad added! You can now hatch %d eggs at once.", upgrade.Capacity)
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

-- Puts a freshly spawned character where it belongs: a player who has never owned a costume starts in front of
-- the Costume Shop (the tutorial leads them to the cheapest costume); everyone else starts on their own base.
function PlotService.Spawn(player: Player)
	local data = DataService.WaitFor(player)
	local character = player.Character
	local spawn = if data and Config.NeedsTutorial(data) then ShopService.GetTutorialSpawn() else nil
	if spawn and character then
		character:PivotTo(spawn)
	else
		PlotService.TeleportHome(player)
	end
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

-- The server awards exactly one ready egg, only at the owner's pad. No yielding before the
-- egg is removed: a repeated click or an old prompt cannot award the same pet twice.
hatchEgg = function(player: Player, plot: Instance, index: number, expectedEntry)
	if not plot or playerPlots[player] ~= plot then
		return false, "You can only hatch eggs on your own base"
	end
	local data = DataService.Get(player)
	local entry = data and data.Incubators[index]
	if not entry or (expectedEntry and entry ~= expectedEntry) then
		return false, "That egg is no longer on this pad"
	end
	if entry.EndsAt > os.time() then
		return false, "This egg is still incubating"
	end
	if os.clock() < (hatchBusyUntil[player] or 0) then
		return false, "Wait for your pet reveal to finish"
	end
	local pads = plot:FindFirstChild("Incubators")
	local pad = pads and pads:FindFirstChild("Incubator" .. index)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (pad and root and humanoid and humanoid.Health > 0 and (root.Position - pad.Position).Magnitude <= 12) then
		return false, "Come to your hatching pad to hatch this egg"
	end
	local toBase = #data.Pets < Config.PetSlotsFor(data.PetCapLevel)
	if not toBase and #data.Storage >= Config.MaxPetsStored then
		return false, "Your base and pet inventory are full. Make room first."
	end
	if not Config.Eggs[entry.Egg] then
		return false, "Unknown egg"
	end
	local petId = entry.Pet or PlotService.RollPet(entry.Egg)
	local pet = Config.Pets[petId]
	if not pet then
		return false, "Unknown pet"
	end
	hatchBusyUntil[player] = os.clock() + 3.2
	local padCFrame = pad.CFrame + Vector3.new(0, pad.Size.Y / 2, 0)
	DataService.Update(player, function(d)
		table.remove(d.Incubators, index)
		table.insert(if toBase then d.Pets else d.Storage, petId)
		local baseId = Config.SplitPet(petId)
		if not table.find(d.Discovered, baseId) then
			table.insert(d.Discovered, baseId)
		end
	end)
	local _, sizeName, materialName = Config.SplitPet(petId)
	DataService.QuestEvent(player, "Hatch", 1, { Size = sizeName, Material = materialName })
	Remotes.EggHatched:FireClient(player, { Egg = entry.Egg, Pet = petId, PadCFrame = padCFrame, ToBase = toBase })
	task.delay(3.1, function()
		if player.Parent then
			local text = string.format("You hatched %s %s! $%s/s", pet.Rarity, pet.Name, shortNumber(pet.MoneyPerSecond))
			if not toBase then text ..= " (in your Pets inventory: base full)" end
			Remotes.Notify:FireClient(player, text, Config.Rarities[pet.Rarity].Color)
		end
	end)
	return true, petId
end

function PlotService.Start(map: Instance)
	plotsFolder = map:WaitForChild("Plots")
	for _, plot in plotsFolder:GetChildren() do
		if plot:GetAttribute("Origin") then
			BaseBuilder.Build(plot, 0, 0)
		end
	end

	-- Studio-only test helper: ServerStorage.DevBuyUpgrade:Invoke(player, "Pets" or "Pads") buys the next upgrade like the sign does.
	if game:GetService("RunService"):IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "DevBuyUpgrade"
		dev.OnInvoke = function(player: Player, kind: string?)
			return buyUpgrade(player, playerPlots[player], kind or "Pets")
		end
		dev.Parent = game:GetService("ServerStorage")
		local hatchTest = Instance.new("BindableFunction")
		hatchTest.Name = "DevHatchEgg"
		hatchTest.OnInvoke = function(player, index, targetPlot)
			return hatchEgg(player, targetPlot or playerPlots[player], index)
		end
		hatchTest.Parent = game:GetService("ServerStorage")
		local readTest = Instance.new("BindableFunction")
		readTest.Name = "DevReadHatchData"
		readTest.OnInvoke = function(player)
			local data = DataService.Get(player)
			return { Pets = table.clone(data.Pets), Storage = table.clone(data.Storage), Incubators = table.clone(data.Incubators), Discovered = table.clone(data.Discovered) }
		end
		readTest.Parent = game:GetService("ServerStorage")
	end

	-- Buttons send only an upgrade kind. The server chooses the caller's own plot
	-- and validates proximity, funds and the current level before charging anything.
	local lastUpgradeClick = {}
	Remotes.UpgradeBase.OnServerInvoke = function(player: Player, kind: any)
		if kind ~= "Pets" and kind ~= "Pads" then
			return false, "Unknown upgrade"
		end
		local now = os.clock()
		if now - (lastUpgradeClick[player] or -math.huge) < 0.35 then
			return false, "Please wait a moment"
		end
		lastUpgradeClick[player] = now
		local plot = playerPlots[player]
		local board = plot and plot:FindFirstChild(kind .. "UpgradeBoard", true)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not (board and board:IsA("BasePart") and root and humanoid and humanoid.Health > 0
			and (root.Position - board.Position).Magnitude <= 20) then
			local message = "Move closer to your base's upgrade board"
			Remotes.Notify:FireClient(player, message, Color3.fromRGB(255, 110, 110))
			return false, message
		end
		local ok, message = buyUpgrade(player, plot, kind)
		Remotes.Notify:FireClient(player, message, if ok then Color3.fromRGB(120, 255, 120) else Color3.fromRGB(255, 90, 90))
		return ok, message
	end
	Players.PlayerRemoving:Connect(function(player)
		lastUpgradeClick[player] = nil
	end)

	local function onPlayerAdded(player: Player)
		claimPlot(player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart")
			task.wait() -- let the default spawn finish first
			PlotService.Spawn(player)
		end)
		if player.Character then
			PlotService.Spawn(player)
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
			table.insert(parts, entry.Egg .. "@" .. entry.EndsAt .. "#" .. (entry.Pet or ""))
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

	-- Every second: pay income, tick incubator countdowns and enable ready prompts.
	task.spawn(function()
		while true do
			task.wait(Config.IncomeTickSeconds)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local data = DataService.Get(player)
				if data then
					local boost = 1 + (player:GetAttribute("FriendBoost") or 0) / 100
					local income = petIncome(data) * boost * Config.BoostFactor(data, "Money") * Config.IncomeTickSeconds
					if income > 0 then
						DataService.Update(player, function(d)
							d.Money += income
						end)
					end
					updateIncubators(player, data)
				end
			end
		end
	end)
end

return PlotService
