-- Full-body costume skins: blocky pieces welded to every body part (head, torso, arms, hands, legs, feet), so a
-- costume replaces the whole look on any avatar and moves with its animations. The player's own avatar is hidden
-- while a skin is worn (CharacterService does that).
-- Pieces are given in each body part's own space, as fractions of that part's size: -0.5..0.5 is the part itself,
-- -0.56..0.56 a shell just around it. Front is -Z. `abs = true` gives a piece in studs instead (props like a scythe).
-- Works on R15; on R6 the arm, leg and torso pieces are fitted onto the single R6 parts.

local Skins = {}

local DEFS: { [string]: { any } } = {}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local BLACK = rgb(20, 16, 24)
local WHITE = rgb(255, 255, 255)
local PINK = rgb(255, 150, 185)
local GOLD = rgb(255, 196, 60)
local ORANGE = rgb(240, 110, 20)
local LEAF = rgb(90, 150, 50)

local function skin(id: string)
	local list = DEFS[id] or {}
	DEFS[id] = list
	local api = {}
	function api.box(seg, color, x0, y0, z0, x1, y1, z1, opt)
		table.insert(list, { seg, color, x0, y0, z0, x1, y1, z1, opt or {} })
	end
	-- the same piece on both sides of one part (coordinates for the right side, +X)
	function api.pair(seg, color, x0, y0, z0, x1, y1, z1, opt)
		opt = opt or {}
		api.box(seg, color, x0, y0, z0, x1, y1, z1, opt)
		local m = table.clone(opt)
		m.rz = opt.rz and -opt.rz
		api.box(seg, color, -x1, y0, z0, -x0, y1, z1, m)
	end
	-- the same piece on the right and left limb (coordinates for the right limb, outer side +X)
	function api.sym(base, color, x0, y0, z0, x1, y1, z1, opt)
		opt = opt or {}
		api.box("Right" .. base, color, x0, y0, z0, x1, y1, z1, opt)
		local m = table.clone(opt)
		m.rz = opt.rz and -opt.rz
		api.box("Left" .. base, color, -x1, y0, z0, -x0, y1, z1, m)
	end
	function api.shell(seg, color, e)
		e = e or 0.56
		api.box(seg, color, -e, -e, -e, e, e, e)
	end
	function api.limb(base, color, e)
		e = e or 0.56
		api.sym(base, color, -e, -e, -e, e, e, e)
	end
	-- base colours for every body part
	function api.body(c)
		api.shell("Head", c.Head, 0.58)
		api.shell("UpperTorso", c.UpperTorso)
		api.shell("LowerTorso", c.LowerTorso)
		for _, base in { "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot" } do
			api.limb(base, c[base])
		end
	end
	-- a band all the way round a part
	function api.ring(seg, color, y0, y1, e, opt)
		e = e or 0.6
		api.box(seg, color, -e, y0, -e, e, y1, e, opt)
	end
	return api
end

------------------------------------------------------------------------ Bedsheet Ghost
do
	local s = skin("Ghost")
	local W, G = rgb(245, 245, 252), rgb(212, 215, 232)
	s.body({ Head = W, UpperTorso = W, LowerTorso = W, UpperArm = W, LowerArm = W, Hand = W, UpperLeg = W, LowerLeg = W, Foot = W })
	s.box("Head", W, -0.62, -0.62, -0.62, 0.62, 0.62, 0.62)
	s.box("Head", W, -0.45, 0.6, -0.45, 0.45, 0.78, 0.45)
	s.pair("Head", BLACK, 0.08, -0.04, -0.66, 0.38, 0.34, -0.62)
	s.pair("Head", WHITE, 0.24, 0.18, -0.67, 0.32, 0.28, -0.66, { mat = NEON })
	s.pair("Head", PINK, 0.38, -0.2, -0.65, 0.52, -0.1, -0.62)
	s.box("Head", BLACK, -0.09, -0.4, -0.66, 0.09, -0.2, -0.62)
	-- the sheet hangs from the hips and flares out
	s.box("LowerTorso", W, -0.66, -3.4, -0.66, 0.66, 0.5, 0.66)
	for i = 0, 5 do
		local x = -0.66 + i * 0.22
		s.box("LowerTorso", if i % 2 == 0 then W else G, x, if i % 2 == 0 then -4 else -3.7, -0.66, x + 0.22, -3.4, 0.66)
	end
	s.box("UpperTorso", W, -0.62, -0.62, -0.62, 0.62, 0.62, 0.62)
	s.sym("UpperArm", W, 0.4, -0.9, -0.62, 0.72, 0.56, 0.62)
	s.sym("LowerArm", G, 0.4, -0.7, -0.6, 0.7, 0.3, 0.6)
	-- jack-o'-lantern candy bucket
	s.box("RightHand", ORANGE, -0.42, -1.1, -0.45, 0.42, -0.3, 0.45, { abs = true })
	s.box("RightHand", rgb(255, 220, 70), -0.28, -0.6, -0.47, -0.08, -0.45, -0.45, { abs = true, mat = NEON })
	s.box("RightHand", rgb(255, 220, 70), 0.08, -0.6, -0.47, 0.28, -0.45, -0.45, { abs = true, mat = NEON })
	s.box("RightHand", rgb(255, 220, 70), -0.25, -0.9, -0.47, 0.25, -0.78, -0.45, { abs = true, mat = NEON })
	s.box("RightHand", BLACK, -0.05, -0.3, -0.05, 0.05, 0.1, 0.05, { abs = true })
end

------------------------------------------------------------------------ Pumpkin Head
do
	local s = skin("Pumpkin")
	local P, PD, SUIT, PANTS, BOOT, GLOVE, GLOW = rgb(245, 120, 20), rgb(205, 85, 10), rgb(60, 35, 80), rgb(45, 40, 55), rgb(90, 60, 40), rgb(90, 150, 50), rgb(255, 210, 70)
	s.body({ Head = P, UpperTorso = SUIT, LowerTorso = PANTS, UpperArm = SUIT, LowerArm = SUIT, Hand = GLOVE, UpperLeg = PANTS, LowerLeg = PANTS, Foot = BOOT })
	s.box("Head", P, -0.85, -0.45, -0.7, 0.85, 0.85, 0.7, { light = rgb(255, 170, 60) })
	s.box("Head", P, -0.7, -0.6, -0.7, 0.7, 1, 0.7)
	s.box("Head", P, -0.7, -0.45, -0.85, 0.7, 0.85, 0.85)
	s.pair("Head", PD, 0.36, -0.35, -0.87, 0.44, 0.75, -0.85)
	s.pair("Head", GLOW, 0.14, 0.3, -0.89, 0.56, 0.42, -0.86, { mat = NEON })
	s.pair("Head", GLOW, 0.22, 0.42, -0.89, 0.48, 0.54, -0.86, { mat = NEON })
	s.pair("Head", GLOW, 0.3, 0.54, -0.89, 0.4, 0.64, -0.86, { mat = NEON })
	s.box("Head", GLOW, -0.08, 0.12, -0.89, 0.08, 0.24, -0.86, { mat = NEON })
	s.box("Head", GLOW, -0.52, -0.3, -0.89, 0.52, -0.06, -0.86, { mat = NEON })
	s.box("Head", P, -0.3, -0.3, -0.9, -0.18, -0.18, -0.88)
	s.box("Head", P, 0.18, -0.18, -0.9, 0.3, -0.06, -0.88)
	s.box("Head", LEAF, -0.1, 1, -0.1, 0.1, 1.3, 0.1)
	s.box("Head", LEAF, 0.1, 1, -0.15, 0.45, 1.07, 0.2)
	-- jacket with an orange vest and a leafy collar
	s.box("UpperTorso", ORANGE, -0.3, -0.5, -0.6, 0.3, 0.5, -0.56)
	for _, y in { 0.25, -0.05, -0.35 } do
		s.box("UpperTorso", BLACK, -0.05, y, -0.62, 0.05, y + 0.08, -0.6)
	end
	s.pair("UpperTorso", LEAF, 0.05, 0.4, -0.62, 0.45, 0.62, -0.3, { rz = -15 })
	s.ring("LowerTorso", BLACK, -0.2, 0.2)
	s.sym("LowerArm", SUIT, -0.65, -0.62, -0.65, 0.65, -0.25, 0.65)
end

------------------------------------------------------------------------ Witch
do
	local s = skin("Witch")
	local SKIN, DRESS, DRESSD, HAT, HAIR, STOCK = rgb(120, 190, 90), rgb(95, 50, 135), rgb(60, 32, 90), rgb(40, 25, 55), rgb(25, 20, 30), rgb(25, 20, 30)
	s.body({ Head = SKIN, UpperTorso = DRESS, LowerTorso = DRESS, UpperArm = DRESS, LowerArm = DRESS, Hand = SKIN, UpperLeg = STOCK, LowerLeg = STOCK, Foot = BLACK })
	s.box("Head", HAIR, -0.62, -0.75, 0.25, 0.62, 0.55, 0.62)
	s.pair("Head", HAIR, 0.5, -0.8, -0.3, 0.63, 0.55, 0.5)
	s.pair("Head", BLACK, 0.12, 0.05, -0.6, 0.32, 0.25, -0.58)
	s.box("Head", rgb(95, 160, 70), -0.08, -0.15, -0.78, 0.08, 0.08, -0.58)
	s.box("Head", rgb(95, 160, 70), 0.04, -0.06, -0.8, 0.12, 0.02, -0.76)
	s.box("Head", BLACK, -0.22, -0.34, -0.6, 0.22, -0.28, -0.58)
	-- hat
	s.box("Head", HAT, -1.1, 0.55, -1.1, 1.1, 0.65, 1.1)
	s.box("Head", HAT, -0.58, 0.65, -0.58, 0.58, 1.2, 0.58)
	s.box("Head", ORANGE, -0.6, 0.65, -0.6, 0.6, 0.85, 0.6)
	s.box("Head", GOLD, -0.14, 0.66, -0.63, 0.14, 0.84, -0.6, { mat = METAL })
	s.box("Head", HAT, -0.42, 1.2, -0.35, 0.42, 1.65, 0.5)
	s.box("Head", HAT, -0.28, 1.65, -0.1, 0.28, 2, 0.6)
	s.box("Head", HAT, -0.16, 1.9, 0.35, 0.16, 2.15, 0.9)
	s.box("Head", HAT, -0.1, 1.75, 0.8, 0.1, 2.05, 1.1)
	-- dress with a wide skirt
	s.box("UpperTorso", ORANGE, -0.35, 0.42, -0.6, 0.35, 0.56, -0.56)
	s.box("LowerTorso", DRESSD, -0.75, -4.2, -0.75, 0.75, 0.5, 0.75)
	s.box("LowerTorso", ORANGE, -0.77, -4.3, -0.77, 0.77, -3.9, 0.77)
	s.sym("LowerArm", DRESSD, -0.7, -0.6, -0.7, 0.7, -0.15, 0.7)
	-- striped stockings and pointy boots
	for _, base in { "UpperLeg", "LowerLeg" } do
		s.sym(base, ORANGE, -0.6, -0.2, -0.6, 0.6, 0.0, 0.6)
		s.sym(base, ORANGE, -0.6, 0.25, -0.6, 0.6, 0.45, 0.6)
	end
	s.sym("Foot", BLACK, -0.55, -0.55, -1.15, 0.55, 0.7, 0.58)
	s.sym("Foot", BLACK, -0.2, 0.3, -1.3, 0.2, 0.75, -0.95)
end

------------------------------------------------------------------------ Vampire
do
	local s = skin("Vampire")
	local PALE, SUIT, RED, SHIRT = rgb(225, 220, 232), rgb(28, 22, 34), rgb(170, 10, 30), rgb(240, 240, 245)
	s.body({ Head = PALE, UpperTorso = SUIT, LowerTorso = SUIT, UpperArm = SUIT, LowerArm = SUIT, Hand = PALE, UpperLeg = SUIT, LowerLeg = SUIT, Foot = BLACK })
	s.box("Head", BLACK, -0.62, 0.38, -0.62, 0.62, 0.68, 0.62)
	s.box("Head", BLACK, -0.16, 0.22, -0.63, 0.16, 0.42, -0.58)
	s.box("Head", BLACK, -0.62, -0.3, 0.45, 0.62, 0.6, 0.63)
	s.pair("Head", BLACK, 0.57, 0, -0.2, 0.63, 0.6, 0.6)
	s.pair("Head", RED, 0.12, 0.02, -0.61, 0.32, 0.17, -0.58, { mat = NEON })
	s.pair("Head", BLACK, 0.1, 0.22, -0.61, 0.36, 0.28, -0.58, { rz = 12 })
	s.box("Head", BLACK, -0.22, -0.26, -0.6, 0.22, -0.21, -0.58)
	s.pair("Head", WHITE, 0.1, -0.38, -0.61, 0.18, -0.24, -0.59)
	-- suit with white shirt, red bow tie and a medallion
	s.box("UpperTorso", SHIRT, -0.22, -0.5, -0.6, 0.22, 0.56, -0.56)
	s.box("UpperTorso", RED, -0.2, 0.32, -0.63, 0.2, 0.44, -0.6)
	s.box("UpperTorso", GOLD, -0.08, -0.05, -0.63, 0.08, 0.1, -0.6, { mat = METAL })
	-- cape with a red lining and a tall collar
	s.box("UpperTorso", SUIT, -0.78, -1.65, 0.58, 0.78, 0.5, 0.68)
	s.box("UpperTorso", RED, -0.74, -1.6, 0.54, 0.74, 0.48, 0.58)
	s.pair("UpperTorso", SUIT, 0.6, -1.6, -0.2, 0.8, 0.5, 0.68)
	s.box("UpperTorso", SUIT, -0.78, 0.45, 0.35, 0.78, 1.0, 0.66)
	s.box("UpperTorso", RED, -0.72, 0.45, 0.3, 0.72, 0.95, 0.35)
	s.pair("UpperTorso", SUIT, 0.55, 0.45, -0.3, 0.8, 0.95, 0.4, { rz = -10 })
end

------------------------------------------------------------------------ Glowing Skeleton
do
	local s = skin("Skeleton")
	local SUIT, BONE, GLOW = rgb(20, 18, 24), rgb(238, 235, 218), rgb(60, 255, 90)
	s.body({ Head = BONE, UpperTorso = SUIT, LowerTorso = SUIT, UpperArm = SUIT, LowerArm = SUIT, Hand = BONE, UpperLeg = SUIT, LowerLeg = SUIT, Foot = SUIT })
	s.box("Head", BONE, -0.5, 0.56, -0.5, 0.5, 0.66, 0.5, { light = GLOW })
	s.pair("Head", BLACK, 0.08, -0.06, -0.6, 0.38, 0.28, -0.58)
	s.pair("Head", GLOW, 0.17, 0.04, -0.61, 0.29, 0.16, -0.6, { mat = NEON })
	s.box("Head", BLACK, -0.07, -0.2, -0.6, 0.07, -0.08, -0.58)
	s.box("Head", WHITE, -0.32, -0.44, -0.6, 0.32, -0.28, -0.585)
	for _, x in { -0.16, 0, 0.16 } do
		s.box("Head", BLACK, x - 0.012, -0.44, -0.6, x + 0.012, -0.28, -0.59)
	end
	s.box("Head", BLACK, -0.32, -0.37, -0.6, 0.32, -0.355, -0.59)
	-- ribs, spine and pelvis
	for _, y in { 0.32, 0.08, -0.16 } do
		s.box("UpperTorso", BONE, -0.42, y, -0.6, 0.42, y + 0.1, -0.56)
	end
	s.box("UpperTorso", BONE, -0.05, -0.4, -0.61, 0.05, 0.48, -0.56)
	s.box("UpperTorso", BONE, -0.05, -0.5, 0.56, 0.05, 0.5, 0.6)
	s.box("LowerTorso", BONE, -0.42, -0.3, -0.6, 0.42, 0.3, -0.56)
	for _, base in { "UpperArm", "LowerArm", "UpperLeg", "LowerLeg" } do
		s.sym(base, BONE, -0.12, -0.45, -0.6, 0.12, 0.45, -0.56)
	end
	s.sym("Foot", BONE, -0.3, -0.2, -0.6, 0.3, 0.3, -0.56)
end

------------------------------------------------------------------------ Werewolf
do
	local s = skin("Werewolf")
	local FUR, DARK, TAN, SHIRT, PLAID, JEANS, EYE = rgb(110, 78, 55), rgb(78, 55, 40), rgb(200, 170, 130), rgb(180, 40, 40), rgb(110, 20, 25), rgb(60, 85, 140), rgb(255, 215, 40)
	s.body({ Head = FUR, UpperTorso = SHIRT, LowerTorso = JEANS, UpperArm = SHIRT, LowerArm = FUR, Hand = FUR, UpperLeg = JEANS, LowerLeg = FUR, Foot = DARK })
	s.box("Head", TAN, -0.32, -0.52, -1, 0.32, 0.05, -0.5)
	s.box("Head", BLACK, -0.13, -0.06, -1.05, 0.13, 0.08, -0.95)
	s.pair("Head", WHITE, 0.16, -0.64, -0.96, 0.25, -0.5, -0.86)
	s.box("Head", BLACK, -0.24, -0.4, -1.02, 0.24, -0.36, -0.98)
	s.pair("Head", EYE, 0.12, 0.14, -0.61, 0.42, 0.3, -0.58, { mat = NEON })
	s.pair("Head", BLACK, 0.24, 0.15, -0.62, 0.3, 0.29, -0.61)
	s.pair("Head", DARK, 0.08, 0.32, -0.62, 0.46, 0.42, -0.57, { rz = 15 })
	s.pair("Head", FUR, 0.22, 0.55, -0.15, 0.56, 0.9, 0.15)
	s.pair("Head", DARK, 0.32, 0.9, -0.08, 0.48, 1.1, 0.08)
	s.pair("Head", rgb(200, 130, 120), 0.3, 0.6, -0.17, 0.48, 0.85, -0.15)
	s.pair("Head", DARK, 0.56, -0.45, -0.3, 0.78, 0.05, 0.25)
	-- torn flannel shirt with fur showing
	s.box("UpperTorso", FUR, -0.3, -0.15, -0.6, 0.3, 0.56, -0.56)
	for _, y in { -0.35, 0.05, 0.4 } do
		s.ring("UpperTorso", PLAID, y, y + 0.06, 0.58)
	end
	s.box("UpperTorso", PLAID, -0.62, -0.56, -0.6, -0.5, 0.56, 0.6)
	s.box("UpperTorso", PLAID, 0.5, -0.56, -0.6, 0.62, 0.56, 0.6)
	-- ragged sleeve and jean edges, clawed hands and paws
	s.sym("LowerArm", SHIRT, -0.6, 0.25, -0.6, 0.6, 0.6, 0.6)
	s.sym("LowerArm", SHIRT, 0.1, 0.05, -0.6, 0.6, 0.3, 0.1)
	s.sym("LowerLeg", JEANS, -0.6, 0.3, -0.6, 0.6, 0.6, 0.6)
	s.sym("LowerLeg", JEANS, -0.6, 0.05, -0.6, 0.1, 0.35, 0.2)
	s.sym("Hand", WHITE, -0.4, -0.75, -0.3, -0.25, -0.5, -0.1)
	s.sym("Hand", WHITE, -0.07, -0.75, -0.3, 0.08, -0.5, -0.1)
	s.sym("Hand", WHITE, 0.25, -0.75, -0.3, 0.4, -0.5, -0.1)
	s.sym("Foot", DARK, -0.62, -0.55, -0.95, 0.62, 0.56, 0.58)
	s.sym("Foot", WHITE, -0.45, -0.4, -1.02, -0.3, -0.1, -0.95)
	s.sym("Foot", WHITE, -0.07, -0.4, -1.02, 0.08, -0.1, -0.95)
	s.sym("Foot", WHITE, 0.3, -0.4, -1.02, 0.45, -0.1, -0.95)
end

------------------------------------------------------------------------ Grim Reaper
do
	local s = skin("Reaper")
	local ROBE, DARK, BONE, EYE, STAFF, BLADE = rgb(30, 28, 38), rgb(16, 15, 22), rgb(235, 232, 215), rgb(120, 255, 230), rgb(80, 55, 35), rgb(185, 190, 205)
	s.body({ Head = ROBE, UpperTorso = ROBE, LowerTorso = ROBE, UpperArm = ROBE, LowerArm = ROBE, Hand = BONE, UpperLeg = ROBE, LowerLeg = ROBE, Foot = DARK })
	s.box("Head", ROBE, -0.7, -0.62, -0.7, 0.7, 0.78, 0.7)
	s.box("Head", ROBE, -0.25, 0.78, -0.2, 0.25, 0.95, 0.5)
	s.box("Head", BLACK, -0.45, -0.52, -0.72, 0.45, 0.48, -0.7)
	s.pair("Head", EYE, 0.1, 0, -0.73, 0.3, 0.12, -0.72, { mat = NEON, light = EYE })
	s.box("UpperTorso", ROBE, -0.62, -0.62, -0.62, 0.62, 0.62, 0.62)
	s.box("LowerTorso", ROBE, -0.72, -5.4, -0.72, 0.72, 0.5, 0.72)
	for i = 0, 6 do
		local x = -0.72 + i * 0.206
		if i % 2 == 1 then
			s.box("LowerTorso", DARK, x, -5.8, -0.72, x + 0.206, -5.4, 0.72)
		end
	end
	s.ring("LowerTorso", rgb(95, 90, 100), 0, 0.4, 0.74)
	s.sym("LowerArm", ROBE, -0.72, -0.62, -0.72, 0.72, 0.1, 0.72)
	-- scythe
	s.box("RightHand", STAFF, -0.08, -1.4, -0.08, 0.08, 3.6, 0.08, { abs = true })
	s.box("RightHand", BLADE, -0.04, 3.2, -2.2, 0.04, 3.55, 0, { abs = true, mat = METAL })
	s.box("RightHand", BLADE, -0.04, 2.75, -2.45, 0.04, 3.3, -1.9, { abs = true, mat = METAL })
	s.box("RightHand", EYE, -0.045, 3.12, -2.1, 0.045, 3.2, -0.1, { abs = true, mat = NEON })
end

------------------------------------------------------------------------ Mummy
do
	local s = skin("Mummy")
	local BAND, BANDD, EYE = rgb(244, 238, 218), rgb(212, 198, 164), rgb(120, 255, 100)
	s.body({ Head = BAND, UpperTorso = BAND, LowerTorso = BAND, UpperArm = BAND, LowerArm = BAND, Hand = BAND, UpperLeg = BAND, LowerLeg = BAND, Foot = BAND })
	s.ring("Head", BANDD, 0.35, 0.45, 0.6, { rz = 8 })
	s.ring("Head", BANDD, -0.3, -0.2, 0.6, { rz = -6 })
	s.box("Head", BLACK, -0.42, 0.0, -0.62, 0.42, 0.24, -0.6)
	s.box("Head", BAND, -0.44, -0.02, -0.63, -0.04, 0.26, -0.61)
	s.box("Head", EYE, 0.12, 0.05, -0.63, 0.3, 0.2, -0.62, { mat = NEON, light = EYE })
	for i, y in { -0.3, 0.05, 0.38 } do
		s.ring("UpperTorso", BANDD, y, y + 0.08, 0.58, { rz = if i % 2 == 0 then 8 else -8 })
	end
	for _, base in { "UpperArm", "LowerArm", "UpperLeg", "LowerLeg" } do
		s.sym(base, BANDD, -0.6, -0.25, -0.6, 0.6, -0.12, 0.6, { rz = 10 })
		s.sym(base, BANDD, -0.6, 0.2, -0.6, 0.6, 0.33, 0.6, { rz = -8 })
	end
	s.box("LeftLowerArm", BAND, -0.15, -1.6, 0.3, 0.15, -0.4, 0.5)
end

------------------------------------------------------------------------ Frankenstein
do
	local s = skin("Frankenstein")
	local SKIN, SKIND, HAIR, JACKET, SHIRT, PANTS, BOLT, SCAR = rgb(115, 175, 90), rgb(85, 140, 65), rgb(25, 22, 28), rgb(45, 40, 52), rgb(95, 90, 100), rgb(40, 38, 48), rgb(150, 150, 160), rgb(45, 65, 40)
	s.body({ Head = SKIN, UpperTorso = JACKET, LowerTorso = PANTS, UpperArm = JACKET, LowerArm = JACKET, Hand = SKIN, UpperLeg = PANTS, LowerLeg = PANTS, Foot = BLACK })
	s.box("Head", HAIR, -0.62, 0.38, -0.62, 0.62, 0.8, 0.62)
	for i = 0, 5 do
		local x = -0.62 + i * 0.207
		s.box("Head", HAIR, x, if i % 2 == 0 then 0.2 else 0.28, -0.64, x + 0.207, 0.4, -0.58)
	end
	s.box("Head", SKIND, -0.5, 0.12, -0.62, 0.5, 0.2, -0.58)
	s.pair("Head", WHITE, 0.1, -0.08, -0.6, 0.36, 0.1, -0.58)
	s.pair("Head", BLACK, 0.18, -0.07, -0.61, 0.28, 0.05, -0.6)
	s.box("Head", SKIND, -0.08, -0.25, -0.66, 0.08, -0.06, -0.58)
	s.box("Head", SCAR, -0.3, -0.38, -0.6, 0.3, -0.35, -0.58)
	for _, x in { -0.2, 0, 0.2 } do
		s.box("Head", SCAR, x - 0.015, -0.42, -0.61, x + 0.015, -0.31, -0.59)
	end
	s.box("Head", SCAR, -0.45, 0.3, -0.61, -0.05, 0.33, -0.59)
	s.pair("Head", BOLT, 0.56, -0.48, -0.12, 0.85, -0.3, 0.12, { mat = METAL })
	s.pair("Head", BOLT, 0.82, -0.53, -0.18, 0.92, -0.25, 0.18, { mat = METAL })
	-- jacket over a grey shirt, short ragged sleeves, big boots
	s.box("UpperTorso", SHIRT, -0.25, -0.56, -0.6, 0.25, 0.56, -0.56)
	s.box("UpperTorso", rgb(110, 70, 140), 0.3, -0.35, -0.6, 0.48, -0.15, -0.57)
	s.sym("LowerArm", SKIN, -0.56, -0.56, -0.56, 0.56, -0.1, 0.56)
	s.sym("LowerArm", SCAR, -0.3, -0.35, -0.58, 0.3, -0.32, -0.56)
	s.sym("Foot", BLACK, -0.65, -0.55, -0.85, 0.65, 0.9, 0.62)
end

------------------------------------------------------------------------ Red Devil
do
	local s = skin("Devil")
	local RED, DARK, HORN, EYE = rgb(205, 30, 30), rgb(140, 15, 20), rgb(250, 235, 200), rgb(255, 225, 60)
	s.body({ Head = RED, UpperTorso = RED, LowerTorso = RED, UpperArm = RED, LowerArm = RED, Hand = RED, UpperLeg = RED, LowerLeg = RED, Foot = BLACK })
	s.pair("Head", HORN, 0.28, 0.55, -0.12, 0.5, 0.85, 0.12)
	s.pair("Head", HORN, 0.36, 0.85, -0.1, 0.56, 1.1, 0.1)
	s.pair("Head", HORN, 0.45, 1.1, -0.07, 0.6, 1.3, 0.07)
	s.pair("Head", EYE, 0.1, 0.05, -0.61, 0.38, 0.24, -0.58, { mat = NEON })
	s.pair("Head", BLACK, 0.2, 0.06, -0.62, 0.28, 0.23, -0.61)
	s.pair("Head", BLACK, 0.06, 0.28, -0.62, 0.44, 0.35, -0.57, { rz = 18 })
	s.box("Head", BLACK, -0.26, -0.3, -0.6, 0.26, -0.24, -0.58)
	s.pair("Head", BLACK, 0.24, -0.26, -0.6, 0.32, -0.18, -0.58)
	s.pair("Head", WHITE, 0.1, -0.35, -0.61, 0.17, -0.25, -0.59)
	s.box("Head", BLACK, -0.1, -0.68, -0.62, 0.1, -0.42, -0.5)
	s.box("UpperTorso", DARK, -0.35, -0.5, -0.6, 0.35, 0.15, -0.56)
	-- bat wings, tail and pitchfork
	s.pair("UpperTorso", DARK, 0.15, -0.1, 0.56, 1.2, 0.45, 0.62, { abs = true })
	s.pair("UpperTorso", DARK, 0.6, 0.25, 0.56, 1.55, 0.95, 0.62, { abs = true })
	s.pair("UpperTorso", DARK, 1.3, 0.75, 0.56, 1.8, 1.2, 0.62, { abs = true })
	for i, p in { { -0.1, 0.6 }, { -0.3, 0.95 }, { -0.25, 1.3 }, { 0.05, 1.55 }, { 0.4, 1.65 } } do
		s.box("LowerTorso", RED, -0.1, p[1] - 0.1, p[2] - 0.1, 0.1, p[1] + 0.1, p[2] + 0.1, { abs = true })
	end
	s.box("LowerTorso", DARK, -0.06, 0.55, 1.5, 0.06, 0.85, 1.8, { abs = true })
	s.box("LowerTorso", DARK, -0.22, 0.6, 1.55, 0.22, 0.72, 1.75, { abs = true })
	s.box("RightHand", BLACK, -0.06, -1.2, -0.06, 0.06, 3, 0.06, { abs = true, mat = METAL })
	s.box("RightHand", BLACK, -0.06, 3, -0.45, 0.06, 3.12, 0.45, { abs = true, mat = METAL })
	for _, z in { -0.42, -0.06, 0.3 } do
		s.box("RightHand", BLACK, -0.06, 3.12, z, 0.06, 3.6, z + 0.12, { abs = true, mat = METAL })
	end
end

---------------------------------------------------------------------------
-- Extra detail layered on top of each skin's base look
---------------------------------------------------------------------------
do -- Ghost: folds in the sheet, a ragged hem, candy in the bucket
	local s = skin("Ghost")
	local W, G, GD = rgb(245, 245, 252), rgb(212, 215, 232), rgb(190, 194, 215)
	for _, x in { -0.45, -0.05, 0.35 } do
		s.box("LowerTorso", G, x, -3.3, -0.68, x + 0.08, 0.3, -0.66)
		s.box("LowerTorso", G, x, -3.3, 0.66, x + 0.08, 0.3, 0.68)
	end
	s.box("UpperTorso", G, -0.4, -0.55, -0.64, -0.32, 0.45, -0.62)
	s.box("UpperTorso", G, 0.3, -0.55, -0.64, 0.38, 0.4, -0.62)
	for i, d in { 0.3, 0.5, 0.15, 0.45, 0.25, 0.4 } do
		local x = -0.66 + (i - 1) * 0.22
		s.box("LowerTorso", GD, x + 0.03, -4 - d, -0.6, x + 0.19, -3.6, 0.6)
	end
	s.box("Head", G, -0.5, 0.62, -0.5, 0.5, 0.66, 0.5)
	s.box("Head", W, -0.2, 0.78, -0.2, 0.2, 0.86, 0.2)
	s.pair("Head", GD, 0.6, -0.5, -0.4, 0.66, 0.5, 0.4)
	s.sym("LowerArm", GD, 0.45, -1.1, -0.5, 0.68, -0.7, 0.5)
	s.box("RightHand", rgb(255, 120, 200), -0.3, -0.3, -0.25, -0.05, -0.12, 0, { abs = true })
	s.box("RightHand", rgb(120, 220, 255), 0.02, -0.3, -0.15, 0.28, -0.15, 0.1, { abs = true })
	s.box("RightHand", rgb(255, 230, 80), -0.12, -0.32, 0.12, 0.12, -0.1, 0.32, { abs = true })
	s.box("RightHand", rgb(200, 90, 20), -0.44, -1.12, -0.47, 0.44, -1.02, 0.47, { abs = true })
end

do -- Pumpkin Head: ribs, curly vine, bow tie, patched pants, straw at the cuffs, a lantern
	local s = skin("Pumpkin")
	local PD, STRAW, PATCH, VINE, GLOW = rgb(205, 85, 10), rgb(235, 200, 90), rgb(120, 90, 160), rgb(70, 130, 40), rgb(255, 210, 70)
	for _, z in { -0.3, 0.3 } do
		s.box("Head", PD, -0.87, -0.35, z - 0.04, -0.85, 0.75, z + 0.04)
		s.box("Head", PD, 0.85, -0.35, z - 0.04, 0.87, 0.75, z + 0.04)
	end
	s.box("Head", PD, -0.04, -0.35, 0.85, 0.04, 0.75, 0.87)
	s.box("Head", PD, -0.55, 0.98, -0.55, 0.55, 1.02, 0.55)
	s.box("Head", VINE, -0.55, 1.02, -0.05, -0.1, 1.08, 0.05)
	s.box("Head", VINE, -0.6, 1.02, -0.05, -0.5, 1.2, 0.05)
	s.box("Head", VINE, -0.6, 1.15, -0.05, -0.38, 1.22, 0.05)
	s.box("UpperTorso", rgb(140, 20, 30), -0.25, 0.42, -0.66, 0.25, 0.56, -0.6)
	s.box("UpperTorso", rgb(110, 15, 25), -0.06, 0.4, -0.67, 0.06, 0.58, -0.62)
	s.box("UpperTorso", rgb(60, 35, 80), -0.62, -0.5, -0.62, -0.3, 0.45, -0.56)
	s.box("UpperTorso", rgb(60, 35, 80), 0.3, -0.5, -0.62, 0.62, 0.45, -0.56)
	s.box("RightUpperLeg", PATCH, 0.05, -0.2, -0.62, 0.4, 0.2, -0.58)
	s.box("LeftLowerLeg", PATCH, -0.35, 0, -0.62, 0, 0.3, -0.58)
	for _, base in { "LowerArm", "LowerLeg" } do
		for i, x in { -0.4, -0.1, 0.2 } do
			s.sym(base, STRAW, x, -0.85 - i * 0.05, -0.3, x + 0.15, -0.45, -0.1)
		end
	end
	s.box("LeftHand", rgb(60, 50, 55), -0.05, -0.6, -0.05, 0.05, -0.15, 0.05, { abs = true, mat = METAL })
	s.box("LeftHand", rgb(60, 50, 55), -0.3, -1.3, -0.3, 0.3, -1.2, 0.3, { abs = true, mat = METAL })
	s.box("LeftHand", GLOW, -0.22, -1.2, -0.22, 0.22, -0.7, 0.22, { abs = true, mat = NEON, light = rgb(255, 180, 60) })
	s.box("LeftHand", rgb(60, 50, 55), -0.28, -0.7, -0.28, 0.28, -0.6, 0.28, { abs = true, mat = METAL })
end

do -- Witch: belt and buckle, apron, long hair, a wart, a broom
	local s = skin("Witch")
	local HAIR, BROOM, BRISTLE = rgb(25, 20, 30), rgb(110, 70, 35), rgb(220, 180, 80)
	s.ring("LowerTorso", BLACK, -0.2, 0.4, 0.62)
	s.box("LowerTorso", GOLD, -0.2, -0.25, -0.66, 0.2, 0.45, -0.62, { mat = METAL })
	s.box("LowerTorso", rgb(50, 25, 75), -0.1, -0.05, -0.67, 0.1, 0.25, -0.65)
	s.box("LowerTorso", rgb(70, 40, 100), -0.5, -3.5, -0.78, 0.5, -0.3, -0.76)
	for _, y in { -1.2, -2.2, -3.2 } do
		s.box("LowerTorso", rgb(45, 22, 70), -0.76, y, -0.79, 0.76, y + 0.12, 0.79)
	end
	s.pair("Head", HAIR, 0.45, -1.6, 0.1, 0.65, -0.7, 0.6)
	s.box("Head", HAIR, -0.6, -1.7, 0.4, 0.6, -0.7, 0.65)
	s.box("Head", rgb(80, 130, 55), 0.25, -0.12, -0.62, 0.33, -0.04, -0.59)
	s.box("Head", rgb(110, 60, 150), -0.55, 0.85, -0.6, -0.15, 0.9, -0.55, { mat = NEON })
	s.sym("UpperArm", rgb(60, 32, 90), -0.62, 0.3, -0.62, 0.62, 0.62, 0.62)
	s.sym("Foot", BLACK, -0.15, 0.6, -1.4, 0.15, 0.95, -1.15)
	s.box("LeftHand", BROOM, -0.07, -2.8, -0.07, 0.07, 1.6, 0.07, { abs = true })
	s.box("LeftHand", BRISTLE, -0.3, -3.6, -0.3, 0.3, -2.7, 0.3, { abs = true })
	s.box("LeftHand", rgb(180, 140, 60), -0.32, -2.85, -0.32, 0.32, -2.7, 0.32, { abs = true })
	s.box("LeftHand", ORANGE, -0.33, -2.75, -0.33, 0.33, -2.68, 0.33, { abs = true })
end

do -- Vampire: red vest, buttons, cuffs with cufflinks, slicked hair, shiny shoes
	local s = skin("Vampire")
	local RED, DRED, SUIT = rgb(170, 10, 30), rgb(110, 5, 20), rgb(28, 22, 34)
	s.box("UpperTorso", DRED, -0.42, -0.56, -0.6, -0.22, 0.25, -0.565)
	s.box("UpperTorso", DRED, 0.22, -0.56, -0.6, 0.42, 0.25, -0.565)
	for _, y in { -0.35, -0.1, 0.15 } do
		s.box("UpperTorso", GOLD, -0.04, y, -0.62, 0.04, y + 0.07, -0.6, { mat = METAL })
	end
	s.pair("UpperTorso", SUIT, 0.2, 0.0, -0.64, 0.5, 0.56, -0.6, { rz = -18 })
	s.box("UpperTorso", GOLD, -0.05, -0.18, -0.64, 0.05, 0.3, -0.62, { mat = METAL })
	s.sym("LowerArm", WHITE, -0.6, -0.62, -0.6, 0.6, -0.42, 0.6)
	s.sym("LowerArm", RED, -0.1, -0.56, -0.64, 0.1, -0.46, -0.6, { mat = NEON })
	s.box("Head", rgb(40, 30, 50), -0.6, 0.55, -0.6, 0.6, 0.6, 0.6)
	s.pair("Head", PINK, 0.38, -0.2, -0.6, 0.5, -0.12, -0.585)
	s.sym("Foot", rgb(70, 70, 80), -0.3, 0.3, -0.62, 0.3, 0.4, -0.59)
	s.box("UpperTorso", RED, -0.5, -1.55, 0.53, 0.5, -1.45, 0.55)
end

do -- Skeleton: collarbones, joints, kneecaps, finger and toe bones, a glowing heart
	local s = skin("Skeleton")
	local BONE, BONED, GLOW = rgb(238, 235, 218), rgb(200, 195, 175), rgb(60, 255, 90)
	s.pair("UpperTorso", BONE, 0.05, 0.42, -0.6, 0.5, 0.5, -0.56, { rz = 10 })
	s.pair("UpperTorso", BONE, 0.5, 0.3, -0.6, 0.6, 0.5, 0.6)
	s.box("UpperTorso", GLOW, 0.1, 0.1, -0.61, 0.25, 0.25, -0.59, { mat = NEON, light = GLOW })
	s.box("LowerTorso", BONED, -0.3, -0.45, -0.6, 0.3, -0.3, -0.56)
	for _, base in { "UpperArm", "UpperLeg" } do
		s.sym(base, BONED, -0.2, -0.55, -0.62, 0.2, -0.38, -0.57)
	end
	s.sym("LowerLeg", BONE, -0.25, 0.3, -0.63, 0.25, 0.5, -0.58)
	for _, x in { -0.32, -0.08, 0.16 } do
		s.sym("Hand", BONE, x, -1.1, -0.15, x + 0.12, -0.5, 0.1)
	end
	for _, x in { -0.35, -0.05, 0.25 } do
		s.sym("Foot", BONE, x, 0.0, -0.62, x + 0.1, 0.3, -0.57)
	end
	s.box("Head", BONED, -0.5, -0.6, -0.5, 0.5, -0.5, 0.5)
	s.pair("Head", BONED, 0.35, -0.3, -0.6, 0.5, -0.15, -0.585)
end

do -- Werewolf: fur tufts, chest fur, a bushy tail, torn holes, toe claws
	local s = skin("Werewolf")
	local FUR, DARK, LIGHT = rgb(110, 78, 55), rgb(78, 55, 40), rgb(150, 115, 85)
	s.pair("UpperTorso", FUR, 0.55, 0.35, -0.4, 0.75, 0.62, 0.4)
	s.pair("UpperTorso", DARK, 0.6, 0.55, -0.3, 0.8, 0.75, 0.3)
	s.box("UpperTorso", LIGHT, -0.2, 0.1, -0.62, 0.2, 0.5, -0.6)
	s.box("UpperTorso", FUR, 0.2, -0.45, -0.61, 0.38, -0.25, -0.59)
	s.box("UpperTorso", FUR, -0.4, -0.3, 0.59, -0.15, 0.0, 0.61)
	s.sym("UpperArm", DARK, 0.5, -0.2, -0.3, 0.7, 0.2, 0.3)
	s.box("Head", DARK, -0.55, 0.55, -0.4, 0.55, 0.7, 0.4)
	s.box("Head", DARK, -0.3, 0.65, -0.3, 0.3, 0.8, 0.3)
	for i, p in { { 0.4, 0.7 }, { 0.25, 1.0 }, { 0.2, 1.3 }, { 0.35, 1.55 } } do
		s.box("LowerTorso", if i == 4 then LIGHT else FUR, -0.22, p[1] - 0.22, p[2] - 0.2, 0.22, p[1] + 0.22, p[2] + 0.2, { abs = true })
	end
	s.sym("Foot", WHITE, -0.42, -0.6, -1.05, -0.32, -0.35, -0.98)
	s.sym("Foot", WHITE, 0.32, -0.6, -1.05, 0.42, -0.35, -0.98)
	s.box("Head", rgb(200, 30, 40), -0.2, -0.45, -0.99, 0.2, -0.4, -0.97)
end

do -- Grim Reaper: a skull face in the hood, hood rim, robe folds, skull belt buckle, chain, lantern
	local s = skin("Reaper")
	local ROBE, DARK, BONE, EYE, CHAIN = rgb(30, 28, 38), rgb(16, 15, 22), rgb(235, 232, 215), rgb(120, 255, 230), rgb(120, 120, 130)
	s.box("Head", BONE, -0.3, -0.4, -0.71, 0.3, 0.3, -0.705)
	s.pair("Head", BLACK, 0.06, -0.05, -0.715, 0.24, 0.18, -0.71)
	s.pair("Head", EYE, 0.11, 0.02, -0.72, 0.19, 0.1, -0.715, { mat = NEON })
	s.box("Head", BLACK, -0.04, -0.15, -0.715, 0.04, -0.07, -0.71)
	s.box("Head", WHITE, -0.18, -0.36, -0.715, 0.18, -0.24, -0.712)
	s.box("Head", rgb(45, 42, 55), -0.72, 0.5, -0.74, 0.72, 0.8, -0.7)
	s.pair("Head", rgb(45, 42, 55), 0.45, -0.6, -0.74, 0.72, 0.8, -0.7)
	for _, x in { -0.5, -0.15, 0.2, 0.5 } do
		s.box("LowerTorso", DARK, x, -5.3, -0.74, x + 0.08, -0.2, -0.72)
		s.box("LowerTorso", DARK, x, -5.3, 0.72, x + 0.08, -0.2, 0.74)
	end
	s.box("LowerTorso", BONE, -0.15, -0.05, -0.77, 0.15, 0.45, -0.74)
	s.box("LowerTorso", BLACK, -0.1, 0.15, -0.78, -0.02, 0.27, -0.77)
	s.box("LowerTorso", BLACK, 0.02, 0.15, -0.78, 0.1, 0.27, -0.77)
	for i = 0, 5 do
		s.box("UpperTorso", CHAIN, -0.55 + i * 0.2, 0.4 - i * 0.18, -0.65, -0.45 + i * 0.2, 0.5 - i * 0.18, -0.63, { mat = METAL })
	end
	s.sym("LowerArm", DARK, -0.72, -0.9, -0.72, 0.72, -0.62, 0.72)
	s.box("LeftHand", CHAIN, -0.04, -0.7, -0.04, 0.04, -0.15, 0.04, { abs = true, mat = METAL })
	s.box("LeftHand", DARK, -0.28, -1.5, -0.28, 0.28, -1.4, 0.28, { abs = true })
	s.box("LeftHand", EYE, -0.2, -1.4, -0.2, 0.2, -0.85, 0.2, { abs = true, mat = NEON, light = EYE })
	s.box("LeftHand", DARK, -0.28, -0.85, -0.28, 0.28, -0.7, 0.28, { abs = true })
end

do -- Mummy: many crossing bandages, darker stains, hanging ends, a scarab amulet
	local s = skin("Mummy")
	local BAND, BANDD, STAIN = rgb(244, 238, 218), rgb(212, 198, 164), rgb(180, 165, 125)
	for i, y in { -0.45, -0.15, 0.2, 0.45 } do
		s.ring("UpperTorso", if i % 2 == 0 then BANDD else STAIN, y, y + 0.07, 0.59, { rz = if i % 2 == 0 then -14 else 12 })
	end
	s.ring("LowerTorso", BANDD, -0.2, 0.15, 0.6, { rz = 6 })
	s.ring("Head", STAIN, 0.05, 0.12, 0.61, { rz = -12 })
	s.ring("Head", BANDD, 0.5, 0.58, 0.61, { rz = -4 })
	for _, base in { "UpperArm", "LowerArm", "UpperLeg", "LowerLeg" } do
		s.sym(base, STAIN, -0.61, 0.0, -0.61, 0.61, 0.08, 0.61, { rz = -14 })
	end
	s.box("RightLowerArm", BAND, 0.2, -1.4, -0.3, 0.45, -0.45, -0.15)
	s.box("LowerTorso", BAND, 0.25, -1.3, 0.55, 0.5, -0.1, 0.65)
	s.box("UpperTorso", rgb(40, 140, 150), -0.15, 0.1, -0.64, 0.15, 0.35, -0.6, { mat = METAL })
	s.box("UpperTorso", GOLD, -0.2, 0.33, -0.63, 0.2, 0.38, -0.6, { mat = METAL })
	s.box("Head", rgb(40, 30, 25), -0.2, -0.38, -0.62, 0.2, -0.32, -0.6)
end

do -- Frankenstein: lapels, buttons, collar, stitches on arms and neck, belt, patched pants
	local s = skin("Frankenstein")
	local JACKET, LAPEL, SCAR, BOLT = rgb(45, 40, 52), rgb(30, 26, 36), rgb(45, 65, 40), rgb(150, 150, 160)
	s.pair("UpperTorso", LAPEL, 0.2, -0.1, -0.64, 0.48, 0.56, -0.6, { rz = -16 })
	for _, y in { -0.35, -0.05 } do
		s.box("UpperTorso", rgb(140, 120, 90), 0.27, y, -0.62, 0.35, y + 0.08, -0.6)
	end
	s.box("UpperTorso", rgb(170, 165, 175), -0.25, 0.45, -0.62, 0.25, 0.58, -0.58)
	s.box("Head", SCAR, -0.55, -0.62, -0.62, 0.55, -0.58, -0.58)
	for _, x in { -0.4, -0.15, 0.1, 0.35 } do
		s.box("Head", SCAR, x - 0.015, -0.66, -0.63, x + 0.015, -0.54, -0.58)
	end
	s.sym("LowerArm", SCAR, -0.58, 0.05, -0.58, 0.58, 0.09, 0.58)
	s.ring("LowerTorso", rgb(70, 50, 30), -0.2, 0.3, 0.6)
	s.box("LowerTorso", BOLT, -0.15, -0.15, -0.64, 0.15, 0.35, -0.6, { mat = METAL })
	s.box("RightUpperLeg", rgb(90, 60, 110), -0.3, -0.3, -0.62, 0.15, 0.15, -0.58)
	s.box("LeftLowerLeg", rgb(70, 90, 60), 0, 0, -0.62, 0.35, 0.35, -0.58)
	s.pair("Head", BOLT, 0.9, -0.48, -0.08, 1.05, -0.32, 0.08, { mat = METAL })
	s.sym("Foot", rgb(60, 55, 60), -0.66, 0.8, -0.86, 0.66, 0.95, 0.63)
end

do -- Red Devil: bigger wings with ribs, gold cuffs and belt, chest markings, a red-and-gold pitchfork
	local s = skin("Devil")
	local RED, DARK, GOLDC, HORN = rgb(205, 30, 30), rgb(140, 15, 20), rgb(255, 196, 60), rgb(250, 235, 200)
	s.pair("UpperTorso", DARK, 0.3, 0.2, 0.58, 2.2, 1.3, 0.64, { abs = true })
	s.pair("UpperTorso", DARK, 1.2, 0.9, 0.58, 2.6, 2.0, 0.64, { abs = true })
	s.pair("UpperTorso", DARK, 2.2, 1.6, 0.58, 2.9, 2.5, 0.64, { abs = true })
	s.pair("UpperTorso", BLACK, 0.4, 0.9, 0.56, 2.7, 1.0, 0.66, { abs = true, rz = 20 })
	s.pair("UpperTorso", BLACK, 0.4, 0.5, 0.56, 2.2, 0.6, 0.66, { abs = true, rz = 5 })
	s.sym("LowerArm", GOLDC, -0.6, -0.6, -0.6, 0.6, -0.4, 0.6, { mat = METAL })
	s.ring("LowerTorso", BLACK, -0.3, 0.3, 0.6)
	s.box("LowerTorso", GOLDC, -0.18, -0.25, -0.64, 0.18, 0.35, -0.6, { mat = METAL })
	s.pair("UpperTorso", DARK, 0.15, 0.1, -0.61, 0.45, 0.4, -0.58, { rz = 20 })
	s.pair("Head", HORN, 0.5, 1.25, -0.04, 0.62, 1.4, 0.04)
	s.sym("Foot", rgb(60, 50, 50), -0.05, -0.55, -0.62, 0.05, 0.3, -0.57)
	s.box("RightHand", RED, -0.09, -1.2, -0.09, 0.09, 3, 0.09, { abs = true })
	s.box("RightHand", GOLDC, -0.1, 2.9, -0.55, 0.1, 3.1, 0.55, { abs = true, mat = METAL })
	for _, z in { -0.5, -0.06, 0.38 } do
		s.box("RightHand", GOLDC, -0.08, 3.1, z, 0.08, 3.7, z + 0.14, { abs = true, mat = METAL })
		s.box("RightHand", GOLDC, -0.05, 3.7, z + 0.02, 0.05, 3.9, z + 0.12, { abs = true, mat = METAL })
	end
	for i, p in { { 0.75, 1.75 }, { 1.05, 1.85 } } do
		s.box("LowerTorso", RED, -0.09, p[1] - 0.09, p[2] - 0.09, 0.09, p[1] + 0.09, p[2] + 0.09, { abs = true })
	end
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------
-- R6 has one part per arm, leg and torso: each R15 piece is fitted onto its share of it (y offset, y scale).
local R6 = {
	UpperTorso = { "Torso", 0.25, 0.5 },
	LowerTorso = { "Torso", -0.3, 0.4 },
}
for _, side in { "Left", "Right" } do
	R6[side .. "UpperArm"] = { side .. " Arm", 1 / 3, 1 / 3 }
	R6[side .. "LowerArm"] = { side .. " Arm", 0, 1 / 3 }
	R6[side .. "Hand"] = { side .. " Arm", -0.42, 0.16 }
	R6[side .. "UpperLeg"] = { side .. " Leg", 1 / 3, 1 / 3 }
	R6[side .. "LowerLeg"] = { side .. " Leg", 0, 1 / 3 }
	R6[side .. "Foot"] = { side .. " Leg", -0.42, 0.16 }
end

function Skins.Has(id: string): boolean
	return DEFS[id] ~= nil
end

-- Builds the skin on `target` (a character, or any model with body parts named like R15) and returns it as a
-- model. The pieces are welded to the body parts, or anchored where they are when `anchored` is set.
function Skins.Build(target: Model, id: string, anchored: boolean?): Model?
	local def = DEFS[id]
	if not def then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "CostumeArt"
	for _, e in def do
		local segName, color, x0, y0, z0, x1, y1, z1, opt = e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8], e[9]
		local seg = target:FindFirstChild(segName)
		local yOffset, yScale = 0, 1
		if not (seg and seg:IsA("BasePart")) then
			local map = R6[segName]
			seg = map and target:FindFirstChild(map[1])
			if not (seg and seg:IsA("BasePart")) then
				continue
			end
			yOffset, yScale = map[2], map[3]
		end
		local size, center
		if opt.abs then
			size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
			center = Vector3.new(x0 + x1, y0 + y1, z0 + z1) / 2
		else
			local s = Vector3.new(seg.Size.X, seg.Size.Y * yScale, seg.Size.Z)
			size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)) * s
			center = Vector3.new(x0 + x1, y0 + y1, z0 + z1) / 2 * s + Vector3.new(0, yOffset * seg.Size.Y, 0)
		end
		local p = Instance.new("Part")
		p.Name = segName
		p.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
		p.CFrame = seg.CFrame * CFrame.new(center) * CFrame.Angles(0, 0, math.rad(opt.rz or 0))
		p.Color = color
		p.Material = opt.mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		if anchored then
			p.Anchored = true
		else
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = seg
			weld.Part1 = p
			weld.Parent = p
		end
		if opt.light then
			local light = Instance.new("PointLight")
			light.Color = opt.light
			light.Range = 8
			light.Brightness = 1.2
			light.Parent = p
		end
		p.Parent = model
	end
	return model
end

-- A plain standing R15-sized body (anchored, invisible) to dress as a shop mannequin. Its feet stand on `cf`,
-- facing cf.LookVector.
function Skins.MakeRig(cf: CFrame): Model
	local rig = Instance.new("Model")
	rig.Name = "SkinRig"
	local function seg(name: string, size: Vector3, pos: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf * CFrame.new(pos)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Parent = rig
	end
	seg("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 5.31, 0))
	seg("UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 3.91, 0))
	seg("LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, 2.91, 0))
	for _, side in { { "Left", -1 }, { "Right", 1 } } do
		local n, s = side[1], side[2]
		seg(n .. "UpperArm", Vector3.new(1, 1.17, 1), Vector3.new(1.5 * s, 4.12, 0))
		seg(n .. "LowerArm", Vector3.new(1, 1.05, 1), Vector3.new(1.5 * s, 3.01, 0))
		seg(n .. "Hand", Vector3.new(1, 0.3, 1), Vector3.new(1.5 * s, 2.34, 0))
		seg(n .. "UpperLeg", Vector3.new(1, 1.22, 1), Vector3.new(0.5 * s, 2.1, 0))
		seg(n .. "LowerLeg", Vector3.new(1, 1.19, 1), Vector3.new(0.5 * s, 0.9, 0))
		seg(n .. "Foot", Vector3.new(1, 0.3, 1), Vector3.new(0.5 * s, 0.15, 0))
	end
	rig.WorldPivot = cf
	return rig
end

return Skins
