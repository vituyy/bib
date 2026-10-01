-- Houses: Trick-or-Treat at the door for Candy (needs a good enough costume), steal eggs from inside,
-- and get chased by the owner. Every night each house fills up with 4-6 eggs of mixed rarity.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Art = require(ReplicatedStorage.Shared.Art)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local CharacterService = require(script.Parent.CharacterService)
local DayNightService = require(script.Parent.DayNightService)

local HouseService = {}

-- Owners walk straight at the thief, so yard props (braziers, statues, fences) must not snag them.
-- Owner parts go in the "Owners" collision group, which passes through "OwnerPassable" decoration.
local PhysicsService = game:GetService("PhysicsService")
local OWNERS, PASSABLE = "Owners", "OwnerPassable"
for _, group in { OWNERS, PASSABLE } do
	if not PhysicsService:IsCollisionGroupRegistered(group) then
		PhysicsService:RegisterCollisionGroup(group)
	end
end
PhysicsService:CollisionGroupSetCollidable(OWNERS, PASSABLE, false)


type HouseState = {
	House: Model,
	Index: number,
	Info: any,
	OwnerName: string,
	Owner: Model?,
	OwnerHome: boolean,
	Spots: { BasePart },
	Eggs: { [number]: Model }, -- spot index -> egg model
	KnockCooldowns: { [Player]: number },
	Door: BasePart?,
	Prompt: ProximityPrompt?,
	Busy: boolean, -- a door scene is playing
}

type Carry = {
	House: HouseState,
	EggId: string,
	PetId: string?,
	Started: number,
	Chased: boolean,
	Character: Model,
}

local houses: { HouseState } = {}
local carrying: { [Player]: Carry } = {}
local chaseLimitZ = -math.huge -- the Level 1 line; set from the map in Start

local GREEN = Color3.fromRGB(120, 255, 120)
local RED = Color3.fromRGB(255, 90, 90)
local ORANGE = Color3.fromRGB(255, 170, 60)

local function notify(player: Player, text: string, color: Color3?)
	Remotes.Notify:FireClient(player, text, color)
end

local function rootOf(model: Model?): BasePart?
	return model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function studs(p: BasePart)
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Inlet
end

---------------------------------------------------------------------------
-- Owner NPC
---------------------------------------------------------------------------
local function buildOwnerRig(name: string, color: Color3, scale: number): Model
	local model = Instance.new("Model")
	model.Name = "Owner"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1) * scale
	root.Color = color
	studs(root)
	root.Parent = model

	local function limb(partName: string, size: Vector3, offset: Vector3, partColor: Color3)
		local p = Instance.new("Part")
		p.Name = partName
		p.Size = size * scale
		p.Color = partColor
		p.CanCollide = false
		p.Massless = true
		studs(p)
		p.CFrame = root.CFrame * CFrame.new(offset * scale)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
		return p
	end
	limb("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0), Color3.fromRGB(230, 220, 200))
	limb("Arms", Vector3.new(4, 2, 1), Vector3.new(0, 0, 0), color)
	limb("Legs", Vector3.new(2, 2, 1), Vector3.new(0, -2, 0), Color3.fromRGB(40, 35, 45))

	local humanoid = Instance.new("Humanoid")
	humanoid.HipHeight = 2 * scale
	humanoid.DisplayName = name
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 80
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.BreakJointsOnDeath = false
	humanoid.Parent = model

	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = OWNERS
		end
	end
	model.PrimaryPart = root
	return model
end

-- Swap the block body for the house's owner model (Assets.Owners.House<N>) when there is one.
local function dressOwner(owner: Model, index: number, scale: number)
	local root = owner:FindFirstChild("HumanoidRootPart") :: BasePart
	local art = Art.Clone("Owners", "House" .. index, 7 * scale, true, true)
	if not art then
		return
	end
	art.Name = "Look"
	art:PivotTo(root.CFrame)
	Art.WeldTo(art, root)
	art.Parent = owner
	for _, p in owner:GetChildren() do
		if p:IsA("BasePart") then
			p.Transparency = 1
		end
	end
end

local function resetOwner(state: HouseState)
	local house = state.House
	local spawnPart = house:FindFirstChild("OwnerSpawn") :: BasePart?
	local owner = state.Owner
	local humanoid = owner and owner:FindFirstChildOfClass("Humanoid")
	if not (owner and owner.Parent and humanoid and humanoid.Health > 0) then
		if owner then
			owner:Destroy()
		end
		local scale = 1 + state.Index * 0.05
		owner = buildOwnerRig(state.OwnerName, Color3.fromHSV((state.Index * 0.13) % 1, 0.6, 0.7), scale)
		dressOwner(owner :: Model, state.Index, scale)
		state.Owner = owner
		humanoid = owner:FindFirstChildOfClass("Humanoid")
	end
	assert(owner and humanoid, "owner rig missing")

	humanoid.WalkSpeed = state.Info.OwnerSpeed
	if spawnPart then
		owner:PivotTo(spawnPart.CFrame)
	end
	owner.Parent = house
	local root = rootOf(owner)
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		pcall(function()
			root:SetNetworkOwner(nil) -- server drives the chase
		end)
		humanoid:MoveTo(root.Position)
	end
	state.OwnerHome = true
end

---------------------------------------------------------------------------
-- Eggs in houses
---------------------------------------------------------------------------
local function rarityOrder(eggId: string): number
	return Config.Rarities[Config.Eggs[eggId].Rarity].Order
end

local function rollEgg(weights: { [string]: number }): string
	local total = 0
	for _, w in weights do
		total += w
	end
	local roll = math.random() * total
	local last
	for eggId, w in weights do
		last = eggId
		roll -= w
		if roll <= 0 then
			return eggId
		end
	end
	return last
end

local onStealTriggered: (HouseState, number, Player) -> () -- defined below

local function clearEggs(state: HouseState)
	for spot, eggModel in state.Eggs do
		eggModel:Destroy()
		state.Eggs[spot] = nil
	end
end

local function spawnEggs(state: HouseState)
	clearEggs(state)
	-- Roll one egg per spot, then put the rarest eggs on the hardest-to-reach spots.
	local rolled = {}
	for _ = 1, #state.Spots do
		table.insert(rolled, rollEgg(state.Info.EggWeights))
	end
	table.sort(rolled, function(a, b)
		return rarityOrder(a) < rarityOrder(b)
	end)

	for spotIndex, spot in state.Spots do
		local eggId = rolled[spotIndex]
		-- The pet is decided now, so the egg can look like what is inside it.
		local petId = PlotService.RollPet(eggId)
		local eggModel = Art.Egg(eggId, petId, true)
		eggModel.Name = "Egg"
		eggModel:PivotTo(spot.CFrame + Vector3.new(0, spot.Size.Y / 2, 0))

		-- No name or rarity sign: players judge the egg by its look.
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Steal"
		prompt.ObjectText = "Egg"
		prompt.HoldDuration = Config.StealHoldDuration
		prompt.MaxActivationDistance = 9
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.Parent = eggModel.PrimaryPart
		prompt.Triggered:Connect(function(player)
			onStealTriggered(state, spotIndex, player)
		end)

		eggModel:SetAttribute("EggId", eggId)
		eggModel:SetAttribute("PetId", petId)
		eggModel.Parent = state.House
		state.Eggs[spotIndex] = eggModel
	end
end

---------------------------------------------------------------------------
-- Carrying and chasing
---------------------------------------------------------------------------
local function attachCarriedEgg(player: Player, eggId: string, petId: string?)
	local root = rootOf(player.Character)
	if not root then
		return
	end
	local eggModel = Art.Egg(eggId, petId, false, true)
	eggModel.Name = "CarriedEgg"
	eggModel:PivotTo(root.CFrame * CFrame.new(0, 3, 0))
	for _, d in eggModel:GetDescendants() do
		if d:IsA("BasePart") then
			d.Massless = true
			d.CanQuery = false
		end
	end
	Art.WeldTo(eggModel, root)
	eggModel.Parent = player.Character
end

local function clearCarry(player: Player)
	carrying[player] = nil
	if player.Parent then
		player:SetAttribute("CarryingEgg", nil)
		Remotes.ChaseState:FireClient(player, false)
	end
	local character = player.Character
	local carried = character and character:FindFirstChild("CarriedEgg")
	if carried then
		carried:Destroy()
	end
end

-- outcome: "escaped" (egg delivered), "caught", "sunrise", or "lost" (thief died or left)
local function finishTheft(player: Player, outcome: string)
	local carry = carrying[player]
	if not carry then
		return
	end
	clearCarry(player)
	local state = carry.House
	local egg = Config.Eggs[carry.EggId]

	if outcome == "escaped" then
		DataService.Update(player, function(data)
			table.insert(data.Eggs, Config.MakeEggEntry(carry.EggId, carry.PetId))
		end)
		notify(player, "You escaped with a " .. egg.Name .. "! Put it in an incubator from the Eggs menu.", GREEN)
	elseif outcome == "caught" then
		notify(player, state.OwnerName .. " caught you and took the " .. egg.Name .. " back!", RED)
		CharacterService.Stun(player, Config.CaughtStunTime)
	elseif outcome == "sunrise" then
		notify(player, "The sun came up and your " .. egg.Name .. " crumbled to dust!", ORANGE)
	end
end

local function startChase(state: HouseState, player: Player, eggId: string, petId: string?)
	carrying[player] = {
		House = state,
		EggId = eggId,
		PetId = petId,
		Started = os.clock(),
		Chased = true,
		Character = player.Character :: Model,
	}
	player:SetAttribute("CarryingEgg", eggId)
	attachCarriedEgg(player, eggId, petId)

	-- The owner bursts out of the front door if they were at home.
	if state.OwnerHome and state.Owner then
		local exit = state.House:FindFirstChild("OwnerExit") :: BasePart?
		if exit then
			state.Owner:PivotTo(exit.CFrame)
		end
		state.OwnerHome = false
	end
	Remotes.ChaseState:FireClient(player, true, state.OwnerName)
	notify(player, state.OwnerName .. " saw you! RUN back to your base!", RED)
end

-- One loop drives every chase: deliveries, catches, give-ups and owners walking home.
local function chaseStep()
	for player, carry in carrying do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not player.Parent or character ~= carry.Character or not humanoid or humanoid.Health <= 0 or not rootOf(character) then
			finishTheft(player, "lost")
		elseif PlotService.IsOnOwnBase(player) then
			finishTheft(player, "escaped")
		end
	end

	for _, state in houses do
		local owner = state.Owner
		local ownerRoot = rootOf(owner)
		local ownerHumanoid = owner and owner:FindFirstChildOfClass("Humanoid")
		if not (ownerRoot and ownerHumanoid) then
			continue
		end

		-- Chase the nearest thief of this house.
		local target: Player? = nil
		local targetDistance = math.huge
		for player, carry in carrying do
			if carry.House == state and carry.Chased then
				local thiefRoot = rootOf(player.Character) :: BasePart
				local distance = (ownerRoot.Position - thiefRoot.Position).Magnitude
				if thiefRoot.Position.Z < chaseLimitZ then
					-- Owners never follow you past the Level 1 line into the hub.
					carry.Chased = false
					Remotes.ChaseState:FireClient(player, false)
					notify(player, "You made it off the street! " .. state.OwnerName .. " stopped chasing.", GREEN)
				elseif os.clock() - carry.Started > Config.ChaseMaxDuration or distance > Config.ChaseGiveUpDistance then
					carry.Chased = false
					Remotes.ChaseState:FireClient(player, false)
					notify(player, state.OwnerName .. " gave up! Get the egg back to your base.", ORANGE)
				elseif distance < targetDistance then
					target = player
					targetDistance = distance
				end
			end
		end

		if target then
			if targetDistance <= Config.CatchDistance then
				finishTheft(target, "caught")
			else
				ownerHumanoid:MoveTo((rootOf(target.Character) :: BasePart).Position)
			end
		elseif not state.OwnerHome then
			resetOwner(state)
		end
	end
end

onStealTriggered = function(state: HouseState, spotIndex: number, player: Player)
	local data = DataService.Get(player)
	local eggModel = state.Eggs[spotIndex]
	if not (data and eggModel) then
		return
	end
	if not DayNightService.IsNight() then
		return
	end
	if carrying[player] then
		notify(player, "You are already carrying an egg!", RED)
		return
	end
	if #data.Eggs >= Config.MaxEggsHeld then
		notify(player, "Your egg bag is full. Hatch some eggs first!", RED)
		return
	end
	local eggId = eggModel:GetAttribute("EggId")
	local petId = eggModel:GetAttribute("PetId")
	eggModel:Destroy()
	state.Eggs[spotIndex] = nil
	startChase(state, player, eggId, petId)
end

---------------------------------------------------------------------------
-- Trick-or-Treat
---------------------------------------------------------------------------
local CANDY_COLORS = {
	Color3.fromRGB(255, 140, 0),
	Color3.fromRGB(255, 80, 160),
	Color3.fromRGB(120, 255, 120),
	Color3.fromRGB(120, 200, 255),
	Color3.fromRGB(255, 240, 90),
}

-- Smoothly move an anchored model. Returns false if `alive` says the scene should stop.
local function glide(model: Model, toCF: CFrame, duration: number, style: Enum.EasingStyle, alive: () -> boolean): boolean
	local fromCF = model:GetPivot()
	local t0 = os.clock()
	while true do
		if not alive() then
			return false
		end
		local a = math.min((os.clock() - t0) / duration, 1)
		model:PivotTo(fromCF:Lerp(toCF, TweenService:GetValue(a, style, Enum.EasingDirection.Out)))
		if a >= 1 then
			return true
		end
		task.wait()
	end
end

local function speechBubble(owner: Model, text: string, color: Color3, scale: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "SpeechBubble"
	gui.Adornee = rootOf(owner)
	gui.Size = UDim2.fromOffset(0, 0)
	gui.StudsOffset = Vector3.new(0, 4.5 * scale, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
	label.TextColor3 = color
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = text
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 22
	limit.Parent = label
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = label
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = gui

	gui.Parent = owner
	TweenService:Create(gui, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(320, 90) }):Play()
	Debris:AddItem(gui, 8)
	return gui
end

-- Candy flies from the owner into the player's hands.
local function tossCandy(from: Vector3, player: Player)
	task.spawn(function()
		local count = 7
		local duration = 0.7
		local pieces = {}
		for i = 1, count do
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Ball
			p.Size = Vector3.one * 0.7
			p.Material = Enum.Material.Neon
			p.Color = CANDY_COLORS[(i - 1) % #CANDY_COLORS + 1]
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.Position = from
			p.Parent = workspace
			Debris:AddItem(p, 5)
			pieces[i] = p
		end
		local t0 = os.clock()
		while os.clock() - t0 < duration + count * 0.06 do
			local targetRoot = rootOf(player.Character)
			local target = targetRoot and targetRoot.Position or from
			for i, p in pieces do
				local a = math.clamp((os.clock() - t0 - (i - 1) * 0.06) / duration, 0, 1)
				if p.Parent then
					p.Position = from:Lerp(target, a) + Vector3.new(0, math.sin(a * math.pi) * 4, 0)
					p.Transparency = if a > 0.85 then (a - 0.85) / 0.15 else 0
				end
			end
			task.wait()
		end
		for _, p in pieces do
			p:Destroy()
		end
	end)
end

-- The door scene: the door opens, the owner steps up and talks, then everything goes back.
-- It stops quietly if the owner leaves to chase a thief or the sun comes up.
local function playDoorScene(state: HouseState, player: Player, happy: boolean, line: string)
	local door, owner = state.Door, state.Owner
	local root = rootOf(owner)
	if not (door and owner and root) then
		return
	end
	local scale = 1 + state.Index * 0.05
	local closedCF = door.CFrame
	local homeCF = owner:GetPivot()
	local function alive()
		return state.OwnerHome and state.Owner == owner and owner.Parent ~= nil
	end

	state.Busy = true
	if state.Prompt then
		state.Prompt.Enabled = false
	end
	root.Anchored = true
	door.CanCollide = false

	-- The door swings inward on its left edge.
	local openCF = closedCF * CFrame.new(-3.5, 0, 0) * CFrame.Angles(0, -math.rad(105), 0) * CFrame.new(3.5, 0, 0)
	TweenService:Create(door, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = openCF }):Play()

	-- The owner steps into the doorway, looking at the player.
	local ahead = closedCF * CFrame.new(0, 0, 3)
	local spot = Vector3.new(ahead.X, homeCF.Y, ahead.Z)
	local lookAt = rootOf(player.Character)
	local faceTo = if lookAt then Vector3.new(lookAt.Position.X, spot.Y, lookAt.Position.Z) else spot + closedCF.LookVector
	local doorwayCF = CFrame.lookAt(spot, faceTo)
	if glide(owner, doorwayCF, 0.6, Enum.EasingStyle.Quad, alive) then
		local bubble = speechBubble(owner, line, if happy then Color3.fromRGB(235, 110, 0) else Color3.fromRGB(200, 40, 40), scale)
		if happy then
			tossCandy(spot + Vector3.new(0, 3, 0), player)
			-- A happy double hop.
			for _ = 1, 2 do
				if not (glide(owner, doorwayCF + Vector3.new(0, 1.5, 0), 0.15, Enum.EasingStyle.Quad, alive)
					and glide(owner, doorwayCF, 0.15, Enum.EasingStyle.Quad, alive)) then
					break
				end
			end
		else
			-- An angry shake.
			for i = 1, 6 do
				local sway = doorwayCF * CFrame.Angles(0, math.rad(if i % 2 == 0 then 14 else -14), 0)
				if not glide(owner, sway, 0.08, Enum.EasingStyle.Linear, alive) then
					break
				end
			end
			glide(owner, doorwayCF, 0.08, Enum.EasingStyle.Linear, alive)
		end
		-- Let the player read it.
		local readUntil = os.clock() + (if happy then 2 else 2.4)
		while os.clock() < readUntil and alive() do
			task.wait(0.1)
		end
		bubble:Destroy()
	end

	-- Back to normal. If the owner left for a chase, only the door is put back.
	if alive() then
		glide(owner, homeCF, 0.6, Enum.EasingStyle.Quad, alive)
	end
	if root.Parent then
		root.Anchored = false
	end
	local closeInfo = if happy
		then TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		else TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In) -- slam!
	local closing = TweenService:Create(door, closeInfo, { CFrame = closedCF })
	closing:Play()
	closing.Completed:Wait()
	door.CFrame = closedCF
	door.CanCollide = true
	state.Busy = false
	if state.Prompt then
		state.Prompt.Enabled = true
	end
end

local function onKnock(state: HouseState, player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	if not DayNightService.IsNight() then
		notify(player, "Nobody answers. Trick-or-Treat only works at night!", ORANGE)
		return
	end
	if state.Busy then
		return
	end
	-- If the owner is out chasing a thief nobody opens the door.
	local scene = state.OwnerHome and state.Door ~= nil
	local costume = Config.GetCostume(data.EquippedCostume)
	if costume.Tier < state.Info.CostumeTier then
		local roast = Config.CostumeRoasts[math.random(#Config.CostumeRoasts)]
		local needed = Config.Costumes[state.Info.CostumeTier + 1]
		notify(player, string.format('%s: "%s"', state.OwnerName, roast), RED)
		notify(player, string.format("Minimum costume for this house: %s. No candy for you!", needed.Name), ORANGE)
		if scene then
			task.spawn(playDoorScene, state, player, false, roast)
		end
		return
	end
	local now = os.clock()
	local readyAt = state.KnockCooldowns[player] or 0
	if now < readyAt then
		notify(player, string.format("%s has no more candy for you. Come back in %ds.", state.OwnerName, math.ceil(readyAt - now)), ORANGE)
		return
	end
	state.KnockCooldowns[player] = now + Config.TrickOrTreatCooldown

	local candy = math.floor(state.Info.CandyPerKnock * (1 + (costume.CandyBonus or 0) / 100))
	DataService.Update(player, function(d)
		d.Candy += candy
	end)
	notify(player, string.format("%s gave you %d Candy!", state.OwnerName, candy), ORANGE)
	if scene then
		task.spawn(playDoorScene, state, player, true, Config.TreatGreetings[math.random(#Config.TreatGreetings)])
	end
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
local function setupHouse(house: Model, index: number)
	local info = Config.Houses[index]
	local spots = {}
	local spotsFolder = house:FindFirstChild("EggSpots")
	if spotsFolder then
		for i = 1, #spotsFolder:GetChildren() do
			local spot = spotsFolder:FindFirstChild("Spot" .. i)
			if spot and spot:IsA("BasePart") then
				table.insert(spots, spot)
			end
		end
	end

	local state: HouseState = {
		House = house,
		Index = index,
		Info = info,
		OwnerName = house:GetAttribute("Owner") or info.Owner,
		Owner = house:FindFirstChild("Owner") :: Model?,
		OwnerHome = true,
		Spots = spots,
		Eggs = {},
		KnockCooldowns = {},
		Door = house:FindFirstChild("Door") :: BasePart?,
		Busy = false,
	}
	table.insert(houses, state)

	-- Decoration taller than a floor slab never blocks the owner (players still bump into it).
	local decor = house:FindFirstChild("Decor")
	if decor then
		for _, p in decor:GetDescendants() do
			if p:IsA("BasePart") and p.CanCollide and p.Size.Y > 1.2 then
				p.CollisionGroup = PASSABLE
			end
		end
	end


	local door = house:FindFirstChild("Door") :: BasePart?
	if door then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Trick-or-Treat!"
		prompt.ObjectText = state.OwnerName
		prompt.MaxActivationDistance = 10
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = door
		state.Prompt = prompt
		prompt.Triggered:Connect(function(player)
			onKnock(state, player)
		end)
	else
		warn("[HouseService] House has no Door part:", house:GetFullName())
	end

	resetOwner(state)
end

function HouseService.IsCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

function HouseService.Start(map: Instance)
	local street = map:WaitForChild("Street")
	local line = street:FindFirstChild("LevelLine1") :: BasePart?
	chaseLimitZ = street:GetAttribute("StartZ") or (line and line.Position.Z) or -math.huge
	-- A house is any Model with an Index attribute and an EggSpots folder, wherever it sits in Workspace,
	-- so houses keep working after being dragged onto their lots by hand.
	for _, house in workspace:GetDescendants() do
		local index = house:IsA("Model") and house:GetAttribute("Index")
		if index and Config.Houses[index] and house:FindFirstChild("EggSpots") then
			setupHouse(house, index)
		end
	end

	DayNightService.OnNightStart(function()
		for _, state in houses do
			spawnEggs(state)
		end
	end)
	DayNightService.OnDayStart(function()
		for player in carrying do
			finishTheft(player, "sunrise")
		end
		for _, state in houses do
			clearEggs(state)
			resetOwner(state)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		finishTheft(player, "lost")
		for _, s in houses do
			s.KnockCooldowns[player] = nil
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(chaseStep)
			if not ok then
				warn("[HouseService] chase error:", err)
			end
		end
	end)
end

return HouseService
