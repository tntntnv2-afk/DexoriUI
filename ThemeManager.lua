local HttpService = game:GetService("HttpService")

local ThemeManager = {}
ThemeManager.Folder = "DexoriUI"
ThemeManager.Library = nil
ThemeManager.BuiltIn = {
	["Frostbite"] = { Background = "070a10", Main = "0b0f17", Element = "111722", ElementHover = "18202e", Accent = "60b2ff", AccentGradient = { "96d6ff", "2260be", 0 }, Outline = "1c2636", OutlineStrong = "2e568c", Font = "e2ebf5", FontDim = "7889a0", Risky = "ff6060" },
	["Dexori Red"] = { Background = "0a0a0b", Main = "0f0f11", Element = "161619", ElementHover = "1e1e22", Accent = "c81e1e", AccentGradient = { "eb2d2d", "6e0808", 0 }, Outline = "242428", OutlineStrong = "461212", Font = "e6e6e8", FontDim = "808088", Risky = "ff5050" },
	["Nightshade"] = { Background = "0b0810", Main = "100c18", Element = "171124", ElementHover = "1f1830", Accent = "9b59ff", AccentGradient = { "c08cff", "5e2bd6", 0 }, Outline = "231a33", OutlineStrong = "42288c", Font = "ece6f8", FontDim = "8b7fa8", Risky = "ff6b6b" },
	["Pine"] = { Background = "07100c", Main = "0b1712", Element = "10201a", ElementHover = "172c24", Accent = "34d399", AccentGradient = { "6ee7b7", "0f9268", 0 }, Outline = "173028", OutlineStrong = "1d6b4c", Font = "e4f3ec", FontDim = "76998a", Risky = "ff6b6b" },
	["Carbon"] = { Background = "09090a", Main = "0e0e10", Element = "141416", ElementHover = "1c1c20", Accent = "d8d8dc", AccentGradient = { "ffffff", "8c8c94", 0 }, Outline = "1f1f23", OutlineStrong = "3a3a42", Font = "f2f2f4", FontDim = "83838c", Risky = "ff5050" },
	["Ember"] = { Background = "100b07", Main = "17100a", Element = "20170f", ElementHover = "2c2016", Accent = "ff8a3d", AccentGradient = { "ffb066", "cc5a10", 0 }, Outline = "2e2114", OutlineStrong = "7a4416", Font = "f6ece2", FontDim = "a08a76", Risky = "ff6060" },
}

local function hexToColor(h)
	h = tostring(h):gsub("#", "")
	return Color3.fromRGB(tonumber(h:sub(1, 2), 16) or 0, tonumber(h:sub(3, 4), 16) or 0, tonumber(h:sub(5, 6), 16) or 0)
end
local function colorToHex(c)
	return string.format("%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

function ThemeManager:SetLibrary(lib) self.Library = lib end
function ThemeManager:SetFolder(folder) self.Folder = folder self:BuildFolderTree() end
function ThemeManager:BuildFolderTree()
	pcall(function()
		if not isfolder(self.Folder) then makefolder(self.Folder) end
		if not isfolder(self.Folder .. "/themes") then makefolder(self.Folder .. "/themes") end
	end)
end

function ThemeManager:Serialize()
	local T = self.Library.Theme
	local out = {}
	for k, v in pairs(T) do
		if typeof(v) == "Color3" then out[k] = colorToHex(v)
		elseif typeof(v) == "ColorSequence" then
			local kp = v.Keypoints
			out[k] = { colorToHex(kp[1].Value), colorToHex(kp[#kp].Value), self._accentRotation or 0 }
		end
	end
	return out
end
function ThemeManager:ApplyData(data)
	local theme = {}
	for k, v in pairs(data) do
		if type(v) == "string" then theme[k] = hexToColor(v)
		elseif type(v) == "table" then
			theme[k] = ColorSequence.new(hexToColor(v[1]), hexToColor(v[2]))
			self._accentRotation = v[3] or 0
		end
	end
	self.Library:SetTheme(theme)
	if self._pickers then
		for k, p in pairs(self._pickers) do
			if theme[k] and typeof(theme[k]) == "Color3" then p:SetValueRGB(theme[k], nil, true)
			elseif theme[k] and typeof(theme[k]) == "ColorSequence" then
				p:SetValueRGB(theme[k].Keypoints[1].Value, nil, true); p:SetValue2(theme[k].Keypoints[#theme[k].Keypoints].Value, true); p:SetRotation(self._accentRotation or 0, true)
			end
		end
	end
end

function ThemeManager:ApplyTheme(name)
	local data = self.BuiltIn[name]
	if not data then
		local ok, raw = pcall(readfile, self.Folder .. "/themes/" .. name .. ".json")
		if ok and raw then local ok2, d = pcall(HttpService.JSONDecode, HttpService, raw) if ok2 then data = d end end
	end
	if data then self:ApplyData(data) self.Library:Notify({ Title = "Theme", Description = "Applied " .. name, Time = 3 }) end
end
function ThemeManager:SaveTheme(name)
	if not name or name == "" then return end
	self:BuildFolderTree()
	pcall(writefile, self.Folder .. "/themes/" .. name .. ".json", HttpService:JSONEncode(self:Serialize()))
	self.Library:Notify({ Title = "Theme", Description = "Saved " .. name, Time = 3 })
end
function ThemeManager:DeleteTheme(name)
	if not name or self.BuiltIn[name] then return false end
	pcall(delfile, self.Folder .. "/themes/" .. name .. ".json")
	self.Library:Notify({ Title = "Theme", Description = "Deleted " .. name, Time = 3 })
	return true
end
function ThemeManager:ListThemes()
	local out = {}
	for k in pairs(self.BuiltIn) do out[#out + 1] = k end
	table.sort(out)
	pcall(function()
		for _, f in ipairs(listfiles(self.Folder .. "/themes")) do
			local name = f:match("([^/\\]+)%.json$")
			if name then out[#out + 1] = name end
		end
	end)
	return out
end
function ThemeManager:SetDefaultTheme(name)
	pcall(writefile, self.Folder .. "/themes/default.txt", name)
end
function ThemeManager:LoadDefault()
	local ok, name = pcall(readfile, self.Folder .. "/themes/default.txt")
	if ok and name and name ~= "" then self:ApplyTheme(name) end
end

function ThemeManager:ApplyToTab(tab)
	local Library = self.Library
	self:BuildFolderTree()
	local gb = tab:AddLeftGroupbox("Theme")
	self._pickers = {}
	local keys = { { "Background", "Background" }, { "Main", "Panels" }, { "Element", "Elements" }, { "ElementHover", "Element hover" }, { "Accent", "Accent" }, { "Outline", "Outline" }, { "OutlineStrong", "Strong outline" }, { "Font", "Text" }, { "FontDim", "Dim text" } }
	for _, pair in ipairs(keys) do
		local key, label = pair[1], pair[2]
		local p = gb:AddColorPicker("Theme_" .. key, { Text = label, Default = Library.Theme[key], Callback = function(c) Library.Theme[key] = c Library:UpdateColorsUsingRegistry() end })
		self._pickers[key] = p
	end
	local accKp = Library.Theme.AccentGradient.Keypoints
	local gp = gb:AddColorPicker("Theme_AccentGradient", { Text = "Accent gradient", Gradient = true, Default = accKp[1].Value, Default2 = accKp[#accKp].Value, Rotation = 0, Callback = function(seq, rot)
		Library.Theme.AccentGradient = seq
		self._accentRotation = rot
		Library:UpdateColorsUsingRegistry()
		for inst, props in pairs(Library.Registry) do
			if props.Color == "AccentGradient" and inst:IsA("UIGradient") then inst.Rotation = rot end
		end
	end })
	self._pickers.AccentGradient = gp

	local gb2 = tab:AddRightGroupbox("Theme Manager")
	local list = gb2:AddDropdown("ThemeManager_List", { Text = "Themes", Values = self:ListThemes(), Default = 1, Searchable = true })
	local nameBox = gb2:AddInput("ThemeManager_Name", { Text = "Theme name", Placeholder = "my theme", Finished = true })
	gb2:AddButton({ Text = "Load", Func = function() if list.Value then self:ApplyTheme(list.Value) end end })
		:AddButton({ Text = "Set default", Func = function() if list.Value then self:SetDefaultTheme(list.Value) Library:Notify({ Title = "Theme", Description = "Default: " .. list.Value, Time = 3 }) end end })
	gb2:AddButton({ Text = "Save as", Func = function() self:SaveTheme(nameBox.Value) list:SetValues(self:ListThemes()) end })
		:AddButton({ Text = "Delete", Risky = true, DoubleClick = true, Func = function() if list.Value and self:DeleteTheme(list.Value) then list:SetValues(self:ListThemes()) end end })
	gb2:AddButton({ Text = "Reset to Frostbite", Func = function() self:ApplyTheme("Frostbite") end })
	gb2:AddButton({ Text = "Refresh list", Func = function() list:SetValues(self:ListThemes()) end })
	self:LoadDefault()
end

return ThemeManager
