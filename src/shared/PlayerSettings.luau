-- Shared preference schema. Only cosmetic/audio preferences belong here.
local Settings = {}
Settings.Defaults = { MusicVolume = 1, SfxVolume = 1, ShowGains = true, EventEffects = true }
function Settings.Normalize(value)
	local result = table.clone(Settings.Defaults)
	if type(value) ~= "table" then return result end
	for key, default in Settings.Defaults do
		local v = value[key]
		if type(default) == "number" then
			if type(v) == "number" and v == v and math.abs(v) < math.huge then
				result[key] = math.floor(math.clamp(v, 0, 1) * 100 + 0.5) / 100
			end
		elseif type(v) == "boolean" then result[key] = v end
	end
	return result
end
function Settings.Validate(value)
	if type(value) ~= "table" then return false end
	for key, default in Settings.Defaults do
		local v = value[key]
		if type(default) == "number" then
			if type(v) ~= "number" or v ~= v or v < 0 or v > 1 then return false end
		elseif type(v) ~= "boolean" then return false end
	end
	for key in value do if Settings.Defaults[key] == nil then return false end end
	return true
end
return Settings