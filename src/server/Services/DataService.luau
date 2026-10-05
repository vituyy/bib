-- Loads, caches and saves player data, and mirrors it to leaderstats and the client.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = {}

-- Session lock: while a player is in a server, their save is stamped with that server's JobId. Another server
-- will not load (and so can not duplicate or overwrite) it until the stamp is released or goes stale. The stamp
-- is refreshed by every autosave, so a crashed server only blocks the player for LOCK_TIMEOUT seconds.
local JOB_ID = if game.JobId ~= "" then game.JobId else "studio"
local LOCK_TIMEOUT = 240
local LOCK_RETRIES = 6 -- tries when the save is open elsewhere, 4 seconds apart
local LOCK_KEY = "__Lock"

local profiles: { [Player]: { [string]: any } } = {}
local canSave: { [Player]: boolean } = {}
local releasing: { [Player]: boolean } = {} -- set once the final save has started, so a late autosave can not re-lock the save
local loadedSignals: { [Player]: BindableEvent } = {}
local changedCallbacks: { (Player, { [string]: any }) -> () } = {}

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStores unavailable, progress will not save:", result)
	end
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Fill in any fields added to StartingData after this player last saved.
local function reconcile(data: { [string]: any })
	for key, default in Config.StartingData do
		if data[key] == nil then
			data[key] = deepCopy(default)
		end
	end
	return data
end

local function isNumber(x: any): boolean
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

local function cleanNumber(data, key: string, min: number, max: number?, whole: boolean?)
	local v = data[key]
	if not isNumber(v) then
		v = Config.StartingData[key]
	end
	v = math.max(min, if max then math.min(v, max) else v)
	data[key] = if whole then math.floor(v) else v
end

local function cleanList(value: any, keep: (any) -> any?): { any }
	local out = {}
	if type(value) == "table" then
		for _, entry in value do
			local kept = keep(entry)
			if kept ~= nil then
				table.insert(out, kept)
			end
		end
	end
	return out
end

-- Repair a loaded save so one bad value (NaN, a negative, a removed pet or egg) can not break the game.
local function sanitize(data: { [string]: any })
	-- Saves from before the two separate base upgrades had one BaseLevel (10 + 2 pets and 3 + 1 pads per level).
	-- Turn it into the closest Pet Capacity and Hatching Pad levels that never take anything away.
	if isNumber(data.BaseLevel) then
		local old = math.clamp(math.floor(data.BaseLevel), 0, 4)
		data.PetCapLevel = math.max(tonumber(data.PetCapLevel) or 0, math.ceil((4 + 2 * old) / 3))
		data.PadLevel = math.max(tonumber(data.PadLevel) or 0, 1 + old)
	end
	data.BaseLevel = nil

	cleanNumber(data, "Candy", 0)
	cleanNumber(data, "Money", 0)
	cleanNumber(data, "SpeedXp", 0)
	cleanNumber(data, "SpeedLevel", 0, Config.MaxSpeedLevel, true)
	cleanNumber(data, "Rebirths", 0, Config.MaxRebirths, true)
	cleanNumber(data, "Treadmill", 1, #Config.Treadmills, true)
	cleanNumber(data, "Trail", 0, #Config.Trails, true)
	cleanNumber(data, "PetCapLevel", 0, #Config.PetCapacityUpgrades, true)
	cleanNumber(data, "PadLevel", 0, #Config.HatchPadUpgrades, true)
	cleanNumber(data, "CustomSpeed", 0, Config.WalkSpeedFor(Config.MaxSpeedLevel))
	cleanNumber(data, "EggsStolen", 0, nil, true)

	-- Quests: keep only well-formed quests (a bad list is simply replaced with fresh quests).
	local function cleanQuests(list: any): { any }
		local out = {}
		if type(list) == "table" then
			for _, q in list do
				if type(q) == "table" and Config.Quests.Templates[q.Id] and isNumber(q.Target) and isNumber(q.Progress) and type(q.Reward) == "table" then
					local reward = {}
					for _, currency in { "Money", "Candy", "Xp" } do
						if isNumber(q.Reward[currency]) and q.Reward[currency] > 0 then
							reward[currency] = q.Reward[currency]
						end
					end
					table.insert(out, {
						Id = q.Id,
						Slot = if type(q.Slot) == "string" then q.Slot else "Easy",
						Target = math.max(1, q.Target),
						Progress = math.clamp(q.Progress, 0, math.max(1, q.Target)),
						Claimed = q.Claimed == true,
						Rerolled = q.Rerolled == true,
						Minutes = if isNumber(q.Minutes) then q.Minutes else 0,
						Param = if isNumber(q.Param) then q.Param else nil,
						Reward = reward,
					})
				end
			end
		end
		return out
	end
	local quests = if type(data.Quests) == "table" then data.Quests else {}
	data.Quests = {
		Day = if isNumber(quests.Day) then quests.Day else 0,
		Week = if isNumber(quests.Week) then quests.Week else 0,
		Daily = cleanQuests(quests.Daily),
		Weekly = cleanQuests(quests.Weekly),
		DailyChest = quests.DailyChest == true,
		WeeklyChest = quests.WeeklyChest == true,
		Streak = if isNumber(quests.Streak) then math.max(0, math.floor(quests.Streak)) else 0,
		LastStreakDay = if isNumber(quests.LastStreakDay) then quests.LastStreakDay else 0,
		Salt = if isNumber(quests.Salt) then quests.Salt else 0, -- the Admin panel changes it to get a different set
	}
	local blood = quests.Blood
	if type(blood) == "table" and isNumber(blood.Id) and isNumber(blood.Target) and isNumber(blood.Progress) and type(blood.Reward) == "table" then
		local reward = {}
		for _, currency in { "Money", "Candy", "Xp" } do
			if isNumber(blood.Reward[currency]) and blood.Reward[currency] > 0 then
				reward[currency] = blood.Reward[currency]
			end
		end
		data.Quests.Blood = { Id = blood.Id, Target = math.max(1, blood.Target), Progress = math.clamp(blood.Progress, 0, math.max(1, blood.Target)), Claimed = blood.Claimed == true, Reward = reward }
	end
	local stats = if type(data.Stats) == "table" then data.Stats else {}
	data.Stats = {}
	for _, key in { "Knocks", "Hatched", "Caught" } do
		data.Stats[key] = if isNumber(stats[key]) then math.max(0, math.floor(stats[key])) else 0
	end
	local potions = if type(data.Potions) == "table" then data.Potions else {}
	local boosts = if type(data.Boosts) == "table" then data.Boosts else {}
	data.Potions, data.Boosts = {}, {}
	for _, kind in Config.PotionOrder do
		data.Potions[kind] = if isNumber(potions[kind]) then math.clamp(math.floor(potions[kind]), 0, 9999) else 0
		data.Boosts[kind] = if isNumber(boosts[kind]) then math.max(0, math.floor(boosts[kind])) else 0
	end
	local playtime = if type(data.Playtime) == "table" then data.Playtime else {}
	data.Playtime = {
		Day = if isNumber(playtime.Day) then playtime.Day else 0,
		Seconds = if isNumber(playtime.Seconds) then math.max(0, math.floor(playtime.Seconds)) else 0,
		Claimed = {},
	}
	if type(playtime.Claimed) == "table" then
		for key, value in playtime.Claimed do
			if value == true and Config.Playtime.Rewards[tonumber(key) or 0] then
				data.Playtime.Claimed[tostring(key)] = true
			end
		end
	end
	local achieved = if type(data.Achieved) == "table" then data.Achieved else {}
	data.Achieved = {}
	for _, achievement in Config.Quests.Achievements do
		local n = achieved[achievement.Id]
		data.Achieved[achievement.Id] = if isNumber(n) then math.clamp(math.floor(n), 0, #achievement.Tiers) else 0
	end

	data.OwnedTrails = cleanList(data.OwnedTrails, function(i)
		return if isNumber(i) and Config.Trails[i] then i else nil
	end)
	if data.Trail ~= 0 and not table.find(data.OwnedTrails, data.Trail) then
		data.Trail = 0
	end
	data.OwnedCostumes = cleanList(data.OwnedCostumes, function(id)
		return if type(id) == "string" and Config.GetCostume(id).Id == id then id else nil
	end)
	if not table.find(data.OwnedCostumes, "None") then
		table.insert(data.OwnedCostumes, 1, "None")
	end
	if type(data.EquippedCostume) ~= "string" or not table.find(data.OwnedCostumes, data.EquippedCostume) then
		data.EquippedCostume = "None"
	end

	local function petOk(id: any): any?
		return if type(id) == "string" and Config.Pets[id] then id else nil
	end
	data.Pets = cleanList(data.Pets, petOk)
	data.Storage = cleanList(data.Storage, petOk)
	data.Eggs = cleanList(data.Eggs, function(entry)
		if type(entry) ~= "string" then
			return nil
		end
		local eggId, petId = Config.ParseEgg(entry)
		if not Config.Eggs[eggId] then
			return nil
		end
		return Config.MakeEggEntry(eggId, if petId and Config.Pets[petId] then petId else nil)
	end)
	data.Incubators = cleanList(data.Incubators, function(entry)
		if type(entry) ~= "table" or type(entry.Egg) ~= "string" or not Config.Eggs[entry.Egg] or not isNumber(entry.EndsAt) then
			return nil
		end
		return { Egg = entry.Egg, Pet = if type(entry.Pet) == "string" and Config.Pets[entry.Pet] then entry.Pet else nil, EndsAt = entry.EndsAt }
	end)
	-- The Index only counts plain pets, never their mutated versions.
	local seen = {}
	data.Discovered = cleanList(data.Discovered, function(id)
		if type(id) ~= "string" then
			return nil
		end
		local baseId = Config.SplitPet(id)
		if rawget(Config.Pets, baseId) and not seen[baseId] then
			seen[baseId] = true
			return baseId
		end
		return nil
	end)
	data.IndexClaimed = cleanList(data.IndexClaimed, function(n)
		return if isNumber(n) then n else nil
	end)
	data.RedeemedCodes = cleanList(data.RedeemedCodes, function(code)
		return if type(code) == "string" then code else nil
	end)
end

local function lockedByOther(record: any): boolean
	local lock = type(record) == "table" and record[LOCK_KEY]
	return type(lock) == "table" and lock.JobId ~= JOB_ID and os.time() - (tonumber(lock.At) or 0) < LOCK_TIMEOUT
end

local function keyFor(player: Player): string
	return "Player_" .. player.UserId
end

local function withRetries<T>(fn: () -> T): (boolean, T | string)
	local lastErr
	for attempt = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(attempt * 2)
	end
	return false, lastErr
end

-- Playtest milestones: how long into the session each stage happened ("costume 2 bought 4:12"). They are printed to
-- the server log as they happen and the Admin panel shows them. Kept in memory only.
local sessionStart: { [Player]: number } = {}
local milestones: { [Player]: { { At: number, Key: string } } } = {}
local milestoneSeen: { [Player]: { [string]: boolean } } = {}
local lastSnapshot: { [Player]: { [string]: number } } = {}
local lastWritten: { [Player]: { [string]: number } } = {} -- board scores already saved, so unchanged ones are skipped
local saveScores: (Player) -> () -- defined with the boards below
local refreshQuests: (Player, { [string]: any }) -> boolean -- defined with the quests below
local achSeen: { [Player]: { [string]: number } } = {} -- highest achievement step already announced, per player
local lastActive: { [Player]: number } = {} -- when each player last did something (for the playtime clock)
local lastSample: { [Player]: Vector3 } = {}
local playtimeNewDay: ({ [string]: any }) -> boolean
local bloodDelivered: { [Player]: number } = {} -- eggs brought home during the current Blood Moon
local ensureBloodQuest: (Player, { [string]: any }) -> ()
local checkAchievements: (Player, { [string]: any }) -> ()

local function clock(seconds: number): string
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

function DataService.Milestone(player: Player, key: string)
	local seen = milestoneSeen[player]
	if not seen or seen[key] then
		return
	end
	seen[key] = true
	local at = os.clock() - (sessionStart[player] or os.clock())
	table.insert(milestones[player], { At = at, Key = key })
	print(string.format("[Playtest] %s  %s  %s", player.Name, clock(at), key))
end

-- The timeline of one player as text (for the Admin panel).
function DataService.TimelineText(player: Player): string
	local list = milestones[player]
	if not list or #list == 0 then
		return "No milestones yet"
	end
	local lines = {}
	for _, m in list do
		table.insert(lines, clock(m.At) .. "  " .. m.Key)
	end
	return table.concat(lines, "\n")
end

-- Compares the new data with the last snapshot and records what changed.
function DataService.TrackMilestones(player: Player, data: { [string]: any })
	if not milestoneSeen[player] then
		return
	end
	local last = lastSnapshot[player]
	local now = {
		Costumes = #data.OwnedCostumes,
		Treadmill = data.Treadmill,
		Trails = #data.OwnedTrails,
		Pets = #data.Pets + #data.Storage,
		Rebirths = data.Rebirths,
		Level = data.SpeedLevel,
		PetCap = data.PetCapLevel,
		Pads = data.PadLevel,
		Stolen = data.EggsStolen,
		Index = #data.Discovered,
	}
	lastSnapshot[player] = now
	checkAchievements(player, data)
	if last and now.Level > last.Level and now.Rebirths == last.Rebirths then
		task.defer(DataService.QuestEvent, player, "Level", now.Level - last.Level) -- after this publish has finished
	end
	if not last then
		return
	end
	local function ifUp(field: string, label: (number) -> string)
		if now[field] > last[field] then
			DataService.Milestone(player, label(now[field]))
		end
	end
	ifUp("Costumes", function(n) return "costume " .. (n - 1) .. " bought" end)
	ifUp("Treadmill", function(n) return "treadmill " .. n .. " bought" end)
	ifUp("Trails", function(n) return "trail " .. n .. " bought" end)
	ifUp("PetCap", function(n) return "pet capacity " .. n .. " bought" end)
	ifUp("Pads", function(n) return "hatching pads " .. n .. " bought" end)
	ifUp("Rebirths", function(n) return "REBIRTH " .. n end)
	ifUp("Stolen", function(n) return "egg delivered #" .. n end)
	ifUp("Index", function(n) return "index " .. n .. " pets" end)
	if now.Pets > last.Pets and (now.Pets == 1 or now.Pets % 5 == 0) then
		DataService.Milestone(player, "pets owned: " .. now.Pets)
	end
	if now.Level > last.Level and now.Level % 5 == 0 then
		DataService.Milestone(player, string.format("speed level %d (rebirth %d)", now.Level, now.Rebirths))
	end
end

local function makeLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	-- The Tab list shows these in this order and sorts players by the first one.
	for _, statName in { "Rebirths", "Speed", "Money", "Candy" } do
		local value = Instance.new("NumberValue")
		value.Name = statName
		value.Parent = leaderstats
	end
	leaderstats.Parent = player
end

local function publish(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Rebirths.Value = data.Rebirths
		leaderstats.Candy.Value = math.floor(data.Candy)
		leaderstats.Money.Value = math.floor(data.Money)
		leaderstats.Speed.Value = Config.WalkSpeedFor(data.SpeedLevel)
	end
	DataService.TrackMilestones(player, data)
	Remotes.DataChanged:FireClient(player, data)
	for _, callback in changedCallbacks do
		task.spawn(callback, player, data)
	end
end

-- Takes this server's session lock on a player's save and returns its contents.
-- Result: "ok" with the data, "locked" (open on another server) or "error".
local function claimSession(player: Player): (string, any)
	local outcome, loaded = "error", nil
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(record)
			if lockedByOther(record) then
				outcome = "locked"
				return nil -- leave the save alone
			end
			record = if type(record) == "table" then record else {}
			record[LOCK_KEY] = { JobId = JOB_ID, At = os.time() }
			outcome, loaded = "ok", record
			return record
		end)
	end)
	if not ok then
		warn("[DataService] Load failed for", player.Name, err)
		return "error", err
	end
	return outcome, loaded
end

-- Writes a player's data back. `release` also frees the session lock (use it when the player leaves).
local function writeSave(player: Player, snapshot: { [string]: any }, release: boolean): boolean
	local conflict = false
	local ok, err = withRetries(function()
		return (store :: DataStore):UpdateAsync(keyFor(player), function(record)
			if lockedByOther(record) then
				conflict = true -- another server took this save over; do not overwrite it
				return nil
			end
			if releasing[player] and not release then
				return nil -- the final save is already on its way
			end
			snapshot[LOCK_KEY] = if release then nil else { JobId = JOB_ID, At = os.time() }
			return snapshot
		end)
	end)
	if not ok then
		warn("[DataService] Failed to save data for", player.Name, err)
		return false
	end
	if conflict then
		warn("[DataService] Save for", player.Name, "is open on another server; not saving here")
		canSave[player] = false
		if player.Parent then
			player:Kick("Your save was opened on another server. Please rejoin.")
		end
		return false
	end
	return true
end

function DataService.Load(player: Player)
	loadedSignals[player] = loadedSignals[player] or Instance.new("BindableEvent")
	sessionStart[player] = os.clock()
	milestones[player] = {}
	milestoneSeen[player] = {}
	makeLeaderstats(player)

	local data
	if store then
		local locked, errors = 0, 0
		while player.Parent do
			local outcome, result = claimSession(player)
			if outcome == "ok" then
				data = result
				data[LOCK_KEY] = nil
				canSave[player] = true
				break
			elseif outcome == "locked" then
				locked += 1
				if locked >= LOCK_RETRIES then
					player:Kick("Your save is still open on another server. Please rejoin in a minute.")
					return
				end
				task.wait(4)
			else
				errors += 1
				if errors >= 3 then
					Remotes.Notify:FireClient(player, "Could not load your save. Progress this session will NOT be saved.", Color3.fromRGB(255, 80, 80))
					break
				end
				task.wait(errors * 2)
			end
		end
	end

	if not player.Parent then
		-- Left while loading: give the save lock back so the next server can open it.
		if canSave[player] and data then
			writeSave(player, data, true)
		end
		canSave[player] = nil
		return
	end

	profiles[player] = reconcile(if type(data) == "table" then data else deepCopy(Config.StartingData))
	sanitize(profiles[player])
	refreshQuests(player, profiles[player])
	if Config.IsBloodMoon() then
		bloodDelivered[player] = 0
		ensureBloodQuest(player, profiles[player])
	end
	playtimeNewDay(profiles[player])
	lastActive[player] = os.clock()
	-- Saves from before the Index: pets already on the base count as discovered.
	for _, petId in profiles[player].Pets do
		local baseId = Config.SplitPet(petId)
		if not table.find(profiles[player].Discovered, baseId) then
			table.insert(profiles[player].Discovered, baseId)
		end
	end
	loadedSignals[player]:Fire()
	publish(player)
end

-- Saves a player's data. With `release` it also frees the session lock (the player is leaving or the server is closing).
function DataService.Save(player: Player, release: boolean?)
	local data = profiles[player]
	if not (store and data and canSave[player]) then
		return
	end
	writeSave(player, deepCopy(data), release == true)
end

function DataService.Release(player: Player)
	task.spawn(saveScores, player)
	releasing[player] = true
	DataService.Save(player, true)
	profiles[player] = nil
	canSave[player] = nil
	releasing[player] = nil
	sessionStart[player], milestones[player], milestoneSeen[player], lastSnapshot[player], lastWritten[player] = nil, nil, nil, nil, nil
	achSeen[player] = nil
	bloodDelivered[player] = nil
	lastActive[player], lastSample[player] = nil, nil
	if loadedSignals[player] then
		loadedSignals[player]:Destroy()
		loadedSignals[player] = nil
	end
end

-- Returns the live data table, or nil if it has not loaded yet. Treat it as read-only; use Update to change it.
function DataService.Get(player: Player): { [string]: any }?
	return profiles[player]
end

-- Yields until the player's data is loaded (or they leave). Returns the data or nil.
function DataService.WaitFor(player: Player): { [string]: any }?
	while player.Parent and not profiles[player] do
		local signal = loadedSignals[player]
		if signal then
			signal.Event:Wait()
		else
			task.wait(0.1)
		end
	end
	return profiles[player]
end

-- Mutates a player's data through a callback and then pushes the change everywhere.
function DataService.Update(player: Player, mutator: ({ [string]: any }) -> ())
	local data = profiles[player]
	if not data then
		return false
	end
	mutator(data)
	publish(player)
	return true
end

-- Register a function called after every change to a player's data.
function DataService.OnChanged(callback: (Player, { [string]: any }) -> ())
	table.insert(changedCallbacks, callback)
end

---------------------------------------------------------------------------
-- Quests (rules and numbers: Config.Quests). Three daily quests (easy, medium, hard), two weekly ones, a chest for
-- finishing each set, and lifetime achievements. Quests are generated per player and per day from a seed, so
-- leaving and rejoining gives the same quests. Progress comes from QuestEvent calls made by the other services.
---------------------------------------------------------------------------
local QuestCfg = Config.Quests

local function shortNumber(n: number): string
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

local function rewardText(reward: { [string]: number }): string
	local parts = {}
	if reward.Money then
		table.insert(parts, "$" .. shortNumber(reward.Money))
	end
	if reward.Candy then
		table.insert(parts, shortNumber(reward.Candy) .. " Candy")
	end
	if reward.Xp then
		table.insert(parts, shortNumber(reward.Xp) .. " Speed XP")
	end
	return table.concat(parts, ", ")
end

local function notify(player: Player, text: string, color: Color3)
	Remotes.Notify:FireClient(player, text, color)
end

local QUEST_GREEN = Color3.fromRGB(120, 255, 120)

-- Template ids that may fill a slot for this player, in a fixed order (so the seed gives the same pick every time).
local function candidates(data: { [string]: any }, slot: string, taken: { [string]: boolean }, exclude: string?): { string }
	local tier = QuestCfg.Tier(data)
	local ids = {}
	for id, template in QuestCfg.Templates do
		if template.Slots[slot] and not taken[template.Kind] and id ~= exclude and tier >= (template.MinTier or 1) then
			if template.Kind ~= "Level" or data.SpeedLevel < Config.MaxSpeedLevel then
				table.insert(ids, id)
			end
		end
	end
	table.sort(ids)
	return ids
end

local function makeQuest(data: { [string]: any }, id: string, slotConfig, rng: Random, mult: number)
	local template = QuestCfg.Templates[id]
	local secPer = QuestCfg.SecondsPer(template, data)
	local isWeekly = slotConfig.Slot == "Weekly"
	local target
	local totalSeconds: number? = nil
	if template.Fixed then
		target = template.Fixed
	elseif template.Kind == "Level" then
		-- Each level costs more XP than the last, so add them up until the effort fits.
		local seconds = rng:NextNumber(slotConfig.Min, slotConfig.Max) * 60
		local most = math.min(if isWeekly then 25 else (template.Max or 8), Config.MaxSpeedLevel - data.SpeedLevel)
		target = 1
		while target < most and QuestCfg.LevelSeconds(data, target + 1) <= seconds do
			target += 1
		end
		totalSeconds = QuestCfg.LevelSeconds(data, target)
	else
		local minutes = rng:NextNumber(slotConfig.Min, slotConfig.Max)
		target = math.max(template.Min or 1, math.floor(minutes * 60 / secPer + 0.5))
		local cap = if isWeekly then template.WeeklyMax else template.Max
		if cap then
			target = math.min(target, cap)
		end
		if template.Unit == "time" then
			target = math.max(30, math.floor(target / 30 + 0.5) * 30) -- whole half-minutes
		end
	end
	local minutes = (totalSeconds or target * secPer) / 60
	return {
		Id = id,
		Slot = slotConfig.Slot,
		Target = target,
		Progress = 0,
		Claimed = false,
		Rerolled = false,
		Minutes = math.floor(minutes * 10 + 0.5) / 10,
		Param = if template.Kind == "DeliverBest" then QuestCfg.Tier(data) else nil,
		Reward = QuestCfg.Reward(data, minutes, template.Share, mult),
	}
end

local function generateQuests(player: Player, data: { [string]: any }, slots, mult: number, seed: number)
	local rng = Random.new(player.UserId % 1000003 * 31 + seed)
	local list, taken = {}, {}
	for _, slotConfig in slots do
		local ids = candidates(data, slotConfig.Slot, taken, nil)
		if #ids == 0 then
			ids = candidates(data, slotConfig.Slot, {}, nil)
		end
		local quest = makeQuest(data, ids[rng:NextInteger(1, #ids)], slotConfig, rng, mult)
		taken[QuestCfg.Templates[quest.Id].Kind] = true
		table.insert(list, quest)
	end
	return list
end

-- Starts a new day or week of quests when the clock has moved on (or the lists are missing). Returns true if
-- anything changed.
refreshQuests = function(player: Player, data: { [string]: any }): boolean
	local quests = data.Quests
	local now = os.time()
	local day, week = QuestCfg.DayKey(now), QuestCfg.WeekKey(now)
	local changed = false
	if quests.Day ~= day or #quests.Daily ~= #QuestCfg.DailySlots then
		quests.Day = day
		quests.Daily = generateQuests(player, data, QuestCfg.DailySlots, QuestCfg.DailyMult, day * 7919 + (quests.Salt or 0) * 131)
		quests.DailyChest = false
		changed = true
	end
	if quests.Week ~= week or #quests.Weekly ~= #QuestCfg.WeeklySlots then
		quests.Week = week
		quests.Weekly = generateQuests(player, data, QuestCfg.WeeklySlots, QuestCfg.WeeklyMult, week * 104729 + (quests.Salt or 0) * 131)
		quests.WeeklyChest = false
		changed = true
	end
	return changed
end

-- Does this game event move that quest forward?
local function countsFor(template, quest, kind: string, info): boolean
	local tk = template.Kind
	if tk == kind then
		return true
	end
	if kind == "Deliver" then
		return tk == "DeliverBest" and info ~= nil and (info.House or 0) >= (quest.Param or 1)
	elseif kind == "Hatch" then
		return info ~= nil and ((tk == "HatchSize" and info.Size ~= nil) or (tk == "HatchMaterial" and info.Material ~= nil))
	end
	return false
end

-- Called by the other services when something quest-worthy happens: "Knock", "Deliver" (info.House), "Hatch"
-- (info.Size, info.Material), "Level", "Run" (seconds), "Caught".
function DataService.QuestEvent(player: Player, kind: string, amount: number, info: { [string]: any }?)
	local data = profiles[player]
	if not data or not data.Quests then
		return
	end
	local fresh = refreshQuests(player, data)
	if kind == "Knock" then
		data.Stats.Knocks += amount
	elseif kind == "Hatch" then
		data.Stats.Hatched += amount
	elseif kind == "Caught" then
		data.Stats.Caught += amount
	end
	local finished = 0
	if kind == "Deliver" and Config.IsBloodMoon() then
		ensureBloodQuest(player, data)
		bloodDelivered[player] = (bloodDelivered[player] or 0) + amount
		local blood = data.Quests.Blood
		if blood and not blood.Claimed and blood.Progress < blood.Target then
			blood.Progress = math.min(blood.Target, blood.Progress + amount)
			if blood.Progress >= blood.Target then
				finished += 1
				notify(player, "Blood Moon quest complete! Open Quests to open the chest.", QUEST_GREEN)
			end
		end
	end
	for _, list in { data.Quests.Daily, data.Quests.Weekly } do
		for _, quest in list do
			local template = QuestCfg.Templates[quest.Id]
			if template and not quest.Claimed and quest.Progress < quest.Target and countsFor(template, quest, kind, info) then
				quest.Progress = math.min(quest.Target, quest.Progress + amount)
				if quest.Progress >= quest.Target then
					finished += 1
					notify(player, "Quest complete: " .. QuestCfg.Describe(quest) .. "! Claim it in Quests.", QUEST_GREEN)
				end
			end
		end
	end
	if kind ~= "Run" or finished > 0 or fresh then
		publish(player) -- running is published by the XP it earns anyway
	end
end

-- Tell the player when a new achievement step becomes claimable (silent for the first look, so old progress
-- does not spam them on every join).
checkAchievements = function(player: Player, data: { [string]: any })
	local seen = achSeen[player]
	local first = seen == nil
	if first then
		seen = {}
		achSeen[player] = seen
	end
	for _, achievement in QuestCfg.Achievements do
		local claimed, _, _, ready = QuestCfg.AchievementState(data, achievement)
		if ready and (seen[achievement.Id] or -1) < claimed + 1 then
			seen[achievement.Id] = claimed + 1
			if not first then
				notify(player, "Achievement ready: " .. achievement.Title .. "! Claim it in Quests.", QUEST_GREEN)
			end
		end
	end
end

local function grant(player: Player, reward: { [string]: number })
	if reward.Xp then
		require(script.Parent.SpeedService).GiveXp(player, reward.Xp)
	end
end

local function questList(data: { [string]: any }, name: any)
	if name == "Daily" then
		return data.Quests.Daily
	elseif name == "Weekly" then
		return data.Quests.Weekly
	end
	return nil
end

-- Starts new quests if the day or week has changed (also used by the Admin panel).
function DataService.RefreshQuests(player: Player)
	local data = profiles[player]
	if data and refreshQuests(player, data) then
		publish(player)
	end
end

function DataService.ClaimQuest(player: Player, arg: any): (boolean, string)
	local data = profiles[player]
	if not data or type(arg) ~= "table" then
		return false, "Not ready yet"
	end
	refreshQuests(player, data)
	local list = questList(data, arg.List)
	local quest = list and list[arg.Index]
	if not quest then
		return false, "That quest is gone"
	elseif quest.Claimed then
		return false, "Already claimed"
	elseif quest.Progress < quest.Target then
		return false, "Not finished yet"
	end
	DataService.Update(player, function(d)
		quest.Claimed = true
		d.Money += quest.Reward.Money or 0
		d.Candy += quest.Reward.Candy or 0
	end)
	grant(player, quest.Reward)
	return true, "Quest reward: " .. rewardText(quest.Reward)
end

function DataService.ClaimChest(player: Player, which: any): (boolean, string)
	local data = profiles[player]
	if not data or (which ~= "Daily" and which ~= "Weekly") then
		return false, "Not ready yet"
	end
	refreshQuests(player, data)
	local quests = data.Quests
	local list = questList(data, which)
	if quests[which .. "Chest"] then
		return false, "Chest already opened"
	end
	for _, quest in list do
		if not quest.Claimed then
			return false, "Claim every quest in the set first"
		end
	end
	local streak = if which == "Daily" then QuestCfg.NextStreak(quests, quests.Day) else 1
	local reward = QuestCfg.ChestReward(list, streak)
	DataService.Update(player, function(d)
		d.Quests[which .. "Chest"] = true
		if which == "Daily" then
			d.Quests.Streak = streak
			d.Quests.LastStreakDay = d.Quests.Day
		end
		d.Money += reward.Money or 0
		d.Candy += reward.Candy or 0
	end)
	grant(player, reward)
	local text = which .. " Chest: " .. rewardText(reward)
	if which == "Daily" and streak > 1 then
		text ..= string.format(" (day %d in a row!)", streak)
	end
	return true, text
end

-- Swap an untouched daily quest for another one of the same difficulty (once per quest).
function DataService.RerollQuest(player: Player, index: any): (boolean, string)
	local data = profiles[player]
	if not data or type(index) ~= "number" then
		return false, "Not ready yet"
	end
	refreshQuests(player, data)
	local quest = data.Quests.Daily[index]
	if not quest then
		return false, "That quest is gone"
	elseif quest.Claimed or quest.Progress > 0 then
		return false, "You already started this quest"
	elseif quest.Rerolled then
		return false, "Already rerolled once"
	end
	local slotConfig
	for _, slot in QuestCfg.DailySlots do
		if slot.Slot == quest.Slot then
			slotConfig = slot
		end
	end
	local taken = {}
	for i, other in data.Quests.Daily do
		if i ~= index then
			taken[QuestCfg.Templates[other.Id].Kind] = true
		end
	end
	local ids = candidates(data, quest.Slot, taken, quest.Id)
	if not slotConfig or #ids == 0 then
		return false, "No other quest fits right now"
	end
	local rng = Random.new(os.clock() * 1000 + player.UserId)
	local fresh = makeQuest(data, ids[rng:NextInteger(1, #ids)], slotConfig, rng, QuestCfg.DailyMult)
	fresh.Rerolled = true
	DataService.Update(player, function(d)
		d.Quests.Daily[index] = fresh
	end)
	return true, "New quest: " .. QuestCfg.Describe(fresh)
end

function DataService.ClaimAchievement(player: Player, id: any): (boolean, string)
	local data = profiles[player]
	if not data or type(id) ~= "string" then
		return false, "Not ready yet"
	end
	for _, achievement in QuestCfg.Achievements do
		if achievement.Id == id then
			local claimed, _, _, ready = QuestCfg.AchievementState(data, achievement)
			if not ready then
				return false, "Not reached yet"
			end
			local reward = QuestCfg.Reward(data, QuestCfg.AchievementMinutes[claimed + 1], { Money = 0.5, Candy = 0.3, Xp = 0.2 }, 1)
			DataService.Update(player, function(d)
				d.Achieved[id] = claimed + 1
				d.Money += reward.Money or 0
				d.Candy += reward.Candy or 0
			end)
			grant(player, reward)
			return true, achievement.Title .. " reward: " .. rewardText(reward)
		end
	end
	return false, "Unknown achievement"
end

---------------------------------------------------------------------------
-- Playtime Rewards and potions (rules and numbers: Config.Playtime, Config.Potions). The server counts today's
-- active play time (it stops when the player stands still without using any menu for a minute). Gifts are claimed
-- from the Rewards window; potions are drunk from there too.
---------------------------------------------------------------------------

-- Called when the player does something (opens a menu, buys): counts as being active.
function DataService.Touch(player: Player)
	lastActive[player] = os.clock()
end

-- Starts a new day of playtime rewards when the date has changed. Returns true if it did.
playtimeNewDay = function(data: { [string]: any }): boolean
	local playtime = data.Playtime
	local day = Config.Quests.DayKey(os.time())
	if playtime.Day ~= day then
		playtime.Day, playtime.Seconds, playtime.Claimed = day, 0, {}
		return true
	end
	return false
end

local function playtimeText(resolved: { [string]: any }): string
	if resolved.EggId then
		return string.format("%d x %s", resolved.Count, Config.Eggs[resolved.EggId].Name)
	elseif resolved.Potion then
		return string.format("%d x %s", resolved.Count, Config.Potions[resolved.Potion].Name)
	end
	return rewardText(resolved)
end

function DataService.ClaimPlaytime(player: Player, index: any): (boolean, string)
	local data = profiles[player]
	local reward = type(index) == "number" and Config.Playtime.Rewards[index]
	if not data or not reward then
		return false, "Not ready yet"
	end
	playtimeNewDay(data)
	local playtime = data.Playtime
	local key = tostring(index)
	if playtime.Claimed[key] then
		return false, "Already claimed"
	elseif playtime.Seconds < reward.Minutes * 60 then
		return false, "Keep playing: not ready yet"
	end
	local resolved = Config.Playtime.Resolve(data, reward)
	if resolved.EggId and #data.Eggs + resolved.Count > Config.MaxEggsHeld then
		return false, "Your egg bag is full. Hatch or free some eggs first!"
	end
	DataService.Update(player, function(d)
		d.Playtime.Claimed[key] = true
		d.Money += resolved.Money or 0
		d.Candy += resolved.Candy or 0
		if resolved.EggId then
			for _ = 1, resolved.Count do
				table.insert(d.Eggs, Config.MakeEggEntry(resolved.EggId, nil))
			end
		elseif resolved.Potion then
			d.Potions[resolved.Potion] += resolved.Count
		end
	end)
	grant(player, resolved)
	return true, "Playtime reward: " .. playtimeText(resolved)
end

function DataService.DrinkPotion(player: Player, kind: any): (boolean, string)
	local data = profiles[player]
	local potion = type(kind) == "string" and Config.Potions[kind]
	if not data or not potion then
		return false, "Unknown potion"
	elseif data.Potions[kind] < 1 then
		return false, "You have no " .. potion.Name
	end
	local now = os.time()
	local ends = math.min(math.max(now, data.Boosts[kind]) + potion.Seconds, now + Config.PotionMaxSeconds)
	DataService.Update(player, function(d)
		d.Potions[kind] -= 1
		d.Boosts[kind] = ends
	end)
	return true, string.format("%s: %s for %d:%02d min", potion.Name, potion.Text, (ends - now) // 60, (ends - now) % 60)
end

---------------------------------------------------------------------------
-- Blood Moon (rules: Config.BloodMoon; the clock and the sky are in DayNightService): a one-off quest per event
-- ("bring N eggs home tonight", with a bonus chest) and a potion for everyone who brought an egg home.
---------------------------------------------------------------------------
ensureBloodQuest = function(player: Player, data: { [string]: any })
	local id = game:GetService("ReplicatedStorage"):GetAttribute("BloodMoonId")
	local current = data.Quests.Blood
	if not id or (current and current.Id == id) then
		return
	end
	local settings = Config.BloodMoon.Quest
	data.Quests.Blood = {
		Id = id,
		Target = settings.Target,
		Progress = 0,
		Claimed = false,
		Reward = QuestCfg.Reward(data, settings.Minutes, settings.Share, settings.Mult),
	}
end

-- Called when a Blood Moon begins: every player in the server gets the quest.
function DataService.BloodMoonStarted()
	for player, data in profiles do
		bloodDelivered[player] = 0
		ensureBloodQuest(player, data)
		publish(player)
	end
end

-- Called when it ends: a random potion for everyone who brought an egg home.
function DataService.BloodMoonEnded()
	local rng = Random.new(os.time())
	for player, data in profiles do
		if (bloodDelivered[player] or 0) > 0 then
			local kind = Config.PotionOrder[rng:NextInteger(1, #Config.PotionOrder)]
			DataService.Update(player, function(d)
				d.Potions[kind] += 1
			end)
			notify(player, "Blood Moon reward: a " .. Config.Potions[kind].Name .. " for brave egg thieves!", QUEST_GREEN)
		end
		bloodDelivered[player] = nil
	end
end

-- Claim the Blood Moon quest: its reward plus the chest (an egg if the bag has room, and a potion).
function DataService.ClaimBloodQuest(player: Player): (boolean, string)
	local data = profiles[player]
	local quest = data and data.Quests.Blood
	if not quest then
		return false, "There is no Blood Moon quest"
	elseif quest.Claimed then
		return false, "Already claimed"
	elseif quest.Progress < quest.Target then
		return false, "Not finished yet"
	end
	local rng = Random.new(os.clock() * 1000 + player.UserId)
	local kind = Config.PotionOrder[rng:NextInteger(1, #Config.PotionOrder)]
	local eggId = Config.Playtime.EggFor(data)
	local giveEgg = #data.Eggs < Config.MaxEggsHeld
	DataService.Update(player, function(d)
		quest.Claimed = true
		d.Money += quest.Reward.Money or 0
		d.Candy += quest.Reward.Candy or 0
		d.Potions[kind] += 1
		if giveEgg then
			table.insert(d.Eggs, Config.MakeEggEntry(eggId, nil))
		end
	end)
	grant(player, quest.Reward)
	local chest = (if giveEgg then Config.Eggs[eggId].Name .. " + " else "") .. Config.Potions[kind].Name
	return true, "Blood Moon quest: " .. rewardText(quest.Reward) .. ". Chest: " .. chest
end

---------------------------------------------------------------------------
-- Global leaderboards: two boards in the hub (Top Runners, Top Egg Thieves). Scores are kept in OrderedDataStores
-- (shared by every server) and written every Config.BoardRefreshSeconds. If DataStores are not available (Studio
-- without API access) the boards show the players in this server.
---------------------------------------------------------------------------
local BOARDS = {
	{
		Key = "Runners",
		Title = "TOP RUNNERS",
		Store = "SpookyTopRunners_v1",
		Score = function(d: { [string]: any }): number
			return d.Rebirths * 1000 + d.SpeedLevel
		end,
		Format = function(score: number): string
			return string.format("Rebirth %d  Lv %d", score // 1000, score % 1000)
		end,
		Spot = Vector3.new(-100, 10, -0.55), -- on the hub's front wall, left of the street entrance
		Accent = Color3.fromRGB(255, 190, 40),
	},
	{
		Key = "Thieves",
		Title = "TOP EGG THIEVES",
		Store = "SpookyTopThieves_v1",
		Score = function(d: { [string]: any }): number
			return d.EggsStolen
		end,
		Format = function(score: number): string
			return score .. " eggs"
		end,
		Spot = Vector3.new(160, 10, -0.55), -- on the wall to the right of the street entrance
		Accent = Color3.fromRGB(190, 120, 255),
	},
}
local BOARD_ROWS = 10
local nameCache: { [number]: string } = {}

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok then name else "Player " .. userId
	return nameCache[userId]
end

local function buildBoard(parent: Instance, def): { [number]: { Rank: TextLabel, Name: TextLabel, Score: TextLabel } }
	-- Hung on the hub's front wall (its face is at z = 0, the wall is 20 studs tall), looking into the hub (-Z).
	local cf = CFrame.new(def.Spot)
	local model = Instance.new("Model")
	model.Name = "Leaderboard_" .. def.Key

	local function block(name: string, size: Vector3, at: CFrame, color: Color3, material: Enum.Material?): Part
		local b = Instance.new("Part")
		b.Name, b.Size, b.CFrame, b.Color = name, size, at, color
		b.Material = material or Enum.Material.SmoothPlastic
		b.Anchored, b.TopSurface, b.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		b.Parent = model
		return b
	end
	local board = block("Board", Vector3.new(24, 16, 1), cf, Color3.fromRGB(24, 16, 36))
	block("Frame", Vector3.new(25.4, 17.4, 0.8), cf * CFrame.new(0, 0, 0.35), def.Accent, Enum.Material.Metal)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.2
	gui.Parent = board

	local function label(props: { [string]: any }): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextScaled = true
		for k, v in props do
			(l :: any)[k] = v
		end
		return l
	end
	local title = label({ Size = UDim2.new(1, 0, 0, 100), Text = def.Title, TextColor3 = def.Accent, Parent = gui })
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = title
	local rows = {}
	for i = 1, BOARD_ROWS do
		local y = 110 + (i - 1) * 50
		local band = Instance.new("Frame")
		band.Size = UDim2.new(1, -40, 0, 44)
		band.Position = UDim2.fromOffset(20, y)
		band.BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(46, 34, 66) else Color3.fromRGB(36, 26, 54)
		band.BorderSizePixel = 0
		band.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = band
		rows[i] = {
			Rank = label({ Size = UDim2.new(0, 70, 1, -8), Position = UDim2.fromOffset(8, 4), Text = "", TextColor3 = if i <= 3 then def.Accent else Color3.new(1, 1, 1), Parent = band }),
			Name = label({ Size = UDim2.new(0.5, -80, 1, -8), Position = UDim2.fromOffset(84, 4), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Parent = band }),
			Score = label({ Size = UDim2.new(0.42, -20, 1, -8), Position = UDim2.new(0.58, 0, 0, 4), Text = "", TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(190, 240, 255), Parent = band }),
		}
	end
	model.Parent = parent
	return rows
end

local function boardScores(def): { { UserId: number, Value: number } }
	local best: { [number]: number } = {}
	if def.OrderedStore then
		local ok, pages = pcall(function()
			return def.OrderedStore:GetSortedAsync(false, BOARD_ROWS)
		end)
		if ok then
			local ok2, page = pcall(function()
				return pages:GetCurrentPage()
			end)
			if ok2 then
				for _, item in page do
					local id = tonumber(item.key)
					if id then
						best[id] = item.value
					end
				end
			end
		end
	end
	for player, data in profiles do
		local score = def.Score(data)
		if score > 0 and score > (best[player.UserId] or 0) then
			best[player.UserId] = score
		end
	end
	local list = {}
	for id, value in best do
		table.insert(list, { UserId = id, Value = value })
	end
	table.sort(list, function(a, b)
		return a.Value > b.Value
	end)
	return list
end

saveScores = function(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	lastWritten[player] = lastWritten[player] or {}
	for _, def in BOARDS do
		local score = def.Score(data)
		if def.OrderedStore and score > 0 and lastWritten[player][def.Key] ~= score then
			local ok = pcall(function()
				def.OrderedStore:SetAsync(tostring(player.UserId), score)
			end)
			if ok then
				lastWritten[player][def.Key] = score
			end
		end
	end
end

local function startBoards()
	local map = workspace:WaitForChild("Map", 20)
	if not map then
		return
	end
	for _, def in BOARDS do
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(def.Store)
		end)
		def.OrderedStore = if ok then result else nil
		local old = map:FindFirstChild("Leaderboard_" .. def.Key)
		if old then
			old:Destroy()
		end
		def.Rows = buildBoard(map, def)
	end
	while true do
		for _, player in Players:GetPlayers() do
			task.spawn(saveScores, player)
		end
		for _, def in BOARDS do
			local list = boardScores(def)
			for i = 1, BOARD_ROWS do
				local row, entry = def.Rows[i], list[i]
				row.Rank.Text = if entry then "#" .. i else ""
				row.Name.Text = if entry then nameOf(entry.UserId) else ""
				row.Score.Text = if entry then def.Format(entry.Value) else ""
			end
		end
		task.wait(Config.BoardRefreshSeconds)
	end
end

function DataService.Start()
	task.spawn(startBoards)
	Players.PlayerAdded:Connect(DataService.Load)
	for _, player in Players:GetPlayers() do
		task.spawn(DataService.Load, player)
	end
	Players.PlayerRemoving:Connect(DataService.Release)

	game:BindToClose(function()
		local threads = {}
		for _, player in Players:GetPlayers() do
			table.insert(threads, task.spawn(DataService.Save, player, true))
		end
		-- Give saves a moment to finish before the server shuts down.
		local deadline = os.clock() + 20
		while os.clock() < deadline do
			local pending = false
			for _, thread in threads do
				if coroutine.status(thread) ~= "dead" then
					pending = true
				end
			end
			if not pending then
				break
			end
			task.wait(0.25)
		end
	end)

	-- Studio-only test helper: ServerStorage.DevSetData:Invoke(player, "Money", 100000) sets any data field.
	if game:GetService("RunService"):IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "DevSetData"
		dev.OnInvoke = function(player: Player, key: string, value: any)
			return DataService.Update(player, function(d)
				d[key] = value
			end)
		end
		dev.Parent = game:GetService("ServerStorage")
	end

	task.spawn(function() -- today's play time: counts one second for every second the player is really playing
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			for player, data in profiles do
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if humanoid and root then
					local before = lastSample[player]
					lastSample[player] = root.Position
					if humanoid.MoveDirection.Magnitude > 0.1 or (before and (root.Position - before).Magnitude > 1) then
						lastActive[player] = os.clock()
					end
				end
				local newDay = playtimeNewDay(data)
				if os.clock() - (lastActive[player] or 0) < Config.Playtime.AfkSeconds then
					data.Playtime.Seconds += 1
				end
				if newDay or tick % 5 == 0 then
					publish(player)
				end
			end
		end
	end)

	task.spawn(function() -- a new day or week of quests starts while the player is online
		while true do
			task.wait(30)
			for player, data in profiles do
				if refreshQuests(player, data) then
					publish(player)
					notify(player, "New quests are ready!", QUEST_GREEN)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for _, player in Players:GetPlayers() do
				task.spawn(DataService.Save, player)
			end
		end
	end)
end

return DataService
