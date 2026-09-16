local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local SaveManager = {}
SaveManager.Folder = "DexoriUI"
SaveManager.Ignore = {}
SaveManager.Library = nil
SaveManager.AutoSave = true
SaveManager.AutoSaveInterval = 30
SaveManager.Parser = {
	Toggle = {
		Save = function(idx, obj) return { type = "Toggle", idx = idx, value = obj.Value } end,
		Load = function(idx, data) local o = SaveManager.Library.Toggles[idx] if o then o:SetValue(data.value) end end,
	},
	Slider = {
		Save = function(idx, obj) return { type = "Slider", idx = idx, value = obj.Value } end,
		Load = function(idx, data) local o = SaveManager.Library.Options[idx] if o then o:SetValue(data.value) end end,
	},
	Dropdown = {
		Save = function(idx, obj) return { type = "Dropdown", idx = idx, value = obj.Value, multi = obj.Multi } end,
		Load = function(idx, data) local o = SaveManager.Library.Options[idx] if o then o:SetValue(data.value) end end,
	},
	ColorPicker = {
		Save = function(idx, obj) return { type = "ColorPicker", idx = idx, value = obj.Value:ToHex(), value2 = obj.Value2 and obj.Value2:ToHex() or nil, transparency = obj.Transparency, rotation = obj.Rotation } end,
		Load = function(idx, data)
			local o = SaveManager.Library.Options[idx]
			if o then
				o:SetValueRGB(Color3.fromHex(data.value), data.transparency, true)
				if data.value2 and o.SetValue2 then o:SetValue2(Color3.fromHex(data.value2), true) end
				if data.rotation and o.SetRotation then o:SetRotation(data.rotation, true) end
				if o.Callback then pcall(o.Callback, o.Gradient and o:GetSequence() or o.Value, o.Gradient and o.Rotation or o.Transparency) end
			end
		end,
	},
	KeyPicker = {
		Save = function(idx, obj) return { type = "KeyPicker", idx = idx, mode = obj.Mode, key = typeof(obj.Value) == "EnumItem" and obj.Value.Name or tostring(obj.Value) } end,
		Load = function(idx, data) local o = SaveManager.Library.Options[idx] if o then o:SetValue({ data.key, data.mode }) end end,
	},
	Input = {
		Save = function(idx, obj) return { type = "Input", idx = idx, text = obj.Value } end,
		Load = function(idx, data) local o = SaveManager.Library.Options[idx] if o then o:SetValue(data.text) end end,
	},
}

function SaveManager:SetLibrary(lib) self.Library = lib end
function SaveManager:SetIgnoreIndexes(list) for _, k in ipairs(list) do self.Ignore[k] = true end end
function SaveManager:IgnoreThemeSettings()
	self:SetIgnoreIndexes({ "ThemeManager_List", "ThemeManager_Name", "SaveManager_ConfigList", "SaveManager_ConfigName" })
	self._ignoreThemePrefix = true
end
function SaveManager:SetFolder(folder) self.Folder = folder self:BuildFolderTree() end
function SaveManager:BuildFolderTree()
	pcall(function()
		local parts = {}
		for seg in string.gmatch(self.Folder, "[^/\\]+") do
			parts[#parts + 1] = seg
			local p = table.concat(parts, "/")
			if not isfolder(p) then makefolder(p) end
		end
		if not isfolder(self.Folder .. "/settings") then makefolder(self.Folder .. "/settings") end
	end)
end
function SaveManager:_path(name) return self.Folder .. "/settings/" .. name .. ".json" end

function SaveManager:Save(name)
	if not name or name == "" then return false, "no config name" end
	self:BuildFolderTree()
	local data = { objects = {} }
	for idx, obj in pairs(self.Library.Toggles) do
		if not self.Ignore[idx] then data.objects[#data.objects + 1] = self.Parser.Toggle.Save(idx, obj) end
	end
	for idx, obj in pairs(self.Library.Options) do
		if not self.Ignore[idx] and not (self._ignoreThemePrefix and string.sub(idx, 1, 6) == "Theme_") then
			local p = self.Parser[obj.Type]
			if p then data.objects[#data.objects + 1] = p.Save(idx, obj) end
		end
	end
	local ok, enc = pcall(HttpService.JSONEncode, HttpService, data)
	if not ok then return false, "encode failed" end
	local ok2 = pcall(writefile, self:_path(name), enc)
	if not ok2 then return false, "write failed" end
	return true
end

function SaveManager:Load(name)
	if not name or name == "" then return false, "no config name" end
	local ok, raw = pcall(readfile, self:_path(name))
	if not ok or not raw then return false, "config not found" end
	local ok2, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok2 or type(data) ~= "table" then return false, "decode failed" end
	for _, entry in ipairs(data.objects or {}) do
		local p = self.Parser[entry.type]
		if p then pcall(p.Load, entry.idx, entry) end
	end
	self._current = name
	return true
end

function SaveManager:Delete(name)
	if not name or name == "" then return false end
	local ok = pcall(delfile, self:_path(name))
	if self._current == name then self._current = nil end
	return ok
end

function SaveManager:ListConfigs()
	local out = {}
	pcall(function()
		for _, f in ipairs(listfiles(self.Folder .. "/settings")) do
			local n = f:match("([^/\\]+)%.json$")
			if n then out[#out + 1] = n end
		end
	end)
	table.sort(out)
	return out
end

function SaveManager:SetAutoload(name) pcall(writefile, self.Folder .. "/settings/autoload.txt", name) end
function SaveManager:RemoveAutoload() pcall(delfile, self.Folder .. "/settings/autoload.txt") end
function SaveManager:GetAutoload()
	local ok, n = pcall(readfile, self.Folder .. "/settings/autoload.txt")
	if ok and n and n ~= "" then return n end
	return nil
end
function SaveManager:LoadAutoloadConfig()
	local n = self:GetAutoload()
	if n then
		local ok, err = self:Load(n)
		if ok then self.Library:Notify({ Title = "Config", Description = "Auto-loaded " .. n, Time = 3 })
		else self.Library:Notify({ Title = "Config", Description = "Autoload failed: " .. tostring(err), Time = 4 }) end
	end
end

function SaveManager:_autosaveNow(reason)
	if not self.AutoSave then return end
	local name = self._current or self:GetAutoload() or "autosave"
	local ok = self:Save(name)
	if ok and reason ~= "tick" then pcall(function() self.Library:Notify({ Title = "Config", Description = "Auto-saved " .. name, Time = 2 }) end) end
end
function SaveManager:StartAutoSave()
	if self._autoStarted then return end
	self._autoStarted = true
	task.spawn(function()
		while not self.Library.Unloaded do
			task.wait(self.AutoSaveInterval)
			if self.AutoSave then pcall(function() self:_autosaveNow("tick") end) end
		end
	end)
	pcall(function() LocalPlayer.OnTeleport:Connect(function() self:_autosaveNow("teleport") end) end)
	pcall(function() game:GetService("GuiService").ErrorMessageChanged:Connect(function() self:_autosaveNow("disconnect") end) end)
	pcall(function() Players.PlayerRemoving:Connect(function(p) if p == LocalPlayer then self:_autosaveNow("leave") end end) end)
	pcall(function() game.Close:Connect(function() self:_autosaveNow("close") end) end)
	self.Library:OnUnload(function() self:_autosaveNow("unload") end)
end

function SaveManager:BuildConfigSection(tab)
	assert(self.Library, "SaveManager: SetLibrary first")
	self:BuildFolderTree()
	local Library = self.Library
	local gb = tab:AddRightGroupbox("Configuration")
	local list = gb:AddDropdown("SaveManager_ConfigList", { Text = "Configs", Values = self:ListConfigs(), Default = 1, Searchable = true, AllowNull = true })
	local nameBox = gb:AddInput("SaveManager_ConfigName", { Text = "Config name", Placeholder = "name", Finished = true })
	local status = gb:AddLabel("Current: none | Autoload: " .. (self:GetAutoload() or "none"))
	local function refresh()
		list:SetValues(self:ListConfigs())
		status:SetText("Current: " .. (self._current or "none") .. " | Autoload: " .. (self:GetAutoload() or "none"))
	end
	gb:AddButton({ Text = "Create", Func = function()
		local n = nameBox.Value
		if n == "" then Library:Notify({ Title = "Config", Description = "Enter a name first", Time = 3 }) return end
		local ok, err = self:Save(n)
		if ok then self._current = n Library:Notify({ Title = "Config", Description = "Created " .. n, Time = 3 }) else Library:Notify({ Title = "Config", Description = tostring(err), Time = 3 }) end
		refresh()
	end }):AddButton({ Text = "Load", Func = function()
		local n = list.Value
		if not n then return end
		local ok, err = self:Load(n)
		Library:Notify({ Title = "Config", Description = ok and ("Loaded " .. n) or tostring(err), Time = 3 })
		refresh()
	end })
	gb:AddButton({ Text = "Overwrite", Func = function()
		local n = list.Value
		if not n then return end
		local ok, err = self:Save(n)
		if ok then self._current = n end
		Library:Notify({ Title = "Config", Description = ok and ("Overwrote " .. n) or tostring(err), Time = 3 })
		refresh()
	end }):AddButton({ Text = "Delete", Risky = true, DoubleClick = true, Func = function()
		local n = list.Value
		if not n then return end
		self:Delete(n)
		Library:Notify({ Title = "Config", Description = "Deleted " .. n, Time = 3 })
		refresh()
	end })
	gb:AddButton({ Text = "Set autoload", Func = function()
		local n = list.Value
		if not n then return end
		self:SetAutoload(n)
		Library:Notify({ Title = "Config", Description = "Autoload: " .. n, Time = 3 })
		refresh()
	end }):AddButton({ Text = "Remove autoload", Func = function()
		self:RemoveAutoload()
		Library:Notify({ Title = "Config", Description = "Autoload removed", Time = 3 })
		refresh()
	end })
	gb:AddToggle("SaveManager_AutoSave", { Text = "Auto save (on leave / every " .. self.AutoSaveInterval .. "s)", Default = true, Callback = function(v) self.AutoSave = v end })
	gb:AddButton({ Text = "Refresh list", Func = refresh })
	self:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName", "SaveManager_AutoSave" })
	self:StartAutoSave()
end

return SaveManager
