-- Client: HUD (Candy and Money on the right, night/day timer, chase banner, messages, speed level bar at the bottom,
-- friend boost in the bottom left), the studded menu buttons on the left (Rebirth, Index, Pet, Egg, Store) and their
-- panels, and the Speed Shop menu.
-- Look: chunky cartoon UI. White studded panels with thick black outlines, cyan boxes, glossy gradient buttons
-- and white text with a black outline. Pets and Eggs use a darker inventory window with a blue title bar.

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
	local slots = Config.PetSlotsFor(d.BaseLevel)
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
	local locked = Config.PetSlotsFor(#Config.BaseUpgrades) - slots
	if locked > 0 then
		blob(equippedGrid, 1000, "+" .. locked, function()
			toast("Upgrade your base for more pet slots!", ORANGE)
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
	local slots = Config.IncubatorsFor(d.BaseLevel)
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
	footerHint(2, "Tap an egg to hatch it. Hatching is free!")
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
		table.concat(d.Discovered or {}, ","), table.concat(d.IndexClaimed or {}, ","), d.BaseLevel,
		if openMenu == "Treadmills" then math.floor(if shopTab == "Trails" then d.Money / 1000 else d.Candy) else 0,
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
-- Server events
---------------------------------------------------------------------------
local function refreshStats(d)
	candyLabel.Text = formatNumber(d.Candy)
	moneyLabel.Text = formatNumber(d.Money)
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
