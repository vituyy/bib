-- Loads, caches and saves player data, and mirrors it to leaderstats and the client.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DataService = {}

local profiles: { [Player]: { [string]: any } } = {}
local canSave: { [Player]: boolean } = {}
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

function DataService.Load(player: Player)
	loadedSignals[player] = loadedSignals[player] or Instance.new("BindableEvent")
	makeLeaderstats(player)

	local data
	if store then
		local ok, result = withRetries(function()
			return store:GetAsync(keyFor(player))
		end)
		if ok then
			data = result
			canSave[player] = true
		else
			warn("[DataService] Failed to load data for", player.Name, result)
			Remotes.Notify:FireClient(player, "Could not load your save. Progress this session will NOT be saved.", Color3.fromRGB(255, 80, 80))
		end
	end

	if not player.Parent then
		return -- left while loading
	end

	profiles[player] = reconcile(if type(data) == "table" then data else deepCopy(Config.StartingData))
	-- Saves from before the Index: pets already on the base count as discovered.
	for _, petId in profiles[player].Pets do
		if not table.find(profiles[player].Discovered, petId) then
			table.insert(profiles[player].Discovered, petId)
		end
	end
	loadedSignals[player]:Fire()
	publish(player)
end

function DataService.Save(player: Player)
	local data = profiles[player]
	if not (store and data and canSave[player]) then
		return
	end
	local snapshot = deepCopy(data)
	local ok, err = withRetries(function()
		return store:UpdateAsync(keyFor(player), function()
			return snapshot
		end)
	end)
	if not ok then
		warn("[DataService] Failed to save data for", player.Name, err)
	end
end

function DataService.Release(player: Player)
	DataService.Save(player)
	profiles[player] = nil
	canSave[player] = nil
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
			table.insert(threads, task.spawn(DataService.Save, player))
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
