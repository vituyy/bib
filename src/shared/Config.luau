-- Central game balance. Tweak numbers here; every server and client script reads from this module.

local Config = {}

Config.DataStoreName = "SpookySteal_PlayerData_v2"
Config.AutosaveInterval = 120 -- seconds
Config.MaxPlayers = 5 -- one base per player (set the same number in Game Settings > Places)

Config.StartingData = {
	Candy = 0,
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
	BaseLevel = 0, -- base upgrades bought (0 to #Config.BaseUpgrades)
	Discovered = {}, -- pet ids hatched at least once (the Index)
	IndexClaimed = {}, -- Index milestone counts already claimed (5, 10, 15, 20)
}

---------------------------------------------------------------------------
-- Day / night. Houses are only open at night; every egg respawns when night starts.
---------------------------------------------------------------------------
Config.NightSeconds = 300
Config.DaySeconds = 10

---------------------------------------------------------------------------
-- Player speed: run on a treadmill for XP, each Speed Level makes you faster.
-- Speed grows exponentially so maxed players look (and are) way faster than new ones.
---------------------------------------------------------------------------
Config.BaseWalkSpeed = 16 -- Roblox default walk speed; new players start here
Config.SpeedBonus = 0 -- flat extra speed on top of the curve
Config.SpeedGrowth = 1.0185 -- walk speed multiplier per Speed Level (about 100 speed at level 100)
Config.MaxSpeedLevel = 100

function Config.WalkSpeedFor(speedLevel: number): number
	return math.floor(Config.BaseWalkSpeed * Config.SpeedGrowth ^ speedLevel + 0.5) + Config.SpeedBonus
end

-- XP needed to reach each Speed Level: XP_TO_REACH[1] is the cost of level 1.
-- Past the table, each level costs floor(level / 4) more than the one before.
local XP_TO_REACH = { 5, 6, 7, 8, 10, 12, 14, 16, 18, 20, 22, 25 }
for level = #XP_TO_REACH + 1, 100 do
	XP_TO_REACH[level] = XP_TO_REACH[level - 1] + math.floor(level / 4)
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

-- Bought with Candy. The new one replaces the old one in front of your base.
Config.Treadmills = {
	{ Name = "Rusty Treadmill", Price = 0, XpPerSecond = 1, Color = Color3.fromRGB(110, 90, 80) },
	{ Name = "Wooden Treadmill", Price = 50, XpPerSecond = 2, Color = Color3.fromRGB(130, 85, 45) },
	{ Name = "Iron Treadmill", Price = 250, XpPerSecond = 4, Color = Color3.fromRGB(120, 125, 135) },
	{ Name = "Pumpkin Treadmill", Price = 1200, XpPerSecond = 8, Color = Color3.fromRGB(255, 120, 0) },
	{ Name = "Bone Treadmill", Price = 6000, XpPerSecond = 16, Color = Color3.fromRGB(230, 225, 200) },
	{ Name = "Ghostly Treadmill", Price = 30000, XpPerSecond = 32, Color = Color3.fromRGB(170, 230, 255) },
	{ Name = "Cursed Treadmill", Price = 150000, XpPerSecond = 64, Color = Color3.fromRGB(140, 40, 200) },
}

-- Trails: bought with Money in the Speed Shop's Trails tab. You keep every trail you buy and equip one.
-- A trail multiplies treadmill Speed XP (a 30 XP/s treadmill with a 1.5x trail gives 45 XP/s),
-- stacks with the rebirth multiplier, and shows as a glowing trail behind you.
Config.Trails = {
	{ Name = "Candle Smoke", Price = 500, Multiplier = 1.25, Color = Color3.fromRGB(200, 190, 180) },
	{ Name = "Bat Swarm", Price = 5000, Multiplier = 1.5, Color = Color3.fromRGB(120, 60, 200) },
	{ Name = "Candy Sparkle", Price = 40000, Multiplier = 2, Color = Color3.fromRGB(255, 120, 200) },
	{ Name = "Ghost Wisp", Price = 250000, Multiplier = 2.5, Color = Color3.fromRGB(200, 240, 255) },
	{ Name = "Pumpkin Fire", Price = 1500000, Multiplier = 3, Color = Color3.fromRGB(255, 130, 20) },
	{ Name = "Blood Moon", Price = 8000000, Multiplier = 4, Color = Color3.fromRGB(230, 30, 50) },
	{ Name = "Nightmare Shadow", Price = 40000000, Multiplier = 5, Color = Color3.fromRGB(60, 0, 90) },
}
function Config.TrailMultiplier(trail: number?): number
	local info = trail and Config.Trails[trail]
	return if info then info.Multiplier else 1
end

---------------------------------------------------------------------------
-- Costumes: bought with Money. Better houses only give Candy to good enough costumes.
-- CandyBonus is the extra Candy per Trick-or-Treat knock, in percent (100 = double Candy).
---------------------------------------------------------------------------
Config.Costumes = {
	{ Id = "None", Name = "No Costume", Tier = 0, Price = 0, CandyBonus = 0, Color = Color3.fromRGB(200, 200, 200) },
	{ Id = "Ghost", Name = "Bedsheet Ghost", Tier = 1, Price = 50, CandyBonus = 10, Attach = "Body", ArtSize = 5.8, Color = Color3.fromRGB(245, 245, 255) },
	{ Id = "Pumpkin", Name = "Pumpkin Head", Tier = 2, Price = 300, CandyBonus = 25, Attach = "Head", ArtSize = 2.6, Color = Color3.fromRGB(255, 140, 0) },
	{ Id = "Witch", Name = "Witch", Tier = 3, Price = 1500, CandyBonus = 50, Attach = "Hat", ArtSize = 2.8, Color = Color3.fromRGB(60, 140, 60) },
	{ Id = "Vampire", Name = "Vampire", Tier = 4, Price = 7500, CandyBonus = 75, Attach = "Back", ArtSize = 4.6, Color = Color3.fromRGB(140, 0, 25) },
	{ Id = "Skeleton", Name = "Glowing Skeleton", Tier = 5, Price = 35000, CandyBonus = 100, Attach = "Head", ArtSize = 2.5, Color = Color3.fromRGB(230, 255, 200) },
	{ Id = "Werewolf", Name = "Werewolf", Tier = 6, Price = 150000, CandyBonus = 150, Attach = "Head", ArtSize = 2.9, Color = Color3.fromRGB(100, 70, 50) },
	{ Id = "Reaper", Name = "Grim Reaper", Tier = 7, Price = 600000, CandyBonus = 200, Attach = "Body", ArtSize = 6.2, Color = Color3.fromRGB(25, 25, 30) },
	{ Id = "Mummy", Name = "Mummy", Tier = 8, Price = 2500000, CandyBonus = 300, Attach = "Body", ArtSize = 6, Color = Color3.fromRGB(225, 215, 180) },
	{ Id = "Frankenstein", Name = "Frankenstein", Tier = 9, Price = 10000000, CandyBonus = 400, Attach = "Head", ArtSize = 2.8, Color = Color3.fromRGB(90, 150, 70) },
	{ Id = "Devil", Name = "Red Devil", Tier = 10, Price = 40000000, CandyBonus = 500, Attach = "Body", ArtSize = 6.2, Color = Color3.fromRGB(200, 25, 25) },
}

function Config.GetCostume(id: string)
	for _, costume in Config.Costumes do
		if costume.Id == id then
			return costume
		end
	end
	return Config.Costumes[1]
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
}

---------------------------------------------------------------------------
-- Pets: hatched from eggs, placed on the base, earn Money per second.
---------------------------------------------------------------------------
Config.Pets = {
	Bat = { Name = "Bat", Rarity = "Common", MoneyPerSecond = 1, Color = Color3.fromRGB(60, 50, 70) },
	BlackCat = { Name = "Black Cat", Rarity = "Common", MoneyPerSecond = 2, Color = Color3.fromRGB(20, 20, 20) },
	Spider = { Name = "Candy Spider", Rarity = "Uncommon", MoneyPerSecond = 4, Color = Color3.fromRGB(120, 40, 160) },
	Pumpkling = { Name = "Pumpkling", Rarity = "Uncommon", MoneyPerSecond = 6, Color = Color3.fromRGB(255, 130, 0) },
	Crow = { Name = "Scarecrow Crow", Rarity = "Uncommon", MoneyPerSecond = 9, Color = Color3.fromRGB(30, 30, 35) },
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
}

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
	{ Count = 5, Money = 25000 },
	{ Count = 10, Money = 300000 },
	{ Count = 15, Money = 3000000 },
	{ Count = 20, Money = 30000000 },
}

---------------------------------------------------------------------------
-- Eggs: stolen from houses, hatched for free at your base. Rarer = bigger, slower to carry, longer to hatch.
-- Pool weights are relative; they do not need to add up to 100.
---------------------------------------------------------------------------
Config.Eggs = {
	CandyEgg = {
		Name = "Candy Egg", Rarity = "Common", HatchSeconds = 10, Size = 2, CarrySpeed = 0.95,
		Color = Color3.fromRGB(255, 180, 200),
		Pool = { { Pet = "Bat", Weight = 55 }, { Pet = "BlackCat", Weight = 35 }, { Pet = "Spider", Weight = 10 } },
	},
	PumpkinEgg = {
		Name = "Pumpkin Egg", Rarity = "Uncommon", HatchSeconds = 30, Size = 2.4, CarrySpeed = 0.93,
		Color = Color3.fromRGB(255, 140, 20),
		Pool = { { Pet = "Pumpkling", Weight = 55 }, { Pet = "Crow", Weight = 35 }, { Pet = "CandyCorn", Weight = 10 } },
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
	{ Owner = "Friendly Mummy", OwnerSpeed = 16, CandyPerKnock = 5, CostumeTier = 0, Floors = 1, Scale = 1.0, EggCount = 4,
		EggWeights = { CandyEgg = 70, PumpkinEgg = 25, BatEgg = 5 } },
	{ Owner = "Old Witch", OwnerSpeed = 18, CandyPerKnock = 10, CostumeTier = 0, Floors = 1, Scale = 1.05, EggCount = 4,
		EggWeights = { CandyEgg = 50, PumpkinEgg = 35, BatEgg = 13, GhostEgg = 2 } },
	{ Owner = "Scarecrow", OwnerSpeed = 21, CandyPerKnock = 20, CostumeTier = 1, Floors = 1, Scale = 1.1, EggCount = 5,
		EggWeights = { CandyEgg = 30, PumpkinEgg = 40, BatEgg = 25, GhostEgg = 5 } },
	{ Owner = "Zombie Chef", OwnerSpeed = 25, CandyPerKnock = 40, CostumeTier = 2, Floors = 2, Scale = 1.15, EggCount = 5,
		EggWeights = { PumpkinEgg = 40, BatEgg = 40, GhostEgg = 18, MoonEgg = 2 } },
	{ Owner = "Gravedigger", OwnerSpeed = 30, CandyPerKnock = 80, CostumeTier = 3, Floors = 1, Scale = 1.2, EggCount = 5,
		EggWeights = { PumpkinEgg = 20, BatEgg = 45, GhostEgg = 30, MoonEgg = 5 } },
	{ Owner = "Count Vlad", OwnerSpeed = 37, CandyPerKnock = 160, CostumeTier = 4, Floors = 2, Scale = 1.25, EggCount = 6,
		EggWeights = { BatEgg = 40, GhostEgg = 40, MoonEgg = 18, CursedEgg = 2 } },
	{ Owner = "Banshee", OwnerSpeed = 46, CandyPerKnock = 320, CostumeTier = 5, Floors = 2, Scale = 1.3, EggCount = 6,
		EggWeights = { BatEgg = 20, GhostEgg = 45, MoonEgg = 30, CursedEgg = 5 } },
	{ Owner = "Headless Horseman", OwnerSpeed = 58, CandyPerKnock = 650, CostumeTier = 6, Floors = 2, Scale = 1.35, EggCount = 6,
		EggWeights = { GhostEgg = 40, MoonEgg = 40, CursedEgg = 18, NightmareEgg = 2 } },
	{ Owner = "Lich King", OwnerSpeed = 72, CandyPerKnock = 1300, CostumeTier = 7, Floors = 2, Scale = 1.45, EggCount = 6,
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
Config.CaughtStunTime = 1.5 -- seconds the thief is slowed after being caught
Config.MaxEggsHeld = 12 -- unhatched egg inventory cap
Config.IncubatorSlots = 3 -- eggs hatching at the same time on a new base
Config.MaxPetsOnBase = 10 -- pet slots on a new base
Config.MaxPetsStored = 60 -- inventory cap for pets that are not equipped
Config.FriendBoostPercent = 10 -- extra pet Money for every friend playing in the same server

---------------------------------------------------------------------------
-- Base upgrades: bought with Money at the UPGRADE BASE sign. Each one makes the base
-- Config.BaseDepthStep studs deeper, and adds 2 pet slots and 1 hatching pedestal.
---------------------------------------------------------------------------
Config.BaseDepth = 40 -- depth of a new base (studs, front to back)
Config.BaseDepthStep = 10
Config.BaseUpgrades = {
	{ Price = 5000 },
	{ Price = 75000 },
	{ Price = 1000000 },
	{ Price = 15000000 },
}

function Config.IncubatorsFor(baseLevel: number?): number
	return Config.IncubatorSlots + (baseLevel or 0)
end

function Config.PetSlotsFor(baseLevel: number?): number
	return Config.MaxPetsOnBase + 2 * (baseLevel or 0)
end
Config.IncomeTickSeconds = 1
Config.PetSellSeconds = 30 -- selling a pet pays this many seconds of its income

return Config
