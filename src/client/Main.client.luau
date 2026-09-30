-- Client: HUD (Candy and Money pills, night/day timer, chase banner, messages, speed level bar at the bottom),
-- the studded menu buttons on the left (Rebirth, Index, Pet, Egg, Store) and their panels, and the Speed Shop menu.
-- Look: chunky cartoon UI. White studded panels with thick black outlines, cyan boxes, glossy gradient buttons
-- and white text with a black outline.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local data: { [string]: any }? = nil

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local ORANGE = Color3.fromRGB(255, 170, 40)
local CYAN = Color3.fromRGB(90, 230, 255)
local GREEN = Color3.fromRGB(120, 255, 120)
local RED = Color3.fromRGB(255, 70, 70)

-- Gradient colours (top, bottom) for boxes and buttons; (left, right) for bar fills.
local PAINT = {
	Cyan = { Color3.fromRGB(120, 235, 255), Color3.fromRGB(25, 165, 240) },
	Orange = { Color3.fromRGB(255, 220, 70), Color3.fromRGB(255, 140, 20) },
	Purple = { Color3.fromRGB(240, 120, 255), Color3.fromRGB(165, 45, 230) },
	Green = { Color3.fromRGB(160, 245, 80), Color3.fromRGB(60, 185, 40) },
	Red = { Color3.fromRGB(255, 110, 110), Color3.fromRGB(215, 35, 50) },
	Grey = { Color3.fromRGB(195, 195, 205), Color3.fromRGB(125, 125, 140) },
	Night = { Color3.fromRGB(160, 120, 255), Color3.fromRGB(85, 45, 185) },
	Day = { Color3.fromRGB(255, 235, 120), Color3.fromRGB(255, 170, 40) },
	Panel = { WHITE, Color3.fromRGB(230, 235, 245) },
	LevelFill = { Color3.fromRGB(255, 100, 20), Color3.fromRGB(255, 235, 60) },
	XpFill = { Color3.fromRGB(100, 215, 30), Color3.fromRGB(190, 250, 80) },
}

---------------------------------------------------------------------------
-- UI kit
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
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

local function gradient(paint: { Color3 }, rotation: number?)
	return new("UIGradient", { Rotation = rotation or 90, Color = ColorSequence.new(paint[1], paint[2]) })
end

-- Thick black outline around a frame or button.
local function border(thickness: number?)
	return new("UIStroke", { Color = BLACK, Thickness = thickness or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

-- White text with a thick black outline.
local function outlined(props: { [string]: any }, thickness: number?)
	props.BackgroundTransparency = 1
	props.Font = props.Font or Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or WHITE
	props.TextScaled = true
	local l = new("TextLabel", props)
	new("UIStroke", { Color = BLACK, Thickness = thickness or 2, LineJoinMode = Enum.LineJoinMode.Round, Parent = l })
	return l
end

-- Glossy highlight across the top half of a box.
local function shine(parent: GuiObject)
	new("Frame", {
		Size = UDim2.new(1, -10, 0.42, 0),
		Position = UDim2.fromOffset(5, 3),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.55,
		Parent = parent,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, 8) }),
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.2, 1) }),
	})
end

-- A rounded box with a gradient, gloss and a black outline.
local function box(props: { [string]: any }, paint: { Color3 })
	props.BackgroundColor3 = WHITE
	local f = new("Frame", props, { corner(), gradient(paint), border() })
	shine(f)
	return f
end

-- Grows a little on hover and squashes when clicked.
local function bounce(target: GuiButton)
	local scale = new("UIScale", { Parent = target })
	target.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.06 }):Play()
	end)
	target.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	target.Activated:Connect(function()
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end)
end

local function chunkyButton(props: { [string]: any }, paint: { Color3 }, onClick: () -> ())
	local text = props.Text
	props.Text = ""
	props.BackgroundColor3 = WHITE
	props.AutoButtonColor = false
	local b = new("TextButton", props, { corner(), gradient(paint), border() })
	shine(b)
	outlined({ Size = UDim2.new(1, -14, 1, -12), Position = UDim2.fromOffset(7, 6), Text = text, ZIndex = 2, Parent = b }, 2)
	bounce(b)
	b.Activated:Connect(onClick)
	return b
end

-- Dark rounded track with a gradient fill. Returns the track and the fill; size the fill with `setBar`.
local function progressBar(props: { [string]: any }, fillPaint: { Color3 })
	props.BackgroundColor3 = Color3.fromRGB(45, 35, 60)
	local back = new("Frame", props, { corner(), border() })
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, Parent = back }, { corner(), gradient(fillPaint, 0) })
	shine(fill)
	return back, fill
end

local function setBar(fill: Frame, ratio: number, animate: boolean?)
	ratio = math.clamp(ratio, 0, 1)
	fill.Visible = ratio > 0.02 -- a sliver of fill looks broken with rounded corners
	local size = UDim2.fromScale(ratio, 1)
	if animate and ratio >= fill.Size.X.Scale then
		TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), { Size = size }):Play()
	else
		fill.Size = size
	end
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

local toggleMenu: (name: string, forceOpen: boolean?) -> ()

---------------------------------------------------------------------------
-- HUD
---------------------------------------------------------------------------
local gui = new("ScreenGui", { Name = "SpookyHUD", ResetOnSpawn = false, IgnoreGuiInset = false, Parent = player:WaitForChild("PlayerGui") })

-- Candy and Money pills, top centre
local currencyBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromOffset(424, 48),
	Position = UDim2.new(0.5, 0, 0, 10),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local function currencyPill(order: number, paint: { Color3 }, icon: string)
	local pill = box({ Size = UDim2.fromOffset(200, 48), LayoutOrder = order, Parent = currencyBar }, paint)
	new("TextLabel", { Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(7, 5), BackgroundTransparency = 1, Text = icon, TextScaled = true, ZIndex = 2, Parent = pill })
	return outlined({ Size = UDim2.new(1, -62, 1, -14), Position = UDim2.fromOffset(52, 7), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Parent = pill }, 2.5)
end
local candyLabel = currencyPill(1, PAINT.Orange, "🍬")
local moneyLabel = currencyPill(2, PAINT.Green, "💰")

-- Night / day timer under the currencies
local phasePill = box({ AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(250, 40), Position = UDim2.new(0.5, 0, 0, 66), Parent = gui }, PAINT.Night)
local phaseGradient = phasePill:FindFirstChildOfClass("UIGradient") :: UIGradient
local phaseLabel = outlined({ Size = UDim2.new(1, -20, 1, -12), Position = UDim2.fromOffset(10, 6), Text = "", ZIndex = 2, Parent = phasePill }, 2)

-- Chase / carrying banner. Pulses gently while shown.
local banner = box({ AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(520, 48), Position = UDim2.new(0.5, 0, 0, 118), Visible = false, Parent = gui }, PAINT.Red)
local bannerGradient = banner:FindFirstChildOfClass("UIGradient") :: UIGradient
local bannerLabel = outlined({ Size = UDim2.new(1, -24, 1, -14), Position = UDim2.fromOffset(12, 7), Text = "", ZIndex = 2, Parent = banner }, 2.5)
TweenService:Create(new("UIScale", { Parent = banner }), TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.05 }):Play()

-- Speed level bar, bottom centre: walk speed and rebirth bonus above a Level / XP bar, with a + that opens the Speed Shop.
local levelHud = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.new(0.5, 0, 0, 84),
	Position = UDim2.new(0.5, 0, 1, -12),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UISizeConstraint", { MaxSize = Vector2.new(640, 84), MinSize = Vector2.new(340, 84) }) })
local speedLabel = outlined({ AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0.45, 0, 0, 28), Position = UDim2.fromScale(0.45, 0), Text = "", Parent = levelHud }, 2.5)
local rebirthLabel = outlined({ AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0.3, 0, 0, 26), Position = UDim2.new(1, -56, 0, 1), Text = "", TextColor3 = CYAN, TextXAlignment = Enum.TextXAlignment.Right, Parent = levelHud }, 2.5)
local levelBar, xpFill = progressBar({ Size = UDim2.new(1, -56, 0, 46), Position = UDim2.fromOffset(0, 34), Parent = levelHud }, PAINT.LevelFill)
local levelLabel = outlined({ Size = UDim2.new(0.5, -16, 1, -14), Position = UDim2.fromOffset(16, 7), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = levelBar }, 2.5)
local xpText = outlined({ Size = UDim2.new(0.5, -16, 1, -16), Position = UDim2.new(0.5, 0, 0, 8), Text = "", TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3, Parent = levelBar }, 2.5)
chunkyButton({ Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, -46, 0, 34), Text = "+", Parent = levelHud }, PAINT.Orange, function()
	toggleMenu("Treadmills", true)
end)

-- Messages float up from above the level bar as outlined text.
local toastHolder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(560, 200),
	Position = UDim2.new(0.5, 0, 1, -110),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 4) }),
})

local function toast(text: string, color: Color3?)
	local t = outlined({ Size = UDim2.new(1, 0, 0, 32), TextColor3 = color or WHITE, Text = text, Parent = toastHolder }, 2.5)
	local scale = new("UIScale", { Scale = 0.6, Parent = t })
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(4, function()
		local fade = TweenInfo.new(0.4)
		TweenService:Create(t, fade, { TextTransparency = 1 }):Play()
		local tween = TweenService:Create(t:FindFirstChildOfClass("UIStroke") :: UIStroke, fade, { Transparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		t:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Menus
---------------------------------------------------------------------------
local TITLES = { Rebirth = "Rebirth", Index = "Pet Index", Pets = "Your Pets", Eggs = "Eggs", Store = "Store", Treadmills = "Speed Shop" }
local ICONS = {
	Rebirth = "rbxassetid://134156079401542",
	Index = "rbxassetid://120727874564424",
	Pets = "rbxassetid://114367839008367",
	Eggs = "rbxassetid://127453926615025",
	Store = "rbxassetid://82681777153242",
}

-- Light grey stud outlines on the white panel, like a Lego plate.
local function studs(parent: Instance, cellSize: UDim2, count: number)
	local layer = new("CanvasGroup", { Name = "Studs", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = parent }, {
		new("UICorner", { CornerRadius = UDim.new(0, 22) }),
		new("UIGridLayout", { CellSize = cellSize, CellPadding = UDim2.new(), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for _ = 1, count do
		local cell = new("Frame", { BackgroundTransparency = 1, Parent = layer })
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6),
			BackgroundTransparency = 1, Parent = cell,
		}, {
			new("UICorner", { CornerRadius = UDim.new(0.25, 0) }),
			new("UIStroke", { Color = Color3.fromRGB(215, 218, 228), Thickness = 2 }),
		})
	end
	return layer
end

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromScale(0.62, 0.76),
	Position = UDim2.fromScale(0.54, 0.54),
	BackgroundColor3 = WHITE,
	Visible = false,
	Parent = gui,
}, {
	corner(22),
	border(4),
	gradient(PAINT.Panel),
	new("UISizeConstraint", { MaxSize = Vector2.new(620, 470), MinSize = Vector2.new(320, 260) }),
})
local panelScale = new("UIScale", { Parent = panel })
studs(panel, UDim2.fromOffset(28, 28), 23 * 18)

-- Title sticks out over the top-left corner: menu icon, then the name in big outlined letters.
local panelIcon = new("ImageLabel", { Size = UDim2.fromOffset(68, 68), Position = UDim2.fromOffset(-14, -40), BackgroundTransparency = 1, ZIndex = 3, Parent = panel })
local panelTitle = outlined({ Size = UDim2.new(0.7, 0, 0, 52), Position = UDim2.fromOffset(58, -30), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = panel }, 3.5)

local list = new("ScrollingFrame", {
	Size = UDim2.new(1, -28, 1, -54),
	Position = UDim2.fromOffset(14, 38),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Color3.fromRGB(60, 60, 80),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = panel,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) }), -- room for the outlines
})

local openMenu: string? = nil
local renderMenu: () -> ()

-- Big red outlined X over the top-right corner.
local closeButton = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(60, 60),
	Position = UDim2.new(1, -8, 0, 8),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	Text = "X",
	TextColor3 = Color3.fromRGB(240, 40, 40),
	TextScaled = true,
	ZIndex = 3,
	Parent = panel,
}, { new("UIStroke", { Color = BLACK, Thickness = 4, LineJoinMode = Enum.LineJoinMode.Round }) })
bounce(closeButton)
closeButton.Activated:Connect(function()
	openMenu = nil
	panel.Visible = false
end)

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

-- Section heading: coloured outlined text straight on the panel.
local function header(order: number, text: string, color: Color3?)
	local f = new("Frame", { Size = UDim2.new(1, -8, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Parent = list })
	outlined({ Size = UDim2.new(1, -8, 1, -2), Position = UDim2.fromOffset(4, 1), Text = text, TextColor3 = color or ORANGE, TextXAlignment = Enum.TextXAlignment.Left, Parent = f }, 2.5)
end

-- One cyan row: text on the left, an optional button on the right.
local function row(order: number, text: string, textColor: Color3?, buttonText: string?, buttonPaint: { Color3 }?, onClick: (() -> ())?)
	local frame = box({ Size = UDim2.new(1, -8, 0, 52), LayoutOrder = order, Parent = list }, PAINT.Cyan)
	outlined({
		Size = UDim2.new(1, if buttonText then -156 else -28, 1, -16),
		Position = UDim2.fromOffset(14, 8),
		Text = text,
		TextColor3 = textColor or WHITE,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = frame,
	}, 2)
	if buttonText then
		chunkyButton({ Size = UDim2.new(0, 132, 1, -12), Position = UDim2.new(1, -138, 0, 6), Text = buttonText, ZIndex = 2, Parent = frame }, buttonPaint or PAINT.Green, onClick or function() end)
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
	header(nextOrder(), string.format("Incubators (%d / %d)", #d.Incubators, Config.IncubatorsFor(d.BaseLevel)))
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

	header(nextOrder(), string.format("Egg Bag (%d / %d) - hatching is free", #d.Eggs, Config.MaxEggsHeld))
	if #d.Eggs == 0 then
		row(nextOrder(), "No eggs yet. Sneak through a window and steal one!")
	end
	local full = #d.Incubators >= Config.IncubatorsFor(d.BaseLevel)
	for index, entry in d.Eggs do
		local eggId = Config.ParseEgg(entry)
		local egg = Config.Eggs[eggId]
		if egg then
			row(nextOrder(), string.format("%s (%s) %s", egg.Name, egg.Rarity, formatTime(egg.HatchSeconds)), Config.Rarities[egg.Rarity].Color,
				if full then "Busy" else "Hatch", if full then PAINT.Grey else PAINT.Green, function()
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
	header(0, string.format("%d / %d pets earning $%s/s", #d.Pets, Config.PetSlotsFor(d.BaseLevel), formatNumber(income)))
	for index, petId in d.Pets do
		local pet = Config.Pets[petId]
		if pet then
			local rarity = Config.Rarities[pet.Rarity]
			local sellValue = math.floor(pet.MoneyPerSecond * Config.PetSellSeconds)
			row(index, string.format("%s (%s) $%s/s", pet.Name, pet.Rarity, formatNumber(pet.MoneyPerSecond)), rarity.Color, "Sell $" .. formatNumber(sellValue), PAINT.Red, function()
				request("SellPet", index)
			end)
		end
	end
end

-- Rebirth: current vs next rebirth side by side, a level bar towards the next one, and the Rebirth button.
local function spacer(order: number, height: number)
	return new("Frame", { Size = UDim2.new(1, -8, 0, height), BackgroundTransparency = 1, LayoutOrder = order, Parent = list })
end

local function compareRow(order: number, left: string, right: string)
	local f = spacer(order, 58)
	for i, text in { left, right } do
		local b = box({ Size = UDim2.new(0.42, 0, 1, -6), Position = UDim2.new((i - 1) * 0.58, 0, 0, 3), Parent = f }, PAINT.Cyan)
		outlined({ Size = UDim2.new(1, -20, 1, -14), Position = UDim2.fromOffset(10, 7), Text = text, ZIndex = 2, Parent = b }, 2.5)
	end
	outlined({ Size = UDim2.new(0.16, 0, 0.6, 0), Position = UDim2.fromScale(0.42, 0.2), Text = ">>", TextColor3 = ORANGE, Parent = f }, 2)
end

function menus.Rebirth(d)
	local needed = Config.RebirthLevel(d.Rebirths)
	local maxed = needed == nil
	local ready = not maxed and d.SpeedLevel >= needed

	local titles = spacer(1, 34)
	outlined({ Size = UDim2.fromScale(0.42, 1), Text = "Rebirth " .. d.Rebirths, Parent = titles }, 2.5)
	outlined({ Size = UDim2.fromScale(0.42, 1), Position = UDim2.fromScale(0.58, 0), Text = if maxed then "MAX" else "Rebirth " .. (d.Rebirths + 1), Parent = titles }, 2.5)

	local mult = "⚡x" .. tostring(Config.XpMultiplier(d.Rebirths)) .. " XP"
	if maxed then
		compareRow(2, mult, "MAX")
	else
		compareRow(2, mult, "⚡x" .. tostring(Config.XpMultiplier(d.Rebirths + 1)) .. " XP")
		compareRow(3, "Speed Lv " .. d.SpeedLevel, "Speed Lv 0")
	end

	local notes = spacer(4, 46)
	outlined({ Size = UDim2.new(1, 0, 0, 24), Text = "Rebirth resets your Speed Level, but gives a permanent training bonus.", TextColor3 = RED, Parent = notes }, 1.5)
	outlined({ Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 26), Text = "You keep pets, eggs, Money, Candy, treadmills, trails and costumes.", TextColor3 = Color3.fromRGB(90, 200, 60), Parent = notes }, 1.5)

	local barHolder = spacer(5, 40)
	local bar, fill = progressBar({ Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3), Parent = barHolder }, PAINT.XpFill)
	setBar(fill, if maxed then 1 else d.SpeedLevel / needed)
	outlined({
		Size = UDim2.new(1, -24, 1, -12),
		Position = UDim2.fromOffset(12, 6),
		Text = if maxed then "ALL REBIRTHS DONE" else string.format("LV.%d/LV.%d", d.SpeedLevel, needed),
		ZIndex = 3,
		Parent = bar,
	}, 2)

	local buttons = spacer(6, 62)
	chunkyButton({ Size = UDim2.new(0.4, 0, 1, -6), Position = UDim2.new(0.07, 0, 0, 3), Text = if ready then "Rebirth" elseif maxed then "Maxed" else "Locked", Parent = buttons },
		if ready then PAINT.Orange else PAINT.Grey, function()
			if ready then
				request("Rebirth")
			else
				toast(if maxed then "All rebirths done!" else string.format("Reach Speed Level %d to rebirth.", needed), ORANGE)
			end
		end)
	chunkyButton({ Size = UDim2.new(0.4, 0, 1, -6), Position = UDim2.new(0.53, 0, 0, 3), Text = "Train Faster", Parent = buttons }, PAINT.Purple, function()
		toggleMenu("Treadmills", true)
	end)
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
	header(0, "Coming soon!")
	for n, item in STORE_ITEMS do
		row(n, string.format("%s (%s)", item.Name, item.Kind), WHITE, "R$ ??", PAINT.Grey, function()
			toast("The Store opens soon!", ORANGE)
		end)
	end
end

-- A pet model in a little 3D window. Undiscovered pets are a black silhouette.
local petAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pets")
local function petViewport(petId: string, parent: Instance, silhouette: boolean)
	local viewport = new("ViewportFrame", {
		Size = UDim2.new(1, -8, 1, -46),
		Position = UDim2.fromOffset(4, 4),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(170, 170, 170),
		LightColor = WHITE,
		LightDirection = Vector3.new(-1, -1, -1),
		ImageColor3 = if silhouette then BLACK else WHITE,
		ImageTransparency = if silhouette then 0.15 else 0,
		ZIndex = 2,
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

	local barHolder = spacer(0, 44)
	local bar, fill = progressBar({ Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3), Parent = barHolder }, PAINT.XpFill)
	setBar(fill, #found / total)
	outlined({ Size = UDim2.new(1, -24, 1, -12), Position = UDim2.fromOffset(12, 6), Text = string.format("%d / %d discovered", #found, total), ZIndex = 3, Parent = bar }, 2)

	for n, reward in Config.IndexRewards do
		local done = table.find(claimed, reward.Count) ~= nil
		local ready = not done and #found >= reward.Count
		row(n, string.format("%d pets: $%s", reward.Count, formatNumber(reward.Money)), if done then Color3.fromRGB(200, 200, 200) elseif ready then GREEN else WHITE,
			if done then "Claimed" elseif ready then "Claim" else string.format("%d/%d", math.min(#found, reward.Count), reward.Count),
			if ready then PAINT.Green else PAINT.Grey, function()
				if ready then
					request("ClaimIndex", reward.Count)
				end
			end)
	end

	local grid = new("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 10, Parent = list }, {
		new("UIGridLayout", { CellSize = UDim2.new(0.25, -8, 0, 132), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingTop = UDim.new(0, 3) }),
	})
	for n, petId in Config.PetOrder do
		local pet = Config.Pets[petId]
		local known = table.find(found, petId) ~= nil
		local rarity = Config.Rarities[pet.Rarity]
		local card = box({ LayoutOrder = n, Parent = grid }, if known then PAINT.Cyan else PAINT.Grey)
		petViewport(petId, card, not known)
		outlined({ Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0, 4, 1, -42), Text = if known then pet.Name else "???", ZIndex = 2, Parent = card }, 1.5)
		outlined({ Size = UDim2.new(1, -8, 0, 17), Position = UDim2.new(0, 4, 1, -21), Text = if known then pet.Rarity else "", TextColor3 = rarity.Color, ZIndex = 2, Parent = card }, 1.5)
	end
end

-- The Speed Shop has two tabs: Treadmills (Candy) and Trails (Money).
local shopTab = "Treadmills"
local function tabRow(order: number)
	local frame = spacer(order, 48)
	for i, name in { "Treadmills", "Trails" } do
		chunkyButton({
			Size = UDim2.new(0.5, -6, 1, -6),
			Position = UDim2.new((i - 1) * 0.5, (i - 1) * 6 + 3, 0, 3),
			Text = name,
			Parent = frame,
		}, if shopTab == name then PAINT.Orange else PAINT.Grey, function()
			shopTab = name
			renderMenu()
		end)
	end
end

function menus.Treadmills(d)
	tabRow(-1)
	if shopTab == "Trails" then
		header(0, "Trails: paid with Money, multiply treadmill XP")
		for index, info in Config.Trails do
			local owned = table.find(d.OwnedTrails or {}, index) ~= nil
			local equipped = d.Trail == index
			local text = string.format("%s  x%s XP", info.Name, tostring(info.Multiplier))
			local buttonText = if equipped then "Equipped" elseif owned then "Equip" else "$" .. formatNumber(info.Price)
			row(index, text, info.Color, buttonText, if equipped then PAINT.Grey elseif owned then PAINT.Orange else PAINT.Green, function()
				request("BuyTrail", index)
			end)
		end
		return
	end
	header(0, "Treadmills: paid with Candy")
	for tier, info in Config.Treadmills do
		local text = string.format("%s  +%d XP/s", info.Name, info.XpPerSecond)
		if tier <= d.Treadmill then
			row(tier, text, info.Color, if tier == d.Treadmill then "Owned" else "-", PAINT.Grey)
		else
			row(tier, text, info.Color, formatNumber(info.Price) .. " Candy", PAINT.Green, function()
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
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local icon = ICONS[openMenu]
	panelIcon.Image = icon or ""
	panelIcon.Visible = icon ~= nil
	panelTitle.Position = UDim2.fromOffset(if icon then 58 else 16, -30)
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

toggleMenu = function(name: string, forceOpen: boolean?)
	if openMenu == name and not forceOpen then
		openMenu = nil
		panel.Visible = false
		return
	end
	local wasOpen = panel.Visible
	openMenu = name
	panel.Visible = true
	if not wasOpen then
		panelScale.Scale = 0.85
		TweenService:Create(panelScale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	lastMenuKey = ""
	renderMenu()
end

-- Studded menu buttons stacked on the left. They scale with screen height so they fit phones too.
local MENU_ORDER = { "Rebirth", "Index", "Pets", "Eggs", "Store" }
local menuButtons = new("Frame", {
	Name = "MenuButtons",
	AnchorPoint = Vector2.new(0, 0.5),
	Size = UDim2.new(0, 100, 0.72, 0),
	Position = UDim2.new(0, 10, 0.54, 0),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UIListLayout", { Padding = UDim.new(0.02, 0), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }) })
for order, menu in MENU_ORDER do
	local tile = new("ImageButton", {
		Name = menu .. "Button",
		Image = ICONS[menu],
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.fromScale(1, 0.18),
		LayoutOrder = order,
		Parent = menuButtons,
	}, {
		new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }),
		new("UISizeConstraint", { MaxSize = Vector2.new(92, 92), MinSize = Vector2.new(50, 50) }),
	})
	bounce(tile)
	tile.Activated:Connect(function()
		toggleMenu(menu)
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
	candyLabel.Text = formatNumber(d.Candy)
	moneyLabel.Text = "$" .. formatNumber(d.Money)
	speedLabel.Text = "Speed: " .. Config.WalkSpeedFor(d.SpeedLevel)
	rebirthLabel.Text = "Rebirth: x" .. tostring(Config.XpMultiplier(d.Rebirths))
	levelLabel.Text = "Level " .. d.SpeedLevel
	if d.SpeedLevel >= Config.MaxSpeedLevel then
		setBar(xpFill, 1)
		xpText.Text = "MAX"
	else
		local need = Config.XpToNext(d.SpeedLevel)
		setBar(xpFill, d.SpeedXp / need, true)
		xpText.Text = formatNumber(d.SpeedXp) .. "/" .. formatNumber(need)
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
		bannerLabel.Text = "RUN! " .. chasedBy .. " is chasing you!"
		bannerGradient.Color = ColorSequence.new(PAINT.Red[1], PAINT.Red[2])
		banner.Visible = true
	elseif player:GetAttribute("CarryingEgg") then
		bannerLabel.Text = "Carrying an egg: get back to your base!"
		bannerGradient.Color = ColorSequence.new(PAINT.Orange[1], PAINT.Orange[2])
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
			local paint = if isNight then PAINT.Night else PAINT.Day
			phaseGradient.Color = ColorSequence.new(paint[1], paint[2])
			phaseLabel.Text = if isNight then "🌙 NIGHT " .. formatTime(left) else "☀️ DAY " .. formatTime(left) .. " - street closed"
		end
		tick += 1
		if tick % 4 == 0 and openMenu == "Eggs" then
			renderMenu()
		end
		task.wait(0.25)
	end
end)
