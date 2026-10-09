-- Houses: Trick-or-Treat at the door for Candy (needs a good enough costume), steal eggs from inside,
-- and get chased by the owner. Every night each house fills up with 4-6 eggs of mixed rarity.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
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
	-- Chase navigation
	Solid: RaycastParams?, -- walls, floors and roofs of this house (for "is the way blocked?")
	GroundOffset: number, -- root height above the floor
	Goal: Vector3?, -- where the owner is heading (the thief, or his spot)
	GoalOffset: number, -- height of that goal's root above its floor
	Waypoints: { PathWaypoint }?,
	WpIndex: number,
	PathPending: boolean,
	PathFailed: boolean,
	PathAt: number,
	PathGoal: Vector3?,
	ReturnStart: number?,
	PathGen: number, -- bumped whenever navigation resets, so a late path result for an old goal is ignored
	AlertUntil: number?, -- the owner is still noticing the thief until this time (os.clock)
	Target: Player?, -- the thief being chased right now (read live every frame, not sampled)
	Active: Player?, -- the thief the owner is dealing with; he finishes with them before the next one
	Intercept: boolean, -- running round to get behind the thief instead of cutting them off
	InterceptSince: number?,
	DoorSetup: any?, -- set while the front door is held open for the chase
}

type Carry = {
	House: HouseState,
	SpotIndex: number, -- where the egg was picked up, so it can go back there
	EggId: string,
	PetId: string?,
	Started: number,
	Chased: boolean,
	ChaseFrom: number?, -- when the owner got within range of this thief (the give-up timer starts here)
	ActivatedAt: number?, -- when this thief became the owner's target (he may still be far away)
	Character: Model,
}

local houses: { HouseState } = {}
local openChaseDoor: (HouseState) -> () -- defined with the door code below
local closeChaseDoor: (HouseState, boolean) -> () -- (state, instant)
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

-- Players can fire prompts from anywhere with cheats, so the server checks they really are standing nearby.
local function isNear(player: Player, prompt: ProximityPrompt): boolean
	local root = rootOf(player.Character)
	local part = prompt.Parent
	return root ~= nil and part ~= nil and part:IsA("BasePart") and (root.Position - part.Position).Magnitude <= prompt.MaxActivationDistance + 14
end

-- Owners run through props with a body that does not collide. If that ever makes one fall through the floor,
-- this turns off and owners collide with props again (they may snag, but the chase keeps working).
local ghostWorks = true

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

-- Owners run Config.BloodMoon.OwnerSpeedMultiplier faster during the Blood Moon.
local function ownerSpeed(state: HouseState): number
	local speed = state.Info.OwnerSpeed
	if ReplicatedStorage:GetAttribute("BloodMoon") then
		speed *= Config.BloodMoon.OwnerSpeedMultiplier
	end
	return speed
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

	humanoid.WalkSpeed = ownerSpeed(state)
	if spawnPart then
		owner:PivotTo(spawnPart.CFrame)
	end
	owner.Parent = house
	local root = rootOf(owner)
	state.Goal, state.Waypoints, state.ReturnStart, state.AlertUntil, state.Target = nil, nil, nil, nil, nil
	state.Active, state.Intercept, state.InterceptSince = nil, false, nil
	state.PathGoal, state.PathFailed = nil, false
	state.PathGen += 1
	closeChaseDoor(state, true)
	if root then
		root.CanCollide = true
		-- How high the root floats above the floor, so the way home can be planned on the floor.
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { owner }
		params.RespectCanCollide = true
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -15, 0), params)
		state.GroundOffset = if hit then root.Position.Y - hit.Position.Y else 3 * (1 + state.Index * 0.05)
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

-- Puts an egg (with the pet inside it, which can be a Big / Golden / ... variant) on a spot, ready to be stolen.
local function placeEgg(state: HouseState, spotIndex: number, eggId: string, petId: string)
	local spot = state.Spots[spotIndex]
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
		if isNear(player, prompt) then
			onStealTriggered(state, spotIndex, player)
		end
	end)

	eggModel:SetAttribute("EggId", eggId)
	eggModel:SetAttribute("PetId", petId)
	eggModel.Parent = state.House
	state.Eggs[spotIndex] = eggModel
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

	-- Blood Moon: bigger size and material chances, and half the time one bloody egg on the hardest spot.
	local bloodMoon = ReplicatedStorage:GetAttribute("BloodMoon") == true
	local bloodySpot = if bloodMoon and state.Info.BloodyEgg and math.random() < Config.BloodMoon.BloodyEggChance then #state.Spots else nil
	for spotIndex = 1, #state.Spots do
		local eggId = rolled[spotIndex]
		-- The pet is decided now, so the egg can look like what is inside it. Size and material are two
		-- separate rolls, so an egg can get both, one or neither.
		local size, material = Config.RollVariant(if bloodMoon then Config.BloodMoon.VariantChanceMultiplier else nil)
		if spotIndex == bloodySpot then
			-- Bloody eggs roll a material at the normal chance, never a size.
			eggId = state.Info.BloodyEgg
			size, material = Config.RollVariant(nil, true)
		end
		local petId = Config.MakePetId(PlotService.RollPet(eggId), size, material)
		placeEgg(state, spotIndex, eggId, petId)
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
	local eggModel = Art.Egg(eggId, petId, false, true, 1.4) -- a Gigantic egg is not drawn bigger than this in your arms
	eggModel.Name = "CarriedEgg"
	-- Held in front of the chest. The model's pivot is the egg's bottom centre. Every client bends the carrier's
	-- arms around it (see "Carrying an egg" in CostumeLabels.client), so it sits close and chest high.
	local height = eggModel:GetAttribute("EggHeight") or 3
	eggModel:PivotTo(root.CFrame * CFrame.new(0, 0.6 - height / 2, -(0.7 + 0.32 * height)))
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

-- A positional sound (everyone near `parent` hears it) from Config.Audio.Sfx; nothing if it has no id.
local function playSfx(name: string, parent: Instance, delay: number?)
	local id = Config.SfxId(name)
	if not id then
		return
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = Config.Audio.Sfx[name].Volume
	sound.RollOffMaxDistance = 150
	sound.Parent = parent
	task.delay(delay or 0, function()
		sound:Play()
	end)
	Debris:AddItem(sound, 6)
end

-- The owner kicks a caught thief away from him: a thud, a grunt, and a long flight in the direction of the kick.
-- The thief's own client launches the character (it owns its physics) and the character flops until it lands.
local function kickThief(state: HouseState, player: Player)
	local thiefRoot = rootOf(player.Character) :: BasePart?
	local ownerRoot = rootOf(state.Owner)
	if not thiefRoot then
		return
	end
	local away = if ownerRoot then Vector3.new(thiefRoot.Position.X - ownerRoot.Position.X, 0, thiefRoot.Position.Z - ownerRoot.Position.Z) else Vector3.zero
	if away.Magnitude < 0.5 then
		away = Vector3.new(thiefRoot.CFrame.LookVector.X, 0, thiefRoot.CFrame.LookVector.Z)
	end
	away = away.Unit
	-- Ballistic launch: range = v^2 * sin(2a) / g, so this lands about KickDistance studs away on flat ground.
	local angle = math.rad(Config.KickAngle)
	local gravity = workspace.Gravity
	local speed = math.sqrt(Config.KickDistance * gravity / math.sin(2 * angle))
	local velocity = away * (speed * math.cos(angle)) + Vector3.new(0, speed * math.sin(angle), 0)
	local flight = 2 * speed * math.sin(angle) / gravity
	CharacterService.Grace(player, flight + 2)
	Remotes.Kick:FireClient(player, velocity, flight + 0.3)
	playSfx("Kick", thiefRoot, 0)
	playSfx("Grunt", thiefRoot, 0.12)
end

-- outcome: "escaped" (egg delivered), "caught", "sunrise", or "lost" (thief died or left)
local function finishTheft(player: Player, outcome: string)
	local carry = carrying[player]
	if not carry then
		return
	end
	-- Capture the carried egg before clearCarry removes its world model.
	local character = player.Character
	local carriedEgg = character and character:FindFirstChild("CarriedEgg")
	local deliveryPosition = nil
	if carriedEgg and carriedEgg:IsA("Model") then
		deliveryPosition = carriedEgg:GetBoundingBox().Position
	else
		local root = rootOf(character)
		if root then deliveryPosition = (root.CFrame * CFrame.new(0, 0.6, -2)).Position end
	end
	clearCarry(player)
	local state = carry.House
	local egg = Config.Eggs[carry.EggId]
	-- The egg's full name, with its size and material when it has them ("Big Golden Candy Egg").
	local _, _, materialName, sizeInfo = Config.SplitPet(carry.PetId or "")
	local eggName = (if sizeInfo then sizeInfo.Label .. " " else "") .. (if materialName then materialName .. " " else "") .. egg.Name

	-- A caught thief (or one who died or left) loses the egg, and it goes back to the nest it came from so
	-- someone else can steal it. At sunrise every egg respawns anyway.
	if (outcome == "caught" or outcome == "lost") and DayNightService.IsNight() and carry.PetId and not state.Eggs[carry.SpotIndex] and state.Spots[carry.SpotIndex] then
		placeEgg(state, carry.SpotIndex, carry.EggId, carry.PetId)
	end

	if outcome == "escaped" then
		local awarded = DataService.Update(player, function(data)
			table.insert(data.Eggs, Config.MakeEggEntry(carry.EggId, carry.PetId))
			data.EggsStolen = (data.EggsStolen or 0) + 1
		end)
		if not awarded then return end
		if deliveryPosition then
			Remotes.EggDelivered:FireClient(player, deliveryPosition, carry.EggId, character)
		end
		DataService.QuestEvent(player, "Deliver", 1, { House = state.Index })
		notify(player, "You escaped with a " .. eggName .. "! Put it in an incubator from the Eggs menu.", GREEN)
		if egg.Rarity == "Bloody" then
			DataService.Update(player, function(data)
				data.BloodMoonSurvivor = true
			end)
			player:SetAttribute("Title", Config.BloodMoon.Title)
			notify(player, "🩸 You earned the title " .. Config.BloodMoon.Title .. "!", Color3.fromRGB(255, 40, 40))
			if Config.BloodMoon.BadgeId ~= 0 then
				task.spawn(pcall, function()
					game:GetService("BadgeService"):AwardBadge(player.UserId, Config.BloodMoon.BadgeId)
				end)
			end
		end
	elseif outcome == "caught" and ReplicatedStorage:GetAttribute("BloodMoon") then
		-- Under the Blood Moon an owner kills the thief. Only the carried egg is lost.
		DataService.QuestEvent(player, "Caught", 1)
		notify(player, state.OwnerName .. " caught you under the Blood Moon and KILLED you! The " .. eggName .. " went back in its nest.", RED)
		playSfx("Kick", rootOf(player.Character) or state.House, 0)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	elseif outcome == "caught" then
		DataService.QuestEvent(player, "Caught", 1)
		notify(player, state.OwnerName .. " caught you and KICKED you away! The " .. eggName .. " went back in its nest.", RED)
		CharacterService.Stun(player, Config.CaughtStunTime)
		kickThief(state, player)
	elseif outcome == "sunrise" then
		notify(player, "The sun came up and your " .. egg.Name .. " crumbled to dust!", ORANGE)
	end
end

---------------------------------------------------------------------------
-- Owner navigation
---------------------------------------------------------------------------
-- The owner is a Humanoid whose body does not collide, so props and furniture never snag him, and he still
-- stands on floors. While a wall or floor of his house is in the way he follows a planned path (through
-- rooms, doors, windows and stairs); in the open he runs straight at his goal.
local PATH_PARAMS = { AgentRadius = 1.5, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 4 }

local function requestPath(state: HouseState, from: Vector3, goal: Vector3)
	state.PathPending = true
	local gen = state.PathGen
	local fromFeet = from - Vector3.new(0, state.GroundOffset, 0)
	local goalFeet = goal - Vector3.new(0, state.GoalOffset, 0)
	task.spawn(function()
		local path = PathfindingService:CreatePath(PATH_PARAMS)
		local ok = pcall(function()
			path:ComputeAsync(fromFeet, goalFeet)
		end)
		if gen ~= state.PathGen then
			state.PathPending = false -- the owner reset while this was computing; the result is for an old goal
			return
		end
		if ok and path.Status == Enum.PathStatus.Success then
			local waypoints = path:GetWaypoints()
			state.Waypoints = waypoints
			-- Start at the waypoint nearest to where he is now (he kept running while this computed).
			local root = rootOf(state.Owner)
			local index = 2
			if root then
				local best = math.huge
				for i = 1, math.min(#waypoints, 5) do
					local p = waypoints[i].Position
					local d = Vector3.new(p.X - root.Position.X, 0, p.Z - root.Position.Z).Magnitude
					if d < best then
						best, index = d, math.max(i, 2)
					end
				end
			end
			state.WpIndex = index
			state.PathGoal = goal
			state.PathFailed = false
		else
			state.Waypoints = nil
			state.PathFailed = true -- he heads straight for the goal instead
		end
		state.PathAt = os.clock()
		state.PathPending = false
	end)
end

-- Decide how to reach `goal` (called about ten times a second).
local function navigate(state: HouseState, goal: Vector3, goalOffset: number)
	local root = rootOf(state.Owner)
	if not root then
		return
	end
	state.Goal = goal
	state.GoalOffset = goalOffset
	local from = root.Position
	local blocked = state.Solid ~= nil and workspace:Raycast(from, goal - from, state.Solid) ~= nil
	if not blocked then
		state.Waypoints = nil
		return
	end
	local moved = not state.PathGoal or (state.PathGoal - goal).Magnitude > 6
	local wait = if state.PathFailed then 1.5 else 0.5
	if not state.PathPending and (moved or not state.Waypoints) and os.clock() - state.PathAt > wait then
		requestPath(state, from, goal)
	end
end

-- Every frame: run toward the next waypoint (or straight at the goal). While chasing, the goal is the thief's
-- live position, and the owner's speed is enforced here so nothing (physics, network ownership, the Humanoid
-- state) can make him slower than his stat.
local function followGoal(state: HouseState, dt: number)
	local owner = state.Owner
	local root = rootOf(owner)
	local humanoid = owner and owner:FindFirstChildOfClass("Humanoid")
	local goal = state.Goal
	if not (root and humanoid and goal) then
		return
	end
	local thief = state.Target
	local thiefRoot = thief and rootOf(thief.Character)
	if thiefRoot and not state.Intercept then
		goal = thiefRoot.Position
	end
	local target = goal
	local waypoints = state.Waypoints
	if waypoints then
		local index = state.WpIndex
		local reach = math.max(3, ownerSpeed(state) * dt * 1.5)
		while index <= #waypoints do
			local p = waypoints[index].Position + Vector3.new(0, state.GroundOffset, 0)
			if Vector3.new(p.X - root.Position.X, 0, p.Z - root.Position.Z).Magnitude < reach then
				index += 1
			else
				break
			end
		end
		state.WpIndex = index
		if index <= #waypoints then
			local wp = waypoints[index]
			target = wp.Position + Vector3.new(0, state.GroundOffset, 0)
			if wp.Action == Enum.PathWaypointAction.Jump and not ghostWorks then
				humanoid.Jump = true
			end
		else
			state.Waypoints = nil
		end
	end
	humanoid:MoveTo(target)

	-- Guaranteed pace: horizontal velocity straight at the target at his full speed (never overshooting it).
	local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	local distance = flat.Magnitude
	if distance > 0.25 then
		local speed = math.min(ownerSpeed(state), distance / math.max(dt, 1 / 120))
		local direction = flat / distance
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(direction.X * speed, velocity.Y, direction.Z * speed)
	end
end

local function arriveHome(state: HouseState)
	local owner = state.Owner
	local root = rootOf(owner)
	local spawnPart = state.House:FindFirstChild("OwnerSpawn") :: BasePart?
	if owner and root and spawnPart then
		owner:PivotTo(spawnPart.CFrame) -- only the last step is snapped, so he stands exactly on his spot
		root.AssemblyLinearVelocity = Vector3.zero
		root.CanCollide = true
		local humanoid = owner:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:MoveTo(root.Position)
		end
	end
	state.Goal, state.Waypoints, state.ReturnStart, state.AlertUntil, state.Target = nil, nil, nil, nil, nil
	state.Active, state.Intercept, state.InterceptSince = nil, false, nil
	state.PathGoal, state.PathFailed = nil, false
	state.PathGen += 1
	state.OwnerHome = true
	closeChaseDoor(state, false)
end

-- A red "!" pops up over the owner's head while he notices the thief.
local function alertMarker(owner: Model, scale: number, duration: number)
	local root = rootOf(owner)
	if not root then
		return
	end
	local old = owner:FindFirstChild("AlertMarker")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "AlertMarker"
	gui.Adornee = root
	gui.Size = UDim2.fromOffset(0, 0)
	gui.StudsOffset = Vector3.new(0, 4.5 * scale, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = "!"
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 70, 70)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = owner
	TweenService:Create(gui, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(70, 90) }):Play()
	Debris:AddItem(gui, duration + 0.2)
end

local function startChase(state: HouseState, player: Player, eggId: string, petId: string?, spotIndex: number)
	local alreadyChasing = false
	for _, other in carrying do
		if other.House == state and other.Chased then
			alreadyChasing = true
		end
	end
	carrying[player] = {
		House = state,
		SpotIndex = spotIndex,
		EggId = eggId,
		PetId = petId,
		Started = os.clock(),
		Chased = true,
		Character = player.Character :: Model,
	}
	player:SetAttribute("CarryingEgg", eggId)
	attachCarriedEgg(player, eggId, petId)
	DataService.Milestone(player, "stole from house " .. state.Index)

	-- The owner starts the chase right where they stand. They pass through props and furniture, and the
	-- front door swings open so they can run out.
	if state.OwnerHome and state.Owner then
		state.OwnerHome = false
		state.ReturnStart = nil
		local root = rootOf(state.Owner)
		if root then
			root.Anchored = false
			root.CanCollide = not ghostWorks
			pcall(function()
				root:SetNetworkOwner(nil) -- unanchoring hands him to a nearby client; the server drives the chase
			end)
		end
		local ownerHumanoid = state.Owner:FindFirstChildOfClass("Humanoid")
		if ownerHumanoid then
			ownerHumanoid.WalkSpeed = ownerSpeed(state)
		end
		openChaseDoor(state)
	end
	-- The owner needs a moment to notice; a rarer (heavier) egg gives a longer head start.
	if not alreadyChasing and state.Owner then
		local egg = Config.Eggs[eggId]
		local reaction = Config.OwnerReaction + Config.OwnerReactionPerRarity * Config.Rarities[egg.Rarity].Order
		state.AlertUntil = os.clock() + reaction
		state.Goal, state.Waypoints = nil, nil
		state.PathGen += 1
		local humanoid = state.Owner:FindFirstChildOfClass("Humanoid")
		local root = rootOf(state.Owner)
		if humanoid and root then
			humanoid:MoveTo(root.Position)
		end
		alertMarker(state.Owner, 1 + state.Index * 0.05, reaction)
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

		if not state.OwnerHome then
			if not ownerRoot.Anchored and ownerRoot:GetNetworkOwner() ~= nil then
				pcall(function()
					ownerRoot:SetNetworkOwner(nil) -- a client simulating him would lag behind the server's view
				end)
			end
			if ownerHumanoid.WalkSpeed ~= ownerSpeed(state) then
				ownerHumanoid.WalkSpeed = ownerSpeed(state)
			end
			local home = state.House:FindFirstChild("OwnerSpawn") :: BasePart?
			if home and ownerRoot.Position.Y < home.Position.Y - 40 then
				if ghostWorks then
					ghostWorks = false
					warn("[HouseService] an owner fell through the floor while passing through props; owners collide with props again")
				end
				resetOwner(state)
				continue
			end
		end

		-- Thieves still running with an egg from this house, in the order they stole. The owner deals with the first
		-- one completely (catch, escape or give-up) and only then goes after the next.
		local queue: { { Player: Player, Carry: any } } = {}
		for player, carry in carrying do
			if carry.House == state and carry.Chased then
				local thiefRoot = rootOf(player.Character) :: BasePart
				if thiefRoot.Position.Z < chaseLimitZ then
					-- Owners never follow you past the Level 1 line into the hub.
					carry.Chased = false
					Remotes.ChaseState:FireClient(player, false)
					notify(player, "You made it off the street! " .. state.OwnerName .. " stopped chasing.", GREEN)
				else
					table.insert(queue, { Player = player, Carry = carry })
				end
			end
		end
		table.sort(queue, function(a, b)
			return a.Carry.Started < b.Carry.Started
		end)

		local target: Player? = nil
		local targetDistance = math.huge
		for _, entry in queue do
			local thiefRoot = rootOf(entry.Player.Character) :: BasePart
			local distance = (ownerRoot.Position - thiefRoot.Position).Magnitude
			-- The thief the owner is already after stays his target; otherwise the earliest thief in line.
			if state.Active ~= entry.Player and state.Active ~= nil and carrying[state.Active] and carrying[state.Active].Chased then
				continue
			end
			if state.Active ~= entry.Player then
				state.Active = entry.Player
				entry.Carry.ActivatedAt = os.clock()
				entry.Carry.ChaseFrom = nil
				state.Intercept, state.InterceptSince = false, nil
			end
			-- A thief who is still far away (the owner was busy with someone else) is run down first; the 30 s and
			-- the give-up distance only count once the owner is within range of him.
			if not entry.Carry.ChaseFrom and distance <= Config.ChaseGiveUpDistance then
				entry.Carry.ChaseFrom = os.clock()
			end
			local gaveUp
			if entry.Carry.ChaseFrom then
				gaveUp = os.clock() - entry.Carry.ChaseFrom > Config.ChaseMaxDuration or distance > Config.ChaseGiveUpDistance
			else
				gaveUp = os.clock() - (entry.Carry.ActivatedAt or 0) > 60
			end
			if gaveUp then
				entry.Carry.Chased = false
				state.Active = nil
				Remotes.ChaseState:FireClient(entry.Player, false)
				notify(entry.Player, state.OwnerName .. " gave up! Get the egg back to your base.", ORANGE)
				continue
			end
			target, targetDistance = entry.Player, distance
			break
		end
		-- He gave up on the first thief just now: the next one in line starts next tick.
		if not target and state.Active and not (carrying[state.Active] and carrying[state.Active].Chased) then
			state.Active = nil
		end

		state.Target = nil
		if target then
			state.ReturnStart = nil
			local thiefHumanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
			local thiefRoot = rootOf(target.Character) :: BasePart
			local thiefOffset = if thiefHumanoid then thiefHumanoid.HipHeight + thiefRoot.Size.Y / 2 else 3
			if os.clock() < (state.AlertUntil or 0) then
				-- Still noticing the thief: he stands there for a moment (and can not catch anyone yet).
				state.Goal, state.Waypoints = nil, nil
				ownerHumanoid:MoveTo(ownerRoot.Position)
			elseif targetDistance <= Config.CatchDistance and not target:GetAttribute("AdminGod") then
				finishTheft(target, "caught")
			else
				state.Target = target
				-- Cut-off check: when the owner is nearer to the thief's base than the thief is, and not close
				-- by, he runs to a spot behind and beside the thief first, then chases from behind.
				local goal = thiefRoot.Position
				local plot = PlotService.GetPlot(target)
				local base = plot and plot:FindFirstChild("Base") :: BasePart?
				local intercepting = false
				if base and targetDistance > Config.InterceptMinDistance then
					local toBase = Vector3.new(base.Position.X - thiefRoot.Position.X, 0, base.Position.Z - thiefRoot.Position.Z)
					local rel = Vector3.new(ownerRoot.Position.X - thiefRoot.Position.X, 0, ownerRoot.Position.Z - thiefRoot.Position.Z)
					if toBase.Magnitude > 1 then
						local dir = toBase.Unit
						local ahead = rel:Dot(dir)
						if ahead > 3 then
							if not state.Intercept then
								state.Intercept, state.InterceptSince = true, os.clock()
							end
							if os.clock() - (state.InterceptSince or 0) <= Config.InterceptMaxSeconds then
								local lateral = rel - dir * ahead
								lateral = if lateral.Magnitude > 1 then lateral.Unit else Vector3.new(-dir.Z, 0, dir.X)
								goal = thiefRoot.Position + lateral * Config.InterceptSide - dir * Config.InterceptBehind
								intercepting = true
							end
						end
					end
				end
				if not intercepting then
					state.Intercept = false
				end
				navigate(state, goal, thiefOffset)
			end
		elseif not state.OwnerHome then
			-- Nobody left to chase: walk back to his spot.
			local home = state.House:FindFirstChild("OwnerSpawn") :: BasePart?
			state.ReturnStart = state.ReturnStart or os.clock()
			if not home or os.clock() - state.ReturnStart > 45 then
				resetOwner(state) -- couldn't get home; put him back
			else
				local flat = Vector3.new(home.Position.X - ownerRoot.Position.X, 0, home.Position.Z - ownerRoot.Position.Z).Magnitude
				if flat < 2.5 and math.abs(home.Position.Y - ownerRoot.Position.Y) < 4 then
					arriveHome(state)
				else
					openChaseDoor(state)
					navigate(state, home.Position, state.GroundOffset)
				end
			end
		end
	end
end

onStealTriggered = function(state: HouseState, spotIndex: number, player: Player)
	local data = DataService.Get(player)
	local eggModel = state.Eggs[spotIndex]
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (data and eggModel and humanoid and humanoid.Health > 0) then
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
	startChase(state, player, eggId, petId, spotIndex)
end

---------------------------------------------------------------------------
-- Trick-or-Treat
---------------------------------------------------------------------------
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

-- Speech bubble above the owner. Dark with white text so it reads at night too (LightInfluence 0).
local function speechBubble(owner: Model, name: string, text: string, accent: Color3, scale: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "SpeechBubble"
	gui.Adornee = rootOf(owner)
	gui.Size = UDim2.fromOffset(0, 0)
	gui.StudsOffset = Vector3.new(0, 4.2 * scale, 0)
	gui.SizeOffset = Vector2.new(0, 0.5) -- the bubble sits on top of the owner's head
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 90

	local bubble = Instance.new("Frame")
	bubble.Size = UDim2.fromScale(1, 1)
	bubble.BackgroundColor3 = Color3.fromRGB(30, 18, 50)
	bubble.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = bubble
	local stroke = Instance.new("UIStroke")
	stroke.Color = accent
	stroke.Thickness = 5
	stroke.Parent = bubble

	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(18, 10)
	header.Size = UDim2.new(1, -36, 0, 24)
	header.Font = Enum.Font.GothamBlack
	header.TextSize = 20
	header.TextColor3 = accent
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = name
	header.Parent = bubble

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Position = UDim2.fromOffset(18, 38)
	body.Size = UDim2.new(1, -36, 1, -48)
	body.Font = Enum.Font.GothamBold
	body.TextSize = 28
	body.TextColor3 = Color3.new(1, 1, 1)
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Text = text
	body.Parent = bubble

	bubble.Parent = gui
	gui.Parent = owner
	TweenService:Create(gui, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(460, 170) }):Play()
	Debris:AddItem(gui, 12)
	return gui
end

-- A wrapped candy like the HUD icon: glossy pink ball with a bow on each side and a dark outline.
local function buildCandy(): Model
	local model = Instance.new("Model")
	model.Name = "Candy"
	local function piece(size: Vector3, offset: CFrame, color: Color3, round: boolean, transparency: number?): Part
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = color
		p.Size = size
		p.Transparency = transparency or 0
		if round then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		end
		p.CFrame = offset
		p.Parent = model
		return p
	end
	local body = piece(Vector3.one * 1.5, CFrame.new(), Color3.fromRGB(255, 110, 190), true)
	model.PrimaryPart = body
	for _, side in { -1, 1 } do
		for _, tilt in { -32, 32 } do
			piece(Vector3.new(1.5, 1.1, 0.18), CFrame.new(side * 1.3, 0, 0) * CFrame.Angles(math.rad(tilt), 0, math.rad(side * 10)), Color3.fromRGB(255, 60, 150), true)
		end
	end
	piece(Vector3.new(0.5, 0.35, 0.2), CFrame.new(-0.3, 0.35, -0.62) * CFrame.Angles(0, 0, math.rad(35)), Color3.new(1, 1, 1), true, 0.25)
	local outline = Instance.new("Highlight")
	outline.Adornee = model
	outline.FillTransparency = 1
	outline.OutlineColor = Color3.new(0, 0, 0)
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Parent = model
	return model
end

-- Candy flies from the owner into the player's hands.
local function tossCandy(from: Vector3, player: Player)
	task.spawn(function()
		local count = 6
		local duration = 0.8
		local pieces = {}
		for i = 1, count do
			local candy = buildCandy()
			candy:PivotTo(CFrame.new(from))
			candy.Parent = workspace
			Debris:AddItem(candy, 6)
			pieces[i] = candy
		end
		local t0 = os.clock()
		while os.clock() - t0 < duration + count * 0.08 do
			local targetRoot = rootOf(player.Character)
			local target = if targetRoot then targetRoot.Position + Vector3.new(0, 1, 0) else from
			for i, candy in pieces do
				local a = math.clamp((os.clock() - t0 - (i - 1) * 0.08) / duration, 0, 1)
				if candy.Parent then
					local pos = from:Lerp(target, a) + Vector3.new(0, math.sin(a * math.pi) * 5, 0)
					candy:PivotTo(CFrame.new(pos) * CFrame.Angles(a * 9 + i, a * 6, a * 12))
					if a >= 1 then
						candy:Destroy()
					end
				end
			end
			task.wait()
		end
		for _, candy in pieces do
			candy:Destroy()
		end
	end)
end

-- Works out how a door is built, whatever its size or direction: which way it faces, how wide it is and
-- which parts (handles, panels, bars...) are mounted on it, so they all swing together.
local DoorMotion = require(script.Parent.DoorMotion)

local function doorSetup(state: HouseState, door: BasePart)
	return DoorMotion.Get(state.House, door, state.Owner)
end

local function placeDoor(setup, amount: number)
	DoorMotion.Snap(setup, amount)
end

local function swingDoor(setup, from: number, to: number, duration: number, style: Enum.EasingStyle, direction: Enum.EasingDirection)
	-- Continue from the live pose rather than an assumed fully-open/closed pose.
	return DoorMotion.Animate(setup, to, duration, style, direction)
end

-- The front door swings open when a chase starts (and stays open while the owner is out), then shuts after
-- he is back on his spot. Everything mounted on the door swings with it.
openChaseDoor = function(state: HouseState)
	local door = state.Door
	if not door or state.DoorSetup or state.Busy then
		return
	end
	local ok, setup = pcall(doorSetup, state, door)
	if not ok then
		return
	end
	state.DoorSetup = setup
	for _, d in setup.Parts do
		d.Part.CanCollide = false
	end
	task.spawn(function()
		pcall(swingDoor, setup, 0, 1, 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end)
end

closeChaseDoor = function(state: HouseState, instant: boolean)
	local setup = state.DoorSetup
	if not setup then
		return
	end
	state.DoorSetup = nil
	local function restore()
		placeDoor(setup, 0)
		for _, d in setup.Parts do
			d.Part.CanCollide = d.Collide
		end
	end
	if instant then
		restore()
		return
	end
	state.Busy = true
	if state.Prompt then
		state.Prompt.Enabled = false
	end
	task.spawn(function()
		pcall(swingDoor, setup, 1, 0, 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		restore()
		state.Busy = false
		if state.Prompt then
			state.Prompt.Enabled = true
		end
	end)
end

-- The door scene: the door opens, the owner steps into the middle of the doorway and talks, then everything
-- goes back. It stops quietly if the owner leaves to chase a thief or the sun comes up.
local function playDoorScene(state: HouseState, player: Player, happy: boolean, line: string)
	local door, owner = state.Door, state.Owner
	local root = rootOf(owner)
	if not (door and owner and root) then
		return
	end
	local scale = 1 + state.Index * 0.05
	local homeCF = owner:GetPivot()
	local function alive()
		return state.OwnerHome and state.Owner == owner and owner.Parent ~= nil
	end

	local setupOk, setup = pcall(doorSetup, state, door)
	if not setupOk then
		warn("[HouseService] door setup error:", setup)
		return
	end
	state.Busy = true
	if state.Prompt then
		state.Prompt.Enabled = false
	end
	root.Anchored = true
	for _, d in setup.Parts do
		d.Part.CanCollide = false
	end

	local ok, err = pcall(function()
		-- Three knocks, then the door creaks open.
		playSfx("Knock", door)
		task.wait(0.65)
		if not alive() then
			return
		end
		playSfx("DoorCreak", door)
		swingDoor(setup, 0, 1, 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		if not alive() then
			return
		end

		-- The owner steps into the middle of the doorway, looking at the player.
		local spot = setup.Closed.Position + setup.Inward * (setup.Thick / 2 + 3.5)
		spot = Vector3.new(spot.X, homeCF.Y, spot.Z)
		local playerRoot = rootOf(player.Character)
		local faceTo = if playerRoot
			then Vector3.new(playerRoot.Position.X, spot.Y, playerRoot.Position.Z)
			else spot - setup.Inward
		local doorwayCF = CFrame.lookAt(spot, faceTo)
		if not glide(owner, doorwayCF, 0.6, Enum.EasingStyle.Quad, alive) then
			return
		end

		local accent = if happy then Color3.fromRGB(255, 150, 40) else Color3.fromRGB(255, 80, 80)
		local bubble = speechBubble(owner, state.OwnerName, line, accent, scale)
		if happy then
			tossCandy(spot + Vector3.new(0, 3, 0), player)
			for _ = 1, 2 do -- a happy double hop
				if not (glide(owner, doorwayCF + Vector3.new(0, 1.5, 0), 0.15, Enum.EasingStyle.Quad, alive)
					and glide(owner, doorwayCF, 0.15, Enum.EasingStyle.Quad, alive)) then
					break
				end
			end
		else
			for i = 1, 6 do -- an angry shake
				local sway = doorwayCF * CFrame.Angles(0, math.rad(if i % 2 == 0 then 14 else -14), 0)
				if not glide(owner, sway, 0.08, Enum.EasingStyle.Linear, alive) then
					break
				end
			end
			glide(owner, doorwayCF, 0.08, Enum.EasingStyle.Linear, alive)
		end

		-- Long enough to read the line.
		local words = #string.split(line, " ")
		local readUntil = os.clock() + 1.8 + words * 0.4
		while os.clock() < readUntil and alive() do
			task.wait(0.1)
		end
		bubble:Destroy()

		if alive() then
			glide(owner, homeCF, 0.6, Enum.EasingStyle.Quad, alive)
		end
	end)
	if not ok then
		warn("[HouseService] door scene error:", err)
	end

	-- Always put everything back, even if the scene was cut short.
	if root.Parent then
		root.Anchored = false
	end
	-- Hand the already-open door to the chase instead of slamming it on the owner.
	if not state.OwnerHome and state.Owner == owner and owner.Parent then
		state.DoorSetup = setup
		state.Busy = false
		if state.Prompt then
			state.Prompt.Enabled = true
		end
		task.spawn(function()
			pcall(swingDoor, setup, setup.Amount, 1, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end)
		return
	end
	if happy then
		swingDoor(setup, 1, 0, 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	else -- slam!
		swingDoor(setup, 1, 0, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end
	placeDoor(setup, 0)
	for _, d in setup.Parts do
		d.Part.CanCollide = d.Collide
	end
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

	local candy = math.floor(state.Info.CandyPerKnock * costume.CandyMultiplier * Config.BoostFactor(data, "Candy"))
	DataService.Update(player, function(d)
		d.Candy += candy
	end)
	DataService.QuestEvent(player, "Knock", 1)
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
		GroundOffset = 3,
		GoalOffset = 3,
		WpIndex = 1,
		Intercept = false,
		PathGen = 0,
		PathPending = false,
		PathFailed = false,
		PathAt = 0,
	}
	table.insert(houses, state)

	-- The walls, floors and roofs: used to tell whether the owner can run straight at someone or must find a way.
	local solid = {}
	for _, d in house:GetDescendants() do
		if d:IsA("BasePart") and d.Anchored and d.CanCollide then
			local skip = false
			local ancestor = d.Parent
			while ancestor and ancestor ~= house do
				if ancestor.Name == "Decor" or ancestor.Name == "Yard" or ancestor.Name == "EggSpots" or ancestor.Name == "Owner" then
					skip = true
					break
				end
				ancestor = ancestor.Parent
			end
			if not skip then
				table.insert(solid, d)
			end
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = solid
	params.RespectCanCollide = true
	state.Solid = params

	-- Decoration taller than a floor slab never blocks the owner (players still bump into it).
	local decor = house:FindFirstChild("Decor")
	if decor then
		for _, p in decor:GetDescendants() do
			if p:IsA("BasePart") and p.CanCollide and p.Size.Y > 1.2 then
				p.CollisionGroup = PASSABLE
			end
		end
	end

	-- Furniture is phantom for players as well: nobody gets stuck on a table or chair during a chase.
	if decor then
		local phantom = 0
		for _, folder in decor:GetChildren() do
			local inside = false
			for _, word in Config.PhantomFurniture.Folders do
				if string.find(string.lower(folder.Name), string.lower(word), 1, true) then
					inside = true
				end
			end
			if inside then
				for _, p in folder:GetDescendants() do
					if p:IsA("BasePart") and p.CanCollide then
						local lower = string.lower(p.Name)
						local standOn = false
						for _, word in Config.PhantomFurniture.Keep do
							if string.find(lower, word, 1, true) then
								standOn = true
								break
							end
						end
						if not standOn then
							p.CanCollide = false
							phantom += 1
						end
					end
				end
			end
		end
		if phantom > 0 then
			print(string.format("[HouseService] House %d: %d furniture parts are phantom", index, phantom))
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
			if isNear(player, prompt) then
				onKnock(state, player)
			end
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
	-- The green signs between levels say which Speed Level to bring and hang over the road.
	local road = street:FindFirstChild("Road")
	local roadX = if road and road:IsA("Model") then road:GetBoundingBox().Position.X else nil
	for index in Config.Houses do
		local marker = street:FindFirstChild("LevelLine" .. index) :: BasePart?
		local gui = marker and marker:FindFirstChildWhichIsA("BillboardGui")
		local sign = marker and marker:FindFirstChildWhichIsA("TextLabel", true)
		if sign then
			sign.Text = "Recommended Level " .. Config.RecommendedLevel(index)
		end
		if marker and gui and roadX then
			local anchor = marker:FindFirstChild("RoadSignAnchor") :: BasePart?
			if not anchor then
				anchor = Instance.new("Part")
				anchor.Name = "RoadSignAnchor"
				anchor.Size = Vector3.one
				anchor.Transparency = 1
				anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
				anchor.Parent = marker
			end
			anchor.Position = Vector3.new(roadX, marker.Position.Y, marker.Position.Z)
			gui.Adornee = anchor
		end
	end
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

	RunService.Heartbeat:Connect(function(dt)
		for _, state in houses do
			if state.OwnerHome or not state.Goal then
				continue
			end
			local thief = state.Target
			local thiefRoot = thief and rootOf(thief.Character)
			local ownerRoot = rootOf(state.Owner)
			if thief and thiefRoot and ownerRoot and not state.Intercept and carrying[thief] and os.clock() >= (state.AlertUntil or 0) then
				-- Catch on the live positions every frame, not only ten times a second.
				if (ownerRoot.Position - thiefRoot.Position).Magnitude <= Config.CatchDistance and not thief:GetAttribute("AdminGod") then
					finishTheft(thief, "caught")
					continue
				end
			end
			followGoal(state, dt)
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
