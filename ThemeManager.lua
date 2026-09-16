local HttpService = game:GetService("HttpService")

local ThemeManager = {}
ThemeManager.Folder = "DexoriUI"
ThemeManager.Library = nil
ThemeManager.BuiltIn = {
	["Dexori Red"] = { Background = "0c0c0c", Main = "131313", Element = "1a1a1a", ElementHover = "222222", Accent = "c81e1e", AccentGradient = { "e62828", "780a0a", 0 }, Outline = "262626", OutlineStrong = "3c1212", Font = "f0f0f0", FontDim = "96969b", Risky = "ff5050" },
	["Midnight"] = { Background = "0b0d14", Main = "10131c", Element = "171b27", ElementHover = "1f2433", Accent = "4f7cff", AccentGradient = { "6b8fff", "2b4fd6", 0 }, Outline = "222838", OutlineStrong = "2c3a66", Font = "eef0f6", FontDim = "8b91a3", Risky = "ff6b6b" },
	["Emerald"] = { Background = "0a0f0c", Main = "0f1612", Element = "151f19", ElementHover = "1c2922", Accent = "2ecc71", AccentGradient = { "3ddc84", "1a8f4c", 0 }, Outline = "1f2b25", OutlineStrong = "1f4a33", Font = "ecf5ef", FontDim = "8aa091", Risky = "ff6b6b" },
	["Mono"] = { Background = "0a0a0a", Main = "111111", Element = "181818", ElementHover = "202020", Accent = "e8e8e8", AccentGradient = { "ffffff", "9a9a9a", 0 }, Outline = "242424", OutlineStrong = "3a3a3a", Font = "f5f5f5", FontDim = "8f8f8f", Risky = "ff5050" },
	["Amethyst"] = { Background = "0d0a14", Main = "130f1c", Element = "1a1527", ElementHover = "231c33", Accent = "9b59ff", AccentGradient = { "b07cff", "5e2bd6", 0 }, Outline = "27203a", OutlineStrong = "3e2c66", Font = "f1ecf8", FontDim = "9a8fb0", Risky = "ff6b6b" },
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
	gb2:AddButton({ Text = "Reset to Dexori Red", Func = function() self:ApplyTheme("Dexori Red") end })
	gb2:AddButton({ Text = "Refresh list", Func = function() list:SetValues(self:ListThemes()) end })
	self:LoadDefault()
end

return ThemeManager
