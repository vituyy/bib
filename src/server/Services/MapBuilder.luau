-- Builds the placeholder studs-style Halloween map when the place has no Workspace.Map yet.
-- Layout: a walled hub with 6 bases and 2 shops, and one long street with 9 houses (one house per level).
-- Once you build your own map in Studio, keep the same names (see README "Map contract")
-- and this builder will skip itself.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Art = require(ReplicatedStorage.Shared.Art)

local MapBuilder = {}

local PLOT_COUNT = Config.MaxPlayers
local PLOT_SPACING = 66
local BASE_SIZE = 56
local HUB_HALF_W = 215
local HUB_MIN_Z = -260
local BASE_Z = HUB_MIN_Z + 12 + BASE_SIZE / 2 -- base centre, along the back wall of the hub
local SHOP_SCALE = 1.5 -- shops are built at normal size, then scaled up

local STRIP_MIN_X, STRIP_MAX_X = -65, 140 -- the street strip
local ROAD_MIN_X, ROAD_MAX_X = -60, -24
local HOUSE_FRONT_X = -16 -- the door side of every house faces the road
local STREET_START_Z = 4
local LOT_GAP = 70 -- open ground between houses: longer lots mean a longer, harder run home
local LOT_LENGTH_SCALE = 1.5 -- each lot is this much longer along the street than house + gap

local HOUSE_W, HOUSE_D, FLOOR_H = 44, 36, 14 -- W runs along the street, D goes back from the road
local HOUSE_SCALE = 1.75 -- houses keep the same plan and are scaled up by this much

local WALL_H = 20

local COLORS = {
	Ground = Color3.fromRGB(40, 48, 36),
	Road = Color3.fromRGB(55, 52, 60),
	Hub = Color3.fromRGB(58, 52, 70),
	Wall = Color3.fromRGB(45, 38, 55),
	Base = Color3.fromRGB(75, 65, 95),
	LevelLine = Color3.fromRGB(70, 255, 90),
	Roof = Color3.fromRGB(35, 30, 42),
	Floor = Color3.fromRGB(95, 65, 45),
}

-- One look per house, easiest (1) to hardest (9). RoofType: gable, battlements or stepped.
-- Yard: props from Assets.Props placed around the house (see the Yard section in buildHouse).
local HOUSE_STYLES = {
	{ Name = "Mummy's Tomb", Wall = Color3.fromRGB(196, 160, 100), Roof = Color3.fromRGB(150, 115, 60), Trim = Color3.fromRGB(230, 190, 60), Glow = Color3.fromRGB(255, 200, 90), RoofType = "stepped", Yard = { PumpkinPile = 2, DeadTree = 1 } },
	{ Name = "Witch's Cottage", Wall = Color3.fromRGB(80, 105, 70), Roof = Color3.fromRGB(90, 40, 120), Trim = Color3.fromRGB(60, 40, 30), Glow = Color3.fromRGB(150, 255, 90), RoofType = "gable", RoofPitch = 0.6, Chimney = true, Yard = { Cauldron = 2, DeadTree = 2 } },
	{ Name = "Scarecrow Farm", Wall = Color3.fromRGB(150, 45, 35), Roof = Color3.fromRGB(70, 45, 30), Trim = Color3.fromRGB(235, 220, 180), Glow = Color3.fromRGB(255, 170, 60), RoofType = "gable", RoofPitch = 0.45, Yard = { PumpkinPile = 4, Fence = 1 } },
	{ Name = "Zombie Diner", Wall = Color3.fromRGB(110, 140, 90), Roof = Color3.fromRGB(50, 60, 45), Trim = Color3.fromRGB(200, 60, 60), Glow = Color3.fromRGB(120, 255, 120), RoofType = "gable", RoofPitch = 0.35, Chimney = true, Yard = { Cauldron = 1, Grave = 3 } },
	{ Name = "Gravedigger's Crypt", Wall = Color3.fromRGB(95, 95, 105), Roof = Color3.fromRGB(60, 60, 70), Trim = Color3.fromRGB(140, 140, 150), Glow = Color3.fromRGB(160, 200, 255), RoofType = "battlements", Yard = { Grave = 8, DeadTree = 1 } },
	{ Name = "Vlad's Manor", Wall = Color3.fromRGB(80, 20, 30), Roof = Color3.fromRGB(25, 20, 30), Trim = Color3.fromRGB(180, 150, 90), Glow = Color3.fromRGB(255, 60, 60), RoofType = "gable", RoofPitch = 0.7, Towers = true, Yard = { DeadTree = 3, Grave = 3, Fence = 1 } },
	{ Name = "Banshee Hall", Wall = Color3.fromRGB(150, 175, 200), Roof = Color3.fromRGB(60, 70, 100), Trim = Color3.fromRGB(230, 240, 255), Glow = Color3.fromRGB(120, 230, 255), RoofType = "gable", RoofPitch = 0.55, Chimney = true, Yard = { DeadTree = 3, Grave = 4 } },
	{ Name = "Horseman's Hollow", Wall = Color3.fromRGB(55, 40, 35), Roof = Color3.fromRGB(35, 25, 20), Trim = Color3.fromRGB(255, 120, 20), Glow = Color3.fromRGB(255, 130, 20), RoofType = "gable", RoofPitch = 0.6, Chimney = true, Yard = { PumpkinPile = 4, DeadTree = 3, Fence = 1 } },
	{ Name = "Lich King's Keep", Wall = Color3.fromRGB(35, 35, 45), Roof = Color3.fromRGB(20, 20, 25), Trim = Color3.fromRGB(80, 255, 170), Glow = Color3.fromRGB(80, 255, 170), RoofType = "battlements", Towers = true, Yard = { Grave = 6, DeadTree = 3, Cauldron = 1 } },
}

-- Target size (largest side, or height) of each prop in Assets.Props.
local PROP_SIZES = {
	DeadTree = { Size = 22, ByHeight = true },
	Grave = { Size = 4, ByHeight = true },
	Lamp = { Size = 13, ByHeight = true },
	Fence = { Size = 10, ByHeight = false },
	PumpkinPile = { Size = 6, ByHeight = false },
	Cauldron = { Size = 4.5, ByHeight = false },
}

-- Places a prop so it stands on the ground at `cf`. Returns nil when the model is missing.
local function prop(name: string, cf: CFrame, parent: Instance, scale: number?): Model?
	local info = PROP_SIZES[name]
	local art = info and Art.Clone("Props", name, info.Size * (scale or 1), info.ByHeight)
	if not art then
		return nil
	end
	local height = art:GetAttribute("ArtHeight") or info.Size
	art.Name = name
	art:PivotTo(cf + Vector3.new(0, height / 2, 0))
	art.Parent = parent
	return art
end

-- Every part gets the classic studs look: studs on top, inlets underneath, plastic material.
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

local function marker(name: string, cf: CFrame, parent: Instance): BasePart
	return part({ Name = name, Size = Vector3.new(1, 1, 1), CFrame = cf, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = parent })
end

local function billboard(adornee: Instance, text: string, color: Color3, offsetY: number, textSize: number?, maxDistance: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(300, 70)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = maxDistance or 150
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.FredokaOne
	label.TextSize = textSize or 26
	label.TextWrapped = true
	label.Parent = gui
	gui.Parent = adornee
	return gui
end

-- A wall running along local X from x0 to x1 (at depth z), with rectangular openings cut out.
-- openings: { { From = x, To = x, Bottom = y, Top = y } }, sorted by From.
local function wallAlongX(parent: Instance, origin: CFrame, x0: number, x1: number, z: number, y0: number, height: number, openings, props)
	local function add(ax: number, bx: number, ay: number, by: number)
		if bx - ax < 0.05 or by - ay < 0.05 then
			return
		end
		part({
			Name = "Wall",
			Size = Vector3.new(bx - ax, by - ay, 1),
			CFrame = origin * CFrame.new((ax + bx) / 2, (ay + by) / 2, z),
			Color = props.Color,
			Parent = parent,
		})
	end
	local cursor = x0
	for _, o in openings do
		add(cursor, o.From, y0, y0 + height)
		add(o.From, o.To, y0, y0 + o.Bottom)
		add(o.From, o.To, y0 + o.Top, y0 + height)
		cursor = o.To
	end
	add(cursor, x1, y0, y0 + height)
end

-- Same as wallAlongX but running along local Z (at x).
local function wallAlongZ(parent: Instance, origin: CFrame, z0: number, z1: number, x: number, y0: number, height: number, openings, props)
	local function add(az: number, bz: number, ay: number, by: number)
		if bz - az < 0.05 or by - ay < 0.05 then
			return
		end
		part({
			Name = "Wall",
			Size = Vector3.new(1, by - ay, bz - az),
			CFrame = origin * CFrame.new(x, (ay + by) / 2, (az + bz) / 2),
			Color = props.Color,
			Parent = parent,
		})
	end
	local cursor = z0
	for _, o in openings do
		add(cursor, o.From, y0, y0 + height)
		add(o.From, o.To, y0, y0 + o.Bottom)
		add(o.From, o.To, y0 + o.Top, y0 + height)
		cursor = o.To
	end
	add(cursor, z1, y0, y0 + height)
end

local function windowGlow(parent: Instance, cf: CFrame, size: Vector3, color: Color3?)
	local glow = part({
		Name = "Window",
		Size = size,
		CFrame = cf,
		Color = color or Color3.fromRGB(255, 200, 80),
		Material = Enum.Material.Neon,
		Transparency = 0.75,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = parent,
	})
	return glow
end

---------------------------------------------------------------------------
-- Houses
---------------------------------------------------------------------------
-- Local frame: front wall (door) at z = -D/2, local X runs along the street, +Y up.
-- yardSide: open ground on each side of the house; yardBack: open ground behind it.
local function buildHouse(parent: Instance, index: number, info, origin: CFrame, W: number, D: number, yardSide: number, yardBack: number)
	local house = Instance.new("Model")
	house.Name = "House" .. index
	house:SetAttribute("Index", index)
	house:SetAttribute("Owner", info.Owner)
	house.Parent = parent

	local style = HOUSE_STYLES[index] or HOUSE_STYLES[1]
	local wallColor = style.Wall
	local trimColor = style.Trim
	local props = { Color = wallColor }
	local H = FLOOR_H
	local floors = info.Floors
	local function at(x, y, z)
		return origin * CFrame.new(x, y, z)
	end

	part({ Name = "Floor", Size = Vector3.new(W, 1, D), CFrame = at(0, 0.5, 0), Color = COLORS.Floor, Parent = house })

	local window = 7
	local sideWindows = {
		{ From = -D / 4 - window / 2, To = -D / 4 + window / 2, Bottom = 1.5, Top = 9 },
		{ From = D / 4 - window / 2, To = D / 4 + window / 2, Bottom = 1.5, Top = 9 },
	}
	for floor = 1, floors do
		local y0 = 1 + (floor - 1) * H
		-- Front wall: the door on the ground floor, windows upstairs
		local frontOpenings = if floor == 1
			then { { From = -3.5, To = 3.5, Bottom = 0, Top = 9 } }
			else { { From = -W / 4 - 3.5, To = -W / 4 + 3.5, Bottom = 3, Top = 10 }, { From = W / 4 - 3.5, To = W / 4 + 3.5, Bottom = 3, Top = 10 } }
		wallAlongX(house, origin, -W / 2, W / 2, -D / 2 + 0.5, y0, H, frontOpenings, props)
		-- Back wall with a window in the middle
		wallAlongX(house, origin, -W / 2, W / 2, D / 2 - 0.5, y0, H, { { From = -3.5, To = 3.5, Bottom = 1.5, Top = 9 } }, props)
		-- Side walls, each with two windows big enough to climb through
		wallAlongZ(house, origin, -D / 2 + 1, D / 2 - 1, -W / 2 + 0.5, y0, H, sideWindows, props)
		wallAlongZ(house, origin, -D / 2 + 1, D / 2 - 1, W / 2 - 0.5, y0, H, sideWindows, props)
		for _, o in sideWindows do
			local z = (o.From + o.To) / 2
			windowGlow(house, at(-W / 2 + 0.5, y0 + (o.Bottom + o.Top) / 2, z), Vector3.new(0.2, o.Top - o.Bottom, o.To - o.From), style.Glow)
			windowGlow(house, at(W / 2 - 0.5, y0 + (o.Bottom + o.Top) / 2, z), Vector3.new(0.2, o.Top - o.Bottom, o.To - o.From), style.Glow)
		end
		windowGlow(house, at(0, y0 + 5.25, D / 2 - 0.5), Vector3.new(7, 7.5, 0.2), style.Glow)
	end

	-- Ground floor rooms: a hall at the front, two rooms at the back.
	wallAlongX(house, origin, -W / 2 + 1, W / 2 - 1, 0, 1, H, { { From = -W / 4 - 3, To = -W / 4 + 3, Bottom = 0, Top = 9 }, { From = W / 4 - 3, To = W / 4 + 3, Bottom = 0, Top = 9 } }, props)
	wallAlongZ(house, origin, 0.5, D / 2 - 1, 0, 1, H, {}, props)

	-- Upstairs: a ramp in the front hall and the upper floor slab with a hole above it.
	if floors >= 2 then
		local rampZ = -D / 2 + 4.5
		local bottom = Vector3.new(W / 2 - 2, 1, rampZ)
		local top = Vector3.new(W / 2 - 20, 1 + H, rampZ)
		local mid = (bottom + top) / 2
		part({
			Name = "Stairs",
			Size = Vector3.new(6, 1, (top - bottom).Magnitude + 1),
			CFrame = origin * CFrame.lookAt(mid, top),
			Color = trimColor,
			Parent = house,
		})
		local holeDepth = 9
		part({ Name = "UpperFloor", Size = Vector3.new(W - 2, 1, D - 1 - holeDepth), CFrame = at(0, H + 0.5, (holeDepth) / 2), Color = COLORS.Floor, Parent = house })
		local stripW = (W - 1) - 21
		part({ Name = "UpperFloor", Size = Vector3.new(stripW, 1, holeDepth), CFrame = at(-W / 2 + 1 + stripW / 2, H + 0.5, -D / 2 + 1 + holeDepth / 2), Color = COLORS.Floor, Parent = house })
	end

	-- Roof: every house style has its own shape
	local roofY = 1 + floors * H
	part({ Name = "Roof", Size = Vector3.new(W + 4, 1.2, D + 4), CFrame = at(0, roofY + 0.6, 0), Color = style.Roof, Parent = house })
	if style.RoofType == "gable" then
		local rise = D * style.RoofPitch
		for side = -1, 1, 2 do
			part({
				ClassName = "WedgePart",
				Name = "Roof",
				Size = Vector3.new(W + 4, rise, (D + 4) / 2),
				-- A wedge's slope faces its front (-Z); flip the back half so both slopes face outward.
				CFrame = at(0, roofY + 1.2 + rise / 2, side * (D + 4) / 4) * (if side == 1 then CFrame.Angles(0, math.pi, 0) else CFrame.identity),
				Color = style.Roof,
				Parent = house,
			})
		end
		if style.Chimney then
			part({ Name = "Chimney", Size = Vector3.new(4, rise + 4, 4), CFrame = at(W / 4, roofY + 1.2 + (rise + 4) / 2, D / 5), Color = style.Trim, Parent = house })
		end
	elseif style.RoofType == "battlements" then
		for x = -W / 2, W / 2 - 1, 6 do
			for _, z in { -D / 2 - 1.5, D / 2 + 1.5 } do
				part({ Name = "Battlement", Size = Vector3.new(3, 3, 1.5), CFrame = at(x + 1.5, roofY + 2.7, z), Color = wallColor, Parent = house })
			end
		end
		for z = -D / 2, D / 2 - 1, 6 do
			for _, x in { -W / 2 - 1.5, W / 2 + 1.5 } do
				part({ Name = "Battlement", Size = Vector3.new(1.5, 3, 3), CFrame = at(x, roofY + 2.7, z + 1.5), Color = wallColor, Parent = house })
			end
		end
	else -- "stepped"
		part({ Name = "Roof", Size = Vector3.new(W - 6, 1.2, D - 8), CFrame = at(0, roofY + 1.8, 0), Color = style.Roof, Parent = house })
		part({ Name = "Roof", Size = Vector3.new(W - 16, 1.2, D - 18), CFrame = at(0, roofY + 3, 0), Color = style.Roof, Parent = house })
		part({ Name = "Roof", Size = Vector3.new(math.max(W - 26, 4), 1.2, math.max(D - 26, 4)), CFrame = at(0, roofY + 4.2, 0), Color = style.Trim, Parent = house })
	end

	-- Corner towers with stepped spires on the grand houses
	if style.Towers then
		local towerH = roofY + 10
		for _, x in { -W / 2 - 2, W / 2 + 2 } do
			part({ Name = "Tower", Size = Vector3.new(8, towerH, 8), CFrame = at(x, towerH / 2, -D / 2 - 2), Color = wallColor, Parent = house })
			for step = 0, 3 do
				local s = 9 - step * 2.2
				part({ Name = "Spire", Size = Vector3.new(s, 2, s), CFrame = at(x, towerH + 1 + step * 2, -D / 2 - 2), Color = style.Roof, Parent = house })
			end
			windowGlow(house, at(x, towerH - 5, -D / 2 - 6.05), Vector3.new(3, 4, 0.2), style.Glow)
		end
	end

	-- Trim along the top of the walls
	part({ Name = "Trim", Size = Vector3.new(W + 1, 1, D + 1), CFrame = at(0, roofY - 0.5, 0), Color = style.Trim, CanCollide = false, Parent = house })

	-- Door (Trick-or-Treat prompt goes on it) and a porch
	local door = part({
		Name = "Door",
		Size = Vector3.new(7, 9, 0.8),
		CFrame = at(0, 5.5, -D / 2 + 0.5),
		Color = Color3.fromRGB(70, 35, 20),
		Parent = house,
	})
	part({ Name = "Porch", Size = Vector3.new(14, 1, 6), CFrame = at(0, 0.5, -D / 2 - 3), Color = trimColor, Parent = house })
	billboard(door, string.format("Level %d\n%s", index, info.Owner), Color3.fromRGB(255, 200, 120), 8, 24)

	marker("OwnerSpawn", at(0, 4, -D / 4 + 2), house)
	marker("OwnerExit", at(0, 4, -D / 2 - 6), house)

	-- Egg spots, ordered easiest to hardest to reach. Rarer eggs go on the later spots.
	local spots = Instance.new("Folder")
	spots.Name = "EggSpots"
	spots.Parent = house
	local positions = {
		Vector3.new(-W / 2 + 5, 1, -D / 2 + 5),
		Vector3.new(-W / 4, 1, D / 4 + 3),
		Vector3.new(W / 4, 1, D / 4 + 3),
		Vector3.new(-W / 2 + 5, 1, D / 2 - 5),
		Vector3.new(W / 2 - 5, 1, D / 2 - 5),
		Vector3.new(0 - 5, 1, -D / 2 + 12),
	}
	if floors >= 2 then
		local upY = 1 + H
		positions = {
			Vector3.new(-W / 2 + 5, 1, -D / 2 + 5),
			Vector3.new(-W / 4, 1, D / 4 + 3),
			Vector3.new(W / 4, 1, D / 4 + 3),
			Vector3.new(-W / 3, upY, 0),
			Vector3.new(-W / 2 + 5, upY, D / 2 - 5),
			Vector3.new(W / 2 - 5, upY, D / 2 - 5),
		}
	end
	for i = 1, info.EggCount do
		local pos = positions[i]
		if pos then
			part({
				Name = "Spot" .. i,
				Size = Vector3.new(4, 1.5, 4),
				CFrame = at(pos.X, pos.Y + 0.75, pos.Z),
				Color = Color3.fromRGB(60, 50, 70),
				Parent = spots,
			})
		end
	end

	-- Jack-o'-lanterns by the door
	for _, x in { -6, 6 } do
		local pumpkin = part({
			Name = "Pumpkin",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(3, 3, 3),
			CFrame = at(x, 1.5, -D / 2 - 3),
			Color = Color3.fromRGB(255, 120, 0),
			Parent = house,
		})
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 150, 50)
		light.Range = 18
		light.Brightness = 2
		light.Parent = pumpkin
	end
	local inside = marker("Lamp", at(0, H - 2, -D / 4), house)
	local lamp = Instance.new("PointLight")
	lamp.Color = Color3.fromRGB(255, 190, 120)
	lamp.Range = 30
	lamp.Brightness = 1.2
	lamp.Parent = inside

	-- Yard: this house's props in the open ground on both sides, plus a fence along the front.
	local yard = Instance.new("Folder")
	yard.Name = "Yard"
	yard.Parent = house
	local rng = Random.new(index * 7919)
	for name, count in style.Yard do
		if name == "Fence" then
			for _, side in { -1, 1 } do
				for n = 0, 1 do
					local x = side * (8 + 5 + n * 10)
					prop("Fence", at(x, 1, -D / 2 - 7), yard)
				end
			end
		else
			for n = 1, count * 2 do -- the big lots get twice the props
				local side = if n % 2 == 0 then 1 else -1
				local x = side * (W / 2 + rng:NextNumber(10, math.max(yardSide - 6, 12)))
				local z = rng:NextNumber(-D / 2, D / 2 + math.max(yardBack - 8, 0))
				prop(name, at(x, 1, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), yard)
			end
		end
	end
	-- Porch lamps
	for _, x in { -9, 9 } do
		local lampPost = prop("Lamp", at(x, 1, -D / 2 - 4), yard, 0.7)
		local anchorPart = if lampPost then lampPost.PrimaryPart else nil
		if anchorPart then
			local glow = Instance.new("PointLight")
			glow.Color = style.Glow
			glow.Range = 22
			glow.Brightness = 1.5
			glow.Parent = anchorPart
		end
	end

	house.PrimaryPart = house:FindFirstChild("Floor") :: BasePart
	-- Same plan, bigger house: scale everything around the house origin.
	house.WorldPivot = origin
	house:ScaleTo(HOUSE_SCALE)
	return house
end

local function buildStreet(map: Instance)
	local street = Instance.new("Folder")
	street.Name = "Street"
	street:SetAttribute("StartZ", STREET_START_Z) -- owners stop chasing at this line (where Level 1 starts)
	street.Parent = map
	local houses = Instance.new("Folder")
	houses.Name = "Houses"
	houses.Parent = street

	local z = STREET_START_Z
	for i, info in Config.Houses do
		local W = math.floor(HOUSE_W * info.Scale + 0.5)
		local D = math.floor(HOUSE_D * info.Scale + 0.5)
		-- W and D are the house plan; Ws and Ds are its real size after scaling.
		local Ws, Ds = W * HOUSE_SCALE, D * HOUSE_SCALE
		local lotLength = (Ws + LOT_GAP) * LOT_LENGTH_SCALE

		-- Level line across the street
		local line = part({
			Name = "LevelLine" .. i,
			Size = Vector3.new(STRIP_MAX_X - STRIP_MIN_X, 0.3, 2),
			CFrame = CFrame.new((STRIP_MIN_X + STRIP_MAX_X) / 2, 0.15, z),
			Color = COLORS.LevelLine,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = street,
		})
		local walkSpeed = info.OwnerSpeed
		billboard(line, string.format("LEVEL %d  |  Owner speed %d", i, walkSpeed), COLORS.LevelLine, 6, 22, 120)

		local centerZ = z + lotLength / 2
		-- Rotate so the house's local -Z (front) faces the road (world -X).
		local origin = CFrame.new(HOUSE_FRONT_X + Ds / 2, 0, centerZ) * CFrame.Angles(0, math.pi / 2, 0)
		-- Yard sizes are given in plan units because the whole house (yard included) is scaled afterwards.
		local yardSide = (lotLength - Ws) / 2 / HOUSE_SCALE
		local yardBack = (STRIP_MAX_X - (HOUSE_FRONT_X + Ds)) / HOUSE_SCALE
		buildHouse(houses, i, info, origin, W, D, yardSide, yardBack)
		z += lotLength
	end
	local streetEnd = z

	-- Road and pavement
	part({
		Name = "Road",
		Size = Vector3.new(ROAD_MAX_X - ROAD_MIN_X, 0.2, streetEnd - STREET_START_Z + 10),
		CFrame = CFrame.new((ROAD_MIN_X + ROAD_MAX_X) / 2, 0.1, (STREET_START_Z + streetEnd) / 2),
		Color = COLORS.Road,
		Parent = street,
	})
	-- Walls along both sides and the far end
	local len = streetEnd - STREET_START_Z + 10
	for _, x in { STRIP_MIN_X - 1, STRIP_MAX_X + 1 } do
		part({ Name = "StreetWall", Size = Vector3.new(2, WALL_H, len), CFrame = CFrame.new(x, WALL_H / 2, STREET_START_Z + len / 2 - 5), Color = COLORS.Wall, Parent = street })
	end
	part({
		Name = "StreetWall",
		Size = Vector3.new(STRIP_MAX_X - STRIP_MIN_X + 4, WALL_H, 2),
		CFrame = CFrame.new((STRIP_MIN_X + STRIP_MAX_X) / 2, WALL_H / 2, streetEnd + 6),
		Color = COLORS.Wall,
		Parent = street,
	})

	-- Invisible zone covering the street: used to send players home when day comes.
	local zone = part({
		Name = "StreetZone",
		Size = Vector3.new(STRIP_MAX_X - STRIP_MIN_X, 120, streetEnd - STREET_START_Z + 10),
		CFrame = CFrame.new((STRIP_MIN_X + STRIP_MAX_X) / 2, 55, (STREET_START_Z + streetEnd + 10) / 2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = street,
	})
	zone:SetAttribute("Zone", true)

	-- The barrier that closes the street during the day.
	local barrier = part({
		Name = "DayBarrier",
		Size = Vector3.new(STRIP_MAX_X - STRIP_MIN_X, WALL_H + 20, 1),
		CFrame = CFrame.new((STRIP_MIN_X + STRIP_MAX_X) / 2, (WALL_H + 20) / 2, STREET_START_Z - 3),
		Color = Color3.fromRGB(255, 190, 60),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		Parent = street,
	})
	billboard(barrier, "", Color3.fromRGB(255, 220, 120), 0, 34).Name = "BarrierSign"

	-- Street lamps along the far side of the road
	local lamps = Instance.new("Folder")
	lamps.Name = "StreetLamps"
	lamps.Parent = street
	for lampZ = STREET_START_Z + 20, streetEnd, 50 do
		local lampPost = prop("Lamp", CFrame.new(ROAD_MIN_X - 2, 0, lampZ), lamps)
		if lampPost and lampPost.PrimaryPart then
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 170, 80)
			glow.Range = 40
			glow.Brightness = 1.4
			glow.Parent = lampPost.PrimaryPart
		end
	end

	return streetEnd
end

---------------------------------------------------------------------------
-- Hub: bases, treadmill spots, shops
---------------------------------------------------------------------------
local function buildPlots(map: Instance)
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = map

	for i = 1, PLOT_COUNT do
		local plot = Instance.new("Model")
		plot.Name = "Plot" .. i
		plot.Parent = plots
		local cx = -((PLOT_COUNT - 1) * PLOT_SPACING) / 2 + (i - 1) * PLOT_SPACING
		local base = part({
			Name = "Base",
			Size = Vector3.new(BASE_SIZE, 1, BASE_SIZE),
			CFrame = CFrame.new(cx, 0.5, BASE_Z),
			Color = COLORS.Base,
			Parent = plot,
		})
		billboard(base, "Empty Plot", Color3.new(1, 1, 1), 12, 28).Name = "OwnerSign"

		-- Pet slots in the back half
		local slots = Instance.new("Folder")
		slots.Name = "PetSlots"
		slots.Parent = plot
		local index = 0
		for row = 0, 1 do
			for col = 0, 4 do
				index += 1
				part({
					Name = "Slot" .. index,
					Size = Vector3.new(6, 0.4, 6),
					CFrame = CFrame.new(cx - 20 + col * 10, 1.2, BASE_Z - 20 + row * 10),
					Color = Color3.fromRGB(120, 60, 160),
					Parent = slots,
				})
			end
		end

		-- Incubators at the front
		local incubators = Instance.new("Folder")
		incubators.Name = "Incubators"
		incubators.Parent = plot
		for n = 1, Config.IncubatorSlots do
			part({
				Name = "Incubator" .. n,
				Size = Vector3.new(7, 1.5, 7),
				CFrame = CFrame.new(cx - 16 + (n - 1) * 16, 1.75, BASE_Z + 17),
				Color = Color3.fromRGB(255, 140, 40),
				Parent = incubators,
			})
		end

		marker("PlayerSpawn", CFrame.new(cx, 4, BASE_Z + 4) * CFrame.Angles(0, math.pi, 0), plot)
		-- Treadmill spot just in front of the base, running toward the street (+Z).
		marker("TreadmillSpot", CFrame.lookAt(Vector3.new(cx, 1, BASE_Z + BASE_SIZE / 2 + 10), Vector3.new(cx, 1, BASE_Z + 100)), plot)
	end
end

local function buildShop(hub: Instance, name: string, title: string, center: Vector3, color: Color3): Model
	local shop = Instance.new("Model")
	shop.Name = name
	shop.Parent = hub
	local W, D, H = 50, 36, 16
	local origin = CFrame.new(center)
	part({ Name = "Floor", Size = Vector3.new(W, 1, D), CFrame = origin * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(70, 60, 85), Parent = shop })
	-- Back wall on the street side (+Z); the open front faces the bases (-Z)
	part({ Name = "Wall", Size = Vector3.new(W, H, 1), CFrame = origin * CFrame.new(0, H / 2, D / 2 - 0.5), Color = color, Parent = shop })
	part({ Name = "Wall", Size = Vector3.new(1, H, D), CFrame = origin * CFrame.new(-W / 2 + 0.5, H / 2, 0), Color = color, Parent = shop })
	part({ Name = "Wall", Size = Vector3.new(1, H, D), CFrame = origin * CFrame.new(W / 2 - 0.5, H / 2, 0), Color = color, Parent = shop })
	local roof = part({ Name = "Roof", Size = Vector3.new(W + 4, 1.2, D + 4), CFrame = origin * CFrame.new(0, H + 0.6, 0), Color = COLORS.Roof, Parent = shop })
	-- Striped awning over the open front
	for s = 0, 9 do
		part({
			Name = "Awning",
			Size = Vector3.new(W / 10, 0.6, 6),
			CFrame = origin * CFrame.new(-W / 2 + W / 20 + s * W / 10, H - 1, -D / 2 - 2) * CFrame.Angles(math.rad(-20), 0, 0),
			Color = if s % 2 == 0 then color else Color3.fromRGB(240, 240, 240),
			Parent = shop,
		})
	end
	billboard(roof, title, Color3.fromRGB(255, 220, 140), 5, 36, 250)
	-- Warm light inside so the displays are easy to see at night
	local lamp = marker("ShopLight", origin * CFrame.new(0, H - 3, 0), shop)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 180)
	light.Range = 40
	light.Brightness = 2
	light.Parent = lamp
	return shop
end

local function buildHub(map: Instance)
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = map

	part({
		Name = "HubFloor",
		Size = Vector3.new(HUB_HALF_W * 2, 0.2, -HUB_MIN_Z),
		CFrame = CFrame.new(0, 0.1, HUB_MIN_Z / 2),
		Color = COLORS.Hub,
		Parent = hub,
	})
	-- Walls: back, sides, and the top wall with a gap for the street entrance.
	part({ Name = "HubWall", Size = Vector3.new(HUB_HALF_W * 2 + 2, WALL_H, 2), CFrame = CFrame.new(0, WALL_H / 2, HUB_MIN_Z - 1), Color = COLORS.Wall, Parent = hub })
	for _, x in { -HUB_HALF_W - 1, HUB_HALF_W + 1 } do
		part({ Name = "HubWall", Size = Vector3.new(2, WALL_H, -HUB_MIN_Z + 2), CFrame = CFrame.new(x, WALL_H / 2, HUB_MIN_Z / 2), Color = COLORS.Wall, Parent = hub })
	end
	local leftLen = (STRIP_MIN_X - 2) + HUB_HALF_W + 2
	part({ Name = "HubWall", Size = Vector3.new(leftLen, WALL_H, 2), CFrame = CFrame.new(-HUB_HALF_W - 2 + leftLen / 2, WALL_H / 2, 1), Color = COLORS.Wall, Parent = hub })
	local rightLen = HUB_HALF_W + 2 - (STRIP_MAX_X + 2)
	part({ Name = "HubWall", Size = Vector3.new(rightLen, WALL_H, 2), CFrame = CFrame.new(STRIP_MAX_X + 2 + rightLen / 2, WALL_H / 2, 1), Color = COLORS.Wall, Parent = hub })

	-- Speed shop (treadmills) in the top-left corner, costume shop in the top-right corner.
	-- Shops are laid out at normal size around their centre, then scaled up at the end.
	local shopX, shopZ = HUB_HALF_W - 50, -45
	local speedCenter = Vector3.new(-shopX, 0, shopZ)
	local costumeCenter = Vector3.new(shopX, 0, shopZ)
	local speedShop = buildShop(hub, "SpeedShop", "SPEED SHOP\nTreadmills", speedCenter, Color3.fromRGB(40, 110, 200))
	local counter = part({
		Name = "Counter",
		Size = Vector3.new(16, 4, 4),
		CFrame = CFrame.new(speedCenter + Vector3.new(0, 2.5, 4)),
		Color = Color3.fromRGB(255, 150, 40),
		Parent = speedShop,
	})
	counter:SetAttribute("OpenMenu", "Treadmills")

	local costumeShop = buildShop(hub, "CostumeShop", "COSTUME SHOP", costumeCenter, Color3.fromRGB(150, 40, 170))
	local mannequins = Instance.new("Folder")
	mannequins.Name = "Mannequins"
	mannequins.Parent = costumeShop
	local count = #Config.Costumes - 1 -- "No Costume" is not on display
	for i = 2, #Config.Costumes do
		local costume = Config.Costumes[i]
		local slot = i - 2
		local row = if slot < 4 then 0 else 1
		local col = slot % 4
		local x = costumeCenter.X - 16.5 + col * 11
		local z = costumeCenter.Z + (if row == 0 then 8 else -6)
		local display = Instance.new("Model")
		display.Name = costume.Id
		display:SetAttribute("Costume", costume.Id)
		display.Parent = mannequins
		local pedestal = part({
			Name = "Pedestal",
			Size = Vector3.new(6, 2, 6),
			CFrame = CFrame.new(x, 2, z),
			Color = Color3.fromRGB(40, 35, 50),
			Parent = display,
		})
		-- A blocky mannequin wearing the costume colour
		part({ Name = "Legs", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(x, 4, z), Color = costume.Color, Parent = display })
		part({ Name = "Torso", Size = Vector3.new(2, 2, 1), CFrame = CFrame.new(x, 6, z), Color = costume.Color, Parent = display })
		part({ Name = "Arms", Size = Vector3.new(4, 2, 1), CFrame = CFrame.new(x, 6, z), Color = costume.Color, Parent = display })
		part({
			Name = "Head",
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = CFrame.new(x, 7.7, z),
			Color = if costume.Id == "Pumpkin" then Color3.fromRGB(255, 120, 0) else Color3.fromRGB(245, 205, 150),
			Parent = display,
		})
		-- Dress the mannequin in the real costume model when there is one.
		local art = Art.Clone("Costumes", costume.Id, costume.ArtSize, costume.Attach == "Body" or costume.Attach == "Back")
		if art then
			local height = art:GetAttribute("ArtHeight") or costume.ArtSize
			local facing = CFrame.new(x, 0, z) * CFrame.Angles(0, math.pi, 0) -- face the open front of the shop
			if costume.Attach == "Head" then
				art:PivotTo(facing + Vector3.new(0, 7.8, 0))
				local head = display:FindFirstChild("Head") :: BasePart?
				if head then
					head.Transparency = 1
				end
			elseif costume.Attach == "Hat" then
				art:PivotTo(facing + Vector3.new(0, 8.4 + height / 2 - 0.4, 0))
			elseif costume.Attach == "Back" then
				art:PivotTo(facing * CFrame.new(0, 7 - height / 2 + 0.6, 0.8))
			else
				art:PivotTo(facing + Vector3.new(0, 3 + height / 2, 0))
				for _, p in display:GetChildren() do
					if p:IsA("BasePart") and p.Name ~= "Pedestal" then
						p.Transparency = 1
					end
				end
			end
			art.Parent = display
		end
		billboard(pedestal, costume.Name, costume.Color, 7.5, 18, 40).Name = "PriceSign"
		display.PrimaryPart = pedestal
	end
	assert(count <= 8, "Costume shop only has room for 8 mannequins")
	for shop, center in { [speedShop] = speedCenter, [costumeShop] = costumeCenter } do
		shop.WorldPivot = CFrame.new(center)
		shop:ScaleTo(SHOP_SCALE)
	end

	-- Decorations: dead trees in the corners, pumpkins by the shops, lamps between the bases.
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = hub
	local edge = HUB_HALF_W - 14
	for _, pos in { Vector3.new(-edge, 0, HUB_MIN_Z + 12), Vector3.new(edge, 0, HUB_MIN_Z + 12), Vector3.new(-edge, 0, -110), Vector3.new(edge, 0, -110), Vector3.new(-70, 0, -110), Vector3.new(70, 0, -110) } do
		prop("DeadTree", CFrame.new(pos) * CFrame.Angles(0, pos.X * 0.1, 0), decor)
	end
	for _, pos in { Vector3.new(-shopX + 50, 0, -90), Vector3.new(shopX - 50, 0, -90), Vector3.new(-edge, 0, -80), Vector3.new(edge, 0, -80), Vector3.new(-12, 0, -12), Vector3.new(12, 0, -12) } do
		prop("PumpkinPile", CFrame.new(pos) * CFrame.Angles(0, pos.X, 0), decor)
	end
	for i = 0, PLOT_COUNT do
		local x = -((PLOT_COUNT - 1) * PLOT_SPACING) / 2 - PLOT_SPACING / 2 + i * PLOT_SPACING
		local lampPost = prop("Lamp", CFrame.new(x, 0, BASE_Z + BASE_SIZE / 2 + 4), decor)
		if lampPost and lampPost.PrimaryPart then
			local glow = Instance.new("PointLight")
			glow.Color = Color3.fromRGB(255, 170, 80)
			glow.Range = 35
			glow.Brightness = 1.3
			glow.Parent = lampPost.PrimaryPart
		end
	end
end

local function setNightLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(80, 60, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(100, 80, 120)
	Lighting.FogColor = Color3.fromRGB(40, 20, 50)
	Lighting.FogStart = 80
	Lighting.FogEnd = 1000
	-- Purple haze and a big moon
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.35
		atmosphere.Color = Color3.fromRGB(120, 80, 160)
		atmosphere.Decay = Color3.fromRGB(60, 30, 80)
		atmosphere.Glare = 0.3
		atmosphere.Haze = 1.5
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.MoonAngularSize = 25
		sky.StarCount = 5000
		sky.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local grade = Instance.new("ColorCorrectionEffect")
		grade.Saturation = 0.15
		grade.Contrast = 0.1
		grade.TintColor = Color3.fromRGB(235, 225, 255)
		grade.Parent = Lighting
	end
end

function MapBuilder.EnsureMap(): Instance
	local existing = workspace:FindFirstChild("Map")
	if existing then
		return existing
	end

	-- Remove the template baseplate and spawn so they do not overlap the map.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local old = workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local map = Instance.new("Folder")
	map.Name = "Map"

	buildPlots(map)
	buildHub(map)
	local streetEnd = buildStreet(map)

	part({
		Name = "Ground",
		Size = Vector3.new(HUB_HALF_W * 2 + 40, 2, streetEnd - HUB_MIN_Z + 60),
		CFrame = CFrame.new(0, -1, (HUB_MIN_Z + streetEnd) / 2),
		Color = COLORS.Ground,
		Parent = map,
	})
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.5, -120)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Studs
	spawn.Parent = map

	setNightLighting()

	map.Parent = workspace
	return map
end

return MapBuilder
