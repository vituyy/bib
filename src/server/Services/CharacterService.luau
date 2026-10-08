-- Applies walk speed (upgrades, egg carrying, stuns) and costume visuals to characters.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Art = require(ReplicatedStorage.Shared.Art)
local Skins = require(ReplicatedStorage.Shared.Skins)
local CostumeOutfits = require(ReplicatedStorage.Shared.CostumeOutfits)
local DataService = require(script.Parent.DataService)

local CharacterService = {}

local stunnedUntil: { [Player]: number } = {}
local graceUntil: { [Player]: number } = {} -- a kick or other server launch moves a player faster than they can run

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

-- The player's own look, saved when a Marketplace costume first goes on, so it can be put back.
local ownLook: { [Model]: HumanoidDescription } = setmetatable({}, { __mode = "k" }) :: any

-- Puts the player's own avatar back if a Marketplace costume changed it (runs in the background).
local function restoreOwnLook(character: Model, costumeId: string)
	local own = ownLook[character]
	if not own then
		return
	end
	task.spawn(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid and character.Parent and character:GetAttribute("CostumeWorn") == costumeId and ownLook[character] == own then
			ownLook[character] = nil
			pcall(humanoid.ApplyDescription, humanoid, own)
		end
	end)
end

local function wearArt(character: Model, costume): boolean
	-- Marketplace costume (Shared.CostumeOutfits): a whole avatar look applied to the character, so it looks
	-- the same on everybody and keeps the avatar's animations.
	if CostumeOutfits.Has(costume.Id) then
		local id = costume.Id
		task.spawn(function()
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid then
				return
			end
			-- Wait until the player's own avatar has finished loading, or it would cover the costume.
			local player = Players:GetPlayerFromCharacter(character)
			local waited = 0
			while player and not player:HasAppearanceLoaded() and waited < 10 do
				waited += task.wait(0.2)
			end
			task.wait(0.1)
			if not ownLook[character] then
				local ok, own = pcall(humanoid.GetAppliedDescription, humanoid)
				if ok then
					ownLook[character] = own
				end
			end
			local desc = CostumeOutfits.Description(id)
			if desc and character.Parent and character:GetAttribute("CostumeWorn") == id then
				local ok, err = pcall(humanoid.ApplyDescription, humanoid, desc)
				if not ok then
					warn("[CharacterService] costume", id, err)
				end
			end
		end)
		return true
	end
	-- Full-body skin (Shared.Skins): replaces the whole avatar, so it looks the same on everybody.
	if Skins.Has(costume.Id) then
		local id = costume.Id
		local function build()
			if character:GetAttribute("CostumeWorn") ~= id then
				return
			end
			local old = character:FindFirstChild("CostumeArt")
			if old then
				old:Destroy()
			end
			local skin = Skins.Build(character, id)
			if skin then
				skin.Parent = character
			end
			setHidden(character, "Body")
		end
		build()
		-- The avatar finishes loading after spawn: body parts get swapped in and accessories and clothing arrive.
		-- Rebuild the skin when a body part changes, and hide anything else that shows up, while this costume is on.
		local pending = false
		local conn: RBXScriptConnection
		conn = character.DescendantAdded:Connect(function(d)
			if character:GetAttribute("CostumeWorn") ~= id then
				conn:Disconnect()
				return
			end
			if d:FindFirstAncestor("CostumeArt") or not (d:IsA("BasePart") or d:IsA("Decal")) or pending then
				return
			end
			pending = true
			task.delay(0.1, function()
				pending = false
				build()
			end)
		end)
		return true
	end
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

	local speed = Config.ChosenSpeed(data)
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
	-- Earned titles show over the head ("Blood Moon Survivor", red).
	if data.BloodMoonSurvivor then
		player:SetAttribute("Title", Config.BloodMoon.Title)
	end
	local title = player:GetAttribute("Title")
	local head = character:FindFirstChild("Head")
	if title and head and not head:FindFirstChild("TitleTag") then
		local tag = Instance.new("BillboardGui")
		tag.Name = "TitleTag"
		tag.Size = UDim2.fromOffset(220, 26)
		tag.StudsOffset = Vector3.new(0, 3.2, 0)
		tag.MaxDistance = 80
		tag.Parent = head
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.Text = "🩸 " .. title
		text.TextColor3 = Color3.fromRGB(255, 50, 50)
		text.TextStrokeTransparency = 0
		text.Parent = tag
	end
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
	if not CostumeOutfits.Has(costume.Id) then
		restoreOwnLook(character, costume.Id)
	end
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

-- The movement check ignores this player for `seconds` (the server launched them).
function CharacterService.Grace(player: Player, seconds: number)
	graceUntil[player] = os.clock() + seconds
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

-- Anti-cheat: the client moves its own character, so a cheat can run far faster than the speed the server gave
-- it (or fly). Every half second the server compares how far each player moved with how far they could have.
-- Four checks in a row over the limit (2 seconds) put them back where they were last fine. One slow frame, a
-- lag burst or a server teleport only ever causes a single check to fail, so normal play is never touched.
local WATCH_INTERVAL = 0.5
local WATCH_STRIKES = 4
local lastFine: { [Player]: { Character: Model, Last: Vector3, Good: Vector3, At: number, Strikes: number } } = {}

local function watchMovement()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (character and root and humanoid and humanoid.Health > 0) then
			lastFine[player] = nil
			continue
		end
		local record = lastFine[player]
		if not record or record.Character ~= character then
			lastFine[player] = { Character = character, Last = root.Position, Good = root.Position, At = now, Strikes = 0 }
			continue
		end
		if (graceUntil[player] or 0) > now then
			record.Last, record.At, record.Strikes = root.Position, now, 0
			continue
		end
		-- Distance since the previous check, against what this player's speed allows (plus room for slopes, lag
		-- and the treadmill belt's 10 studs/s).
		local flat = Vector3.new(root.Position.X - record.Last.X, 0, root.Position.Z - record.Last.Z).Magnitude
		local allowed = (humanoid.WalkSpeed * 1.3 + 25) * (now - record.At)
		if flat <= allowed then
			record.Strikes = 0
			record.Good = root.Position
		else
			record.Strikes += 1
			if record.Strikes >= WATCH_STRIKES then
				character:PivotTo(CFrame.new(record.Good + Vector3.new(0, 3, 0)))
				record.Strikes = 0
				record.Last = record.Good
				record.At = now
				continue
			end
		end
		record.Last = root.Position
		record.At = now
	end
end

-- Costume Shop mannequins: when the game starts, each one becomes a full avatar wearing its Marketplace costume,
-- standing on its pedestal and facing the shop entrance. (In Edit mode they keep the simple placeholder look.)
local function dressMannequins()
	local map = workspace:FindFirstChild("Map")
	local hub = map and map:FindFirstChild("Hub")
	local shop = hub and hub:FindFirstChild("CostumeShop")
	local mannequins = shop and shop:FindFirstChild("Mannequins")
	if not mannequins then
		return
	end
	for _, man in mannequins:GetChildren() do
		local id = man:GetAttribute("Costume")
		local art = man:FindFirstChild("Art")
		local cap = man:FindFirstChild("Cap") :: BasePart?
		if not (id and art and cap and CostumeOutfits.Has(id)) then
			continue
		end
		task.spawn(function()
			local desc = CostumeOutfits.Description(id)
			if not desc then
				return
			end
			local ok, rig = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
			if not ok then
				warn("[CharacterService] mannequin", id, rig)
				return
			end
			-- Face the same way as the placeholder, feet on the pedestal top.
			local pivot = art:GetPivot()
			local look = Vector3.new(pivot.LookVector.X, 0, pivot.LookVector.Z)
			local placeholder = art:FindFirstChild("SkinRig")
			if placeholder and placeholder:IsA("Model") then
				local l = placeholder:GetPivot().LookVector
				look = Vector3.new(l.X, 0, l.Z)
			end
			if look.Magnitude < 0.01 then
				look = Vector3.new(-1, 0, 0)
			end
			-- Highest point of the pedestal (its parts are rotated cylinders, so use their world extents).
			local top = -math.huge
			for _, name in { "Pedestal", "Cap" } do
				local p = man:FindFirstChild(name) :: BasePart?
				if p then
					local c = p.CFrame
					local h = math.abs(c.RightVector.Y) * p.Size.X + math.abs(c.UpVector.Y) * p.Size.Y + math.abs(c.LookVector.Y) * p.Size.Z
					top = math.max(top, p.Position.Y + h / 2)
				end
			end
			local humanoid = rig:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
			rig.Name = "CostumeAvatar"
			rig:PivotTo(CFrame.lookAt(Vector3.new(cap.Position.X, top + 5, cap.Position.Z), Vector3.new(cap.Position.X, top + 5, cap.Position.Z) + look.Unit))
			for _, p in rig:GetDescendants() do
				if p:IsA("BasePart") then
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
				end
			end
			local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				root.Anchored = true
			end
			rig.Parent = man
			task.wait(1) -- let the rig settle before lining up the feet
			-- Stand on the feet (a long robe may hang lower than them).
			local bottom = math.huge
			for _, name in { "LeftFoot", "RightFoot", "Left Leg", "Right Leg" } do
				local f = rig:FindFirstChild(name) :: BasePart?
				if f then
					bottom = math.min(bottom, f.Position.Y - f.Size.Y / 2)
				end
			end
			if bottom == math.huge then
				local cf, size = rig:GetBoundingBox()
				bottom = cf.Position.Y - size.Y / 2
			end
			rig:PivotTo(rig:GetPivot() + Vector3.new(0, top - bottom, 0))
			art.Parent = nil -- the placeholder is no longer needed
		end)
	end
end

function CharacterService.Start()
	task.spawn(dressMannequins)
	task.spawn(function()
		while true do
			task.wait(WATCH_INTERVAL)
			local ok, err = pcall(watchMovement)
			if not ok then
				warn("[CharacterService] movement check error:", err)
			end
		end
	end)
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
		graceUntil[player] = nil
		lastFine[player] = nil
	end)
	DataService.OnChanged(function(player)
		CharacterService.Refresh(player)
	end)
end

return CharacterService
