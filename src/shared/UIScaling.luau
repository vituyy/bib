-- Responsive UI scaling. Every screen layer is a Frame inside a ScreenGui, sized 1/scale and drawn with a UIScale, so the
-- fixed-pixel layouts keep their proportions on phones, tablets, laptops, big monitors and TVs.
-- UIScaling.Scale   how much the layouts are enlarged / shrunk on this screen
-- UIScaling.Size    the screen in layout units (pixels / Scale); this is what to position against
-- UIScaling.Compact true on phones and other short screens, where the HUD uses a tighter arrangement
-- UIScaling.Changed fires (scale, size) when any of those change (window resize, rotation)

local GuiService = game:GetService("GuiService")

local COMPACT_BELOW = 580 -- layout height under which the screen counts as compact

local UIScaling = {
	Scale = 1,
	Size = Vector2.new(1280, 780),
	Compact = false,
}

local changed = Instance.new("BindableEvent")
UIScaling.Changed = changed.Event

-- Layout height shrinks from 780 on a desktop window down to 480 on a phone, so phones get a bigger UI than a plain
-- height ratio would give (still readable and tappable), and big monitors grow with the screen. The width keeps at least
-- 900 layout units across so the HUD columns never collide.
local function scaleFor(size: Vector2): number
	local height = math.clamp(480 + (size.Y - 340) * (300 / 340), 480, 780)
	local scale = math.min(size.Y / height, size.X / 900)
	if GuiService:IsTenFootInterface() then
		scale *= 1.25 -- sitting far from a TV
	end
	return math.clamp(scale, 0.5, 2.5)
end

-- Returns the frame to build the layer's UI in. Pass shared = true for the main HUD layers so they publish Scale / Size.
function UIScaling.attach(gui: ScreenGui, shared: boolean?): Frame
	local root = Instance.new("Frame")
	root.Name = "Scaled"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = root

	local function update()
		local size = gui.AbsoluteSize
		if size.X < 2 or size.Y < 2 then
			local camera = workspace.CurrentCamera
			size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		end
		local scale = scaleFor(size)
		uiScale.Scale = scale
		root.Size = UDim2.fromScale(1 / scale, 1 / scale)
		if shared then
			local logical = size / scale
			if scale ~= UIScaling.Scale or logical ~= UIScaling.Size then
				UIScaling.Scale = scale
				UIScaling.Size = logical
				UIScaling.Compact = logical.Y < COMPACT_BELOW
				changed:Fire(scale, logical)
			end
		end
	end

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
	root.Parent = gui
	update()
	return root
end

return UIScaling
