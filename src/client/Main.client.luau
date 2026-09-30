-- Client: HUD (Candy, Money, Speed + XP bar, night/day timer, chase banner, messages)
-- the studded menu buttons on the left (Rebirth, Index, Pet, Egg, Store) and their panels, and the Treadmills menu.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local data: { [string]: any }? = nil

local ORANGE = Color3.fromRGB(255, 150, 40)
local PURPLE = Color3.fromRGB(45, 25, 60)
local DARK = Color3.fromRGB(25, 18, 32)
local WHITE = Color3.new(1, 1, 1)
local BLUE = Color3.fromRGB(120, 220, 255)
local GREEN = Color3.fromRGB(120, 255, 120)
local RED = Color3.fromRGB(255, 90, 90)

---------------------------------------------------------------------------
-- Small UI helpers
---------------------------------------------------------------------------
local function new(className: string, props: { [string]: any }, children: { Instance }?)
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

local function corner(radius: number?)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

local function label(props: { [string]: any })
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = if props.TextScaled == nil then true else props.TextScaled
	return new("TextLabel", props)
end

local function button(props: { [string]: any }, onClick: () -> ())
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = true
	props.BackgroundColor3 = props.BackgroundColor3 or ORANGE
	props.AutoButtonColor = true
	local b = new("TextButton", props, { corner(8) })
	b.Activated:Connect(onClick)
	return b
end

local function formatNumber(n: number): string
	n = math.floor(n)
	local suffixes = { "", "K", "M", "B", "T" }
	local i = 1
	local value = n
	while value >= 1000 and i < #suffixes do
		value /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(n)
	end
	return string.format("%.1f%s", value, suffixes[i])
end

local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 60 then
		return string.format("%d:%02d", seconds // 60, seconds % 60)
	end
	return seconds .. "s"
end

---------------------------------------------------------------------------
-- Screen
---------------------------------------------------------------------------
local gui = new("ScreenGui", { Name = "SpookyHUD", ResetOnSpawn = false, IgnoreGuiInset = false, Parent = player:WaitForChild("PlayerGui") })

local statsBar = new("Frame", {
	Size = UDim2.new(0, 480, 0, 50),
	Position = UDim2.new(0.5, -240, 0, 8),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.2,
	Parent = gui,
}, { corner(12) })
local candyLabel = label({ Size = UDim2.new(1 / 3, -10, 1, -10), Position = UDim2.fromOffset(10, 5), Text = "Candy: 0", TextColor3 = ORANGE, Parent = statsBar })
local moneyLabel = label({ Size = UDim2.new(1 / 3, -10, 1, -10), Position = UDim2.new(1 / 3, 0, 0, 5), Text = "$0", TextColor3 = GREEN, Parent = statsBar })
local speedLabel = label({ Size = UDim2.new(1 / 3, -10, 1, -10), Position = UDim2.new(2 / 3, 0, 0, 5), Text = "Speed 16", TextColor3 = BLUE, Parent = statsBar })

-- XP bar under the stats
local xpBack = new("Frame", {
	Size = UDim2.new(0, 480, 0, 14),
	Position = UDim2.new(0.5, -240, 0, 62),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.2,
	Parent = gui,
}, { corner(7) })
local xpFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = BLUE, Parent = xpBack }, { corner(7) })
local xpText = label({ Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = WHITE, ZIndex = 2, Parent = xpBack })

-- Night / day timer in the top right
local phaseLabel = label({
	Size = UDim2.new(0, 220, 0, 44),
	Position = UDim2.new(1, -230, 0, 8),
	BackgroundTransparency = 0.2,
	BackgroundColor3 = DARK,
	Text = "",
	Parent = gui,
})
corner().Parent = phaseLabel

local banner = label({
	Size = UDim2.new(0, 520, 0, 44),
	Position = UDim2.new(0.5, -260, 0, 84),
	BackgroundTransparency = 0.15,
	BackgroundColor3 = Color3.fromRGB(170, 20, 30),
	Text = "",
	Visible = false,
	Parent = gui,
})
corner().Parent = banner

local toastHolder = new("Frame", {
	Size = UDim2.new(0, 560, 0, 220),
	Position = UDim2.new(0.5, -280, 1, -320),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }),
})

local function toast(text: string, color: Color3?)
	local t = label({
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 0.25,
		BackgroundColor3 = DARK,
		TextColor3 = color or WHITE,
		Text = text,
		Parent = toastHolder,
	})
	corner(8).Parent = t
	task.delay(4, function()
		local tween = TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		t:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Menus
---------------------------------------------------------------------------
local BLACK = Color3.new(0, 0, 0)

-- Tile colours (top, bottom) for each menu, matching the menu button art.
local THEMES = {
	Rebirth = { Color3.fromRGB(255, 95, 185), Color3.fromRGB(225, 30, 140) },
	Index = { Color3.fromRGB(70, 180, 255), Color3.fromRGB(25, 105, 235) },
	Pets = { Color3.fromRGB(255, 195, 40), Color3.fromRGB(110, 215, 40) },
	Eggs = { Color3.fromRGB(245, 70, 220), Color3.fromRGB(125, 45, 215) },
	Store = { Color3.fromRGB(255, 105, 195), Color3.fromRGB(225, 40, 150) },
	Treadmills = { Color3.fromRGB(255, 165, 50), Color3.fromRGB(215, 90, 20) },
}
local TITLES = { Rebirth = "Rebirth", Index = "Pet Index", Pets = "Your Pets", Eggs = "Eggs", Store = "Store", Treadmills = "Speed Shop" }

local function themeGradient(name: string)
	local theme = THEMES[name] or THEMES.Treadmills
	return ColorSequence.new(theme[1], theme[2])
end

-- White text with a thick black outline, like the menu button labels.
local function outlined(props: { [string]: any }, thickness: number?)
	local l = label(props)
	new("UIStroke", { Color = BLACK, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = l })
	return l
end

-- A grid of raised studs (Lego plate look) filling `parent`. Studs are see-through white, so they take the tile colour.
local function studs(parent: Instance, cellSize: UDim2, count: number)
	local layer = new("CanvasGroup", { Name = "Studs", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent }, {
		new("UICorner", { CornerRadius = UDim.new(0, 14) }),
		new("UIGridLayout", { CellSize = cellSize, CellPadding = UDim2.new(), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for _ = 1, count do
		local cell = new("Frame", { BackgroundTransparency = 1, Parent = layer })
		new("Frame", { -- shadow under the stud
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.55, 0.57), Size = UDim2.fromScale(0.58, 0.58),
			BackgroundColor3 = BLACK, BackgroundTransparency = 0.78, Parent = cell,
		}, { new("UICorner", { CornerRadius = UDim.new(0.2, 0) }) })
		new("Frame", { -- the stud, lit from the top
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.58, 0.58),
			BackgroundColor3 = WHITE, BackgroundTransparency = 0.72, Parent = cell,
		}, {
			new("UICorner", { CornerRadius = UDim.new(0.2, 0) }),
			new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 0.7) }),
		})
	end
	return layer
end

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromScale(0.62, 0.8),
	Position = UDim2.fromScale(0.54, 0.52),
	BackgroundColor3 = WHITE,
	Visible = false,
	Parent = gui,
}, {
	corner(14),
	new("UIStroke", { Color = BLACK, Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	new("UISizeConstraint", { MaxSize = Vector2.new(560, 470), MinSize = Vector2.new(300, 240) }),
})
local panelGradient = new("UIGradient", { Rotation = 90, Color = themeGradient("Treadmills"), Parent = panel })
studs(panel, UDim2.fromOffset(26, 26), 22 * 19)
new("Frame", { -- glossy bevel just inside the outline
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -6, 1, -6),
	BackgroundTransparency = 1, Parent = panel,
}, { corner(12), new("UIStroke", { Color = WHITE, Transparency = 0.35, Thickness = 2 }) })
local panelTitle = outlined({ Size = UDim2.new(1, -70, 0, 40), Position = UDim2.fromOffset(14, 6), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Parent = panel }, 3)
local list = new("ScrollingFrame", {
	Size = UDim2.new(1, -20, 1, -60),
	Position = UDim2.fromOffset(10, 50),
	BackgroundTransparency = 1,
	ScrollBarThickness = 6,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = panel,
}, { new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

local openMenu: string? = nil
local renderMenu: () -> ()

local closeButton = button({ Size = UDim2.fromOffset(40, 40), Position = UDim2.new(1, -48, 0, 6), Text = "X", BackgroundColor3 = Color3.fromRGB(230, 50, 60), Parent = panel }, function()
	openMenu = nil
	panel.Visible = false
end)
new("UIStroke", { Color = BLACK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = closeButton })
new("UIStroke", { Color = BLACK, Thickness = 2, Parent = closeButton })

local function request(action: string, arg: any?)
	local ok, success, message = pcall(function()
		return Remotes.Request:InvokeServer(action, arg)
	end)
	if not ok then
		toast("Something went wrong, try again.", RED)
		return
	end
	toast(message or "", if success then GREEN else RED)
end

-- One row: text on the left, an optional action button on the right.
local function row(order: number, text: string, textColor: Color3?, buttonText: string?, buttonColor: Color3?, onClick: (() -> ())?)
	local frame = new("Frame", { Size = UDim2.new(1, -8, 0, 46), BackgroundColor3 = DARK, BackgroundTransparency = 0.15, LayoutOrder = order, Parent = list }, { corner(8), new("UIStroke", { Color = BLACK, Thickness = 2 }) })
	label({
		Size = UDim2.new(1, if buttonText then -140 else -16, 1, -8),
		Position = UDim2.fromOffset(8, 4),
		Text = text,
		TextColor3 = textColor or WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	if buttonText then
		button({ Size = UDim2.new(0, 124, 1, -10), Position = UDim2.new(1, -130, 0, 5), Text = buttonText, BackgroundColor3 = buttonColor, Parent = frame }, onClick or function() end)
	end
end

local menus = {}

function menus.Eggs(d)
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local now = workspace:GetServerTimeNow()
	row(nextOrder(), string.format("INCUBATORS (%d / %d)", #d.Incubators, Config.IncubatorsFor(d.BaseLevel)), ORANGE)
	if #d.Incubators == 0 then
		row(nextOrder(), "Nothing hatching. Pick an egg below!")
	end
	for _, entry in d.Incubators do
		local egg = Config.Eggs[entry.Egg]
		if egg then
			local left = entry.EndsAt - now
			row(nextOrder(), string.format("%s: %s", egg.Name, if left > 0 then formatTime(left) else "hatching!"), Config.Rarities[egg.Rarity].Color)
		end
	end

	row(nextOrder(), string.format("EGG BAG (%d / %d)  Hatching is free", #d.Eggs, Config.MaxEggsHeld), ORANGE)
	if #d.Eggs == 0 then
		row(nextOrder(), "No eggs yet. Sneak through a window and steal one!")
	end
	local full = #d.Incubators >= Config.IncubatorsFor(d.BaseLevel)
	for index, entry in d.Eggs do
		local eggId = Config.ParseEgg(entry)
		local egg = Config.Eggs[eggId]
		if egg then
			row(nextOrder(), string.format("%s (%s) %s", egg.Name, egg.Rarity, formatTime(egg.HatchSeconds)), Config.Rarities[egg.Rarity].Color,
				if full then "Busy" else "Hatch", if full then Color3.fromRGB(80, 80, 90) else nil, function()
					request("Hatch", index)
				end)
		end
	end
end

function menus.Pets(d)
	local income = 0
	for _, petId in d.Pets do
		local pet = Config.Pets[petId]
		income += if pet then pet.MoneyPerSecond else 0
	end
	row(0, string.format("%d / %d pets earning $%s/s", #d.Pets, Config.PetSlotsFor(d.BaseLevel), formatNumber(income)), ORANGE)
	for index, petId in d.Pets do
		local pet = Config.Pets[petId]
		if pet then
			local rarity = Config.Rarities[pet.Rarity]
			local sellValue = math.floor(pet.MoneyPerSecond * Config.PetSellSeconds)
			row(index, string.format("%s (%s) $%s/s", pet.Name, pet.Rarity, formatNumber(pet.MoneyPerSecond)), rarity.Color, "Sell $" .. formatNumber(sellValue), Color3.fromRGB(150, 40, 50), function()
				request("SellPet", index)
			end)
		end
	end
end

function menus.Rebirth(d)
	local needed = Config.RebirthLevel(d.Rebirths)
	local maxed = needed == nil
	local ready = not maxed and d.SpeedLevel >= needed
	local nextMult = Config.XpMultiplier(d.Rebirths + 1)
	row(1, string.format("Rebirths: %d / %d   Training x%s", d.Rebirths, Config.MaxRebirths, tostring(Config.XpMultiplier(d.Rebirths))), BLUE)
	if maxed then
		row(2, "MAX REBIRTHS REACHED", GREEN)
	else
		row(2, string.format("NEED: Speed Level %d (you: Level %d)", needed, d.SpeedLevel), if ready then GREEN else RED)
	end
	row(3, string.format("BONUS: train x%s faster on treadmills", tostring(nextMult)), GREEN)
	row(4, "KEEP: pets, eggs, Money, Candy, Index", WHITE)
	row(5, "KEEP: base, treadmills, trails, costumes", WHITE)
	row(6, "LOSE: Speed Level and Speed XP", RED)
	row(7, if maxed then "All rebirths done!" elseif ready then "Ready to rebirth!" else "Keep training on your treadmill", if ready or maxed then GREEN else WHITE,
		if ready then "REBIRTH" else "Locked", if ready then Color3.fromRGB(230, 40, 150) else Color3.fromRGB(80, 80, 90), function()
			if ready then
				request("Rebirth")
			end
		end)
	local speed = Config.WalkSpeedFor(d.SpeedLevel)
	row(8, "OWNER SPEEDS (yours: " .. speed .. ")", ORANGE)
	for n, house in Config.Houses do
		row(8 + n, string.format("Level %d  %s: %d", n, house.Owner, house.OwnerSpeed), if speed >= house.OwnerSpeed then GREEN else RED)
	end
end

-- Placeholder shop: nothing here is for sale yet (no Robux products exist).
local STORE_ITEMS = {
	{ Name = "2x Money forever", Kind = "Game Pass" },
	{ Name = "2x Speed XP forever", Kind = "Game Pass" },
	{ Name = "VIP: +50% Candy", Kind = "Game Pass" },
	{ Name = "+4 Pet Slots", Kind = "Game Pass" },
	{ Name = "Finish all hatching now", Kind = "Product" },
	{ Name = "$100K Money Pack", Kind = "Product" },
}
function menus.Store(_d)
	row(0, "COMING SOON", ORANGE)
	for n, item in STORE_ITEMS do
		row(n, string.format("%s (%s)", item.Name, item.Kind), WHITE, "R$ ??", Color3.fromRGB(80, 80, 90), function()
			toast("The Store opens soon!", ORANGE)
		end)
	end
end

-- A pet model in a little 3D window. Undiscovered pets are a black silhouette.
local petAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pets")
local function petViewport(petId: string, parent: Instance, silhouette: boolean)
	local viewport = new("ViewportFrame", {
		Size = UDim2.new(1, -8, 1, -44),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = WHITE,
		LightDirection = Vector3.new(-1, -1, -1),
		ImageColor3 = if silhouette then BLACK else WHITE,
		ImageTransparency = if silhouette then 0.15 else 0,
		Parent = parent,
	})
	local template = petAssets:FindFirstChild(petId)
	if not template then
		return
	end
	local model = template:Clone()
	model.Parent = viewport
	local center, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = size.Magnitude / 2 / math.tan(math.rad(20)) * 0.9
	local look = model:GetPivot().LookVector
	camera.CFrame = CFrame.lookAt(center.Position + look * distance + Vector3.new(0, size.Y * 0.3, 0), center.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
end

function menus.Index(d)
	local found = d.Discovered or {}
	local claimed = d.IndexClaimed or {}
	local total = #Config.PetOrder

	-- Progress bar
	local bar = new("Frame", { Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = DARK, BackgroundTransparency = 0.15, LayoutOrder = 0, Parent = list }, { corner(8), new("UIStroke", { Color = BLACK, Thickness = 2 }) })
	new("Frame", { Size = UDim2.fromScale(#found / total, 1), BackgroundColor3 = Color3.fromRGB(40, 150, 255), Parent = bar }, { corner(8) })
	outlined({ Size = UDim2.new(1, 0, 1, -8), Position = UDim2.fromOffset(0, 4), Text = string.format("%d / %d discovered", #found, total), ZIndex = 2, Parent = bar })

	for n, reward in Config.IndexRewards do
		local done = table.find(claimed, reward.Count) ~= nil
		local ready = not done and #found >= reward.Count
		row(n, string.format("%d pets: $%s", reward.Count, formatNumber(reward.Money)), if done then Color3.fromRGB(150, 150, 150) elseif ready then GREEN else WHITE,
			if done then "Claimed" elseif ready then "Claim" else string.format("%d/%d", math.min(#found, reward.Count), reward.Count),
			if ready then Color3.fromRGB(40, 190, 60) else Color3.fromRGB(80, 80, 90), function()
				if ready then
					request("ClaimIndex", reward.Count)
				end
			end)
	end

	local grid = new("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 10, Parent = list }, {
		new("UIGridLayout", { CellSize = UDim2.new(0.25, -6, 0, 128), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for n, petId in Config.PetOrder do
		local pet = Config.Pets[petId]
		local known = table.find(found, petId) ~= nil
		local rarity = Config.Rarities[pet.Rarity]
		local card = new("Frame", { BackgroundColor3 = DARK, BackgroundTransparency = 0.15, LayoutOrder = n, Parent = grid }, {
			corner(10),
			new("UIStroke", { Color = if known then rarity.Color else BLACK, Thickness = 2 }),
		})
		petViewport(petId, card, not known)
		outlined({ Size = UDim2.new(1, -6, 0, 20), Position = UDim2.new(0, 3, 1, -40), Text = if known then pet.Name else "???", Parent = card }, 1.5)
		label({ Size = UDim2.new(1, -6, 0, 16), Position = UDim2.new(0, 3, 1, -19), Text = if known then pet.Rarity else "", TextColor3 = rarity.Color, Parent = card })
	end
end

-- The Speed Shop has two tabs: Treadmills (Candy) and Trails (Money).
local shopTab = "Treadmills"
local function tabRow(order: number)
	local frame = new("Frame", { Size = UDim2.new(1, -8, 0, 40), BackgroundTransparency = 1, LayoutOrder = order, Parent = list })
	for i, name in { "Treadmills", "Trails" } do
		button({
			Size = UDim2.new(0.5, -4, 1, 0),
			Position = UDim2.new((i - 1) * 0.5, (i - 1) * 4, 0, 0),
			Text = name,
			BackgroundColor3 = if shopTab == name then ORANGE else Color3.fromRGB(80, 70, 95),
			Parent = frame,
		}, function()
			shopTab = name
			renderMenu()
		end)
	end
end

function menus.Treadmills(d)
	tabRow(-1)
	if shopTab == "Trails" then
		row(0, "TRAILS (paid with Money, multiply treadmill XP)", ORANGE)
		for index, info in Config.Trails do
			local owned = table.find(d.OwnedTrails or {}, index) ~= nil
			local equipped = d.Trail == index
			local text = string.format("%s  x%s XP", info.Name, tostring(info.Multiplier))
			local buttonText = if equipped then "Equipped" elseif owned then "Equip" else "$" .. formatNumber(info.Price)
			row(index, text, info.Color, buttonText, if equipped then Color3.fromRGB(80, 80, 90) else nil, function()
				request("BuyTrail", index)
			end)
		end
		return
	end
	row(0, "TREADMILLS (paid with Candy)", ORANGE)
	for tier, info in Config.Treadmills do
		local text = string.format("%s  +%d XP/s", info.Name, info.XpPerSecond)
		if tier <= d.Treadmill then
			row(tier, text, info.Color, if tier == d.Treadmill then "Owned" else "-", Color3.fromRGB(80, 80, 90))
		else
			row(tier, text, info.Color, formatNumber(info.Price) .. " Candy", nil, function()
				request("BuyTreadmill", tier)
			end)
		end
	end
end

renderMenu = function()
	if not (openMenu and data) then
		return
	end
	local scroll = list.CanvasPosition
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	panelTitle.Text = TITLES[openMenu] or openMenu
	menus[openMenu](data)
	list.CanvasPosition = scroll
end

-- Menus only need a redraw when something other than the ticking Money changes.
local lastMenuKey = ""
local function menuKey(d)
	local incubating = {}
	for _, entry in d.Incubators do
		table.insert(incubating, entry.Egg)
	end
	return table.concat({
		openMenu or "", shopTab, d.SpeedLevel, d.Rebirths, d.Treadmill, d.Trail or 0, #(d.OwnedTrails or {}), d.EquippedCostume,
		table.concat(d.Eggs, ","), table.concat(incubating, ","), table.concat(d.Pets, ","),
		table.concat(d.Discovered or {}, ","), table.concat(d.IndexClaimed or {}, ","), d.BaseLevel,
		if openMenu == "Treadmills" then math.floor(if shopTab == "Trails" then d.Money / 1000 else d.Candy) else 0,
	}, "|")
end

local function toggleMenu(name: string, forceOpen: boolean?)
	if openMenu == name and not forceOpen then
		openMenu = nil
		panel.Visible = false
		return
	end
	openMenu = name
	panelGradient.Color = themeGradient(name)
	panel.Visible = true
	lastMenuKey = ""
	renderMenu()
end

-- Studded menu buttons stacked on the left. They scale with screen height so they fit phones too.
local MENU_BUTTONS = {
	{ Menu = "Rebirth", Image = "rbxassetid://134156079401542" },
	{ Menu = "Index", Image = "rbxassetid://120727874564424" },
	{ Menu = "Pets", Image = "rbxassetid://114367839008367" },
	{ Menu = "Eggs", Image = "rbxassetid://127453926615025" },
	{ Menu = "Store", Image = "rbxassetid://82681777153242" },
}
local menuButtons = new("Frame", {
	Name = "MenuButtons",
	AnchorPoint = Vector2.new(0, 0.5),
	Size = UDim2.new(0, 100, 0.72, 0),
	Position = UDim2.new(0, 10, 0.54, 0),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0.02, 0), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
for order, info in MENU_BUTTONS do
	local tile = new("ImageButton", {
		Name = info.Menu .. "Button",
		Image = info.Image,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 0.18),
		LayoutOrder = order,
		Parent = menuButtons,
	}, {
		new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }),
		new("UISizeConstraint", { MaxSize = Vector2.new(92, 92), MinSize = Vector2.new(50, 50) }),
	})
	local scale = new("UIScale", { Parent = tile })
	tile.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.07 }):Play()
	end)
	tile.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	tile.Activated:Connect(function()
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		toggleMenu(info.Menu)
	end)
end

-- The Speed Shop counter opens the treadmill menu.
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local menu = prompt:GetAttribute("OpenMenu")
	if menu and menus[menu] then
		toggleMenu(menu, true)
	end
end)

---------------------------------------------------------------------------
-- Server events
---------------------------------------------------------------------------
local function refreshStats(d)
	candyLabel.Text = "Candy: " .. formatNumber(d.Candy)
	moneyLabel.Text = "$" .. formatNumber(d.Money)
	speedLabel.Text = string.format("Speed %d (Lv %d)", Config.WalkSpeedFor(d.SpeedLevel), d.SpeedLevel)
	if d.SpeedLevel >= Config.MaxSpeedLevel then
		xpFill.Size = UDim2.fromScale(1, 1)
		xpText.Text = "MAX SPEED"
	else
		local need = Config.XpToNext(d.SpeedLevel)
		xpFill.Size = UDim2.fromScale(math.clamp(d.SpeedXp / need, 0, 1), 1)
		xpText.Text = string.format("Speed XP %d / %d", math.floor(d.SpeedXp), need)
	end
end

Remotes.DataChanged.OnClientEvent:Connect(function(newData)
	data = newData
	refreshStats(newData)
	if openMenu then
		local key = menuKey(newData)
		if key ~= lastMenuKey then
			lastMenuKey = key
			renderMenu()
		end
	end
end)

Remotes.Notify.OnClientEvent:Connect(function(text: string, color: Color3?)
	toast(text, color)
end)

local function refreshBanner(chasedBy: string?)
	if chasedBy then
		banner.Text = "RUN! " .. chasedBy .. " is chasing you!"
		banner.BackgroundColor3 = Color3.fromRGB(170, 20, 30)
		banner.Visible = true
	elseif player:GetAttribute("CarryingEgg") then
		banner.Text = "Carrying an egg: get back to your base!"
		banner.BackgroundColor3 = Color3.fromRGB(160, 90, 10)
		banner.Visible = true
	else
		banner.Visible = false
	end
end

Remotes.ChaseState.OnClientEvent:Connect(function(isChased: boolean, ownerName: string?)
	refreshBanner(if isChased then ownerName else nil)
end)
player:GetAttributeChangedSignal("CarryingEgg"):Connect(function()
	refreshBanner(nil)
end)

---------------------------------------------------------------------------
-- Treadmill auto-run: standing on your own treadmill makes your character run by itself. Jump to get off.
---------------------------------------------------------------------------
local jumpedOff = false
RunService:BindToRenderStep("TreadmillAutoRun", Enum.RenderPriority.Character.Value + 1, function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plotName = player:GetAttribute("Plot")
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	local plot = plots and plotName and plots:FindFirstChild(plotName)
	local treadmill = plot and plot:FindFirstChild("Treadmill")
	local belt = treadmill and treadmill:FindFirstChild("Belt") :: BasePart?
	if not (humanoid and root and belt) then
		return
	end
	local offset = belt.CFrame:PointToObjectSpace(root.Position)
	local onBelt = math.abs(offset.X) <= belt.Size.X / 2 + 0.5 and math.abs(offset.Z) <= belt.Size.Z / 2 + 0.5 and offset.Y > 0 and offset.Y < 6
	if not onBelt then
		jumpedOff = false
		return
	end
	if humanoid.Jump then
		jumpedOff = true -- the belt carries you off the back once you stop running
	end
	if not jumpedOff then
		humanoid:Move(belt.CFrame.LookVector, false)
	end
end)

-- Night/day timer, and a live countdown in the Eggs menu.
task.spawn(function()
	local tick = 0
	while true do
		local isNight = ReplicatedStorage:GetAttribute("IsNight")
		local endsAt = ReplicatedStorage:GetAttribute("PhaseEndsAt")
		if endsAt then
			local left = endsAt - workspace:GetServerTimeNow()
			if isNight then
				phaseLabel.Text = "NIGHT " .. formatTime(left)
				phaseLabel.TextColor3 = Color3.fromRGB(190, 140, 255)
			else
				phaseLabel.Text = "DAY " .. formatTime(left) .. " (street closed)"
				phaseLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
			end
		end
		tick += 1
		if tick % 4 == 0 and openMenu == "Eggs" then
			renderMenu()
		end
		task.wait(0.25)
	end
end)
