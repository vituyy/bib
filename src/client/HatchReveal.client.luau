-- A short client-only reveal of the server-confirmed pet. Inventory rewards are owned by the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Config = require(ReplicatedStorage.Shared.Config)
local Art = require(ReplicatedStorage.Shared.Art)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIScaling = require(ReplicatedStorage.Shared.UIScaling)
local player = Players.LocalPlayer

-- Only show the owner's hatch prompts. The server independently checks ownership and distance.
local function filterPrompt(inst)
	if inst:IsA("ProximityPrompt") and inst.Name == "ManualHatch" and inst:GetAttribute("OwnerUserId") ~= player.UserId then
		inst.Enabled = false
		inst:GetPropertyChangedSignal("Enabled"):Connect(function()
			if inst.Enabled then inst.Enabled = false end
		end)
	end
end
workspace.DescendantAdded:Connect(filterPrompt)
for _, inst in workspace:GetDescendants() do filterPrompt(inst) end
ProximityPromptService.PromptShown:Connect(filterPrompt)

local function make(className, props, parent)
	local o = Instance.new(className)
	for key, value in props do o[key] = value end
	o.Parent = parent
	return o
end
local function tween(o, seconds, props, style, direction)
	local t = TweenService:Create(o, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local activeCleanup
local function reveal(payload)
	local pet = Config.Pets[payload.Pet]
	local rarity = pet and Config.Rarities[pet.Rarity]
	if not (pet and rarity and Config.Eggs[payload.Egg]) then return end
	if activeCleanup then activeCleanup() end
	local gui = make("ScreenGui", { Name = "HatchReveal", ResetOnSpawn = true, IgnoreGuiInset = true, DisplayOrder = 60 }, player.PlayerGui)
	local card = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(320, 338), BackgroundColor3 = Color3.fromRGB(35, 18, 57),
		BackgroundTransparency = 0.06, BorderSizePixel = 0,
	}, UIScaling.attach(gui)) -- the card is built in layout units; UIScaling fits them to the screen
	make("UICorner", { CornerRadius = UDim.new(0, 18) }, card)
	make("UIStroke", { Color = rarity.Color, Thickness = 3 }, card)
	local uiScale = make("UIScale", { Scale = 0.75 }, card)
	local function text(y, height, value, color)
		return make("TextLabel", { Position = UDim2.new(0, 12, 0, y), Size = UDim2.new(1, -24, 0, height),
			BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextScaled = true,
			TextColor3 = color, TextStrokeTransparency = 0.25, Text = value }, card)
	end
	local title = text(12, 31, "Hatching...", Color3.fromRGB(255, 235, 172))
	local petName = text(256, 34, "", Color3.new(1, 1, 1))
	local detail = text(292, 24, "", rarity.Color)
	local viewport = make("ViewportFrame", { Position = UDim2.fromOffset(14, 48), Size = UDim2.new(1, -28, 0, 203),
		BackgroundTransparency = 1, Ambient = Color3.fromRGB(205, 205, 220), LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1) }, card)
	local world = make("WorldModel", {}, viewport)
	local camera = make("Camera", { FieldOfView = 38 }, viewport)
	viewport.CurrentCamera = camera
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 1.5, -9), Vector3.new(0, 0, 0))
	local egg = Art.Egg(payload.Egg, payload.Pet)
	local _, bounds = egg:GetBoundingBox()
	egg:ScaleTo(egg:GetScale() * 3.3 / math.max(bounds.X, bounds.Y, bounds.Z))
	-- Bounding-box centre, rather than variant metadata, keeps every egg centred.
	local cf = egg:GetBoundingBox()
	local offset = egg:GetPivot():ToObjectSpace(cf).Position
	egg:PivotTo(CFrame.new(-offset))
	egg.Parent = world
	local petModel
	local revealStarted
	local initialScale
	local alive = true
	local connection
	local function cleanup()
		if not alive then return end
		alive = false
		if connection then connection:Disconnect() end
		gui:Destroy()
		if activeCleanup == cleanup then activeCleanup = nil end
	end
	activeCleanup = cleanup
	gui.Destroying:Connect(cleanup)
	tween(uiScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	local began = os.clock()
	connection = RunService.RenderStepped:Connect(function()
		if not alive then return end
		local elapsed = os.clock() - began
		if egg and egg.Parent then
			local wiggle = math.sin(elapsed * (22 + elapsed * 24)) * math.rad(5 + elapsed * 9)
			egg:PivotTo(CFrame.new(0, math.abs(math.sin(elapsed * 14)) * 0.12, 0) * CFrame.Angles(0, 0, wiggle) * CFrame.new(-offset))
		elseif petModel and petModel.Parent then
			local p = math.clamp((os.clock() - revealStarted) / 0.45, 0, 1)
			local scale = if p < 0.65 then 0.12 + 1.03 * math.sin(p / 0.65 * math.pi / 2) else 1 + 0.15 * math.cos((p - 0.65) / 0.35 * math.pi / 2)
			petModel:ScaleTo(initialScale * scale)
			petModel:PivotTo(CFrame.new(0, math.sin(elapsed * 3) * 0.08, 0) * CFrame.Angles(0, math.sin(elapsed * 2) * 0.15, 0))
		end
	end)
	task.wait(0.85)
	if not alive then return end
	egg:Destroy()
	egg = nil
	petModel = Art.Clone("Pets", payload.Pet, 3.6)
	if not petModel then
		petModel = Instance.new("Model")
		local body = make("Part", { Name = "Body", Size = Vector3.new(2.5, 2.5, 2.5), Anchored = true,
			CanCollide = false, Color = pet.Color, TopSurface = Enum.SurfaceType.Studs, BottomSurface = Enum.SurfaceType.Inlet }, petModel)
		petModel.PrimaryPart = body
	end
	Art.MaterialLook(petModel, petModel.PrimaryPart, pet.Material)
	initialScale = petModel:GetScale()
	petModel:ScaleTo(initialScale * 0.12)
	petModel:PivotTo(CFrame.new())
	petModel.Parent = world
	revealStarted = os.clock()
	title.Text = rarity.Order >= 5 and "WOW! NEW PET!" or "You hatched!"
	title.TextColor3 = rarity.Color
	petName.Text = pet.Name
	detail.Text = pet.Rarity .. (if payload.ToBase then " • On your base" else " • In your inventory")
	tween(uiScale, 0.12, { Scale = 1.06 })
	task.wait(0.12)
	if not alive then return end
	tween(uiScale, 0.25, { Scale = 1 })
	task.wait(1.8)
	if not alive then return end
	tween(uiScale, 0.22, { Scale = 0.75 })
	tween(card, 0.22, { BackgroundTransparency = 1 })
	task.wait(0.22)
	cleanup()
end

Remotes.EggHatched.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or type(payload.Pet) ~= "string" or type(payload.Egg) ~= "string" then return end
	task.spawn(function()
		local ok, err = pcall(reveal, payload)
		if not ok then
			if activeCleanup then activeCleanup() end
			warn("[HatchReveal]", err)
		end
	end)
end)
player.CharacterRemoving:Connect(function()
	if activeCleanup then activeCleanup() end
end)
