-- Finds optional art models in ReplicatedStorage.Assets and returns ready-to-place copies.
-- Folders: Assets.Pets.<PetId>, Assets.Owners.House<N>, Assets.Costumes.<CostumeId>, Assets.Props.<Name>.
-- Every script in a copy is removed and every part is made non-colliding, so Toolbox models are safe to drop in.
-- When a model is missing the game falls back to its simple block version.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Art = {}

-- Generated models face +Z; Roblox characters face -Z. Turn them around so they look the right way.
local FACE_FORWARD = CFrame.Angles(0, math.pi, 0)

function Art.Get(category: string, name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild(category)
	-- A mutated pet id ("Bat+Golden") uses the plain pet's art.
	local template = folder and folder:FindFirstChild(string.match(name, "^([^+]+)") or name)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

-- Returns a copy scaled so its largest side (or its height, if byHeight) equals `size`, with its bounding box
-- centred on the model pivot and turned to face -Z. Parts are anchored unless `unanchored` is set.
function Art.Clone(category: string, name: string, size: number, byHeight: boolean?, unanchored: boolean?): Model?
	local template = Art.Get(category, name)
	if not template then
		return nil
	end
	local model = template:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("ModuleScript") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = not unanchored
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end

	local boxCf, boxSize = model:GetBoundingBox()
	local current = if byHeight then boxSize.Y else math.max(boxSize.X, boxSize.Y, boxSize.Z)
	if current > 0 then
		model:ScaleTo(model:GetScale() * size / current)
	end
	-- Re-centre the pivot on the bounding box and face forward.
	boxCf, boxSize = model:GetBoundingBox()
	local holder = Instance.new("Part")
	holder.Name = "ArtRoot"
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.Transparency = 1
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Massless = true
	holder.Anchored = not unanchored
	holder.CFrame = CFrame.new(boxCf.Position) * FACE_FORWARD
	holder.Parent = model
	model.PrimaryPart = holder
	model:SetAttribute("ArtHeight", boxSize.Y)
	return model
end

-- Builds an egg whose look hints at the pet inside (Assets.Eggs.<PetId>, falling back to a plain studded egg
-- in the egg type's colour), optionally sitting in a wooden plank nest. The model's pivot is its bottom centre,
-- so model:PivotTo(groundCFrame) stands it on the ground. Parts are anchored unless `unanchored` is set.
function Art.Egg(eggId: string, petId: string?, withNest: boolean?, unanchored: boolean?): Model
	local Config = require(ReplicatedStorage.Shared.Config)
	local egg = Config.Eggs[eggId]
	local height = (if egg then egg.Size else 2) * 1.8 -- sized for the scaled-up houses
	local model = Instance.new("Model")
	model.Name = "EggModel"

	local root = Instance.new("Part")
	root.Name = "EggRoot"
	root.Size = Vector3.new(height * 0.8, height, height * 0.8)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.Anchored = not unanchored
	root.CFrame = CFrame.new(0, height / 2, 0)
	root.Parent = model
	model.PrimaryPart = root

	local art = petId and Art.Clone("Eggs", petId, height, true, unanchored)
	if art then
		art:PivotTo(root.CFrame)
		for _, d in art:GetDescendants() do
			if d:IsA("BasePart") then
				d.Parent = model
			end
		end
		art:Destroy()
	else
		local shell = Instance.new("Part")
		shell.Name = "Shell"
		shell.Shape = Enum.PartType.Ball
		shell.Size = root.Size
		shell.Color = if egg then egg.Color else Color3.fromRGB(240, 240, 240)
		shell.Material = Enum.Material.Plastic
		shell.TopSurface = Enum.SurfaceType.Studs
		shell.CanCollide = false
		shell.Anchored = not unanchored
		shell.CFrame = root.CFrame
		shell.Parent = model
	end

	if withNest then
		local r = height * 0.42
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			local plank = Instance.new("Part")
			plank.Name = "NestPlank"
			plank.Size = Vector3.new(height * 0.16, height * 0.22, height * 0.5)
			plank.Color = if i % 2 == 0 then Color3.fromRGB(120, 78, 40) else Color3.fromRGB(95, 60, 32)
			plank.Material = Enum.Material.Plastic
			plank.TopSurface = Enum.SurfaceType.Studs
			plank.CanCollide = false
			plank.Anchored = not unanchored
			plank.CFrame = CFrame.new(math.cos(a) * r, height * 0.1, math.sin(a) * r) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 20 else -15))
			plank.Parent = model
		end
		local base = Instance.new("Part")
		base.Name = "NestBase"
		base.Size = Vector3.new(r * 2, height * 0.1, r * 2)
		base.Color = Color3.fromRGB(85, 55, 30)
		base.Material = Enum.Material.Plastic
		base.TopSurface = Enum.SurfaceType.Studs
		base.CanCollide = false
		base.Anchored = not unanchored
		base.CFrame = CFrame.new(0, height * 0.05, 0)
		base.Parent = model
	end

	-- Mutated eggs (Golden, Diamond) glow in the mutation's colour.
	local _, mutationName = Config.SplitPet(petId or "")
	local mutation = mutationName and Config.Mutations[mutationName]
	if mutation then
		local glow = Instance.new("Highlight")
		glow.Name = "MutationGlow"
		glow.FillColor = mutation.Color
		glow.FillTransparency = 0.6
		glow.OutlineColor = mutation.Color
		glow.OutlineTransparency = 0
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Parent = model
		local light = Instance.new("PointLight")
		light.Color = mutation.Color
		light.Range = 12
		light.Brightness = 2
		light.Parent = root
	end

	-- Pivot at the bottom centre (the root sits half an egg above the ground).
	root.PivotOffset = CFrame.new(0, -height / 2, 0)
	model:SetAttribute("EggHeight", height)
	return model
end

-- Welds every part of an art model to `anchor` so it moves with it.
function Art.WeldTo(model: Model, anchor: BasePart)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchor
			weld.Part1 = d
			weld.Parent = d
		end
	end
end

return Art
