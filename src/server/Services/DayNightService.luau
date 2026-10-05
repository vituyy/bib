-- Night (5 min): houses are open and full of eggs. Day (20 s): the street closes and everyone on it is sent home.
-- Phase is mirrored to ReplicatedStorage attributes IsNight and PhaseEndsAt (server time) for the client HUD.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlotService = require(script.Parent.PlotService)
local DataService = require(script.Parent.DataService)

local DayNightService = {}

local skipPhase = false -- set by the Admin panel to end the current phase now

-- Ends the current night or day right away (playtest tool).
function DayNightService.Skip()
	skipPhase = true
end

-- The Blood Moon starts at the top of every hour (UTC), so every server runs it at the same moment.
local function nextFullHour(now: number): number
	return (math.floor(now / 3600) + 1) * 3600
end
local nextBloodMoon = nextFullHour(os.time())
local function bloodMoonDue(): boolean
	return os.time() >= nextBloodMoon
end

-- Starts the Blood Moon right away (Admin panel).
function DayNightService.TriggerBloodMoon()
	nextBloodMoon = os.time()
end

-- task.wait that the Admin panel's "skip phase" can cut short, and that a Blood Moon that becomes due can too.
local function waitPhase(seconds: number, endForBloodMoon: boolean)
	skipPhase = false
	local deadline = os.clock() + seconds
	while os.clock() < deadline and not skipPhase and not (endForBloodMoon and bloodMoonDue()) do
		task.wait(0.2)
	end
	skipPhase = false
end

local nightCallbacks: { () -> () } = {}
local dayCallbacks: { () -> () } = {}

function DayNightService.IsNight(): boolean
	return ReplicatedStorage:GetAttribute("IsNight") == true
end

function DayNightService.OnNightStart(callback: () -> ())
	table.insert(nightCallbacks, callback)
end

function DayNightService.OnDayStart(callback: () -> ())
	table.insert(dayCallbacks, callback)
end

local function isInside(zone: BasePart, position: Vector3): boolean
	local offset = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z
end

function DayNightService.Start(map: Instance)
	local street = map:WaitForChild("Street")
	local barrier = street:FindFirstChild("DayBarrier") :: BasePart?
	local zone = street:FindFirstChild("StreetZone") :: BasePart?
	local barrierSign = barrier and barrier:FindFirstChild("BarrierSign")
	local barrierLabel = barrierSign and barrierSign:FindFirstChild("Label") :: TextLabel?

	local function setPhase(isNight: boolean, duration: number)
		ReplicatedStorage:SetAttribute("IsNight", isNight)
		ReplicatedStorage:SetAttribute("PhaseEndsAt", workspace:GetServerTimeNow() + duration)
		Lighting.ClockTime = if isNight then 0 else 7
		if barrier then
			barrier.CanCollide = not isNight
			barrier.Transparency = if isNight then 1 else 0.3
		end
		if barrierLabel then
			barrierLabel.Text = if isNight then "" else "It's daytime! The street opens at night."
		end
	end

	ReplicatedStorage:SetAttribute("NextBloodMoon", nextBloodMoon)
	ReplicatedStorage:SetAttribute("BloodMoon", false)

	-- Warnings: a minute and ten seconds before the Blood Moon.
	task.spawn(function()
		local warned: { [number]: boolean } = {}
		while true do
			task.wait(1)
			local left = nextBloodMoon - os.time()
			if left == Config.BloodMoon.WarningSeconds and not warned[nextBloodMoon] then
				warned[nextBloodMoon] = true
				Remotes.Notify:FireAllClients("🩸 The Blood Moon rises in 1 minute! Owners will be angrier, the eggs better.", Color3.fromRGB(255, 70, 70))
			elseif left == 10 then
				Remotes.Notify:FireAllClients("🩸 Blood Moon in 10 seconds!", Color3.fromRGB(255, 70, 70))
			end
		end
	end)

	task.spawn(function()
		while true do
			local bloodMoon = bloodMoonDue()
			local duration = Config.NightSeconds
			if bloodMoon then
				local startedAt = os.time()
				nextBloodMoon = nextFullHour(startedAt)
				ReplicatedStorage:SetAttribute("NextBloodMoon", nextBloodMoon)
				ReplicatedStorage:SetAttribute("BloodMoonId", startedAt)
				ReplicatedStorage:SetAttribute("BloodMoon", true) -- before the callbacks, so houses fill with Blood Moon eggs
				DataService.BloodMoonStarted()
				duration = Config.BloodMoon.Seconds
			end
			setPhase(true, duration)
			for _, callback in nightCallbacks do
				task.spawn(callback)
			end
			if bloodMoon then
				Remotes.Notify:FireAllClients("🩸 THE BLOOD MOON HAS RISEN! Better eggs, angrier owners.", Color3.fromRGB(255, 60, 60))
			else
				Remotes.Notify:FireAllClients("Night has fallen! Fresh eggs are in every house.", Color3.fromRGB(190, 120, 255))
			end
			waitPhase(duration, not bloodMoon)

			local cutShort = not bloodMoon and bloodMoonDue()
			if bloodMoon then
				ReplicatedStorage:SetAttribute("BloodMoon", false)
				DataService.BloodMoonEnded()
			end
			if cutShort then
				-- The Blood Moon is due while a normal night is running: end the night quietly (eggs dropped, chases
				-- stopped) without sending anybody home, and start the Blood Moon straight away.
				for _, callback in dayCallbacks do
					callback()
				end
			else
				setPhase(false, Config.DaySeconds)
				for _, callback in dayCallbacks do
					callback() -- runs first so carried eggs are dropped before anyone is sent home
				end
				if zone then
					for _, player in Players:GetPlayers() do
						local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root and isInside(zone, root.Position) then
							PlotService.TeleportHome(player)
						end
					end
				end
				Remotes.Notify:FireAllClients("The sun is up! The street is closed until night.", Color3.fromRGB(255, 220, 120))
				waitPhase(Config.DaySeconds, true)
			end
		end
	end)
end

return DayNightService
