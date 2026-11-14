local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local Library
local function Notify(Text, Duration)
	Duration = Duration or 8
	if Library and Library.Notify then
		local Ok = pcall(Library.Notify, Library, { Title = "Umber", Description = Text, Time = Duration })
		if Ok then
			return
		end
	end
	pcall(StarterGui.SetCore, StarterGui, "SendNotification", { Title = "Umber", Text = Text, Duration = Duration })
end
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local LocalPlayer = Players.LocalPlayer
if not (LocalPlayer and LocalPlayer:WaitForChild("PlayerGui", 15)) then
	Notify("Join a game before running this script.")
	return
end
local Missing = {}
if not Drawing then table.insert(Missing, "Drawing") end
if not loadstring then table.insert(Missing, "loadstring") end
if not getgenv then table.insert(Missing, "getgenv") end
if #Missing > 0 then
	Notify("This executor is missing: " .. table.concat(Missing, ", "))
	return
end
local Env = getgenv()
if typeof(Env.UmberUnload) == "function" then
	pcall(Env.UmberUnload)
end
local Previous = Env.Library
if Previous
	and Previous.Unload
	and Previous.Options
	and Previous.Options.WalkSpeedToggle
	and Previous.Options.ZombieType
then
	pcall(Previous.Unload, Previous)
end
local HookState = Env.UmberHook
if not HookState then
	HookState = {}
	Env.UmberHook = HookState
end
local BaseUrl = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local LastLoadError
local function LoadModule(Path)
	for _ = 1, 3 do
		local Ok, Source = pcall(game.HttpGet, game, BaseUrl .. Path)
		if not Ok then
			LastLoadError = Path .. ": HttpGet failed: " .. tostring(Source)
		else
			local Chunk, CompileErr = loadstring(Source)
			if not Chunk then
				LastLoadError = Path .. ": compile failed: " .. tostring(CompileErr)
			else
				local RunOk, Module = pcall(Chunk)
				if RunOk and Module then
					return Module
				end
				LastLoadError = Path .. ": run failed: " .. tostring(Module)
			end
		end
		task.wait(1)
	end
end
Library = LoadModule("Library.lua")
local ThemeManager = LoadModule("addons/ThemeManager.lua")
local SaveManager = LoadModule("addons/SaveManager.lua")
if not (Library and ThemeManager and SaveManager) then
	Notify("Could not load Obsidian. " .. tostring(LastLoadError), 12)
	return
end
local Options, Toggles = Library.Options, Library.Toggles
local Window = Library:CreateWindow({ Title = "Umber", Footer = "v0.1", NotifySide = "Right", Font = Enum.Font.Gotham })
ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("Umber")
ThemeManager:SetDefaultTheme({ FontFace = "Gotham", FontColor = "ffffff", MainColor = "4d3b27", AccentColor = "a45b26",
	BackgroundColor = "6f472d", OutlineColor = "282828", BackgroundImage = ""
})
local Tabs = { Main = Window:AddTab("Main", "home"), Player = Window:AddTab("Player", "user"),
	Visuals = Window:AddTab("Visuals", "eye"), World = Window:AddTab("World", "sun"),
	Combat = Window:AddTab("Combat", "swords"), Settings = Window:AddTab("Settings", "settings")
}
local Unloaded, LoadingConfig = false, false
local Connections, Tracked, Visuals, FuseMarks, RenderSeen = {}, {}, {}, {}, {}
local TrackedCount, MaxTracked = 0, 60
local RenderView = { Camera = nil, Position = Vector3.zero, Look = Vector3.zero, Viewport = Vector2.zero, Now = 0 }
local SpeedModifier, ChargeSpeed, ChargeValue, ChargeRetries = nil, false, 55, 0
local AntiGrabEnabled = false
local EspIdle, LastESPUpdate, LastVisualRefresh = false, 0, 0
local AssistPicker
local HitboxConfig = { Enabled = false, Size = 5, Part = "All", IgnoreBarrel = false, Show = false, Transparency = 0.9 }
local MeleeConfig = { AutoHeadshot = false, Chance = 100, SwingSpeed = 1, SwingSpeedEnabled = false }
local ThrowableConfig = { MortarTimer = false, Trajectory = false }
local AimConfig = { Enabled = false, Types = { All = true }, FOV = 40, ShowFOV = false }
local WorldConfig = { Fullbright = false }
local WorldOriginal = { Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
	Brightness = Lighting.Brightness
}
local ZombieConfig = { Enabled = false, Types = { All = true }, Box = true, BoxStyle = "Box",
	BoxColor = Color3.fromRGB(164, 91, 38), Chams = false, ChamsColor = Color3.fromRGB(200, 80, 40),
	Tracers = false, TracerColor = Color3.fromRGB(164, 91, 38), Names = false,
	NameColor = Color3.fromRGB(255, 255, 255), NameStyle = "Text", Health = false,
	HealthColor = Color3.fromRGB(90, 200, 90), HealthStyle = "Text", Distance = true, BomberTimer = true,
	BomberTimerColor = Color3.fromRGB(255, 90, 60), BomberTimerPosition = "Bottom",
	BomberTimerOffsetX = 0, BomberTimerOffsetY = 0, BlastRadius = true,
	BlastRadiusColor = Color3.fromRGB(255, 90, 60)
}
local PlayerConfig = { Enabled = false, Box = true, BoxColor = Color3.fromRGB(120, 200, 130), Chams = false,
	ChamsColor = Color3.fromRGB(120, 200, 130), Tracers = false,
	TracerColor = Color3.fromRGB(120, 200, 130), Names = false,
	NameColor = Color3.fromRGB(255, 255, 255), NameStyle = "Text", Health = false,
	HealthColor = Color3.fromRGB(90, 200, 90), HealthStyle = "Text", Distance = true, Infection = true,
	InfectionColor = Color3.fromRGB(190, 70, 70), Grabbed = true,
	GrabbedColor = Color3.fromRGB(255, 70, 70), Pinned = true,
	PinnedColor = Color3.fromRGB(255, 170, 60), Burning = false,
	BurningColor = Color3.fromRGB(255, 130, 40), BrokenLegs = false,
	BrokenLegsColor = Color3.fromRGB(180, 180, 255), BoxStyle = "Box"
}
local ZombieColors = { Normal = Color3.fromRGB(120, 220, 120), Fast = Color3.fromRGB(80, 190, 255),
	Barrel = Color3.fromRGB(255, 130, 60), Sapper = Color3.fromRGB(255, 220, 90),
	Igniter = Color3.fromRGB(200, 110, 255), Cuirassier = Color3.fromRGB(100, 230, 200),
	Crawler = Color3.fromRGB(255, 120, 200), Headless = Color3.fromRGB(235, 235, 235),
	BigBoy = Color3.fromRGB(255, 70, 70)
}
local ZombieNames = { Normal = "Shambler", Fast = "Runner", Barrel = "Bomber", Sapper = "Sapper", Igniter = "Igniter",
	Cuirassier = "Cuirassier", Crawler = "Crawler", Headless = "Headless", BigBoy = "Big Boy"
}
local ZombieTypeValues = { "All", "Shambler", "Runner", "Bomber", "Sapper", "Igniter", "Cuirassier", "Crawler", "Headless",
	"Big Boy"
}
local HitboxPartNames = { Head = { Head = true }, Torso = { Torso = true },
	Legs = { ["Left Leg"] = true, ["Right Leg"] = true }, HumanoidRootPart = { HumanoidRootPart = true }
}
local PinLabels = { RunnerTackle = "Tackled", RunnerAttack = "Pinned", RunnerClaw = "Clawed",
	RunnerVomit = "Vomited On", SapperBlocked = "Sapper Block", CuirassierImpale = "Impaled"
}
local function Track(Connection)
	table.insert(Connections, Connection)
	return Connection
end
local function EnsureEnabled(Name)
	local Toggle = Toggles[Name]
	if not LoadingConfig and Toggle and not Toggle.Value then
		Toggle:SetValue(true)
	end
end
local WriteCache = setmetatable({}, { __mode = "k" })
local function Set(Target, Prop, Value)
	local Memo = WriteCache[Target]
	if not Memo then
		Memo = {}
		WriteCache[Target] = Memo
	end
	if Memo[Prop] ~= Value then
		Memo[Prop] = Value
		Target[Prop] = Value
	end
end
local function NewDrawing(Class, Props)
	local Object = Drawing.new(Class)
	for Key, Value in Props do
		Object[Key] = Value
	end
	Object.Visible = false
	return Object
end
local function CreateText(Size)
	return NewDrawing("Text", { Size = Size, Center = true, Outline = true, OutlineColor = Color3.new(0, 0, 0) })
end
local function RemoveDrawing(Object)
	pcall(function()
		Object:Remove()
	end)
end
local function GetZombieLabel(Model)
	local Type = Model:GetAttribute("Type")
	if Type == nil then
		return Model.Name
	end
	return ZombieNames[Type] or tostring(Type)
end
local function TypeAllowed(Types, Model)
	return Types.All or Types[GetZombieLabel(Model)] == true
end
local function IsBarrel(Model)
	return Model:GetAttribute("Type") == "Barrel"
end
local function ApplyWorldLighting()
	if Unloaded then
		return
	end
	if WorldConfig.Fullbright then
		Lighting.Ambient = Color3.new(1, 1, 1)
		Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
		Lighting.Brightness = 3
	else
		Lighting.Ambient = WorldOriginal.Ambient
		Lighting.OutdoorAmbient = WorldOriginal.OutdoorAmbient
		Lighting.Brightness = WorldOriginal.Brightness
	end
end
local function ClearChargeSpeed()
	if SpeedModifier and SpeedModifier.Parent then
		SpeedModifier:Destroy()
	end
	SpeedModifier, ChargeRetries = nil, 0
end
local function ApplyChargeSpeed()
	if Unloaded then
		return
	end
	if not ChargeSpeed then
		ClearChargeSpeed()
		return
	end
	if SpeedModifier and SpeedModifier.Parent then
		SpeedModifier.Value, ChargeRetries = ChargeValue, 0
		return
	end
	SpeedModifier = nil
	local Character = LocalPlayer.Character
	local _sc4 = Character and Character:FindFirstChild("UserStates")
	local States = _sc4
	local _sc5 = _sc4 and States:FindFirstChild("SpeedController")
	local Module = _sc5
	if _sc5 then
		local Ok, Controller = pcall(require, Module)
		local Added, Modifier = false, nil
		if Ok then
			Added, Modifier = pcall(function()
				return Controller.AddModifier("Charge", ChargeValue, 100)
			end)
		end
		if Added and typeof(Modifier) == "Instance" then
			SpeedModifier, ChargeRetries = Modifier, 0
			Modifier.Destroying:Once(function()
				SpeedModifier = nil
				task.defer(ApplyChargeSpeed)
			end)
			return
		end
	end
	if ChargeRetries < 20 then
		ChargeRetries += 1
		task.delay(0.25, ApplyChargeSpeed)
	end
end
local function SpoofGrabPosition()
	local Character = LocalPlayer.Character
	local _sc3 = Character and Character:FindFirstChildOfClass("Humanoid")
	local Humanoid = _sc3
	if AntiGrabEnabled and _sc3 then
		Humanoid:Move(Vector3.new(0, 100000, 0))
	end
end
local SwingBuffs = setmetatable({}, { __mode = "k" })
local function ClearSwingBuffs()
	for Tool, Buff in SwingBuffs do
		if Buff.Parent == Tool then
			Buff:Destroy()
		end
	end
	table.clear(SwingBuffs)
end
local function IsMeleeTool(Tool)
	local Animations = Tool:FindFirstChild("Animations")
	local _sc3 = Animations ~= nil
	if _sc3 then
		local _sc4_s1 = Animations:FindFirstChild("SwingRight") ~= nil or Animations:FindFirstChild("SwingDown") ~= nil
		_sc3 = _sc4_s1 or Animations:FindFirstChild("Thrust") ~= nil
	end
	return _sc3
end
local function ApplySwingSpeed()
	if Unloaded then
		return
	end
	if MeleeConfig.SwingSpeed <= 1 or not MeleeConfig.SwingSpeedEnabled then
		ClearSwingBuffs()
		return
	end
	local Character = LocalPlayer.Character
	local _sc4 = Character and Character:FindFirstChildOfClass("Tool")
	local Tool = _sc4
	if not _sc4 or not IsMeleeTool(Tool) then
		return
	end
	local Buff = SwingBuffs[Tool]
	if not Buff or Buff.Parent ~= Tool then
		Buff = Tool:FindFirstChild("SwingSpeedBuff")
		if not Buff then
			Buff = Instance.new("NumberValue")
			Buff.Name = "SwingSpeedBuff"
			Buff.Parent = Tool
		end
		SwingBuffs[Tool] = Buff
	end
	Set(Buff, "Value", (MeleeConfig.SwingSpeed - 1) / 0.35)
end
local NearPlane = 0.1
local ProjectCorners, ProjectDepth, Bounds = table.create(8), table.create(8), { 0, 0, 0, 0 }
local ProjectEdges = { { 1, 2 }, { 3, 4 }, { 1, 3 }, { 2, 4 }, { 5, 6 }, { 7, 8 }, { 5, 7 }, { 6, 8 }, { 1, 5 }, { 2, 6 },
	{ 3, 7 }, { 4, 8 }
}
local function Expand(Point)
	Bounds[1], Bounds[2] = math.min(Bounds[1], Point.X), math.min(Bounds[2], Point.Y)
	Bounds[3], Bounds[4] = math.max(Bounds[3], Point.X), math.max(Bounds[4], Point.Y)
end
local function ProjectModel(Model, Camera)
	local Ok, BoxCFrame, BoxSize = pcall(Model.GetBoundingBox, Model)
	if not Ok then
		return nil
	end
	Bounds[1], Bounds[2], Bounds[3], Bounds[4] = math.huge, math.huge, -math.huge, -math.huge
	local Visible, AllFront = false, true
	for Index = 0, 7 do
		local World = BoxCFrame
			* Vector3.new(
				BoxSize.X * (Index % 2 == 0 and 0.5 or -0.5),
				BoxSize.Y * (Index // 2 % 2 == 0 and 0.5 or -0.5),
				BoxSize.Z * (Index < 4 and 0.5 or -0.5)
			)
		local Point = Camera:WorldToViewportPoint(World)
		ProjectCorners[Index + 1], ProjectDepth[Index + 1] = World, Point.Z
		if Point.Z > NearPlane then
			Visible = true
			Expand(Point)
		else
			AllFront = false
		end
	end
	if not AllFront then
		for Index = 1, 12 do
			local Edge = ProjectEdges[Index]
			local DepthA, DepthB = ProjectDepth[Edge[1]], ProjectDepth[Edge[2]]
			if DepthA > NearPlane ~= (DepthB > NearPlane) then
				local A, B = ProjectCorners[Edge[1]], ProjectCorners[Edge[2]]
				local Point = Camera:WorldToViewportPoint(A + (B - A) * ((NearPlane - DepthA) / (DepthB - DepthA)))
				if Point.Z > 0 then
					Visible = true
					Expand(Point)
				end
			end
		end
	end
	if not Visible then
		return nil
	end
	return Bounds[1], Bounds[2], Bounds[3], Bounds[4]
end
local function MakeEntry(Kind)
	local Entry = { Kind = Kind, All = {}, StatusTexts = {}, Suppressed = {}, SuppressAt = 0 }
	local function Add(Object)
		table.insert(Entry.All, Object)
		return Object
	end
	Entry.Fill = Add(NewDrawing("Square", { Filled = true, Thickness = 1, Transparency = 0.9 }))
	Entry.Box = Add(NewDrawing("Square", { Filled = false, Thickness = 1 }))
	Entry.Tracer = Add(NewDrawing("Line", { Thickness = 1 }))
	Entry.NameText, Entry.HealthText = Add(CreateText(14)), Add(CreateText(13))
	if Kind == "zombie" then
		Entry.TimerText = Add(CreateText(14))
	else
		for Index = 1, 5 do
			Entry.StatusTexts[Index] = Add(CreateText(13))
		end
	end
	return Entry
end
local function EnsureCorners(Entry)
	if not Entry.Corners then
		Entry.Corners = {}
		for Index = 1, 8 do
			Entry.Corners[Index] = NewDrawing("Line", { Thickness = 2 })
			table.insert(Entry.All, Entry.Corners[Index])
		end
	end
	return Entry.Corners
end
local function RestoreHighlights(Entry)
	for Highlight, Enabled in Entry.Suppressed do
		if Highlight.Parent then
			Highlight.Enabled = Enabled
		end
	end
	table.clear(Entry.Suppressed)
	Entry.SuppressTarget = nil
end
local function SuppressHighlights(Entry, Model, Ours)
	for Highlight in Entry.Suppressed do
		if not Highlight.Parent then
			Entry.Suppressed[Highlight] = nil
		end
	end
	for _, Child in Model:GetChildren() do
		if Child:IsA("Highlight") and Child ~= Ours then
			if Entry.Suppressed[Child] == nil then
				Entry.Suppressed[Child] = Child.Enabled
			end
			Child.Enabled = false
		end
	end
end
local function DestroyEntry(Entry)
	RestoreHighlights(Entry)
	for _, Object in Entry.All do
		RemoveDrawing(Object)
	end
	if Entry.Highlight then
		pcall(Entry.Highlight.Destroy, Entry.Highlight)
	end
	if Entry.Gui then
		pcall(Entry.Gui.Holder.Destroy, Entry.Gui.Holder)
	end
end
local function Drop(Model)
	local Entry = Tracked[Model]
	if Entry then
		DestroyEntry(Entry)
		Tracked[Model] = nil
		TrackedCount -= 1
	end
	FuseMarks[Model] = nil
end
local function GetEntry(Model, Kind)
	local Entry = Tracked[Model]
	if Entry and Entry.Kind ~= Kind then
		Drop(Model)
		Entry = nil
	end
	if not Entry then
		if TrackedCount >= MaxTracked then
			return nil
		end
		Entry = MakeEntry(Kind)
		Tracked[Model] = Entry
		TrackedCount += 1
	end
	return Entry
end
local function HideEntry(Entry)
	for _, Object in Entry.All do
		Set(Object, "Visible", false)
	end
	if Entry.Highlight then
		Set(Entry.Highlight, "Enabled", false)
	end
	RestoreHighlights(Entry)
	if Entry.Gui then
		Set(Entry.Gui.Holder, "Enabled", false)
	end
end
local function EnsureGui(Entry, Model)
	if Entry.Gui and Entry.Gui.Holder.Parent then
		return
	end
	local _sc4_s1 = Model:FindFirstChild("Head") or Model:FindFirstChild("HumanoidRootPart")
	local Head = _sc4_s1
	if not _sc4_s1 then
		return
	end
	local Holder = Instance.new("BillboardGui")
	Holder.Name, Holder.AlwaysOnTop, Holder.LightInfluence, Holder.ResetOnSpawn = "UmberESP", true, 0, false
	Holder.Size, Holder.StudsOffset = UDim2.fromOffset(150, 34), Vector3.new(0, 2.4, 0)
	Holder.Parent = Head
	local NameLabel = Instance.new("TextLabel")
	NameLabel.BackgroundColor3, NameLabel.BackgroundTransparency, NameLabel.BorderSizePixel = Color3.new(0, 0, 0), 0.35, 0
	NameLabel.Font, NameLabel.TextSize, NameLabel.TextColor3 = Enum.Font.GothamBold, 13, Color3.new(1, 1, 1)
	NameLabel.Size, NameLabel.Visible, NameLabel.Parent = UDim2.new(1, 0, 0, 16), false, Holder
	local HealthBack = Instance.new("Frame")
	HealthBack.BackgroundColor3, HealthBack.BackgroundTransparency, HealthBack.BorderSizePixel = Color3.new(0, 0, 0), 0.35, 0
	HealthBack.Size, HealthBack.Visible, HealthBack.Parent = UDim2.new(1, 0, 0, 6), false, Holder
	local HealthFill = Instance.new("Frame")
	HealthFill.BorderSizePixel, HealthFill.Size, HealthFill.Parent = 0, UDim2.fromScale(1, 1), HealthBack
	Entry.Gui = { Holder = Holder, NameLabel = NameLabel, HealthBack = HealthBack, HealthFill = HealthFill }
end
local function RefreshVisuals(Now)
	if Now - LastVisualRefresh < 0.1 then
		return
	end
	LastVisualRefresh = Now
	table.clear(Visuals)
	local Camera = workspace.CurrentCamera
	for _, Child in Camera and Camera:GetChildren() or {} do
		local Orig = Child:FindFirstChild("Orig")
		if Orig and Orig:IsA("ObjectValue") and Orig.Value then
			Visuals[Orig.Value] = Child
		end
	end
end
local function GetVisual(Model)
	local Visual = Visuals[Model]
	if Visual and Visual.Parent then
		return Visual
	end
	local Ref = Model:FindFirstChild("ClientRef")
	if Ref and Ref:IsA("ObjectValue") and Ref.Value then
		return Ref.Value
	end
	return Model
end
local function EnsureHighlight(Entry, Target)
	if Entry.Highlight and Entry.Highlight.Parent == Target then
		return Entry.Highlight
	end
	if Entry.Highlight then
		pcall(Entry.Highlight.Destroy, Entry.Highlight)
	end
	local Highlight = Instance.new("Highlight")
	Highlight.Name, Highlight.DepthMode = "UmberChams", Enum.HighlightDepthMode.AlwaysOnTop
	Highlight.FillTransparency, Highlight.OutlineTransparency, Highlight.Parent = 0.55, 0.1, Target
	Entry.Highlight = Highlight
	return Highlight
end
local function GetStatuses(Model)
	local List = {}
	local States = Model:FindFirstChild("UserStates")
	if not States then
		return List
	end
	local function State(Name)
		local Object = States:FindFirstChild(Name)
		return Object and Object.Value
	end
	local Infected, Grabbed, Pin, BrokenLegs = State("Infected"), State("Grabbed"), State("Pin"), State("BrokenLegs")
	local Burning = Model:GetAttribute("Burning")
	if PlayerConfig.Infection and typeof(Infected) == "number" and Infected > 0 then
		table.insert(List, { Text = string.format("Infection %d%%", math.floor(Infected + 0.5)),
			Color = PlayerConfig.InfectionColor
		})
	end
	if PlayerConfig.Grabbed and typeof(Grabbed) == "number" and Grabbed > 0 then
		table.insert(List, { Text = "Grabbed", Color = PlayerConfig.GrabbedColor })
	end
	if PlayerConfig.Pinned and typeof(Pin) == "string" and Pin ~= "None" and Pin ~= "" then
		table.insert(List, { Text = PinLabels[Pin] or Pin, Color = PlayerConfig.PinnedColor })
	end
	if PlayerConfig.Burning and Burning and Burning ~= 0 then
		table.insert(List, { Text = "Burning", Color = PlayerConfig.BurningColor })
	end
	if PlayerConfig.BrokenLegs and BrokenLegs then
		table.insert(List, { Text = "Broken Legs", Color = PlayerConfig.BrokenLegsColor })
	end
	return List
end
local function GetFuseRemaining(Model)
	local State = Model:FindFirstChild("State")
	if not (State and State:GetChildren()[1]) then
		FuseMarks[Model] = nil
		return nil
	end
	local FuseMarks_v1 = FuseMarks
	local _sc4 = FuseMarks[Model]
	FuseMarks_v1[Model] = _sc4 or os.clock()
	return math.max(0, 3.5 - (os.clock() - FuseMarks[Model]))
end
local function RenderModel(Model, Kind, View)
	local Config = Kind == "zombie" and ZombieConfig or PlayerConfig
	local Cached = Tracked[Model]
	local _sc3 = Cached and Cached.Humanoid
	local Humanoid = _sc3
	if not (_sc3 and Humanoid.Parent) then
		Humanoid = Model:FindFirstChildOfClass("Humanoid")
	end
	if not Humanoid or Humanoid.Health <= 0 then
		return
	end
	local _sc6 = Cached and Cached.Root
	local Root = _sc6
	if not (_sc6 and Root.Parent) then
		Root = Model:FindFirstChild("HumanoidRootPart")
	end
	local _sc8 = Root and Root.Position
	local RootPos = _sc8
	if _sc8 and (RootPos - View.Position):Dot(View.Look) < -2 then
		return
	end
	local Label, Type
	if Kind == "zombie" then
		Type, Label = Model:GetAttribute("Type"), GetZombieLabel(Model)
		if not TypeAllowed(ZombieConfig.Types, Model) then
			return
		end
	else
		local Player = Players:FindFirstChild(Model.Name)
		local displayName = Player and Player.DisplayName
		local _sc10 = displayName
		Label = if displayName then _sc10 else Model.Name
	end
	local MinX, MinY, MaxX, MaxY = ProjectModel(Model, View.Camera)
	if not MinX then
		return
	end
	local Entry = GetEntry(Model, Kind)
	if not Entry then
		return
	end
	Entry.Humanoid, Entry.Root = Humanoid, Root
	RenderSeen[Model] = true
	local CenterX = (MinX + MaxX) * 0.5
	if Config.Distance then
		local _sc10 = RootPos
		local format = string.format
		if RootPos then
			local string_v1 = string
			_sc10 = math.floor((RootPos - View.Position).Magnitude)
		end
		Label = format("%s [%dm]", Label, _sc10 or 0)
	end
	local TypeColor = Kind == "zombie" and ZombieColors[Type] or nil
	local Style = Config.BoxStyle
	local ShowBox, ShowCorners = Config.Box and Style ~= "Corner", Config.Box and Style == "Corner"
	local ShowFill = ShowBox and Style == "Filled Box"
	local BoxColor = TypeColor or Config.BoxColor
	Set(Entry.Box, "Visible", ShowBox)
	Set(Entry.Fill, "Visible", ShowFill)
	local _sc12 = ShowCorners and EnsureCorners(Entry) or Entry.Corners
	local Corners = _sc12
	for Index = 1, _sc12 and 8 or 0 do
		Set(Corners[Index], "Visible", ShowCorners)
	end
	if ShowBox then
		local Position, Size = Vector2.new(MinX, MinY), Vector2.new(MaxX - MinX, MaxY - MinY)
		local ShowFill_v1 = ShowFill
		local Box = Entry.Box
		if ShowFill then
			ShowFill_v1 = Entry.Fill
		end
		for _, Square in { Box, ShowFill_v1 or nil } do
			Set(Square, "Color", BoxColor)
			Set(Square, "Position", Position)
			Set(Square, "Size", Size)
		end
	elseif ShowCorners then
		local Length = math.clamp(math.min(MaxX - MinX, MaxY - MinY) * 0.25, 4, 18)
		for Index = 1, 4 do
			local X, Y = Index % 2 == 1 and MinX or MaxX, Index <= 2 and MinY or MaxY
			local _t2165 = Index % 2
			local _sc15 = Index <= 2 and 1 or -1
			local Horizontal, Vertical = Corners[Index * 2 - 1], Corners[Index * 2]
			Set(Horizontal, "Color", BoxColor)
			Set(Horizontal, "From", Vector2.new(X, Y))
			Set(Horizontal, "To", Vector2.new(X + (_t2165 == 1 and 1 or -1) * Length, Y))
			Set(Vertical, "Color", BoxColor)
			Set(Vertical, "From", Vector2.new(X, Y))
			Set(Vertical, "To", Vector2.new(X, Y + _sc15 * Length))
		end
	end
	Set(Entry.Tracer, "Visible", Config.Tracers)
	if Config.Tracers then
		Set(Entry.Tracer, "Color", Config.TracerColor)
		Set(Entry.Tracer, "From", Vector2.new(View.Viewport.X * 0.5, View.Viewport.Y))
		Set(Entry.Tracer, "To", Vector2.new(CenterX, MaxY))
	end
	local NameOn, HealthOn = Config.Names, Config.Health
	local NameText, NameGui = NameOn and Config.NameStyle ~= "GUI", NameOn and Config.NameStyle ~= "Text"
	local HealthText, HealthGui = HealthOn and Config.HealthStyle ~= "GUI", HealthOn and Config.HealthStyle ~= "Text"
	Set(Entry.NameText, "Visible", NameText)
	if NameText then
		Set(Entry.NameText, "Text", Label)
		Set(Entry.NameText, "Color", Config.NameColor)
		Set(Entry.NameText, "Position", Vector2.new(CenterX, MinY - 18))
	end
	Set(Entry.HealthText, "Visible", HealthText)
	if HealthText then
		Set(Entry.HealthText, "Text", string.format("%d HP", math.ceil(Humanoid.Health)))
		Set(Entry.HealthText, "Color", Config.HealthColor)
		Set(Entry.HealthText, "Position", Vector2.new(CenterX, MinY - (NameText and 34 or 18)))
	end
	if NameGui or HealthGui then
		EnsureGui(Entry, Model)
	end
	local Gui = Entry.Gui
	if Gui and Gui.Holder.Parent then
		Set(Gui.NameLabel, "Visible", NameGui)
		Set(Gui.HealthBack, "Visible", HealthGui)
		if NameGui then
			Set(Gui.NameLabel, "Text", Label)
			Set(Gui.NameLabel, "TextColor3", Config.NameColor)
		end
		if HealthGui then
			Set(Gui.HealthFill, "Size", UDim2.fromScale(math.clamp(Humanoid.Health / Humanoid.MaxHealth, 0, 1), 1))
			Set(Gui.HealthFill, "BackgroundColor3", Config.HealthColor)
			Set(Gui.HealthBack, "Position", UDim2.fromOffset(0, NameGui and 18 or 0))
		end
		Set(Gui.Holder, "Size", UDim2.fromOffset(150, (NameGui and 18 or 0) + (HealthGui and 8 or 0)))
		Set(Gui.Holder, "Enabled", NameGui or HealthGui)
	elseif Gui then
		Set(Gui.Holder, "Enabled", false)
	end
	if Config.Chams then
		local Target = GetVisual(Model)
		local Highlight = EnsureHighlight(Entry, Target)
		local TypeColor_v1 = TypeColor
		if not TypeColor then
			local Set_v1 = Set
			TypeColor_v1 = Config.ChamsColor
		end
		Set(Highlight, "FillColor", TypeColor_v1)
		local TypeColor_v2 = TypeColor
		if not TypeColor then
			local Set_v1 = Set
			TypeColor_v2 = Config.ChamsColor
		end
		Set(Highlight, "OutlineColor", TypeColor_v2)
		Set(Highlight, "Enabled", true)
		if Entry.SuppressTarget ~= Target or View.Now - Entry.SuppressAt >= 0.25 then
			Entry.SuppressTarget, Entry.SuppressAt = Target, View.Now
			SuppressHighlights(Entry, Target, Highlight)
		end
	else
		if Entry.Highlight then
			Set(Entry.Highlight, "Enabled", false)
		end
		RestoreHighlights(Entry)
	end
	if Kind == "zombie" then
		local Remaining = Config.BomberTimer and Type == "Barrel" and GetFuseRemaining(Model) or nil
		Set(Entry.TimerText, "Visible", Remaining ~= nil)
		if Remaining then
			local Where, MidY = Config.BomberTimerPosition, (MinY + MaxY) * 0.5
			local TimerX, TimerY = CenterX, MaxY + 4
			if Where == "Top" then
				TimerY = MinY - 18
			elseif Where == "Center" then
				TimerY = MidY
			elseif Where == "Left" then
				TimerX, TimerY = MinX - 6, MidY
			elseif Where == "Right" then
				TimerX, TimerY = MaxX + 6, MidY
			end
			Set(Entry.TimerText, "Text", string.format("%.1fs", Remaining))
			Set(Entry.TimerText, "Color", Config.BomberTimerColor)
			Set(Entry.TimerText, "Position", Vector2.new(TimerX + Config.BomberTimerOffsetX, TimerY + Config.BomberTimerOffsetY))
		end
	else
		local Statuses = GetStatuses(Model)
		for Index, StatusText in Entry.StatusTexts do
			local Status = Statuses[Index]
			Set(StatusText, "Visible", Status ~= nil)
			if Status then
				Set(StatusText, "Text", Status.Text)
				Set(StatusText, "Color", Status.Color)
				Set(StatusText, "Position", Vector2.new(CenterX, MaxY + 4 + (Index - 1) * 14))
			end
		end
	end
end
local function UpdateESP()
	local Now = time()
	local _sc3 = Unloaded
	if if Unloaded then _sc3 else Now - LastESPUpdate < 1 / 30 then
		return
	end
	LastESPUpdate = Now
	if not (ZombieConfig.Enabled or PlayerConfig.Enabled) then
		for Model, Entry in Tracked do
			if not Model.Parent then
				Drop(Model)
			elseif not EspIdle then
				HideEntry(Entry)
			end
		end
		EspIdle = true
		return
	end
	EspIdle = false
	local Camera = workspace.CurrentCamera
	if not Camera then
		return
	end
	if ZombieConfig.Enabled then
		RefreshVisuals(Now)
	end
	local View, CamCF = RenderView, Camera.CFrame
	RenderView.Camera, RenderView.Position, RenderView.Look = Camera, CamCF.Position, CamCF.LookVector
	View.Viewport, View.Now = Camera.ViewportSize, Now
	table.clear(RenderSeen)
	for _, Source in { { ZombieConfig, "Zombies", "zombie" }, { PlayerConfig, "Players", "player" } } do
		local _sc5 = Source[1].Enabled and workspace:FindFirstChild(Source[2])
		local Container = _sc5
		for _, Model in _sc5 and Container:GetChildren() or {} do
			if Model:IsA("Model") and Model ~= LocalPlayer.Character then
				RenderModel(Model, Source[3], View)
			end
		end
	end
	for Model, Entry in Tracked do
		if RenderSeen[Model] then
			continue
		end
		if Model.Parent then
			HideEntry(Entry)
		else
			Drop(Model)
		end
	end
end
local BlastRings = setmetatable({}, { __mode = "k" })
local BlastRingSegments, LastBlastRing = 36, 0
local function DestroyBlastRing(Model)
	for _, Line in BlastRings[Model] or {} do
		RemoveDrawing(Line)
	end
	BlastRings[Model] = nil
end
local function UpdateBlastRings()
	if Unloaded then
		return
	end
	if not ZombieConfig.BlastRadius then
		for Model in BlastRings do
			DestroyBlastRing(Model)
		end
		return
	end
	local Now = time()
	local Camera, Container = workspace.CurrentCamera, workspace:FindFirstChild("Zombies")
	if Now - LastBlastRing < 0.05 or not Camera or not Container then
		return
	end
	LastBlastRing = Now
	local Seen = {}
	for _, Model in Container:GetChildren() do
		if not (Model:IsA("Model") and IsBarrel(Model) and GetFuseRemaining(Model)) then
			continue
		end
		Seen[Model] = true
		local Radius = Model:GetAttribute("BlastRadius")
		local Radius_s1 = typeof(Radius) == "number" and Radius or 10
		local BoxCFrame, BoxSize = Model:GetBoundingBox()
		local Center = Vector3.new(BoxCFrame.Position.X, BoxCFrame.Position.Y - BoxSize.Y * 0.5 + 0.15, BoxCFrame.Position.Z)
		local Ring = BlastRings[Model]
		if not Ring then
			Ring = {}
			BlastRings[Model] = Ring
		end
		for Index = #Ring + 1, BlastRingSegments do
			Ring[Index] = NewDrawing("Line", { Thickness = 1.5, Transparency = 0.75 })
		end
		for Index = 1, BlastRingSegments do
			local AngleA, AngleB = (Index - 1) / BlastRingSegments * math.pi * 2, Index / BlastRingSegments * math.pi * 2
			local ScreenA, OnA = Camera:WorldToViewportPoint(Center + Vector3.new(math.cos(AngleA) * Radius_s1, 0, math.sin(AngleA) * Radius_s1))
			local ScreenB, OnB = Camera:WorldToViewportPoint(Center + Vector3.new(math.cos(AngleB) * Radius_s1, 0, math.sin(AngleB) * Radius_s1))
			local Line = Ring[Index]
			Set(Line, "Visible", OnA and OnB)
			if OnA and OnB then
				Set(Line, "From", Vector2.new(ScreenA.X, ScreenA.Y))
				Set(Line, "To", Vector2.new(ScreenB.X, ScreenB.Y))
				Set(Line, "Color", ZombieConfig.BlastRadiusColor)
			end
		end
	end
	for Model in BlastRings do
		if not Seen[Model] then
			DestroyBlastRing(Model)
		end
	end
end
local HitboxParts, HitboxPartsStamp = {}, 0
local function RefreshHitboxParts()
	local Now = time()
	if Now - HitboxPartsStamp < 0.05 then
		return
	end
	HitboxPartsStamp = Now
	local Camera, Container = workspace.CurrentCamera, workspace:FindFirstChild("Zombies")
	local Names, List = HitboxPartNames[HitboxConfig.Part], {}
	if Camera and Container then
		local Matched = {}
		for _, Child in Camera:GetChildren() do
			local Orig = Child:FindFirstChild("Orig")
			if Orig and Orig:IsA("ObjectValue") and Orig.Value and Orig.Value:IsDescendantOf(Container) then
				Matched[Child] = Orig.Value
			end
		end
		for _, Model in Container:GetChildren() do
			local Ref = Model:FindFirstChild("ClientRef")
			if Ref and Ref:IsA("ObjectValue") and Ref.Value and Ref.Value.Parent == Camera then
				Matched[Ref.Value] = Matched[Ref.Value] or Model
			end
		end
		for Visual, Agent in Matched do
			if HitboxConfig.IgnoreBarrel and IsBarrel(Agent) then
				continue
			end
			for _, Part in Visual:GetChildren() do
				if Part:IsA("BasePart") then
					if not Names or Names[Part.Name] then
						table.insert(List, Part)
					end
				end
			end
		end
	end
	HitboxParts = List
end
local function FindExpandedHit(Origin, Direction, Filter)
	local Length = Direction.Magnitude
	if Length <= 0 then
		return nil
	end
	local Unit, Radius = Direction / Length, HitboxConfig.Size * 0.5
	local BestPart, BestPoint, BestNormalDir
	local BestAlong, BestCost, BestExtent = math.huge, math.huge, 0
	for _, Part in HitboxParts do
		local Along = (Part.Position - Origin):Dot(Unit)
		if not (Along >= -Radius and Along <= Length + Radius and not table.find(Filter, Part)) then
			continue
		end
		local Clamped = math.clamp(Along, 0, Length)
		local Point = Origin + Unit * Clamped
		local Perp = Part.Position - Point
		local Gap = Perp.Magnitude
		local Size = Part.Size
		if Gap <= Radius + math.max(Size.X, Size.Y, Size.Z) * 0.5 then
			local Extent, NormalDir = 0, nil
			if Gap > 0.0001 then
				NormalDir = Perp / Gap
				local Frame = Part.CFrame
				Extent = math.abs(NormalDir:Dot(Frame.RightVector)) * Size.X * 0.5
					+ math.abs(NormalDir:Dot(Frame.UpVector)) * Size.Y * 0.5
					+ math.abs(NormalDir:Dot(Frame.LookVector)) * Size.Z * 0.5
			end
			local Cost = Clamped + Gap
			if Gap <= Radius + Extent and Cost < BestCost then
				BestPart, BestPoint, BestAlong, BestCost, BestNormalDir, BestExtent = Part, Point, Clamped, Cost, NormalDir, Extent
			end
		end
	end
	if not BestPart then
		return nil
	end
	local Normal, Position = -Unit, BestPoint
	if BestNormalDir then
		Position, Normal = BestPart.Position - BestNormalDir * BestExtent, -BestNormalDir
	end
	return { Instance = BestPart, Position = Position, Normal = Normal, Distance = BestAlong,
		Material = Enum.Material.Plastic
	}
end
local function MakeHeadshot(Result, Origin, Direction)
	local Part = Result.Instance
	local _sc3_s1 = not Part or not Part.Parent
	local _sc3_s2 = _sc3_s1 or Part.Parent.Name ~= "m_Zombie"
	if _sc3_s2 or Part.Name == "Head" then
		return nil
	end
	if math.random() * 100 > MeleeConfig.Chance then
		return nil
	end
	local Head = Part.Parent:FindFirstChild("Head")
	if not Head or not Head:IsA("BasePart") then
		return nil
	end
	local Length = Direction.Magnitude
	local Head_Position = Head.Position
	local _sc6 = Length > 0 and -Direction / Length
	return { Instance = Head, Position = Head_Position, Normal = _sc6 or Vector3.yAxis,
		Distance = (Head.Position - Origin).Magnitude, Material = Enum.Material.Plastic
	}
end
local function ProcessMeleeRay(Origin, Direction, Params, Built)
	local Filter = Params.FilterDescendantsInstances
	if not Filter or not rawequal(Filter[1], workspace:FindFirstChild("Zombies")) then
		return Built
	end
	local Result = Built
	if HitboxConfig.Enabled then
		RefreshHitboxParts()
		local Expanded = FindExpandedHit(Origin, Direction, Filter)
		local _sc4 = Expanded
		if Expanded then
			_sc4 = not Result or Expanded.Distance < Result.Distance
		end
		if _sc4 then
			Result = Expanded
		end
	end
	if Result and MeleeConfig.AutoHeadshot then
		Result = MakeHeadshot(Result, Origin, Direction) or Result
	end
	return Result
end
local function RaycastHandler(Original, Self, ...)
	local Origin, Direction, Params = ...
	local Built = Original(Self, ...)
	if typeof(Params) ~= "RaycastParams" or Params.CollisionGroup ~= "Raycast" then
		return Built
	end
	local Ok, Result = pcall(ProcessMeleeRay, Origin, Direction, Params, Built)
	if Ok and Result then
		return Result
	end
	return Built
end
local function EnsureHook()
	if HookState.Installed or typeof(hookmetamethod) ~= "function" then
		return
	end
	local Original
	local Wrap = newcclosure or function(Function)
		return Function
	end
	local Ok, Result = pcall(hookmetamethod, game, "__namecall", Wrap(function(Self, ...)
		local Handler = HookState.Handler
		if Handler
			and Self == workspace
			and getnamecallmethod() == "Raycast"
			and not (checkcaller and checkcaller())
		then
			return Handler(Original, Self, ...)
		end
		return Original(Self, ...)
	end))
	if Ok and typeof(Result) == "function" then
		Original, HookState.Installed = Result, true
	end
end
local function SyncHook()
	if HitboxConfig.Enabled or MeleeConfig.AutoHeadshot then
		EnsureHook()
		HookState.Handler = HookState.Installed and RaycastHandler or nil
	else
		HookState.Handler = nil
	end
end
local FOVCircle
local function GetFOVRadius(Camera, FOV)
	local Half = math.tan(math.rad(math.clamp(FOV, 1, 179) * 0.5))
	local ScreenHalf = math.tan(math.rad(Camera.FieldOfView * 0.5))
	return ScreenHalf > 0 and Half / ScreenHalf * Camera.ViewportSize.Y * 0.5 or 0
end
local function PickAimTarget(Camera)
	local Container = workspace:FindFirstChild("Zombies")
	if not Container then
		return nil
	end
	local Center, Radius = Camera.ViewportSize * 0.5, GetFOVRadius(Camera, AimConfig.FOV)
	local Best, BestDistance
	for _, Model in Container:GetChildren() do
		local _sc3 = Model:IsA("Model") and Model:FindFirstChildOfClass("Humanoid")
		local Humanoid = _sc3
		if _sc3 and Humanoid.Health > 0 and TypeAllowed(AimConfig.Types, Model) then
			local Part = Model:FindFirstChild("Head")
			if not (Part and Part:IsA("BasePart")) then
				Part = Model:FindFirstChild("HumanoidRootPart")
			end
			if Part and Part:IsA("BasePart") then
				local Screen, OnScreen = Camera:WorldToViewportPoint(Part.Position)
				local Distance = (Vector2.new(Screen.X, Screen.Y) - Center).Magnitude
				if OnScreen and Distance <= Radius then
					if not BestDistance or Distance < BestDistance then
						Best, BestDistance = Part.Position, Distance
					end
				end
			end
		end
	end
	return Best
end
local function UpdateAim()
	if Unloaded then
		return
	end
	local Camera = workspace.CurrentCamera
	local _sc3 = FOVCircle
	FOVCircle = if FOVCircle then _sc3 else NewDrawing("Circle", { Thickness = 1, Filled = false, NumSides = 64, Transparency = 0.55 })
	local _sc4 = Camera ~= nil and AimConfig.Enabled and AimConfig.ShowFOV
	Set(FOVCircle, "Visible", _sc4)
	if _sc4 then
		Set(FOVCircle, "Position", Camera.ViewportSize * 0.5)
		Set(FOVCircle, "Radius", GetFOVRadius(Camera, AimConfig.FOV))
		Set(FOVCircle, "Color", Color3.fromRGB(120, 200, 255))
	end
	local _sc5_s1 = not Camera or not AimConfig.Enabled
	if _sc5_s1 or Library.Toggled then
		return
	end
	if AssistPicker and AssistPicker.Value ~= "None" and not AssistPicker:GetState() then
		return
	end
	local Target = PickAimTarget(Camera)
	local Position = Camera.CFrame.Position
	if Target and (Target - Position).Magnitude > 0.1 then
		Camera.CFrame = CFrame.lookAt(Position, Target)
	end
end
local HitboxVisuals, LastHitboxVisuals = {}, 0
local function ClearHitboxVisuals()
	for _, Box in HitboxVisuals do
		pcall(Box.Destroy, Box)
	end
	table.clear(HitboxVisuals)
end
local function UpdateHitboxVisuals()
	local Now = time()
	local _sc3 = Unloaded
	if if Unloaded then _sc3 else Now - LastHitboxVisuals < 0.05 then
		return
	end
	LastHitboxVisuals = Now
	if not HitboxConfig.Show then
		if next(HitboxVisuals) then
			ClearHitboxVisuals()
		end
		return
	end
	RefreshHitboxParts()
	local Seen = {}
	local Pad = HitboxConfig.Enabled and HitboxConfig.Size or 0
	for _, Part in HitboxParts do
		Seen[Part] = true
		local Box = HitboxVisuals[Part]
		if not Box or Box.Parent ~= Part then
			Box = Instance.new("BoxHandleAdornment")
			Box.Name, Box.Adornee, Box.Color3, Box.AlwaysOnTop = "UmberHitbox", Part, Color3.fromRGB(255, 170, 80), true
			Box.Parent = Part
			HitboxVisuals[Part] = Box
		end
		Set(Box, "Size", Part.Size + Vector3.new(Pad, Pad, Pad))
		Set(Box, "Transparency", HitboxConfig.Transparency)
	end
	for Part, Box in HitboxVisuals do
		if not Seen[Part] then
			pcall(Box.Destroy, Box)
			HitboxVisuals[Part] = nil
		end
	end
end
local ProjectileTimers = setmetatable({}, { __mode = "k" })
local LastProjectileTimer, TrajectoryLines = 0, nil
local LocalMouse = LocalPlayer:GetMouse()
local ThrowFilter = RaycastParams.new()
ThrowFilter.FilterType = Enum.RaycastFilterType.Exclude
local ThrowIgnore = {}
local function UntrackProjectile(Projectile)
	local Entry = ProjectileTimers[Projectile]
	if Entry then
		RemoveDrawing(Entry.Text)
		ProjectileTimers[Projectile] = nil
	end
end
local function ClearProjectileTimers()
	for Projectile in ProjectileTimers do
		UntrackProjectile(Projectile)
	end
end
local function TrackProjectile(Projectile)
	local _sc3 = Unloaded
	local _sc3_s1 = if Unloaded then _sc3 else not ThrowableConfig.MortarTimer
	local _sc3_s2 = _sc3_s1 or not Projectile:IsA("ValueBase")
	if _sc3_s2 or ProjectileTimers[Projectile] then
		return
	end
	local Fuse, Start = Projectile:GetAttribute("FuseTimer"), Projectile:GetAttribute("Start")
	local Character = LocalPlayer.Character
	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	local _sc5_s1 = typeof(Fuse) ~= "number" or typeof(Start) ~= "Vector3"
	local _sc5_s2 = _sc5_s1 or not Root
	if _sc5_s2 or (Start - Root.Position).Magnitude > 12 then
		return
	end
	ProjectileTimers[Projectile] = { Text = CreateText(14), Fuse = Fuse, Started = time() }
end
local function UpdateProjectileTimers(Now)
	if not ThrowableConfig.MortarTimer then
		ClearProjectileTimers()
		return
	end
	if Now - LastProjectileTimer < 1 / 30 then
		return
	end
	LastProjectileTimer = Now
	local Camera = workspace.CurrentCamera
	for Projectile, Entry in ProjectileTimers do
		if not Projectile.Parent then
			UntrackProjectile(Projectile)
		elseif Camera then
			local Remaining = Entry.Fuse - (Now - Entry.Started)
			local _sc3 = typeof(Projectile.Value) == "Vector3" and Camera:WorldToViewportPoint(Projectile.Value)
			local Screen = _sc3
			local _sc4 = _sc3 and Remaining > 0 and Screen.Z > 0
			Set(Entry.Text, "Visible", _sc4)
			if _sc4 then
				Set(Entry.Text, "Text", string.format("%.1f", Remaining))
				local Entry_Text = Entry.Text
				local _sc6 = Remaining < 1
				if _sc6 then
					local _t3985 = Set
					_sc6 = Color3.fromRGB(255, 70, 70)
				end
				local _sc5 = _sc6
				if not _sc6 then
					local _t3985 = Set
					_sc5 = Color3.fromRGB(255, 170, 80)
				end
				Set(Entry_Text, "Color", _sc5)
				Set(Entry.Text, "Position", Vector2.new(Screen.X, Screen.Y - 20))
			end
		end
	end
end
local function HideTrajectory()
	for _, Line in TrajectoryLines or {} do
		Set(Line, "Visible", false)
	end
end
local function SolveThrow(Start, Target, Speed)
	local DeltaX, DeltaZ, DeltaY = Target.X - Start.X, Target.Z - Start.Z, Target.Y - Start.Y
	local Flat = DeltaX * DeltaX + DeltaZ * DeltaZ
	local Gravity, Speed2 = -workspace.Gravity, Speed * Speed
	if Flat <= 0 then
		local Vector3_new = Vector3.new
		local _sc4 = DeltaY < 0 and -Speed
		return Vector3_new(0, _sc4 or DeltaY > 0 and Speed or 0, 0)
	end
	local Scale = Flat / (2 * (Flat + DeltaY * DeltaY))
	local Root = Speed2 * (2 * Gravity * DeltaY + Speed2) - Gravity * Gravity * Flat
	if Root <= 0 then
		return nil
	end
	local High = Scale * (Gravity * DeltaY + Speed2 + math.sqrt(Root))
	if High < 0 or Speed2 - High < 0 then
		return nil
	end
	local FlatRoot, Vertical = math.sqrt(Flat), math.sqrt(Speed2 - High)
	if not (Gravity * Flat / (2 * Speed2) < DeltaY) then
		Vertical = -Vertical
	end
	return Vector3.new(DeltaX / FlatRoot * math.sqrt(High), Vertical, DeltaZ / FlatRoot * math.sqrt(High))
end
local function UpdateTrajectory()
	local Character, Camera = LocalPlayer.Character, workspace.CurrentCamera
	local _sc3 = ThrowableConfig.Trajectory and Character and Character:FindFirstChildOfClass("Tool")
	local Tool = _sc3
	local _sc4 = _sc3 and Tool:FindFirstChild("Configuration")
	local Configuration = _sc4
	local Speed = _sc4 and Configuration:GetAttribute("ThrowSpeed")
	local Delay = Configuration and Configuration:GetAttribute("ThrowDelay")
	local _sc7 = Character
	if Character then
		local _sc8_s1 = Character:FindFirstChild("RightHand") or Character:FindFirstChild("Right Arm")
		_sc7 = _sc8_s1 or Character:FindFirstChild("HumanoidRootPart")
	end
	local Hand = _sc7
	local _sc9 = _sc7
		and Camera
		and typeof(Speed) == "number"
		and typeof(Delay) == "number"
		and SolveThrow(Hand.Position, LocalMouse.Hit.Position, Speed)
	local Velocity = _sc9
	if not _sc9 then
		HideTrajectory()
		return
	end
	if not TrajectoryLines then
		TrajectoryLines = {}
		for Index = 1, 24 do
			TrajectoryLines[Index] = NewDrawing("Line", { Thickness = 2 })
		end
	end
	local Gravity, Point, Step, Count = Vector3.new(0, -workspace.Gravity, 0), Hand.Position, 0.06, 0
	ThrowIgnore[1], ThrowIgnore[2] = Character, Camera
	ThrowFilter.FilterDescendantsInstances = ThrowIgnore
	for Index = 1, 24 do
		local Next = Point + Velocity * Step + Gravity * 0.0018
		local Result = workspace:Raycast(Point, Next - Point, ThrowFilter)
		Velocity += Gravity * Step
		if Result then
			Next = Result.Position
		end
		local From, To = Camera:WorldToViewportPoint(Point), Camera:WorldToViewportPoint(Next)
		local _t4315 = TrajectoryLines[Index]
		local _sc10 = From.Z > 0 and To.Z > 0
		local Line = _t4315
		Set(Line, "Visible", _sc10)
		if _sc10 then
			Set(Line, "Color", Color3.fromRGB(255, 170, 80))
			Set(Line, "From", Vector2.new(From.X, From.Y))
			Set(Line, "To", Vector2.new(To.X, To.Y))
		end
		Count, Point = Index, Next
		if Result then
			break
		end
	end
	for Index = Count + 1, 24 do
		Set(TrajectoryLines[Index], "Visible", false)
	end
end
local function UpdateThrowables()
	if not Unloaded then
		UpdateProjectileTimers(time())
		UpdateTrajectory()
	end
end
task.spawn(function()
	local Folder = workspace:WaitForChild("Projectiles", 60)
	if Unloaded or not Folder then
		return
	end
	Track(Folder.ChildAdded:Connect(TrackProjectile))
	Track(Folder.ChildRemoved:Connect(UntrackProjectile))
end)
local function Cleanup()
	Unloaded = true
	HookState.Handler = nil
	for _, Connection in Connections do
		Connection:Disconnect()
	end
	table.clear(Connections)
	for Model in Tracked do
		Drop(Model)
	end
	for Model in BlastRings do
		DestroyBlastRing(Model)
	end
	table.clear(Visuals)
	ClearHitboxVisuals()
	ClearProjectileTimers()
	for _, Line in TrajectoryLines or {} do
		RemoveDrawing(Line)
	end
	TrajectoryLines = nil
	if FOVCircle then
		RemoveDrawing(FOVCircle)
		FOVCircle = nil
	end
	pcall(RunService.UnbindFromRenderStep, RunService, "UmberAim")
	Lighting.Ambient, Lighting.OutdoorAmbient, Lighting.Brightness = WorldOriginal.Ambient, WorldOriginal.OutdoorAmbient, WorldOriginal.Brightness
	ClearChargeSpeed()
	ClearSwingBuffs()
	Env.UmberUnload = nil
end
local RenderSteps = { ESP = UpdateESP, HitboxVisuals = UpdateHitboxVisuals, Throwables = UpdateThrowables,
	BlastRings = UpdateBlastRings
}
local HeartSteps = { AntiGrab = SpoofGrabPosition, SwingSpeed = ApplySwingSpeed }
local Failed = {}
local function RunSteps(Steps)
	for Name, Step in Steps do
		local Ok, Err = pcall(Step)
		if not Ok and not Failed[Name] then
			Failed[Name] = true
			Notify(Name .. " failed: " .. tostring(Err), 10)
		end
	end
end
Track(LocalPlayer.CharacterAdded:Connect(function()
	SpeedModifier = nil
	ApplyChargeSpeed()
end))
Track(RunService.RenderStepped:Connect(function()
	RunSteps(RenderSteps)
end))
Track(RunService.Heartbeat:Connect(function()
	if not Unloaded then
		RunSteps(HeartSteps)
	end
end))
pcall(RunService.BindToRenderStep, RunService, "UmberAim", Enum.RenderPriority.Camera.Value + 1, function()
	local Ok, Err = pcall(UpdateAim)
	if not Ok and not Failed.Aim then
		Failed.Aim = true
		Notify("Aim failed: " .. tostring(Err), 10)
	end
end)
Library:OnUnload(Cleanup)
function Env.UmberUnload()
	Library:Unload()
end
local function Bind(Config, Key, After)
	return function(Value)
		Config[Key] = Value
		if After then
			After(Value)
		end
	end
end
local function TypesCallback(Config)
	return function(Value)
		local Types = {}
		for Key in Value do
			Types[Key] = true
		end
		Config.Types = Types
	end
end
local function AddDropdown(Group, Name, Config, Key, Text, Tip, Values, Default, After)
	return Group:AddDropdown(Name, { Values = Values, Default = Default, Text = Text, Tooltip = Tip, Callback = Bind(Config, Key, After) })
end
local function AddSlider(Group, Name, Config, Key, Text, Tip, Default, Min, Max, Extra, After)
	local Info = { Text = Text, Tooltip = Tip, Default = Default, Min = Min, Max = Max, Rounding = 0,
		Callback = Bind(Config, Key, After)
	}
	for Field, Value in Extra or {} do
		Info[Field] = Value
	end
	return Group:AddSlider(Name, Info)
end
local function AddFeature(Group, Prefix, Config, Master, Key, Text, Tip, Default, ColorKey, ColorDefault, ColorTitle)
	local Toggle = Group:AddToggle(Prefix .. Key, { Text = Text, Tooltip = Tip, Default = Default,
		Callback = Bind(Config, Key, function(Value)
			if Value then
				EnsureEnabled(Master)
			end
		end)
	})
	if ColorKey then
		Toggle:AddColorPicker(Prefix .. Key .. "Color", { Default = ColorDefault, Title = ColorTitle, Callback = Bind(Config, ColorKey) })
	end
	return Toggle
end
local function AddCommonESP(Group, Prefix, Config, Master, Noun, BoxColor)
	AddFeature(Group, Prefix, Config, Master, "Box", "Box", "Box around each " .. Noun .. ".", true, BoxColor and "BoxColor", BoxColor, "Box Color")
	AddDropdown(Group, Prefix .. "BoxStyle", Config, "BoxStyle", "Box Style", "Plain box, corner brackets, or a filled box.", { "Box", "Corner", "Filled Box" }, "Box")
	AddFeature(Group, Prefix, Config, Master, "Chams", "Chams", "Colours the " .. Noun .. " model.", false, BoxColor and "ChamsColor", BoxColor, "Chams Color")
	local _sc3 = BoxColor
	if not BoxColor then
		local AddFeature_v1 = AddFeature
		_sc3 = Color3.fromRGB(164, 91, 38)
	end
	AddFeature(Group, Prefix, Config, Master, "Tracers", "Tracers", "Line from your screen to them.", false, "TracerColor", _sc3, "Tracer Color")
	AddFeature(Group, Prefix, Config, Master, "Names", "Names", "Name above the box.", false, "NameColor", Color3.fromRGB(255, 255, 255), "Name Color")
	AddDropdown(Group, Prefix .. "NameStyle", Config, "NameStyle", "Name Display", "Text draws it, GUI is a label.", { "Text", "GUI", "Both" }, "Text")
	AddFeature(Group, Prefix, Config, Master, "Health", "Health Bar", "Health under the name.", false, "HealthColor", Color3.fromRGB(90, 200, 90), "Health Color")
	AddDropdown(Group, Prefix .. "HealthStyle", Config, "HealthStyle", "Health Display", "How the health is drawn.", { "Text", "GUI", "Both" }, "Text")
	Group:AddToggle(Prefix .. "Distance", { Text = "Show Distance", Tooltip = "Distance in studs next to the name.", Default = true,
		Callback = Bind(Config, "Distance")
	})
end
local AvatarUrl = string.format("rbxthumb://type=AvatarHeadShot&id=%s&w=150&h=150", LocalPlayer.UserId)
local Greetings = { "Welcome to Umber, %s", "Greetings, %s", "Good to see you, %s", "Umber is ready, %s",
	"Back again, %s?"
}
local AboutGroup = Tabs.Main:AddGroupbox({ Name = "About", Side = "Left", IconName = "circle-user" })
AboutGroup:AddImage("AboutAvatar", { Image = AvatarUrl, Height = 72, ScaleType = Enum.ScaleType.Fit })
AboutGroup:AddLabel({ Text = string.format("%s (@%s)", LocalPlayer.DisplayName, LocalPlayer.Name), DoesWrap = true,
	Size = 16
})
AboutGroup:AddLabel({ Text = string.format(Greetings[math.random(#Greetings)], LocalPlayer.DisplayName), DoesWrap = true,
	Size = 14
})
task.wait()
local MovementGroup = Tabs.Player:AddGroupbox({ Name = "Movement", Side = "Left", IconName = "footprints" })
MovementGroup:AddToggle("WalkSpeedToggle", { Text = "Walkspeed Toggle",
	Tooltip = "Borrows the game's Charge speed buff so your speed holds through swings and reloads.",
	Default = false,
	["Callback"] = function(Value)
		ChargeSpeed = Value
		ApplyChargeSpeed()
	end
})
MovementGroup:AddSlider("WalkSpeedValue", { Text = "Walk Speed", Tooltip = "How fast you move while the toggle is on.", Default = 55, Min = 16,
	Max = 70, Rounding = 0,
	["Callback"] = function(Value)
		ChargeValue = Value
		if ChargeSpeed then
			ApplyChargeSpeed()
		end
	end
})
local ProtectionGroup = Tabs.Player:AddGroupbox({ Name = "Protection", Side = "Right", IconName = "shield" })
ProtectionGroup:AddToggle("AntiGrab", { Text = "Anti Grab", Tooltip = "Moves you out of grab range on paper so shamblers can't latch on.",
	Default = false,
	["Callback"] = function(Value)
		AntiGrabEnabled = Value
	end
})
task.wait()
local ESPGroup = Tabs.Visuals:AddGroupbox({ Name = "ESP", Side = "Left", IconName = "scan-eye" })
ESPGroup:AddToggle("ZombieESP", { Text = "Zombie ESP", Tooltip = "Turns on all the zombie visuals.", Default = false,
	Callback = Bind(ZombieConfig, "Enabled")
})
ESPGroup:AddToggle("PlayerESP", { Text = "Player ESP", Tooltip = "Turns on all the player visuals.", Default = false,
	Callback = Bind(PlayerConfig, "Enabled")
})
local ZombieGroup = Tabs.Visuals:AddGroupbox({ Name = "Zombie ESP Options", Side = "Left", IconName = "crosshair" })
ZombieGroup:AddDropdown("ZombieType", { Values = ZombieTypeValues, Default = { "All" }, Text = "Zombie Type",
	Tooltip = "Only draw the types you tick.", Multi = true, Callback = TypesCallback(ZombieConfig)
})
AddCommonESP(ZombieGroup, "Zombie", ZombieConfig, "ZombieESP", "zombie", nil)
AddFeature(ZombieGroup, "Zombie", ZombieConfig, "ZombieESP", "BomberTimer", "Bomber Timer", "Countdown before a bomber blows up.", true, "BomberTimerColor", Color3.fromRGB(255, 90, 60), "Bomber Timer Color")
AddDropdown(ZombieGroup, "ZombieBomberTimerPosition", ZombieConfig, "BomberTimerPosition", "Timer Position", "Where the countdown sits.", { "Bottom", "Top", "Center", "Left", "Right" }, "Bottom")
AddSlider(ZombieGroup, "ZombieBomberTimerOffsetX", ZombieConfig, "BomberTimerOffsetX", "Timer Offset X", "Nudge the timer left or right.", 0, -400, 400)
AddSlider(ZombieGroup, "ZombieBomberTimerOffsetY", ZombieConfig, "BomberTimerOffsetY", "Timer Offset Y", "Nudge the timer up or down.", 0, -400, 400)
ZombieGroup:AddToggle("ZombieBlastRadius", { Text = "Bomber Blast Radius",
	Tooltip = "Draws the explosion circle while a bomber is about to blow.", Default = true,
	Callback = Bind(ZombieConfig, "BlastRadius")
}):AddColorPicker("ZombieBlastRadiusColor", { Default = Color3.fromRGB(255, 90, 60), Title = "Blast Radius Color",
	Callback = Bind(ZombieConfig, "BlastRadiusColor")
})
task.wait()
local ColorsGroup = Tabs.Visuals:AddGroupbox({ Name = "Zombie Colors", Side = "Left", IconName = "palette" })
for _, Item in { { "Normal", "Shambler" }, { "Fast", "Runner" }, { "Barrel", "Bomber" }, { "Sapper", "Sapper" },
	{ "Igniter", "Igniter" }, { "Cuirassier", "Cuirassier" }, { "Crawler", "Crawler" },
	{ "Headless", "Headless" }, { "BigBoy", "Big Boy" }
} do
	local Key, Display = Item[1], Item[2]
	local Row = ColorsGroup:AddLabel(Display)
	Row:AddColorPicker("ZombieColor" .. Key, { Default = ZombieColors[Key], Title = Display .. " Color", Callback = Bind(ZombieColors, Key) })
	Library:AddTooltip("Box and chams colour for " .. Display:lower() .. (Key == "Headless" and "." or "s."), nil, Row.TextLabel)
end
local PlayerGroup = Tabs.Visuals:AddGroupbox({ Name = "Player ESP Options", Side = "Right", IconName = "users" })
AddCommonESP(PlayerGroup, "Player", PlayerConfig, "PlayerESP", "player", Color3.fromRGB(120, 200, 130))
PlayerGroup:AddDivider()
for _, Item in { { "Infection", "Infection", "Shows infection percent.", true, Color3.fromRGB(190, 70, 70) },
	{ "Grabbed", "Grabbed", "Flags players a zombie is holding.", true, Color3.fromRGB(255, 70, 70) },
	{ "Pinned", "Pinned", "Shows what pinned them.", true, Color3.fromRGB(255, 170, 60) },
	{ "Burning", "Burning", "Flags players on fire.", false, Color3.fromRGB(255, 130, 40) },
	{ "BrokenLegs", "Broken Legs", "Flags players with broken legs.", false,
		Color3.fromRGB(180, 180, 255)
	}
} do
	AddFeature(PlayerGroup, "Player", PlayerConfig, "PlayerESP", Item[1], Item[2], Item[3], Item[4], Item[1] .. "Color", Item[5], Item[2] .. " Color")
end
local ThrowableGroup = Tabs.Visuals:AddGroupbox({ Name = "Throwables", Side = "Right", IconName = "bomb" })
ThrowableGroup:AddToggle("ThrowableMortarTimer", { Text = "Hand Mortar Timer", Tooltip = "Counts down the fuse on grenades you fire.", Default = false,
	Callback = Bind(ThrowableConfig, "MortarTimer")
})
ThrowableGroup:AddToggle("ThrowableTrajectory", { Text = "Throwable Trajectory", Tooltip = "Shows where your grenade or tar bottle will land.",
	Default = false, Callback = Bind(ThrowableConfig, "Trajectory")
})
task.wait()
local WorldGroup = Tabs.World:AddGroupbox({ Name = "Lighting", Side = "Left", IconName = "sun" })
WorldGroup:AddToggle("WorldFullbright", { Text = "Fullbright", Tooltip = "Lights up the whole map.", Default = false,
	Callback = Bind(WorldConfig, "Fullbright", ApplyWorldLighting)
})
task.wait()
local HitboxGroup = Tabs.Combat:AddGroupbox({ Name = "Hitbox Expander", Side = "Left", IconName = "expand" })
local function InvalidateHitboxParts()
	HitboxPartsStamp = 0
end
HitboxGroup:AddToggle("HitboxExpander", { Text = "Hitbox Expander", Tooltip = "Bigger hit area on your swings.", Default = false,
	Callback = Bind(HitboxConfig, "Enabled", SyncHook)
})
AddSlider(HitboxGroup, "HitboxExpanderSize", HitboxConfig, "Size", "Hitbox Expander Size", "How much bigger that area is.", 5, 1, 10)
AddDropdown(HitboxGroup, "HitboxExpanderPart", HitboxConfig, "Part", "Hitbox Part", "Which parts get the bigger hit area.", { "All", "Head", "Torso", "Legs", "HumanoidRootPart" }, "All", InvalidateHitboxParts)
HitboxGroup:AddToggle("HitboxIgnoreBarrel", { Text = "Ignore Bombers/Barrel", Tooltip = "Skips bombers so you don't pop them.", Default = false,
	Callback = Bind(HitboxConfig, "IgnoreBarrel", InvalidateHitboxParts)
})
HitboxGroup:AddToggle("HitboxShow", { Text = "Show Hitboxes", Tooltip = "Draws the hit area so you can see it.", Default = false,
	Callback = Bind(HitboxConfig, "Show")
})
HitboxGroup:AddSlider("HitboxTransparency", { Text = "Hitbox Transparency", Tooltip = "How faded the hitboxes are. 90 is barely visible.",
	Default = 90, Min = 0, Max = 100, Rounding = 0, Suffix = "%",
	["Callback"] = function(Value)
		HitboxConfig.Transparency = Value / 100
	end
})
local FirearmsGroup = Tabs.Combat:AddGroupbox({ Name = "Firearms", Side = "Left", IconName = "crosshair" })
FirearmsGroup:AddToggle("AimAssist", { Text = "Aim Assist", Tooltip = "Sways your camera onto the nearest zombie in the circle.",
	Default = false, Callback = Bind(AimConfig, "Enabled")
}):AddKeyPicker("AimAssistKey", { Text = "Aim Assist key", Default = "None", Mode = "Hold" })
AssistPicker = Options.AimAssistKey
FirearmsGroup:AddDropdown("AimAssistTypes", { Values = ZombieTypeValues, Default = { "All" }, Text = "Aim Assist Types",
	Tooltip = "Which zombies aim assist goes for.", Multi = true, Callback = TypesCallback(AimConfig)
})
AddSlider(FirearmsGroup, "AimAssistFOV", AimConfig, "FOV", "Aim Assist FOV", "How far from your crosshair it will look.", 40, 5, 180)
FirearmsGroup:AddToggle("AimAssistShowFOV", { Text = "Show Aim Assist FOV", Tooltip = "Draws the aim assist circle.", Default = false,
	Callback = Bind(AimConfig, "ShowFOV")
})
local MeleeGroup = Tabs.Combat:AddGroupbox({ Name = "Melee", Side = "Right", IconName = "target" })
MeleeGroup:AddToggle("MeleeAutoHeadshot", { Text = "Auto Headshot", Tooltip = "Turns your hits into headshots.", Default = false,
	Callback = Bind(MeleeConfig, "AutoHeadshot", SyncHook)
})
AddSlider(MeleeGroup, "MeleeHeadshotChance", MeleeConfig, "Chance", "Headshot Chance", "Odds a hit lands as a headshot.", 100, 0, 100, { Suffix = "%" })
MeleeGroup:AddToggle("MeleeSwingSpeedEnabled", { Text = "Swing Speed", Tooltip = "Turns the multiplier below on.", Default = false,
	Callback = Bind(MeleeConfig, "SwingSpeedEnabled", ApplySwingSpeed)
})
AddSlider(MeleeGroup, "MeleeSwingSpeed", MeleeConfig, "SwingSpeed", "Swing Speed Multiplier", "How many times faster you swing.", 1, 1, 5, { Rounding = 1, Suffix = "x" }, ApplySwingSpeed)
task.wait()
local MenuGroup = Tabs.Settings:AddGroupbox({ Side = "Left", Name = "Menu", IconName = "wrench" })
MenuGroup:AddToggle("KeybindMenuOpen", { Default = Library.KeybindFrame.Visible, Text = "Open Keybind Menu",
	Tooltip = "Shows the keybind list on screen.",
	["Callback"] = function(Value)
		Library.KeybindFrame.Visible = Value
	end
})
MenuGroup:AddToggle("KeybindMenuVisibilityControl", { Default = false, Text = "Keybind Menu Visibility", Tooltip = "Adds a gear to the keybind list.",
	["Callback"] = function(Value)
		Library.KeybindMenu:SetVisibilityControl(Value)
	end
})
MenuGroup:AddToggle("ShowCustomCursor", { Text = "Custom Cursor", Tooltip = "Swaps out the mouse cursor.", Default = Library.ShowCustomCursor,
	["Callback"] = function(Value)
		Library.ShowCustomCursor = Value
	end
})
MenuGroup:AddToggle("AlwaysOnTop", { Text = "Always On Top", Tooltip = "Keeps the menu above other windows.",
	Default = Window.AlwaysOnTop,
	["Callback"] = function(Value)
		Window:SetAlwaysOnTop(Value)
	end
})
MenuGroup:AddDropdown("NotificationSide", { Values = { "Left", "Right" }, Default = "Right", Text = "Notification Side",
	Tooltip = "Where notifications pop up.",
	["Callback"] = function(Value)
		Library:SetNotifySide(Value)
	end
})
MenuGroup:AddDropdown("DPIDropdown", { Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" }, Default = "100%",
	Text = "DPI Scale", Tooltip = "Scales the whole menu.",
	["Callback"] = function(Value)
		Library:SetDPIScale(tonumber((Value:gsub("%%", ""))))
	end
})
MenuGroup:AddSlider("UICornerSlider", { Text = "Corner Radius", Tooltip = "How round the menu corners are.", Default = Library.CornerRadius,
	Min = 0, Max = 20, Rounding = 0,
	["Callback"] = function(Value)
		Window:SetCornerRadius(Value)
	end
})
MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
MenuGroup:AddButton({ Text = "Unload", Tooltip = "Closes the menu and undoes everything.",
	["Func"] = function()
		Library:Unload()
	end
})
Library.ToggleKeybind = Options.MenuKeybind
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
SaveManager:SetFolder("Umber/Default")
SaveManager:BuildConfigSection(Tabs.Settings)
ThemeManager:ApplyToTab(Tabs.Settings)
LoadingConfig = true
local ConfigOk, ConfigErr = pcall(SaveManager.LoadAutoloadConfig, SaveManager)
LoadingConfig = false
if not ConfigOk then
	Notify("Autoload config failed: " .. tostring(ConfigErr), 10)
end
