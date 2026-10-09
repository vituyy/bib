-- Client-only presentation for a server-confirmed delivery. Never changes inventory.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")

local EggDeliveryFX = {}
local ICON = "rbxassetid://133588379059427"
local FLIGHT_TIME, LAND_TIME = 0.92, 0.42

local function make(class, props, parent)
	local instance = Instance.new(class)
	for key, value in props do instance[key] = value end
	instance.Parent = parent
	return instance
end

function EggDeliveryFX.Attach(button: ImageButton, remote: RemoteEvent, playSound)
	local player = Players.LocalPlayer
	local layer = make("ScreenGui", {
		Name = "EggDeliveryFX", ResetOnSpawn = false, DisplayOrder = 35,
		IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None,
		ClipToDeviceSafeArea = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local root = make("Frame", {
		Name = "FlightLayer", Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Active = false,
	}, layer)
	local preload = make("ImageLabel", {
		Image = ICON, BackgroundTransparency = 1, Visible = false,
	}, root)
	task.spawn(function()
		pcall(function() ContentProvider:PreloadAsync({ preload }) end)
	end)
	local controller = { Connections = {}, Flights = {}, Destroyed = false, WiggleOwner = nil }
	local restingRotation = button.Rotation

	local function remove(flight)
		if flight.Connection then flight.Connection:Disconnect() end
		if controller.WiggleOwner == flight then
			controller.WiggleOwner = nil
			if button.Parent then button.Rotation = restingRotation end
		end
		flight.Holder:Destroy()
		local index = table.find(controller.Flights, flight)
		if index then table.remove(controller.Flights, index) end
	end

	function controller:Cancel()
		while #self.Flights > 0 do remove(self.Flights[1]) end
	end

	function controller:Destroy()
		if self.Destroyed then return end
		self.Destroyed = true
		self:Cancel()
		for _, connection in self.Connections do connection:Disconnect() end
		layer:Destroy()
	end

	function controller:Play(worldPosition: Vector3)
		local camera = workspace.CurrentCamera
		if self.Destroyed or not camera or not button.Parent or not button.Visible then return end
		if typeof(worldPosition) ~= "Vector3" then return end
		if #self.Flights >= 3 then remove(self.Flights[1]) end
		local viewport = camera.ViewportSize
		if viewport.X <= 0 or viewport.Y <= 0 then return end
		local projected, onScreen = camera:WorldToViewportPoint(worldPosition)
		local start = Vector2.new(projected.X, projected.Y)
		if not onScreen or projected.Z <= 0 then
			-- In first person the hand may be outside the camera; keep the effect visible.
			start = Vector2.new(viewport.X * 0.5, viewport.Y * 0.65)
		end
		local size = math.clamp(math.min(viewport.X, viewport.Y) * 0.16, 64, 108)
		start = Vector2.new(math.clamp(start.X, size / 2, viewport.X - size / 2), math.clamp(start.Y, size / 2, viewport.Y - size / 2))
		local normalizedStart = start / viewport
		local holder = make("Frame", { Name = "Delivery", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false }, root)
		local icon = make("ImageLabel", {
			Name = "FlyingEgg", Image = ICON, BackgroundTransparency = 1,
			AnchorPoint = Vector2.one * 0.5, ScaleType = Enum.ScaleType.Fit, ZIndex = 3,
			Position = UDim2.fromOffset(start.X, start.Y), Size = UDim2.fromOffset(size * 0.72, size * 0.72),
		}, holder)
		local ring = make("Frame", {
			Name = "ArrivalPulse", BackgroundTransparency = 1, AnchorPoint = Vector2.one * 0.5, Visible = false,
		}, holder)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
		local rim = make("UIStroke", { Color = Color3.fromRGB(255, 225, 116), Thickness = 3, Transparency = 0.12 }, ring)
		local sparks = {}
		for i = 1, 4 do
			sparks[i] = make("Frame", {
				Name = "Sparkle", BackgroundColor3 = Color3.fromRGB(255, 242, 172), BorderSizePixel = 0,
				AnchorPoint = Vector2.one * 0.5, Size = UDim2.fromOffset(6, 6), Rotation = 45, Visible = false,
			}, holder)
		end
		local flight = { Holder = holder, Arrived = false }
		table.insert(self.Flights, flight)
		local began = os.clock()
		playSound("Whoosh", 1.08)
		flight.Connection = RunService.RenderStepped:Connect(function()
			local currentCamera = workspace.CurrentCamera
			if self.Destroyed or not button.Parent or not layer.Parent or not currentCamera then remove(flight); return end
			local elapsed = os.clock() - began
			local view = currentCamera.ViewportSize
			-- GUI absolute positions share an inset origin; convert into this full-screen layer.
			local target = button.AbsolutePosition + button.AbsoluteSize / 2 - root.AbsolutePosition
			local inset = GuiService:GetGuiInset()
			local origin = normalizedStart * view - (root.AbsolutePosition + inset)
			local a = math.clamp((elapsed - 0.12) / (FLIGHT_TIME - 0.12), 0, 1)
			if elapsed < FLIGHT_TIME then
				local eased = a * a * (3 - 2 * a)
				local distance = (origin - target).Magnitude
				local height = math.min(distance * 0.3, view.Y * 0.22)
				local point = origin:Lerp(target, eased) - Vector2.new(0, math.sin(eased * math.pi) * height)
				local currentSize = size * (1 - eased * 0.62)
				if elapsed < 0.12 then currentSize = size * (0.72 + 0.28 * math.sin(elapsed / 0.12 * math.pi / 2)) end
				icon.Position = UDim2.fromOffset(point.X, point.Y)
				icon.Size = UDim2.fromOffset(currentSize, currentSize)
				icon.Rotation = math.sin(a * math.pi) * -16
				return
			end
			if not flight.Arrived then
				flight.Arrived = true
				self.WiggleOwner = flight
				icon.Visible = false
				ring.Visible = true
				for _, spark in sparks do spark.Visible = true end
				playSound("Escape", 1.12)
			end
			local b = math.clamp((elapsed - FLIGHT_TIME) / LAND_TIME, 0, 1)
			if self.WiggleOwner == flight then
				button.Rotation = restingRotation + math.sin(b * math.pi * 6) * 9 * (1 - b)
			end
			local radius = math.min(button.AbsoluteSize.X, button.AbsoluteSize.Y) * (0.4 + b * 0.38)
			ring.Position = UDim2.fromOffset(target.X, target.Y)
			ring.Size = UDim2.fromOffset(radius * 2, radius * 2)
			rim.Transparency = 0.12 + b * 0.88
			for i, spark in sparks do
				local angle = math.pi / 4 + i * math.pi / 2
				local point = target + Vector2.new(math.cos(angle), math.sin(angle)) * radius
				spark.Position = UDim2.fromOffset(point.X, point.Y)
				spark.BackgroundTransparency = b
				spark.Size = UDim2.fromOffset(7 * (1 - b), 7 * (1 - b))
			end
			if b >= 1 then remove(flight) end
		end)
	end

	table.insert(controller.Connections, remote.OnClientEvent:Connect(function(position, _eggId, character)
		if character ~= player.Character then return end
		controller:Play(position)
	end))
	table.insert(controller.Connections, player.CharacterRemoving:Connect(function() controller:Cancel() end))
	table.insert(controller.Connections, button.Destroying:Connect(function() controller:Destroy() end))
	table.insert(controller.Connections, layer.Destroying:Connect(function() controller:Destroy() end))
	return controller
end

return EggDeliveryFX

