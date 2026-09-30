-- Handles every purchase and menu action. The server re-checks all costs; the client only asks.
-- Also wires the costume shop mannequins (walk up and buy) and the speed shop counter (opens the menu).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local ShopService = {}

local lastRequest: { [Player]: number } = {}

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
	if data.Candy < info.Price then
		return false, "You need " .. fmt(info.Price) .. " Candy"
	end
	DataService.Update(player, function(d)
		d.Candy -= info.Price
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
	if data.Money < costume.Price then
		return false, "You need $" .. fmt(costume.Price)
	end
	DataService.Update(player, function(d)
		d.Money -= costume.Price
		table.insert(d.OwnedCostumes, costumeId)
		d.EquippedCostume = costumeId
	end)
	return true, "Bought and equipped " .. costume.Name .. "!"
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
	if #data.Incubators >= Config.IncubatorsFor(data.BaseLevel) then
		return false, "All your incubators are busy"
	end
	DataService.Update(player, function(d)
		table.remove(d.Eggs, eggIndex)
		table.insert(d.Incubators, { Egg = eggId, Pet = petId, EndsAt = os.time() + egg.HatchSeconds })
	end)
	return true, string.format("%s is incubating on your base", egg.Name)
end

function actions.SellPet(player: Player, data, petIndex: any)
	if type(petIndex) ~= "number" then
		return false, "Pick a pet"
	end
	local petId = data.Pets[petIndex]
	local pet = petId and Config.Pets[petId]
	if not pet then
		return false, "That pet is gone"
	end
	local value = math.floor(pet.MoneyPerSecond * Config.PetSellSeconds)
	DataService.Update(player, function(d)
		table.remove(d.Pets, petIndex)
		d.Money += value
	end)
	return true, string.format("Sold %s for $%s", pet.Name, fmt(value))
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
	for _, display in mannequins:GetChildren() do
		local costumeId = display:GetAttribute("Costume")
		local costume = costumeId and Config.GetCostume(costumeId)
		local pedestal = display:FindFirstChild("Pedestal")
		if costume and costume.Id == costumeId and pedestal then
			-- Name, Candy bonus and price; the client swaps the price for Owned / Wearing.
			local sign = pedestal:FindFirstChild("InfoSign")
			if sign then
				(sign:FindFirstChild("NameLabel", true) :: TextLabel).Text = costume.Name;
				(sign:FindFirstChild("BonusLabel", true) :: TextLabel).Text = string.format("+%d%% Candy", costume.CandyBonus or 0);
				(sign:FindFirstChild("PriceLabel", true) :: TextLabel).Text = "$" .. fmt(costume.Price)
			end
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Buy / Wear"
			prompt.ObjectText = string.format("%s ($%s)", costume.Name, fmt(costume.Price))
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.Parent = pedestal
			prompt.Triggered:Connect(function(player)
				local ok, message = runAction(player, "BuyCostume", costume.Id)
				Remotes.Notify:FireClient(player, message, if ok then Color3.fromRGB(120, 255, 120) else Color3.fromRGB(255, 90, 90))
			end)
		end
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
	wireCostumeShop(map)
	wireMenuCounters(map)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ShopService
