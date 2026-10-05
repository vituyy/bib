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
		Spot = Vector3.new(-8, 0, -22),
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
		Spot = Vector3.new(68, 0, -22),
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
	local facing = Vector3.new(30, 0, -30) -- the lobby spawn: the boards turn toward it
	local center = def.Spot + Vector3.new(0, 11, 0)
	local cf = CFrame.lookAt(center, Vector3.new(facing.X, center.Y, facing.Z))
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
	for _, side in { -1, 1 } do
		block("Post", Vector3.new(1.2, 12.4, 1.2), cf * CFrame.new(side * 9, -4.6, 0.9), Color3.fromRGB(70, 45, 30), Enum.Material.Wood)
	end

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
