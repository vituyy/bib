-- Applies walk speed (upgrades, egg carrying, stuns) and costume visuals to characters.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Art = require(ReplicatedStorage.Shared.Art)
local DataService = require(script.Parent.DataService)

local CharacterService = {}

local stunnedUntil: { [Player]: number } = {}

-- Hide the parts a costume covers: "Head" hides the head, face and accessories, "Body" hides everything.
-- "None" shows everything again.
local function setHidden(character: Model, mode: string)
	for _, d in character:GetDescendants() do
		if d.Name == "HumanoidRootPart" or d:FindFirstAncestor("CostumeArt") or d:FindFirstAncestor("CarriedEgg") or d.Name == "CarriedEgg" then
			continue
		end
		local isHead = d.Name == "Head" or (d.Parent and d.Parent.Name == "Head") or d:FindFirstAncestorOfClass("Accessory") ~= nil
		local hide = mode == "Body" or (mode == "Head" and isHead)
		if d:IsA("BasePart") or d:IsA("Decal") then
			if hide and d:GetAttribute("CostumeOriginal") == nil then
				d:SetAttribute("CostumeOriginal", d.Transparency)
				d.Transparency = 1
			elseif not hide and d:GetAttribute("CostumeOriginal") ~= nil then
				d.Transparency = d:GetAttribute("CostumeOriginal")
				d:SetAttribute("CostumeOriginal", nil)
			end
		end
	end
end

local function wearArt(character: Model, costume): boolean
	local head = character:FindFirstChild("Head") :: BasePart?
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (head and torso and root and costume.Attach) then
		return false
	end
	local art = Art.Clone("Costumes", costume.Id, costume.ArtSize, costume.Attach ~= "Head" and costume.Attach ~= "Hat", true)
	if not art then
		return false
	end
	art.Name = "CostumeArt"
	local height = art:GetAttribute("ArtHeight") or costume.ArtSize
	local anchor: BasePart
	if costume.Attach == "Head" then
		anchor = head
		art:PivotTo(head.CFrame * CFrame.new(0, 0.15, 0))
	elseif costume.Attach == "Hat" then
		anchor = head
		art:PivotTo(head.CFrame * CFrame.new(0, head.Size.Y / 2 + height / 2 - 0.4, 0))
	elseif costume.Attach == "Back" then
		anchor = torso
		art:PivotTo(torso.CFrame * CFrame.new(0, -height / 2 + torso.Size.Y / 2 + 0.6, torso.Size.Z / 2 + 0.3))
	else -- "Body": a shell over the whole character
		anchor = root
		art:PivotTo(root.CFrame * CFrame.new(0, -0.35, 0))
	end
	Art.WeldTo(art, anchor)
	art.Parent = character
	setHidden(character, if costume.Attach == "Body" then "Body" elseif costume.Attach == "Head" then "Head" else "None")
	return true
end

function CharacterService.Refresh(player: Player)
	local data = DataService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (data and humanoid) then
		return
	end

	local speed = Config.WalkSpeedFor(data.SpeedLevel)
	local carriedEgg = Config.Eggs[player:GetAttribute("CarryingEgg") or ""]
	if carriedEgg then
		speed *= carriedEgg.CarrySpeed
	end
	if (stunnedUntil[player] or 0) > os.clock() then
		speed = 4
	end
	humanoid.WalkSpeed = speed

	local costume = Config.GetCostume(data.EquippedCostume)
	-- The costume shop labels read these to show Owned / Wearing.
	player:SetAttribute("CostumeEquipped", costume.Id)
	player:SetAttribute("CostumesOwned", table.concat(data.OwnedCostumes, ","))
	if character:GetAttribute("CostumeWorn") == costume.Id then
		return
	end
	character:SetAttribute("CostumeWorn", costume.Id)
	for _, name in { "CostumeCape", "CostumeArt" } do
		local old = character:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	setHidden(character, "None")
	if costume.Id == "None" then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	-- Real costume model from Assets.Costumes when there is one.
	if wearArt(character, costume) then
		return
	end

	-- Fallback: a simple colored cape on the character's back.
	local cape = character:FindFirstChild("CostumeCape")
	if not cape then
		cape = Instance.new("Part")
		cape.Name = "CostumeCape"
		cape.Size = Vector3.new(2.2, 3.2, 0.2)
		cape.CanCollide = false
		cape.CanQuery = false
		cape.Massless = true
		cape.CFrame = root.CFrame * CFrame.new(0, -0.2, 0.65)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = cape
		weld.Parent = cape
		cape.Parent = character
	end
	cape.Color = costume.Color
	cape.Material = if costume.Id == "Skeleton" then Enum.Material.Neon else Enum.Material.Fabric
end

function CharacterService.Stun(player: Player, seconds: number)
	stunnedUntil[player] = os.clock() + seconds
	CharacterService.Refresh(player)
	task.delay(seconds, function()
		if player.Parent then
			CharacterService.Refresh(player)
		end
	end)
end

function CharacterService.Start()
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Humanoid")
			DataService.WaitFor(player)
			CharacterService.Refresh(player)
		end)
		player:GetAttributeChangedSignal("CarryingEgg"):Connect(function()
			CharacterService.Refresh(player)
		end)
		if player.Character then
			task.spawn(function()
				DataService.WaitFor(player)
				CharacterService.Refresh(player)
			end)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		stunnedUntil[player] = nil
	end)
	DataService.OnChanged(function(player)
		CharacterService.Refresh(player)
	end)
end

return CharacterService
