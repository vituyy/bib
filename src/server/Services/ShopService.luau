-- Handles every purchase and menu action. The server re-checks all costs; the client only asks.
-- Also wires the costume shop mannequins (walk up and buy) and the speed shop counter (opens the menu).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local ShopService = {}

-- Where a brand-new player spawns: on the ground in front of the Costume Shop, looking at the cheapest costume.
local tutorialSpawn: CFrame? = nil
function ShopService.GetTutorialSpawn(): CFrame?
	return tutorialSpawn
end

local lastRequest: { [Player]: number } = {}

-- Redeemable codes (typed in the Store menu). Each player can use a code once. Codes are not case sensitive.
-- Keep them here, not in Config: Config is sent to every player, this script is not.
-- Rewards: Money and/or Candy.
local CODES: { [string]: { Money: number?, Candy: number? } } = {
	DEV01 = { Money = 100000 },
	DEV02 = { Candy = 10000 },
	DEV03 = { Money = 100000000 },
}
local wrongCodes: { [Player]: { Count: number, ResetAt: number } } = {}

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local actions = {}

function actions.BuyTreadmill(player: Player, data, tier: any)
	if type(tier) ~= "number" then
		return false, "Pick a treadmill"
	end
	local info = Config.Treadmills[tier]
	if not info then
		return false, "Unknown treadmill"
	end
	if tier <= data.Treadmill then
		return false, "You already have a better treadmill"
	end
	if data.Money < info.Price then
		return false, "You need $" .. fmt(info.Price)
	end
	DataService.Update(player, function(d)
		d.Money -= info.Price
		d.Treadmill = tier
	end)
	return true, info.Name .. " is now in front of your base!"
end

-- Buy a trail with Money, or equip one you already own (pressing an equipped trail takes it off).
function actions.BuyTrail(player: Player, data, index: any)
	local info = type(index) == "number" and Config.Trails[index]
	if not info then
		return false, "Unknown trail"
	end
	if table.find(data.OwnedTrails, index) then
		local equip = if data.Trail == index then 0 else index
		DataService.Update(player, function(d)
			d.Trail = equip
		end)
		return true, if equip == 0 then info.Name .. " taken off" else info.Name .. " equipped"
	end
	if data.Money < info.Price then
		return false, "You need $" .. fmt(info.Price)
	end
	DataService.Update(player, function(d)
		d.Money -= info.Price
		table.insert(d.OwnedTrails, index)
		d.Trail = index
	end)
	return true, string.format("Bought %s! Treadmill XP x%s", info.Name, tostring(info.Multiplier))
end

function actions.BuyCostume(player: Player, data, costumeId: any)
	if type(costumeId) ~= "string" then
		return false, "Unknown costume"
	end
	local costume = Config.GetCostume(costumeId)
	if costume.Id ~= costumeId then
		return false, "Unknown costume"
	end
	if table.find(data.OwnedCostumes, costumeId) then
		DataService.Update(player, function(d)
			d.EquippedCostume = costumeId
		end)
		return true, costume.Name .. " equipped"
	end
	if data.Candy < costume.Price then
		return false, "You need " .. fmt(costume.Price) .. " Candy"
	end
	DataService.Update(player, function(d)
		d.Candy -= costume.Price
		table.insert(d.OwnedCostumes, costumeId)
		d.EquippedCostume = costumeId
	end)
	return true, "Bought and equipped " .. costume.Name .. "!"
end

function actions.RedeemCode(player: Player, data, code: any)
	if type(code) ~= "string" or #code > 40 then
		return false, "Type a code first"
	end
	local key = string.upper((string.gsub(code, "%s", "")))
	if key == "" then
		return false, "Type a code first"
	end
	local now = os.clock()
	local tries = wrongCodes[player]
	if tries and now < tries.ResetAt and tries.Count >= 5 then
		return false, "Too many wrong codes. Wait a minute and try again."
	end
	local reward = CODES[key]
	if not reward then
		if not tries or now >= tries.ResetAt then
			tries = { Count = 0, ResetAt = now + 60 }
			wrongCodes[player] = tries
		end
		tries.Count += 1
		return false, "That code does not exist"
	end
	if table.find(data.RedeemedCodes, key) then
		return false, "You already used this code"
	end
	DataService.Update(player, function(d)
		table.insert(d.RedeemedCodes, key)
		d.Money += reward.Money or 0
		d.Candy += reward.Candy or 0
	end)
	local parts = {}
	if reward.Money then
		table.insert(parts, "$" .. fmt(reward.Money))
	end
	if reward.Candy then
		table.insert(parts, fmt(reward.Candy) .. " Candy")
	end
	return true, "Code accepted! You got " .. table.concat(parts, " and ") .. "!"
end

---------------------------------------------------------------------------
-- Playtest tools (Admin panel). Only admins can use them: everyone inside Studio, Config.AdminUserIds, and the
-- game's creator (or a group owner). Every command re-checks this on the server.
---------------------------------------------------------------------------
local function isAdmin(player: Player): boolean
	if RunService:IsStudio() or table.find(Config.AdminUserIds, player.UserId) then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return game.CreatorId == player.UserId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank >= 254
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

local adminCommands: { [string]: (player: Player, data: any, n: number?) -> (boolean, string) } = {}

adminCommands.Money = function(player)
	DataService.Update(player, function(d)
		d.Money += 100000
	end)
	return true, "+$100,000"
end

adminCommands.Candy = function(player)
	DataService.Update(player, function(d)
		d.Candy += 10000
	end)
	return true, "+10,000 Candy"
end

adminCommands.Level = function(player, data)
	DataService.Update(player, function(d)
		d.SpeedLevel = math.min(d.SpeedLevel + 10, Config.MaxSpeedLevel)
		d.SpeedXp = 0
	end)
	return true, "Speed Level " .. data.SpeedLevel
end

adminCommands.Rebirth = function(player, data)
	if data.Rebirths >= Config.MaxRebirths then
		return false, "Already at the last rebirth"
	end
	DataService.Update(player, function(d)
		d.Rebirths += 1
		d.SpeedLevel, d.SpeedXp = 0, 0
	end)
	return true, "Rebirth " .. data.Rebirths
end

adminCommands.Unlock = function(player)
	DataService.Update(player, function(d)
		for _, costume in Config.Costumes do
			if not table.find(d.OwnedCostumes, costume.Id) then
				table.insert(d.OwnedCostumes, costume.Id)
			end
		end
		d.Treadmill = #Config.Treadmills
		d.OwnedTrails = {}
		for i = 1, #Config.Trails do
			table.insert(d.OwnedTrails, i)
		end
		d.PetCapLevel, d.PadLevel = #Config.PetCapacityUpgrades, #Config.HatchPadUpgrades
	end)
	return true, "Everything in the shops unlocked (your costume stays as it was)"
end

adminCommands.Eggs = function(player)
	local added = 0
	DataService.Update(player, function(d)
		for eggId in Config.Eggs do
			if #d.Eggs < Config.MaxEggsHeld then
				table.insert(d.Eggs, Config.MakeEggEntry(eggId, nil))
				added += 1
			end
		end
	end)
	return true, "Added " .. added .. " eggs to your bag"
end

adminCommands.HatchNow = function(player)
	DataService.Update(player, function(d)
		for _, entry in d.Incubators do
			entry.EndsAt = 0
		end
	end)
	return true, "Every incubating egg is ready"
end

adminCommands.Phase = function()
	require(script.Parent.DayNightService).Skip()
	return true, "Phase skipped (skip the day too for a fresh night with new eggs)"
end

adminCommands.God = function(player)
	local on = not player:GetAttribute("AdminGod")
	player:SetAttribute("AdminGod", on or nil)
	return true, if on then "God mode ON: owners can not catch you" else "God mode OFF"
end

adminCommands.Teleport = function(player, _data, n)
	local character = player.Character
	if not character then
		return false, "No character"
	end
	if n == 0 then
		require(script.Parent.PlotService).TeleportHome(player)
		return true, "Teleported to your base"
	elseif n == -1 then
		local spawn = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("LobbySpawn") :: BasePart?
		if spawn then
			character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
			return true, "Teleported to the hub"
		end
		return false, "No lobby spawn"
	end
	local houses = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Street") and workspace.Map.Street:FindFirstChild("Houses")
	local house = houses and houses:FindFirstChild("House" .. tostring(n))
	local exit = house and (house:FindFirstChild("OwnerExit", true) or house:FindFirstChild("OwnerSpawn", true)) :: BasePart?
	if not exit then
		return false, "House " .. tostring(n) .. " has no front-door marker"
	end
	character:PivotTo(CFrame.new(exit.Position + Vector3.new(0, 4, 0)))
	return true, "Teleported to House " .. tostring(n)
end

adminCommands.Reset = function(player)
	DataService.Update(player, function(d)
		for key in d do
			d[key] = nil
		end
		for key, value in Config.StartingData do
			d[key] = deepCopy(value)
		end
	end)
	return true, "Your progress was reset to a brand-new player"
end

adminCommands.Timeline = function(player)
	return true, DataService.TimelineText(player)
end

function actions.Admin(player: Player, data, arg: any)
	if not isAdmin(player) then
		return false, "Admins only"
	end
	local command = type(arg) == "table" and adminCommands[arg.Cmd]
	if not command then
		return false, "Unknown command"
	end
	local n = if type(arg.N) == "number" then arg.N else nil
	return command(player, data, n)
end

-- Put an egg from the bag into a free incubator. Hatching is free; rarer eggs take longer.
function actions.Hatch(player: Player, data, eggIndex: any)
	if type(eggIndex) ~= "number" then
		return false, "Pick an egg"
	end
	local entry = data.Eggs[eggIndex]
	local eggId, petId
	if entry then
		eggId, petId = Config.ParseEgg(entry)
	end
	local egg = eggId and Config.Eggs[eggId]
	if not egg then
		return false, "That egg is gone"
	end
	if #data.Incubators >= Config.IncubatorsFor(data.PadLevel) then
		return false, "All your incubators are busy"
	end
	DataService.Update(player, function(d)
		table.remove(d.Eggs, eggIndex)
		table.insert(d.Incubators, { Egg = eggId, Pet = petId, EndsAt = os.time() + egg.HatchSeconds })
	end)
	return true, string.format("%s is incubating on your base", egg.Name)
end

-- Pets are either equipped (data.Pets: on the base, earning) or in the inventory (data.Storage).
-- The Pets menu sends { Pet = petId, Equipped = bool } to say which one it means.
local function petArg(data, arg: any): (string?, { string }?)
	if type(arg) ~= "table" or type(arg.Pet) ~= "string" or not Config.Pets[arg.Pet] then
		return nil, nil
	end
	local list = if arg.Equipped then data.Pets else data.Storage
	return if table.find(list, arg.Pet) then arg.Pet else nil, list
end

local function removeOne(list: { string }, petId: string)
	table.remove(list, table.find(list, petId) :: number)
end

function actions.SellPet(player: Player, data, arg: any)
	local petId = petArg(data, arg)
	if not petId then
		return false, "That pet is gone"
	end
	local pet = Config.Pets[petId]
	local value = math.floor(pet.MoneyPerSecond * Config.PetSellSeconds)
	DataService.Update(player, function(d)
		removeOne(if arg.Equipped then d.Pets else d.Storage, petId)
		d.Money += value
	end)
	return true, string.format("Sold %s for $%s", pet.Name, fmt(value))
end

function actions.EquipPet(player: Player, data, petId: any)
	if type(petId) ~= "string" or not table.find(data.Storage, petId) then
		return false, "That pet is gone"
	end
	if #data.Pets >= Config.PetSlotsFor(data.PetCapLevel) then
		return false, "Your base is full. Unequip a pet or upgrade your base."
	end
	DataService.Update(player, function(d)
		removeOne(d.Storage, petId)
		table.insert(d.Pets, petId)
	end)
	return true, Config.Pets[petId].Name .. " is on your base"
end

function actions.UnequipPet(player: Player, data, petId: any)
	if type(petId) ~= "string" or not table.find(data.Pets, petId) then
		return false, "That pet is gone"
	end
	if #data.Storage >= Config.MaxPetsStored then
		return false, "Your pet inventory is full"
	end
	DataService.Update(player, function(d)
		removeOne(d.Pets, petId)
		table.insert(d.Storage, petId)
	end)
	return true, Config.Pets[petId].Name .. " went to your inventory"
end

-- Puts the highest-earning pets on the base and the rest in the inventory.
function actions.EquipBest(player: Player, data)
	local all = table.clone(data.Pets)
	table.move(data.Storage, 1, #data.Storage, #all + 1, all)
	table.sort(all, function(a, b)
		return Config.Pets[a].MoneyPerSecond > Config.Pets[b].MoneyPerSecond
	end)
	local slots = Config.PetSlotsFor(data.PetCapLevel)
	local best = { table.unpack(all, 1, math.min(slots, #all)) }
	local rest = { table.unpack(all, slots + 1, #all) }
	DataService.Update(player, function(d)
		d.Pets = best
		d.Storage = rest
	end)
	return true, "Equipped your best pets!"
end

-- Fills every free incubator with the rarest eggs in the bag.
function actions.HatchBest(player: Player, data)
	local free = Config.IncubatorsFor(data.PadLevel) - #data.Incubators
	if free <= 0 then
		return false, "All your incubators are busy"
	end
	if #data.Eggs == 0 then
		return false, "No eggs to hatch. Go steal some!"
	end
	local order = {}
	for index, entry in data.Eggs do
		local egg = Config.Eggs[(Config.ParseEgg(entry))]
		if egg then
			table.insert(order, { Index = index, Rank = Config.Rarities[egg.Rarity].Order })
		end
	end
	table.sort(order, function(a, b)
		return a.Rank > b.Rank
	end)
	local picked = {}
	for n = 1, math.min(free, #order) do
		table.insert(picked, order[n].Index)
	end
	table.sort(picked, function(a, b)
		return a > b -- remove from the back so the other indexes stay valid
	end)
	local now = os.time()
	DataService.Update(player, function(d)
		for _, index in picked do
			local eggId, petId = Config.ParseEgg(table.remove(d.Eggs, index))
			table.insert(d.Incubators, { Egg = eggId, Pet = petId, EndsAt = now + Config.Eggs[eggId].HatchSeconds })
		end
	end)
	return true, string.format("%d egg%s incubating on your base", #picked, if #picked == 1 then " is" else "s are")
end

function actions.Rebirth(player: Player, data)
	local needed = Config.RebirthLevel(data.Rebirths)
	if not needed then
		return false, "You have done every rebirth!"
	end
	if data.SpeedLevel < needed then
		return false, "Reach Speed Level " .. needed .. " to rebirth"
	end
	DataService.Update(player, function(d)
		d.Rebirths += 1
		d.SpeedLevel = 0
		d.SpeedXp = 0
	end)
	return true, string.format("Rebirth %d! You now train x%s faster.", data.Rebirths, tostring(Config.XpMultiplier(data.Rebirths)))
end

-- Claim an Index milestone reward once enough different pets have been discovered.
function actions.ClaimIndex(player: Player, data, count: any)
	local reward
	for _, info in Config.IndexRewards do
		if info.Count == count then
			reward = info
		end
	end
	if not reward then
		return false, "Unknown reward"
	end
	if table.find(data.IndexClaimed, count) then
		return false, "Already claimed"
	end
	if #data.Discovered < count then
		return false, string.format("Discover %d pets first", count)
	end
	DataService.Update(player, function(d)
		table.insert(d.IndexClaimed, count)
		d.Money += reward.Money
	end)
	return true, string.format("Index reward: +$%s!", fmt(reward.Money))
end

-- Custom speed panel: run slower than your max speed. Picking your max (or more) goes back to always-max.
function actions.SetCustomSpeed(player: Player, data, speed: any)
	if type(speed) ~= "number" or speed ~= speed then
		return false, "Pick a speed"
	end
	local max = Config.WalkSpeedFor(data.SpeedLevel)
	speed = math.clamp(math.floor(speed * 2 + 0.5) / 2, math.min(Config.MinCustomSpeed, max), max)
	DataService.Update(player, function(d)
		d.CustomSpeed = if speed >= max then 0 else speed
	end)
	return true, "Speed set to " .. Config.FormatSpeed(speed)
end

local function runAction(player: Player, action: any, arg: any)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < 0.15 then
		return false, "Slow down!"
	end
	lastRequest[player] = now

	local handler = type(action) == "string" and actions[action]
	local data = DataService.Get(player)
	if not handler or not data then
		return false, "Not ready yet"
	end
	return handler(player, data, arg)
end

local function wireCostumeShop(map: Instance)
	-- The shop may sit in the map or anywhere else in Workspace (e.g. dragged in from the model rows).
	local shop = map:FindFirstChild("CostumeShop", true) or workspace:FindFirstChild("CostumeShop", true)
	local mannequins = shop and shop:FindFirstChild("Mannequins")
	if not mannequins then
		return
	end
	local cheapestId = Config.Costumes[2].Id -- the first costume after "None"
	local cheapestPedestal: BasePart? = nil
	for _, display in mannequins:GetChildren() do
		local costumeId = display:GetAttribute("Costume")
		local costume = costumeId and Config.GetCostume(costumeId)
		local pedestal = display:FindFirstChild("Pedestal")
		if costume and costume.Id == costumeId and pedestal then
			-- Name, Candy multiplier and XP rate, and price in Candy; the client swaps the price for Owned / Wearing.
			local sign = pedestal:FindFirstChild("InfoSign")
			if sign then
				(sign:FindFirstChild("NameLabel", true) :: TextLabel).Text = costume.Name;
				(sign:FindFirstChild("BonusLabel", true) :: TextLabel).Text = string.format("x%s Candy  |  %s XP/s", tostring(costume.CandyMultiplier), tostring(costume.XpPerSecond));
				(sign:FindFirstChild("PriceLabel", true) :: TextLabel).Text = fmt(costume.Price) .. " Candy"
			end
			if costume.Id == cheapestId and pedestal:IsA("BasePart") then
				cheapestPedestal = pedestal
			end
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Buy / Wear"
			prompt.ObjectText = string.format("%s (%s Candy)", costume.Name, fmt(costume.Price))
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.Parent = pedestal
			prompt.Triggered:Connect(function(player)
				-- Prompts can be fired from anywhere with cheats, so check the player really is at the mannequin.
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not (root and (root.Position - pedestal.Position).Magnitude <= prompt.MaxActivationDistance + 14) then
					return
				end
				local ok, message = runAction(player, "BuyCostume", costume.Id)
				Remotes.Notify:FireClient(player, message, if ok then Color3.fromRGB(120, 255, 120) else Color3.fromRGB(255, 90, 90))
			end)
		end
	end

	-- Tutorial: stand in front of the shop (on the side facing the hub's lobby spawn), look at the cheapest costume.
	-- The pedestal is tagged "TutorialCostume" and carries the ground point where the guide arrows start, so the
	-- client can draw the arrows for first-time players.
	if cheapestPedestal and shop and shop:IsA("Model") then
		local pedestal = cheapestPedestal :: BasePart
		local lobby = workspace:FindFirstChild("LobbySpawn", true)
		local toward = if lobby and lobby:IsA("BasePart") then lobby.Position else Vector3.zero
		local center = shop:GetBoundingBox().Position
		local out = Vector3.new(toward.X - center.X, 0, toward.Z - center.Z)
		out = if out.Magnitude > 1 then out.Unit else Vector3.new(-1, 0, 0)
		local want = pedestal.Position + out * 18
		local hit = workspace:Raycast(Vector3.new(want.X, pedestal.Position.Y + 40, want.Z), Vector3.new(0, -120, 0))
		local ground = if hit then hit.Position else Vector3.new(want.X, 0, want.Z)
		local standAt = ground + Vector3.new(0, 3.5, 0)
		tutorialSpawn = CFrame.lookAt(standAt, Vector3.new(pedestal.Position.X, standAt.Y, pedestal.Position.Z))
		pedestal:SetAttribute("TutorialSpawn", ground)
		CollectionService:AddTag(pedestal, "TutorialCostume")
	end
end

local function wireMenuCounters(map: Instance)
	for _, inst in workspace:GetDescendants() do
		local menu = inst:GetAttribute("OpenMenu")
		if menu and inst:IsA("BasePart") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Shop"
			prompt.ObjectText = menu
			prompt.MaxActivationDistance = 10
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt:SetAttribute("OpenMenu", menu) -- the client opens the menu when this prompt fires
			prompt.Parent = inst
		end
	end
end

function ShopService.Start(map: Instance)
	Remotes.Request.OnServerInvoke = runAction
	local function markAdmin(player: Player)
		if isAdmin(player) then
			player:SetAttribute("IsAdmin", true) -- the client shows the Admin panel
		end
	end
	Players.PlayerAdded:Connect(markAdmin)
	for _, player in Players:GetPlayers() do
		task.spawn(markAdmin, player)
	end
	wireCostumeShop(map)
	wireMenuCounters(map)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		wrongCodes[player] = nil
	end)
end

return ShopService
