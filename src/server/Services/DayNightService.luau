-- Night (5 min): houses are open and full of eggs. Day (20 s): the street closes and everyone on it is sent home.
-- Phase is mirrored to ReplicatedStorage attributes IsNight and PhaseEndsAt (server time) for the client HUD.
-- Blood Moon: every full hour (Config.BloodMoon) the night is a blood moon. The night before it is cut short
-- so its day ends right at :00. Attributes: BloodMoon (true while it lasts), BloodMoonAt (next start).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlotService = require(script.Parent.PlotService)

local DayNightService = {}

local skipPhase = false -- set by the Admin panel to end the current phase now
local forceBloodMoon = false -- set by the Admin panel: the next night is a Blood Moon

-- Starts a Blood Moon now (playtest tool): ends the current phase, and the next night is red.
function DayNightService.ForceBloodMoon()
	forceBloodMoon = true
	skipPhase = true
end

function DayNightService.IsBloodMoon(): boolean
	return ReplicatedStorage:GetAttribute("BloodMoon") == true
end

-- Ends the current night or day right away (playtest tool).
function DayNightService.Skip()
	skipPhase = true
end

-- task.wait that the Admin panel's "skip phase" can cut short.
local function waitPhase(seconds: number)
	skipPhase = false
	local deadline = os.clock() + seconds
	while os.clock() < deadline and not skipPhase do
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

	-- Blood Moon look for everyone: red fog, sky and light, and a huge red moon. Restored when it ends.
	local saved: { [Instance]: { [string]: any } } = {}
	local RED_LOOK: { [string]: { [string]: any } } = {
		Lighting = { Ambient = Color3.fromRGB(110, 30, 35), OutdoorAmbient = Color3.fromRGB(140, 40, 45), FogColor = Color3.fromRGB(70, 5, 10), FogStart = 40, FogEnd = 700 },
		Atmosphere = { Color = Color3.fromRGB(200, 40, 40), Decay = Color3.fromRGB(110, 10, 15), Density = 0.42, Glare = 0.6, Haze = 2.2 },
		ColorCorrection = { TintColor = Color3.fromRGB(255, 190, 190), Saturation = 0.25, Contrast = 0.18 },
		Sky = { MoonAngularSize = 60, StarCount = 1500 },
	}
	local moon: BasePart? = nil
	local function setBloodLook(on: boolean)
		for name, props in RED_LOOK do
			local inst = if name == "Lighting" then Lighting else Lighting:FindFirstChild(name)
			if inst then
				if on then
					saved[inst] = saved[inst] or {}
					for prop, value in props do
						if saved[inst][prop] == nil then
							saved[inst][prop] = (inst :: any)[prop]
						end
						(inst :: any)[prop] = value
					end
				elseif saved[inst] then
					for prop, value in saved[inst] do
						(inst :: any)[prop] = value
					end
					saved[inst] = nil
				end
			end
		end
		if on and not moon then
			-- A red disc high over the street; a billboard is not hidden by fog like a part would be.
			local anchor = Instance.new("Part")
			anchor.Name = "BloodMoon"
			anchor.Size = Vector3.one
			anchor.Transparency = 1
			anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
			anchor.Position = Vector3.new(40, 520, 1400)
			local board = Instance.new("BillboardGui")
			board.Size = UDim2.fromScale(330, 330)
			board.LightInfluence = 0
			board.MaxDistance = 100000
			board.Parent = anchor
			local glow = Instance.new("Frame")
			glow.AnchorPoint = Vector2.new(0.5, 0.5)
			glow.Position = UDim2.fromScale(0.5, 0.5)
			glow.Size = UDim2.fromScale(1, 1)
			glow.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
			glow.BackgroundTransparency = 0.75
			glow.Parent = board
			Instance.new("UICorner", glow).CornerRadius = UDim.new(0.5, 0)
			local disc = glow:Clone()
			disc.Size = UDim2.fromScale(0.72, 0.72)
			disc.BackgroundColor3 = Color3.fromRGB(200, 15, 20)
			disc.BackgroundTransparency = 0
			disc.Parent = board
			local gradient = Instance.new("UIGradient")
			gradient.Rotation = 35
			gradient.Color = ColorSequence.new(Color3.fromRGB(255, 120, 100), Color3.fromRGB(120, 0, 10))
			gradient.Parent = disc
			anchor.Parent = workspace
			moon = anchor
		elseif not on and moon then
			moon:Destroy()
			moon = nil
		end
	end

	local function now(): number
		return workspace:GetServerTimeNow()
	end

	local function startNight(duration: number, bloodMoon: boolean)
		ReplicatedStorage:SetAttribute("BloodMoon", bloodMoon)
		ReplicatedStorage:SetAttribute("BloodMoonAt", if bloodMoon then Config.NextBloodMoon(now() + 5) else Config.NextBloodMoon(now()))
		setBloodLook(bloodMoon)
		setPhase(true, duration)
		for _, callback in nightCallbacks do
			task.spawn(callback)
		end
		if bloodMoon then
			Remotes.Notify:FireAllClients("🩸 THE BLOOD MOON RISES! Rare eggs, bloody eggs and red candy... but the owners kill anyone they catch!", Color3.fromRGB(255, 40, 40))
		else
			Remotes.Notify:FireAllClients("Night has fallen! Fresh eggs are in every house.", Color3.fromRGB(190, 120, 255))
		end
		waitPhase(duration)
	end

	task.spawn(function()
		local every, length = Config.BloodMoon.EverySeconds, Config.BloodMoon.Seconds
		while true do
			local into = now() % every
			if forceBloodMoon or into < length - 5 then
				-- Inside the Blood Moon hour window (or forced by an admin): a red night until it ends.
				local duration = if forceBloodMoon then length else length - into
				forceBloodMoon = false
				startNight(duration, true)
			else
				-- A normal night, cut short so that night plus day end exactly when the next Blood Moon starts.
				local untilEvent = every - into
				local nightLength = math.min(Config.NightSeconds, untilEvent - Config.DaySeconds)
				if nightLength < 60 then
					-- Too little time for a real night: a longer day straight into the Blood Moon.
					ReplicatedStorage:SetAttribute("BloodMoonAt", Config.NextBloodMoon(now()))
					setPhase(false, untilEvent)
					waitPhase(untilEvent)
					continue
				end
				startNight(nightLength, false)
			end

			ReplicatedStorage:SetAttribute("BloodMoon", false)
			setBloodLook(false)
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
			waitPhase(Config.DaySeconds)
		end
	end)
end

return DayNightService
