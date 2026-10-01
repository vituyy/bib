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
	cleanNumber(data, "Candy", 0)
	cleanNumber(data, "Money", 0)
	cleanNumber(data, "SpeedXp", 0)
	cleanNumber(data, "SpeedLevel", 0, Config.MaxSpeedLevel, true)
	cleanNumber(data, "Rebirths", 0, Config.MaxRebirths, true)
	cleanNumber(data, "Treadmill", 1, #Config.Treadmills, true)
	cleanNumber(data, "Trail", 0, #Config.Trails, true)
	cleanNumber(data, "BaseLevel", 0, #Config.BaseUpgrades, true)

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

local function makeLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, statName in { "Candy", "Money", "Speed" } do
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
		leaderstats.Candy.Value = math.floor(data.Candy)
		leaderstats.Money.Value = math.floor(data.Money)
		leaderstats.Speed.Value = Config.WalkSpeedFor(data.SpeedLevel)
	end
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
	releasing[player] = true
	DataService.Save(player, true)
	profiles[player] = nil
	canSave[player] = nil
	releasing[player] = nil
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

function DataService.Start()
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
