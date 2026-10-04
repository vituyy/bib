-- Builds a player base (fence, hatching stall, pedestals, two Upgrade signs) at a given Pet Capacity level and
-- Hatching Pad level. Pet Capacity makes the pet courtyard deeper; Hatching Pads add pedestals (and a second row).
-- Each Plot model in Workspace.Map.Plots has an "Origin" CFrame attribute: the middle of the base's front edge
-- (the entrance), on the floor, looking out toward the hub centre. The base grows backward (away from the
-- entrance) by Config.BaseDepthStep per upgrade, so the front, the Upgrade sign and the treadmill never move.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BaseBuilder = {}

local W = 44 -- width across the entrance
local GAP = 10 -- entrance gap in the front fence
local PLINTH_H = 1.2
local POST_H = 5

local STONE = Color3.fromRGB(93, 85, 108)
local WOOD = Color3.fromRGB(60, 37, 32)
local PLANK = Color3.fromRGB(125, 72, 42)
local ORANGE = Color3.fromRGB(255, 140, 30)
local PURPLE = Color3.fromRGB(150, 60, 220)

-- Every generated piece is removed before a rebuild; the player's pets, eggs and treadmill are kept.
local BUILT = { "Structure", "Base", "PetArea", "Incubators", "PlayerSpawn", "TreadmillSpot", "PetSlots" }

function BaseBuilder.Depth(petCapLevel: number): number
	return Config.BaseDepth + Config.BaseDepthStep * petCapLevel
end

-- Where the hatching pads stand, measured back from the hatchery's rear wall. Up to 4 pads fit in one row;
-- from the 5th pad a second row opens up under a longer roof.
local function padLayout(count: number): ({ Vector2 }, boolean)
	local back, front = 7, 15.5 -- distance in front of the rear wall
	local row = function(xs: { number }, d: number)
		local out = {}
		for _, x in xs do
			table.insert(out, Vector2.new(x, d))
		end
		return out
	end
	local rows = {
		[2] = { row({ -5, 5 }, back) },
		[3] = { row({ -10, 0, 10 }, back) },
		[4] = { row({ -15, -5, 5, 15 }, back) },
		[5] = { row({ -15, -5, 5, 15 }, back), row({ 0 }, front) },
		[6] = { row({ -10, 0, 10 }, back), row({ -10, 0, 10 }, front) },
		[7] = { row({ -15, -5, 5, 15 }, back), row({ -10, 0, 10 }, front) },
	}
	local chosen = rows[math.clamp(count, 2, 7)]
	local spots = {}
	for _, r in chosen do
		for _, v in r do
			table.insert(spots, v)
		end
	end
	return spots, count >= 5
end

local function part(props: { [string]: any }): BasePart
	local p = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	p.Anchored = true
	p.Material = Enum.Material.Plastic
	p.TopSurface = Enum.SurfaceType.Studs
	p.BottomSurface = Enum.SurfaceType.Inlet
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function deco(props: { [string]: any }): BasePart
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	return part(props)
end

local function light(parent: Instance, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

-- Clones a generated prop from ServerStorage.SpeedShopArt, scaled to `height`, standing on the floor at `cf`.
local function art(name: string, cf: CFrame, height: number, parent: Instance): Model?
	local folder = ServerStorage:FindFirstChild("SpeedShopArt")
	local source = folder and folder:FindFirstChild(name)
	if not source then
		return nil
	end
	local model = source:Clone() :: Model
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * height / size.Y)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	model:PivotTo(cf)
	local box, boxSize = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(cf.X - box.X, cf.Y + boxSize.Y / 2 - box.Y, cf.Z - box.Z))
	model.Parent = parent
	return model
end

local function surfaceText(board: BasePart, lines: { { Name: string, Text: string, Color: Color3, Height: number } })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = gui
	for i, line in lines do
		local l = Instance.new("TextLabel")
		l.Name = line.Name
		l.LayoutOrder = i
		l.Size = UDim2.fromScale(1, line.Height)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = line.Color
		l.TextStrokeTransparency = 0.2
		l.Text = line.Text
		l.Parent = gui
	end
	gui.Parent = board
	return gui
end

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

-- Sign text for the next upgrade of a kind ("Pets" or "Pads") at the given level: "6 > 9  |  $2,000" or "MAX 18".
function BaseBuilder.UpgradeText(kind: string, level: number): string
	local isPets = kind == "Pets"
	local upgrades = if isPets then Config.PetCapacityUpgrades else Config.HatchPadUpgrades
	local now = if isPets then Config.PetSlotsFor(level) else Config.IncubatorsFor(level)
	local nextUpgrade = upgrades[level + 1]
	if not nextUpgrade then
		return string.format("MAX  %d", now)
	end
	return string.format("%d > %d  |  $%s", now, nextUpgrade.Capacity, fmt(nextUpgrade.Price))
end

function BaseBuilder.Build(plot: Model, petCapLevel: number, padLevel: number)
	for _, name in BUILT do
		local old = plot:FindFirstChild(name)
		while old do
			old:Destroy()
			old = plot:FindFirstChild(name)
		end
	end
	local origin: CFrame = plot:GetAttribute("Origin")
	local D = BaseBuilder.Depth(petCapLevel)
	local padCount = Config.IncubatorsFor(padLevel)
	local padSpots, twoRows = padLayout(padCount)
	plot:SetAttribute("PetCapLevel", petCapLevel)
	plot:SetAttribute("PadLevel", padLevel)
	-- Local frame: +X across the base, +Z backward into the base (away from the entrance).
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	local structure = Instance.new("Model")
	structure.Name = "Structure"
	structure.Parent = plot

	-- Logical ownership bounds stay separate from the decorative courtyard.
	local base = deco({ Name = "Base", Size = Vector3.new(W, 1, D), CFrame = at(0, -0.4, D / 2), Transparency = 1, Parent = plot })
	local ownerSign = Instance.new("BillboardGui")
	ownerSign.Name = "OwnerSign"
	ownerSign.Size = UDim2.fromOffset(300, 70)
	ownerSign.StudsOffsetWorldSpace = Vector3.new(0, 20, 0)
	ownerSign.MaxDistance = 150
	local ownerLabel = Instance.new("TextLabel")
	ownerLabel.Name = "Label"
	ownerLabel.Size = UDim2.fromScale(1, 1)
	ownerLabel.BackgroundTransparency = 1
	ownerLabel.Font = Enum.Font.FredokaOne
	ownerLabel.TextSize = 28
	ownerLabel.TextColor3 = Color3.new(1, 1, 1)
	ownerLabel.TextStrokeTransparency = 0
	ownerLabel.Text = "Empty Plot"
	ownerLabel.Parent = ownerSign
	ownerSign.Parent = base
	-- Pets roam the front part of the base, clear of the hatching stall.
	local pavilionDepth = if twoRows then 21 else 12 -- the hatchery grows a second row with the 5th pad
	local roamDepth = math.max(D - (pavilionDepth + 6), 12)
	deco({ Name = "PetArea", Size = Vector3.new(W - 16, 1, roamDepth), CFrame = at(0, -0.2, 3 + roamDepth / 2), Transparency = 1, Parent = plot })

	-- Studded courtyard and inset flagstone path grow from the fixed front edge.
	local function box(name, x, y, z, sx, sy, sz, color, solid, frame)
		return (if solid then part else deco)({
			Name = name, Size = Vector3.new(sx, sy, sz), CFrame = at(x, y, z) * (frame or CFrame.identity),
			Color = color, Parent = structure,
		})
	end
	local dark = Color3.fromRGB(47, 35, 57)
	local trim = Color3.fromRGB(83, 54, 42)
	local gold = Color3.fromRGB(193, 121, 47)
	local roofColors = { Color3.fromRGB(73, 42, 101), Color3.fromRGB(88, 49, 118), Color3.fromRGB(64, 36, 86) }
	local stallFront = D - pavilionDepth
	local stallZ = D - 2.5
	-- Keep the floor flush enough for pets and character movement.
	for ix = 0, 9 do
		for iz = 0, D / 4 - 1 do
			local x, z = -18 + ix * 4, 2 + iz * 4
			box("CourtyardTile", x, 0.1, z, 3.96, 0.4, 3.96,
				if (ix + iz) % 2 == 0 then Color3.fromRGB(65, 78, 55) else Color3.fromRGB(54, 65, 48), true)
		end
	end
	for z = 2, stallFront - 2, 4 do
		for _, x in { -2, 2 } do
			box("PathStone", x, 0.33, z, 3.8, 0.16, 3.75,
				if (math.floor(z / 4) + x) % 2 == 0 then Color3.fromRGB(126, 111, 128) else Color3.fromRGB(108, 95, 113), false)
		end
	end
	for _, side in { -1, 1 } do
		box("PathBorder", side * 4.2, 0.37, stallFront / 2, 0.32, 0.14, stallFront, gold, false)
		box("CourtyardCoping", side * 20.4, 0.5, D / 2, 1, 0.4, D, dark, true)
	end
	-- A shallow timber deck marks the hatching area; upgrades extend its canopy.
	box("HatchDeckFoundation", 0, 0.42, (stallFront + stallZ) / 2, 36, 0.64, stallZ - stallFront + 2, dark, true)
	for z = stallFront, stallZ, 1.5 do
		box("HatchDeckPlank", 0, 0.8, z, 35.4, 0.18, 1.43,
			if math.floor(z / 1.5) % 2 == 0 then PLANK else Color3.fromRGB(112, 63, 40), false)
	end
	box("HatchDeckStep", 0, 0.42, stallFront - 1.4, 35.8, 0.28, 1.5, STONE, true)

	-- Stone-brick plinth around the edge, with the entrance gap at the front
	local function plinth(cx: number, cz: number, sx: number, sz: number)
		part({ Name = "Plinth", Size = Vector3.new(sx, PLINTH_H, sz), CFrame = at(cx, PLINTH_H / 2, cz), Color = STONE, Material = Enum.Material.Plastic, Parent = structure })
	end
	plinth(0, D - 1, W, 2)
	plinth(-W / 2 + 1, D / 2, 2, D - 4)
	plinth(W / 2 - 1, D / 2, 2, D - 4)
	local frontLen = (W - GAP) / 2
	plinth(-GAP / 2 - frontLen / 2, 1, frontLen, 2)
	plinth(GAP / 2 + frontLen / 2, 1, frontLen, 2)

	-- Fence: brick posts with lanterns, two wooden rails between them
	local posts = {}
	local lit = 0
	local function post(x: number, z: number, withLight: boolean)
		local key = string.format("%.1f,%.1f", x, z)
		if posts[key] then
			return
		end
		posts[key] = true
		part({ Name = "Post", Size = Vector3.new(2.2, POST_H, 2.2), CFrame = at(x, PLINTH_H + POST_H / 2, z), Color = STONE, Material = Enum.Material.Brick, Parent = structure })
		part({ Name = "PostCap", Size = Vector3.new(2.8, 0.5, 2.8), CFrame = at(x, PLINTH_H + POST_H + 0.25, z), Color = Color3.fromRGB(80, 74, 82), Parent = structure })

		box("PostFoot", x, 1.6, z, 2.7, 0.55, 2.7, dark, true)
		box("PostCollar", x, 5.8, z, 2.5, 0.35, 2.5, gold, false)
		box("PostInset", x, 3.65, z - 1.12, 1.2, 1.8, 0.09, Color3.fromRGB(56, 47, 67), false)
		local lantern = art("GenLantern", at(x, PLINTH_H + POST_H + 0.5, z), 2.4, structure)
		if lantern and (withLight or (z > 10 and z < D - 10 and math.floor(z / 10) % 2 == 0)) then
			lit += 1
			light(lantern:FindFirstChildWhichIsA("BasePart", true) :: BasePart, Color3.fromRGB(255, 174, 92), 18, if withLight then 1.1 else 0.7)
		end
	end
	local function fence(x0: number, z0: number, x1: number, z1: number)
		local a, b = Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z1)
		local len = (b - a).Magnitude
		local n = math.max(1, math.ceil(len / 11))
		for i = 0, n do
			local p = a:Lerp(b, i / n)
			post(p.X, p.Z, i == 0 or i == n)
		end
		-- Narrow iron pickets and spear tips make the low fence feel like a haunted garden.
		for i = 1, math.floor(len / 2) - 1 do
			local p = a:Lerp(b, i / math.floor(len / 2))
			box("IronPicket", p.X, 3.2, p.Z, 0.18, 3.7, 0.18, dark, false)
			box("PicketTip", p.X, 5.15, p.Z, 0.42, 0.42, 0.42, gold, false, CFrame.Angles(0, 0, math.pi / 4))
		end

		local mid = (a + b) / 2
		local dir = CFrame.lookAt(Vector3.zero, b - a)
		for _, y in { PLINTH_H + 1.5, PLINTH_H + 3.6 } do
			part({
				Name = "Rail",
				Size = Vector3.new(0.5, 0.7, len),
				CFrame = at(mid.X, y, mid.Z) * dir,
				Color = WOOD,
				Material = Enum.Material.Plastic,
				Parent = structure,
			})
		end
	end
	local L, R = -W / 2 + 1, W / 2 - 1
	fence(L, 1, L, D - 1)
	fence(L, D - 1, R, D - 1)
	fence(R, D - 1, R, 1)
	fence(L, 1, -GAP / 2 - 1, 1)
	fence(GAP / 2 + 1, 1, R, 1)

	-- Wooden steps at the entrance
	part({ Name = "Step", Size = Vector3.new(GAP, 0.4, 2.5), CFrame = at(0, 0.2, -1.5), Color = PLANK, Material = Enum.Material.Plastic, Parent = structure })
	part({ Name = "Step", Size = Vector3.new(GAP, 0.8, 2), CFrame = at(0, 0.4, 1), Color = PLANK, Material = Enum.Material.Plastic, Parent = structure })


	-- Layered entrance piers stay fixed as the courtyard lengthens.
	for _, side in { -1, 1 } do
		local x = side * 6
		box("GatePier", x, 4.2, 1, 2.5, 6.4, 2.5, STONE, true)
		box("GatePierCap", x, 7.6, 1, 3.3, 0.45, 3.3, dark, true)
		box("GatePierBand", x, 6.8, 1, 2.7, 0.4, 2.7, gold, false)
		box("GateInset", x, 4.3, -0.3, 1.3, 2.5, 0.1, dark, false)
	end
	-- Dead trees at the corners, jack-o'-lanterns by the entrance
	for _, side in { -1, 1 } do
		art("GenTree", at(side * (W / 2 + 3.5), 0, 3) * CFrame.Angles(0, side * 0.8, 0), 13, structure)
		art("GenTree", at(side * (W / 2 + 3.5), 0, D - 4) * CFrame.Angles(0, side * 2.2, 0), 14, structure)
		local pumpkin = art("GenPumpkin", at(side * (GAP / 2 + 2.2), 0, -2.5) * CFrame.Angles(0, math.pi, 0), 2.6, structure)
		if pumpkin then
			light(pumpkin:FindFirstChildWhichIsA("BasePart", true) :: BasePart, ORANGE, 12, 1.5)
		end
		art("GenPumpkin", at(side * (W / 2 - 4), 0, D - 4), 2.4, structure)
	end

	-- Crates with lit candles along the side fences
	local function crate(x: number, z: number)
		local box = art("GenCrate", at(x, 0, z), 2.6, structure)
		if not box then
			return
		end
		local _, size = box:GetBoundingBox()
		for i, offset in { Vector3.new(-0.5, 0, -0.3), Vector3.new(0.4, 0, 0.2), Vector3.new(0, 0, 0.5) } do
			local h = 0.6 + i * 0.25
			local candle = deco({ Name = "Candle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 0.45, 0.45), CFrame = at(x + offset.X, size.Y + h / 2, z + offset.Z) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(245, 235, 210), Material = Enum.Material.SmoothPlastic, Parent = structure })
			local flame = deco({ Name = "Flame", Size = Vector3.new(0.25, 0.4, 0.25), CFrame = at(x + offset.X, size.Y + h + 0.2, z + offset.Z), Color = Color3.fromRGB(255, 190, 60), Material = Enum.Material.Neon, Parent = structure })
			if i == 1 then
				light(flame, Color3.fromRGB(255, 170, 70), 10, 1.2)
			end
			local _ = candle
		end
	end
	crate(L + 2.8, 5)
	crate(R - 2.8, 5)
	-- Side garden beds occupy the middle bays as the base grows.

	-- Purple spiderwebs in the four corners of the fence
	for _, c in { { L, 1, 1, 1 }, { R, 1, -1, 1 }, { L, D - 1, 1, -1 }, { R, D - 1, -1, -1 } } do
		local x, z, sx, sz = c[1], c[2], c[3], c[4]
		for k = 0, 3 do
			local angle = k * math.pi / 6
			local dir = Vector3.new(sx * math.cos(angle), 0, sz * math.sin(angle))
			local from = Vector3.new(x, PLINTH_H + POST_H, z)
			local to = from + dir * 3.2 - Vector3.new(0, 2.2, 0)
			deco({ Name = "Web", Size = Vector3.new(0.12, 0.12, (to - from).Magnitude), CFrame = origin * CFrame.lookAt((from + to) / 2, to), Color = PURPLE, Material = Enum.Material.Neon, Transparency = 0.25, Parent = structure })
		end
		for _, r in { 1.4, 2.6 } do
			local a = Vector3.new(x + sx * r, PLINTH_H + POST_H - r * 0.69, z)
			local b = Vector3.new(x, PLINTH_H + POST_H - r * 0.69, z + sz * r)
			deco({ Name = "Web", Size = Vector3.new(0.1, 0.1, (b - a).Magnitude), CFrame = origin * CFrame.lookAt((a + b) / 2, b), Color = PURPLE, Material = Enum.Material.Neon, Transparency = 0.35, Parent = structure })
		end
	end


	-- Timber-framed haunted hatchery: open front, layered purple studded roof,
	-- stained glass, warm lanterns and clearly numbered ritual pedestals.
	local stallW = 36
	box("StallWall", 0, 5.5, stallZ, stallW, 9.4, 0.8, dark, true)
	for i = 0, 11 do
		box("WallPanel", -16.5 + i * 3, 5.2, stallZ - 0.46, 2.88, 8.4, 0.22,
			if i % 2 == 0 then PLANK else Color3.fromRGB(106, 58, 39), false)
	end
	box("WallStoneFoot", 0, 1.5, stallZ - 0.6, stallW, 1.3, 0.55, STONE, true)
	for _, x in { -17, 17 } do
		for _, z in { stallFront + 0.5, stallZ - 0.5 } do
			box("PavilionPierFoot", x, 1.4, z, 2.6, 1.6, 2.6, STONE, true)
			box("StallPost", x, 5.65, z, 1.25, 9.7, 1.25, WOOD, true)
			box("PavilionCapital", x, 10.1, z, 2, 0.55, 2, gold, false)
			box("PierInset", x, 5.4, z - 0.67, 0.55, 4, 0.1, PLANK, false)
		end
		box("SideSill", x, 2.25, (stallFront + stallZ) / 2, 0.7, 0.65, stallZ - stallFront, WOOD, true)
		box("SideBeam", x, 10.3, (stallFront + stallZ) / 2, 1.3, 0.85, stallZ - stallFront + 1.5, WOOD, true)
		for _, z in { stallFront + 2.2, stallZ - 2.2 } do
			box("CornerBrace", x - math.sign(x) * 0.8, 8.9, z, 0.65, 3.3, 0.7, WOOD, false, CFrame.Angles(0, 0, math.sign(x) * math.pi / 5))
		end
	end
	for _, y in { 2.6, 10.1 } do
		box("RearCrossBeam", 0, y, stallZ - 0.8, stallW, 0.65, 0.55, WOOD, false)
	end
	for _, x in { -12, -6, 0, 6, 12 } do
		box("RearTimber", x, 6.35, stallZ - 0.7, 0.5, 7.3, 0.5, WOOD, false)
	end
	-- Three jewel-like windows visible above the eggs, with stone mullions.
	for _, x in { -10, 0, 10 } do
		box("WindowFrame", x, 6.7, stallZ - 0.83, 4.1, 4.6, 0.36, gold, false)
		box("StainedGlass", x, 6.7, stallZ - 1.04, 3.5, 4, 0.12, Color3.fromRGB(91, 164, 137), false)
		box("WindowMullion", x, 6.7, stallZ - 1.13, 0.22, 4, 0.12, dark, false)
		box("WindowMullion", x, 6.65, stallZ - 1.13, 3.5, 0.22, 0.12, dark, false)
		box("WindowCrown", x, 9.12, stallZ - 0.9, 1.1, 1.1, 0.35, gold, false, CFrame.Angles(0, 0, math.pi / 4))
	end
	local roofD = stallZ - stallFront + 4
	local roofC = (stallZ + stallFront) / 2
	local rise, halfWidth, eaveY = 5.5, 19.5, 10.8
	local slope = math.atan(rise / halfWidth)
	local slopeLength = math.sqrt(halfWidth * halfWidth + rise * rise)
	local zCount = math.ceil(roofD / 3.2)
	for _, side in { -1, 1 } do
		local rotation = CFrame.Angles(0, 0, -side * slope)
		box("RoofUnderlay", side * halfWidth / 2, eaveY + rise / 2, roofC, slopeLength, 0.65, roofD, dark, true, rotation)
		for row = 0, 4 do
			local t = (row + 0.5) / 5
			for col = 0, zCount - 1 do
				local z = roofC - roofD / 2 + (col + 0.5) * roofD / zCount
				box("RoofShingle", side * halfWidth * t, eaveY + rise * (1 - t) + 0.4, z,
					slopeLength / 5 + 0.08, 0.23, roofD / zCount - 0.09, roofColors[(row + col) % #roofColors + 1], false, rotation)
			end
		end
		box("EaveTrim", side * halfWidth, eaveY, roofC, 0.7, 0.8, roofD + 0.8, WOOD, false)
		for _, z in { roofC - roofD / 2, roofC + roofD / 2 } do
			box("GableFascia", side * halfWidth / 2, eaveY + rise / 2 + 0.24, z,
				slopeLength + 0.5, 0.5, 0.7, gold, false, rotation)
		end
	end
	box("RoofRidge", 0, eaveY + rise + 0.52, roofC, 1.2, 0.65, roofD + 1.2, WOOD, false)
	box("StallBeam", 0, 10.05, stallFront + 0.5, stallW + 1, 0.8, 0.8, WOOD, true)
	box("GableKingPost", 0, 13, stallFront - 1.5, 0.7, 5.7, 0.65, WOOD, false)
	-- Roof finials and witch's hat repeat the houses' playful Halloween silhouette.
	for _, z in { roofC - roofD / 2, roofC + roofD / 2 } do
		box("RidgeFinial", 0, 17.35, z, 0.7, 2, 0.7, gold, false)
	end
	art("GenHat", at(0, 16.7, stallFront - 1.4) * CFrame.Angles(0, math.pi, 0), 4.5, structure)
	local board = box("HatchSign", 0, 11.2, stallFront - 1.9, 18, 3.25, 0.6, dark, false)
	surfaceText(board, {
		{ Name = "Title", Text = "HATCH EGGS", Color = Color3.fromRGB(255, 203, 97), Height = 0.61 },
		{ Name = "Capacity", Text = tostring(padCount) .. " HATCHING PADS", Color = Color3.fromRGB(212, 193, 231), Height = 0.25 },
	})
	for _, y in { 9.5, 12.9 } do box("SignFrame", 0, y, stallFront - 2.05, 18.8, 0.25, 0.3, gold, false) end
	for _, x in { -9.25, 9.25 } do box("SignFrame", x, 11.2, stallFront - 2.05, 0.25, 3.6, 0.3, gold, false) end
	for i = 0, 15 do
		local x = -15 + i * 2
		local sag = 0.8 * (1 - (x / 15) ^ 2)
		box("BuntingCord", x, 9.55 - sag, stallFront - 0.4, 2.1, 0.08, 0.12, gold, false)
		box("Bunting", x, 9.1 - sag, stallFront - 0.4, 0.75, 0.85, 0.16,
			if i % 2 == 0 then ORANGE else PURPLE, false, CFrame.Angles(0, 0, math.pi / 4))
	end
	for _, x in { -14.5, 14.5 } do
		local lantern = art("GenLantern", at(x, 6.2, stallFront + 1), 2.7, structure)
		if lantern then light(lantern:FindFirstChildWhichIsA("BasePart", true), Color3.fromRGB(255, 166, 70), 15, 1.2) end
		box("Chain", x, 9.2, stallFront + 1, 0.12, 1.4, 0.12, dark, false)
	end
	-- Border beds frame the pet courtyard, leaving its middle and entrance open.
	for _, side in { -1, 1 } do
		for z = 10, stallFront - 5, 12 do
			box("GardenBed", side * 18.5, 0.85, z, 2.8, 0.7, 5, STONE, true)
			box("GardenSoil", side * 18.5, 1.24, z, 2.35, 0.15, 4.5, Color3.fromRGB(43, 33, 36), false)
			art("GenPumpkin", at(side * 18.5, 1.3, z - 0.8), 1.8, structure)
			for i = 0, 2 do
				box("SpookyGrass", side * 18.5 + (i - 1) * 0.55, 1.8, z + 1.2, 0.16, 1.1 + i * 0.25, 0.18,
					Color3.fromRGB(104, 115, 69), false, CFrame.Angles(0, 0, (i - 1) * 0.3))
			end
		end
	end

	local pads = Instance.new("Folder")
	pads.Name = "Incubators"
	pads.Parent = plot
	for n, rel in padSpots do
		local s = Vector2.new(rel.X, D - rel.Y) -- rel.Y is the distance in front of the rear wall
		local cylinderRotation = CFrame.Angles(0, 0, math.pi / 2)
		deco({ Name = "PedestalFoot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, 6.5, 6.5),
			CFrame = at(s.X, 1.05, s.Y) * cylinderRotation, Color = dark, Parent = structure })
		local pad = part({ Name = "Incubator" .. n, Size = Vector3.new(4.4, 1.05, 4.4), CFrame = at(s.X, 1.43, s.Y),
			Color = STONE, Parent = pads })
		deco({ Name = "PedestalRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 5.4, 5.4),
			CFrame = at(s.X, 1.4, s.Y) * cylinderRotation, Color = gold, Parent = structure })
		deco({ Name = "PedestalGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 3.9, 3.9),
			CFrame = at(s.X, 1.99, s.Y) * cylinderRotation, Color = Color3.fromRGB(191, 120, 247),
			Material = Enum.Material.Neon, Parent = structure })
		for i = 0, 3 do
			local a = i * math.pi / 2
			box("PedestalRune", s.X + math.cos(a) * 2.65, 1.32, s.Y + math.sin(a) * 2.65, 0.38, 0.13, 0.38, ORANGE, false,
				CFrame.Angles(0, math.pi / 4, 0))
		end
		local plaque = box("PadPlaque", s.X, 1.13, s.Y - 2.7, 1.8, 0.8, 0.16, dark, false)
		surfaceText(plaque, { { Name = "Number", Text = string.format("%02d", n), Color = Color3.fromRGB(255, 212, 120), Height = 0.9 } })
	end
	-- Two upgrade signs side by side on the left of the entrance, away from the treadmill on the right (the
	-- prompts are wired by PlotService): PET CAPACITY nearest the entrance, HATCHING PADS beyond it. Each one upgrades only its own capacity.
	local function upgradeSign(kind: string, level: number, signX: number, title: string, icons: string, color: Color3)
		local signZ = -4
		for _, dx in { -4.2, 4.2 } do
			part({ Name = "SignPost", Size = Vector3.new(0.9, 9, 0.9), CFrame = at(signX + dx, 4.5, signZ + 0.4), Color = WOOD, Material = Enum.Material.Plastic, Parent = structure })
		end
		local board = part({ Name = "UpgradeBoard" .. kind, Size = Vector3.new(11, 6, 0.6), CFrame = at(signX, 6.5, signZ), Color = PLANK, Material = Enum.Material.Plastic, Parent = structure })
		for _, y in { 3.4, 9.6 } do box("UpgradeFrame", signX, y, signZ - 0.38, 11.8, 0.3, 0.4, gold, false) end
		for _, dx in { -5.75, 5.75 } do box("UpgradeFrame", signX + dx, 6.5, signZ - 0.38, 0.3, 6.5, 0.4, dark, false) end
		board:SetAttribute("UpgradeKind", kind)
		surfaceText(board, {
			{ Name = "Title", Text = title, Color = color, Height = 0.34 },
			{ Name = "Icons", Text = icons, Color = Color3.fromRGB(120, 255, 120), Height = 0.3 },
			{ Name = "Info", Text = BaseBuilder.UpgradeText(kind, level), Color = Color3.new(1, 1, 1), Height = 0.26 },
		})
		local arrow = deco({ Name = "Arrow", ClassName = "WedgePart", Size = Vector3.new(0.4, 1.6, 2.4), CFrame = at(signX + 4.6, 10.4, signZ - 0.2) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(80, 230, 90), Material = Enum.Material.Neon, Parent = structure })
		local _ = arrow
		local upgrades = if kind == "Pets" then Config.PetCapacityUpgrades else Config.HatchPadUpgrades
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "UpgradePrompt"
		prompt.ActionText = if kind == "Pets" then "Upgrade Pet Capacity" else "Add Hatching Pad"
		prompt.ObjectText = BaseBuilder.UpgradeText(kind, level)
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Enabled = upgrades[level + 1] ~= nil
		prompt:SetAttribute("UpgradeKind", kind)
		prompt.Parent = board
	end
	upgradeSign("Pets", petCapLevel, -GAP / 2 - 9, "PET CAPACITY", "\u{1F43E} \u{2B06}\u{FE0F}", Color3.fromRGB(255, 160, 220))
	upgradeSign("Pads", padLevel, -GAP / 2 - 22, "HATCHING PADS", "\u{1F95A} \u{2B06}\u{FE0F}", Color3.fromRGB(255, 220, 90))

	part({ Name = "PlayerSpawn", Size = Vector3.new(1, 1, 1), CFrame = at(0, 4, 7), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = plot })
	-- Treadmill just outside the base, right of the entrance, running toward the hub centre.
	part({ Name = "TreadmillSpot", Size = Vector3.new(1, 1, 1), CFrame = at(GAP / 2 + 9, 1, -14), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = plot })

	plot.PrimaryPart = base
	return plot
end

return BaseBuilder
