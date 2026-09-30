-- Builds a player base (fence, hatching stall, pedestals, Upgrade sign) at a given upgrade level.
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

local STONE = Color3.fromRGB(112, 104, 112)
local WOOD = Color3.fromRGB(92, 42, 30)
local PLANK = Color3.fromRGB(125, 72, 42)
local ORANGE = Color3.fromRGB(255, 140, 30)
local PURPLE = Color3.fromRGB(150, 60, 220)

-- Every generated piece is removed before a rebuild; the player's pets, eggs and treadmill are kept.
local BUILT = { "Structure", "Base", "PetArea", "Incubators", "PlayerSpawn", "TreadmillSpot", "PetSlots" }

function BaseBuilder.Depth(level: number): number
	return Config.BaseDepth + Config.BaseDepthStep * level
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

function BaseBuilder.UpgradeText(level: number): string
	local nextUpgrade = Config.BaseUpgrades[level + 1]
	if not nextUpgrade then
		return string.format("Level %d  |  MAX", level + 1)
	end
	return string.format("Level %d  >  $%s", level + 1, fmt(nextUpgrade.Price))
end

function BaseBuilder.Build(plot: Model, level: number)
	for _, name in BUILT do
		local old = plot:FindFirstChild(name)
		while old do
			old:Destroy()
			old = plot:FindFirstChild(name)
		end
	end
	local origin: CFrame = plot:GetAttribute("Origin")
	local D = BaseBuilder.Depth(level)
	plot:SetAttribute("Level", level)
	-- Local frame: +X across the base, +Z backward into the base (away from the entrance).
	local function at(x: number, y: number, z: number): CFrame
		return origin * CFrame.new(x, y, z)
	end

	local structure = Instance.new("Model")
	structure.Name = "Structure"
	structure.Parent = plot

	-- Floor area (invisible: the tattersall floor shows through). Pets, the owner check and the owner sign use it.
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
	local roamDepth = math.max(D - 26, 12)
	deco({ Name = "PetArea", Size = Vector3.new(W - 8, 1, roamDepth), CFrame = at(0, -0.4, 3 + roamDepth / 2), Transparency = 1, Parent = plot })

	-- Stone-brick plinth around the edge, with the entrance gap at the front
	local function plinth(cx: number, cz: number, sx: number, sz: number)
		part({ Name = "Plinth", Size = Vector3.new(sx, PLINTH_H, sz), CFrame = at(cx, PLINTH_H / 2, cz), Color = STONE, Material = Enum.Material.Brick, Parent = structure })
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
		local lantern = art("GenLantern", at(x, PLINTH_H + POST_H + 0.5, z), 2.4, structure)
		if withLight and lantern then
			lit += 1
			light(lantern:FindFirstChildWhichIsA("BasePart", true) :: BasePart, Color3.fromRGB(255, 160, 60), 18, 1.4)
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
		local mid = (a + b) / 2
		local dir = CFrame.lookAt(Vector3.zero, b - a)
		for _, y in { PLINTH_H + 1.5, PLINTH_H + 3.6 } do
			part({
				Name = "Rail",
				Size = Vector3.new(0.5, 0.7, len),
				CFrame = at(mid.X, y, mid.Z) * dir,
				Color = WOOD,
				Material = Enum.Material.Wood,
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
	part({ Name = "Step", Size = Vector3.new(GAP, 0.4, 2.5), CFrame = at(0, 0.2, -1.5), Color = PLANK, Material = Enum.Material.WoodPlanks, Parent = structure })
	part({ Name = "Step", Size = Vector3.new(GAP, 0.8, 2), CFrame = at(0, 0.4, 1), Color = PLANK, Material = Enum.Material.WoodPlanks, Parent = structure })

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
	crate(L + 2.8, D / 2)
	crate(R - 2.8, D / 2)

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

	-- HATCH EGGS stall at the back: plank wall, two posts, peaked roof, sign with a witch hat, bunting, lanterns
	local stallZ = D - 2.5 -- back wall
	local stallFront = D - 11
	local stallW = 32
	part({ Name = "StallWall", Size = Vector3.new(stallW, 10, 0.8), CFrame = at(0, 5, stallZ), Color = PLANK, Material = Enum.Material.WoodPlanks, Parent = structure })
	for _, x in { -stallW / 2 + 0.6, stallW / 2 - 0.6 } do
		part({ Name = "StallPost", Size = Vector3.new(1.2, 10, 1.2), CFrame = at(x, 5, stallFront + 0.6), Color = WOOD, Material = Enum.Material.Wood, Parent = structure })
		part({ Name = "StallSide", Size = Vector3.new(0.6, 4, stallZ - stallFront), CFrame = at(x, 2, (stallZ + stallFront) / 2), Color = PLANK, Material = Enum.Material.WoodPlanks, Parent = structure })
	end
	local roofD = stallZ - stallFront + 3
	local roofC = (stallZ + stallFront) / 2
	local rise = 4
	for _, side in { -1, 1 } do
		part({
			ClassName = "WedgePart",
			Name = "StallRoof",
			Size = Vector3.new(stallW + 3, rise, roofD / 2),
			CFrame = at(0, 10 + rise / 2, roofC + side * roofD / 4) * (if side == 1 then CFrame.Angles(0, math.pi, 0) else CFrame.identity),
			Color = Color3.fromRGB(105, 45, 35),
			Material = Enum.Material.WoodPlanks,
			Parent = structure,
		})
	end
	part({ Name = "StallBeam", Size = Vector3.new(stallW + 1, 0.8, 0.8), CFrame = at(0, 9.6, stallFront + 0.6), Color = WOOD, Material = Enum.Material.Wood, Parent = structure })
	local board = part({ Name = "HatchSign", Size = Vector3.new(17, 3.6, 0.6), CFrame = at(0, 12.2, stallFront - 1.1), Color = Color3.fromRGB(70, 35, 25), Material = Enum.Material.Wood, Parent = structure })
	surfaceText(board, { { Name = "Title", Text = "HATCH EGGS", Color = ORANGE, Height = 0.9 } })
	art("GenHat", at(0, 14, stallFront - 1.1) * CFrame.Angles(0, math.pi, 0), 5, structure)
	local flags = 16
	for i = 0, flags - 1 do
		local x = -stallW / 2 + 1 + i * (stallW - 2) / (flags - 1)
		deco({ Name = "Bunting", Size = Vector3.new(1.1, 1.1, 0.15), CFrame = at(x, 9.2, stallFront - 0.1) * CFrame.Angles(0, 0, math.pi / 4), Color = if i % 2 == 0 then ORANGE else PURPLE, Parent = structure })
	end
	for _, x in { -stallW / 2 + 3, stallW / 2 - 3 } do
		local lantern = art("GenLantern", at(x, 6.6, stallFront + 1), 2.4, structure)
		if lantern then
			light(lantern:FindFirstChildWhichIsA("BasePart", true) :: BasePart, Color3.fromRGB(255, 160, 60), 16, 1.5)
		end
		deco({ Name = "Chain", Size = Vector3.new(0.15, 1.1, 0.15), CFrame = at(x, 9.1, stallFront + 1), Color = Color3.fromRGB(40, 40, 45), Parent = structure })
	end
	local fill = deco({ Name = "PurpleFill", Size = Vector3.new(1, 1, 1), CFrame = at(0, 12, D / 2), Transparency = 1, Parent = structure })
	light(fill, Color3.fromRGB(150, 80, 255), 40, 0.8)

	-- Hatching pedestals: 3 under the stall, one more in front of it per upgrade
	local pads = Instance.new("Folder")
	pads.Name = "Incubators"
	pads.Parent = plot
	local spots = {
		Vector2.new(-10, D - 7), Vector2.new(0, D - 7), Vector2.new(10, D - 7),
		Vector2.new(-15, D - 16), Vector2.new(15, D - 16), Vector2.new(-5, D - 16), Vector2.new(5, D - 16),
	}
	for n = 1, Config.IncubatorsFor(level) do
		local s = spots[n]
		if not s then
			break
		end
		part({ Name = "Incubator" .. n, Size = Vector3.new(4.4, 1.6, 4.4), CFrame = at(s.X, 0.8, s.Y), Color = Color3.fromRGB(72, 66, 78), Material = Enum.Material.Slate, Parent = pads })
		local ring = deco({ Name = "PedestalRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 6.4, 6.4), CFrame = at(s.X, 0.2, s.Y) * CFrame.Angles(0, 0, math.pi / 2), Color = ORANGE, Material = Enum.Material.Neon, Parent = structure })
		deco({ Name = "PedestalGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 3.8, 3.8), CFrame = at(s.X, 1.62, s.Y) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromRGB(255, 215, 80), Material = Enum.Material.Neon, Parent = structure })
		light(ring, Color3.fromRGB(255, 170, 60), 9, 1.2)
	end

	-- UPGRADE BASE sign beside the entrance (the prompt is wired by PlotService)
	local signX, signZ = -GAP / 2 - 9, -4
	for _, dx in { -4.2, 4.2 } do
		part({ Name = "SignPost", Size = Vector3.new(0.9, 9, 0.9), CFrame = at(signX + dx, 4.5, signZ + 0.4), Color = WOOD, Material = Enum.Material.Wood, Parent = structure })
	end
	local upgradeBoard = part({ Name = "UpgradeBoard", Size = Vector3.new(11, 6, 0.6), CFrame = at(signX, 6.5, signZ), Color = PLANK, Material = Enum.Material.WoodPlanks, Parent = structure })
	upgradeBoard:SetAttribute("UpgradeBase", true)
	surfaceText(upgradeBoard, {
		{ Name = "Title", Text = "UPGRADE BASE", Color = Color3.fromRGB(255, 220, 90), Height = 0.34 },
		{ Name = "Icons", Text = "\u{1FA99} \u{1F528} \u{2B06}\u{FE0F}", Color = Color3.fromRGB(120, 255, 120), Height = 0.3 },
		{ Name = "Info", Text = BaseBuilder.UpgradeText(level), Color = Color3.new(1, 1, 1), Height = 0.26 },
	})
	local coin = deco({ Name = "Coin", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 2.4, 2.4), CFrame = at(signX - 4.6, 9.8, signZ - 0.2) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Metal, Parent = structure })
	local arrow = deco({ Name = "Arrow", ClassName = "WedgePart", Size = Vector3.new(0.4, 1.6, 2.4), CFrame = at(signX + 4.6, 10.4, signZ - 0.2) * CFrame.Angles(0, math.pi / 2, 0), Color = Color3.fromRGB(80, 230, 90), Material = Enum.Material.Neon, Parent = structure })
	local _ = coin and arrow
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradePrompt"
	prompt.ActionText = "Upgrade Base"
	prompt.ObjectText = BaseBuilder.UpgradeText(level)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Enabled = Config.BaseUpgrades[level + 1] ~= nil
	prompt:SetAttribute("UpgradeBase", true)
	prompt.Parent = upgradeBoard

	part({ Name = "PlayerSpawn", Size = Vector3.new(1, 1, 1), CFrame = at(0, 4, 7), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = plot })
	-- Treadmill just outside the base, right of the entrance, running toward the hub centre.
	part({ Name = "TreadmillSpot", Size = Vector3.new(1, 1, 1), CFrame = at(GAP / 2 + 9, 1, -14), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = plot })

	plot.PrimaryPart = base
	return plot
end

return BaseBuilder
