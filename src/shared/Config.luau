-- Central game balance. Tweak numbers here; every server and client script reads from this module.

local Config = {}

Config.DataStoreName = "SpookySteal_PlayerData_v2"
Config.AutosaveInterval = 120 -- seconds
Config.MaxPlayers = 5 -- one base per player (set the same number in Game Settings > Places)

Config.StartingData = {
	Candy = 0, -- set below to the price of the cheapest costume, so a new player can buy one at once
	Money = 0,
	SpeedLevel = 0,
	SpeedXp = 0,
	Rebirths = 0,
	Treadmill = 1, -- index into Config.Treadmills
	OwnedTrails = {}, -- indexes into Config.Trails
	Trail = 0, -- equipped trail (0 = none)
	OwnedCostumes = { "None" },
	EquippedCostume = "None",
	Eggs = {}, -- "EggId|PetId" entries waiting to be hatched (the pet is decided when the egg spawns)
	Incubators = {}, -- { { Egg = eggId, Pet = petId, EndsAt = unix time } }
	Pets = {}, -- pet ids equipped: placed on the base, earning Money
	Storage = {}, -- pet ids owned but not equipped (the Pets menu inventory)
	PetCapLevel = 0, -- Pet Capacity upgrades bought (0 to #Config.PetCapacityUpgrades)
	PadLevel = 0, -- Hatching Pad upgrades bought (0 to #Config.HatchPadUpgrades)
	Discovered = {}, -- pet ids hatched at least once (the Index)
	IndexClaimed = {}, -- Index milestone counts already claimed (5, 10, 15, 20)
	RedeemedCodes = {}, -- codes this player has already used (see CODES in ShopService)
	CustomSpeed = 0, -- speed the player chose with the Custom speed panel (0 = always run at their max speed)
	EggsStolen = 0, -- eggs brought home in total (the Top Egg Thieves board)
}

---------------------------------------------------------------------------
-- Day / night. Houses are only open at night; every egg respawns when night starts.
---------------------------------------------------------------------------
Config.NightSeconds = 300
Config.DaySeconds = 10

---------------------------------------------------------------------------
-- Player speed: run on a treadmill for XP, each Speed Level makes you faster.
-- Speed grows by the same amount every level: 20 at level 0, 170 at level 100.
---------------------------------------------------------------------------
Config.BaseWalkSpeed = 20 -- new players start here
Config.SpeedPerLevel = 1.5 -- extra walk speed for every Speed Level
Config.SpeedBonus = 0 -- flat extra speed on top of the curve
Config.MaxSpeedLevel = 100
Config.MinCustomSpeed = 16 -- lowest speed the Custom speed panel can pick (Roblox default walk speed)

-- A player's max speed at this Speed Level.
function Config.WalkSpeedFor(speedLevel: number): number
	return Config.BaseWalkSpeed + Config.SpeedPerLevel * speedLevel + Config.SpeedBonus
end

-- The speed a player actually runs at: their Custom speed if they picked one below their max, else their max.
function Config.ChosenSpeed(data: { [string]: any }): number
	local max = Config.WalkSpeedFor(data.SpeedLevel)
	local custom = tonumber(data.CustomSpeed) or 0
	return if custom > 0 then math.clamp(custom, math.min(Config.MinCustomSpeed, max), max) else max
end

-- 21.5 -> "21.5", 23 -> "23".
function Config.FormatSpeed(speed: number): string
	return if speed % 1 == 0 then string.format("%d", speed) else string.format("%.1f", speed)
end

-- XP needed to reach each Speed Level: XP_TO_REACH[1] is the cost of level 1.
-- Each level costs 20% more than the one before up to level 30, then 8% more up to level 70 and 4% more
-- after that. The first levels are cheap, the steep part makes levels 20 to 30 (houses 3 and 4) take about
-- 20 and 35 minutes, and the flatter end keeps up with the big treadmill, costume and trail multipliers.
local XP_TO_REACH = {}
local xpCost = 20
for level = 1, 100 do
	XP_TO_REACH[level] = math.floor(xpCost + 0.5)
	xpCost *= if level < 30 then 1.2 elseif level < 70 then 1.08 else 1.04
end

-- XP needed to go from this Speed Level to the next one.
function Config.XpToNext(speedLevel: number): number
	return XP_TO_REACH[speedLevel + 1] or XP_TO_REACH[#XP_TO_REACH]
end

-- Rebirth: reset Speed Level to 0 for a permanent XP multiplier.
-- Speed Level needed for each rebirth: every 10 levels up to 40, then every 15 up to 100.
Config.RebirthLevels = { 10, 20, 30, 40, 55, 70, 85, 100 }
Config.MaxRebirths = #Config.RebirthLevels

-- Level needed for the next rebirth, or nil once every rebirth is done.
function Config.RebirthLevel(rebirths: number): number?
	return Config.RebirthLevels[rebirths + 1]
end

-- Treadmill XP multiplier: 1 rebirth = x2, 2 rebirths = x3, and so on.
function Config.XpMultiplier(rebirths: number): number
	return 1 + rebirths
end

Config.TreadmillBeltSpeed = 10 -- studs/s the belt pushes you back; stop running and you slide off
Config.TreadmillTick = 0.5 -- seconds between XP payouts

-- Treadmills are bought with Money. The new one replaces the old one in front of your base.
-- A treadmill does not give Speed XP by itself: it multiplies the XP your costume gives per second
-- (a costume with 10 XP/s on a x2 treadmill earns 20 XP/s while you run on it).
Config.Treadmills = {
	{ Name = "Rusty Treadmill", Price = 0, XpMultiplier = 1, Color = Color3.fromRGB(110, 90, 80) },
	{ Name = "Wooden Treadmill", Price = 500, XpMultiplier = 2, Color = Color3.fromRGB(130, 85, 45) },
	{ Name = "Iron Treadmill", Price = 3000, XpMultiplier = 3, Color = Color3.fromRGB(120, 125, 135) },
	{ Name = "Pumpkin Treadmill", Price = 15000, XpMultiplier = 5, Color = Color3.fromRGB(255, 120, 0) },
	{ Name = "Bone Treadmill", Price = 80000, XpMultiplier = 8, Color = Color3.fromRGB(230, 225, 200) },
	{ Name = "Ghostly Treadmill", Price = 500000, XpMultiplier = 13, Color = Color3.fromRGB(170, 230, 255) },
	{ Name = "Cursed Treadmill", Price = 3000000, XpMultiplier = 21, Color = Color3.fromRGB(140, 40, 200) },
}

-- Trails: bought with Money in the Speed Shop's Trails tab. You keep every trail you buy and equip one.
-- A trail multiplies your Speed XP (a costume rate of 30 XP/s with a 1.5x trail gives 45 XP/s),
-- stacks with the rebirth multiplier, and shows as a glowing trail behind you.
Config.Trails = {
	{ Name = "Candle Smoke", Price = 1500, Multiplier = 1.5, Color = Color3.fromRGB(200, 190, 180) },
	{ Name = "Bat Swarm", Price = 15000, Multiplier = 2, Color = Color3.fromRGB(120, 60, 200) },
	{ Name = "Candy Sparkle", Price = 120000, Multiplier = 3, Color = Color3.fromRGB(255, 120, 200) },
	{ Name = "Blood Moon", Price = 900000, Multiplier = 4, Color = Color3.fromRGB(230, 30, 50) },
	{ Name = "Nightmare Shadow", Price = 6000000, Multiplier = 5, Color = Color3.fromRGB(60, 0, 90) },
}
function Config.TrailMultiplier(trail: number?): number
	local info = trail and Config.Trails[trail]
	return if info then info.Multiplier else 1
end

---------------------------------------------------------------------------
-- Costumes: bought with Candy. Better houses only give Candy to good enough costumes (Tier).
--   CandyMultiplier: multiplies the Candy you get from every Trick-or-Treat knock (the first costume is x2).
--   XpPerSecond: the Speed XP per second you earn while running (anywhere; a treadmill multiplies it).
-- "None" is what a brand-new player wears: x1 Candy and the lowest XP rate.
---------------------------------------------------------------------------
Config.Costumes = {
	{ Id = "None", Name = "No Costume", Tier = 0, Price = 0, CandyMultiplier = 1, XpPerSecond = 1, Color = Color3.fromRGB(200, 200, 200) },
	{ Id = "Ghost", Name = "Bedsheet Ghost", Tier = 1, Price = 100, CandyMultiplier = 2, XpPerSecond = 1.5, Attach = "Body", ArtSize = 5.8, Color = Color3.fromRGB(245, 245, 255) },
	{ Id = "Pumpkin", Name = "Pumpkin Head", Tier = 2, Price = 400, CandyMultiplier = 3, XpPerSecond = 2.5, Attach = "Head", ArtSize = 2.6, Color = Color3.fromRGB(255, 140, 0) },
	{ Id = "Witch", Name = "Witch", Tier = 3, Price = 1500, CandyMultiplier = 4, XpPerSecond = 4, Attach = "Hat", ArtSize = 2.8, Color = Color3.fromRGB(60, 140, 60) },
	{ Id = "Vampire", Name = "Vampire", Tier = 4, Price = 6000, CandyMultiplier = 6, XpPerSecond = 7, Attach = "Back", ArtSize = 4.6, Color = Color3.fromRGB(140, 0, 25) },
	{ Id = "Skeleton", Name = "Glowing Skeleton", Tier = 5, Price = 24000, CandyMultiplier = 8, XpPerSecond = 12, Attach = "Head", ArtSize = 2.5, Color = Color3.fromRGB(230, 255, 200) },
	{ Id = "Werewolf", Name = "Werewolf", Tier = 6, Price = 90000, CandyMultiplier = 12, XpPerSecond = 20, Attach = "Head", ArtSize = 2.9, Color = Color3.fromRGB(100, 70, 50) },
	{ Id = "Reaper", Name = "Grim Reaper", Tier = 7, Price = 300000, CandyMultiplier = 16, XpPerSecond = 35, Attach = "Body", ArtSize = 6.2, Color = Color3.fromRGB(25, 25, 30) },
	{ Id = "Mummy", Name = "Mummy", Tier = 8, Price = 1000000, CandyMultiplier = 24, XpPerSecond = 60, Attach = "Body", ArtSize = 6, Color = Color3.fromRGB(225, 215, 180) },
	{ Id = "Frankenstein", Name = "Frankenstein", Tier = 9, Price = 2500000, CandyMultiplier = 32, XpPerSecond = 100, Attach = "Head", ArtSize = 2.8, Color = Color3.fromRGB(90, 150, 70) },
	{ Id = "Devil", Name = "Red Devil", Tier = 10, Price = 5000000, CandyMultiplier = 50, XpPerSecond = 170, Attach = "Body", ArtSize = 6.2, Color = Color3.fromRGB(200, 25, 25) },
}

-- A brand-new player starts with exactly enough Candy for the cheapest costume (the tutorial sends them to buy it).
Config.StartingData.Candy = Config.Costumes[2].Price

function Config.GetCostume(id: string)
	for _, costume in Config.Costumes do
		if costume.Id == id then
			return costume
		end
	end
	return Config.Costumes[1]
end

-- True for a player who has never owned a costume: they get the first-time tutorial and spawn at the Costume Shop.
function Config.NeedsTutorial(data: { [string]: any }): boolean
	return #data.OwnedCostumes <= 1
end

-- Speed XP per second for a player's data. The base rate comes from the equipped costume; running on a
-- treadmill multiplies it by that treadmill's XpMultiplier; rebirths and the equipped trail multiply it too.
function Config.XpRateFor(data: { [string]: any }, onTreadmill: boolean): number
	local rate = Config.GetCostume(data.EquippedCostume).XpPerSecond
	if onTreadmill then
		local treadmill = Config.Treadmills[data.Treadmill] or Config.Treadmills[1]
		rate *= treadmill.XpMultiplier
	end
	return rate * Config.XpMultiplier(data.Rebirths) * Config.TrailMultiplier(data.Trail)
end

-- What owners say when your costume is not good enough.
Config.CostumeRoasts = {
	"And you call this a costume? I'm not giving you my candy!",
	"Nice try. Come back when you actually dress up!",
	"That's it? My cat has a scarier costume.",
	"No costume, no candy. Rules are rules!",
	"Is that a costume or did you just wake up?",
	"I've seen scarier things in my fridge. Shoo!",
	"You call that spooky? My grandma wears scarier pajamas!",
	"Come back when you're less... boring.",
	"Wow, you really put in zero effort. Respect. Now go away!",
	"My doorbell is scarier than you. Bye!",
}

-- What an owner says when your costume is good enough.
Config.TreatGreetings = {
	"Happy Halloween!",
	"Ooh, what a spooky costume! Happy Halloween!",
	"Now THAT is a costume! Here, take some candy!",
	"Happy Halloween, little monster!",
	"Boo! Scary stuff! Have some treats!",
	"Fantastic costume! Happy Halloween!",
}

---------------------------------------------------------------------------
-- Rarities
---------------------------------------------------------------------------
Config.Rarities = {
	Common = { Order = 1, Color = Color3.fromRGB(190, 190, 190) },
	Uncommon = { Order = 2, Color = Color3.fromRGB(90, 220, 90) },
	Rare = { Order = 3, Color = Color3.fromRGB(70, 140, 255) },
	Epic = { Order = 4, Color = Color3.fromRGB(180, 80, 255) },
	Legendary = { Order = 5, Color = Color3.fromRGB(255, 190, 40) },
	Mythic = { Order = 6, Color = Color3.fromRGB(255, 60, 90) },
	Secret = { Order = 7, Color = Color3.fromRGB(20, 255, 220) },
	-- Level pets have no tier: the label is their level's place, and better pets just earn more.
	Swamp = { Order = 1, Color = Color3.fromRGB(120, 220, 90) },
	Pyramid = { Order = 2, Color = Color3.fromRGB(240, 200, 100) },
	Harvest = { Order = 3, Color = Color3.fromRGB(255, 150, 40) },
	Bakery = { Order = 4, Color = Color3.fromRGB(232, 141, 160) },
}

---------------------------------------------------------------------------
-- Pets: hatched from eggs, placed on the base, earn Money per second.
---------------------------------------------------------------------------
Config.Pets = {
	CroissantBat = { Name = "Croissant Bat", Rarity = "Bakery", MoneyPerSecond = 300, Color = Color3.fromRGB(221, 155, 76) },
	CupcakeGhost = { Name = "Cupcake Ghost", Rarity = "Bakery", MoneyPerSecond = 380, Color = Color3.fromRGB(227, 200, 236) },
	DonutSpider = { Name = "Doughnut Spider", Rarity = "Bakery", MoneyPerSecond = 500, Color = Color3.fromRGB(232, 141, 160) },
	GingerbreadZombie = { Name = "Gingerbread Zombie", Rarity = "Bakery", MoneyPerSecond = 700, Color = Color3.fromRGB(128, 187, 160) },
	Bat = { Name = "Bat", Rarity = "Common", MoneyPerSecond = 1, Color = Color3.fromRGB(60, 50, 70) },
	Spider = { Name = "Candy Spider", Rarity = "Uncommon", MoneyPerSecond = 4, Color = Color3.fromRGB(120, 40, 160) },
	Pumpkling = { Name = "Pumpkling", Rarity = "Uncommon", MoneyPerSecond = 6, Color = Color3.fromRGB(255, 130, 0) },
	CandyCorn = { Name = "Candy Corn Critter", Rarity = "Rare", MoneyPerSecond = 15, Color = Color3.fromRGB(255, 220, 60) },
	VampBat = { Name = "Vampire Bat", Rarity = "Rare", MoneyPerSecond = 22, Color = Color3.fromRGB(120, 0, 30) },
	Zombie = { Name = "Zombie Pup", Rarity = "Rare", MoneyPerSecond = 32, Color = Color3.fromRGB(110, 160, 90) },
	Tralalero = { Name = "Tralalero Tralala", Rarity = "Epic", MoneyPerSecond = 65, Color = Color3.fromRGB(80, 170, 255) },
	Ghosty = { Name = "Ghosty", Rarity = "Epic", MoneyPerSecond = 90, Color = Color3.fromRGB(230, 240, 255) },
	Wraith = { Name = "Wraith", Rarity = "Epic", MoneyPerSecond = 130, Color = Color3.fromRGB(90, 90, 140) },
	TungTung = { Name = "Tung Tung Tung Sahur", Rarity = "Legendary", MoneyPerSecond = 260, Color = Color3.fromRGB(170, 120, 70) },
	Werewolf = { Name = "Mini Werewolf", Rarity = "Legendary", MoneyPerSecond = 380, Color = Color3.fromRGB(110, 80, 60) },
	Bombardiro = { Name = "Bombardiro Crocodilo", Rarity = "Legendary", MoneyPerSecond = 620, Color = Color3.fromRGB(70, 120, 60) },
	BloodBat = { Name = "Blood Moon Bat", Rarity = "Mythic", MoneyPerSecond = 1000, Color = Color3.fromRGB(200, 20, 40) },
	LichCat = { Name = "Lich Cat", Rarity = "Mythic", MoneyPerSecond = 1600, Color = Color3.fromRGB(80, 255, 170) },
	Ballerina = { Name = "Ballerina Cappuccina", Rarity = "Mythic", MoneyPerSecond = 2600, Color = Color3.fromRGB(255, 170, 200) },
	ShadowClown = { Name = "Shadow Clown", Rarity = "Mythic", MoneyPerSecond = 4000, Color = Color3.fromRGB(40, 0, 60) },
	HeadlessHorse = { Name = "Headless Horseman", Rarity = "Secret", MoneyPerSecond = 8000, Color = Color3.fromRGB(40, 0, 0) },
	PumpkinKing = { Name = "Pumpkin King", Rarity = "Secret", MoneyPerSecond = 15000, Color = Color3.fromRGB(255, 90, 0) },

	-- Level 1: the Old Witch's swamp.
	BogToad = { Name = "Bog Toad", Rarity = "Swamp", MoneyPerSecond = 3, Color = Color3.fromRGB(90, 130, 60) },
	BlackCat = { Name = "Black Cat", Rarity = "Swamp", MoneyPerSecond = 4, Color = Color3.fromRGB(20, 20, 20) },
	MushroomImp = { Name = "Mushroom Imp", Rarity = "Swamp", MoneyPerSecond = 5, Color = Color3.fromRGB(200, 60, 60) },
	CauldronSlime = { Name = "Cauldron Slime", Rarity = "Swamp", MoneyPerSecond = 7, Color = Color3.fromRGB(120, 255, 80) },
	HexedOwl = { Name = "Hexed Owl", Rarity = "Swamp", MoneyPerSecond = 11, Color = Color3.fromRGB(110, 70, 160) },
	-- Level 2: the Friendly Mummy's pyramid.
	SandScarab = { Name = "Sand Scarab", Rarity = "Pyramid", MoneyPerSecond = 15, Color = Color3.fromRGB(40, 140, 150) },
	Camel = { Name = "Camel", Rarity = "Pyramid", MoneyPerSecond = 20, Color = Color3.fromRGB(205, 165, 105) },
	CanopicJar = { Name = "Canopic Jar Critter", Rarity = "Pyramid", MoneyPerSecond = 25, Color = Color3.fromRGB(225, 205, 160) },
	MiniSphinx = { Name = "Mini Sphinx", Rarity = "Pyramid", MoneyPerSecond = 35, Color = Color3.fromRGB(230, 190, 110) },
	AnubisPup = { Name = "Anubis Pup", Rarity = "Pyramid", MoneyPerSecond = 55, Color = Color3.fromRGB(30, 30, 40) },
	-- Level 3: the Scarecrow's harvest barn.
	HayMouse = { Name = "Hay Mouse", Rarity = "Harvest", MoneyPerSecond = 70, Color = Color3.fromRGB(170, 150, 130) },
	Crow = { Name = "Scarecrow Crow", Rarity = "Harvest", MoneyPerSecond = 90, Color = Color3.fromRGB(30, 30, 35) },
	CiderRaccoon = { Name = "Cider Barrel Raccoon", Rarity = "Harvest", MoneyPerSecond = 115, Color = Color3.fromRGB(120, 110, 100) },
	LanternMoth = { Name = "Lantern Moth", Rarity = "Harvest", MoneyPerSecond = 160, Color = Color3.fromRGB(255, 200, 90) },
	StrawGolem = { Name = "Straw Golem", Rarity = "Harvest", MoneyPerSecond = 250, Color = Color3.fromRGB(220, 180, 80) },
}

---------------------------------------------------------------------------
-- Egg variants. Every egg rolls two separate things, and one result never changes the other, so an egg can
-- have both (a Big Diamond egg), only one (a Gigantic egg, a Rainbow egg) or neither:
--   Size:     Big, Huge or Gigantic. The egg and the pet grow.
--   Material: Golden, Diamond or Rainbow. The egg and the pet glow.
-- Chance is the share of all eggs that get that tier (the rest get none). Multipliers stack: a pet's Money per
-- second = its normal income x Size multiplier x Material multiplier.
-- A variant pet is stored as "<PetId>+<Size>+<Material>", for example "Bat+Big+Golden", "Bat+Huge" or
-- "Bat+Rainbow". Config.Pets understands those ids too, so scripts that look a pet up by id need no changes;
-- use Config.SplitPet when you need the plain pet id (art, Index).
---------------------------------------------------------------------------
-- EggScale / PetScale: how big the egg and the pet are drawn compared with the normal size. A normal egg is
-- drawn at DefaultEggScale (smaller than before) so a Big egg is clearly bigger next to it. Normal pets keep
-- their size (1); variant pets grow by PetScale.
Config.DefaultEggScale = 0.7
Config.Sizes = {
	Big = { Name = "Big", Chance = 0.20, Multiplier = 3, EggScale = 1.56, PetScale = 1.6 },
	Huge = { Name = "Huge", Chance = 0.04, Multiplier = 8, EggScale = 1.89, PetScale = 2.1 },
	Gigantic = { Name = "Gigantic", Chance = 0.005, Multiplier = 30, EggScale = 2.34, PetScale = 2.8 },
}
Config.Materials = {
	Golden = { Name = "Golden", Chance = 0.15, Multiplier = 3, Color = Color3.fromRGB(255, 205, 50) },
	Diamond = { Name = "Diamond", Chance = 0.05, Multiplier = 8, Color = Color3.fromRGB(120, 230, 255) },
	Rainbow = { Name = "Rainbow", Chance = 0.01, Multiplier = 25, Color = Color3.fromRGB(255, 120, 200) }, -- cycles through every colour
}
local SIZE_ORDER = { "Gigantic", "Huge", "Big" } -- rarest first
local MATERIAL_ORDER = { "Rainbow", "Diamond", "Golden" }

local function rollTier(pool, order: { string }): string?
	local roll = math.random()
	for _, name in order do
		roll -= pool[name].Chance
		if roll < 0 then
			return name
		end
	end
	return nil
end

-- Rolls a freshly spawned egg's size and material: (size or nil, material or nil).
function Config.RollVariant(): (string?, string?)
	return rollTier(Config.Sizes, SIZE_ORDER), rollTier(Config.Materials, MATERIAL_ORDER)
end

-- "Bat+Big+Golden" -> "Bat", "Big", "Golden". A plain id gives (id, nil, nil).
function Config.SplitPet(id: string): (string, string?, string?)
	local parts = string.split(id, "+")
	local size, material
	for i = 2, #parts do
		local token = parts[i]
		if Config.Sizes[token] and not size then
			size = token
		elseif Config.Materials[token] and not material then
			material = token
		else
			return id, nil, nil -- not a valid variant id
		end
	end
	return parts[1], size, material
end

function Config.MakePetId(baseId: string, size: string?, material: string?): string
	local id = baseId
	if size then
		id ..= "+" .. size
	end
	if material then
		id ..= "+" .. material
	end
	return id
end

local variantPets = {}
setmetatable(Config.Pets, {
	__index = function(_, id)
		if type(id) ~= "string" then
			return nil
		end
		local cached = variantPets[id]
		if cached then
			return cached
		end
		local baseId, size, material = Config.SplitPet(id)
		local base = rawget(Config.Pets, baseId)
		if not base or not (size or material) then
			return nil
		end
		local sizeInfo = size and Config.Sizes[size]
		local materialInfo = material and Config.Materials[material]
		local info = table.clone(base)
		info.Name = (if sizeInfo then sizeInfo.Name .. " " else "") .. (if materialInfo then materialInfo.Name .. " " else "") .. base.Name
		info.MoneyPerSecond = base.MoneyPerSecond * (if sizeInfo then sizeInfo.Multiplier else 1) * (if materialInfo then materialInfo.Multiplier else 1)
		info.BaseId = baseId
		info.Size = size
		info.Material = material
		info.Scale = if sizeInfo then sizeInfo.PetScale else 1
		variantPets[id] = info
		return info
	end,
})

-- Index order: every pet, weakest first.
Config.PetOrder = {}
for petId in Config.Pets do
	table.insert(Config.PetOrder, petId)
end
table.sort(Config.PetOrder, function(a, b)
	return Config.Pets[a].MoneyPerSecond < Config.Pets[b].MoneyPerSecond
end)

-- Index milestones: Money for discovering this many different pets.
Config.IndexRewards = {
	{ Count = 5, Money = 45000 },
	{ Count = 10, Money = 750000 },
	{ Count = 15, Money = 12000000 },
	{ Count = 20, Money = 135000000 },
}

---------------------------------------------------------------------------
-- Eggs: stolen from houses, hatched for free at your base. Rarer = bigger, slower to carry, longer to hatch.
-- Pool weights are relative; they do not need to add up to 100.
---------------------------------------------------------------------------
Config.Eggs = {
	BakeryEgg = { Name = "Bakery Egg", Rarity = "Bakery", HatchSeconds = 90, Size = 3, CarrySpeed = 0.90, Color = Color3.fromRGB(232, 141, 160),
		Pool = { { Pet = "CroissantBat", Weight = 40 }, { Pet = "CupcakeGhost", Weight = 30 }, { Pet = "DonutSpider", Weight = 20 }, { Pet = "GingerbreadZombie", Weight = 10 } } },
	-- Level eggs: houses 1-3 drop only their own egg. Cheaper pets hatch more often.
	SwampEgg = {
		Name = "Swamp Egg", Rarity = "Swamp", HatchSeconds = 10, Size = 2, CarrySpeed = 0.95,
		Color = Color3.fromRGB(110, 170, 70),
		Pool = { { Pet = "BogToad", Weight = 35 }, { Pet = "BlackCat", Weight = 27 }, { Pet = "MushroomImp", Weight = 20 }, { Pet = "CauldronSlime", Weight = 12 }, { Pet = "HexedOwl", Weight = 6 } },
	},
	PyramidEgg = {
		Name = "Pyramid Egg", Rarity = "Pyramid", HatchSeconds = 30, Size = 2.4, CarrySpeed = 0.93,
		Color = Color3.fromRGB(230, 190, 110),
		Pool = { { Pet = "SandScarab", Weight = 35 }, { Pet = "Camel", Weight = 27 }, { Pet = "CanopicJar", Weight = 20 }, { Pet = "MiniSphinx", Weight = 12 }, { Pet = "AnubisPup", Weight = 6 } },
	},
	HarvestEgg = {
		Name = "Harvest Egg", Rarity = "Harvest", HatchSeconds = 60, Size = 2.8, CarrySpeed = 0.91,
		Color = Color3.fromRGB(255, 150, 40),
		Pool = { { Pet = "HayMouse", Weight = 35 }, { Pet = "Crow", Weight = 27 }, { Pet = "CiderRaccoon", Weight = 20 }, { Pet = "LanternMoth", Weight = 12 }, { Pet = "StrawGolem", Weight = 6 } },
	},
	CandyEgg = {
		Name = "Candy Egg", Rarity = "Common", HatchSeconds = 10, Size = 2, CarrySpeed = 0.95,
		Color = Color3.fromRGB(255, 180, 200),
		Pool = { { Pet = "Bat", Weight = 85 }, { Pet = "Spider", Weight = 15 } },
	},
	PumpkinEgg = {
		Name = "Pumpkin Egg", Rarity = "Uncommon", HatchSeconds = 30, Size = 2.4, CarrySpeed = 0.93,
		Color = Color3.fromRGB(255, 140, 20),
		Pool = { { Pet = "Pumpkling", Weight = 85 }, { Pet = "CandyCorn", Weight = 15 } },
	},
	BatEgg = {
		Name = "Bat Egg", Rarity = "Rare", HatchSeconds = 120, Size = 2.8, CarrySpeed = 0.91,
		Color = Color3.fromRGB(70, 60, 110),
		Pool = { { Pet = "VampBat", Weight = 55 }, { Pet = "Zombie", Weight = 35 }, { Pet = "Tralalero", Weight = 10 } },
	},
	GhostEgg = {
		Name = "Ghost Egg", Rarity = "Epic", HatchSeconds = 300, Size = 3.3, CarrySpeed = 0.89,
		Color = Color3.fromRGB(210, 230, 255),
		Pool = { { Pet = "Ghosty", Weight = 55 }, { Pet = "Wraith", Weight = 35 }, { Pet = "TungTung", Weight = 10 } },
	},
	MoonEgg = {
		Name = "Blood Moon Egg", Rarity = "Legendary", HatchSeconds = 900, Size = 3.8, CarrySpeed = 0.87,
		Color = Color3.fromRGB(200, 30, 50),
		Pool = { { Pet = "Werewolf", Weight = 55 }, { Pet = "Bombardiro", Weight = 35 }, { Pet = "BloodBat", Weight = 10 } },
	},
	CursedEgg = {
		Name = "Cursed Egg", Rarity = "Mythic", HatchSeconds = 1800, Size = 4.4, CarrySpeed = 0.85,
		Color = Color3.fromRGB(140, 60, 220),
		Pool = { { Pet = "LichCat", Weight = 50 }, { Pet = "Ballerina", Weight = 35 }, { Pet = "ShadowClown", Weight = 15 } },
	},
	NightmareEgg = {
		Name = "Nightmare Egg", Rarity = "Secret", HatchSeconds = 3600, Size = 5, CarrySpeed = 0.82,
		Color = Color3.fromRGB(10, 10, 10),
		Pool = { { Pet = "HeadlessHorse", Weight = 70 }, { Pet = "PumpkinKing", Weight = 30 } },
	},
}

-- Eggs in the bag are stored as "EggId|PetId". Old saves may have just "EggId" (pet rolled at hatch).
function Config.MakeEggEntry(eggId: string, petId: string?): string
	return if petId then eggId .. "|" .. petId else eggId
end

function Config.ParseEgg(entry: string): (string, string?)
	local eggId, petId = string.match(entry, "^([^|]+)|(.+)$")
	if eggId then
		return eggId, petId
	end
	return entry, nil
end

---------------------------------------------------------------------------
-- The street: 9 houses, each one its own level. House 1 is next to the bases, house 9 is the far end.
-- Floors: 1 or 2. Scale: house size multiplier. EggCount: eggs spawned inside each night.
-- CostumeTier: the minimum costume tier that gets Candy at the door.
---------------------------------------------------------------------------
Config.Houses = {
	{ Owner = "Old Witch", OwnerSpeed = 20, CandyPerKnock = 5, CostumeTier = 0, Floors = 1, Scale = 1.0, EggCount = 4,
		EggWeights = { SwampEgg = 100 } },
	{ Owner = "Friendly Mummy", OwnerSpeed = 41, CandyPerKnock = 10, CostumeTier = 0, Floors = 1, Scale = 1.05, EggCount = 4,
		EggWeights = { PyramidEgg = 100 } },
	{ Owner = "Scarecrow", OwnerSpeed = 56, CandyPerKnock = 20, CostumeTier = 1, Floors = 1, Scale = 1.1, EggCount = 5,
		EggWeights = { HarvestEgg = 100 } },
	{ Owner = "Zombie Chef", OwnerSpeed = 75, CandyPerKnock = 40, CostumeTier = 2, Floors = 2, Scale = 1.15, EggCount = 5,
		EggWeights = { BakeryEgg = 100 } },
	{ Owner = "Gravedigger", OwnerSpeed = 87, CandyPerKnock = 80, CostumeTier = 3, Floors = 1, Scale = 1.2, EggCount = 5,
		EggWeights = { PumpkinEgg = 20, BatEgg = 45, GhostEgg = 30, MoonEgg = 5 } },
	{ Owner = "Count Vlad", OwnerSpeed = 91, CandyPerKnock = 160, CostumeTier = 4, Floors = 2, Scale = 1.25, EggCount = 6,
		EggWeights = { BatEgg = 40, GhostEgg = 40, MoonEgg = 18, CursedEgg = 2 } },
	{ Owner = "Banshee", OwnerSpeed = 108, CandyPerKnock = 320, CostumeTier = 5, Floors = 2, Scale = 1.3, EggCount = 6,
		EggWeights = { BatEgg = 20, GhostEgg = 45, MoonEgg = 30, CursedEgg = 5 } },
	{ Owner = "Headless Horseman", OwnerSpeed = 128, CandyPerKnock = 650, CostumeTier = 6, Floors = 2, Scale = 1.35, EggCount = 6,
		EggWeights = { GhostEgg = 40, MoonEgg = 40, CursedEgg = 18, NightmareEgg = 2 } },
	{ Owner = "Lich King", OwnerSpeed = 148, CandyPerKnock = 1300, CostumeTier = 7, Floors = 2, Scale = 1.45, EggCount = 6,
		EggWeights = { GhostEgg = 20, MoonEgg = 45, CursedEgg = 30, NightmareEgg = 5 } },
}

---------------------------------------------------------------------------
-- House interaction timings
---------------------------------------------------------------------------
Config.TrickOrTreatCooldown = 20 -- seconds, per player per house
Config.StealHoldDuration = 1 -- seconds holding the prompt
Config.ChaseMaxDuration = 30 -- owner gives up after this long
Config.ChaseGiveUpDistance = 150 -- owner gives up if the thief gets this far ahead
Config.CatchDistance = 5 -- studs between owner and thief that counts as caught
-- No cutting off: if the owner is nearer to the thief's base than the thief is (and more than InterceptMinDistance
-- away), he first runs to a spot InterceptBehind studs behind the thief and InterceptSide studs to the side, and only then
-- chases normally. A chase only counts its time and give-up distance once the owner is actually after that thief.
Config.InterceptMinDistance = 18
Config.InterceptBehind = 22
Config.InterceptSide = 14
Config.InterceptMaxSeconds = 8 -- never stays in this mode longer than this
Config.OwnerReaction = 0.8 -- seconds the owner needs to notice a thief before he starts running
Config.OwnerReactionPerRarity = 0.2 -- extra seconds per egg rarity step (Common = 1 step, Secret = 7): rarer eggs give a bigger head start
Config.CaughtStunTime = 1.5 -- seconds the thief is slowed after being caught
Config.KickDistance = 100 -- studs a caught thief is kicked away from the owner
Config.KickAngle = 35 -- degrees above the ground the kick launches the thief (a higher angle flies higher and lasts longer)

---------------------------------------------------------------------------
-- Playtest tools: these Roblox user ids (plus the game's creator, plus everyone inside Studio) see the Admin panel
-- (F2 or the ADMIN button). Add a friend's UserId to let them test too.
---------------------------------------------------------------------------
Config.AdminUserIds = {} -- e.g. { 12345678, 87654321 }

-- Global boards in the hub: how often scores are saved and the boards redrawn.
Config.BoardRefreshSeconds = 90

---------------------------------------------------------------------------
-- Audio. The files are made by tools/make_audio.py into audio/ (see audio/README.md). Upload them to Roblox
-- and paste each id into `Id` ("rbxassetid://123456" or just the number). An empty Id plays the Fallback (a
-- sound that ships with Roblox) or nothing. Volume is 0 to 1 and multiplies the player's sound setting.
---------------------------------------------------------------------------
Config.Audio = {
	Music = {
		Chill = { Id = "104408838738669", File = "music_chill.mp3", Volume = 0.45 }, -- slow spooky waltz, always playing
		Chase = { Id = "84750268429068", File = "music_chase.mp3", Volume = 0.7 }, -- replaces it while an owner chases you
	},
	Sfx = {
		Click = { Id = "90777076070251", File = "ui_click.mp3", Volume = 0.6, Fallback = "rbxasset://sounds/clickfast.wav" },
		Hover = { Id = "136773357162673", File = "ui_hover.mp3", Volume = 0.25 },
		Open = { Id = "112378718438149", File = "ui_open.mp3", Volume = 0.5 },
		Close = { Id = "140705850204002", File = "ui_close.mp3", Volume = 0.45 },
		Buy = { Id = "111698847950410", File = "ui_buy.mp3", Volume = 0.7, Fallback = "rbxasset://sounds/electronicpingshort.wav" },
		Error = { Id = "112807538408601", File = "ui_error.mp3", Volume = 0.6, Fallback = "rbxasset://sounds/bass.wav" },
		Notify = { Id = "140436292459203", File = "ui_notify.mp3", Volume = 0.45 },
		Candy = { Id = "136234586640642", File = "ui_candy.mp3", Volume = 0.5 },
		LevelUp = { Id = "70844323367904", File = "ui_levelup.mp3", Volume = 0.7 },
		Fanfare = { Id = "102746230510443", File = "fanfare.mp3", Volume = 0.8 },
		EggPickup = { Id = "117400458549929", File = "egg_pickup.mp3", Volume = 0.7 },
		EggPlace = { Id = "113778628585626", File = "egg_place.mp3", Volume = 0.6 },
		EggHatch = { Id = "138241628258698", File = "egg_hatch.mp3", Volume = 0.8 },
		ChaseAlert = { Id = "138434141721230", File = "chase_alert.mp3", Volume = 0.8 },
		Escape = { Id = "110374782293236", File = "escape.mp3", Volume = 0.8 },
		Caught = { Id = "110987063379359", File = "caught.mp3", Volume = 0.8 },
		Kick = { Id = "88984337474065", File = "kick.mp3", Volume = 1.2, Fallback = "rbxasset://sounds/Kickhit.wav" },
		Grunt = { Id = "", Volume = 0.9, Fallback = "rbxasset://sounds/uuhhh.mp3" },
		Knock = { Id = "131329535742082", File = "knock.mp3", Volume = 1 },
		DoorCreak = { Id = "137180994933404", File = "door_creak.mp3", Volume = 0.8 },
		Whoosh = { Id = "73038656223943", File = "whoosh.mp3", Volume = 0.5 },
	},
}

-- The sound id to play for a Config.Audio.Sfx name: the uploaded id, else the fallback, else nil.
function Config.SfxId(name: string): string?
	local info = Config.Audio.Sfx[name]
	if not info then
		return nil
	end
	local id: string = info.Id
	if id ~= "" then
		return if string.match(id, "^%d+$") then "rbxassetid://" .. id else id
	end
	return info.Fallback
end
Config.MaxEggsHeld = 12 -- unhatched egg inventory cap
Config.IncubatorSlots = 2 -- hatching pads on a new base
Config.MaxPetsOnBase = 6 -- pet slots on a new base
Config.MaxPetsStored = 60 -- inventory cap for pets that are not equipped
Config.FriendBoostPercent = 10 -- extra pet Money for every friend playing in the same server

---------------------------------------------------------------------------
-- Base upgrades: two separate upgrades, both bought with Money at their own sign by the base entrance.
--   Pet Capacity: how many pets can stand on the base (starts at Config.MaxPetsOnBase).
--   Hatching Pads: how many eggs can hatch at once (starts at Config.IncubatorSlots).
-- Each upgrade changes only its own capacity. Pet Capacity also makes the pet courtyard Config.BaseDepthStep
-- studs deeper; Hatching Pads add pedestals and, from the fifth pad, a second row under a longer roof.
---------------------------------------------------------------------------
Config.BaseDepth = 40 -- depth of a new base (studs, front to back)
Config.BaseDepthStep = 10
Config.PetCapacityUpgrades = {
	{ Price = 2000, Capacity = 9 },
	{ Price = 30000, Capacity = 12 },
	{ Price = 500000, Capacity = 15 },
	{ Price = 8000000, Capacity = 18 },
}
Config.HatchPadUpgrades = {
	{ Price = 5000, Capacity = 3 },
	{ Price = 60000, Capacity = 4 },
	{ Price = 700000, Capacity = 5 },
	{ Price = 8000000, Capacity = 6 },
	{ Price = 90000000, Capacity = 7 },
}

-- Eggs that can hatch at once, with this many Hatching Pad upgrades.
function Config.IncubatorsFor(padLevel: number?): number
	local upgrade = Config.HatchPadUpgrades[padLevel or 0]
	return if upgrade then upgrade.Capacity else Config.IncubatorSlots
end

-- Pets that can stand on the base, with this many Pet Capacity upgrades.
function Config.PetSlotsFor(petCapLevel: number?): number
	local upgrade = Config.PetCapacityUpgrades[petCapLevel or 0]
	return if upgrade then upgrade.Capacity else Config.MaxPetsOnBase
end

-- The most a base can ever hold (the "+N locked" hint in the Pets menu uses these).
function Config.MaxPetSlots(): number
	return Config.PetCapacityUpgrades[#Config.PetCapacityUpgrades].Capacity
end

Config.IncomeTickSeconds = 1
Config.PetSellSeconds = 30 -- selling a pet pays this many seconds of its income

return Config
