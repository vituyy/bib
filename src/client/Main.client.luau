-- Client: HUD (Candy and Money on the right, night/day timer, chase banner, messages, speed level bar at the bottom,
-- friend boost in the bottom left), the studded menu buttons on the left (Rebirth, Index, Pet, Egg, Store) and their
-- panels, and the Speed Shop menu.
-- Look: chunky cartoon UI. White studded panels with thick black outlines, cyan boxes, glossy gradient buttons
-- and white text with a black outline. Pets and Eggs use a darker inventory window with a blue title bar.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Art = require(ReplicatedStorage.Shared.Art)
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
	Panel = { WHITE, Color3.fromRGB(230, 235, 245) },
	Header = { Color3.fromRGB(100, 215, 255), Color3.fromRGB(25, 125, 230) },
	CandyText = { Color3.fromRGB(255, 175, 220), Color3.fromRGB(240, 60, 150) },
	MoneyText = { Color3.fromRGB(255, 240, 60), Color3.fromRGB(255, 160, 0) },
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

-- Money and Candy, right side in the middle: a cartoon icon and a big number in gradient letters
-- with a thick black outline. The icons are drawn from shapes; to use your own pictures instead,
-- upload them to Roblox and put their ids here (e.g. "rbxassetid://123").
local CURRENCY_IMAGES = { Money = "", Candy = "" }

local function circle(props: { [string]: any }, paint: { Color3 }, outline: number?)
	props.BackgroundColor3 = WHITE
	return new("Frame", props, {
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		gradient(paint),
		border(outline or 3),
	})
end

-- A stack of gold coins with a big "$" coin in front.
local function drawCoins(icon: Frame)
	local gold = { Color3.fromRGB(255, 225, 60), Color3.fromRGB(245, 150, 10) }
	for i = 3, 1, -1 do -- coin edges, bottom one first
		circle({ Size = UDim2.fromScale(0.62, 0.24), Position = UDim2.fromScale(0.02, 0.12 + i * 0.17), ZIndex = 1, Parent = icon }, gold)
	end
	circle({ Size = UDim2.fromScale(0.62, 0.26), Position = UDim2.fromScale(0.02, 0.06), ZIndex = 1, Parent = icon }, { Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 190, 30) })
	local coin = circle({ Size = UDim2.fromScale(0.64, 0.74), Position = UDim2.fromScale(0.36, 0.26), ZIndex = 2, Parent = icon }, gold)
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.72, 0.72), BackgroundTransparency = 1, ZIndex = 2, Parent = coin }, {
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		new("UIStroke", { Color = Color3.fromRGB(215, 120, 10), Thickness = 2 }),
	})
	local dollar = outlined({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.66), Text = "$", TextColor3 = Color3.fromRGB(255, 220, 50), ZIndex = 3, Parent = coin }, 1.5)
	;(dollar:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = Color3.fromRGB(190, 95, 10)
end

-- A round pink sweet in a twisted wrapper.
local function drawCandy(icon: Frame)
	local wrapper = { Color3.fromRGB(255, 140, 200), Color3.fromRGB(235, 50, 150) }
	for i, x in { 0.17, 0.83 } do -- the two wrapper ends, as squashed diamonds
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.5),
			Size = UDim2.fromScale(0.3, 0.42),
			Rotation = if i == 1 then 45 else -45,
			BackgroundColor3 = WHITE,
			ZIndex = 1,
			Parent = icon,
		}, { new("UICorner", { CornerRadius = UDim.new(0, 4) }), gradient(wrapper), border(3) })
	end
	local ball = circle({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.86), ZIndex = 2, Parent = icon },
		{ Color3.fromRGB(255, 175, 220), Color3.fromRGB(235, 40, 140) })
	new("Frame", { -- shine
		Position = UDim2.fromScale(0.2, 0.14),
		Size = UDim2.fromScale(0.36, 0.22),
		Rotation = -25,
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.25,
		ZIndex = 3,
		Parent = ball,
	}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
end

local currencyStack = new("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Size = UDim2.fromOffset(270, 140),
	Position = UDim2.new(1, -16, 0.5, 0),
	BackgroundTransparency = 1,
	Parent = gui,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 10), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
})
local function currencyRow(order: number, image: string, draw: (Frame) -> (), textPaint: { Color3 })
	local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, LayoutOrder = order, Parent = currencyStack })
	if image ~= "" then
		new("ImageLabel", { Size = UDim2.fromOffset(78, 62), BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit, Parent = holder })
	else
		draw(new("Frame", { Size = UDim2.fromOffset(74, 56), Position = UDim2.fromOffset(2, 3), BackgroundTransparency = 1, Parent = holder }))
	end
	local value = outlined({ Size = UDim2.new(1, -86, 1, -4), Position = UDim2.fromOffset(84, 2), Text = "0", TextXAlignment = Enum.TextXAlignment.Left, Parent = holder }, 4)
	gradient(textPaint).Parent = value -- a UIGradient on a text label colours the letters
	return value
end
local moneyLabel = currencyRow(1, CURRENCY_IMAGES.Money, drawCoins, PAINT.MoneyText)
local candyLabel = currencyRow(2, CURRENCY_IMAGES.Candy, drawCandy, PAINT.CandyText)

-- Friend boost, bottom left: +10% pet Money for each friend in this server.
local friendHud = new("Frame", { AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(270, 34), Position = UDim2.new(0, 16, 1, -16), BackgroundTransparency = 1, Parent = gui })
local friendLabel = outlined({ Size = UDim2.new(1, -44, 1, 0), Text = "Friend Boost +0%", TextXAlignment = Enum.TextXAlignment.Left, Parent = friendHud }, 2.5)
local friendIcon = outlined({ Size = UDim2.fromOffset(34, 34), Position = UDim2.new(1, -38, 0, 0), Text = "✚", TextColor3 = Color3.fromRGB(80, 230, 90), Parent = friendHud }, 2.5)
local function refreshFriendBoost()
	local boost = player:GetAttribute("FriendBoost") or 0
	friendLabel.Text = string.format("Friend Boost +%d%%", boost)
	friendIcon.TextColor3 = if boost > 0 then Color3.fromRGB(80, 230, 90) else Color3.fromRGB(150, 160, 150)
end
player:GetAttributeChangedSignal("FriendBoost"):Connect(refreshFriendBoost)
refreshFriendBoost()

-- Custom speed, under Money and Candy: run slower than your max speed if you want. Type a number or use - / +.
-- The server clamps it between Config.MinCustomSpeed and your max and saves it.
local customSpeedHud = new("Frame", { AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(270, 112), Position = UDim2.new(1, -16, 0.5, 80), BackgroundTransparency = 1, Parent = gui })
outlined({ Size = UDim2.fromOffset(62, 62), Position = UDim2.fromOffset(0, 26), Text = "⚡", TextColor3 = Color3.fromRGB(255, 200, 30), Parent = customSpeedHud }, 3)
outlined({ Size = UDim2.new(1, -66, 0, 30), Position = UDim2.fromOffset(66, 0), Text = "Custom speed", Parent = customSpeedHud }, 3)
local speedBox = new("Frame", {
	Size = UDim2.new(1, -66, 0, 54),
	Position = UDim2.fromOffset(66, 32),
	BackgroundColor3 = Color3.fromRGB(15, 70, 25),
	BackgroundTransparency = 0.3,
	Parent = customSpeedHud,
}, { corner(12), new("UIStroke", { Color = Color3.fromRGB(10, 40, 15), Thickness = 2, Transparency = 0.3 }) })
local speedInput = new("TextBox", {
	Size = UDim2.new(1, -96, 1, -8),
	Position = UDim2.fromOffset(48, 4),
	BackgroundTransparency = 1,
	Font = Enum.Font.FredokaOne,
	TextColor3 = WHITE,
	TextScaled = true,
	ClearTextOnFocus = false,
	Text = "",
	Parent = speedBox,
}, { new("UIStroke", { Color = BLACK, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round }) })
local maxSpeedLabel = outlined({ AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(1, -66, 0, 22), Position = UDim2.new(1, -4, 0, 89), Text = "Max: 0", TextXAlignment = Enum.TextXAlignment.Right, Parent = customSpeedHud }, 2)

local shownSpeed: number? = nil -- what the panel shows; nil until the first data arrives
local sendSpeedAt = 0
local function speedLimits(): (number, number)
	local max = if data then Config.WalkSpeedFor(data.SpeedLevel) else Config.BaseWalkSpeed
	return math.min(Config.MinCustomSpeed, max), max
end
local function showSpeed(speed: number)
	local low, max = speedLimits()
	shownSpeed = math.clamp(math.floor(speed * 2 + 0.5) / 2, low, max)
	speedInput.Text = Config.FormatSpeed(shownSpeed :: number)
	maxSpeedLabel.Text = "Max: " .. Config.FormatSpeed(max)
end
-- Wait a moment after the last change before telling the server, so holding/clicking fast sends one request.
local function pickSpeed(speed: number)
	showSpeed(speed)
	local at = os.clock()
	sendSpeedAt = at
	task.delay(0.35, function()
		if sendSpeedAt == at and shownSpeed then
			Remotes.Request:InvokeServer("SetCustomSpeed", shownSpeed)
		end
	end)
end
for _, step in { -1, 1 } do
	chunkyButton({
		AnchorPoint = Vector2.new(if step < 0 then 0 else 1, 0.5),
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(if step < 0 then 0 else 1, if step < 0 then 6 else -6, 0.5, 0),
		Text = if step < 0 then "-" else "+",
		ZIndex = 2,
		Parent = speedBox,
	}, if step < 0 then PAINT.Red else PAINT.Green, function()
		if shownSpeed then
			pickSpeed(if step > 0 then math.floor(shownSpeed) + 1 else math.ceil(shownSpeed) - 1)
		end
	end)
end
speedInput.FocusLost:Connect(function()
	local typed = tonumber(speedInput.Text)
	if typed and typed == typed then
		pickSpeed(typed)
	elseif shownSpeed then
		showSpeed(shownSpeed)
	end
end)
local function refreshCustomSpeed(d)
	if speedInput:IsFocused() or os.clock() - sendSpeedAt < 1 then
		maxSpeedLabel.Text = "Max: " .. Config.FormatSpeed(Config.WalkSpeedFor(d.SpeedLevel))
		return -- the player is changing it right now
	end
	showSpeed(Config.ChosenSpeed(d))
end

-- Night / day timer, top centre: just outlined text.
local phaseLabel = outlined({ AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(340, 40), Position = UDim2.new(0.5, 0, 0, 10), Text = "", Parent = gui }, 3)

-- Chase / carrying banner. Pulses gently while shown.
local banner = box({ AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(520, 48), Position = UDim2.new(0.5, 0, 0, 62), Visible = false, Parent = gui }, PAINT.Red)
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
local speedShopButton = chunkyButton({ Size = UDim2.fromOffset(46, 46), Position = UDim2.new(1, -46, 0, 34), Text = "+", Parent = levelHud }, PAINT.Orange, function()
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
local TITLES = { Rebirth = "Rebirth", Index = "Pet Index", Pets = "Pets", Eggs = "Eggs", Store = "Store", Treadmills = "Speed Shop" }
local ICONS = {
	Rebirth = "rbxassetid://134156079401542",
	Index = "rbxassetid://120727874564424",
	Pets = "rbxassetid://114367839008367",
	Eggs = "rbxassetid://127453926615025",
	Store = "rbxassetid://82681777153242",
}

-- Stud outlines like a Lego plate. Fills the window with as many whole studs as fit, centred, so none
-- poke past the edges; refills when the window changes size.
local function studs(parent: GuiObject, cell: number, radius: number, color: Color3?, transparency: number?)
	local inset = 6
	local layer = new("CanvasGroup", {
		Name = "Studs",
		Size = UDim2.new(1, -inset * 2, 1, -inset * 2),
		Position = UDim2.fromOffset(inset, inset),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		new("UICorner", { CornerRadius = UDim.new(0, math.max(radius - inset, 0)) }),
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(cell, cell),
			CellPadding = UDim2.new(),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local built = 0
	local function fill()
		-- AbsoluteSize includes the pop-open UIScale; divide it out so the count doesn't change mid-animation.
		local scale = parent:FindFirstChildOfClass("UIScale")
		local size = layer.AbsoluteSize / (if scale and scale.Scale > 0 then scale.Scale else 1)
		local columns = math.floor(size.X / cell)
		local count = columns * math.floor(size.Y / cell)
		if count == built or columns <= 0 then
			return
		end
		built = count
		local layout = layer:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		layout.FillDirectionMaxCells = columns
		for _, child in layer:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for _ = 1, count do
			local slot = new("Frame", { BackgroundTransparency = 1, Parent = layer })
			new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.6),
				BackgroundTransparency = 1, Parent = slot,
			}, {
				new("UICorner", { CornerRadius = UDim.new(0.25, 0) }),
				new("UIStroke", { Color = color or Color3.fromRGB(215, 218, 228), Transparency = transparency or 0, Thickness = 2 }),
			})
		end
	end
	layer:GetPropertyChangedSignal("AbsoluteSize"):Connect(fill)
	fill()
	return layer
end

local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromScale(0.62, 0.76),
	Position = UDim2.fromScale(0.5, 0.5),
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
studs(panel, 28, 22)

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
local invPanel: Frame
local function closeMenus()
	openMenu = nil
	panel.Visible = false
	invPanel.Visible = false
end
bounce(closeButton)
closeButton.Activated:Connect(closeMenus)

local function request(action: string, arg: any?)
	local ok, success, message = pcall(function()
		return Remotes.Request:InvokeServer(action, arg)
	end)
	if not ok then
		toast("Something went wrong, try again.", RED)
		return
	end
	if message and message ~= "" then
		toast(message, if success then GREEN else RED)
	end
end

-- Fast Hatch: every egg on your pads hatches now. Free in the tutorial, otherwise a Robux purchase (the server
-- opens it).
local function fastHatch()
	if data and #data.Incubators == 0 then
		toast("Nothing is hatching. Tap an egg in the Eggs menu first!", ORANGE)
		return
	end
	request("FastHatch")
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

---------------------------------------------------------------------------
-- Inventory window (Pets and Eggs): blue title bar with search and X, dark studded body with card grids,
-- buttons along the bottom.
---------------------------------------------------------------------------
local INVENTORY_MENUS = { Pets = true, Eggs = true }

invPanel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromScale(0.66, 0.78),
	Position = UDim2.fromScale(0.5, 0.5),
	BackgroundColor3 = Color3.fromRGB(45, 28, 80),
	BackgroundTransparency = 0.12,
	Visible = false,
	Parent = gui,
}, {
	corner(14),
	border(4),
	new("UISizeConstraint", { MaxSize = Vector2.new(760, 520), MinSize = Vector2.new(360, 280) }),
})
local invScale = new("UIScale", { Parent = invPanel })
studs(invPanel, 34, 14, WHITE, 0.9)

local invHeader = box({ Size = UDim2.new(1, 0, 0, 66), Parent = invPanel }, PAINT.Header)
local invIcon = new("ImageLabel", { Size = UDim2.fromOffset(72, 72), Position = UDim2.fromOffset(-4, -8), BackgroundTransparency = 1, ZIndex = 3, Parent = invHeader })
local invTitle = outlined({ Size = UDim2.new(0.3, 0, 0, 46), Position = UDim2.fromOffset(78, 10), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3, Parent = invHeader }, 3)
local searchBox = new("TextBox", {
	AnchorPoint = Vector2.new(1, 0.5),
	Size = UDim2.new(0.4, 0, 0, 42),
	Position = UDim2.new(1, -76, 0.5, 0),
	BackgroundColor3 = Color3.fromRGB(20, 45, 90),
	BackgroundTransparency = 0.25,
	Font = Enum.Font.FredokaOne,
	PlaceholderText = "Search...",
	PlaceholderColor3 = Color3.fromRGB(150, 170, 205),
	Text = "",
	TextColor3 = WHITE,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false,
	ZIndex = 3,
	Parent = invHeader,
}, {
	corner(8),
	new("UIStroke", { Color = Color3.fromRGB(10, 25, 55), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 7), PaddingBottom = UDim.new(0, 7) }),
})
chunkyButton({ AnchorPoint = Vector2.new(1, 0.5), Size = UDim2.fromOffset(52, 52), Position = UDim2.new(1, -10, 0.5, 0), Text = "X", ZIndex = 3, Parent = invHeader }, PAINT.Red, closeMenus)

local invList = new("ScrollingFrame", {
	Size = UDim2.new(1, -20, 1, -152),
	Position = UDim2.fromOffset(10, 74),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = Color3.fromRGB(200, 190, 230),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Parent = invPanel,
}, {
	new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }),
})
local invFooter = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.new(1, -20, 0, 58),
	Position = UDim2.new(0.5, 0, 1, -10),
	BackgroundTransparency = 1,
	Parent = invPanel,
}, {
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}),
})

-- "Equipped 3/10" between two faint lines.
local function sectionTitle(order: number, text: string)
	local f = new("Frame", { Size = UDim2.new(1, -8, 0, 34), BackgroundTransparency = 1, LayoutOrder = order, Parent = invList })
	for i, x in { 0, 0.72 } do
		new("Frame", {
			Size = UDim2.new(0.28, -8, 0, 3),
			Position = UDim2.new(x, if i == 1 then 0 else 8, 0.5, -1),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			Parent = f,
		})
	end
	outlined({ Size = UDim2.fromScale(0.44, 0.9), Position = UDim2.fromScale(0.28, 0.05), Text = text, Parent = f }, 2)
end

local function invHint(order: number, text: string)
	local f = new("Frame", { Size = UDim2.new(1, -8, 0, 28), BackgroundTransparency = 1, LayoutOrder = order, Parent = invList })
	outlined({ Size = UDim2.fromScale(1, 0.85), Text = text, TextColor3 = Color3.fromRGB(200, 190, 230), Parent = f }, 1.5)
end

local function cardGrid(order: number)
	return new("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, Parent = invList }, {
		new("UIGridLayout", {
			CellSize = UDim2.fromOffset(104, 112),
			CellPadding = UDim2.fromOffset(10, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
end

-- A model in a little 3D window, framed to fit.
local function modelViewport(model: Model?, parent: Instance, props: { [string]: any })
	props.BackgroundTransparency = 1
	props.Ambient = Color3.fromRGB(170, 170, 170)
	props.LightColor = WHITE
	props.LightDirection = Vector3.new(-1, -1, -1)
	props.Parent = parent
	local viewport = new("ViewportFrame", props)
	if not model then
		return viewport
	end
	model.Parent = viewport
	local center, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = size.Magnitude / 2 / math.tan(math.rad(20)) * 0.9
	local look = model:GetPivot().LookVector
	camera.CFrame = CFrame.lookAt(center.Position + look * distance + Vector3.new(0, size.Y * 0.3, 0), center.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

local petAssets = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Pets")
local function petModel(petId: string): Model?
	local template = petAssets:FindFirstChild((Config.SplitPet(petId))) -- Big or Golden pets use the plain pet's model
	return if template then template:Clone() else nil
end

-- One pet or egg card: a coloured splash, the model, an optional count in the corner and a line of text
-- underneath. Returns the button and the bottom label.
local function card(grid: Instance, order: number, model: Model?, splash: Color3, bottomText: string, countText: string?, selected: boolean, onClick: () -> ())
	local b = new("TextButton", { Text = "", BackgroundTransparency = 1, AutoButtonColor = false, LayoutOrder = order, Parent = grid }, { corner(14) })
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.8, 0.72),
		BackgroundColor3 = splash,
		BackgroundTransparency = 0.35,
		Parent = b,
	}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	modelViewport(model, b, { Size = UDim2.new(1, 0, 1, -20), ZIndex = 2 })
	if countText then
		outlined({ AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(50, 28), Position = UDim2.fromScale(1, 0), Text = countText, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 3, Parent = b }, 2.5)
	end
	local bottom = outlined({ Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 1, -26), Text = bottomText, ZIndex = 3, Parent = b }, 2.5)
	if selected then
		new("UIStroke", { Color = Color3.fromRGB(255, 225, 60), Thickness = 4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b })
	end
	bounce(b)
	b.Activated:Connect(onClick)
	return b, bottom
end

-- Dark blob for a slot with nothing in it ("+4" locked pet slots, "Empty" incubators).
local function blob(grid: Instance, order: number, text: string, onClick: () -> ())
	local b = new("TextButton", { Text = "", BackgroundTransparency = 1, AutoButtonColor = false, LayoutOrder = order, Parent = grid })
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.8, 0.72),
		BackgroundColor3 = BLACK,
		BackgroundTransparency = 0.45,
		Parent = b,
	}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	outlined({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.62, 0.3), Text = text, Parent = b }, 2)
	bounce(b)
	b.Activated:Connect(onClick)
end

local function footerButton(order: number, text: string, paint: { Color3 }, onClick: () -> ())
	chunkyButton({ Size = UDim2.new(0.3, 0, 0, 52), Text = text, LayoutOrder = order, Parent = invFooter }, paint, onClick)
end

local function footerHint(order: number, text: string)
	outlined({ Size = UDim2.new(0.5, 0, 0, 30), Text = text, TextColor3 = Color3.fromRGB(200, 190, 230), LayoutOrder = order, Parent = invFooter }, 1.5)
end

local function matchesSearch(name: string): boolean
	local query = string.lower(searchBox.Text)
	return query == "" or string.find(string.lower(name), query, 1, true) ~= nil
end

local function byIncome(a: string, b: string): boolean
	return Config.Pets[a].MoneyPerSecond > Config.Pets[b].MoneyPerSecond
end

-- Pets: equipped pets (on the base) on top, the inventory below, stacked by kind.
local selectedPet: { Pet: string, Equipped: boolean }? = nil

function menus.Pets(d)
	local slots = Config.PetSlotsFor(d.PetCapLevel)
	local boost = 1 + (player:GetAttribute("FriendBoost") or 0) / 100
	if selectedPet and not table.find(if selectedPet.Equipped then d.Pets else d.Storage, selectedPet.Pet) then
		selectedPet = nil -- sold or moved
	end

	local function petCard(grid: Instance, order: number, petId: string, equipped: boolean, count: number?)
		local pet = Config.Pets[petId]
		local isSelected = selectedPet ~= nil and selectedPet.Pet == petId and selectedPet.Equipped == equipped
		card(grid, order, petModel(petId), Config.Rarities[pet.Rarity].Color, "$" .. formatNumber(pet.MoneyPerSecond * boost) .. "/s",
			if count then "x" .. count else nil, isSelected, function()
				selectedPet = if isSelected then nil else { Pet = petId, Equipped = equipped }
				renderMenu()
			end)
	end

	sectionTitle(1, string.format("Equipped %d/%d", #d.Pets, slots))
	local equippedGrid = cardGrid(2)
	local equipped = table.clone(d.Pets)
	table.sort(equipped, byIncome)
	for n, petId in equipped do
		if matchesSearch(Config.Pets[petId].Name) then
			petCard(equippedGrid, n, petId, true)
		end
	end
	local locked = Config.MaxPetSlots() - slots
	if locked > 0 then
		blob(equippedGrid, 1000, "+" .. locked, function()
			toast("Upgrade your Pet Capacity at the sign by your base entrance for more pet slots!", ORANGE)
		end)
	end

	local counts, kinds = {}, {}
	for _, petId in d.Storage do
		if not counts[petId] then
			counts[petId] = 0
			table.insert(kinds, petId)
		end
		counts[petId] += 1
	end
	table.sort(kinds, byIncome)
	sectionTitle(3, string.format("Inventory %d/%d", #d.Storage, Config.MaxPetsStored))
	if #kinds == 0 then
		invHint(4, if #d.Pets == 0 then "Hatch eggs to get pets!" else "Pets that don't fit on your base wait here.")
	end
	local inventoryGrid = cardGrid(5)
	for n, petId in kinds do
		if matchesSearch(Config.Pets[petId].Name) then
			petCard(inventoryGrid, n, petId, false, counts[petId])
		end
	end

	footerButton(1, "Equip Best", PAINT.Green, function()
		selectedPet = nil
		request("EquipBest")
	end)
	local target = selectedPet
	if target then
		local pet = Config.Pets[target.Pet]
		footerButton(2, if target.Equipped then "Unequip" else "Equip", PAINT.Purple, function()
			selectedPet = nil
			request(if target.Equipped then "UnequipPet" else "EquipPet", target.Pet)
		end)
		footerButton(3, "Sell $" .. formatNumber(pet.MoneyPerSecond * Config.PetSellSeconds), PAINT.Red, function()
			request("SellPet", target)
		end)
	else
		footerHint(2, "Tap a pet to equip, unequip or sell it")
	end
end

-- Eggs: what's hatching (with live countdowns) on top, the egg bag below. Tap an egg to hatch it.
local incubatorTimers: { { Label: TextLabel, EndsAt: number } } = {}

local function refreshIncubatorTimers()
	local now = workspace:GetServerTimeNow()
	for _, timer in incubatorTimers do
		local left = timer.EndsAt - now
		timer.Label.Text = if left > 0 then formatTime(left) else "Hatching!"
	end
end

function menus.Eggs(d)
	local slots = Config.IncubatorsFor(d.PadLevel)
	sectionTitle(1, string.format("Hatching %d/%d", #d.Incubators, slots))
	local hatchGrid = cardGrid(2)
	for n, entry in d.Incubators do
		local egg = Config.Eggs[entry.Egg]
		if egg then
			local _, timer = card(hatchGrid, n, Art.Egg(entry.Egg, entry.Pet), Config.Rarities[egg.Rarity].Color, "", nil, false, function()
				toast(egg.Name .. " is hatching on your base", ORANGE)
			end)
			table.insert(incubatorTimers, { Label = timer, EndsAt = entry.EndsAt })
		end
	end
	refreshIncubatorTimers()
	for n = #d.Incubators + 1, slots do
		blob(hatchGrid, n, "Empty", function()
			toast("Tap an egg below to hatch it!", ORANGE)
		end)
	end

	local counts, kinds = {}, {}
	for _, entry in d.Eggs do
		if not counts[entry] then
			counts[entry] = 0
			table.insert(kinds, entry)
		end
		counts[entry] += 1
	end
	local function rank(entry: string): number
		local egg = Config.Eggs[(Config.ParseEgg(entry))]
		return if egg then Config.Rarities[egg.Rarity].Order else 0
	end
	table.sort(kinds, function(a, b)
		return rank(a) > rank(b)
	end)
	sectionTitle(3, string.format("Egg Bag %d/%d", #d.Eggs, Config.MaxEggsHeld))
	if #kinds == 0 then
		invHint(4, "No eggs yet. Sneak through a window and steal one!")
	end
	local bagGrid = cardGrid(5)
	for n, entry in kinds do
		local eggId, petId = Config.ParseEgg(entry)
		local egg = Config.Eggs[eggId]
		if egg and matchesSearch(egg.Name) then
			card(bagGrid, n, Art.Egg(eggId, petId), Config.Rarities[egg.Rarity].Color, formatTime(egg.HatchSeconds), "x" .. counts[entry], false, function()
				local index = table.find(d.Eggs, entry)
				if index then
					request("Hatch", index)
				end
			end)
		end
	end

	footerButton(1, "Hatch Best", PAINT.Orange, function()
		request("HatchBest")
	end)
	if #d.Incubators > 0 then
		local free = Config.TutorialStepName(d) == "Hatch"
		footerButton(2, if free then "Fast Hatch FREE" else "Fast Hatch R$" .. Config.FastHatchRobux, if free then PAINT.Green else PAINT.Purple, fastHatch)
	else
		footerHint(2, "Tap an egg to hatch it. Hatching is free!")
	end
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	if openMenu and INVENTORY_MENUS[openMenu] then
		renderMenu()
	end
end)

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
	-- Codes: type one and press Redeem (the server checks it and gives the reward once per player).
	header(0, "Codes")
	local codeRow = box({ Size = UDim2.new(1, -8, 0, 60), LayoutOrder = 1, Parent = list }, PAINT.Cyan)
	local codeInput = new("TextBox", {
		Size = UDim2.new(1, -168, 1, -16),
		Position = UDim2.fromOffset(12, 8),
		BackgroundColor3 = Color3.fromRGB(25, 15, 45),
		TextColor3 = WHITE,
		PlaceholderText = "Type a code...",
		PlaceholderColor3 = Color3.fromRGB(160, 160, 195),
		Font = Enum.Font.FredokaOne,
		TextScaled = true,
		ClearTextOnFocus = false,
		Text = "",
		ZIndex = 2,
		Parent = codeRow,
	}, { corner(10), new("UITextSizeConstraint", { MaxTextSize = 26 }), new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }) })
	chunkyButton({ Size = UDim2.new(0, 132, 1, -12), Position = UDim2.new(1, -138, 0, 6), Text = "Redeem", ZIndex = 2, Parent = codeRow }, PAINT.Green, function()
		local code = codeInput.Text
		codeInput.Text = ""
		request("RedeemCode", code)
	end)
	header(2, "Coming soon!")
	for n, item in STORE_ITEMS do
		row(n + 2, string.format("%s (%s)", item.Name, item.Kind), WHITE, "R$ ??", PAINT.Grey, function()
			toast("The Store opens soon!", ORANGE)
		end)
	end
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
		modelViewport(petModel(petId), card, {
			Size = UDim2.new(1, -8, 1, -46),
			Position = UDim2.fromOffset(4, 4),
			ImageColor3 = if known then WHITE else BLACK, -- undiscovered pets are a black silhouette
			ImageTransparency = if known then 0 else 0.15,
			ZIndex = 2,
		})
		outlined({ Size = UDim2.new(1, -8, 0, 20), Position = UDim2.new(0, 4, 1, -42), Text = if known then pet.Name else "???", ZIndex = 2, Parent = card }, 1.5)
		outlined({ Size = UDim2.new(1, -8, 0, 17), Position = UDim2.new(0, 4, 1, -21), Text = if known then pet.Rarity else "", TextColor3 = rarity.Color, ZIndex = 2, Parent = card }, 1.5)
	end
end

-- The Speed Shop has two tabs: Treadmills and Trails (both paid with Money). Every item is a studded card with a
-- little 3D picture of it, its XP multiplier on a badge and a price / equip button underneath.
local shopTab = "Treadmills"
local SHOP_TABS = { { Name = "Treadmills", Paint = PAINT.Orange }, { Name = "Trails", Paint = PAINT.Purple } }
local function tabRow(order: number)
	local frame = spacer(order, 54)
	for i, tab in SHOP_TABS do
		local active = shopTab == tab.Name
		local b = chunkyButton({
			Size = UDim2.new(0.5, -10, 1, if active then -4 else -12),
			Position = UDim2.new((i - 1) * 0.5, (i - 1) * 6 + 4, 0, if active then 2 else 8),
			Text = tab.Name,
			Parent = frame,
		}, if active then tab.Paint else PAINT.Grey, function()
			shopTab = tab.Name
			renderMenu()
		end)
		if active then
			studs(b, 16, 12, WHITE, 0.6)
		end
	end
end

-- Builds a small blocky model for a shop picture. Parts get studded tops like the rest of the game.
local function pictureBuilder(model: Model)
	return function(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, transparency: number?, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.Plastic
		p.Transparency = transparency or 0
		p.TopSurface = Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Inlet
		if shape then
			p.Shape = shape
		end
		p.Parent = model
		return p
	end
end

-- A mini treadmill in the tier's colour, with a little Halloween topper on the better ones.
local function treadmillPicture(info, tier: number): Model
	-- Use the real treadmill model for this tier (Assets.Treadmills.<tier>), seen from the console's front corner.
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Treadmills")
	local real = folder and folder:FindFirstChild(tostring(tier))
	if real and real:IsA("Model") then
		local copy = real:Clone()
		for _, d in copy:GetDescendants() do
			if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("LayerCollector") then
				d:Destroy()
			end
		end
		copy.PrimaryPart = nil -- so the picture angle comes from WorldPivot, not the belt
		copy.WorldPivot = CFrame.new(copy:GetBoundingBox().Position) * CFrame.Angles(0, math.rad(-40), 0)
		copy:SetAttribute("Zoom", 0.8)
		return copy
	end
	-- No model for this tier: draw a simple one instead.
	local m = Instance.new("Model")
	local p = pictureBuilder(m)
	local c = info.Color
	local light = c:Lerp(WHITE, 0.15)
	local ghostly = if tier == 6 then 0.3 else 0
	p(Vector3.new(4, 0.8, 7), CFrame.new(0, 0.4, 0), c:Lerp(BLACK, 0.15), nil, ghostly)
	p(Vector3.new(3.2, 0.2, 6.6), CFrame.new(0, 0.9, 0), Color3.fromRGB(35, 30, 40), Enum.Material.SmoothPlastic)
	for i = -2, 2 do
		p(Vector3.new(3.2, 0.1, 0.35), CFrame.new(0, 1.04, i * 1.3), Color3.fromRGB(75, 70, 85), Enum.Material.SmoothPlastic)
	end
	for _, x in { -1.8, 1.8 } do
		p(Vector3.new(0.5, 3.2, 0.5), CFrame.new(x, 2.4, -3), light, nil, ghostly)
		p(Vector3.new(0.4, 0.4, 2.2), CFrame.new(x, 3.8, -2.1), light, nil, ghostly)
		p(Vector3.new(0.15, 0.3, 7), CFrame.new(x * 1.14, 0.45, 0), light, Enum.Material.Neon)
	end
	p(Vector3.new(4, 0.4, 0.4), CFrame.new(0, 3.9, -3), light, nil, ghostly)
	p(Vector3.new(2.6, 1.1, 0.7), CFrame.new(0, 4.3, -3.2), c:Lerp(BLACK, 0.55))
	p(Vector3.new(2, 0.7, 0.1), CFrame.new(0, 4.35, -3.58), light, Enum.Material.Neon)
	if tier == 4 then -- pumpkin
		p(Vector3.new(1.3, 1.1, 1.3), CFrame.new(0, 5.4, -3.2), Color3.fromRGB(255, 120, 0), nil, nil, Enum.PartType.Ball)
		p(Vector3.new(0.25, 0.5, 0.25), CFrame.new(0, 6.1, -3.2), Color3.fromRGB(90, 160, 50))
	elseif tier == 5 then -- crossed bones
		for _, a in { 35, -35 } do
			p(Vector3.new(1.8, 0.3, 0.3), CFrame.new(0, 5.2, -3.2) * CFrame.Angles(0, 0, math.rad(a)), Color3.fromRGB(240, 235, 215))
		end
	elseif tier >= 6 then -- a tiny ghost, or a skull on the cursed one
		local head = p(Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 5.4, -3.2), if tier == 6 then WHITE else Color3.fromRGB(235, 230, 215), nil, if tier == 6 then 0.15 else 0)
		for _, x in { -0.25, 0.25 } do
			p(Vector3.new(0.25, 0.3, 0.1), CFrame.new(x, 5.5, -3.78), if tier == 6 then BLACK else Color3.fromRGB(170, 60, 255), if tier == 6 then nil else Enum.Material.Neon)
		end
		head.TopSurface = Enum.SurfaceType.Smooth
	end
	m.WorldPivot = CFrame.new(0, 2.2, 0) * CFrame.Angles(0, math.rad(-35), 0)
	return m
end

-- A blocky runner with a glowing streak of the trail's colour behind it.
local function trailPicture(info, index: number): Model
	local m = Instance.new("Model")
	local p = pictureBuilder(m)
	local skin = Color3.fromRGB(225, 225, 235)
	p(Vector3.new(1.6, 1.8, 1), CFrame.new(0, 2.7, 0), skin)
	p(Vector3.new(1.4, 1.4, 1.4), CFrame.new(0, 4.3, 0), skin)
	for _, x in { -0.35, 0.35 } do
		p(Vector3.new(0.25, 0.35, 0.1), CFrame.new(x, 4.4, -0.72), BLACK)
	end
	for i, x in { -0.45, 0.45 } do
		local swing = if i == 1 then 35 else -35
		p(Vector3.new(0.7, 1.7, 0.7), CFrame.new(x, 1.1, 0) * CFrame.Angles(math.rad(swing), 0, 0), skin)
		p(Vector3.new(0.5, 1.5, 0.5), CFrame.new(x * 2.5, 2.8, 0) * CFrame.Angles(math.rad(-swing), 0, 0), skin)
	end
	local c = info.Color
	for i = 1, 7 do
		local s = 1.8 - i * 0.17
		p(Vector3.new(s, s, s), CFrame.new(0, 2.8 + math.sin(i * 0.9) * 0.45, 0.7 + i * 1.05), c:Lerp(BLACK, i * 0.06), Enum.Material.Neon, (i - 1) * 0.09)
	end
	for i = 1, 2 + index do -- sparkles, more on the better trails
		local a = i * 2.4
		p(Vector3.new(0.35, 0.35, 0.35), CFrame.new(math.cos(a) * 1.4, 2.8 + math.sin(a * 1.7) * 1.6, 1.5 + (i % 6) * 1.1), c:Lerp(WHITE, 0.5), Enum.Material.Neon)
	end
	m.WorldPivot = CFrame.new(0, 2.8, 3) * CFrame.Angles(0, math.rad(-60), 0)
	m:SetAttribute("Zoom", 0.82)
	return m
end

local function shopGrid(order: number)
	return new("Frame", { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order, Parent = list }, {
		new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -8, 0, 226),
			CellPadding = UDim2.fromOffset(8, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }),
	})
end

-- One shop item: studded card in the item's colour, name on top, picture window, XP badge and a button.
local function shopCard(grid: Instance, order: number, name: string, color: Color3, model: Model, multiplier: number, buttonText: string, buttonPaint: { Color3 }, dim: boolean, onClick: (() -> ())?)
	local top = if dim then Color3.fromRGB(175, 175, 190) else color:Lerp(WHITE, 0.45)
	local bottom = if dim then Color3.fromRGB(110, 110, 125) else color:Lerp(BLACK, 0.15)
	local card = box({ LayoutOrder = order, Parent = grid }, { top, bottom })
	studs(card, 18, 12, WHITE, 0.72)
	outlined({ Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 6), Text = name, ZIndex = 3, Parent = card }, 2)
	local window = new("Frame", {
		Size = UDim2.new(1, -16, 1, -98),
		Position = UDim2.fromOffset(8, 34),
		BackgroundColor3 = Color3.fromRGB(35, 22, 60),
		BackgroundTransparency = 0.2,
		ZIndex = 2,
		Parent = card,
	}, { corner(10), new("UIStroke", { Color = BLACK, Thickness = 2.5 }) })
	local viewport = modelViewport(model, window, { Size = UDim2.fromScale(1, 1), ZIndex = 3, ImageTransparency = if dim then 0.4 else 0 })
	local camera = viewport.CurrentCamera
	if camera then -- frame the picture tighter than the default
		local center = model:GetBoundingBox().Position
		camera.CFrame = CFrame.lookAt(center + (camera.CFrame.Position - center) * (model:GetAttribute("Zoom") or 0.68), center)
	end
	local badge = box({ AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(84, 30), Position = UDim2.new(1, -2, 1, -58), Rotation = -6, ZIndex = 4, Parent = card }, PAINT.Cyan)
	outlined({ Size = UDim2.new(1, -10, 1, -6), Position = UDim2.fromOffset(5, 3), Text = "x" .. tostring(multiplier) .. " XP", ZIndex = 5, Parent = badge }, 2)
	for _, child in badge:GetChildren() do
		if child:IsA("Frame") then
			child.ZIndex = 4
		end
	end
	chunkyButton({ Size = UDim2.new(1, -16, 0, 44), Position = UDim2.new(0, 8, 1, -52), Text = buttonText, ZIndex = 2, Parent = card }, buttonPaint, onClick or function() end)
	return card
end

function menus.Treadmills(d)
	tabRow(-1)
	if shopTab == "Trails" then
		header(0, "Trails: paid with Money, multiply your Speed XP")
		local grid = shopGrid(1)
		for index, info in Config.Trails do
			local owned = table.find(d.OwnedTrails or {}, index) ~= nil
			local equipped = d.Trail == index
			local buttonText = if equipped then "Equipped" elseif owned then "Equip" else "$" .. formatNumber(info.Price)
			local paint = if equipped then PAINT.Grey elseif owned then PAINT.Orange elseif d.Money >= info.Price then PAINT.Green else PAINT.Red
			shopCard(grid, index, info.Name, info.Color, trailPicture(info, index), info.Multiplier, buttonText, paint, false, function()
				request("BuyTrail", index)
			end)
		end
		return
	end
	header(0, "Treadmills: paid with Money, multiply your costume's XP while you run on them")
	local grid = shopGrid(1)
	for tier, info in Config.Treadmills do
		local picture = treadmillPicture(info, tier)
		if tier <= d.Treadmill then
			shopCard(grid, tier, info.Name, info.Color, picture, info.XpMultiplier, if tier == d.Treadmill then "Owned" else "-", PAINT.Grey, tier < d.Treadmill)
		else
			shopCard(grid, tier, info.Name, info.Color, picture, info.XpMultiplier, "$" .. formatNumber(info.Price), if d.Money >= info.Price then PAINT.Green else PAINT.Red, false, function()
				request("BuyTreadmill", tier)
			end)
		end
	end
end

renderMenu = function()
	if not (openMenu and data) then
		return
	end
	local inventory = INVENTORY_MENUS[openMenu] ~= nil
	local target = if inventory then invList else list
	local scroll = target.CanvasPosition
	for _, container in { list, invList, invFooter } do
		for _, child in container:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end
	table.clear(incubatorTimers)
	local icon = ICONS[openMenu]
	if inventory then
		invIcon.Image = icon or ""
		invTitle.Text = TITLES[openMenu] or openMenu
	else
		panelIcon.Image = icon or ""
		panelIcon.Visible = icon ~= nil
		panelTitle.Position = UDim2.fromOffset(if icon then 58 else 16, -30)
		panelTitle.Text = TITLES[openMenu] or openMenu
	end
	menus[openMenu](data)
	target.CanvasPosition = scroll
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
		table.concat(d.Eggs, ","), table.concat(incubating, ","), table.concat(d.Pets, ","), table.concat(d.Storage or {}, ","),
		player:GetAttribute("FriendBoost") or 0,
		table.concat(d.Discovered or {}, ","), table.concat(d.IndexClaimed or {}, ","), d.PetCapLevel, d.PadLevel,
		d.TutorialStep or 0,
		if openMenu == "Treadmills" then math.floor(d.Money / 1000) else 0,
	}, "|")
end

toggleMenu = function(name: string, forceOpen: boolean?)
	if openMenu == name and not forceOpen then
		closeMenus()
		return
	end
	local inventory = INVENTORY_MENUS[name] ~= nil
	local window = if inventory then invPanel else panel
	local scale = if inventory then invScale else panelScale
	local wasOpen = window.Visible
	if openMenu ~= name then
		selectedPet = nil
	end
	openMenu = name
	searchBox.Text = ""
	;(if inventory then panel else invPanel).Visible = false
	window.Visible = true
	if not wasOpen then
		scale.Scale = 0.85
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	lastMenuKey = ""
	renderMenu()
end

-- Studded menu buttons stacked on the left. They scale with screen height so they fit phones too.
local MENU_ORDER = { "Rebirth", "Index", "Pets", "Eggs", "Store" }
local menuButtons = new("Frame", {
	Name = "MenuButtons",
	AnchorPoint = Vector2.new(0, 0.5),
	Size = UDim2.new(0, 100, 0.66, 0),
	Position = UDim2.new(0, 10, 0.5, 0),
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
-- Tutorial: Scarecrow Jack, a pumpkin-headed scarecrow, hops along next to new players and walks them through
-- Config.TutorialSteps: buy a costume, run and level up, use the base treadmill, knock on House 1, steal an egg
-- (a chase that can't be lost), Fast Hatch it (free once) and buy the second treadmill.
-- The server decides when a step is done (ShopService "Tutorial") and tells us with Remotes.Tutorial; everything
-- here is only drawn for this player: Jack, his dialogue box, the objective card (top centre) with a Skip button,
-- arrows on the ground, a spinning arrow and a glow on the target, an arrow on the screen edge when the target is
-- off screen, a hand pointing at buttons, confetti and the hatch reveal. It all lives in its own function so it
-- does not use up the main chunk's local variables.
---------------------------------------------------------------------------
local updateTutorial: (d: { [string]: any }) -> () = (function()
	local Debris = game:GetService("Debris")
	local GuiService = game:GetService("GuiService")
	local SoundService = game:GetService("SoundService")

	local GOLD = Color3.fromRGB(255, 225, 60)
	local LAVENDER = Color3.fromRGB(205, 190, 240)
	local PUMPKIN = Color3.fromRGB(255, 130, 20)
	local GUIDE_NAME = "Scarecrow Jack"

	-- Built-in Roblox sounds. Swap in your own ids ("rbxassetid://123") to change them; "" turns one off.
	local SOUNDS = {
		Talk = "rbxasset://sounds/electronicpingshort.wav",
		Poof = "rbxasset://sounds/swoosh.wav",
		Step = "rbxasset://sounds/victory.wav",
		Click = "rbxasset://sounds/button.wav",
		Shake = "rbxasset://sounds/clickfast.wav",
	}

	-- What Jack says when a step starts, and when it is done. Knock's line needs the Candy the witch gave.
	local INTRO: { [string]: { string } } = {
		Costume = {
			"Boo! Hehe, did I scare ya? I'm Scarecrow Jack, and this spooky street is my patch.",
			"Around here we trick-or-treat for Candy, steal eggs from creepy houses and hatch them into pets!",
			"But nobody hands out candy to a kid with no costume. Follow the arrows and grab the Bedsheet Ghost!",
		},
		Run = {
			"Next up: SPEED! Running anywhere earns Speed XP. Fill the bar at the bottom to level up.",
			"Race me back to your base! Ready... set... GO!",
		},
		Treadmill = { "See that treadmill in front of your base? Hop on and run! It multiplies the XP your costume gives you." },
		Knock = { "Now the fun part. Go to House 1, the Old Witch's place, knock on her door and shout Trick-or-Treat!" },
		Steal = { "Sneak into House 1, hold F on an egg to grab it, then RUN it back to your base!" },
		Hatch = { "Eggs hatch on your base. Open the Eggs menu and tap your egg to put it on a hatching pad." },
		Treadmill2 = {
			"Your pet earns Money every second, even while you play. Save up for the Wooden Treadmill!",
			"Press the + next to your speed bar to open the Speed Shop. Keep stealing eggs while you wait!",
		},
	}
	local DONE: { [string]: any } = {
		Costume = { "Ooooh, now THAT is spooky! Costumes get you more Candy at every door and help you train faster." },
		Run = { "LEVEL UP! Every level makes you faster for good. Faster legs, fewer catches!" },
		Treadmill = { "Feel the burn! Better treadmills train you even faster. Remember that, it matters later!" },
		Knock = function(candy: number)
			return {
				string.format("That old witch gave you only %d %s??? Well, we'll have to do a Steal/trick to teach her a lesson!", candy, if candy == 1 then "candy" else "candies"),
				"She hides eggs inside her house. Sneak in, grab one and run home. Don't worry, I tied her shoelaces together. She won't catch you this time!",
			}
		end,
		Steal = { "HAHA! You actually did it! Listen to her screech! That's what she gets for being stingy." },
		Hatch = { "Look at that little guy! Pets live on your base and earn you Money every single second." },
		Treadmill2 = {
			"You're a natural, kid! Now hit the scarier houses, steal rarer eggs and become the spookiest thief on the street!",
			string.format("Here's %d Candy for the road. See ya around!", Config.TutorialReward.Candy or 0),
		},
	}
	-- These steps already got their instructions in the previous step's "done" lines.
	local SKIP_INTRO_AFTER_DONE = { Steal = true }
	local HATCH_HINT = "Too slow? Smash that FAST HATCH button. It's on me this time, totally free!"
	local CHASE_LINE = "RUN!!! Back to your base! Don't look back!"

	local step: string? = nil -- the step on screen (nil when there is no tutorial)
	local seen = false -- got the first data yet
	local active = false -- Jack and the tutorial UI exist
	local hatchHinted = false
	local lastEgg: { Egg: string, Pet: string? }? = nil -- the egg on the first pad, for the hatch reveal
	local root: BasePart? = nil

	local function sfx(name: string, volume: number?, pitch: number?)
		local id = SOUNDS[name]
		if not id or id == "" then
			return
		end
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = volume or 0.5
		sound.PlaybackSpeed = pitch or 1
		sound.Parent = SoundService
		sound:Play()
		Debris:AddItem(sound, 8)
	end

	local function isNight(): boolean
		return ReplicatedStorage:GetAttribute("IsNight") == true
	end

	local function nightIn(): string
		local endsAt = ReplicatedStorage:GetAttribute("PhaseEndsAt")
		return if endsAt then formatTime(endsAt - workspace:GetServerTimeNow()) else "soon"
	end

	-------------------------------------------------------------------------
	-- Scarecrow Jack: a wooden pole, a plaid shirt stuffed with straw, a glowing carved pumpkin head, a straw
	-- hat and a crow friend on his arm. Built from parts so it needs no uploaded model. He faces -Z and his
	-- pivot is the bottom of the pole.
	-------------------------------------------------------------------------
	local guide: Model? = nil
	local face: { Mouth: Frame, Eyes: { TextLabel } }? = nil

	local function buildGuide(): Model
		local model = Instance.new("Model")
		model.Name = "ScarecrowJack"
		local function part(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, round: boolean?, className: string?): BasePart
			local p = Instance.new(className or "Part") :: BasePart
			p.Size = size
			p.CFrame = cf
			p.Color = color
			p.Material = material or Enum.Material.SmoothPlastic
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
			p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			if round then
				new("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
			end
			p.Parent = model
			return p
		end
		local C = CFrame.new
		local WOOD = Color3.fromRGB(115, 78, 45)
		local STRAW = Color3.fromRGB(240, 205, 95)
		local SHIRT = Color3.fromRGB(185, 55, 45)
		local PLAID = Color3.fromRGB(95, 25, 30)
		local HAT = Color3.fromRGB(210, 170, 95)

		part(Vector3.new(0.5, 3.6, 0.5), C(0, 1.8, 0), WOOD, Enum.Material.Wood)
		for i = 0, 9 do -- straw sticking out under the shirt
			local a = i / 10 * math.pi * 2
			part(Vector3.new(0.2, 1.1, 0.2), C(math.cos(a) * 0.8, 3.05, math.sin(a) * 0.42) * CFrame.Angles(math.sin(a) * 0.4, 0, -math.cos(a) * 0.4), STRAW)
		end
		part(Vector3.new(2.2, 2.3, 1.2), C(0, 4.45, 0), SHIRT, Enum.Material.Fabric)
		for _, x in { -0.55, 0.55 } do -- plaid
			part(Vector3.new(0.14, 2.32, 1.24), C(x, 4.45, 0), PLAID, Enum.Material.Fabric)
		end
		for _, y in { 4.0, 4.9 } do
			part(Vector3.new(2.24, 0.14, 1.24), C(0, y, 0), PLAID, Enum.Material.Fabric)
		end
		part(Vector3.new(2.3, 0.28, 1.3), C(0, 3.45, 0), Color3.fromRGB(140, 105, 60), Enum.Material.Fabric) -- rope belt
		part(Vector3.new(0.62, 0.62, 0.08), C(0.55, 4.2, -0.63) * CFrame.Angles(0, 0, math.rad(12)), Color3.fromRGB(70, 115, 175), Enum.Material.Fabric) -- patch
		part(Vector3.new(6.2, 0.45, 0.45), C(0, 5.1, 0), WOOD, Enum.Material.Wood) -- arms
		for _, side in { -1, 1 } do
			part(Vector3.new(1.7, 0.95, 0.95), C(side * 1.9, 5.1, 0), SHIRT, Enum.Material.Fabric)
			for k = -1, 1 do -- straw hands
				part(Vector3.new(1, 0.16, 0.16), C(side * 3.1, 5.1 + k * 0.2, k * 0.14) * CFrame.Angles(0, k * 0.45, side * k * 0.35), STRAW)
			end
		end

		-- The pumpkin head: a squashed ball with four ribs, a curly stem hidden under the hat.
		local headY = 6.8
		part(Vector3.new(2.7, 2.3, 2.6), C(0, headY, 0), PUMPKIN, nil, true)
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + math.pi / 4
			part(Vector3.new(1.55, 2.2, 1.55), C(math.cos(a) * 0.62, headY, math.sin(a) * 0.6), PUMPKIN:Lerp(Color3.fromRGB(150, 60, 0), 0.15), nil, true)
		end
		local glow = Instance.new("PointLight")
		glow.Color = Color3.fromRGB(255, 170, 60)
		glow.Brightness = 1.6
		glow.Range = 12
		glow.Parent = part(Vector3.new(0.2, 0.2, 0.2), C(0, headY, -0.6), PUMPKIN)

		-- The carved face glows (it ignores the night lighting).
		local facePart = part(Vector3.new(2.1, 1.9, 0.05), C(0, headY - 0.05, -1.28), PUMPKIN)
		facePart.Transparency = 1
		local surface = new("SurfaceGui", { Face = Enum.NormalId.Front, LightInfluence = 0, PixelsPerStud = 100, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, Parent = facePart })
		local eyes = {}
		for i, x in { 0.1, 0.58 } do
			eyes[i] = new("TextLabel", {
				Size = UDim2.fromScale(0.32, 0.36), Position = UDim2.fromScale(x, 0.08), BackgroundTransparency = 1,
				Font = Enum.Font.GothamBlack, Text = "▲", TextScaled = true, TextColor3 = Color3.fromRGB(255, 235, 110),
				TextStrokeColor3 = Color3.fromRGB(120, 40, 0), TextStrokeTransparency = 0, Parent = surface,
			})
		end
		new("TextLabel", {
			Size = UDim2.fromScale(0.16, 0.18), Position = UDim2.fromScale(0.42, 0.42), BackgroundTransparency = 1,
			Font = Enum.Font.GothamBlack, Text = "▲", TextScaled = true, TextColor3 = Color3.fromRGB(255, 220, 90), Parent = surface,
		})
		local mouth = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromScale(0.74, 0.2), Position = UDim2.fromScale(0.5, 0.64),
			BackgroundColor3 = Color3.fromRGB(255, 235, 110), Parent = surface,
		}, { new("UICorner", { CornerRadius = UDim.new(0.45, 0) }), new("UIStroke", { Color = Color3.fromRGB(120, 40, 0), Thickness = 3 }) })
		for _, x in { 0.3, 0.7 } do -- two pumpkin "teeth" hang into the grin
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(0.13, 0.5), Position = UDim2.fromScale(x, 0.05), Rotation = 45, BackgroundColor3 = PUMPKIN, BorderSizePixel = 0, Parent = mouth })
		end
		face = { Mouth = mouth, Eyes = eyes }

		-- Straw hat, tipped to one side, with a band and straw poking out.
		local hatBase = C(0, headY, 0) * CFrame.Angles(0, 0, math.rad(-9))
		local upright = CFrame.Angles(0, 0, math.pi / 2)
		part(Vector3.new(0.22, 4.4, 4.4), hatBase * C(0, 1.0, 0) * upright, HAT, Enum.Material.Fabric).Shape = Enum.PartType.Cylinder
		part(Vector3.new(1.5, 2.3, 2.3), hatBase * C(0, 1.75, 0) * upright, HAT, Enum.Material.Fabric).Shape = Enum.PartType.Cylinder
		part(Vector3.new(0.32, 2.36, 2.36), hatBase * C(0, 1.25, 0) * upright, Color3.fromRGB(150, 40, 60), Enum.Material.Fabric).Shape = Enum.PartType.Cylinder
		for _, side in { -1, 1 } do
			for k = 0, 2 do
				part(Vector3.new(0.14, 0.75, 0.14), hatBase * C(side * (1.25 + k * 0.12), 0.65, -0.3 + k * 0.3) * CFrame.Angles(0, 0, side * (0.6 + k * 0.15)), STRAW)
			end
		end

		-- His crow, perched on the left arm.
		local crow = Color3.fromRGB(30, 28, 38)
		part(Vector3.new(0.75, 0.7, 1), C(-2.45, 5.75, 0.05), crow, nil, true)
		part(Vector3.new(0.5, 0.5, 0.5), C(-2.45, 6.2, -0.35), crow, nil, true)
		part(Vector3.new(0.18, 0.14, 0.32), C(-2.45, 6.17, -0.68), Color3.fromRGB(255, 190, 40))
		part(Vector3.new(0.6, 0.1, 0.5), C(-2.45, 5.75, 0.6) * CFrame.Angles(math.rad(-25), 0, 0), crow)

		new("Highlight", { FillTransparency = 1, OutlineColor = BLACK, OutlineTransparency = 0.2, DepthMode = Enum.HighlightDepthMode.Occluded, Parent = model })
		model.WorldPivot = CFrame.identity
		return model
	end

	-- A burst of orange and purple sparks.
	local function poof(at: Vector3, count: number?)
		local holder = Instance.new("Part")
		holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.CFrame = CFrame.new(at)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, PUMPKIN), ColorSequenceKeypoint.new(0.5, GOLD), ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 80, 255)) })
		emitter.LightEmission = 0.7
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new(0, 1)
		emitter.Lifetime = NumberRange.new(0.6, 1.1)
		emitter.Speed = NumberRange.new(8, 16)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Drag = 4
		emitter.Rate = 0
		emitter.Parent = holder
		holder.Parent = workspace
		emitter:Emit(count or 40)
		Debris:AddItem(holder, 2)
	end

	-------------------------------------------------------------------------
	-- Screen UI: dialogue box (bottom), objective card (top centre), Fast Hatch button, pointers.
	-------------------------------------------------------------------------
	-- Dialogue box, above the speed bar: Jack's portrait, his name and the typed-out line. Tap it to skip ahead.
	local dialog = new("TextButton", {
		Name = "TutorialDialog",
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(0.9, 0, 0, 122),
		Position = UDim2.new(0.5, 0, 1, -104),
		BackgroundColor3 = Color3.fromRGB(40, 22, 70),
		BackgroundTransparency = 0.06,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	}, {
		corner(18),
		border(4),
		new("UISizeConstraint", { MaxSize = Vector2.new(620, 122) }),
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 160, 200)) }),
	})
	local dialogScale = new("UIScale", { Parent = dialog })

	-- Portrait: a drawn pumpkin with a straw hat, sticking out of the top-left corner. Its mouth moves as he talks.
	local portrait = new("Frame", { Size = UDim2.fromOffset(104, 104), Position = UDim2.fromOffset(-20, -34), BackgroundTransparency = 1, ZIndex = 7, Parent = dialog })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(0.92, 0.8), BackgroundColor3 = WHITE, ZIndex = 7, Parent = portrait }, {
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		gradient({ Color3.fromRGB(255, 175, 60), Color3.fromRGB(230, 95, 10) }),
		border(4),
	})
	for _, x in { 0.36, 0.64 } do -- ribs
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.58), Size = UDim2.fromScale(0.08, 0.66), BackgroundColor3 = Color3.fromRGB(205, 85, 10), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 7, Parent = portrait }, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }) })
	end
	for _, x in { 0.3, 0.7 } do
		outlined({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5), Size = UDim2.fromScale(0.26, 0.24), Text = "▲", TextColor3 = Color3.fromRGB(255, 240, 120), ZIndex = 8, Parent = portrait }, 2.5)
	end
	local portraitMouth = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.76), Size = UDim2.fromScale(0.5, 0.1),
		BackgroundColor3 = Color3.fromRGB(255, 240, 120), ZIndex = 8, Parent = portrait,
	}, { new("UICorner", { CornerRadius = UDim.new(0.5, 0) }), new("UIStroke", { Color = Color3.fromRGB(110, 35, 0), Thickness = 2.5 }) })
	local hatColors = { Color3.fromRGB(235, 200, 120), Color3.fromRGB(180, 135, 60) }
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.22), Size = UDim2.fromScale(1.05, 0.12), Rotation = -8, BackgroundColor3 = WHITE, ZIndex = 9, Parent = portrait }, { corner(6), gradient(hatColors), border(3) })
	new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.53, 0.2), Size = UDim2.fromScale(0.52, 0.24), Rotation = -8, BackgroundColor3 = WHITE, ZIndex = 9, Parent = portrait }, { corner(8), gradient(hatColors), border(3) })

	local nameLabel = outlined({ Size = UDim2.new(1, -130, 0, 28), Position = UDim2.fromOffset(96, 8), Text = GUIDE_NAME, TextColor3 = ORANGE, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6, Parent = dialog }, 2.5)
	nameLabel.TextScaled = false
	nameLabel.TextSize = 24
	local body = new("TextLabel", {
		Size = UDim2.new(1, -116, 1, -46),
		Position = UDim2.fromOffset(96, 38),
		BackgroundTransparency = 1,
		Font = Enum.Font.FredokaOne,
		TextColor3 = WHITE,
		TextSize = 21,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		ZIndex = 6,
		Parent = dialog,
	}, { new("UIStroke", { Color = BLACK, Thickness = 1.8, LineJoinMode = Enum.LineJoinMode.Round }), new("UITextSizeConstraint", { MaxTextSize = 21, MinTextSize = 12 }) })
	body.TextScaled = true
	local nextArrow = outlined({ AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(28, 22), Position = UDim2.new(1, -12, 1, -6), Text = "▼", TextColor3 = GOLD, ZIndex = 6, Visible = false, Parent = dialog }, 2)

	local TOAST_HOME = toastHolder.Position
	local function showDialog(show: boolean)
		if dialog.Visible == show then
			return
		end
		if show then
			dialog.Visible = true
			dialogScale.Scale = 0.7
			TweenService:Create(dialogScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			TweenService:Create(toastHolder, TweenInfo.new(0.25), { Position = TOAST_HOME - UDim2.fromOffset(0, 140) }):Play()
		else
			dialog.Visible = false
			TweenService:Create(toastHolder, TweenInfo.new(0.25), { Position = TOAST_HOME }):Play()
		end
	end

	-- Objective card, top centre under the night timer and chase banner (the player list covers the top right):
	-- step number, what to do, a progress bar and a Skip button.
	local card = box({ AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(360, 112), Position = UDim2.new(0.5, 0, 0, 116), Visible = false, Parent = gui }, { Color3.fromRGB(90, 50, 150), Color3.fromRGB(45, 22, 85) })
	local cardScale = new("UIScale", { Parent = card })
	local stepLabel = outlined({ Size = UDim2.new(1, -110, 0, 22), Position = UDim2.fromOffset(12, 8), Text = "", TextColor3 = ORANGE, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Parent = card }, 2)
	local titleLabel = outlined({ Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 30), Text = "", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Parent = card }, 2.5)
	local detailLabel = outlined({ Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, 62), Text = "", TextColor3 = LAVENDER, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2, Parent = card }, 1.5)
	local cardBar, cardFill = progressBar({ Size = UDim2.new(1, -24, 0, 16), Position = UDim2.fromOffset(12, 88), ZIndex = 2, Parent = card }, PAINT.XpFill)
	for _, d in cardBar:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 3
		end
	end
	local skipArmed = 0
	local skipButton: TextButton
	skipButton = chunkyButton({ AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(92, 30), Position = UDim2.new(1, -8, 0, 6), Text = "Skip", ZIndex = 3, Parent = card }, PAINT.Grey, function()
		-- Tap twice so one stray tap doesn't throw the tutorial away.
		local label = skipButton:FindFirstChildOfClass("TextLabel") :: TextLabel
		if os.clock() - skipArmed > 3 then
			skipArmed = os.clock()
			label.Text = "Sure?"
			task.delay(3, function()
				if os.clock() - skipArmed >= 3 then
					label.Text = "Skip"
				end
			end)
			return
		end
		skipArmed = 0
		label.Text = "Skip"
		request("TutorialSkip")
	end)

	-- Fast Hatch button next to the speed bar, shown while an egg is on a pad. Free in the tutorial's Hatch step.
	local fastButton = chunkyButton({ Size = UDim2.fromOffset(170, 46), Position = UDim2.new(1, 12, 0, 34), Text = "", Visible = false, Parent = levelHud }, PAINT.Purple, fastHatch)
	local fastGradient = fastButton:FindFirstChildOfClass("UIGradient") :: UIGradient
	local fastLabel = fastButton:FindFirstChildOfClass("TextLabel") :: TextLabel
	local function refreshFastButton(d)
		local free = Config.TutorialStepName(d) == "Hatch"
		fastButton.Visible = #d.Incubators > 0
		fastLabel.Text = if free then "⚡ FAST HATCH: FREE" else "⚡ FAST HATCH R$" .. Config.FastHatchRobux
		local paint = if free then PAINT.Green else PAINT.Purple
		fastGradient.Color = ColorSequence.new(paint[1], paint[2])
	end
	task.spawn(function() -- a gentle heartbeat so it gets noticed
		while true do
			local scale = fastButton:FindFirstChildOfClass("UIScale") :: UIScale?
			if fastButton.Visible and scale and scale.Scale == 1 then
				TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), { Scale = 1.08 }):Play()
			end
			task.wait(1.6)
		end
	end)

	-- Hand that points at a button, with a glowing ring around the button.
	local ring = new("Frame", { BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = gui }, {
		new("UICorner", { CornerRadius = UDim.new(0, 16) }),
		new("UIStroke", { Color = GOLD, Thickness = 5 }),
	})
	local ringStroke = ring:FindFirstChildOfClass("UIStroke") :: UIStroke
	local hand = outlined({ Size = UDim2.fromOffset(64, 64), Visible = false, Text = "👆", ZIndex = 21, Parent = gui }, 0)
	local pointAt: GuiObject? = nil

	-- Off-screen arrow on the screen edge, pointing toward the target, with its distance.
	local edge = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(70, 70), BackgroundTransparency = 1, Visible = false, Parent = gui })
	local edgeArrow = outlined({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8), Text = "➤", TextColor3 = GOLD, Parent = edge }, 3)
	local edgeDistance = outlined({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(90, 24), Text = "", Parent = edge }, 2)

	-------------------------------------------------------------------------
	-- World pointers: chevrons on the ground from the player toward the target, a spinning arrow above the
	-- target with its distance, and a glow on the target itself.
	-------------------------------------------------------------------------
	local folder: Folder? = nil
	local chevrons: { { BasePart } } = {}
	local bigArrow: Model? = nil
	local arrowDistance: TextLabel? = nil
	local targetGlow: Highlight? = nil
	local target: { Position: Vector3, Top: number, Instance: Instance? }? = nil
	local CHEVRONS = 8

	local function worldPart(size: Vector3, color: Color3, className: string?): BasePart
		local p = Instance.new(className or "Part") :: BasePart
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.Neon
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Parent = folder
		return p
	end

	local function buildPointers()
		local f = Instance.new("Folder")
		f.Name = "TutorialPointers"
		f.Parent = workspace
		folder = f
		chevrons = {}
		for i = 1, CHEVRONS do
			chevrons[i] = { worldPart(Vector3.new(1, 0.15, 3.2), GOLD), worldPart(Vector3.new(1, 0.15, 3.2), GOLD) }
		end

		-- A fat arrow pointing down: a shaft and a two-wedge head, spinning above the target.
		local arrow = Instance.new("Model")
		arrow.Name = "TargetArrow"
		local W, H, T = 3.4, 2.4, 1
		local head = { worldPart(Vector3.new(T, H, W / 2), GOLD, "WedgePart"), worldPart(Vector3.new(T, H, W / 2), GOLD, "WedgePart") }
		head[1].CFrame = CFrame.new(0, 0, W / 4) * CFrame.Angles(math.pi, 0, 0)
		head[2].CFrame = CFrame.new(0, 0, -W / 4) * CFrame.Angles(0, 0, math.pi)
		local shaft = worldPart(Vector3.new(T, 2.4, 1.4), GOLD)
		shaft.CFrame = CFrame.new(0, H / 2 + 1.2, 0)
		for _, p in { head[1], head[2], shaft } do
			p.Parent = arrow
		end
		arrow.WorldPivot = CFrame.identity -- the arrow's tip is at its pivot... roughly: the head's bottom point
		new("Highlight", { FillTransparency = 1, OutlineColor = BLACK, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = arrow })
		local tag = new("BillboardGui", { Size = UDim2.fromOffset(120, 34), StudsOffset = Vector3.new(0, 5, 0), AlwaysOnTop = true, LightInfluence = 0, Adornee = shaft, Parent = arrow })
		arrowDistance = outlined({ Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = GOLD, Parent = tag }, 2.5)
		arrow.Parent = f
		bigArrow = arrow

		targetGlow = new("Highlight", { FillColor = GOLD, FillTransparency = 0.75, OutlineColor = GOLD, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Enabled = false, Parent = f })
	end

	-- Where things are. The map is fully loaded on the client (no streaming), so these can just look.
	-- House 1 is any Model with Index 1 and an EggSpots folder (like HouseService finds it). Look on the street
	-- first, then everywhere, at most every few seconds.
	local houseOne: Model? = nil
	local houseSearchAt = 0
	local function isHouseOne(d: Instance): boolean
		return d:IsA("Model") and d:GetAttribute("Index") == 1 and d:FindFirstChild("EggSpots") ~= nil
	end
	local function findHouseOne(): Model?
		if houseOne and houseOne.Parent then
			return houseOne
		end
		if os.clock() - houseSearchAt < 3 then
			return nil
		end
		houseSearchAt = os.clock()
		local map = workspace:FindFirstChild("Map")
		local street = map and map:FindFirstChild("Street")
		local houses = street and street:FindFirstChild("Houses")
		for pass = 1, 2 do
			for _, d in if pass == 1 then (if houses then houses:GetChildren() else {}) else workspace:GetDescendants() do
				if isHouseOne(d) then
					houseOne = d :: Model
					return houseOne
				end
			end
		end
		return nil
	end

	local function myPlot(): Instance?
		local map = workspace:FindFirstChild("Map")
		local plots = map and map:FindFirstChild("Plots")
		local name = player:GetAttribute("Plot")
		return plots and name and plots:FindFirstChild(name)
	end

	local function topOf(inst: Instance): (Vector3, number)
		if inst:IsA("Model") then
			local cf, size = inst:GetBoundingBox()
			return cf.Position, cf.Position.Y + size.Y / 2
		elseif inst:IsA("BasePart") then
			return inst.Position, inst.Position.Y + inst.Size.Y / 2
		end
		return Vector3.zero, 0
	end

	local function targetFor(inst: Instance?, glow: boolean?): { Position: Vector3, Top: number, Instance: Instance? }?
		if not inst then
			return nil
		end
		local position, top = topOf(inst)
		return { Position = position, Top = top, Instance = if glow == false then nil else inst }
	end

	local function baseTarget()
		local plot = myPlot()
		local spawnPart = plot and plot:FindFirstChild("PlayerSpawn")
		local t = targetFor(spawnPart, false)
		if t then
			t.Top -= 3
		end
		return t
	end

	-- The thing the current step wants: (world target or nil, button to point at or nil).
	local function resolveTarget(d): ({ Position: Vector3, Top: number, Instance: Instance? }?, GuiObject?)
		if step == "Costume" then
			local pedestal = CollectionService:GetTagged("TutorialCostume")[1]
			return targetFor(pedestal and pedestal.Parent), nil
		elseif step == "Run" then
			return baseTarget(), nil
		elseif step == "Treadmill" then
			local plot = myPlot()
			return targetFor(plot and plot:FindFirstChild("Treadmill")), nil
		elseif step == "Knock" then
			local house = findHouseOne()
			return targetFor(house and house:FindFirstChild("Door")), nil
		elseif step == "Steal" then
			if player:GetAttribute("CarryingEgg") then
				return baseTarget(), nil
			end
			local house = findHouseOne()
			local best, bestDistance = nil, math.huge
			if house and root then
				for _, child in house:GetChildren() do
					if child.Name == "Egg" and child:IsA("Model") then
						local distance = (child:GetPivot().Position - root.Position).Magnitude
						if distance < bestDistance then
							best, bestDistance = child, distance
						end
					end
				end
			end
			return targetFor(best or (house and house:FindFirstChild("Door"))), nil
		elseif step == "Hatch" then
			if #d.Incubators > 0 then
				local plot = myPlot()
				local visuals = plot and plot:FindFirstChild("IncubatorVisuals")
				return targetFor(visuals and visuals:FindFirstChild("IncubatingEgg")), fastButton
			elseif #d.Eggs > 0 then
				local eggsOpen = invPanel.Visible and invTitle.Text == TITLES.Eggs
				return nil, if eggsOpen then nil else menuButtons:FindFirstChild("EggsButton") :: GuiObject?
			end
		elseif step == "Treadmill2" then
			local shopOpen = panel.Visible and panelTitle.Text == TITLES.Treadmills
			if d.Money >= Config.Treadmills[2].Price and not shopOpen then
				return nil, speedShopButton
			end
		end
		return nil, nil
	end

	-- Objective card text for the current step: (title, detail, progress 0-1 or nil).
	local function objective(d): (string, string, number?)
		if step == "Costume" then
			return "Buy a costume", "Press E at the glowing Bedsheet Ghost", nil
		elseif step == "Run" then
			local need = Config.XpToNext(d.SpeedLevel)
			return "Run and level up", string.format("Speed XP %s / %s", formatNumber(d.SpeedXp), formatNumber(need)), d.SpeedXp / need
		elseif step == "Treadmill" then
			local seconds = player:GetAttribute("TutorialTreadmill") or 0
			return "Use your treadmill", string.format("Run on it: %ds / %ds", math.floor(seconds), Config.TutorialTreadmillSeconds), seconds / Config.TutorialTreadmillSeconds
		elseif step == "Knock" then
			if not isNight() then
				return "Knock on House 1", "Houses open at night: " .. nightIn(), nil
			end
			return "Knock on House 1", "Press E at the Old Witch's door", nil
		elseif step == "Steal" then
			if player:GetAttribute("CarryingEgg") then
				return "Get home!", "Run the egg back to your base", nil
			elseif not isNight() then
				return "Steal an egg", "Houses open at night: " .. nightIn(), nil
			end
			return "Steal an egg", "Sneak into House 1 and hold F on an egg", nil
		elseif step == "Hatch" then
			if #d.Incubators > 0 then
				return "Hatch your egg", "Press FAST HATCH. It's free!", nil
			end
			return "Hatch your egg", "Open the Eggs menu and tap your egg", nil
		elseif step == "Treadmill2" then
			local price = Config.Treadmills[2].Price
			if d.Money >= price then
				return "Buy a better treadmill", "Open the Speed Shop and buy the Wooden Treadmill", 1
			end
			return "Buy a better treadmill", string.format("Save up: $%s / $%s", formatNumber(d.Money), formatNumber(price)), d.Money / price
		end
		return "", "", nil
	end

	local function refresh(d)
		refreshFastButton(d)
		if #d.Incubators > 0 then
			lastEgg = { Egg = d.Incubators[1].Egg, Pet = d.Incubators[1].Pet }
		end
		if not (active and step) then
			return
		end
		local index = table.find(Config.TutorialSteps, step) or 1
		stepLabel.Text = string.format("STEP %d / %d", index, #Config.TutorialSteps)
		local title, detail, progress = objective(d)
		titleLabel.Text = title
		detailLabel.Text = detail
		cardBar.Visible = progress ~= nil
		if progress then
			setBar(cardFill, progress, true)
		end
		local t, button = resolveTarget(d)
		target = t
		pointAt = button
		if targetGlow then
			targetGlow.Adornee = if t then t.Instance else nil
			targetGlow.Enabled = t ~= nil and t.Instance ~= nil
		end
	end

	-------------------------------------------------------------------------
	-- Dialogue queue: lines are typed out one at a time; a function in the queue (the hatch reveal) runs in
	-- order with the lines.
	-------------------------------------------------------------------------
	local queue: { any } = {}
	local talking = false
	local typing = false
	local tapped = false
	local interrupt = false
	local onQueueEmpty: (() -> ())? = nil

	dialog.Activated:Connect(function()
		tapped = true
	end)

	local function sayLine(text: string)
		showDialog(true)
		nextArrow.Visible = false
		body.Text = text
		body.MaxVisibleGraphemes = 0
		tapped, typing = false, true
		local length = utf8.len(text) or #text
		for i = 1, length do
			if tapped or interrupt then
				break
			end
			body.MaxVisibleGraphemes = i
			if i % 3 == 1 then
				sfx("Talk", 0.12, 1.5 + math.random() * 0.4)
			end
			task.wait(0.024)
		end
		body.MaxVisibleGraphemes = -1
		typing = false
		tapped = false
		nextArrow.Visible = true
		local readUntil = os.clock() + math.min(2.4 + length * 0.04, 10)
		while os.clock() < readUntil and not tapped and not interrupt do
			task.wait(0.05)
		end
		nextArrow.Visible = false
		if tapped then
			sfx("Click", 0.3)
		end
	end

	local function pump()
		if talking then
			return
		end
		talking = true
		task.spawn(function()
			while #queue > 0 do
				local item = table.remove(queue, 1)
				interrupt = false
				if type(item) == "function" then
					showDialog(false)
					item()
				else
					sayLine(item)
				end
			end
			talking = false
			showDialog(false)
			if onQueueEmpty then
				local callback = onQueueEmpty
				onQueueEmpty = nil
				callback()
			end
		end)
	end

	local function say(lines: { any }?)
		for _, line in lines or {} do
			table.insert(queue, line)
		end
		pump()
	end

	-- Drop whatever he was saying and say this now.
	local function sayNow(lines: { any })
		table.clear(queue)
		interrupt = talking
		say(lines)
	end

	-------------------------------------------------------------------------
	-- Celebrations: confetti, a "STEP COMPLETE!" stamp and sparks around the player.
	-------------------------------------------------------------------------
	local CONFETTI = { GOLD, PUMPKIN, Color3.fromRGB(170, 80, 255), Color3.fromRGB(90, 230, 255), Color3.fromRGB(120, 255, 120), Color3.fromRGB(255, 110, 190) }
	local function confetti(count: number)
		for _ = 1, count do
			local piece = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.3),
				Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22)),
				Rotation = math.random(0, 360),
				BackgroundColor3 = CONFETTI[math.random(#CONFETTI)],
				BorderSizePixel = 0,
				ZIndex = 50,
				Parent = gui,
			}, { new("UIStroke", { Color = BLACK, Thickness = 1.5 }) })
			local angle = math.random() * math.pi * 2
			local burst = UDim2.new(0.5 + math.cos(angle) * (0.1 + math.random() * 0.25), 0, 0.3 + math.sin(angle) * (0.08 + math.random() * 0.2), 0)
			local up = TweenService:Create(piece, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = burst, Rotation = piece.Rotation + math.random(-180, 180) })
			up:Play()
			up.Completed:Connect(function()
				local fall = TweenService:Create(piece, TweenInfo.new(1.4 + math.random(), Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Position = burst + UDim2.new(math.random() * 0.1 - 0.05, 0, 0.75, 0),
					Rotation = piece.Rotation + math.random(-360, 360),
					BackgroundTransparency = 0.6,
				})
				fall:Play()
				fall.Completed:Connect(function()
					piece:Destroy()
				end)
			end)
		end
	end

	local function stamp(text: string, sub: string?)
		local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.26), Size = UDim2.fromOffset(560, 110), BackgroundTransparency = 1, Rotation = -4, ZIndex = 31, Parent = gui })
		local scale = new("UIScale", { Scale = 2.2, Parent = holder })
		local big = outlined({ Size = UDim2.new(1, 0, 0, 70), Text = text, ZIndex = 31, Parent = holder }, 5)
		gradient(PAINT.MoneyText).Parent = big
		local small = if sub then outlined({ Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 74), Text = sub, TextColor3 = WHITE, ZIndex = 31, Parent = holder }, 3) else nil
		TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(1.9, function()
			local fade = TweenInfo.new(0.35)
			TweenService:Create(scale, fade, { Scale = 0.6 }):Play()
			for _, label in { big, small } do
				if label then
					TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
					TweenService:Create(label:FindFirstChildOfClass("UIStroke") :: UIStroke, fade, { Transparency = 1 }):Play()
				end
			end
			task.wait(0.4)
			holder:Destroy()
		end)
	end

	local function celebrate(final: boolean)
		sfx("Step", 0.6)
		confetti(if final then 90 else 45)
		if final then
			stamp("TUTORIAL COMPLETE!", string.format("+%d Candy", Config.TutorialReward.Candy or 0))
		else
			stamp("STEP COMPLETE!")
		end
		if root then
			poof(root.Position, 30)
		end
	end

	-------------------------------------------------------------------------
	-- Hatch reveal: the egg shakes harder and harder, flashes, and the pet pops out spinning.
	-------------------------------------------------------------------------
	local function hatchReveal(eggId: string?, petId: string)
		local pet = Config.Pets[petId]
		if not pet then
			return
		end
		local rarityColor = Config.Rarities[pet.Rarity].Color
		-- Reaches up over the top bar too.
		local overlay = new("TextButton", { Size = UDim2.new(1, 0, 1, 60), Position = UDim2.fromOffset(0, -60), BackgroundColor3 = BLACK, BackgroundTransparency = 1, AutoButtonColor = false, Text = "", ZIndex = 40, Parent = gui })
		TweenService:Create(overlay, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()
		local rays = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(520, 520), BackgroundTransparency = 1, ZIndex = 41, Visible = false, Parent = overlay })
		for i = 1, 12 do
			new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 34, 1, 0), Rotation = i * 15, BackgroundColor3 = rarityColor, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 41, Parent = rays }, {
				new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }),
			})
		end
		local stage = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(320, 320), BackgroundTransparency = 1, ZIndex = 42, Parent = overlay })
		local egg = if eggId then Art.Egg(eggId, petId) else nil
		local view = modelViewport(egg, stage, { Size = UDim2.fromScale(1, 1), ZIndex = 42 })
		local caption = outlined({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.45, 170), Size = UDim2.fromOffset(600, 50), Text = "Hatching...", ZIndex = 43, Parent = overlay }, 3.5)
		local sub = outlined({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.45, 222), Size = UDim2.fromOffset(500, 30), Text = "", TextColor3 = GREEN, ZIndex = 43, Parent = overlay }, 2.5)

		-- Shake, getting wilder.
		local eggPivot = if egg then egg:GetPivot() else nil
		local t0 = os.clock()
		while os.clock() - t0 < 1.8 do
			local a = (os.clock() - t0) / 1.8
			local wobble = math.sin(os.clock() * (25 + a * 30))
			if egg and eggPivot then
				egg:PivotTo(eggPivot * CFrame.Angles(0, 0, math.rad(wobble * (5 + a * 18))))
			end
			stage.Position = UDim2.new(0.5, wobble * a * 6, 0.45, 0)
			if math.random() < 0.12 then
				sfx("Shake", 0.25, 0.8 + a)
			end
			task.wait()
		end
		stage.Position = UDim2.fromScale(0.5, 0.45)

		-- Flash, then the pet.
		local flash = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = 45, Parent = overlay })
		TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		Debris:AddItem(flash, 0.7)
		sfx("Step", 0.6)
		view:Destroy()
		local model = petModel(petId)
		local petView = modelViewport(model, stage, { Size = UDim2.fromScale(1, 1), ZIndex = 42 })
		local stageScale = new("UIScale", { Scale = 0.3, Parent = stage })
		TweenService:Create(stageScale, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		rays.Visible = true
		caption.Text = "You hatched a " .. pet.Name .. "!"
		caption.TextColor3 = rarityColor
		sub.Text = string.format("%s pet  |  earns $%s/s", pet.Rarity, formatNumber(pet.MoneyPerSecond))
		confetti(60)

		local closed = false
		overlay.Activated:Connect(function()
			closed = true
		end)
		local pivot = if model then model:GetPivot() else nil
		local shown = os.clock()
		while not closed and os.clock() - shown < 5 do
			rays.Rotation = (os.clock() * 25) % 360
			if model and pivot then
				model:PivotTo(pivot * CFrame.Angles(0, (os.clock() - shown) * 1.6, 0))
			end
			task.wait()
		end
		local fade = TweenInfo.new(0.3)
		TweenService:Create(overlay, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(stageScale, fade, { Scale = 0 }):Play()
		rays.Visible = false
		caption.Visible = false
		sub.Visible = false
		task.wait(0.3)
		petView:Destroy()
		overlay:Destroy()
	end

	-------------------------------------------------------------------------
	-- Start / stop, and the per-frame animation.
	-------------------------------------------------------------------------
	local render: RBXScriptConnection? = nil
	local guidePos: Vector3? = nil
	local hop = 0
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local function ground(at: Vector3, fallback: number): Vector3
		local hit = workspace:Raycast(at + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), rayParams)
		return if hit then hit.Position else Vector3.new(at.X, fallback, at.Z)
	end

	local function frame(dt: number)
		local character = player.Character
		root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local now = os.clock()
		local ignore: { Instance } = { folder :: Folder }
		if character then
			table.insert(ignore, character)
		end
		rayParams.FilterDescendantsInstances = ignore

		-- Jack hops along beside you on his pole and turns to face you.
		if guide and root then
			local feet = root.Position.Y - 3
			local want = ground((root.CFrame * CFrame.new(4.5, 0, -1.5)).Position, feet)
			if not guidePos or (want - guidePos).Magnitude > 80 then
				if guidePos then
					poof(guidePos + Vector3.new(0, 4, 0), 25)
				end
				guidePos = want
				poof(want + Vector3.new(0, 4, 0), 25)
				sfx("Poof", 0.4)
			end
			local before = guidePos :: Vector3
			local nextPos = before:Lerp(want, 1 - math.exp(-dt * 5))
			guidePos = nextPos
			local speed = (nextPos - before).Magnitude / math.max(dt, 1 / 240)
			hop += dt * (if speed > 1 then 11 else 0)
			local lift = if speed > 1 then math.abs(math.sin(hop)) * math.min(speed / 8, 1.3) else 0
			if typing then
				lift += math.abs(math.sin(now * 14)) * 0.25 -- bounces while he talks
			end
			local look = Vector3.new(root.Position.X, nextPos.Y, root.Position.Z)
			local cf = if (look - nextPos).Magnitude > 0.5 then CFrame.lookAt(nextPos, look) else CFrame.new(nextPos)
			guide:PivotTo(cf * CFrame.new(0, lift, 0) * CFrame.Angles(0, 0, math.sin(now * 1.7) * 0.06))
			if face then
				face.Mouth.Size = UDim2.fromScale(0.74, if typing then 0.14 + math.abs(math.sin(now * 16)) * 0.16 else 0.2)
				local blink = (now % 4) < 0.12
				for _, eye in face.Eyes do
					eye.Size = UDim2.fromScale(0.32, if blink then 0.06 else 0.36)
					eye.Position = UDim2.fromScale(eye.Position.X.Scale, if blink then 0.24 else 0.08)
				end
			end
		end
		portraitMouth.Size = UDim2.fromScale(0.5, if typing then 0.06 + math.abs(math.sin(now * 16)) * 0.12 else 0.1)
		nextArrow.Position = UDim2.new(1, -12, 1, -6 + math.sin(now * 6) * 3)

		-- Ground chevrons from you toward the target, pulsing toward it.
		local t = target
		local distance = if t and root then (Vector3.new(t.Position.X, 0, t.Position.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude else 0
		for i, bars in chevrons do
			local along = 3 + i * 4.5
			local show = t ~= nil and root ~= nil and along < distance - 3
			if show and t and root then
				local flat = Vector3.new(t.Position.X - root.Position.X, 0, t.Position.Z - root.Position.Z).Unit
				local spot = ground(root.Position + flat * along, root.Position.Y - 3)
				local tip = CFrame.lookAt(spot + Vector3.new(0, 0.15, 0), spot + Vector3.new(0, 0.15, 0) + flat) * CFrame.new(0, 0, -1.5)
				local transparency = 0.15 + 0.6 * (0.5 + 0.5 * math.sin(now * 5 - i * 0.8))
				for k, bar in bars do
					bar.CFrame = tip * CFrame.Angles(0, if k == 1 then math.rad(40) else math.rad(-40), 0) * CFrame.new(0, 0, 1.6)
					bar.Transparency = transparency
				end
			else
				for _, bar in bars do
					bar.Transparency = 1
				end
			end
		end

		-- Spinning arrow over the target, and the edge arrow when the target is off screen.
		local camera = workspace.CurrentCamera
		if bigArrow then
			if t then
				local tipAt = Vector3.new(t.Position.X, t.Top + 1.8 + math.abs(math.sin(now * 3)) * 1.2, t.Position.Z)
				bigArrow:PivotTo(CFrame.new(tipAt + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, now * 2.5, 0))
				if arrowDistance then
					arrowDistance.Text = if distance > 12 then math.floor(distance) .. "m" else ""
				end
			else
				bigArrow:PivotTo(CFrame.new(0, -1000, 0))
			end
		end
		if targetGlow and targetGlow.Enabled then
			targetGlow.FillTransparency = 0.6 + 0.3 * math.sin(now * 4)
		end
		local edgeShown = false
		if t and camera then
			local screen, onScreen = camera:WorldToViewportPoint(Vector3.new(t.Position.X, t.Top + 2, t.Position.Z))
			if not onScreen or screen.Z < 0 then
				local size = camera.ViewportSize
				local center = size / 2
				local dir = Vector2.new(screen.X, screen.Y) - center
				if screen.Z < 0 then
					dir = -dir
				end
				if dir.Magnitude > 1 then
					local margin = 80
					local scale = math.min((center.X - margin) / math.max(math.abs(dir.X), 1), (center.Y - margin) / math.max(math.abs(dir.Y), 1))
					local pos = center + dir * scale
					-- The GUI sits under the top bar inset, viewport points don't.
					local inset = GuiService:GetGuiInset()
					edge.Position = UDim2.fromOffset(pos.X - inset.X, pos.Y - inset.Y)
					edgeArrow.Rotation = math.deg(math.atan2(dir.Y, dir.X))
					edgeDistance.Text = math.floor(distance) .. "m"
					edgeShown = true
				end
			end
		end
		edge.Visible = edgeShown

		-- Hand and ring on a button.
		local button = pointAt
		if button and button.Parent and button.Visible and button.AbsoluteSize.X > 0 then
			local p, s = button.AbsolutePosition, button.AbsoluteSize
			ring.Visible = true
			ring.Position = UDim2.fromOffset(p.X - 6, p.Y - 6)
			ring.Size = UDim2.fromOffset(s.X + 12, s.Y + 12)
			ringStroke.Transparency = 0.2 + 0.4 * (0.5 + 0.5 * math.sin(now * 6))
			hand.Visible = true
			local bob = math.abs(math.sin(now * 5)) * 10
			-- Point from wherever there is room: buttons low on the screen get the hand from above.
			if p.Y > gui.AbsoluteSize.Y * 0.6 then
				hand.Text = "👇"
				hand.Position = UDim2.fromOffset(p.X + s.X / 2 - 32, p.Y - 70 - bob)
			else
				hand.Text = "👈"
				hand.Position = UDim2.fromOffset(p.X + s.X + 8 + bob, p.Y + s.Y / 2 - 32)
			end
		else
			ring.Visible = false
			hand.Visible = false
		end
	end

	local function start()
		if active then
			return
		end
		active = true
		buildPointers()
		local model = buildGuide()
		model.Parent = folder
		guide = model
		guidePos = nil
		card.Visible = true
		cardScale.Scale = 0.5
		TweenService:Create(cardScale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		render = RunService.RenderStepped:Connect(frame)
	end

	local function stop()
		if not active then
			return
		end
		active = false
		if render then
			render:Disconnect()
			render = nil
		end
		if guidePos then
			poof(guidePos + Vector3.new(0, 4, 0), 50)
			sfx("Poof", 0.5)
		end
		if folder then
			folder:Destroy()
		end
		folder, guide, face, bigArrow, targetGlow, arrowDistance, target, pointAt = nil, nil, nil, nil, nil, nil, nil, nil
		chevrons = {}
		ring.Visible = false
		hand.Visible = false
		edge.Visible = false
		local fade = TweenService:Create(cardScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
		fade:Play()
		fade.Completed:Connect(function()
			if not active then
				card.Visible = false
			end
		end)
	end

	-- Pop the objective card when a new step starts.
	local function bumpCard()
		cardScale.Scale = 0.8
		TweenService:Create(cardScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	-------------------------------------------------------------------------
	-- Events from the server.
	-------------------------------------------------------------------------
	Remotes.Tutorial.OnClientEvent:Connect(function(kind: string, stepName: string?, extra: any)
		if kind == "StepDone" and stepName then
			local final = stepName == Config.TutorialSteps[#Config.TutorialSteps]
			if stepName == "Hatch" and type(extra) == "string" then
				local egg = lastEgg
				table.insert(queue, function()
					hatchReveal(egg and egg.Egg, extra)
					celebrate(false)
				end)
			else
				celebrate(final)
			end
			local lines = DONE[stepName]
			if type(lines) == "function" then
				lines = lines(tonumber(extra) or 0)
			end
			say(lines)
		elseif kind == "Skipped" then
			sayNow({ "Alright, alright, you already know your stuff! See ya around, kid!" })
		end
	end)

	Remotes.ChaseState.OnClientEvent:Connect(function(isChased: boolean)
		if isChased and step == "Steal" then
			sayNow({ CHASE_LINE })
		end
	end)

	-- Refresh the card and pointers a few times a second (night timer, treadmill seconds, nearest egg, etc.).
	task.spawn(function()
		while true do
			task.wait(0.25)
			if active and data then
				refresh(data)
			end
		end
	end)

	return function(d)
		local name = Config.TutorialStepName(d)
		if not seen then
			seen = true
			step = name
			if name then
				start()
				if name == "Costume" and #d.OwnedCostumes <= 1 then
					say(INTRO.Costume)
				else
					say({ "Hey, welcome back! Let's pick up where we left off." })
					say(INTRO[name])
				end
			end
			refresh(d)
			return
		end
		if name ~= step then
			local previous = step
			step = name
			if name then
				start()
				bumpCard()
				if not (previous and SKIP_INTRO_AFTER_DONE[name]) then
					say(INTRO[name])
				end
			else
				-- Finished or skipped: Jack says goodbye, then vanishes in a puff.
				onQueueEmpty = stop
				pump()
			end
		end
		if name == "Hatch" and #d.Incubators > 0 and not hatchHinted then
			hatchHinted = true
			say({ HATCH_HINT })
		end
		refresh(d)
	end
end)()

---------------------------------------------------------------------------
-- Server events
---------------------------------------------------------------------------
local function refreshStats(d)
	candyLabel.Text = formatNumber(d.Candy)
	moneyLabel.Text = formatNumber(d.Money)
	speedLabel.Text = "Speed: " .. Config.FormatSpeed(Config.ChosenSpeed(d))
	refreshCustomSpeed(d)
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
	updateTutorial(newData)
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
-- Treadmill: step onto your own belt and you are held in the middle, running in place while the belt scrolls.
-- Press a move key or jump to step off; leave the belt and walk back on to start again.
---------------------------------------------------------------------------
local locked = false -- held on the belt, running
local armed = false -- move keys let go since locking, so the next press steps off
local released = false -- stepped off; stays free until leaving the belt
local runTrack: AnimationTrack? = nil
local runTrackOwner: Humanoid? = nil
local beltScroll: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any
local jumpRequested = false
game:GetService("UserInputService").JumpRequest:Connect(function()
	jumpRequested = true
end)

local function playRun(character: Model, humanoid: Humanoid)
	if runTrackOwner ~= humanoid then
		runTrackOwner = humanoid
		runTrack = nil
		local animate = character:FindFirstChild("Animate")
		local run = animate and animate:FindFirstChild("run")
		local anim = run and run:FindFirstChildOfClass("Animation")
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if anim and animator then
			runTrack = animator:LoadAnimation(anim)
			runTrack.Priority = Enum.AnimationPriority.Action
			runTrack.Looped = true
		end
	end
	if runTrack and not runTrack.IsPlaying then
		runTrack:Play(0.2)
	end
end

local function unlock()
	locked = false
	Remotes.TreadmillRunning:FireServer(false)
	if runTrack then
		runTrack:Stop(0.2)
	end
end

-- Scroll the slats of every belt someone is running on (the server marks those treadmills "Running";
-- our own belt follows our local state so it stops the instant we step off).
local function scrollBelts(plots: Instance, dt: number)
	for _, plot in plots:GetChildren() do
		local treadmill = plot:FindFirstChild("Treadmill")
		local belt = treadmill and treadmill:FindFirstChild("Belt") :: BasePart?
		local slats = treadmill and treadmill:FindFirstChild("Slats")
		if belt and slats then
			local active = if plot.Name == player:GetAttribute("Plot") then locked else treadmill:GetAttribute("Running") == true
			if active then
				local len = belt.Size.Z
				local list = slats:GetChildren()
				local gap = len / #list
				local off = ((beltScroll[belt] or 0) + dt * Config.TreadmillBeltSpeed * 1.4) % len
				beltScroll[belt] = off
				for i, s in list do
					(s :: BasePart).CFrame = belt.CFrame * CFrame.new(0, belt.Size.Y / 2 + 0.03, -len / 2 + ((i - 0.5) * gap + off) % len)
				end
			end
		end
	end
end

RunService:BindToRenderStep("TreadmillAutoRun", Enum.RenderPriority.Character.Value + 1, function(dt)
	local map = workspace:FindFirstChild("Map")
	local plots = map and map:FindFirstChild("Plots")
	if plots then
		scrollBelts(plots, dt)
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plotName = player:GetAttribute("Plot")
	local plot = plots and plotName and plots:FindFirstChild(plotName)
	local treadmill = plot and plot:FindFirstChild("Treadmill")
	local belt = treadmill and treadmill:FindFirstChild("Belt") :: BasePart?
	local jumped = jumpRequested
	jumpRequested = false
	if not (character and humanoid and root and belt) or humanoid.Health <= 0 then
		if locked then
			unlock()
		end
		return
	end
	local offset = belt.CFrame:PointToObjectSpace(root.Position)
	local overBelt = math.abs(offset.X) <= belt.Size.X / 2 + 0.5 and math.abs(offset.Z) <= belt.Size.Z / 2 + 0.5
	if not overBelt then
		released = false -- stepping off the treadmill re-arms it
	end
	if not overBelt or offset.Y <= 0 or offset.Y >= 6 or player:GetAttribute("CarryingEgg") then
		if locked then
			unlock()
		end
		return
	end
	if released then
		return
	end
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	if locked and (jumped or (armed and moving)) then
		unlock()
		released = true
		return
	end
	if not locked then
		locked = true
		armed = false
		Remotes.TreadmillRunning:FireServer(true)
		playRun(character, humanoid)
	end
	if not moving then
		armed = true
	end
	-- Hold the runner in the middle of the belt, facing the console.
	humanoid:Move(Vector3.zero, false)
	local target = belt.CFrame * CFrame.new(0, belt.Size.Y / 2 + humanoid.HipHeight + root.Size.Y / 2, 0)
	if (root.Position - target.Position).Magnitude > 0.2 or root.CFrame.LookVector:Dot(target.LookVector) < 0.99 then
		root.CFrame = target
	end
	root.AssemblyLinearVelocity = Vector3.zero
	if runTrack then
		runTrack:AdjustSpeed(math.clamp(humanoid.WalkSpeed / 16, 1, 2.5))
	end
end)

-- Night/day timer, and the live countdowns in the Eggs menu.
task.spawn(function()
	while true do
		local isNight = ReplicatedStorage:GetAttribute("IsNight")
		local endsAt = ReplicatedStorage:GetAttribute("PhaseEndsAt")
		if endsAt then
			local left = endsAt - workspace:GetServerTimeNow()
			phaseLabel.Text = if isNight then "🌙 NIGHT " .. formatTime(left) else "☀️ DAY " .. formatTime(left) .. " - street closed"
		end
		if openMenu == "Eggs" then
			refreshIncubatorTimers()
		end
		task.wait(0.25)
	end
end)
