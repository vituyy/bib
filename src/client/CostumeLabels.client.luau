-- Costume Shop labels: shows WEARING / OWNED instead of the price for costumes this player has.
-- Also holds the "carry an egg in both arms" pose (the block below), which needed a script with free local slots.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer

-- Carrying an egg (lives in this script, not in Main.client, because Main.client is at Roblox's limit of 200 local
-- variables and one more breaks the whole HUD): the arms wrap around the egg. The server only welds the egg to the body; this poses the R15 arm
-- joints on every client, for every player who carries an egg, so both arms reach the sides of the egg
-- (two-bone IK on the shoulder and elbow Motor6Ds). The pose is written into the joints' C0, which animations
-- never touch, so the walking animation can not undo it; the animation's own Transform is cancelled out of it.
do
	local RunService = game:GetService("RunService")
	local CARRY_ARMS = {
		{ Side = 1, Shoulder = "RightShoulder", Elbow = "RightElbow", Wrist = "RightWrist" },
		{ Side = -1, Shoulder = "LeftShoulder", Elbow = "LeftElbow", Wrist = "LeftWrist" },
	}
	local BLEND_SPEED = 9 -- how fast the arms move into and out of the carrying pose (per second)
	local rigs: { [Model]: any } = {}
	local blend: { [Model]: number } = {}

	-- BEGIN-IK
	-- Reads the fixed frames of one arm once (the same for every pose).
	local function readArm(character: Model, def)
		local shoulder = character:FindFirstChild(def.Shoulder, true)
		local elbow = character:FindFirstChild(def.Elbow, true)
		local wrist = character:FindFirstChild(def.Wrist, true)
		if not (shoulder and elbow and wrist and shoulder:IsA("Motor6D") and elbow:IsA("Motor6D") and wrist:IsA("Motor6D")) then
			return nil
		end
		if not shoulder.Part0 then
			return nil
		end
		local F1 = shoulder.C1:Inverse() * elbow.C0 -- elbow joint, seen from the shoulder joint
		local F2 = elbow.C1:Inverse() * wrist.C0 -- wrist joint, seen from the elbow joint
		local toHand = F2 * wrist.C1:Inverse().Position -- hand centre, seen from the elbow joint
		local u1 = F1.Position.Unit
		local h1 = F1.RightVector - u1 * F1.RightVector:Dot(u1) -- the elbow's bend axis, straightened
		return {
			Side = def.Side,
			Shoulder = shoulder,
			Elbow = elbow,
			Part0 = shoulder.Part0,
			C0 = shoulder.C0,
			ElbowC0 = elbow.C0,
			F1 = F1,
			A = F1.Position.Magnitude, -- shoulder to elbow
			B = toHand.Magnitude, -- elbow to hand centre
			Basis = CFrame.fromMatrix(Vector3.zero, h1.Unit, u1),
			HandDir = toHand.Unit,
		}
	end

	-- The rotations of the shoulder and the elbow joints that put the hand centre on `target` (or as close as the
	-- arm reaches), with the elbow bent outwards and down.
	local function solveArm(arm, target: Vector3): (CFrame?, CFrame?)
		local torso = arm.Part0.CFrame
		local joint = torso * arm.C0
		local shoulderPos = joint.Position
		local toTarget = target - shoulderPos
		local distance = toTarget.Magnitude
		if distance < 0.05 then
			return nil, nil
		end
		local dir = toTarget / distance
		local reach = math.clamp(distance, math.abs(arm.A - arm.B) + 0.05, (arm.A + arm.B) * 0.995)
		local along = (arm.A * arm.A - arm.B * arm.B + reach * reach) / (2 * reach)
		local out = math.sqrt(math.max(arm.A * arm.A - along * along, 0))
		local pole = torso:VectorToWorldSpace(Vector3.new(arm.Side * 0.6, -1, 0.15))
		pole -= dir * pole:Dot(dir)
		if pole.Magnitude < 1e-3 then
			pole = -torso.UpVector
		end
		pole = pole.Unit
		local elbowPos = shoulderPos + dir * along + pole * out
		local handPos = shoulderPos + dir * reach
		local upper = (elbowPos - shoulderPos).Unit
		local lower = (handPos - elbowPos).Unit
		local bendAxis = pole:Cross(dir).Unit
		-- Shoulder: turn the upper arm to point at the elbow with the bend axis along the bend.
		local worldBasis = CFrame.fromMatrix(Vector3.zero, bendAxis, upper)
		local toWorld = worldBasis * arm.Basis:Inverse()
		local shoulderRotation = joint.Rotation:Inverse() * toWorld
		-- Elbow: a hinge about its X axis that turns the forearm onto the hand.
		local elbowFrame = toWorld * arm.F1.Rotation
		local want = elbowFrame:VectorToObjectSpace(lower)
		local angle = math.atan2(want.Z, want.Y) - math.atan2(arm.HandDir.Z, arm.HandDir.Y)
		return shoulderRotation, CFrame.Angles(angle, 0, 0)
	end
	-- END-IK

	local function release(rig)
		for _, arm in rig.Arms do
			arm.Shoulder.C0 = arm.C0
			arm.Elbow.C0 = arm.ElbowC0
		end
	end

	local function usable(rig, character: Model): boolean
		for _, arm in rig.Arms do
			if not (arm.Shoulder:IsDescendantOf(character) and arm.Elbow:IsDescendantOf(character) and arm.Part0:IsDescendantOf(character)) then
				return false
			end
		end
		return #rig.Arms > 0
	end

	RunService.Heartbeat:Connect(function(dt)
		for _, other in Players:GetPlayers() do
			local character = other.Character
			local egg = character and character:FindFirstChild("CarriedEgg")
			local eggRoot = egg and egg:FindFirstChild("EggRoot") :: BasePart?
			local rig = if character then rigs[character] else nil
			if character and eggRoot then
				if rig and not usable(rig, character) then
					rigs[character] = nil
					rig = nil
				end
				if rig == nil then
					local arms = {}
					for _, def in CARRY_ARMS do
						local arm = readArm(character, def)
						if arm then
							table.insert(arms, arm)
						end
					end
					rig = { Arms = arms }
					rigs[character] = rig
					if #arms == 0 then
						warn("[SpookySteal] carry pose: no R15 arm joints found on " .. character.Name)
					end
					character.Destroying:Connect(function()
						rigs[character] = nil
						blend[character] = nil
					end)
				end
				local weight = math.min(1, (blend[character] or 0) + dt * BLEND_SPEED)
				blend[character] = weight
				local size = eggRoot.Size
				for _, arm in rig.Arms do
					-- The hands rest on the sides of the egg, a little below its middle and towards the player.
					local target = eggRoot.CFrame * Vector3.new(arm.Side * size.X * 0.46, -size.Y * 0.12, size.Z * 0.12)
					local ok, shoulderR, elbowR = pcall(solveArm, arm, target)
					if not ok and not arm.Warned then
						arm.Warned = true
						warn("[SpookySteal] carry pose failed:", shoulderR)
					end
					if ok and shoulderR and elbowR then
						-- joint = C0 * Transform. Pick C0 so that C0 * (the animation's Transform) is the wanted rotation.
						local shoulderDelta = shoulderR * arm.Shoulder.Transform:Inverse()
						local elbowDelta = elbowR * arm.Elbow.Transform:Inverse()
						arm.Shoulder.C0 = arm.C0 * CFrame.identity:Lerp(shoulderDelta, weight)
						arm.Elbow.C0 = arm.ElbowC0 * CFrame.identity:Lerp(elbowDelta, weight)
					end
				end
			elseif character and blend[character] then
				blend[character] = nil
				if rig then
					release(rig)
				end
			end
		end
	end)
end

local shop = workspace:WaitForChild("Map"):WaitForChild("Hub"):WaitForChild("CostumeShop")
local mannequins = shop:WaitForChild("Mannequins")

local GOLD = Color3.fromRGB(255, 200, 80)
local GREEN = Color3.fromRGB(120, 255, 140)
local LAVENDER = Color3.fromRGB(210, 170, 255)

local function fmt(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function refresh()
	local equipped = player:GetAttribute("CostumeEquipped")
	local owned = {}
	for id in string.gmatch(player:GetAttribute("CostumesOwned") or "", "[^,]+") do
		owned[id] = true
	end
	for _, display in mannequins:GetChildren() do
		local id = display:GetAttribute("Costume")
		local costume = id and Config.GetCostume(id)
		local sign = display:FindFirstChild("InfoSign", true)
		local price = sign and sign:FindFirstChild("PriceLabel", true) :: TextLabel?
		if costume and costume.Id == id and price then
			if equipped == id then
				price.Text, price.TextColor3 = "WEARING", GREEN
			elseif owned[id] then
				price.Text, price.TextColor3 = "OWNED - press E to wear", LAVENDER
			else
				price.Text, price.TextColor3 = fmt(costume.Price) .. " Candy", GOLD
			end
		end
	end
end

player:GetAttributeChangedSignal("CostumeEquipped"):Connect(refresh)
player:GetAttributeChangedSignal("CostumesOwned"):Connect(refresh)
refresh()
