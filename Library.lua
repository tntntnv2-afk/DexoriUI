local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local Library = {
	Version = "2.0.0",
	Registry = {},
	Toggles = {},
	Options = {},
	Signals = {},
	Windows = {},
	SearchIndex = {},
	OpenPopups = {},
	Unloaded = false,
	IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
	Theme = {
		Background = Color3.fromRGB(10, 10, 11),
		Main = Color3.fromRGB(15, 15, 17),
		Element = Color3.fromRGB(22, 22, 25),
		ElementHover = Color3.fromRGB(30, 30, 34),
		Accent = Color3.fromRGB(200, 30, 30),
		AccentGradient = ColorSequence.new(Color3.fromRGB(235, 45, 45), Color3.fromRGB(110, 8, 8)),
		Outline = Color3.fromRGB(36, 36, 40),
		OutlineStrong = Color3.fromRGB(70, 18, 18),
		Font = Color3.fromRGB(230, 230, 232),
		FontDim = Color3.fromRGB(128, 128, 136),
		Risky = Color3.fromRGB(255, 80, 80),
	},
	FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium),
	FontFaceBold = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold),
	ESPFont = Font.fromEnum(Enum.Font.Code),
	ToggleKeybind = Enum.KeyCode.RightControl,
	Icon = "rbxassetid://83607561451748",
	Effects = { Blur = true, Snow = true, BlurSize = 12, SnowCount = 45 },
}

getgenv().Toggles = Library.Toggles
getgenv().Options = Library.Options

local function getGuiParent()
	local ok, hui = pcall(function() return gethui and gethui() end)
	if ok and hui then return hui end
	return CoreGui
end
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "DexoriUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
pcall(function() ScreenGui.Parent = getGuiParent() end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
Library.ScreenGui = ScreenGui

-- ---------------------------------------------------------------- helpers
local function Create(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do if k ~= "Parent" then inst[k] = v end end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end
local function Tween(obj, props, t, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
function Library:AddToRegistry(inst, props)
	self.Registry[inst] = props
	for prop, key in pairs(props) do local v = self.Theme[key] if v ~= nil then pcall(function() inst[prop] = v end) end end
end
function Library:RemoveFromRegistry(inst) self.Registry[inst] = nil end
function Library:UpdateColorsUsingRegistry()
	for inst, props in pairs(self.Registry) do
		if inst and inst.Parent then
			for prop, key in pairs(props) do local v = self.Theme[key] if v ~= nil then pcall(function() inst[prop] = v end) end end
		else self.Registry[inst] = nil end
	end
end
function Library:SetTheme(theme) for k, v in pairs(theme) do self.Theme[k] = v end self:UpdateColorsUsingRegistry() end
function Library:GiveSignal(c) table.insert(self.Signals, c) return c end
local function Corner(p, r) return Create("UICorner", { CornerRadius = UDim.new(0, r or 2), Parent = p }) end
local function Stroke(p, key, thick, transp)
	local s = Create("UIStroke", { Thickness = thick or 1, Transparency = transp or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p })
	Library:AddToRegistry(s, { Color = key or "Outline" })
	return s
end
local function Pad(p, l, r, t, b) return Create("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0), PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0), Parent = p }) end
local function Text(parent, txt, size, bold, key)
	local l = Create("TextLabel", { BackgroundTransparency = 1, Text = txt or "", TextSize = size or 12, FontFace = bold and Library.FontFaceBold or Library.FontFace, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.new(1, 0, 0, 16), RichText = true, TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent })
	Library:AddToRegistry(l, { TextColor3 = key or "Font" })
	return l
end
local function IsPressed(inp) return inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch end
local function Draggable(handle, frame)
	local dragging, dragStart, startPos = false, nil, nil
	handle.InputBegan:Connect(function(inp)
		if IsPressed(inp) then
			dragging = true dragStart = inp.Position startPos = frame.Position
			inp.Changed:Connect(function() if inp.UserInputState == Enum.UserInputState.End then dragging = false end end)
		end
	end)
	Library:GiveSignal(UserInputService.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
			local d = inp.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end))
end
-- click ripple, used on every pressable surface
local function Ripple(btn, color)
	btn.ClipsDescendants = true
	btn.InputBegan:Connect(function(inp)
		if not (inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch) then return end
		local abs = btn.AbsolutePosition
		local rx, ry = inp.Position.X - abs.X, inp.Position.Y - abs.Y
		local far = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) * 2
		local c = Create("Frame", { Size = UDim2.fromOffset(0, 0), Position = UDim2.fromOffset(rx, ry), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color or Library.Theme.Accent, BackgroundTransparency = 0.72, BorderSizePixel = 0, ZIndex = (btn.ZIndex or 1) + 1, Parent = btn })
		Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = c })
		Tween(c, { Size = UDim2.fromOffset(far, far), BackgroundTransparency = 1 }, 0.45, Enum.EasingStyle.Quint)
		task.delay(0.5, function() c:Destroy() end)
	end)
end
-- squash on press so buttons feel physical
local function Press(btn, scale)
	local s = Create("UIScale", { Scale = 1, Parent = btn })
	btn.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			Tween(s, { Scale = scale or 0.97 }, 0.08)
		end
	end)
	btn.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			Tween(s, { Scale = 1 }, 0.16, Enum.EasingStyle.Back)
		end
	end)
	return s
end
local function Hover(btn, normalKey, hoverKey)
	btn.MouseEnter:Connect(function() Tween(btn, { BackgroundColor3 = Library.Theme[hoverKey] }, 0.1) end)
	btn.MouseLeave:Connect(function() Tween(btn, { BackgroundColor3 = Library.Theme[normalKey] }, 0.1) end)
end
-- glass: a light top-down sheen + hairline highlight so panels read as frosted, not flat
local function Glass(frame)
	local sheen = Create("Frame", { Name = "_glass", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.93, BorderSizePixel = 0, ZIndex = (frame.ZIndex or 1), Parent = frame })
	Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = sheen })
	Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.86), NumberSequenceKeypoint.new(0.45, 0.98), NumberSequenceKeypoint.new(1, 1) }), Parent = sheen })
	local edge = Create("UIStroke", { Thickness = 1, Transparency = 0.55, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = Color3.fromRGB(255, 255, 255), Parent = frame })
	Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.9) }), Parent = edge })
	return sheen
end
local function Shadow(frame, spread)
	local s = Create("ImageLabel", { Name = "_shadow", Size = UDim2.new(1, (spread or 24) * 2, 1, (spread or 24) * 2), Position = UDim2.new(0, -(spread or 24), 0, -(spread or 24) + 4), BackgroundTransparency = 1, Image = "rbxassetid://6014261993", ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0.45, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450), ZIndex = (frame.ZIndex or 1) - 1, Parent = frame })
	return s
end
Library.Create, Library.Tween, Library.Text, Library.Draggable = Create, Tween, Text, Draggable
Library.Ripple, Library.Press = Ripple, Press
Library.Glass, Library.Shadow = Glass, Shadow

-- ---------------------------------------------------------------- backdrop: blur + snow
local Backdrop = Create("Frame", { Name = "Backdrop", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 0, Parent = ScreenGui })
Create("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 18, 20)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
	}),
	Parent = Backdrop,
})
local BackdropGlow = Create("ImageLabel", { Name = "Glow", Size = UDim2.new(1.4, 0, 1.4, 0), Position = UDim2.new(-0.2, 0, -0.5, 0), BackgroundTransparency = 1, Image = "rbxassetid://5028857084", ImageColor3 = Color3.fromRGB(0, 0, 0), ImageTransparency = 0.5, ZIndex = 0, Parent = Backdrop })
local Blur = Create("BlurEffect", { Name = "DexoriBlur", Size = 0, Enabled = false, Parent = Lighting })
local flakes = {}
local snowConn = nil
local function makeFlake()
	local s = math.random(2, 5)
	local near = s >= 4
	local f = Create("ImageLabel", {
		Size = UDim2.fromOffset(s * 3, s * 3), BackgroundTransparency = 1,
		Image = "rbxassetid://4996891970", ImageColor3 = Color3.fromRGB(226, 240, 255),
		ImageTransparency = near and 0.25 or math.random(45, 75) / 100,
		ZIndex = 1, Parent = Backdrop,
	})
	return { f = f, x = math.random(), y = -math.random() * 0.4, vy = (near and math.random(45, 80) or math.random(18, 40)) / 1000, drift = math.random(-18, 18) / 1000, phase = math.random() * 6.28, spin = math.random(-40, 40) }
end
local function startSnow()
	if snowConn then return end
	for i = 1, Library.Effects.SnowCount do flakes[i] = flakes[i] or makeFlake() end
	snowConn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for _, fl in ipairs(flakes) do
			fl.y = fl.y + fl.vy * dt * 3
			fl.x = fl.x + (fl.drift + math.sin(t * 0.8 + fl.phase) * 0.006) * dt * 3
			if fl.y > 1.05 then fl.y = -0.05 fl.x = math.random() end
			if fl.x < -0.03 then fl.x = 1.03 elseif fl.x > 1.03 then fl.x = -0.03 end
			fl.f.Position = UDim2.new(fl.x, 0, fl.y, 0)
			fl.f.Rotation = (t * fl.spin) % 360
		end
	end)
end
local function stopSnow()
	if snowConn then snowConn:Disconnect() snowConn = nil end
end
function Library:_SetBackdrop(on)
	if on then
		Backdrop.Visible = true
		Tween(Backdrop, { BackgroundTransparency = 0.32 }, 0.25)
		if self.Effects.Blur then Blur.Enabled = true Tween(Blur, { Size = self.Effects.BlurSize }, 0.25) end
		if self.Effects.Snow then startSnow() end
	else
		Tween(Backdrop, { BackgroundTransparency = 1 }, 0.2).Completed:Connect(function() if Backdrop.BackgroundTransparency >= 0.99 then Backdrop.Visible = false end end)
		Tween(Blur, { Size = 0 }, 0.2).Completed:Connect(function() if Blur.Size == 0 then Blur.Enabled = false end end)
		stopSnow()
	end
end
function Library:SetEffects(cfg) for k, v in pairs(cfg) do self.Effects[k] = v end end

-- ---------------------------------------------------------------- notifications
local NotifHolder = Create("Frame", { Name = "Notifications", BackgroundTransparency = 1, Size = UDim2.new(0, 280, 1, -20), Position = UDim2.new(1, -292, 0, 12), Parent = ScreenGui })
Create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = NotifHolder })
function Library:SetNotifySide(side)
	if side == "Left" then NotifHolder.Position = UDim2.new(0, 12, 0, 12) NotifHolder.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	else NotifHolder.Position = UDim2.new(1, -292, 0, 12) NotifHolder.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right end
end
function Library:Notify(opts, duration)
	if type(opts) ~= "table" then opts = { Description = tostring(opts), Time = duration } end
	local time = opts.Time or 4
	local card = Create("Frame", { Size = UDim2.new(0, 270, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 0.1, ClipsDescendants = true, Parent = NotifHolder })
	self:AddToRegistry(card, { BackgroundColor3 = "Main" }); Corner(card, 10); Library.Glass(card); Library.Shadow(card, 16)
	local bar = Create("Frame", { Size = UDim2.new(0, 2, 1, 0), BorderSizePixel = 0, Parent = card })
	Create("UIGradient", { Rotation = 90, Parent = bar })
	self:AddToRegistry(bar.UIGradient, { Color = "AccentGradient" })
	local inner = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 10, 0, 0), Parent = card })
	Pad(inner, 0, 0, 7, 7)
	Create("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder, Parent = inner })
	local t = Text(inner, opts.Title or "dexori", 12, true); t.LayoutOrder = 1; t.Size = UDim2.new(1, 0, 0, 14)
	local d = Text(inner, opts.Description or "", 11, false, "FontDim"); d.LayoutOrder = 2; d.TextWrapped = true; d.AutomaticSize = Enum.AutomaticSize.Y; d.Size = UDim2.new(1, 0, 0, 0); d.TextTruncate = Enum.TextTruncate.None
	local prog = Create("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BorderSizePixel = 0, Parent = card })
	self:AddToRegistry(prog, { BackgroundColor3 = "Accent" })
	card.Position = UDim2.new(1, 280, 0, 0)
	Tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.22)
	Tween(prog, { Size = UDim2.new(0, 0, 0, 1) }, time, Enum.EasingStyle.Linear)
	local obj = { Frame = card }
	function obj:Destroy() if card.Parent then Tween(card, { Position = UDim2.new(1, 280, 0, 0) }, 0.18).Completed:Connect(function() card:Destroy() end) end end
	task.delay(time, function() obj:Destroy() end)
	card.InputBegan:Connect(function(inp) if IsPressed(inp) then obj:Destroy() end end)
	return obj
end

-- ---------------------------------------------------------------- watermark + search
local Watermark = Create("Frame", { Name = "Watermark", Size = UDim2.new(0, 0, 0, 26), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0, 12, 0, 12), Visible = false, Parent = ScreenGui })
Library:AddToRegistry(Watermark, { BackgroundColor3 = "Main" })
Watermark.BackgroundTransparency = 0.12; Corner(Watermark, 2); Stroke(Watermark, "Outline")
local wmAccent = Create("Frame", { Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, Parent = Watermark })
Create("UIGradient", { Parent = wmAccent }); Library:AddToRegistry(wmAccent.UIGradient, { Color = "AccentGradient" })
Pad(Watermark, 8, 8, 0, 0)
Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Watermark })
Create("ImageLabel", { LayoutOrder = 1, Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Image = Library.Icon, Parent = Watermark })
local WmText = Create("TextLabel", { LayoutOrder = 2, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), FontFace = Library.FontFaceBold, TextSize = 11, Text = "dexori", Parent = Watermark })
Library:AddToRegistry(WmText, { TextColor3 = "Font" })
local sep = Create("Frame", { LayoutOrder = 3, Size = UDim2.new(0, 1, 0, 12), BorderSizePixel = 0, Parent = Watermark }); Library:AddToRegistry(sep, { BackgroundColor3 = "Outline" })
local WmSearchBox = Create("Frame", { LayoutOrder = 4, Size = UDim2.new(0, 140, 0, 18), Parent = Watermark })
Library:AddToRegistry(WmSearchBox, { BackgroundColor3 = "Element" }); Corner(WmSearchBox, 2); Stroke(WmSearchBox, "Outline")
local WmSearch = Create("TextBox", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 1, 0), Position = UDim2.new(0, 6, 0, 0), PlaceholderText = "search", Text = "", TextSize = 11, FontFace = Library.FontFace, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = WmSearchBox })
Library:AddToRegistry(WmSearch, { TextColor3 = "Font", PlaceholderColor3 = "FontDim" })
local WmResults = Create("Frame", { Size = UDim2.new(0, 260, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 12, 0, 42), Visible = false, ZIndex = 80, Parent = ScreenGui })
Library:AddToRegistry(WmResults, { BackgroundColor3 = "Main" }); Corner(WmResults, 2); Stroke(WmResults, "OutlineStrong")
Pad(WmResults, 3, 3, 3, 3)
Create("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder, Parent = WmResults })
function Library:SetWatermarkVisibility(on) Watermark.Visible = on and true or false end
Watermark.Visible = false
function Library:SetWatermark(text) WmText.Text = text or "dexori" end
function Library:RegisterSearch(name, path, focus) table.insert(self.SearchIndex, { name = name, path = path, focus = focus }) end
local function runSearch(q)
	for _, c in ipairs(WmResults:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
	q = string.lower(q or "")
	if q == "" then WmResults.Visible = false return end
	local n = 0
	for _, e in ipairs(Library.SearchIndex) do
		if string.find(string.lower(e.name), q, 1, true) or string.find(string.lower(e.path), q, 1, true) then
			n = n + 1
			if n > 8 then break end
			local b = Create("TextButton", { AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 26), Text = "", LayoutOrder = n, ZIndex = 81, Parent = WmResults })
			Library:AddToRegistry(b, { BackgroundColor3 = "Element" }); Corner(b, 2)
			local nm = Text(b, e.name, 11, true); nm.Position = UDim2.new(0, 6, 0, 1); nm.Size = UDim2.new(1, -12, 0, 13); nm.ZIndex = 82
			local pt = Text(b, e.path, 10, false, "FontDim"); pt.Position = UDim2.new(0, 6, 0, 13); pt.Size = UDim2.new(1, -12, 0, 12); pt.ZIndex = 82
			Hover(b, "Element", "ElementHover")
			b.MouseButton1Click:Connect(function() pcall(e.focus) WmSearch.Text = "" WmResults.Visible = false end)
		end
	end
	WmResults.Visible = n > 0
end
WmSearch:GetPropertyChangedSignal("Text"):Connect(function() runSearch(WmSearch.Text) end)
Draggable(Watermark, Watermark)

-- ---------------------------------------------------------------- keybind list
local KeybindFrame = Create("Frame", { Name = "Keybinds", Size = UDim2.new(0, 150, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 12, 0.5, -60), Visible = false, Parent = ScreenGui })
Library:AddToRegistry(KeybindFrame, { BackgroundColor3 = "Main" }); Corner(KeybindFrame, 2); Stroke(KeybindFrame, "Outline")
local kbAccent = Create("Frame", { Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0, Parent = KeybindFrame })
Create("UIGradient", { Parent = kbAccent }); Library:AddToRegistry(kbAccent.UIGradient, { Color = "AccentGradient" })
Pad(KeybindFrame, 7, 7, 6, 6)
Create("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder, Parent = KeybindFrame })
local kbTitle = Text(KeybindFrame, "keybinds", 11, true); kbTitle.LayoutOrder = 0; kbTitle.Size = UDim2.new(1, 0, 0, 14)
Library.KeybindFrame = KeybindFrame
Draggable(KeybindFrame, KeybindFrame)
KeybindFrame.Visible = false
function Library:SetKeybindVisibility(on) KeybindFrame.Visible = on and true or false end

-- ---------------------------------------------------------------- popups (outside-click close)
function Library:_ClosePopups(except) for _, p in pairs(self.OpenPopups) do if p ~= except then pcall(function() p.Visible = false end) end end end
Library:GiveSignal(UserInputService.InputBegan:Connect(function(inp)
	if not IsPressed(inp) then return end
	local pos = inp.Position
	for _, p in pairs(Library.OpenPopups) do
		if p.Visible then
			local a, s = p.AbsolutePosition, p.AbsoluteSize
			local inside = pos.X >= a.X and pos.X <= a.X + s.X and pos.Y >= a.Y and pos.Y <= a.Y + s.Y
			if not inside then task.defer(function() p.Visible = false end) end
		end
	end
end))

-- ---------------------------------------------------------------- window
function Library:CreateWindow(cfg)
	cfg = cfg or {}
	local window = { Tabs = {}, ActiveTab = nil }
	local size = cfg.Size or UDim2.fromOffset(760, 520)
	if Library.IsMobile then
		local vp = ScreenGui.AbsoluteSize
		size = UDim2.fromOffset(math.min(size.X.Offset, vp.X - 16), math.min(size.Y.Offset, vp.Y - 16))
	end

	local main = Create("Frame", { Name = "Window", Size = size, Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2), ClipsDescendants = true, ZIndex = 10, Parent = ScreenGui })
	self:AddToRegistry(main, { BackgroundColor3 = "Background" })
	Corner(main, 14)
	Create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 226, 232)), Parent = main })
	local edge = Create("UIStroke", { Thickness = 1, Transparency = 0.5, Color = Color3.fromRGB(255, 255, 255), Parent = main })
	Create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.92) }), Parent = edge })
	Shadow(main, 34)
	window.Frame = main

	-- ---------------------------------------------------------------- left rail
	local rail = Create("Frame", { Name = "Rail", Size = UDim2.new(0, 68, 1, 0), BorderSizePixel = 0, ZIndex = 11, Parent = main })
	self:AddToRegistry(rail, { BackgroundColor3 = "Main" })
	local railEdge = Create("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 12, Parent = rail })
	self:AddToRegistry(railEdge, { BackgroundColor3 = "Outline" })
	local logoRing = Create("Frame", { Size = UDim2.fromOffset(42, 42), Position = UDim2.new(0.5, -21, 0, 14), BackgroundTransparency = 1, ZIndex = 12, Parent = rail })
	Corner(logoRing, 14)
	local ringStroke = Create("UIStroke", { Thickness = 1, Transparency = 0.55, Parent = logoRing })
	self:AddToRegistry(ringStroke, { Color = "Accent" })
	local logo = Create("ImageLabel", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0.5, -13, 0, 22), BackgroundTransparency = 1, Image = cfg.Icon and ("rbxassetid://" .. tostring(cfg.Icon)) or Library.Icon, ZIndex = 13, Parent = rail })
	task.spawn(function()
		while not Library.Unloaded and ringStroke.Parent do
			Tween(ringStroke, { Transparency = 0.85 }, 1.5, Enum.EasingStyle.Sine)
			task.wait(1.5)
			Tween(ringStroke, { Transparency = 0.45 }, 1.5, Enum.EasingStyle.Sine)
			task.wait(1.5)
		end
	end)
	local railList = Create("Frame", { Size = UDim2.new(1, 0, 1, -140), Position = UDim2.new(0, 0, 0, 68), BackgroundTransparency = 1, ZIndex = 12, Parent = rail })
	Create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = railList })
	-- sliding indicator
	local pill = Create("Frame", { Size = UDim2.fromOffset(3, 24), Position = UDim2.new(0, 0, 0, 80), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 14, Parent = rail })
	self:AddToRegistry(pill, { BackgroundColor3 = "Accent" }); Corner(pill, 2)
	local pillGlow = Create("ImageLabel", { Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0, -16, 0.5, -26), BackgroundTransparency = 1, Image = "rbxassetid://5028857084", ImageTransparency = 0.6, ZIndex = 13, Parent = pill })
	self:AddToRegistry(pillGlow, { ImageColor3 = "Accent" })
	-- toggle hint at the bottom of the rail
	local hint = Text(rail, "", 9, false, "FontDim"); hint.TextXAlignment = Enum.TextXAlignment.Center; hint.Position = UDim2.new(0, 0, 1, -26); hint.Size = UDim2.new(1, 0, 0, 14); hint.ZIndex = 13
	hint.Text = tostring(Library.ToggleKeybind and Library.ToggleKeybind.Name or "")

	-- ---------------------------------------------------------------- header
	local head = Create("Frame", { Size = UDim2.new(1, -68, 0, 72), Position = UDim2.new(0, 68, 0, 0), BackgroundTransparency = 1, ZIndex = 12, Parent = main })
	local pageTitle = Text(head, "", 21, true); pageTitle.Position = UDim2.new(0, 24, 0, 13); pageTitle.Size = UDim2.new(0.5, 0, 0, 26); pageTitle.ZIndex = 13
	local titleBar = Create("Frame", { Size = UDim2.fromOffset(24, 3), Position = UDim2.new(0, 24, 0, 41), ZIndex = 13, Parent = head })
	Corner(titleBar, 2); Create("UIGradient", { Parent = titleBar })
	self:AddToRegistry(titleBar.UIGradient, { Color = "AccentGradient" })
	local pageSub = Text(head, cfg.Subtitle or "", 11, false, "FontDim"); pageSub.Position = UDim2.new(0, 24, 0, 48); pageSub.Size = UDim2.new(0.5, 0, 0, 14); pageSub.ZIndex = 13
	Draggable(head, main)

	local searchBox = Create("Frame", { Size = UDim2.new(0, 210, 0, 32), Position = UDim2.new(1, -232, 0, 22), ZIndex = 13, Parent = head })
	self:AddToRegistry(searchBox, { BackgroundColor3 = "Main" }); Corner(searchBox, 10); Stroke(searchBox, "Outline")
	local sIcon = Text(searchBox, "⌕", 15, true, "FontDim"); sIcon.TextXAlignment = Enum.TextXAlignment.Center; sIcon.Position = UDim2.new(0, 6, 0, 0); sIcon.Size = UDim2.new(0, 18, 1, 0); sIcon.ZIndex = 14
	local searchIn = Create("TextBox", { Size = UDim2.new(1, -34, 1, 0), Position = UDim2.new(0, 26, 0, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "search settings", TextSize = 12, FontFace = Library.FontFace, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 14, Parent = searchBox })
	self:AddToRegistry(searchIn, { TextColor3 = "Font", PlaceholderColor3 = "FontDim" })
	local results = Create("Frame", { Size = UDim2.new(0, 260, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(1, -282, 0, 58), Visible = false, ZIndex = 40, Parent = head })
	self:AddToRegistry(results, { BackgroundColor3 = "Main" }); Corner(results, 10); Stroke(results, "Outline"); Shadow(results, 16)
	Pad(results, 6, 6, 6, 6)
	Create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder, Parent = results })
	local function runSearch(q)
		for _, c in ipairs(results:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		q = string.lower(q or "")
		if q == "" then results.Visible = false return end
		local n = 0
		for _, e in ipairs(Library.SearchIndex) do
			if string.find(string.lower(e.name), q, 1, true) or string.find(string.lower(e.path), q, 1, true) then
				n = n + 1
				if n > 7 then break end
				local b = Create("TextButton", { Size = UDim2.new(1, 0, 0, 34), Text = "", AutoButtonColor = false, BackgroundTransparency = 1, LayoutOrder = n, ZIndex = 41, Parent = results })
				Corner(b, 8); Library:AddToRegistry(b, { BackgroundColor3 = "Element" })
				local nm = Text(b, e.name, 12, true); nm.Position = UDim2.new(0, 10, 0, 4); nm.Size = UDim2.new(1, -20, 0, 14); nm.ZIndex = 42
				local pt = Text(b, e.path, 10, false, "FontDim"); pt.Position = UDim2.new(0, 10, 0, 18); pt.Size = UDim2.new(1, -20, 0, 12); pt.ZIndex = 42
				b.MouseEnter:Connect(function() b.BackgroundTransparency = 0 end)
				b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
				b.MouseButton1Click:Connect(function() pcall(e.focus) searchIn.Text = "" results.Visible = false end)
			end
		end
		results.Visible = n > 0
	end
	searchIn:GetPropertyChangedSignal("Text"):Connect(function() runSearch(searchIn.Text) end)
	searchIn.FocusLost:Connect(function() task.delay(0.2, function() if searchIn.Text == "" then results.Visible = false end end) end)

	-- ---------------------------------------------------------------- body + footer
	local body = Create("Frame", { Size = UDim2.new(1, -68, 1, -104), Position = UDim2.new(0, 68, 0, 72), BackgroundTransparency = 1, ZIndex = 11, Parent = main })
	local footer = Create("Frame", { Size = UDim2.new(1, -68, 0, 32), Position = UDim2.new(0, 68, 1, -32), BackgroundTransparency = 1, ZIndex = 12, Parent = main })
	local footLine = Create("Frame", { Size = UDim2.new(1, -44, 0, 1), Position = UDim2.new(0, 22, 0, 0), BackgroundTransparency = 0.5, BorderSizePixel = 0, ZIndex = 12, Parent = footer })
	self:AddToRegistry(footLine, { BackgroundColor3 = "Outline" })
	local footL = Text(footer, cfg.Footer or "", 10, false, "FontDim"); footL.Position = UDim2.new(0, 22, 0, 0); footL.Size = UDim2.new(0.5, 0, 1, 0); footL.ZIndex = 13
	local footR = Text(footer, "", 10, false, "FontDim"); footR.TextXAlignment = Enum.TextXAlignment.Right; footR.Position = UDim2.new(1, -222, 0, 0); footR.Size = UDim2.new(0, 200, 1, 0); footR.ZIndex = 13
	task.spawn(function()
		local frames, acc, fps = 0, 0, 0
		local c = RunService.RenderStepped:Connect(function(dt) frames = frames + 1 acc = acc + dt if acc >= 1 then fps = frames frames = 0 acc = 0 end end)
		Library:GiveSignal(c)
		while not Library.Unloaded do
			local ping = ""
			pcall(function() ping = game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString():match("^(%d+)") or "" end)
			footR.Text = string.format("%s   ·   %d fps   ·   %s ms", tostring(LocalPlayer.DisplayName), fps, ping)
			task.wait(1)
		end
	end)

	-- ---------------------------------------------------------------- visibility
	local visible = cfg.AutoShow ~= false
	local winScale = Create("UIScale", { Scale = 1, Parent = main })
	local function show(on)
		visible = on
		Library:_SetBackdrop(on)
		if on then
			main.Visible = true
			winScale.Scale = 0.92
			main.BackgroundTransparency = 1
			Tween(winScale, { Scale = 1 }, 0.34, Enum.EasingStyle.Back)
			Tween(main, { BackgroundTransparency = 0 }, 0.2)
			-- rail items cascade in
			for i, t in ipairs(window.Tabs) do
				local sc = t._btn:FindFirstChildOfClass("UIScale") or Create("UIScale", { Parent = t._btn })
				sc.Scale = 0.6
				task.delay(0.04 * i, function() Tween(sc, { Scale = 1 }, 0.3, Enum.EasingStyle.Back) end)
			end
		else
			Library:_ClosePopups()
			Tween(winScale, { Scale = 0.94 }, 0.16, Enum.EasingStyle.Quad)
			Tween(main, { BackgroundTransparency = 1 }, 0.16).Completed:Connect(function()
				if not visible then main.Visible = false main.BackgroundTransparency = 0 winScale.Scale = 1 end
			end)
		end
	end
	function window:SetVisible(on) show(on) end
	function window:Toggle() show(not visible) end
	function window:IsVisible() return visible end
	Library.ToggleKeybind = cfg.ToggleKeybind or Library.ToggleKeybind
	hint.Text = tostring(Library.ToggleKeybind.Name)
	self:GiveSignal(UserInputService.InputBegan:Connect(function(inp, gpe)
		if gpe then return end
		if inp.KeyCode == Library.ToggleKeybind then show(not visible) end
	end))
	if Library.IsMobile then
		local mob = Create("TextButton", { Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, 14, 0.5, -23), Text = "", AutoButtonColor = false, ZIndex = 40, Parent = ScreenGui })
		self:AddToRegistry(mob, { BackgroundColor3 = "Main" }); Corner(mob, 14); Stroke(mob, "Outline"); Shadow(mob, 18)
		Create("ImageLabel", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0.5, -13, 0.5, -13), BackgroundTransparency = 1, Image = Library.Icon, ZIndex = 41, Parent = mob })
		mob.MouseButton1Click:Connect(function() show(not visible) end)
		Draggable(mob, mob)
	end

	-- ---------------------------------------------------------------- tabs
	local order = 0
	local function columns(parent, top)
		local l = Create("ScrollingFrame", { Size = UDim2.new(0.5, -28, 1, -top), Position = UDim2.new(0, 22, 0, top), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageTransparency = 0.5, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 12, Parent = parent })
		Library:AddToRegistry(l, { ScrollBarImageColor3 = "Accent" })
		Create("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = l })
		Pad(l, 0, 6, 0, 16)
		local r = Create("ScrollingFrame", { Size = UDim2.new(0.5, -28, 1, -top), Position = UDim2.new(0.5, 6, 0, top), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageTransparency = 0.5, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 12, Parent = parent })
		Library:AddToRegistry(r, { ScrollBarImageColor3 = "Accent" })
		Create("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, Parent = r })
		Pad(r, 0, 6, 0, 16)
		return l, r
	end

	function window:AddTab(name, icon)
		order = order + 1
		local tab = { Name = name, Subtabs = {} }
		local btn = Create("TextButton", { Size = UDim2.fromOffset(44, 44), Text = "", AutoButtonColor = false, BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 13, Parent = railList })
		Corner(btn, 12); Library:AddToRegistry(btn, { BackgroundColor3 = "Element" })
		local glyph
		if icon then
			glyph = Create("ImageLabel", { Size = UDim2.fromOffset(20, 20), Position = UDim2.new(0.5, -10, 0.5, -10), BackgroundTransparency = 1, Image = (type(icon) == "number") and ("rbxassetid://" .. icon) or tostring(icon), ZIndex = 14, Parent = btn })
			Library:AddToRegistry(glyph, { ImageColor3 = "FontDim" })
		else
			glyph = Text(btn, string.upper(string.sub(name, 1, 2)), 12, true, "FontDim")
			glyph.TextXAlignment = Enum.TextXAlignment.Center; glyph.Size = UDim2.new(1, 0, 1, 0); glyph.ZIndex = 14
		end
		-- hover label
		local tip = Create("Frame", { Size = UDim2.new(0, 0, 0, 22), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(1, 8, 0.5, -11), Visible = false, ZIndex = 45, Parent = btn })
		Library:AddToRegistry(tip, { BackgroundColor3 = "Element" }); Corner(tip, 7); Pad(tip, 8, 8, 0, 0); Shadow(tip, 10)
		local tipT = Text(tip, name, 11, true); tipT.AutomaticSize = Enum.AutomaticSize.X; tipT.Size = UDim2.new(0, 0, 1, 0); tipT.ZIndex = 46
		btn.MouseEnter:Connect(function() tip.Visible = true if window.ActiveTab ~= tab then Tween(btn, { BackgroundTransparency = 0 }, 0.1) end end)
		btn.MouseLeave:Connect(function() tip.Visible = false if window.ActiveTab ~= tab then Tween(btn, { BackgroundTransparency = 1 }, 0.1) end end)
		tab._btn, tab._glyph = btn, glyph

		local page = Create("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 11, Parent = body })
		tab.Page = page
		local subRow = Create("Frame", { Size = UDim2.new(1, -44, 0, 30), Position = UDim2.new(0, 22, 0, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 12, Parent = page })
		Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = subRow })
		local l, r = columns(page, 6)
		tab.Left, tab.Right, tab._cols = l, r, { l, r }

		local function relayout()
			local top = subRow.Visible and 40 or 6
			local all = { l, r }
			for _, st in ipairs(tab.Subtabs) do all[#all + 1] = st.Left all[#all + 1] = st.Right end
			for _, c in ipairs(all) do
				c.Position = UDim2.new(c.Position.X.Scale, c.Position.X.Offset, 0, top)
				c.Size = UDim2.new(c.Size.X.Scale, c.Size.X.Offset, 1, -top)
			end
		end

		function tab:Select()
			for _, t in ipairs(window.Tabs) do
				t.Page.Visible = false
				t._btn.BackgroundTransparency = 1
				if t._glyph:IsA("ImageLabel") then Tween(t._glyph, { ImageColor3 = Library.Theme.FontDim }, 0.12) else Tween(t._glyph, { TextColor3 = Library.Theme.FontDim }, 0.12) end
			end
			self.Page.Visible = true
			self._btn.BackgroundTransparency = 0
			if self._glyph:IsA("ImageLabel") then Tween(self._glyph, { ImageColor3 = Library.Theme.Accent }, 0.12) else Tween(self._glyph, { TextColor3 = Library.Theme.Accent }, 0.12) end
			pageTitle.Text = name
			task.defer(function() Tween(titleBar, { Size = UDim2.fromOffset(math.clamp(pageTitle.TextBounds.X, 20, 140), 3) }, 0.28, Enum.EasingStyle.Quint) end)
			window.ActiveTab = self
			local y = self._btn.AbsolutePosition.Y - rail.AbsolutePosition.Y + self._btn.AbsoluteSize.Y * 0.5
			Tween(pill, { Position = UDim2.new(0, 0, 0, y) }, 0.22, Enum.EasingStyle.Back)
			-- cards stagger in
			local i = 0
			for _, c in ipairs(self._cols) do
				for _, card in ipairs(c:GetChildren()) do
					if card:IsA("Frame") then
						i = i + 1
						local sc = card:FindFirstChildOfClass("UIScale") or Create("UIScale", { Parent = card })
						sc.Scale = 0.97
						card.BackgroundTransparency = 1
						local delay = 0.025 * math.min(i, 8)
						task.delay(delay, function()
							Tween(sc, { Scale = 1 }, 0.26, Enum.EasingStyle.Back)
							Tween(card, { BackgroundTransparency = 0 }, 0.2)
						end)
					end
				end
			end
		end
		Press(btn, 0.92)
		btn.MouseButton1Click:Connect(function() tab:Select() end)

		function tab:AddSubTab(subName)
			local st = { Name = subName }
			local sb = Create("TextButton", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Text = "", AutoButtonColor = false, BackgroundTransparency = 1, LayoutOrder = #tab.Subtabs + 1, ZIndex = 13, Parent = subRow })
			Corner(sb, 9); Pad(sb, 14, 14, 0, 0); Library:AddToRegistry(sb, { BackgroundColor3 = "Element" })
			local sl = Text(sb, subName, 11, true, "FontDim"); sl.AutomaticSize = Enum.AutomaticSize.X; sl.Size = UDim2.new(0, 0, 1, 0); sl.ZIndex = 14
			local sub = Create("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 11, Parent = page })
			local sl2, sr2 = columns(sub, 40)
			st.Page, st.Left, st.Right, st._btn, st._label = sub, sl2, sr2, sb, sl
			function st:Select()
				for _, c in ipairs(tab._cols) do c.Visible = false end
				for _, o in ipairs(tab.Subtabs) do
					o.Page.Visible = false
					o._btn.BackgroundTransparency = 1
					Tween(o._label, { TextColor3 = Library.Theme.FontDim }, 0.1)
				end
				self.Page.Visible = true
				self._btn.BackgroundTransparency = 0
				Tween(self._label, { TextColor3 = Library.Theme.Font }, 0.1)
			end
			sb.MouseButton1Click:Connect(function() st:Select() end)
			st.AddLeftGroupbox = function(_, n) return window:_MakeGroupbox(sl2, n, name .. " / " .. subName, tab, st) end
			st.AddRightGroupbox = function(_, n) return window:_MakeGroupbox(sr2, n, name .. " / " .. subName, tab, st) end
			table.insert(tab.Subtabs, st)
			subRow.Visible = true
			relayout()
			if #tab.Subtabs == 1 then task.defer(function() st:Select() end) end
			return st
		end

		tab.AddLeftGroupbox = function(_, n) return window:_MakeGroupbox(l, n, name, tab) end
		tab.AddRightGroupbox = function(_, n) return window:_MakeGroupbox(r, n, name, tab) end
		table.insert(window.Tabs, tab)
		if #window.Tabs == 1 then task.defer(function() tab:Select() end) end
		return tab
	end

	-- ---------------------------------------------------------------- cards
	local gbOrder = 0
	function window:_MakeGroupbox(column, name, path, tabRef, subRef)
		gbOrder = gbOrder + 1
		local gb = { Name = name, Path = path .. " / " .. name }
		local card = Create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = gbOrder, ZIndex = 12, Parent = column })
		Library:AddToRegistry(card, { BackgroundColor3 = "Main" }); Corner(card, 14); Stroke(card, "Outline")
		local lip = Create("Frame", { Size = UDim2.new(1, -30, 0, 1), Position = UDim2.new(0, 15, 0, 0), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.9, BorderSizePixel = 0, ZIndex = 13, Parent = card })
		local head2 = Create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, ZIndex = 13, Parent = card })
		local mark = Create("Frame", { Size = UDim2.fromOffset(4, 16), Position = UDim2.new(0, 15, 0.5, -8), ZIndex = 14, Parent = head2 })
		Library:AddToRegistry(mark, { BackgroundColor3 = "Accent" }); Corner(mark, 2)
		Create("UIGradient", { Rotation = 90, Parent = mark }); Library:AddToRegistry(mark.UIGradient, { Color = "AccentGradient" })
		local t = Text(head2, string.upper(name), 11, true); t.Position = UDim2.new(0, 28, 0, 0); t.Size = UDim2.new(1, -44, 1, 0); t.ZIndex = 14
		local holder = Create("Frame", { Size = UDim2.new(1, -32, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 16, 0, 40), BackgroundTransparency = 1, ZIndex = 13, Parent = card })
		Pad(holder, 0, 0, 0, 14)
		Create("UIListLayout", { Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
		gb.Frame, gb.Holder, gb._order = card, holder, 0
		function gb:_next() self._order = self._order + 1 return self._order end
		function gb:_focus(el)
			if tabRef then tabRef:Select() end
			if subRef then subRef:Select() end
			show(true)
			if el then local s = Stroke(el, "Accent", 1) task.delay(1.5, function() Library:RemoveFromRegistry(s) s:Destroy() end) end
		end
		setmetatable(gb, { __index = Library.GroupboxMethods })
		return gb
	end

	task.defer(function() show(visible) end)
	table.insert(self.Windows, window)
	return window
end

-- ================================================================ elements
local GroupboxMethods = {}
Library.GroupboxMethods = GroupboxMethods

local function row(gb, h)
	return Create("Frame", { Size = UDim2.new(1, 0, 0, h or 18), BackgroundTransparency = 1, LayoutOrder = gb:_next(), ZIndex = 4, Parent = gb.Holder })
end
local function reg(gb, name, frame) Library:RegisterSearch(name, gb.Path, function() gb:_focus(frame) end) end
local function slotHolder(frame)
	local h = frame:FindFirstChild("_slots")
	if h then return h end
	h = Create("Frame", { Name = "_slots", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, ZIndex = 6, Parent = frame })
	Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = h })
	return h
end
-- keeps a row's text from ever running under its pickers
local function bindLabelWidth(label, frame, leftInset)
	local h = frame:FindFirstChild("_slots")
	local function fit()
		local w = h and h.AbsoluteSize.X or 0
		label.Size = UDim2.new(1, -(leftInset + (w > 0 and (w + 8) or 0)), label.Size.Y.Scale, label.Size.Y.Offset)
	end
	if h then h:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit) end
	fit()
	return fit
end

-- label / divider ------------------------------------------------------------
function GroupboxMethods:AddLabel(text, wrap)
	local f = row(self, 14)
	local l = Text(f, text, 11, false, "FontDim"); l.Size = UDim2.new(1, 0, 0, 14); l.ZIndex = 5
	if wrap then l.TextWrapped = true l.AutomaticSize = Enum.AutomaticSize.Y f.AutomaticSize = Enum.AutomaticSize.Y l.TextTruncate = Enum.TextTruncate.None end
	local obj = { Frame = f, TextLabel = l }
	function obj:SetText(t) l.Text = t end
	function obj:AddKeyPicker(idx, cfg) local k = Library._AttachKeyPicker(self, f, idx, cfg) bindLabelWidth(l, f, 0) return k end
	function obj:AddColorPicker(idx, cfg) local c = Library._AttachColorPicker(self, f, idx, cfg) bindLabelWidth(l, f, 0) return c end
	return obj
end
function GroupboxMethods:AddDivider()
	local f = row(self, 5)
	local line = Create("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0.5, 0), BorderSizePixel = 0, ZIndex = 5, Parent = f })
	Library:AddToRegistry(line, { BackgroundColor3 = "Outline" })
	return { Frame = f }
end

-- button ---------------------------------------------------------------------
local function makeButton(parent, cfg, size, pos)
	local b = Create("TextButton", { Size = size, Position = pos or UDim2.new(0, 0, 0, 0), Text = "", AutoButtonColor = false, ZIndex = 5, Parent = parent })
	Library:AddToRegistry(b, { BackgroundColor3 = "Element" }); Corner(b, 8); Stroke(b, cfg.Risky and "Risky" or "Outline")
	local l = Text(b, cfg.Text or "button", 11, true, cfg.Risky and "Risky" or "Font"); l.TextXAlignment = Enum.TextXAlignment.Center; l.Size = UDim2.new(1, 0, 1, 0); l.ZIndex = 6
	Hover(b, "Element", "ElementHover")
	Ripple(b); Press(b)
	local armed = false
	b.MouseButton1Click:Connect(function()
		if cfg.DoubleClick then
			if armed then armed = false l.Text = cfg.Text pcall(cfg.Func)
			else armed = true l.Text = "confirm?" task.delay(1.5, function() armed = false l.Text = cfg.Text end) end
		else pcall(cfg.Func) end
	end)
	return b, l
end
function GroupboxMethods:AddButton(cfg, func)
	if type(cfg) == "string" then cfg = { Text = cfg, Func = func } end
	local f = row(self, 22)
	local b, l = makeButton(f, cfg, UDim2.new(1, 0, 1, 0))
	reg(self, cfg.Text or "button", f)
	local obj = { Frame = f, Button = b }
	function obj:SetText(t) l.Text = t end
	function obj:AddButton(cfg2, func2)
		if type(cfg2) == "string" then cfg2 = { Text = cfg2, Func = func2 } end
		b.Size = UDim2.new(0.5, -2, 1, 0)
		local b2, l2 = makeButton(f, cfg2, UDim2.new(0.5, -2, 1, 0), UDim2.new(0.5, 2, 0, 0))
		reg(self, cfg2.Text or "button", f)
		return { Frame = f, Button = b2, SetText = function(_, t) l2.Text = t end }
	end
	return obj
end

-- toggle (square checkbox) ---------------------------------------------------
function GroupboxMethods:AddToggle(idx, cfg)
	cfg = cfg or {}
	local f = row(self, 20)
	local hit = Create("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = f })
	local box = Create("Frame", { Size = UDim2.fromOffset(30, 16), Position = UDim2.new(0, 0, 0.5, -8), ZIndex = 5, Parent = f })
	Library:AddToRegistry(box, { BackgroundColor3 = "Element" }); Corner(box, 8); local bs = Stroke(box, "Outline")
	local fill = Create("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 6, Parent = box })
	Corner(fill, 8); Create("UIGradient", { Rotation = 15, Parent = fill }); Library:AddToRegistry(fill.UIGradient, { Color = "AccentGradient" })
	local knobT = Create("Frame", { Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, 2, 0.5, -6), BackgroundColor3 = Color3.fromRGB(190, 190, 196), BorderSizePixel = 0, ZIndex = 7, Parent = box })
	Corner(knobT, 6)
	local l = Text(f, cfg.Text or idx, 12, false); l.Position = UDim2.new(0, 40, 0, 0); l.Size = UDim2.new(1, -40, 1, 0); l.ZIndex = 5
	local fitLabel = function() bindLabelWidth(l, f, 40) end
	local obj = { Frame = f, Value = cfg.Default and true or false, Type = "Toggle", Idx = idx, Callback = cfg.Callback, _changed = {} }
	local function render()
		local on = obj.Value
		Tween(fill, { BackgroundTransparency = on and 0 or 1 }, 0.16)
		Tween(knobT, { Position = on and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6), BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(190, 190, 196) }, 0.2, Enum.EasingStyle.Back)
		bs.Color = on and Library.Theme.Accent or Library.Theme.Outline
		Library.Registry[bs] = obj.Value and { Color = "Accent" } or { Color = "Outline" }
		Tween(l, { TextColor3 = obj.Value and Library.Theme.Font or Library.Theme.FontDim }, 0.1)
		Library.Registry[l] = obj.Value and { TextColor3 = "Font" } or { TextColor3 = "FontDim" }
	end
	function obj:SetValue(v, silent)
		self.Value = v and true or false
		render()
		if not silent then
			if self.Callback then pcall(self.Callback, self.Value) end
			for _, fn in ipairs(self._changed) do pcall(fn, self.Value) end
		end
	end
	function obj:OnChanged(fn) table.insert(self._changed, fn) end
	function obj:SetText(t) l.Text = t end
	function obj:AddKeyPicker(kidx, kcfg) local k = Library._AttachKeyPicker(self, f, kidx, kcfg) fitLabel() return k end
	function obj:AddColorPicker(cidx, ccfg) local c = Library._AttachColorPicker(self, f, cidx, ccfg) fitLabel() return c end
	hit.MouseButton1Click:Connect(function() obj:SetValue(not obj.Value) end)
	hit.MouseEnter:Connect(function() if not obj.Value then Tween(l, { TextColor3 = Library.Theme.Font }, 0.1) end end)
	hit.MouseLeave:Connect(function() if not obj.Value then Tween(l, { TextColor3 = Library.Theme.FontDim }, 0.1) end end)
	render()
	if cfg.Default and cfg.Callback then task.defer(function() pcall(cfg.Callback, true) end) end
	Library.Toggles[idx] = obj
	reg(self, cfg.Text or idx, f)
	return obj
end

-- slider ---------------------------------------------------------------------
function GroupboxMethods:AddSlider(idx, cfg)
	cfg = cfg or {}
	local compact = cfg.Compact
	local f = row(self, compact and 16 or 34)
	local l = Text(f, cfg.Text or idx, 11, false, "FontDim"); l.Size = UDim2.new(1, -70, 0, 14); l.ZIndex = 5; l.Visible = not compact
	local val = Text(f, "", 11, true); val.TextXAlignment = Enum.TextXAlignment.Right; val.Size = UDim2.new(0, 70, 0, 14); val.Position = UDim2.new(1, -70, 0, 0); val.ZIndex = 5; val.Visible = not compact
	local track = Create("Frame", { Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 0, compact and 4 or 22), ZIndex = 5, Parent = f })
	Library:AddToRegistry(track, { BackgroundColor3 = "Element" }); Corner(track, 4); Stroke(track, "Outline")
	local fill = Create("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, ZIndex = 6, Parent = track }); Corner(fill, 4)
	Create("UIGradient", { Parent = fill }); Library:AddToRegistry(fill.UIGradient, { Color = "AccentGradient" })
	local knob = Create("Frame", { Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BorderSizePixel = 0, ZIndex = 7, Parent = track })
	Library:AddToRegistry(knob, { BackgroundColor3 = "Font" }); Corner(knob, 5)
	local hit = Create("TextButton", { Size = UDim2.new(1, 0, 1, 10), Position = UDim2.new(0, 0, 0, -5), BackgroundTransparency = 1, Text = "", ZIndex = 8, Parent = track })
	local min, max = cfg.Min or 0, cfg.Max or 100
	local rounding = cfg.Rounding or 0
	local obj = { Frame = f, Value = cfg.Default or min, Type = "Slider", Idx = idx, Callback = cfg.Callback, Min = min, Max = max, _changed = {} }
	local function fmt(v) return (cfg.Prefix or "") .. string.format("%." .. rounding .. "f", v) .. (cfg.Suffix or "") end
	local function render()
		local a = math.clamp((obj.Value - min) / math.max(max - min, 1e-9), 0, 1)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		val.Text = fmt(obj.Value)
	end
	function obj:SetValue(v, silent)
		v = math.clamp(tonumber(v) or min, min, max)
		local m = 10 ^ rounding
		self.Value = math.floor(v * m + 0.5) / m
		render()
		if not silent then
			if self.Callback then pcall(self.Callback, self.Value) end
			for _, fn in ipairs(self._changed) do pcall(fn, self.Value) end
		end
	end
	function obj:SetMax(m) max = m self.Max = m self:SetValue(self.Value, true) end
	function obj:SetMin(m) min = m self.Min = m self:SetValue(self.Value, true) end
	function obj:OnChanged(fn) table.insert(self._changed, fn) end
	local dragging = false
	local function fromX(x) obj:SetValue(min + (max - min) * math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)) end
	hit.InputBegan:Connect(function(inp) if IsPressed(inp) then dragging = true Tween(knob, { Size = UDim2.fromOffset(14, 14) }, 0.12, Enum.EasingStyle.Back) fromX(inp.Position.X) end end)
	Library:GiveSignal(UserInputService.InputChanged:Connect(function(inp) if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then fromX(inp.Position.X) end end))
	Library:GiveSignal(UserInputService.InputEnded:Connect(function(inp) if IsPressed(inp) then if dragging then Tween(knob, { Size = UDim2.fromOffset(10, 10) }, 0.14) end dragging = false end end))
	render()
	Library.Options[idx] = obj
	reg(self, cfg.Text or idx, f)
	return obj
end

-- input ----------------------------------------------------------------------
function GroupboxMethods:AddInput(idx, cfg)
	cfg = cfg or {}
	local f = row(self, 36)
	local l = Text(f, cfg.Text or idx, 11, false, "FontDim"); l.Size = UDim2.new(1, 0, 0, 14); l.ZIndex = 5
	local boxF = Create("Frame", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 16), ZIndex = 5, Parent = f })
	Library:AddToRegistry(boxF, { BackgroundColor3 = "Element" }); Corner(boxF, 8); local st = Stroke(boxF, "Outline")
	local tb = Create("TextBox", { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0), BackgroundTransparency = 1, Text = cfg.Default or "", PlaceholderText = cfg.Placeholder or "", TextSize = 11, FontFace = Library.FontFace, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 6, Parent = boxF })
	Library:AddToRegistry(tb, { TextColor3 = "Font", PlaceholderColor3 = "FontDim" })
	local obj = { Frame = f, Value = cfg.Default or "", Type = "Input", Idx = idx, Callback = cfg.Callback, _changed = {} }
	local function fire()
		if cfg.Numeric and tb.Text ~= "" and not tonumber(tb.Text) then tb.Text = obj.Value return end
		obj.Value = tb.Text
		if obj.Callback then pcall(obj.Callback, obj.Value) end
		for _, fn in ipairs(obj._changed) do pcall(fn, obj.Value) end
	end
	tb.Focused:Connect(function() st.Color = Library.Theme.Accent end)
	tb.FocusLost:Connect(function() st.Color = Library.Theme.Outline fire() end)
	if not cfg.Finished then tb:GetPropertyChangedSignal("Text"):Connect(function() if tb:IsFocused() then fire() end end) end
	function obj:SetValue(v, silent) tb.Text = tostring(v or "") self.Value = tb.Text if not silent then fire() end end
	function obj:OnChanged(fn) table.insert(self._changed, fn) end
	Library.Options[idx] = obj
	reg(self, cfg.Text or idx, f)
	return obj
end

-- dropdown -------------------------------------------------------------------
function GroupboxMethods:AddDropdown(idx, cfg)
	cfg = cfg or {}
	local f = row(self, 36)
	local l = Text(f, cfg.Text or idx, 11, false, "FontDim"); l.Size = UDim2.new(1, 0, 0, 14); l.ZIndex = 5
	local btn = Create("TextButton", { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 0, 16), Text = "", AutoButtonColor = false, ZIndex = 5, Parent = f })
	Library:AddToRegistry(btn, { BackgroundColor3 = "Element" }); Corner(btn, 8); Stroke(btn, "Outline")
	local cur = Text(btn, "", 11, false); cur.Position = UDim2.new(0, 6, 0, 0); cur.Size = UDim2.new(1, -26, 1, 0); cur.ZIndex = 6
	local arrow = Text(btn, "▾", 12, true, "FontDim"); arrow.Position = UDim2.new(1, -16, 0, 0); arrow.Size = UDim2.new(0, 12, 1, 0); arrow.ZIndex = 6
	Hover(btn, "Element", "ElementHover")
	local list = Create("Frame", { Size = UDim2.new(0, 200, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 60, Parent = ScreenGui })
	Library:AddToRegistry(list, { BackgroundColor3 = "Main" }); Corner(list, 10); Stroke(list, "OutlineStrong"); Library.Shadow(list, 18)
	Pad(list, 3, 3, 3, 3)
	Create("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	Library.OpenPopups[list] = list
	local search = nil
	if cfg.Searchable then
		local sf = Create("Frame", { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 0, ZIndex = 61, Parent = list })
		Library:AddToRegistry(sf, { BackgroundColor3 = "Element" }); Corner(sf, 6)
		search = Create("TextBox", { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "search", TextSize = 11, FontFace = Library.FontFace, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 62, Parent = sf })
		Library:AddToRegistry(search, { TextColor3 = "Font", PlaceholderColor3 = "FontDim" })
	end
	local scroll = Create("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ZIndex = 61, Parent = list })
	Library:AddToRegistry(scroll, { ScrollBarImageColor3 = "Accent" })
	Create("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	Create("UISizeConstraint", { MaxSize = Vector2.new(9999, 190), Parent = scroll })
	local obj = { Frame = f, Values = cfg.Values or {}, Multi = cfg.Multi, Type = "Dropdown", Idx = idx, Callback = cfg.Callback, _changed = {} }
	if cfg.Multi then
		obj.Value = {}
		if type(cfg.Default) == "table" then for k, v in pairs(cfg.Default) do if type(k) == "string" and v then obj.Value[k] = true elseif type(v) == "string" then obj.Value[v] = true end end end
	else
		if type(cfg.Default) == "number" then obj.Value = obj.Values[cfg.Default] elseif type(cfg.Default) == "string" then obj.Value = cfg.Default end
	end
	local function display()
		if obj.Multi then
			local t = {}
			for _, v in ipairs(obj.Values) do if obj.Value[v] then t[#t + 1] = tostring(v) end end
			cur.Text = #t > 0 and table.concat(t, ", ") or "---"
		else cur.Text = obj.Value ~= nil and tostring(obj.Value) or "---" end
	end
	local function fire() if obj.Callback then pcall(obj.Callback, obj.Value) end for _, fn in ipairs(obj._changed) do pcall(fn, obj.Value) end end
	local function build()
		for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		local q = search and string.lower(search.Text) or ""
		for i, v in ipairs(obj.Values) do
			if q == "" or string.find(string.lower(tostring(v)), q, 1, true) then
				local selected = obj.Multi and obj.Value[v] or (not obj.Multi and obj.Value == v)
				local ib = Create("TextButton", { Size = UDim2.new(1, 0, 0, 20), Text = "", AutoButtonColor = false, LayoutOrder = i, ZIndex = 62, BackgroundTransparency = selected and 0 or 1, BackgroundColor3 = Library.Theme.Element, Parent = scroll })
				Corner(ib, 6)
				local il = Text(ib, tostring(v), 11, selected, selected and "Accent" or "FontDim"); il.Position = UDim2.new(0, 6, 0, 0); il.Size = UDim2.new(1, -12, 1, 0); il.ZIndex = 63
				ib.MouseEnter:Connect(function() ib.BackgroundTransparency = 0 ib.BackgroundColor3 = Library.Theme.ElementHover end)
				ib.MouseLeave:Connect(function() ib.BackgroundTransparency = selected and 0 or 1 ib.BackgroundColor3 = Library.Theme.Element end)
				ib.MouseButton1Click:Connect(function()
					if obj.Multi then
						if obj.Value[v] then obj.Value[v] = nil else obj.Value[v] = true end
						if not cfg.AllowNull and next(obj.Value) == nil then obj.Value[v] = true end
					else
						if cfg.AllowNull and obj.Value == v then obj.Value = nil else obj.Value = v end
						list.Visible = false
					end
					display() build() fire()
				end)
			end
		end
	end
	if search then search:GetPropertyChangedSignal("Text"):Connect(build) end
	btn.MouseButton1Click:Connect(function()
		Library:_ClosePopups(list)
		list.Size = UDim2.new(0, btn.AbsoluteSize.X, 0, 0)
		list.Position = UDim2.new(0, btn.AbsolutePosition.X, 0, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 3)
		build()
		if list.Visible then
			list.Visible = false
		else
			list.Visible = true
			local sc = list:FindFirstChildOfClass("UIScale") or Create("UIScale", { Parent = list })
			sc.Scale = 0.94
			Tween(sc, { Scale = 1 }, 0.22, Enum.EasingStyle.Back)
		end
		Tween(arrow, { Rotation = list.Visible and 180 or 0 }, 0.18)
	end)
	function obj:SetValues(vals)
		self.Values = vals or {}
		if self.Multi then for k in pairs(self.Value) do if not table.find(self.Values, k) then self.Value[k] = nil end end
		elseif self.Value ~= nil and not table.find(self.Values, self.Value) then self.Value = nil end
		display()
	end
	function obj:SetValue(v, silent)
		if self.Multi then
			self.Value = {}
			if type(v) == "table" then for k, on in pairs(v) do if type(k) == "string" and on then self.Value[k] = true elseif type(on) == "string" then self.Value[on] = true end end end
		else self.Value = v end
		display()
		if not silent then fire() end
	end
	function obj:OnChanged(fn) table.insert(self._changed, fn) end
	display()
	Library.Options[idx] = obj
	reg(self, cfg.Text or idx, f)
	return obj
end

-- color picker ---------------------------------------------------------------
local function toHex(c) return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
local function fromHex(s)
	s = tostring(s):gsub("#", "")
	if #s ~= 6 then return nil end
	local r, g, b = tonumber(s:sub(1, 2), 16), tonumber(s:sub(3, 4), 16), tonumber(s:sub(5, 6), 16)
	if not (r and g and b) then return nil end
	return Color3.fromRGB(r, g, b)
end

function Library._AttachColorPicker(parentObj, parentFrame, idx, cfg)
	cfg = cfg or {}
	local holder = slotHolder(parentFrame)
	local swatch = Create("TextButton", { Size = UDim2.fromOffset(22, 12), Text = "", AutoButtonColor = false, LayoutOrder = #holder:GetChildren(), ZIndex = 6, Parent = holder })
	Corner(swatch, 5); Stroke(swatch, "Outline")
	local swatchGrad = Create("UIGradient", { Enabled = false, Parent = swatch })
	local obj = { Frame = swatch, Type = "ColorPicker", Idx = idx, Callback = cfg.Callback, Gradient = cfg.Gradient, _changed = {} }
	obj.Value = cfg.Default or Color3.fromRGB(255, 255, 255)
	obj.Transparency = cfg.Transparency or 0
	obj.Value2 = cfg.Default2 or Color3.fromRGB(0, 0, 0)
	obj.Rotation = cfg.Rotation or 0
	local activeStop = 1

	local pop = Create("Frame", { Size = UDim2.new(0, 210, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 70, Parent = ScreenGui })
	Library:AddToRegistry(pop, { BackgroundColor3 = "Main" }); Corner(pop, 10); Stroke(pop, "OutlineStrong"); Library.Shadow(pop, 18)
	Pad(pop, 8, 8, 8, 8)
	Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pop })
	Library.OpenPopups[pop] = pop
	local tl = Text(pop, string.lower(cfg.Title or idx), 11, true, "Accent"); tl.LayoutOrder = 0; tl.ZIndex = 71; tl.Size = UDim2.new(1, 0, 0, 12)
	local sv = Create("ImageButton", { Size = UDim2.new(1, 0, 0, 110), LayoutOrder = 1, AutoButtonColor = false, ZIndex = 71, Image = "rbxassetid://4155801252", Parent = pop })
	Corner(sv, 8); Stroke(sv, "Outline")
	local svCursor = Create("Frame", { Size = UDim2.fromOffset(6, 6), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 73, Parent = sv }); Corner(svCursor, 3); Create("UIStroke", { Color = Color3.new(0, 0, 0), Parent = svCursor })
	local hue = Create("ImageButton", { Size = UDim2.new(1, 0, 0, 8), LayoutOrder = 2, AutoButtonColor = false, ZIndex = 71, Parent = pop })
	Corner(hue, 6)
	Create("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)), ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)) }), Parent = hue })
	local hueCursor = Create("Frame", { Size = UDim2.new(0, 2, 1, 4), Position = UDim2.new(0, 0, 0, -2), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 73, Parent = hue })
	local alpha, alphaCursor = nil, nil
	if cfg.Transparency ~= nil then
		alpha = Create("ImageButton", { Size = UDim2.new(1, 0, 0, 8), LayoutOrder = 3, AutoButtonColor = false, ZIndex = 71, Parent = pop })
		Corner(alpha, 6)
		Create("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0)), Parent = alpha })
		alphaCursor = Create("Frame", { Size = UDim2.new(0, 2, 1, 4), Position = UDim2.new(0, 0, 0, -2), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 73, Parent = alpha })
	end
	local hexF = Create("Frame", { Size = UDim2.new(1, 0, 0, 20), LayoutOrder = 4, ZIndex = 71, Parent = pop })
	Library:AddToRegistry(hexF, { BackgroundColor3 = "Element" }); Corner(hexF, 2); Stroke(hexF, "Outline")
	local hexBox = Create("TextBox", { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0), BackgroundTransparency = 1, Text = toHex(obj.Value), TextSize = 11, FontFace = Library.FontFace, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 72, Parent = hexF })
	Library:AddToRegistry(hexBox, { TextColor3 = "Font" })
	local stopA, stopB, rotSlider, prevGrad, rotFill = nil, nil, nil, nil, nil
	if cfg.Gradient then
		local g = Create("Frame", { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 5, BackgroundTransparency = 1, ZIndex = 71, Parent = pop })
		local prev = Create("Frame", { Size = UDim2.new(1, 0, 0, 12), ZIndex = 71, Parent = g }); Corner(prev, 2); Stroke(prev, "Outline")
		prevGrad = Create("UIGradient", { Parent = prev })
		stopA = Create("TextButton", { Size = UDim2.new(0.5, -2, 0, 18), Position = UDim2.new(0, 0, 0, 18), Text = "stop 1", TextSize = 10, FontFace = Library.FontFaceBold, AutoButtonColor = false, ZIndex = 72, Parent = g })
		stopB = Create("TextButton", { Size = UDim2.new(0.5, -2, 0, 18), Position = UDim2.new(0.5, 2, 0, 18), Text = "stop 2", TextSize = 10, FontFace = Library.FontFaceBold, AutoButtonColor = false, ZIndex = 72, Parent = g })
		for _, b in ipairs({ stopA, stopB }) do Corner(b, 8); Stroke(b, "Outline"); Library:AddToRegistry(b, { BackgroundColor3 = "Element", TextColor3 = "Font" }) end
		local rr = Create("Frame", { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 6, BackgroundTransparency = 1, ZIndex = 71, Parent = pop })
		local rl = Text(rr, "rotation", 10, false, "FontDim"); rl.Size = UDim2.new(0, 56, 1, 0); rl.ZIndex = 72
		rotSlider = Create("TextButton", { Size = UDim2.new(1, -60, 0, 6), Position = UDim2.new(0, 60, 0.5, -3), Text = "", AutoButtonColor = false, ZIndex = 72, Parent = rr })
		Library:AddToRegistry(rotSlider, { BackgroundColor3 = "Element" }); Corner(rotSlider, 2); Stroke(rotSlider, "Outline")
		rotFill = Create("Frame", { Size = UDim2.new(obj.Rotation / 360, 0, 1, 0), BorderSizePixel = 0, ZIndex = 73, Parent = rotSlider }); Corner(rotFill, 2)
		Library:AddToRegistry(rotFill, { BackgroundColor3 = "Accent" })
	end
	local function currentColor() return activeStop == 1 and obj.Value or obj.Value2 end
	local function render()
		local col = currentColor()
		swatch.BackgroundColor3 = obj.Value
		swatch.BackgroundTransparency = obj.Transparency
		if cfg.Gradient then
			swatchGrad.Enabled = true swatchGrad.Color = ColorSequence.new(obj.Value, obj.Value2) swatchGrad.Rotation = obj.Rotation
			prevGrad.Color = ColorSequence.new(obj.Value, obj.Value2) prevGrad.Rotation = obj.Rotation
			stopA.TextColor3 = activeStop == 1 and Library.Theme.Accent or Library.Theme.Font
			stopB.TextColor3 = activeStop == 2 and Library.Theme.Accent or Library.Theme.Font
			rotFill.Size = UDim2.new(obj.Rotation / 360, 0, 1, 0)
		end
		local hh, ss, vv = col:ToHSV()
		sv.BackgroundColor3 = Color3.fromHSV(hh, 1, 1)
		svCursor.Position = UDim2.new(ss, 0, 1 - vv, 0)
		hueCursor.Position = UDim2.new(hh, -1, 0, -2)
		if alphaCursor then alphaCursor.Position = UDim2.new(obj.Transparency, -1, 0, -2) end
		if not hexBox:IsFocused() then hexBox.Text = toHex(col) end
	end
	local function fire()
		if obj.Callback then
			if cfg.Gradient then pcall(obj.Callback, ColorSequence.new(obj.Value, obj.Value2), obj.Rotation) else pcall(obj.Callback, obj.Value, obj.Transparency) end
		end
		for _, fn in ipairs(obj._changed) do pcall(fn, obj.Value, obj.Transparency) end
	end
	local function setCurrent(c) if activeStop == 1 then obj.Value = c else obj.Value2 = c end render() fire() end
	local svD, hueD, aD, rD = false, false, false, false
	local function svAt(p) local a, s = sv.AbsolutePosition, sv.AbsoluteSize local hh = select(1, currentColor():ToHSV()) setCurrent(Color3.fromHSV(hh, math.clamp((p.X - a.X) / s.X, 0, 1), 1 - math.clamp((p.Y - a.Y) / s.Y, 0, 1))) end
	local function hueAt(p) local a, s = hue.AbsolutePosition, hue.AbsoluteSize local _, ss, vv = currentColor():ToHSV() setCurrent(Color3.fromHSV(math.clamp((p.X - a.X) / s.X, 0, 0.999), ss, vv)) end
	local function alphaAt(p) local a, s = alpha.AbsolutePosition, alpha.AbsoluteSize obj.Transparency = math.clamp((p.X - a.X) / s.X, 0, 1) render() fire() end
	local function rotAt(p) local a, s = rotSlider.AbsolutePosition, rotSlider.AbsoluteSize obj.Rotation = math.floor(math.clamp((p.X - a.X) / s.X, 0, 1) * 360) render() fire() end
	sv.InputBegan:Connect(function(inp) if IsPressed(inp) then svD = true svAt(inp.Position) end end)
	hue.InputBegan:Connect(function(inp) if IsPressed(inp) then hueD = true hueAt(inp.Position) end end)
	if alpha then alpha.InputBegan:Connect(function(inp) if IsPressed(inp) then aD = true alphaAt(inp.Position) end end) end
	if rotSlider then rotSlider.InputBegan:Connect(function(inp) if IsPressed(inp) then rD = true rotAt(inp.Position) end end) end
	Library:GiveSignal(UserInputService.InputChanged:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
			if svD then svAt(inp.Position) elseif hueD then hueAt(inp.Position) elseif aD then alphaAt(inp.Position) elseif rD then rotAt(inp.Position) end
		end
	end))
	Library:GiveSignal(UserInputService.InputEnded:Connect(function(inp) if IsPressed(inp) then svD, hueD, aD, rD = false, false, false, false end end))
	hexBox.FocusLost:Connect(function() local c = fromHex(hexBox.Text) if c then setCurrent(c) else render() end end)
	if stopA then stopA.MouseButton1Click:Connect(function() activeStop = 1 render() end) stopB.MouseButton1Click:Connect(function() activeStop = 2 render() end) end
	swatch.MouseButton1Click:Connect(function()
		Library:_ClosePopups(pop)
		pop.Position = UDim2.new(0, swatch.AbsolutePosition.X + swatch.AbsoluteSize.X - 210, 0, swatch.AbsolutePosition.Y + swatch.AbsoluteSize.Y + 4)
		pop.Visible = not pop.Visible
	end)
	function obj:SetValueRGB(c, t, silent) self.Value = c if t then self.Transparency = t end render() if not silent then fire() end end
	function obj:SetValue(c, t, silent) self:SetValueRGB(c, t, silent) end
	function obj:SetValue2(c, silent) self.Value2 = c render() if not silent then fire() end end
	function obj:SetRotation(r, silent) self.Rotation = r render() if not silent then fire() end end
	function obj:GetSequence() return ColorSequence.new(self.Value, self.Value2) end
	function obj:OnChanged(fn) table.insert(self._changed, fn) end
	render()
	Library.Options[idx] = obj
	return obj
end
function GroupboxMethods:AddColorPicker(idx, cfg)
	cfg = cfg or {}
	local f = row(self, 16)
	local l = Text(f, cfg.Text or idx, 12, false); l.Size = UDim2.new(1, -30, 1, 0); l.ZIndex = 5
	local obj = Library._AttachColorPicker(nil, f, idx, cfg)
	obj.Frame = f
	reg(self, cfg.Text or idx, f)
	return obj
end

-- key picker -----------------------------------------------------------------
local KEY_NAMES = { MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3", LeftControl = "LCtrl", RightControl = "RCtrl", LeftShift = "LShift", RightShift = "RShift", LeftAlt = "LAlt", RightAlt = "RAlt" }
local function keyName(k) if typeof(k) == "EnumItem" then return KEY_NAMES[k.Name] or k.Name end return tostring(k) end

function Library._AttachKeyPicker(parentObj, parentFrame, idx, cfg)
	cfg = cfg or {}
	local holder = slotHolder(parentFrame)
	local btn = Create("TextButton", { Size = UDim2.new(0, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.X, Text = "", AutoButtonColor = false, LayoutOrder = #holder:GetChildren(), ZIndex = 6, Parent = holder })
	Pad(btn, 4, 4, 0, 0)
	local kl = Text(btn, "", 10, true, "Accent"); kl.AutomaticSize = Enum.AutomaticSize.X; kl.Size = UDim2.new(0, 0, 1, 0); kl.ZIndex = 7
	local obj = { Frame = btn, Type = "KeyPicker", Idx = idx, Mode = cfg.Mode or "Toggle", Value = cfg.Default or "None", Toggled = false, Callback = cfg.Callback, ChangedCallback = cfg.ChangedCallback, SyncToggleState = cfg.SyncToggleState, Text = cfg.Text or idx, _changed = {} }
	local binding = false
	local menu = Create("Frame", { Size = UDim2.new(0, 70, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 70, Parent = ScreenGui })
	Library:AddToRegistry(menu, { BackgroundColor3 = "Main" }); Corner(menu, 10); Stroke(menu, "OutlineStrong"); Library.Shadow(menu, 14); Pad(menu, 3, 3, 3, 3)
	Create("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })
	Library.OpenPopups[menu] = menu
	local modeLbls = {}
	for i, mode in ipairs(cfg.Modes or { "Always", "Toggle", "Hold" }) do
		local mb = Create("TextButton", { Size = UDim2.new(1, 0, 0, 18), Text = "", AutoButtonColor = false, LayoutOrder = i, ZIndex = 71, Parent = menu })
		Corner(mb, 6)
		local ml = Text(mb, string.lower(mode), 10, true, "FontDim"); ml.TextXAlignment = Enum.TextXAlignment.Center; ml.Size = UDim2.new(1, 0, 1, 0); ml.ZIndex = 72
		mb.MouseButton1Click:Connect(function() obj.Mode = mode menu.Visible = false obj:_render() end)
		modeLbls[mode] = ml
	end
	local kbRow = nil
	if not cfg.NoUI then
		kbRow = Create("Frame", { Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1, Visible = false, LayoutOrder = 1, Parent = KeybindFrame })
		local kn = Text(kbRow, string.lower(obj.Text), 10, false); kn.Size = UDim2.new(1, -46, 1, 0)
		obj._kbv = Text(kbRow, "", 10, true, "Accent"); obj._kbv.TextXAlignment = Enum.TextXAlignment.Right; obj._kbv.Size = UDim2.new(0, 46, 1, 0); obj._kbv.Position = UDim2.new(1, -46, 0, 0)
	end
	function obj:_render()
		kl.Text = binding and "[...]" or ("[" .. keyName(self.Value) .. "]")
		for mode, ml in pairs(modeLbls) do ml.TextColor3 = (mode == self.Mode) and Library.Theme.Accent or Library.Theme.FontDim end
		if kbRow then kbRow.Visible = self.Value ~= "None" self._kbv.Text = keyName(self.Value) .. (self:GetState() and " ●" or "") end
	end
	function obj:GetState() if self.Mode == "Always" then return true elseif self.Mode == "Hold" then return self._held == true end return self.Toggled end
	function obj:SetValue(v, silent)
		if type(v) == "table" then self.Mode = v[2] or self.Mode v = v[1] end
		if typeof(v) == "string" then
			if v == "None" then self.Value = "None" else
				local ok, k = pcall(function() return Enum.KeyCode[v] end)
				if ok and k then self.Value = k else local ok2, m = pcall(function() return Enum.UserInputType[v] end) self.Value = (ok2 and m) or "None" end
			end
		else self.Value = v end
		self:_render()
		if not silent and self.ChangedCallback then pcall(self.ChangedCallback, self.Value) end
	end
	function obj:OnClick(fn) table.insert(self._changed, fn) end
	function obj:OnChanged(fn) self.ChangedCallback = fn end
	local function doToggle()
		if obj.Mode == "Toggle" then
			obj.Toggled = not obj.Toggled
			if obj.SyncToggleState and parentObj and parentObj.SetValue then parentObj:SetValue(obj.Toggled) end
		end
		if obj.Callback then pcall(obj.Callback, obj:GetState()) end
		for _, fn in ipairs(obj._changed) do pcall(fn, obj:GetState()) end
		obj:_render()
	end
	btn.MouseButton1Click:Connect(function() binding = true obj:_render() end)
	btn.MouseButton2Click:Connect(function() Library:_ClosePopups(menu) menu.Position = UDim2.new(0, btn.AbsolutePosition.X, 0, btn.AbsolutePosition.Y + 18) menu.Visible = not menu.Visible end)
	Library:GiveSignal(UserInputService.InputBegan:Connect(function(inp, gpe)
		if binding then
			if inp.UserInputType == Enum.UserInputType.Keyboard then binding = false obj:SetValue(inp.KeyCode == Enum.KeyCode.Escape and "None" or inp.KeyCode)
			elseif inp.UserInputType == Enum.UserInputType.MouseButton2 or inp.UserInputType == Enum.UserInputType.MouseButton3 then binding = false obj:SetValue(inp.UserInputType) end
			return
		end
		if gpe then return end
		local match = (inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == obj.Value) or (inp.UserInputType == obj.Value)
		if match then
			if obj.Mode == "Hold" then obj._held = true if obj.Callback then pcall(obj.Callback, true) end obj:_render() else doToggle() end
		end
	end))
	Library:GiveSignal(UserInputService.InputEnded:Connect(function(inp)
		local match = (inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == obj.Value) or (inp.UserInputType == obj.Value)
		if match and obj.Mode == "Hold" then obj._held = false if obj.Callback then pcall(obj.Callback, false) end obj:_render() end
	end))
	if parentObj and parentObj.OnChanged and obj.SyncToggleState then parentObj:OnChanged(function(v) obj.Toggled = v obj:_render() end) end
	obj:_render()
	Library.Options[idx] = obj
	return obj
end
function GroupboxMethods:AddKeyPicker(idx, cfg)
	cfg = cfg or {}
	local f = row(self, 16)
	local l = Text(f, cfg.Text or idx, 12, false); l.Size = UDim2.new(1, -60, 1, 0); l.ZIndex = 5
	local obj = Library._AttachKeyPicker(nil, f, idx, cfg)
	obj.Frame = f
	reg(self, cfg.Text or idx, f)
	return obj
end

-- ================================================================ ESP preview (viewport)
function GroupboxMethods:AddESPPreview(cfg)
	cfg = cfg or {}
	local tabsCfg = cfg.Tabs or { "Enemy", "Team" }
	local f = row(self, 214)
	local tabBar = Create("Frame", { Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, ZIndex = 5, Parent = f })
	Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabBar })
	local canvas = Create("Frame", { Size = UDim2.new(1, 0, 0, 190), Position = UDim2.new(0, 0, 0, 24), ClipsDescendants = true, ZIndex = 5, Parent = f })
	Library:AddToRegistry(canvas, { BackgroundColor3 = "Background" }); Corner(canvas, 10); Stroke(canvas, "Outline")
	local vp = Create("ViewportFrame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Ambient = Color3.fromRGB(120, 120, 130), LightColor = Color3.fromRGB(255, 255, 255), LightDirection = Vector3.new(-1, -1.5, -1), ZIndex = 6, Parent = canvas })
	local wm = Create("WorldModel", { Parent = vp })
	local cam = Create("Camera", { FieldOfView = 40, Parent = vp })
	vp.CurrentCamera = cam
	local dummy = nil
	pcall(function()
		local ok, m = pcall(function() return Players:CreateHumanoidModelFromUserId(LocalPlayer.UserId) end)
		if not ok or not m then m = Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15) end
		m.Parent = wm
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hum then hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
		m:PivotTo(CFrame.new(0, 0, 0))
		dummy = m
	end)
	if not dummy then
		dummy = Instance.new("Model")
		for _, spec in ipairs({ { "Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0) }, { "Torso", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0) }, { "LA", Vector3.new(1, 2, 1), Vector3.new(-1.5, 0, 0) }, { "RA", Vector3.new(1, 2, 1), Vector3.new(1.5, 0, 0) }, { "LL", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0) }, { "RL", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0) } }) do
			Create("Part", { Name = spec[1], Size = spec[2], CFrame = CFrame.new(spec[3]), Anchored = true, Color = Color3.fromRGB(90, 90, 100), Material = Enum.Material.SmoothPlastic, Parent = dummy })
		end
		dummy.Parent = wm
	end
	local preview = { Frame = f, Tabs = {}, Active = nil, _tracked = {} }
	local angle = 0
	local function project(world)
		local rel = cam.CFrame:PointToObjectSpace(world)
		if rel.Z > -0.05 then return nil end
		local sz = canvas.AbsoluteSize
		if sz.X < 1 or sz.Y < 1 then return nil end
		local tanHalf = math.tan(math.rad(cam.FieldOfView) * 0.5)
		local px = (rel.X / -rel.Z) / (tanHalf * (sz.X / sz.Y))
		local py = (rel.Y / -rel.Z) / tanHalf
		return Vector2.new((px * 0.5 + 0.5) * sz.X, (0.5 - py * 0.5) * sz.Y)
	end
	local spin = Library:GiveSignal(RunService.RenderStepped:Connect(function(dt)
		if not canvas.Visible or not f:IsDescendantOf(ScreenGui) then return end
		angle = angle + dt * 0.5
		local boxCf, extents = dummy:GetBoundingBox()
		local pivot = boxCf.Position
		cam.CFrame = CFrame.new(pivot + Vector3.new(math.sin(angle) * 9, 1.2, math.cos(angle) * 9), pivot + Vector3.new(0, 0.2, 0))
		local hx, hy, hz = extents.X * 0.5, extents.Y * 0.5, extents.Z * 0.5
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for i = 0, 7 do
			local c = boxCf * CFrame.new((i % 2 == 0) and -hx or hx, (math.floor(i / 2) % 2 == 0) and -hy or hy, (i < 4) and -hz or hz)
			local p = project(c.Position)
			if not p then return end
			if p.X < minX then minX = p.X end
			if p.Y < minY then minY = p.Y end
			if p.X > maxX then maxX = p.X end
			if p.Y > maxY then maxY = p.Y end
		end
		local w, h = maxX - minX, maxY - minY
		local cx, cy = minX + w * 0.5, minY + h * 0.5
		for _, t in ipairs(preview._tracked) do
			if t.Page.Visible then
				local P = t.Parts
				P.Box.Size = UDim2.fromOffset(math.floor(w + 0.5), math.floor(h + 0.5))
				P.Box.Position = UDim2.fromOffset(math.floor(cx + 0.5), math.floor(cy + 0.5))
				local top = math.floor(minY) - 6
				P.Name.Position = UDim2.fromOffset(math.floor(cx + 0.5), top - 17)
				P.Distance.Position = UDim2.fromOffset(math.floor(cx + 0.5), top - 4)
				P.HealthBg.Position = UDim2.fromOffset(math.floor(cx + 0.5), top)
				P.Weapon.Position = UDim2.fromOffset(math.floor(cx + 0.5), math.floor(maxY) + 4)
				local ox, oy = canvas.AbsoluteSize.X * 0.5, canvas.AbsoluteSize.Y
				local dx, dy = cx - ox, maxY - oy
				local len = math.sqrt(dx * dx + dy * dy)
				P.Tracer.Size = UDim2.fromOffset(1, math.floor(len + 0.5))
				P.Tracer.Position = UDim2.fromOffset(math.floor(ox), math.floor(oy))
				P.Tracer.Rotation = -math.deg(math.atan2(dx, -dy))
			end
		end
	end))
	for i, name in ipairs(tabsCfg) do
		local page = Create("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, ZIndex = 7, Parent = canvas })
		local box = Create("Frame", { Size = UDim2.new(0, 64, 0, 132), Position = UDim2.new(0.5, -32, 0.5, -66), BackgroundTransparency = 1, ZIndex = 8, Parent = page })
		box.AnchorPoint = Vector2.new(0.5, 0.5)
		local boxStroke = Create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 1, Parent = box })
		-- same card the in-game ESP draws: Code font, hard black stroke, name over "[dist] hp/max", flat bar under it
		local nameL = Create("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(0, 160, 0, 14), Position = UDim2.new(0.5, 0, 0.5, -80), BackgroundTransparency = 1, Text = "player", TextSize = 13, FontFace = Library.ESPFont, TextColor3 = Color3.fromRGB(255, 255, 255), TextStrokeColor3 = Color3.fromRGB(0, 0, 0), TextStrokeTransparency = 0, ZIndex = 9, Parent = page })
		local distL = Create("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(0, 160, 0, 12), Position = UDim2.new(0.5, 0, 0.5, -66), BackgroundTransparency = 1, Text = "[42] 180/250", TextSize = 11, FontFace = Library.ESPFont, TextColor3 = Color3.fromRGB(220, 220, 220), TextStrokeColor3 = Color3.fromRGB(0, 0, 0), TextStrokeTransparency = 0, ZIndex = 9, Parent = page })
		local weapon = Create("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 160, 0, 12), Position = UDim2.new(0.5, 0, 0.5, 74), BackgroundTransparency = 1, Text = "weapon", TextSize = 11, FontFace = Library.ESPFont, TextColor3 = Color3.fromRGB(220, 220, 220), TextStrokeColor3 = Color3.fromRGB(0, 0, 0), TextStrokeTransparency = 0, ZIndex = 9, Parent = page })
		local hpBg = Create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(0, 60, 0, 3), Position = UDim2.new(0.5, 0, 0.5, -52), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 1, BorderColor3 = Color3.fromRGB(0, 0, 0), ZIndex = 9, Parent = page })
		local hp = Create("Frame", { Size = UDim2.fromScale(0.72, 1), BackgroundColor3 = Color3.fromRGB(71, 255, 0), BorderSizePixel = 0, ZIndex = 10, Parent = hpBg })
		local tracer = Create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.new(0, 1, 0, 70), Position = UDim2.new(0.5, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 8, Parent = page })
		local tab = { Name = name, Page = page, Parts = { Box = box, BoxStroke = boxStroke, Name = nameL, Distance = distL, HealthBg = hpBg, Health = hp, Tracer = tracer, Weapon = weapon } }
		preview._tracked = preview._tracked or {}
		table.insert(preview._tracked, tab)
		function tab:SetText(which, text)
			local p = self.Parts[which]
			if p and p:IsA("TextLabel") then p.Text = text end
		end
		function tab:SetHealth(frac)
			frac = math.clamp(frac or 1, 0, 1)
			self.Parts.Health.Size = UDim2.fromScale(frac, 1)
			self.Parts.Health.BackgroundColor3 = Color3.fromRGB(math.floor(255 * (1 - frac)), math.floor(255 * frac), 0)
		end
		function tab:Set(settings)
			for key, val in pairs(settings) do
				local part = self.Parts[key]
				if part then
					if typeof(val) == "boolean" then part.Visible = val
					elseif typeof(val) == "Color3" then
						if part:IsA("TextLabel") then part.TextColor3 = val elseif key == "Box" then self.Parts.BoxStroke.Color = val else part.BackgroundColor3 = val end
					end
				end
			end
		end
		local tb = Create("TextButton", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Text = "", AutoButtonColor = false, LayoutOrder = i, ZIndex = 6, Parent = tabBar })
		Library:AddToRegistry(tb, { BackgroundColor3 = "Element" }); Corner(tb, 7); Stroke(tb, "Outline"); Pad(tb, 8, 8, 0, 0)
		local tl = Text(tb, string.lower(name), 10, true, "FontDim"); tl.AutomaticSize = Enum.AutomaticSize.X; tl.Size = UDim2.new(0, 0, 1, 0); tl.ZIndex = 7
		tab._label = tl
		function tab:Select()
			for _, o in ipairs(preview.Tabs) do o.Page.Visible = false o._label.TextColor3 = Library.Theme.FontDim end
			self.Page.Visible = true self._label.TextColor3 = Library.Theme.Font
			preview.Active = self
		end
		tb.MouseButton1Click:Connect(function() tab:Select() end)
		table.insert(preview.Tabs, tab)
	end
	function preview:GetTab(name) for _, t in ipairs(self.Tabs) do if t.Name == name then return t end end end
	function preview:Set(name, settings) local t = self:GetTab(name) if t then t:Set(settings) end end
	if preview.Tabs[1] then preview.Tabs[1]:Select() end
	return preview
end

-- ================================================================ unload
Library._onUnload = {}
function Library:OnUnload(fn) table.insert(self._onUnload, fn) end
function Library:Unload()
	if self.Unloaded then return end
	self.Unloaded = true
	for _, fn in ipairs(self._onUnload) do pcall(fn) end
	for _, c in ipairs(self.Signals) do pcall(function() c:Disconnect() end) end
	stopSnow()
	pcall(function() Blur:Destroy() end)
	pcall(function() ScreenGui:Destroy() end)
end

return Library
