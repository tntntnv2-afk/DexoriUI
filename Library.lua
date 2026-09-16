local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Library = {
	Version = "1.0.0",
	Registry = {},
	Toggles = {},
	Options = {},
	Signals = {},
	Windows = {},
	Notifications = {},
	KeybindFrame = nil,
	Unloaded = false,
	IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled,
	NotifySide = "Right",
	ShowCustomCursor = false,
	Theme = {
		Background = Color3.fromRGB(12, 12, 12),
		Main = Color3.fromRGB(19, 19, 19),
		Element = Color3.fromRGB(26, 26, 26),
		ElementHover = Color3.fromRGB(34, 34, 34),
		Accent = Color3.fromRGB(200, 30, 30),
		AccentGradient = ColorSequence.new(Color3.fromRGB(230, 40, 40), Color3.fromRGB(120, 10, 10)),
		Outline = Color3.fromRGB(38, 38, 38),
		OutlineStrong = Color3.fromRGB(60, 18, 18),
		Font = Color3.fromRGB(240, 240, 240),
		FontDim = Color3.fromRGB(150, 150, 155),
		Risky = Color3.fromRGB(255, 80, 80),
	},
	FontFace = Font.fromEnum(Enum.Font.GothamMedium),
	FontFaceBold = Font.fromEnum(Enum.Font.GothamBold),
	CornerRadius = 6,
	ToggleKeybind = Enum.KeyCode.RightControl,
	Icon = "rbxassetid://83607561451748",
}
Library.__index = Library

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

local function Create(class, props, children)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then inst[k] = v end
	end
	for _, c in ipairs(children or {}) do c.Parent = inst end
	if props and props.Parent then inst.Parent = props.Parent end
	return inst
end
Library.Create = Create

local function Tween(obj, props, t, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
Library.Tween = Tween

local function Corner(parent, r)
	return Create("UICorner", { CornerRadius = UDim.new(0, r or Library.CornerRadius), Parent = parent })
end
local function Stroke(parent, themeKey, thickness, transparency)
	local s = Create("UIStroke", { Thickness = thickness or 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
	Library:AddToRegistry(s, { Color = themeKey or "Outline" })
	return s
end
local function Padding(parent, l, r, t, b)
	return Create("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0), PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0), Parent = parent })
end

function Library:AddToRegistry(inst, props)
	self.Registry[inst] = props
	for prop, key in pairs(props) do
		local v = self.Theme[key]
		if v ~= nil then pcall(function() inst[prop] = v end) end
	end
end
function Library:RemoveFromRegistry(inst)
	self.Registry[inst] = nil
end
function Library:UpdateColorsUsingRegistry()
	for inst, props in pairs(self.Registry) do
		if inst and inst.Parent then
			for prop, key in pairs(props) do
				local v = self.Theme[key]
				if v ~= nil then pcall(function() inst[prop] = v end) end
			end
		else
			self.Registry[inst] = nil
		end
	end
end
function Library:SetTheme(theme)
	for k, v in pairs(theme) do self.Theme[k] = v end
	self:UpdateColorsUsingRegistry()
end

function Library:GiveSignal(conn)
	table.insert(self.Signals, conn)
	return conn
end

local function MakeLabel(parent, text, size, bold, themeKey)
	local lbl = Create("TextLabel", {
		BackgroundTransparency = 1, Text = text or "", TextSize = size or 13,
		FontFace = bold and Library.FontFaceBold or Library.FontFace,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 18), RichText = true, TextTruncate = Enum.TextTruncate.AtEnd, Parent = parent,
	})
	Library:AddToRegistry(lbl, { TextColor3 = themeKey or "Font" })
	return lbl
end
Library.MakeLabel = MakeLabel

local function Draggable(handle, frame)
	local dragging, dragStart, startPos = false, nil, nil
	handle.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true; dragStart = inp.Position; startPos = frame.Position
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
Library.Draggable = Draggable

local function Hover(btn, normalKey, hoverKey)
	btn.MouseEnter:Connect(function() if Library.Theme[hoverKey] then Tween(btn, { BackgroundColor3 = Library.Theme[hoverKey] }, 0.12) end end)
	btn.MouseLeave:Connect(function() if Library.Theme[normalKey] then Tween(btn, { BackgroundColor3 = Library.Theme[normalKey] }, 0.12) end end)
end

local function IsPressed(inp)
	return inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch
end

-- ===================================================================================
-- Notifications
-- ===================================================================================
local NotifHolder = Create("Frame", { Name = "Notifications", BackgroundTransparency = 1, Size = UDim2.new(0, 300, 1, -20), Position = UDim2.new(1, -310, 0, 10), Parent = ScreenGui })
Create("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Top, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = NotifHolder })

function Library:SetNotifySide(side)
	self.NotifySide = side
	if side == "Left" then
		NotifHolder.Position = UDim2.new(0, 10, 0, 10)
		NotifHolder.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	else
		NotifHolder.Position = UDim2.new(1, -310, 0, 10)
		NotifHolder.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	end
end

function Library:Notify(opts, duration)
	if type(opts) ~= "table" then opts = { Description = tostring(opts), Time = duration } end
	local title = opts.Title or "Dexori"
	local desc = opts.Description or ""
	local time = opts.Time or 4
	local card = Create("Frame", { BackgroundTransparency = 0, Size = UDim2.new(0, 290, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true, Parent = NotifHolder })
	self:AddToRegistry(card, { BackgroundColor3 = "Main" })
	Corner(card); Stroke(card, "Outline")
	local bar = Create("Frame", { Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, Parent = card })
	self:AddToRegistry(bar, { BackgroundColor3 = "Accent" })
	local inner = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -14, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 10, 0, 0), Parent = card })
	Padding(inner, 0, 0, 8, 8)
	Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = inner })
	local t = MakeLabel(inner, title, 13, true); t.LayoutOrder = 1
	local d = MakeLabel(inner, desc, 12, false, "FontDim"); d.LayoutOrder = 2; d.TextWrapped = true; d.AutomaticSize = Enum.AutomaticSize.Y; d.Size = UDim2.new(1, 0, 0, 0); d.TextTruncate = Enum.TextTruncate.None
	local prog = Create("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BorderSizePixel = 0, Parent = card })
	self:AddToRegistry(prog, { BackgroundColor3 = "Accent" })
	card.Position = UDim2.new(1, 300, 0, 0)
	Tween(card, { Position = UDim2.new(0, 0, 0, 0) }, 0.25, Enum.EasingStyle.Back)
	Tween(prog, { Size = UDim2.new(0, 0, 0, 2) }, time, Enum.EasingStyle.Linear)
	local obj = { Frame = card }
	function obj:Destroy()
		if not card.Parent then return end
		Tween(card, { Position = UDim2.new(1, 300, 0, 0) }, 0.2).Completed:Connect(function() card:Destroy() end)
	end
	task.delay(time, function() obj:Destroy() end)
	card.InputBegan:Connect(function(inp) if IsPressed(inp) then obj:Destroy() end end)
	return obj
end

-- ===================================================================================
-- Watermark with embedded search
-- ===================================================================================
Library.SearchIndex = {}
local Watermark = Create("Frame", { Name = "Watermark", Size = UDim2.new(0, 0, 0, 30), AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.new(0, 12, 0, 12), Visible = false, Parent = ScreenGui })
Library:AddToRegistry(Watermark, { BackgroundColor3 = "Main" })
Corner(Watermark); Stroke(Watermark, "OutlineStrong")
Padding(Watermark, 10, 10, 0, 0)
Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = Watermark })
local WmLogo = Create("ImageLabel", { LayoutOrder = 1, Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1, Image = Library.Icon, Parent = Watermark })
local WmText = Create("TextLabel", { LayoutOrder = 2, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), FontFace = Library.FontFaceBold, TextSize = 12, Text = "Dexori", Parent = Watermark })
Library:AddToRegistry(WmText, { TextColor3 = "Font" })
local WmSep = Create("Frame", { LayoutOrder = 3, Size = UDim2.new(0, 1, 0, 16), BorderSizePixel = 0, Parent = Watermark })
Library:AddToRegistry(WmSep, { BackgroundColor3 = "Outline" })
local WmSearchBox = Create("Frame", { LayoutOrder = 4, Size = UDim2.new(0, 150, 0, 20), Parent = Watermark })
Library:AddToRegistry(WmSearchBox, { BackgroundColor3 = "Element" })
Corner(WmSearchBox, 4); Stroke(WmSearchBox, "Outline")
local WmSearchIcon = Create("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(0, 16, 1, 0), Position = UDim2.new(0, 4, 0, 0), Text = "⌕", TextSize = 14, FontFace = Library.FontFaceBold, Parent = WmSearchBox })
Library:AddToRegistry(WmSearchIcon, { TextColor3 = "FontDim" })
local WmSearch = Create("TextBox", { BackgroundTransparency = 1, Size = UDim2.new(1, -24, 1, 0), Position = UDim2.new(0, 22, 0, 0), PlaceholderText = "Search...", Text = "", TextSize = 12, FontFace = Library.FontFace, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = WmSearchBox })
Library:AddToRegistry(WmSearch, { TextColor3 = "Font", PlaceholderColor3 = "FontDim" })
local WmResults = Create("Frame", { Name = "SearchResults", Size = UDim2.new(0, 260, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 12, 0, 46), Visible = false, Parent = ScreenGui })
Library:AddToRegistry(WmResults, { BackgroundColor3 = "Main" })
Corner(WmResults); Stroke(WmResults, "OutlineStrong")
Padding(WmResults, 4, 4, 4, 4)
Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = WmResults })

function Library:SetWatermarkVisibility(on) Watermark.Visible = on and true or false end
function Library:SetWatermark(text) WmText.Text = text or "Dexori" end
function Library:RegisterSearch(name, path, focus)
	table.insert(self.SearchIndex, { name = name, path = path, focus = focus })
end
local function runSearch(q)
	for _, c in ipairs(WmResults:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
	q = string.lower(q or "")
	if q == "" then WmResults.Visible = false return end
	local n = 0
	for _, e in ipairs(Library.SearchIndex) do
		if string.find(string.lower(e.name), q, 1, true) or string.find(string.lower(e.path), q, 1, true) then
			n = n + 1
			if n > 8 then break end
			local b = Create("TextButton", { AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 30), Text = "", LayoutOrder = n, Parent = WmResults })
			Library:AddToRegistry(b, { BackgroundColor3 = "Element" }); Corner(b, 4)
			local nm = MakeLabel(b, e.name, 12, true); nm.Position = UDim2.new(0, 8, 0, 2); nm.Size = UDim2.new(1, -16, 0, 14)
			local pt = MakeLabel(b, e.path, 10, false, "FontDim"); pt.Position = UDim2.new(0, 8, 0, 15); pt.Size = UDim2.new(1, -16, 0, 12)
			Hover(b, "Element", "ElementHover")
			b.MouseButton1Click:Connect(function()
				pcall(e.focus)
				WmSearch.Text = ""
				WmResults.Visible = false
			end)
		end
	end
	WmResults.Visible = n > 0
end
WmSearch:GetPropertyChangedSignal("Text"):Connect(function() runSearch(WmSearch.Text) end)
WmSearch.FocusLost:Connect(function() task.delay(0.15, function() if WmSearch.Text == "" then WmResults.Visible = false end end) end)
Draggable(Watermark, Watermark)

-- ===================================================================================
-- Keybind list
-- ===================================================================================
local KeybindFrame = Create("Frame", { Name = "Keybinds", Size = UDim2.new(0, 170, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 12, 0.5, -80), Visible = false, Parent = ScreenGui })
Library:AddToRegistry(KeybindFrame, { BackgroundColor3 = "Main" })
Corner(KeybindFrame); Stroke(KeybindFrame, "OutlineStrong")
Padding(KeybindFrame, 8, 8, 6, 6)
Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = KeybindFrame })
local kbTitle = MakeLabel(KeybindFrame, "Keybinds", 12, true); kbTitle.LayoutOrder = 0
Library.KeybindFrame = KeybindFrame
Draggable(KeybindFrame, KeybindFrame)
function Library:SetKeybindVisibility(on) KeybindFrame.Visible = on and true or false end

-- ===================================================================================
-- Window
-- ===================================================================================
function Library:CreateWindow(cfg)
	cfg = cfg or {}
	local window = { Tabs = {}, ActiveTab = nil }
	local size = cfg.Size or UDim2.fromOffset(660, 540)
	if Library.IsMobile then
		local vp = ScreenGui.AbsoluteSize
		size = UDim2.fromOffset(math.min(size.X.Offset, vp.X - 20), math.min(size.Y.Offset, vp.Y - 20))
	end
	local main = Create("Frame", { Name = "Window", Size = size, Position = UDim2.new(0.5, -size.X.Offset / 2, 0.5, -size.Y.Offset / 2), ClipsDescendants = true, Parent = ScreenGui })
	self:AddToRegistry(main, { BackgroundColor3 = "Background" })
	Corner(main, 8); Stroke(main, "OutlineStrong", 1)
	window.Frame = main

	local sidebar = Create("Frame", { Name = "Sidebar", Size = UDim2.new(0, 170, 1, 0), BorderSizePixel = 0, Parent = main })
	self:AddToRegistry(sidebar, { BackgroundColor3 = "Main" })
	local sideLine = Create("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0), BorderSizePixel = 0, Parent = sidebar })
	self:AddToRegistry(sideLine, { BackgroundColor3 = "Outline" })

	local header = Create("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundTransparency = 1, Parent = sidebar })
	local logo = Create("ImageLabel", { Size = cfg.IconSize or UDim2.fromOffset(30, 30), Position = UDim2.new(0, 14, 0.5, -15), BackgroundTransparency = 1, Image = cfg.Icon and ("rbxassetid://" .. tostring(cfg.Icon)) or Library.Icon, Parent = header })
	local title = MakeLabel(header, cfg.Title or "", 15, true); title.Position = UDim2.new(0, 52, 0, 12); title.Size = UDim2.new(1, -60, 0, 18)
	local subtitle = MakeLabel(header, cfg.Subtitle or "", 11, false, "FontDim"); subtitle.Position = UDim2.new(0, 52, 0, 30); subtitle.Size = UDim2.new(1, -60, 0, 14)
	local accentLine = Create("Frame", { Size = UDim2.new(1, -28, 0, 2), Position = UDim2.new(0, 14, 0, 58), BorderSizePixel = 0, Parent = sidebar })
	local accentGrad = Create("UIGradient", { Parent = accentLine })
	self:AddToRegistry(accentGrad, { Color = "AccentGradient" })
	Draggable(header, main)

	local tabList = Create("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -100), Position = UDim2.new(0, 0, 0, 66), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), Parent = sidebar })
	Padding(tabList, 10, 10, 0, 0)
	Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabList })

	local footer = MakeLabel(sidebar, cfg.Footer or "", 11, false, "FontDim"); footer.Position = UDim2.new(0, 14, 1, -26); footer.Size = UDim2.new(1, -28, 0, 18)

	local content = Create("Frame", { Name = "Content", Size = UDim2.new(1, -170, 1, 0), Position = UDim2.new(0, 170, 0, 0), BackgroundTransparency = 1, Parent = main })
	window.Content = content

	-- toggle visibility
	local visible = cfg.AutoShow ~= false
	main.Visible = visible
	function window:SetVisible(on)
		visible = on
		main.Visible = on
		if not on then
			for _, w in pairs(Library.OpenPopups or {}) do pcall(function() w.Visible = false end) end
		end
	end
	function window:Toggle() self:SetVisible(not visible) end
	function window:IsVisible() return visible end
	Library.ToggleKeybind = cfg.ToggleKeybind or Library.ToggleKeybind
	self:GiveSignal(UserInputService.InputBegan:Connect(function(inp, gpe)
		if gpe then return end
		if inp.KeyCode == Library.ToggleKeybind then window:Toggle() end
	end))
	if Library.IsMobile then
		local mob = Create("TextButton", { Size = UDim2.fromOffset(44, 44), Position = UDim2.new(0, 12, 0.5, -22), Text = "", AutoButtonColor = false, Parent = ScreenGui })
		self:AddToRegistry(mob, { BackgroundColor3 = "Main" }); Corner(mob, 22); Stroke(mob, "OutlineStrong")
		Create("ImageLabel", { Size = UDim2.fromOffset(26, 26), Position = UDim2.new(0.5, -13, 0.5, -13), BackgroundTransparency = 1, Image = Library.Icon, Parent = mob })
		mob.MouseButton1Click:Connect(function() window:Toggle() end)
		Draggable(mob, mob)
	end

	-- ------------------------------------------------------------------ tabs
	local tabOrder = 0
	function window:AddTab(name, icon)
		tabOrder = tabOrder + 1
		local tab = { Name = name, Window = window, Subtabs = {}, Groupboxes = {} }
		local btn = Create("TextButton", { Size = UDim2.new(1, 0, 0, 32), Text = "", AutoButtonColor = false, BackgroundTransparency = 1, LayoutOrder = tabOrder, Parent = tabList })
		Corner(btn, 5)
		local sel = Create("Frame", { Size = UDim2.new(0, 3, 0, 18), Position = UDim2.new(0, 0, 0.5, -9), BorderSizePixel = 0, Visible = false, Parent = btn })
		Library:AddToRegistry(sel, { BackgroundColor3 = "Accent" }); Corner(sel, 2)
		local hasIcon = icon ~= nil
		if hasIcon then
			local img = Create("ImageLabel", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 12, 0.5, -8), BackgroundTransparency = 1, Image = (type(icon) == "number") and ("rbxassetid://" .. icon) or tostring(icon), Parent = btn })
			Library:AddToRegistry(img, { ImageColor3 = "FontDim" })
			tab._icon = img
		end
		local lbl = MakeLabel(btn, name, 13, true, "FontDim"); lbl.Position = UDim2.new(0, hasIcon and 36 or 14, 0, 0); lbl.Size = UDim2.new(1, -40, 1, 0)
		tab._label = lbl; tab._btn = btn; tab._sel = sel

		local page = Create("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, Parent = content })
		tab.Page = page
		-- subtab bar (hidden until a subtab is added)
		local subBar = Create("Frame", { Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 0, 10), BackgroundTransparency = 1, Visible = false, Parent = page })
		Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = subBar })
		tab.SubBar = subBar

		local function makeColumns(parent, topOffset)
			local left = Create("ScrollingFrame", { Size = UDim2.new(0.5, -18, 1, -(topOffset + 12)), Position = UDim2.new(0, 12, 0, topOffset), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), Parent = parent })
			Library:AddToRegistry(left, { ScrollBarImageColor3 = "Accent" })
			Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
			Padding(left, 0, 4, 0, 10)
			local right = Create("ScrollingFrame", { Size = UDim2.new(0.5, -18, 1, -(topOffset + 12)), Position = UDim2.new(0.5, 6, 0, topOffset), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0), Parent = parent })
			Library:AddToRegistry(right, { ScrollBarImageColor3 = "Accent" })
			Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = right })
			Padding(right, 0, 4, 0, 10)
			return left, right
		end
		local mainLeft, mainRight = makeColumns(page, 12)
		tab.Left, tab.Right = mainLeft, mainRight
		tab._mainCols = { mainLeft, mainRight }

		local function relayout()
			local top = subBar.Visible and 50 or 12
			for _, col in ipairs(tab._mainCols) do
				col.Position = UDim2.new(col.Position.X.Scale, col.Position.X.Offset, 0, top)
				col.Size = UDim2.new(col.Size.X.Scale, col.Size.X.Offset, 1, -(top + 12))
			end
			for _, st in ipairs(tab.Subtabs) do
				for _, col in ipairs(st._cols) do
					col.Position = UDim2.new(col.Position.X.Scale, col.Position.X.Offset, 0, top)
					col.Size = UDim2.new(col.Size.X.Scale, col.Size.X.Offset, 1, -(top + 12))
				end
			end
		end

		function tab:Select()
			for _, t in ipairs(window.Tabs) do
				t.Page.Visible = false; t._sel.Visible = false
				Tween(t._label, { TextColor3 = Library.Theme.FontDim }, 0.12)
				if t._icon then Tween(t._icon, { ImageColor3 = Library.Theme.FontDim }, 0.12) end
				t._btn.BackgroundTransparency = 1
			end
			self.Page.Visible = true; self._sel.Visible = true
			Tween(self._label, { TextColor3 = Library.Theme.Font }, 0.12)
			if self._icon then Tween(self._icon, { ImageColor3 = Library.Theme.Accent }, 0.12) end
			self._btn.BackgroundTransparency = 0
			self._btn.BackgroundColor3 = Library.Theme.Element
			window.ActiveTab = self
		end
		btn.MouseButton1Click:Connect(function() tab:Select() end)
		Hover(btn, "Element", "ElementHover")

		-- subpages
		function tab:AddSubTab(subName)
			local st = { Name = subName, Tab = tab, Groupboxes = {} }
			local sbtn = Create("TextButton", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Text = "", AutoButtonColor = false, LayoutOrder = #tab.Subtabs + 1, Parent = subBar })
			Library:AddToRegistry(sbtn, { BackgroundColor3 = "Element" }); Corner(sbtn, 5); Stroke(sbtn, "Outline")
			Padding(sbtn, 12, 12, 0, 0)
			local sl = MakeLabel(sbtn, subName, 12, true, "FontDim"); sl.AutomaticSize = Enum.AutomaticSize.X; sl.Size = UDim2.new(0, 0, 1, 0)
			st._btn, st._label = sbtn, sl
			local sub = Create("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, Parent = page })
			st.Page = sub
			local l, r = makeColumns(sub, 50)
			st.Left, st.Right, st._cols = l, r, { l, r }
			function st:Select()
				for _, col in ipairs(tab._mainCols) do col.Visible = false end
				for _, o in ipairs(tab.Subtabs) do
					o.Page.Visible = false
					Tween(o._label, { TextColor3 = Library.Theme.FontDim }, 0.12)
					o._btn.BackgroundColor3 = Library.Theme.Element
				end
				self.Page.Visible = true
				Tween(self._label, { TextColor3 = Library.Theme.Font }, 0.12)
				self._btn.BackgroundColor3 = Library.Theme.ElementHover
			end
			sbtn.MouseButton1Click:Connect(function() st:Select() end)
			st.AddLeftGroupbox = function(_, name) return window:_MakeGroupbox(l, name, tab.Name .. " / " .. subName) end
			st.AddRightGroupbox = function(_, name) return window:_MakeGroupbox(r, name, tab.Name .. " / " .. subName) end
			table.insert(tab.Subtabs, st)
			subBar.Visible = true
			relayout()
			if #tab.Subtabs == 1 then st:Select() end
			return st
		end

		tab.AddLeftGroupbox = function(_, name) return window:_MakeGroupbox(mainLeft, name, tab.Name) end
		tab.AddRightGroupbox = function(_, name) return window:_MakeGroupbox(mainRight, name, tab.Name) end
		table.insert(window.Tabs, tab)
		if #window.Tabs == 1 then tab:Select() end
		return tab
	end

	-- ------------------------------------------------------------------ groupboxes
	local gbOrder = 0
	function window:_MakeGroupbox(column, name, pathPrefix)
		gbOrder = gbOrder + 1
		local gb = { Name = name, Path = pathPrefix .. " / " .. name, Elements = {} }
		local frame = Create("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = gbOrder, Parent = column })
		Library:AddToRegistry(frame, { BackgroundColor3 = "Main" }); Corner(frame); Stroke(frame, "Outline")
		local titleBar = Create("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = frame })
		local t = MakeLabel(titleBar, name, 13, true); t.Position = UDim2.new(0, 12, 0, 0); t.Size = UDim2.new(1, -24, 1, 0)
		local line = Create("Frame", { Size = UDim2.new(1, -24, 0, 1), Position = UDim2.new(0, 12, 0, 30), BorderSizePixel = 0, Parent = frame })
		Library:AddToRegistry(line, { BackgroundColor3 = "Outline" })
		local holder = Create("Frame", { Size = UDim2.new(1, -24, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(0, 12, 0, 36), BackgroundTransparency = 1, Parent = frame })
		Padding(holder, 0, 0, 0, 10)
		Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = holder })
		gb.Frame, gb.Holder = frame, holder
		gb._order = 0
		function gb:_next() self._order = self._order + 1 return self._order end
		function gb:_focus(el)
			local tab = nil
			for _, tb in ipairs(window.Tabs) do
				if column:IsDescendantOf(tb.Page) then tab = tb break end
			end
			if tab then
				tab:Select()
				for _, st in ipairs(tab.Subtabs) do if column:IsDescendantOf(st.Page) then st:Select() end end
			end
			window:SetVisible(true)
			if el then
				local s = Stroke(el, "Accent", 1.5)
				task.delay(1.5, function() Library:RemoveFromRegistry(s) s:Destroy() end)
			end
		end
		setmetatable(gb, { __index = Library.GroupboxMethods })
		return gb
	end

	table.insert(self.Windows, window)
	return window
end

Library.OpenPopups = {}
function Library:_ClosePopups(except)
	for _, p in pairs(self.OpenPopups) do
		if p ~= except then pcall(function() p.Visible = false end) end
	end
end
ScreenGui.DescendantAdded:Connect(function() end)
UserInputService.InputBegan:Connect(function(inp)
	if IsPressed(inp) then
		local pos = inp.Position
		for _, p in pairs(Library.OpenPopups) do
			if p.Visible then
				local a, s = p.AbsolutePosition, p.AbsoluteSize
				local inside = pos.X >= a.X and pos.X <= a.X + s.X and pos.Y >= a.Y and pos.Y <= a.Y + s.Y
				local owner = p:GetAttribute("OwnerOpen")
				if not inside and not p:GetAttribute("Sticky") then
					task.defer(function() if not p:GetAttribute("KeepOpen") then p.Visible = false end end)
				end
			end
		end
	end
end)


-- ===================================================================================
-- Elements
-- ===================================================================================
local GroupboxMethods = {}
Library.GroupboxMethods = GroupboxMethods

local function elementBase(gb, height)
	local f = Create("Frame", { Size = UDim2.new(1, 0, 0, height or 30), BackgroundTransparency = 1, LayoutOrder = gb:_next(), Parent = gb.Holder })
	return f
end

local function registerSearch(gb, name, frame)
	Library:RegisterSearch(name, gb.Path, function() gb:_focus(frame) end)
end

-- Label ----------------------------------------------------------------------------
function GroupboxMethods:AddLabel(text, wrap)
	local f = elementBase(self, 16)
	local l = MakeLabel(f, text, 12, false, "FontDim")
	l.Size = UDim2.new(1, 0, 0, 16)
	if wrap then l.TextWrapped = true; l.AutomaticSize = Enum.AutomaticSize.Y; f.AutomaticSize = Enum.AutomaticSize.Y; l.TextTruncate = Enum.TextTruncate.None end
	local obj = { Frame = f, TextLabel = l }
	function obj:SetText(t) l.Text = t end
	function obj:AddKeyPicker(idx, cfg) return Library._AttachKeyPicker(self, f, idx, cfg) end
	function obj:AddColorPicker(idx, cfg) return Library._AttachColorPicker(self, f, idx, cfg) end
	return obj
end

-- Divider --------------------------------------------------------------------------
function GroupboxMethods:AddDivider()
	local f = elementBase(self, 8)
	local line = Create("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0.5, 0), BorderSizePixel = 0, Parent = f })
	Library:AddToRegistry(line, { BackgroundColor3 = "Outline" })
	return { Frame = f }
end

-- Button ---------------------------------------------------------------------------
function GroupboxMethods:AddButton(cfg, func)
	if type(cfg) == "string" then cfg = { Text = cfg, Func = func } end
	local f = elementBase(self, 30)
	local b = Create("TextButton", { Size = UDim2.new(1, 0, 1, 0), Text = "", AutoButtonColor = false, Parent = f })
	Library:AddToRegistry(b, { BackgroundColor3 = "Element" }); Corner(b, 5); Stroke(b, cfg.Risky and "Risky" or "Outline")
	local l = MakeLabel(b, cfg.Text or "Button", 13, true, cfg.Risky and "Risky" or "Font")
	l.TextXAlignment = Enum.TextXAlignment.Center; l.Size = UDim2.new(1, 0, 1, 0)
	Hover(b, "Element", "ElementHover")
	local obj = { Frame = f, Button = b }
	b.MouseButton1Click:Connect(function()
		if cfg.DoubleClick then
			if obj._armed then obj._armed = false l.Text = cfg.Text pcall(cfg.Func)
			else obj._armed = true l.Text = "Confirm?" task.delay(1.5, function() obj._armed = false l.Text = cfg.Text end) end
		else
			pcall(cfg.Func)
		end
	end)
	registerSearch(self, cfg.Text or "Button", f)
	function obj:SetText(t) l.Text = t end
	function obj:AddButton(cfg2, func2)
		if type(cfg2) == "string" then cfg2 = { Text = cfg2, Func = func2 } end
		b.Size = UDim2.new(0.5, -3, 1, 0)
		local b2 = Create("TextButton", { Size = UDim2.new(0.5, -3, 1, 0), Position = UDim2.new(0.5, 3, 0, 0), Text = "", AutoButtonColor = false, Parent = f })
		Library:AddToRegistry(b2, { BackgroundColor3 = "Element" }); Corner(b2, 5); Stroke(b2, cfg2.Risky and "Risky" or "Outline")
		local l2 = MakeLabel(b2, cfg2.Text or "Button", 13, true, cfg2.Risky and "Risky" or "Font")
		l2.TextXAlignment = Enum.TextXAlignment.Center; l2.Size = UDim2.new(1, 0, 1, 0)
		Hover(b2, "Element", "ElementHover")
		b2.MouseButton1Click:Connect(function() pcall(cfg2.Func) end)
		registerSearch(self, cfg2.Text or "Button", f)
		return { Frame = f, Button = b2, SetText = function(_, t) l2.Text = t end }
	end
	return obj
end

-- Toggle ---------------------------------------------------------------------------
function GroupboxMethods:AddToggle(idx, cfg)
	cfg = cfg or {}
	local f = elementBase(self, 24)
	local hit = Create("TextButton", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", Parent = f })
	local box = Create("Frame", { Size = UDim2.fromOffset(36, 18), Position = UDim2.new(0, 0, 0.5, -9), Parent = f })
	Library:AddToRegistry(box, { BackgroundColor3 = "Element" }); Corner(box, 9); local bs = Stroke(box, "Outline")
	local knob = Create("Frame", { Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 2, 0.5, -7), Parent = box })
	Library:AddToRegistry(knob, { BackgroundColor3 = "FontDim" }); Corner(knob, 7)
	local l = MakeLabel(f, cfg.Text or idx, 13, false); l.Position = UDim2.new(0, 46, 0, 0); l.Size = UDim2.new(1, -46, 1, 0)
	local obj = { Frame = f, Value = cfg.Default and true or false, Type = "Toggle", Idx = idx, Callback = cfg.Callback, Risky = cfg.Risky, _changed = {} }
	local function render(anim)
		local on = obj.Value
		local t = anim and 0.15 or 0
		Tween(knob, { Position = on and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7), BackgroundColor3 = on and Color3.fromRGB(255, 255, 255) or Library.Theme.FontDim }, t)
		Tween(box, { BackgroundColor3 = on and Library.Theme.Accent or Library.Theme.Element }, t)
		bs.Color = on and Library.Theme.Accent or Library.Theme.Outline
		Library.Registry[box] = on and { BackgroundColor3 = "Accent" } or { BackgroundColor3 = "Element" }
		Library.Registry[bs] = on and { Color = "Accent" } or { Color = "Outline" }
		if on then Library.Registry[knob] = nil else Library.Registry[knob] = { BackgroundColor3 = "FontDim" } end
	end
	function obj:SetValue(v, silent)
		self.Value = v and true or false
		render(true)
		if not silent then
			if self.Callback then pcall(self.Callback, self.Value) end
			for _, fn in ipairs(self._changed) do pcall(fn, self.Value) end
		end
	end
	function obj:OnChanged(fn) table.insert(self._changed, fn) end
	function obj:SetText(t) l.Text = t end
	function obj:AddKeyPicker(kidx, kcfg) return Library._AttachKeyPicker(self, f, kidx, kcfg) end
	function obj:AddColorPicker(cidx, ccfg) return Library._AttachColorPicker(self, f, cidx, ccfg) end
	hit.MouseButton1Click:Connect(function() obj:SetValue(not obj.Value) end)
	render(false)
	if cfg.Default and cfg.Callback then task.defer(function() pcall(cfg.Callback, true) end) end
	Library.Toggles[idx] = obj
	registerSearch(self, cfg.Text or idx, f)
	return obj
end

-- Slider ---------------------------------------------------------------------------
function GroupboxMethods:AddSlider(idx, cfg)
	cfg = cfg or {}
	local f = elementBase(self, cfg.Compact and 20 or 38)
	local l = MakeLabel(f, cfg.Text or idx, 12, false); l.Size = UDim2.new(1, -60, 0, 16)
	local val = MakeLabel(f, "", 12, true); val.TextXAlignment = Enum.TextXAlignment.Right; val.Size = UDim2.new(0, 90, 0, 16); val.Position = UDim2.new(1, -90, 0, 0)
	local track = Create("Frame", { Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 0, cfg.Compact and 4 or 22), Parent = f })
	Library:AddToRegistry(track, { BackgroundColor3 = "Element" }); Corner(track, 6); Stroke(track, "Outline")
	local fill = Create("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, Parent = track })
	Corner(fill, 6)
	local fg = Create("UIGradient", { Parent = fill }); Library:AddToRegistry(fg, { Color = "AccentGradient" })
	local hit = Create("TextButton", { Size = UDim2.new(1, 0, 1, 8), Position = UDim2.new(0, 0, 0, -4), BackgroundTransparency = 1, Text = "", Parent = track })
	if cfg.Compact then l.Visible = false val.Visible = false end
	local min, max = cfg.Min or 0, cfg.Max or 100
	local rounding = cfg.Rounding or 0
	local obj = { Frame = f, Value = cfg.Default or min, Type = "Slider", Idx = idx, Callback = cfg.Callback, Min = min, Max = max, _changed = {} }
	local function fmt(v)
		local s = string.format("%." .. rounding .. "f", v)
		return (cfg.Prefix or "") .. s .. (cfg.Suffix or "")
	end
	local function render()
		local a = (obj.Value - min) / math.max(max - min, 1e-9)
		fill.Size = UDim2.new(math.clamp(a, 0, 1), 0, 1, 0)
		val.Text = fmt(obj.Value)
		if cfg.Compact then l.Text = (cfg.Text or idx) .. ": " .. fmt(obj.Value) end
	end
	function obj:SetValue(v, silent)
		v = math.clamp(tonumber(v) or min, min, max)
		local m = 10 ^ rounding
		v = math.floor(v * m + 0.5) / m
		self.Value = v
		render()
		if not silent then
			if self.Callback then pcall(self.Callback, v) end
			for _, fn in ipairs(self._changed) do pcall(fn, v) end
		end
	end
	function obj:SetMax(m) max = m self.Max = m self:SetValue(self.Value, true) end
	function obj:SetMin(m) min = m self.Min = m self:SetValue(self.Value, true) end
	function obj:OnChanged(fn) table.insert(self._changed, fn) end
	local dragging = false
	local function fromInput(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		obj:SetValue(min + (max - min) * a)
	end
	hit.InputBegan:Connect(function(inp) if IsPressed(inp) then dragging = true fromInput(inp.Position.X) end end)
	hit.InputEnded:Connect(function(inp) if IsPressed(inp) then dragging = false end end)
	Library:GiveSignal(UserInputService.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then fromInput(inp.Position.X) end
	end))
	Library:GiveSignal(UserInputService.InputEnded:Connect(function(inp) if IsPressed(inp) then dragging = false end end))
	render()
	Library.Options[idx] = obj
	registerSearch(self, cfg.Text or idx, f)
	return obj
end

-- Input ----------------------------------------------------------------------------
function GroupboxMethods:AddInput(idx, cfg)
	cfg = cfg or {}
	local f = elementBase(self, 46)
	local l = MakeLabel(f, cfg.Text or idx, 12, false); l.Size = UDim2.new(1, 0, 0, 16)
	local boxF = Create("Frame", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 20), Parent = f })
	Library:AddToRegistry(boxF, { BackgroundColor3 = "Element" }); Corner(boxF, 5); local st = Stroke(boxF, "Outline")
	local tb = Create("TextBox", { Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0), BackgroundTransparency = 1, Text = cfg.Default or "", PlaceholderText = cfg.Placeholder or "", TextSize = 12, FontFace = Library.FontFace, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, Parent = boxF })
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
	registerSearch(self, cfg.Text or idx, f)
	return obj
end

-- Dropdown -------------------------------------------------------------------------
function GroupboxMethods:AddDropdown(idx, cfg)
	cfg = cfg or {}
	local f = elementBase(self, 46)
	local l = MakeLabel(f, cfg.Text or idx, 12, false); l.Size = UDim2.new(1, 0, 0, 16)
	local btn = Create("TextButton", { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 20), Text = "", AutoButtonColor = false, Parent = f })
	Library:AddToRegistry(btn, { BackgroundColor3 = "Element" }); Corner(btn, 5); Stroke(btn, "Outline")
	local cur = MakeLabel(btn, "", 12, false); cur.Position = UDim2.new(0, 8, 0, 0); cur.Size = UDim2.new(1, -30, 1, 0)
	local arrow = MakeLabel(btn, "▾", 14, true, "FontDim"); arrow.Position = UDim2.new(1, -20, 0, 0); arrow.Size = UDim2.new(0, 14, 1, 0)
	Hover(btn, "Element", "ElementHover")
	local list = Create("Frame", { Size = UDim2.new(0, 200, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 50, Parent = ScreenGui })
	Library:AddToRegistry(list, { BackgroundColor3 = "Main" }); Corner(list, 5); Stroke(list, "OutlineStrong")
	Padding(list, 4, 4, 4, 4)
	Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	Library.OpenPopups[list] = list
	local search = nil
	if cfg.Searchable then
		local sf = Create("Frame", { Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 0, ZIndex = 51, Parent = list })
		Library:AddToRegistry(sf, { BackgroundColor3 = "Element" }); Corner(sf, 4)
		search = Create("TextBox", { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "Search...", TextSize = 12, FontFace = Library.FontFace, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 52, Parent = sf })
		Library:AddToRegistry(search, { TextColor3 = "Font", PlaceholderColor3 = "FontDim" })
	end
	local scroll = Create("ScrollingFrame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, LayoutOrder = 1, ZIndex = 51, Parent = list })
	Library:AddToRegistry(scroll, { ScrollBarImageColor3 = "Accent" })
	Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })
	Create("UISizeConstraint", { MaxSize = Vector2.new(9999, 200), Parent = scroll })

	local obj = { Frame = f, Values = cfg.Values or {}, Multi = cfg.Multi, Type = "Dropdown", Idx = idx, Callback = cfg.Callback, _changed = {} }
	if cfg.Multi then
		obj.Value = {}
		if type(cfg.Default) == "table" then
			for k, v in pairs(cfg.Default) do
				if type(k) == "string" and v then obj.Value[k] = true elseif type(v) == "string" then obj.Value[v] = true end
			end
		end
	else
		if type(cfg.Default) == "number" then obj.Value = obj.Values[cfg.Default]
		elseif type(cfg.Default) == "string" then obj.Value = cfg.Default end
	end
	local function display()
		if obj.Multi then
			local t = {}
			for _, v in ipairs(obj.Values) do if obj.Value[v] then t[#t + 1] = tostring(v) end end
			cur.Text = #t > 0 and table.concat(t, ", ") or "---"
		else
			cur.Text = obj.Value ~= nil and tostring(obj.Value) or "---"
		end
	end
	local function fire()
		if obj.Callback then pcall(obj.Callback, obj.Value) end
		for _, fn in ipairs(obj._changed) do pcall(fn, obj.Value) end
	end
	local function build()
		for _, c in ipairs(scroll:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
		local q = search and string.lower(search.Text) or ""
		for i, v in ipairs(obj.Values) do
			if q == "" or string.find(string.lower(tostring(v)), q, 1, true) then
				local ib = Create("TextButton", { Size = UDim2.new(1, 0, 0, 24), Text = "", AutoButtonColor = false, LayoutOrder = i, ZIndex = 52, Parent = scroll })
				Corner(ib, 4)
				local selected = obj.Multi and obj.Value[v] or (not obj.Multi and obj.Value == v)
				ib.BackgroundTransparency = selected and 0 or 1
				ib.BackgroundColor3 = Library.Theme.Element
				local il = MakeLabel(ib, tostring(v), 12, selected, selected and "Font" or "FontDim"); il.Position = UDim2.new(0, 8, 0, 0); il.Size = UDim2.new(1, -16, 1, 0); il.ZIndex = 53
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
					display(); build(); fire()
				end)
			end
		end
	end
	if search then search:GetPropertyChangedSignal("Text"):Connect(build) end
	local function open()
		Library:_ClosePopups(list)
		list.Size = UDim2.new(0, btn.AbsoluteSize.X, 0, 0)
		list.Position = UDim2.new(0, btn.AbsolutePosition.X, 0, btn.AbsolutePosition.Y + btn.AbsoluteSize.Y + 4)
		build()
		list.Visible = not list.Visible
	end
	btn.MouseButton1Click:Connect(open)
	function obj:SetValues(vals) self.Values = vals or {} if self.Multi then for k in pairs(self.Value) do if not table.find(self.Values, k) then self.Value[k] = nil end end elseif self.Value ~= nil and not table.find(self.Values, self.Value) then self.Value = nil end display() end
	function obj:SetValue(v, silent)
		if self.Multi then
			self.Value = {}
			if type(v) == "table" then for k, on in pairs(v) do if type(k) == "string" and on then self.Value[k] = true elseif type(on) == "string" then self.Value[on] = true end end end
		else
			self.Value = v
		end
		display()
		if not silent then fire() end
	end
	function obj:OnChanged(fn) table.insert(self._changed, fn) end
	display()
	Library.Options[idx] = obj
	registerSearch(self, cfg.Text or idx, f)
	return obj
end

-- Color picker ---------------------------------------------------------------------
local function hsvToRgb(h, s, v) return Color3.fromHSV(h, s, v) end
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
	local existing = 0
	for _, c in ipairs(parentFrame:GetChildren()) do if c:GetAttribute("DexoriSwatch") then existing = existing + 1 end end
	local swatch = Create("TextButton", { Size = UDim2.fromOffset(28, 16), Position = UDim2.new(1, -(28 + existing * 34), 0.5, -8), Text = "", AutoButtonColor = false, Parent = parentFrame })
	swatch:SetAttribute("DexoriSwatch", true)
	Corner(swatch, 4); Stroke(swatch, "Outline")
	local swatchGrad = Create("UIGradient", { Enabled = false, Parent = swatch })

	local obj = { Frame = swatch, Type = "ColorPicker", Idx = idx, Callback = cfg.Callback, Gradient = cfg.Gradient, _changed = {} }
	obj.Value = cfg.Default or Color3.fromRGB(255, 255, 255)
	obj.Transparency = cfg.Transparency or 0
	obj.Value2 = cfg.Default2 or Color3.fromRGB(0, 0, 0)
	obj.Rotation = cfg.Rotation or 0
	local h, s, v = obj.Value:ToHSV()

	local pop = Create("Frame", { Size = UDim2.new(0, 230, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 60, Parent = ScreenGui })
	Library:AddToRegistry(pop, { BackgroundColor3 = "Main" }); Corner(pop); Stroke(pop, "OutlineStrong")
	Padding(pop, 8, 8, 8, 8)
	Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = pop })
	Library.OpenPopups[pop] = pop

	local titleL = MakeLabel(pop, cfg.Title or idx, 12, true); titleL.LayoutOrder = 0; titleL.ZIndex = 61
	local sv = Create("ImageButton", { Size = UDim2.new(1, 0, 0, 120), LayoutOrder = 1, AutoButtonColor = false, ZIndex = 61, Image = "rbxassetid://4155801252", Parent = pop })
	Corner(sv, 4)
	local svCursor = Create("Frame", { Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 63, Parent = sv }); Corner(svCursor, 4); Create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Parent = svCursor })
	local hue = Create("ImageButton", { Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 2, AutoButtonColor = false, ZIndex = 61, Parent = pop })
	Corner(hue, 4)
	Create("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)), ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)) }), Parent = hue })
	local hueCursor = Create("Frame", { Size = UDim2.new(0, 3, 1, 4), Position = UDim2.new(0, 0, 0, -2), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 63, Parent = hue })
	local alpha = nil
	local alphaCursor = nil
	if cfg.Transparency ~= nil then
		alpha = Create("ImageButton", { Size = UDim2.new(1, 0, 0, 12), LayoutOrder = 3, AutoButtonColor = false, ZIndex = 61, Parent = pop })
		Corner(alpha, 4)
		Create("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0, 0, 0)), Parent = alpha })
		alphaCursor = Create("Frame", { Size = UDim2.new(0, 3, 1, 4), Position = UDim2.new(0, 0, 0, -2), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 63, Parent = alpha })
	end
	local hexRow = Create("Frame", { Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 4, BackgroundTransparency = 1, ZIndex = 61, Parent = pop })
	local hexBoxF = Create("Frame", { Size = UDim2.new(1, 0, 1, 0), ZIndex = 61, Parent = hexRow })
	Library:AddToRegistry(hexBoxF, { BackgroundColor3 = "Element" }); Corner(hexBoxF, 4); Stroke(hexBoxF, "Outline")
	local hexBox = Create("TextBox", { Size = UDim2.new(1, -12, 1, 0), Position = UDim2.new(0, 6, 0, 0), BackgroundTransparency = 1, Text = toHex(obj.Value), TextSize = 12, FontFace = Library.FontFace, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 62, Parent = hexBoxF })
	Library:AddToRegistry(hexBox, { TextColor3 = "Font" })

	-- gradient section
	local gradRow, stopA, stopB, rotSlider, activeStop = nil, nil, nil, nil, 1
	if cfg.Gradient then
		gradRow = Create("Frame", { Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 5, BackgroundTransparency = 1, ZIndex = 61, Parent = pop })
		local prev = Create("Frame", { Size = UDim2.new(1, 0, 0, 16), ZIndex = 61, Parent = gradRow }); Corner(prev, 4)
		obj._prevGrad = Create("UIGradient", { Parent = prev })
		stopA = Create("TextButton", { Size = UDim2.new(0.5, -3, 0, 20), Position = UDim2.new(0, 0, 0, 22), Text = "Stop 1", TextSize = 11, FontFace = Library.FontFaceBold, AutoButtonColor = false, ZIndex = 62, Parent = gradRow })
		stopB = Create("TextButton", { Size = UDim2.new(0.5, -3, 0, 20), Position = UDim2.new(0.5, 3, 0, 22), Text = "Stop 2", TextSize = 11, FontFace = Library.FontFaceBold, AutoButtonColor = false, ZIndex = 62, Parent = gradRow })
		for _, b in ipairs({ stopA, stopB }) do Corner(b, 4); Library:AddToRegistry(b, { BackgroundColor3 = "Element", TextColor3 = "Font" }) end
		local rotRow = Create("Frame", { Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 6, BackgroundTransparency = 1, ZIndex = 61, Parent = pop })
		local rotL = MakeLabel(rotRow, "Rotation", 11, false, "FontDim"); rotL.Size = UDim2.new(0, 60, 1, 0); rotL.ZIndex = 62
		rotSlider = Create("TextButton", { Size = UDim2.new(1, -66, 0, 8), Position = UDim2.new(0, 66, 0.5, -4), Text = "", AutoButtonColor = false, ZIndex = 62, Parent = rotRow })
		Library:AddToRegistry(rotSlider, { BackgroundColor3 = "Element" }); Corner(rotSlider, 4)
		obj._rotFill = Create("Frame", { Size = UDim2.new(obj.Rotation / 360, 0, 1, 0), BorderSizePixel = 0, ZIndex = 63, Parent = rotSlider }); Corner(obj._rotFill, 4)
		Library:AddToRegistry(obj._rotFill, { BackgroundColor3 = "Accent" })
	end

	local function currentColor() return activeStop == 1 and obj.Value or obj.Value2 end
	local function render()
		local col = currentColor()
		swatch.BackgroundColor3 = obj.Value
		if cfg.Gradient then
			swatchGrad.Enabled = true
			swatchGrad.Color = ColorSequence.new(obj.Value, obj.Value2)
			swatchGrad.Rotation = obj.Rotation
			obj._prevGrad.Color = ColorSequence.new(obj.Value, obj.Value2)
			obj._prevGrad.Rotation = obj.Rotation
			stopA.TextColor3 = activeStop == 1 and Library.Theme.Accent or Library.Theme.Font
			stopB.TextColor3 = activeStop == 2 and Library.Theme.Accent or Library.Theme.Font
			obj._rotFill.Size = UDim2.new(obj.Rotation / 360, 0, 1, 0)
		end
		local hh, ss, vv = col:ToHSV()
		sv.BackgroundColor3 = Color3.fromHSV(hh, 1, 1)
		svCursor.Position = UDim2.new(ss, 0, 1 - vv, 0)
		hueCursor.Position = UDim2.new(hh, -1, 0, -2)
		if alphaCursor then alphaCursor.Position = UDim2.new(obj.Transparency, -1, 0, -2) end
		if not hexBox:IsFocused() then hexBox.Text = toHex(col) end
		swatch.BackgroundTransparency = obj.Transparency
	end
	local function fire()
		if obj.Callback then
			if cfg.Gradient then pcall(obj.Callback, ColorSequence.new(obj.Value, obj.Value2), obj.Rotation)
			else pcall(obj.Callback, obj.Value, obj.Transparency) end
		end
		for _, fn in ipairs(obj._changed) do pcall(fn, obj.Value, obj.Transparency) end
	end
	local function setCurrent(col)
		if activeStop == 1 then obj.Value = col else obj.Value2 = col end
		render(); fire()
	end
	local svDrag, hueDrag, alphaDrag, rotDrag = false, false, false, false
	local function svAt(p)
		local a = sv.AbsolutePosition; local sz = sv.AbsoluteSize
		local ss = math.clamp((p.X - a.X) / sz.X, 0, 1); local vv = 1 - math.clamp((p.Y - a.Y) / sz.Y, 0, 1)
		local hh = select(1, currentColor():ToHSV())
		setCurrent(Color3.fromHSV(hh, ss, vv))
	end
	local function hueAt(p)
		local a = hue.AbsolutePosition; local sz = hue.AbsoluteSize
		local hh = math.clamp((p.X - a.X) / sz.X, 0, 0.999)
		local _, ss, vv = currentColor():ToHSV()
		setCurrent(Color3.fromHSV(hh, ss, vv))
	end
	local function alphaAt(p)
		local a = alpha.AbsolutePosition; local sz = alpha.AbsoluteSize
		obj.Transparency = math.clamp((p.X - a.X) / sz.X, 0, 1); render(); fire()
	end
	local function rotAt(p)
		local a = rotSlider.AbsolutePosition; local sz = rotSlider.AbsoluteSize
		obj.Rotation = math.floor(math.clamp((p.X - a.X) / sz.X, 0, 1) * 360); render(); fire()
	end
	sv.InputBegan:Connect(function(inp) if IsPressed(inp) then svDrag = true svAt(inp.Position) end end)
	hue.InputBegan:Connect(function(inp) if IsPressed(inp) then hueDrag = true hueAt(inp.Position) end end)
	if alpha then alpha.InputBegan:Connect(function(inp) if IsPressed(inp) then alphaDrag = true alphaAt(inp.Position) end end) end
	if rotSlider then rotSlider.InputBegan:Connect(function(inp) if IsPressed(inp) then rotDrag = true rotAt(inp.Position) end end) end
	Library:GiveSignal(UserInputService.InputChanged:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
			if svDrag then svAt(inp.Position) elseif hueDrag then hueAt(inp.Position) elseif alphaDrag then alphaAt(inp.Position) elseif rotDrag then rotAt(inp.Position) end
		end
	end))
	Library:GiveSignal(UserInputService.InputEnded:Connect(function(inp) if IsPressed(inp) then svDrag, hueDrag, alphaDrag, rotDrag = false, false, false, false end end))
	hexBox.FocusLost:Connect(function() local c = fromHex(hexBox.Text) if c then setCurrent(c) else render() end end)
	if stopA then
		stopA.MouseButton1Click:Connect(function() activeStop = 1 render() end)
		stopB.MouseButton1Click:Connect(function() activeStop = 2 render() end)
	end
	swatch.MouseButton1Click:Connect(function()
		Library:_ClosePopups(pop)
		pop.Position = UDim2.new(0, swatch.AbsolutePosition.X - 230 + swatch.AbsoluteSize.X, 0, swatch.AbsolutePosition.Y + swatch.AbsoluteSize.Y + 6)
		pop.Visible = not pop.Visible
	end)
	function obj:SetValueRGB(col, transp, silent) self.Value = col if transp then self.Transparency = transp end render() if not silent then fire() end end
	function obj:SetValue(col, transp, silent) self:SetValueRGB(col, transp, silent) end
	function obj:SetValue2(col, silent) self.Value2 = col render() if not silent then fire() end end
	function obj:SetRotation(r, silent) self.Rotation = r render() if not silent then fire() end end
	function obj:GetSequence() return ColorSequence.new(self.Value, self.Value2) end
	function obj:OnChanged(fn) table.insert(self._changed, fn) end
	render()
	Library.Options[idx] = obj
	return obj
end

function GroupboxMethods:AddColorPicker(idx, cfg)
	cfg = cfg or {}
	local f = elementBase(self, 24)
	local l = MakeLabel(f, cfg.Text or idx, 13, false); l.Size = UDim2.new(1, -40, 1, 0)
	local obj = Library._AttachColorPicker(nil, f, idx, cfg)
	obj.Frame = f
	registerSearch(self, cfg.Text or idx, f)
	return obj
end

-- Key picker -----------------------------------------------------------------------
local KEY_NAMES = { MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3" }
local function keyName(k)
	if typeof(k) == "EnumItem" then return KEY_NAMES[k.Name] or k.Name end
	return tostring(k)
end

function Library._AttachKeyPicker(parentObj, parentFrame, idx, cfg)
	cfg = cfg or {}
	local existing = 0
	for _, c in ipairs(parentFrame:GetChildren()) do if c:GetAttribute("DexoriSwatch") or c:GetAttribute("DexoriKey") then existing = existing + 1 end end
	local btn = Create("TextButton", { Size = UDim2.fromOffset(52, 18), Position = UDim2.new(1, -(52 + existing * 34), 0.5, -9), Text = "", AutoButtonColor = false, Parent = parentFrame })
	btn:SetAttribute("DexoriKey", true)
	Library:AddToRegistry(btn, { BackgroundColor3 = "Element" }); Corner(btn, 4); Stroke(btn, "Outline")
	local kl = MakeLabel(btn, "", 11, true, "FontDim"); kl.TextXAlignment = Enum.TextXAlignment.Center; kl.Size = UDim2.new(1, 0, 1, 0)
	local obj = { Frame = btn, Type = "KeyPicker", Idx = idx, Mode = cfg.Mode or "Toggle", Value = cfg.Default or "None", Toggled = false, Callback = cfg.Callback, ChangedCallback = cfg.ChangedCallback, SyncToggleState = cfg.SyncToggleState, Text = cfg.Text or idx, NoUI = cfg.NoUI, _changed = {} }
	local binding = false
	local menu = Create("Frame", { Size = UDim2.new(0, 80, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Visible = false, ZIndex = 60, Parent = ScreenGui })
	Library:AddToRegistry(menu, { BackgroundColor3 = "Main" }); Corner(menu, 5); Stroke(menu, "OutlineStrong")
	Padding(menu, 4, 4, 4, 4)
	Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })
	Library.OpenPopups[menu] = menu
	local modeBtns = {}
	for i, mode in ipairs(cfg.Modes or { "Always", "Toggle", "Hold" }) do
		local mb = Create("TextButton", { Size = UDim2.new(1, 0, 0, 20), Text = "", AutoButtonColor = false, LayoutOrder = i, ZIndex = 61, Parent = menu })
		Corner(mb, 4)
		local ml = MakeLabel(mb, mode, 11, true, "FontDim"); ml.TextXAlignment = Enum.TextXAlignment.Center; ml.Size = UDim2.new(1, 0, 1, 0); ml.ZIndex = 62
		mb.MouseButton1Click:Connect(function() obj.Mode = mode menu.Visible = false obj:_render() end)
		modeBtns[mode] = { b = mb, l = ml }
	end
	local kbRow = nil
	if not cfg.NoUI then
		kbRow = Create("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Visible = false, LayoutOrder = 1, Parent = KeybindFrame })
		local kn = MakeLabel(kbRow, obj.Text, 11, false); kn.Size = UDim2.new(1, -50, 1, 0)
		local kv = MakeLabel(kbRow, "", 11, true, "Accent"); kv.TextXAlignment = Enum.TextXAlignment.Right; kv.Size = UDim2.new(0, 50, 1, 0); kv.Position = UDim2.new(1, -50, 0, 0)
		obj._kbv = kv
	end
	function obj:_render()
		kl.Text = binding and "..." or keyName(self.Value)
		for mode, r in pairs(modeBtns) do r.l.TextColor3 = (mode == self.Mode) and Library.Theme.Accent or Library.Theme.FontDim end
		if kbRow then
			local active = self:GetState()
			kbRow.Visible = self.Value ~= "None"
			self._kbv.Text = "[" .. keyName(self.Value) .. "]" .. (active and " ●" or "")
		end
	end
	function obj:GetState()
		if self.Mode == "Always" then return true end
		if self.Mode == "Hold" then return self._held == true end
		return self.Toggled
	end
	function obj:SetValue(v, silent)
		if type(v) == "table" then self.Mode = v[2] or self.Mode v = v[1] end
		if typeof(v) == "string" then
			if v == "None" then self.Value = "None"
			else
				local ok, k = pcall(function() return Enum.KeyCode[v] end)
				if ok and k then self.Value = k else
					local ok2, m = pcall(function() return Enum.UserInputType[v] end)
					self.Value = (ok2 and m) or "None"
				end
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
	btn.MouseButton2Click:Connect(function()
		Library:_ClosePopups(menu)
		menu.Position = UDim2.new(0, btn.AbsolutePosition.X, 0, btn.AbsolutePosition.Y + 22)
		menu.Visible = not menu.Visible
	end)
	Library:GiveSignal(UserInputService.InputBegan:Connect(function(inp, gpe)
		if binding then
			if inp.UserInputType == Enum.UserInputType.Keyboard then
				binding = false
				obj:SetValue(inp.KeyCode == Enum.KeyCode.Escape and "None" or inp.KeyCode)
			elseif inp.UserInputType == Enum.UserInputType.MouseButton2 or inp.UserInputType == Enum.UserInputType.MouseButton3 then
				binding = false
				obj:SetValue(inp.UserInputType)
			end
			return
		end
		if gpe then return end
		local match = (inp.UserInputType == Enum.UserInputType.Keyboard and inp.KeyCode == obj.Value) or (inp.UserInputType == obj.Value)
		if match then
			if obj.Mode == "Hold" then obj._held = true if obj.Callback then pcall(obj.Callback, true) end obj:_render()
			else doToggle() end
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
	local f = elementBase(self, 24)
	local l = MakeLabel(f, cfg.Text or idx, 13, false); l.Size = UDim2.new(1, -60, 1, 0)
	local obj = Library._AttachKeyPicker(nil, f, idx, cfg)
	obj.Frame = f
	registerSearch(self, cfg.Text or idx, f)
	return obj
end

-- ===================================================================================
-- ESP Preview
-- ===================================================================================
function GroupboxMethods:AddESPPreview(cfg)
	cfg = cfg or {}
	local tabsCfg = cfg.Tabs or { "Enemy", "Team" }
	local f = elementBase(self, 210)
	local tabBar = Create("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Parent = f })
	Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabBar })
	local canvas = Create("Frame", { Size = UDim2.new(1, 0, 0, 180), Position = UDim2.new(0, 0, 0, 28), ClipsDescendants = true, Parent = f })
	Library:AddToRegistry(canvas, { BackgroundColor3 = "Background" }); Corner(canvas, 5); Stroke(canvas, "Outline")
	local preview = { Frame = f, Tabs = {}, Active = nil }
	local function figure(parent, color)
		local fig = Create("Frame", { Size = UDim2.new(0, 60, 0, 130), Position = UDim2.new(0.5, -30, 0.5, -60), BackgroundTransparency = 1, Parent = parent })
		local head = Create("Frame", { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(0.5, -11, 0, 0), BackgroundColor3 = color, Parent = fig }); Corner(head, 11)
		local torso = Create("Frame", { Size = UDim2.fromOffset(30, 44), Position = UDim2.new(0.5, -15, 0, 26), BackgroundColor3 = color, Parent = fig }); Corner(torso, 4)
		local la = Create("Frame", { Size = UDim2.fromOffset(9, 40), Position = UDim2.new(0.5, -26, 0, 27), BackgroundColor3 = color, Parent = fig }); Corner(la, 4)
		local ra = Create("Frame", { Size = UDim2.fromOffset(9, 40), Position = UDim2.new(0.5, 17, 0, 27), BackgroundColor3 = color, Parent = fig }); Corner(ra, 4)
		local ll = Create("Frame", { Size = UDim2.fromOffset(12, 46), Position = UDim2.new(0.5, -14, 0, 72), BackgroundColor3 = color, Parent = fig }); Corner(ll, 4)
		local rl = Create("Frame", { Size = UDim2.fromOffset(12, 46), Position = UDim2.new(0.5, 2, 0, 72), BackgroundColor3 = color, Parent = fig }); Corner(rl, 4)
		return fig
	end
	for i, name in ipairs(tabsCfg) do
		local page = Create("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, Parent = canvas })
		local fig = figure(page, Color3.fromRGB(70, 70, 75))
		local box = Create("Frame", { Size = UDim2.new(0, 72, 0, 138), Position = UDim2.new(0.5, -36, 0.5, -66), BackgroundTransparency = 1, Parent = page })
		local boxStroke = Create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1.5, Parent = box })
		local nameL = Create("TextLabel", { Size = UDim2.new(0, 120, 0, 14), Position = UDim2.new(0.5, -60, 0.5, -84), BackgroundTransparency = 1, Text = "Player", TextSize = 12, FontFace = Library.FontFaceBold, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, Parent = page })
		local distL = Create("TextLabel", { Size = UDim2.new(0, 120, 0, 12), Position = UDim2.new(0.5, -60, 0.5, 72), BackgroundTransparency = 1, Text = "[42]", TextSize = 11, FontFace = Library.FontFace, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, Parent = page })
		local hpBg = Create("Frame", { Size = UDim2.new(0, 3, 0, 138), Position = UDim2.new(0.5, -42, 0.5, -66), BackgroundColor3 = Color3.new(0, 0, 0), Parent = page })
		local hp = Create("Frame", { Size = UDim2.new(1, 0, 0.75, 0), Position = UDim2.new(0, 0, 0.25, 0), BackgroundColor3 = Color3.fromRGB(60, 220, 90), BorderSizePixel = 0, Parent = hpBg })
		local tracer = Create("Frame", { Size = UDim2.new(0, 1, 0, 60), Position = UDim2.new(0.5, 0, 1, -60), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Rotation = 20, Parent = page })
		local weapon = Create("TextLabel", { Size = UDim2.new(0, 120, 0, 12), Position = UDim2.new(0.5, -60, 0.5, 84), BackgroundTransparency = 1, Text = "Weapon", TextSize = 11, FontFace = Library.FontFace, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0, Parent = page })
		local tab = { Name = name, Page = page, Parts = { Box = box, BoxStroke = boxStroke, Name = nameL, Distance = distL, HealthBg = hpBg, Health = hp, Tracer = tracer, Weapon = weapon, Figure = fig } }
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
		local tb = Create("TextButton", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Text = "", AutoButtonColor = false, LayoutOrder = i, Parent = tabBar })
		Library:AddToRegistry(tb, { BackgroundColor3 = "Element" }); Corner(tb, 4); Stroke(tb, "Outline"); Padding(tb, 10, 10, 0, 0)
		local tl = MakeLabel(tb, name, 11, true, "FontDim"); tl.AutomaticSize = Enum.AutomaticSize.X; tl.Size = UDim2.new(0, 0, 1, 0)
		tab._btn, tab._label = tb, tl
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

-- ===================================================================================
-- Unload
-- ===================================================================================
Library._onUnload = {}
function Library:OnUnload(fn) table.insert(self._onUnload, fn) end
function Library:Unload()
	if self.Unloaded then return end
	self.Unloaded = true
	for _, fn in ipairs(self._onUnload) do pcall(fn) end
	for _, c in ipairs(self.Signals) do pcall(function() c:Disconnect() end) end
	pcall(function() ScreenGui:Destroy() end)
end

return Library
