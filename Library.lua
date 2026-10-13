local ObsErrorLog = {}
local function ObsReportError(Kind, Message, Trace)
    pcall(function()
        local genv = type(getgenv) == "function" and getgenv() or _G
        local Report = genv and rawget(genv, "__AzureReport")
        if type(Report) == "function" then
            Report(Kind, Message, Trace)
        end
    end)
end
local function ObsErrorHandler(err)
    local msg = tostring(err)
    ObsErrorLog[#ObsErrorLog + 1] = msg
    if #ObsErrorLog > 50 then table.remove(ObsErrorLog, 1) end
    local genv = type(getgenv) == "function" and getgenv() or _G
    if genv then genv.__obsErrors = ObsErrorLog end
    ObsReportError("callback", msg, debug.traceback(msg, 2))
    return msg
end
local ObsGetIdentity = type(getthreadidentity) == "function" and getthreadidentity or nil
local ObsSetIdentity = type(setthreadidentity) == "function" and setthreadidentity or nil
local ObsIdentity = nil
pcall(function() ObsIdentity = ObsGetIdentity and ObsGetIdentity() end)
local function ObsGuard(fn)
    if type(fn) ~= "function" then return fn end
    return function(...)
        if ObsIdentity and ObsSetIdentity then
            pcall(function()
                ObsSetIdentity(ObsIdentity)
            end)
        end
        local res = table.pack(xpcall(fn, ObsErrorHandler, ...))
        if res[1] then return table.unpack(res, 2, res.n) end
        return nil
    end
end
local ObsRawTask = task
local task = setmetatable({
    spawn = function(fn, ...) return ObsRawTask.spawn(ObsGuard(fn), ...) end,
    defer = function(fn, ...) return ObsRawTask.defer(ObsGuard(fn), ...) end,
    delay = function(t, fn, ...) return ObsRawTask.delay(t, ObsGuard(fn), ...) end,
}, { __index = ObsRawTask })
local RawCloneref = cloneref or clonereference
local cloneref = function(instance: any)
    if instance == nil or type(RawCloneref) ~= "function" then
        return instance
    end
    local ok, result = pcall(RawCloneref, instance)
    if ok and result ~= nil then
        return result
    end
    return instance
end
local RobloxFont = Font
local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))
local Players: Players = cloneref(game:GetService("Players"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local SoundService: SoundService = cloneref(game:GetService("SoundService"))
local UserInputService: UserInputService = cloneref(game:GetService("UserInputService"))
local TextService: TextService = cloneref(game:GetService("TextService"))
local Teams: Teams = cloneref(game:GetService("Teams"))
local TweenService: TweenService = cloneref(game:GetService("TweenService"))

local getgenv = getgenv or function()
    return shared
end
local setclipboard = setclipboard or nil
local ColorClipboard = {}
do
    local Reader = getclipboard or fromclipboard or (typeof(Clipboard) == "table" and Clipboard.get) or nil

    function ColorClipboard.Parse(Text)
        if type(Text) ~= "string" then
            return nil
        end
        Text = Text:gsub("^%s+", ""):gsub("%s+$", "")
        local Hex = Text:match("^#?(%x%x%x%x%x%x)$")
        if Hex then
            local Ok, Color = pcall(Color3.fromHex, Hex)
            return Ok and Color or nil
        end
        local Short = Text:match("^#?(%x%x%x)$")
        if Short then
            local Long = Short:sub(1, 1):rep(2) .. Short:sub(2, 2):rep(2) .. Short:sub(3, 3):rep(2)
            local Ok, Color = pcall(Color3.fromHex, Long)
            return Ok and Color or nil
        end
        local R, G, B = Text:match("(%d+)%s*[,%s]%s*(%d+)%s*[,%s]%s*(%d+)")
        if R then
            return Color3.fromRGB(math.clamp(tonumber(R), 0, 255), math.clamp(tonumber(G), 0, 255), math.clamp(tonumber(B), 0, 255))
        end
        return nil
    end

    function ColorClipboard.Recents()
        local List = nil
        pcall(function()
            List = getgenv().__AzureRecentColors
        end)
        if type(List) ~= "table" then
            List = {}
            pcall(function()
                getgenv().__AzureRecentColors = List
            end)
        end
        return List
    end

    function ColorClipboard.Remember(Color)
        if typeof(Color) ~= "Color3" then
            return
        end
        local List = ColorClipboard.Recents()
        local Hex = Color:ToHex()
        for Index = #List, 1, -1 do
            if List[Index] == Hex then
                table.remove(List, Index)
            end
        end
        table.insert(List, 1, Hex)
        while #List > 8 do
            table.remove(List)
        end
    end

    function ColorClipboard.Write(Color, Transparency)
        ColorClipboard.Remember(Color)
        local Store = { Color, Transparency or 0 }
        Library.CopiedColor = Store
        pcall(function()
            getgenv().__AzureCopiedColor = Store
        end)
        local Wrote = false
        if setclipboard then
            Wrote = pcall(setclipboard, "#" .. Color:ToHex())
        end
        return Wrote
    end

    function ColorClipboard.Read()
        if Reader then
            local Ok, Text = pcall(Reader)
            local Color = Ok and ColorClipboard.Parse(Text) or nil
            if Color then
                return Color, nil
            end
        end
        local Store = Library.CopiedColor
        if not Store then
            pcall(function()
                Store = getgenv().__AzureCopiedColor
            end)
        end
        if type(Store) == "table" and typeof(Store[1]) == "Color3" then
            return Store[1], Store[2]
        end
        return nil
    end
end
local protectgui = protectgui or (syn and syn.protect_gui) or function() end
local gethui = gethui or function()
    return CoreGui
end

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local Mouse = nil
pcall(function()
    local PlayerMouse = LocalPlayer:GetMouse()
    if PlayerMouse then Mouse = cloneref(PlayerMouse) end
end)
if not Mouse then
    local GuiService = cloneref(game:GetService("GuiService"))
    Mouse = setmetatable({}, {
        __index = function(_, Key)
            if Key ~= "X" and Key ~= "Y" then return nil end
            local Location = UserInputService:GetMouseLocation()
            local Inset = GuiService:GetGuiInset()
            return if Key == "X" then Location.X - Inset.X else Location.Y - Inset.Y
        end,
    })
end

local Labels = {}
local Buttons = {}
local Toggles = {}
local Options = {}
local Tooltips = {}

local BaseURL = "https://raw.githubusercontent.com/swrenic/ui/main/"
local CustomImageManager = {}
local CustomImageManagerAssets = {
    TransparencyTexture = {
        RobloxId = 0,
        Path = "Azure/assets/TransparencyTexture.png",
        URL = BaseURL .. "assets/TransparencyTexture.png",

        Id = nil,
    },

    SaturationMap = {
        RobloxId = 0,
        Path = "Azure/assets/SaturationMap.png",
        URL = BaseURL .. "assets/SaturationMap.png",

        Id = nil,
    },

    LoadingIcon = {
        RobloxId = 97544096941083,
        Path = "Azure/assets/LoadingIcon.png",
        URL = BaseURL .. "assets/LoadingIcon.png",

        Id = nil,
    },

    CheckIcon = {
        RobloxId = 97682394690683,
        Path = "Azure/assets/CheckIcon.png",
        URL = BaseURL .. "assets/CheckIcon.png",

        Id = nil,
    },
}
do
    local function RecursiveCreatePath(Path: string, IsFile: boolean?)
        if not isfolder or not makefolder then
            return
        end

        local Segments = Path:split("/")
        local TraversedPath = ""

        if IsFile then
            table.remove(Segments, #Segments)
        end

        for _, Segment in ipairs(Segments) do
            if not isfolder(TraversedPath .. Segment) then
                makefolder(TraversedPath .. Segment)
            end

            TraversedPath = TraversedPath .. Segment .. "/"
        end

        return TraversedPath
    end

    function CustomImageManager.AddAsset(
        AssetName: string,
        RobloxAssetId: number,
        URL: string,
        ForceRedownload: boolean?
    )
        if CustomImageManagerAssets[AssetName] ~= nil then
            error(string.format("Asset %q already exists", AssetName))
        end

        assert(typeof(RobloxAssetId) == "number", "RobloxAssetId must be a number")

        CustomImageManagerAssets[AssetName] = {
            RobloxId = RobloxAssetId,
            Path = string.format("Azure/custom_assets/%s", AssetName),
            URL = URL,

            Id = nil,
        }

        CustomImageManager.DownloadAsset(AssetName, ForceRedownload)
    end

    function CustomImageManager.GetAsset(AssetName: string)
        if not CustomImageManagerAssets[AssetName] then
            return nil
        end

        local AssetData = CustomImageManagerAssets[AssetName]
        if AssetData.Id then
            return AssetData.Id
        end

        local AssetID = string.format("rbxassetid://%s", AssetData.RobloxId)

        if getcustomasset then
            local Success, NewID = pcall(getcustomasset, AssetData.Path)

            if Success and NewID then
                AssetID = NewID
            end
        end

        AssetData.Id = AssetID
        return AssetID
    end

    function CustomImageManager.DownloadAsset(AssetName: string, ForceRedownload: boolean?)
        if not getcustomasset or not writefile or not isfile then
            return false, "missing functions"
        end

        local AssetData = CustomImageManagerAssets[AssetName]

        RecursiveCreatePath(AssetData.Path, true)

        -- A cached file that isn't actually PNG data means some earlier fetch
        -- (a transient outage, a 404 before the asset was uploaded, whatever)
        -- got written to disk as if it succeeded, and it would otherwise stay
        -- cached forever - every UI element using it silently renders blank.
        -- Treat that the same as "not cached" and redownload.
        local function isPng(data)
            return typeof(data) == "string" and #data >= 4 and data:byte(1) == 0x89
                and data:byte(2) == 0x50 and data:byte(3) == 0x4E and data:byte(4) == 0x47
        end

        if ForceRedownload ~= true and isfile(AssetData.Path) then
            local cached = nil
            pcall(function() cached = readfile(AssetData.Path) end)
            if isPng(cached) then
                return true, nil
            end
        end

        local success, errorMessage = pcall(function()
            local data = game:HttpGet(AssetData.URL)
            if not isPng(data) then
                error("downloaded asset is not valid PNG data")
            end
            writefile(AssetData.Path, data)
        end)

        return success, errorMessage
    end

    for AssetName, _ in CustomImageManagerAssets do
        CustomImageManager.DownloadAsset(AssetName)
    end
end

local Library = {
    LocalPlayer = LocalPlayer,
    IsRobloxFocused = true,

    --// Device \\--
    DevicePlatform = nil,
    IsMobile = false,

    --// Azure Windows \\--
    ScreenGui = nil,
    Window = nil,
    WindowContainer = nil,

    --// Search \\--
    SearchText = "",
    Searching = false,
    GlobalSearch = false,
    LastSearchTab = nil,

    --// Tabs \\--
    ActiveTab = nil,
    PreviousTab = nil,
    Tabs = {},
    TabButtons = {},

    --// Dependency Boxes \\--
    DependencyBoxes = {},

    --// Keybinds Frame \\--
    KeybindFrame = nil,
    KeybindContainer = nil,
    KeybindToggles = {},

    --// Notifications \\--
    Notifications = {},
    NotifySide = "Right",
    NotifyTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),

    --// Dialogues \\--
    Dialogues = {},
    ActiveDialog = nil,

    --// Loading Window \\--
    ActiveLoading = nil,

    --// Corners \\--
    Corners = {},
    SpecificCorners = {},

    --// Animations \\--
    TweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),

    TabTransitionInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    TabSwipeOffset = 26,
    TabSwipeFrom = "bottom",

    WindowAnimationInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    DropdownTransitionInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    KeyPickerTransitionInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),

    GroupboxTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
    RotatingChevronTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),

    Animations = {
        -- ToggleWindow is left off deliberately: our own window fade replaced
        -- upstream's and does not read this flag.
        ToggleWindow = false,
        TabSwitch = true,
        Groupbox = true,
        Dropdown = true,
        KeyPicker = true
    },

    --// States \\--
    Toggled = false,
    Unloaded = false,

    --// Elements \\--
    Labels = Labels,
    Buttons = Buttons,
    Toggles = Toggles,
    Options = Options,

    --// Options \\--
    ToggleKeybind = Enum.KeyCode.RightControl,
    ShowToggleFrameInKeybinds = true,

    NotifyOnError = false,
    ShowCustomCursor = true,
    ForceCheckbox = false,

    CantDragForced = false,
    DraggableElements = {},

    --// Signals \\--
    Signals = {},
    UnloadSignals = {},

    OriginalMinSize = Vector2.new(480, 360),
    MinSize = Vector2.new(480, 360),
    DPIScale = 1,
    -- Groupbox pop-out (detach) is opt-in per library now; the header button was
    -- unwanted clutter on every box. A script can flip this on, or pass PopOut = true.
    GroupboxPopOut = false,
    PopOutSnapDistance = 80,
    PopOutDragThreshold = 8,
    PopOutHoldTime = 0.15,
    CornerRadius = 4,

    --// Scheme \\--
    IsLightTheme = false,
    Scheme = {
        BackgroundColor = Color3.fromRGB(10, 11, 14),
        MainColor = Color3.fromRGB(18, 19, 23),
        AccentColor = Color3.fromRGB(125, 85, 255),
        OutlineColor = Color3.fromRGB(30, 31, 36),
        FontColor = Color3.new(1, 1, 1),
        Font = Font.fromEnum(Enum.Font.Code),

        RedColor = Color3.fromRGB(255, 50, 50),
        DestructiveColor = Color3.fromRGB(220, 38, 38),
        DarkColor = Color3.new(0, 0, 0),
        WhiteColor = Color3.new(1, 1, 1),

        BackgroundImage = ""
    },

    --// Registry \\--
    Registry = {},
	Scales = {},
	ScalesOffset = {},

    --// Misc \\--
    ImageManager = CustomImageManager,
    ShowCursorBinding = string.sub(tostring({}), 10),

    Notify = nil, Toggle = nil -- we love luau lsp
}

if RunService:IsStudio() then
    if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
        Library.IsMobile = true
        Library.OriginalMinSize = Vector2.new(480, 240)
    else
        Library.IsMobile = false
        Library.OriginalMinSize = Vector2.new(480, 360)
    end
else
    pcall(function()
        Library.DevicePlatform = UserInputService:GetPlatform()
    end)

    Library.IsMobile = (Library.DevicePlatform == Enum.Platform.Android or Library.DevicePlatform == Enum.Platform.IOS) and not UserInputService.KeyboardEnabled
    Library.OriginalMinSize = Library.IsMobile and Vector2.new(480, 240) or Vector2.new(480, 360)
end
if Library.IsMobile then
    Library.DPIScale = 0.85
end

local Templates = {
    --// UI \\--
    Frame = {
        BorderSizePixel = 0,
    },
    ImageLabel = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    },
    ImageButton = {
        AutoButtonColor = false,
        BorderSizePixel = 0,
    },
    ScrollingFrame = {
        BorderSizePixel = 0,
    },
    TextLabel = {
        BorderSizePixel = 0,
        FontFace = "Font",
        RichText = true,
        TextColor3 = "FontColor",
    },
    TextButton = {
        AutoButtonColor = false,
        BorderSizePixel = 0,
        FontFace = "Font",
        RichText = true,
        TextColor3 = "FontColor",
    },
    TextBox = {
        BorderSizePixel = 0,
        FontFace = "Font",
        PlaceholderColor3 = function()
            local H, S, V = Library.Scheme.FontColor:ToHSV()
            return Color3.fromHSV(H, S, V / 2)
        end,
        Text = "",
        TextColor3 = "FontColor",
    },
    UIListLayout = {
        SortOrder = Enum.SortOrder.LayoutOrder,
    },
    UIStroke = {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    },

    --// Library \\--
    Window = {
        Title = "No Title",
        Footer = "No Footer",

        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(720, 600),
        IconSize = UDim2.fromOffset(30, 30),

        AutoShow = true,
        Center = true,
        Resizable = true,
        AlwaysOnTop = false,

        SearchbarSize = UDim2.fromScale(1, 1),
        GlobalSearch = false,

        CornerRadius = 4,
        NotifySide = "Right",
        ShowCustomCursor = true,

        Font = Enum.Font.Code,
        ToggleKeybind = Enum.KeyCode.RightControl,

        ShowMobileButtons = true,
        MobileButtonsSide = "Left",

        TabDock = true,
        TabDockSide = "Right",

        UnlockMouseWhileOpen = true,

        EnableSidebarResize = false,
        EnableCompacting = true,
        DisableCompactingSnap = false,
        SidebarCompacted = false,
        MinContainerWidth = 256,

        --// Window Snapping \\--
        Snapping = false,
        SnapDistance = 28,
        SnapMargin = 8,
        SnapAvoidCoreGui = true,

        --// Snapping \\--
        MinSidebarWidth = 128,
        SidebarCompactWidth = 48,
        SidebarCollapseThreshold = 0.5,

        --// Dragging \\--
        CompactWidthActivation = 128,

        --// Background \\--
        BackgroundImage = "",

        --// Animations \\--
        Animations = {
            ToggleWindow = false,
            TabSwitch = true,
            Groupbox = true,
            Dropdown = true,
            KeyPicker = true
        },

        TabTransitionTime = 0.22,
        TabSwipeOffset = 26,
        TabSwipeFrom = "bottom",
        TabButtonsStyle = {
            Gap = 0,
            Padding = 0,
            CornerRadius = 0,
            Indicator = false,
            IndicatorWidth = 2,
            IndicatorHeight = 20,
            SelectedTransparency = 0.82,
            IndicatorOffset = 2,
        },
    },
    Dialog = {
        Title = "Dialog",
        Description = "Description",
        AutoDismiss = true,
        OutsideClickDismiss = true,
        FooterButtons = {}
    },
    Loading = {
        Title = "mspaint",
        Icon = 95816097006870,
        IconSize = UDim2.fromOffset(30, 30),

        LoadingIcon = CustomImageManager.GetAsset("LoadingIcon"),
        LoadingIconColor = nil,
        LoadingIconTweenTime = 1,

        CurrentStep = 0,
        TotalSteps = 10,

        ShowSidebar = false,
        AutoResizeHeight = false,
        AlwaysOnTop = true,

        WindowWidth = 450,
        WindowHeight = 275,

        ContentWidth = 450,
        SidebarWidth = 250,
    },
    Toggle = {
        Text = "Toggle",
        Default = false,

        Callback = function() end,
        Changed = function() end,

        Risky = false,
        Disabled = false,
        Visible = true,
    },
    Input = {
        Text = "Input",
        Default = "",
        Finished = false,
        Numeric = false,
        ClearTextOnFocus = true,
        ClearTextOnBlur = false,
        Placeholder = "",
        AllowEmpty = true,
        EmptyReset = "---",

        Callback = function() end,
        Changed = function() end,
        VerifyValue = nil,

        Disabled = false,
        Visible = true,
    },
    Slider = {
        Text = "Slider",
        Default = 0,
        Min = 0,
        Max = 100,
        Rounding = 0,

        Prefix = "",
        Suffix = "",

        Callback = function() end,
        Changed = function() end,

        Disabled = false,
        Visible = true,

        AllowRightClickInput = true
    },
    Dropdown = {
        Values = {},
        DisabledValues = {},
        ValueImages = {},
        ValueSuffixImages = {},
        SuffixAfterText = "",

        Multi = false,
        DragSelect = false,
        MaxVisibleDropdownItems = 8,

        Callback = function() end,
        Changed = function() end,

        Disabled = false,
        Visible = true,
    },
    Viewport = {
        Object = nil,
        Camera = nil,
        Clone = true,
        AutoFocus = true,
        Interactive = false,
        Height = 200,
        Visible = true,
    },
    Image = {
        Image = "",
        Transparency = 0,
        BackgroundTransparency = 0,
        Color = Color3.new(1, 1, 1),
        RectOffset = Vector2.zero,
        RectSize = Vector2.zero,
        ScaleType = Enum.ScaleType.Fit,
        Height = 200,
        Visible = true,
    },
    Video = {
        Video = "",
        Looped = false,
        Playing = false,
        Volume = 1,
        Height = 200,
        Visible = true,
    },
    UIPassthrough = {
        Instance = nil,
        Height = 24,
        Visible = true,
    },

    --// Addons \\-
    KeyPicker = {
        Text = "KeyPicker",

        Default = "None",
        DefaultModifiers = {},

        Blacklisted = {},
        BlacklistedModifiers = {},
        Whitelisted = {},
        WhitelistedModifiers = {},

        Mode = "Toggle",
        Modes = { "Always", "Toggle", "Hold" },
        SyncToggleState = false,

        Callback = function() end,
        ChangedCallback = function() end,
        Changed = function() end,
        Clicked = function() end,
    },
    ColorPicker = {
        Default = Color3.new(1, 1, 1),

        Resizable = true,

        Callback = function() end,
        Changed = function() end,
    },
}

local Places = {
    Bottom = { 0, 1 },
    Right = { 1, 0 },
}
local Sizes = {
    Left = { 0.5, 1 },
    Right = { 0.5, 1 },
}

--// Scheme Functions \\--
local SchemeReplaceAlias = {
    RedColor = "Red",
    WhiteColor = "White",
    DarkColor = "Dark"
}

local SchemeAlias = {
    Red = "RedColor",
    White = "WhiteColor",
    Dark = "DarkColor"
}

local function GetSchemeValue(Index)
    if not Index then
        return nil
    end

    local ReplaceAliasIndex = SchemeReplaceAlias[Index]
    if ReplaceAliasIndex and Library.Scheme[ReplaceAliasIndex] ~= nil then
        Library.Scheme[Index] = Library.Scheme[ReplaceAliasIndex]
        Library.Scheme[ReplaceAliasIndex] = nil

        return Library.Scheme[Index]
    end

    local AliasIndex = SchemeAlias[Index]
    if AliasIndex and Library.Scheme[AliasIndex] ~= nil then
        do end
        return Library.Scheme[AliasIndex]
    end

    return Library.Scheme[Index]
end

--// Basic Functions \\--
local function WaitForEvent(Event, Timeout, Condition)
    local Bindable = Instance.new("BindableEvent")
    local Connection = Event:Once(ObsGuard(function(...)
        if not Condition or typeof(Condition) == "function" and Condition(...) then
            Bindable:Fire(true)
        else
            Bindable:Fire(false)
        end
    end))
    task.delay(Timeout, function()
        Connection:Disconnect()
        Bindable:Fire(false)
    end)

    local Result = Bindable.Event:Wait()
    Bindable:Destroy()

    return Result
end

local function IsMouseInput(Input: InputObject, IncludeM2: boolean?)
    return Input.UserInputType == Enum.UserInputType.MouseButton1
        or (IncludeM2 == true and Input.UserInputType == Enum.UserInputType.MouseButton2)
        or Input.UserInputType == Enum.UserInputType.Touch
end
local function IsClickInput(Input: InputObject, IncludeM2: boolean?)
    return IsMouseInput(Input, IncludeM2)
        and Input.UserInputState == Enum.UserInputState.Begin
        and Library.IsRobloxFocused
end
local function IsHoverInput(Input: InputObject)
    return (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch)
        and Input.UserInputState == Enum.UserInputState.Change
end
local function IsDragInput(Input: InputObject, IncludeM2: boolean?)
    return IsMouseInput(Input, IncludeM2)
        and (Input.UserInputState == Enum.UserInputState.Begin or Input.UserInputState == Enum.UserInputState.Change)
        and Library.IsRobloxFocused
end
local function IsMouseClickInput(Input: InputObject)
    return Input.UserInputType == Enum.UserInputType.MouseButton1 or 
        Input.UserInputType == Enum.UserInputType.MouseButton2 or 
        Input.UserInputType == Enum.UserInputType.MouseButton3
end
local function IsMovementInput(Input: InputObject)
    return (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch)
        and Library.IsRobloxFocused
end

local function GetTableSize(Table: { [any]: any })
    local Size = 0

    for _, _ in Table do
        Size += 1
    end

    return Size
end
local function IsSequentialArray(Table: { [any]: any })
    for Key in Table do
        if typeof(Key) ~= "number" or Key < 1 or Key % 1 ~= 0 then
            return false
        end
    end

    return true
end

local function StopTween(Tween: TweenBase, Destroy: boolean?)
    if not Tween then
        return
    end

    if Tween.PlaybackState == Enum.PlaybackState.Playing then
        Tween:Cancel()
    end

    if Destroy == true then
        pcall(Tween.Destroy, Tween)
    end
end

local function Trim(Text: string)
    return Text:match("^%s*(.-)%s*$")
end
local function Round(Value, Rounding)
    assert(Rounding >= 0, "Invalid rounding number.")

    if Rounding == 0 then
        return math.floor(Value)
    end

    return tonumber(string.format("%." .. Rounding .. "f", Value))
end

--// Fuzzy Search \\--
local function FuzzyScore(Text: string, Search: string): (boolean, number)
    if Search == "" then
        return true, 0
    end
    if Text == "" then
        return false, 0
    end

    --// Fast path: literal substring match (also the best possible score) \\--
    local ExactIdx = Text:find(Search, 1, true)
    if ExactIdx then
        local PrevChar = ExactIdx > 1 and Text:sub(ExactIdx - 1, ExactIdx - 1) or ""
        local AtBoundary = ExactIdx == 1 or PrevChar:match("[%s%p_]") ~= nil

        return true, 1e5 - ExactIdx + (AtBoundary and 500 or 0) + (Search:len() * 5)
    end

    --// Fallback: fuzzy, in-order, non-consecutive character matching \\--
    local TextLen, SearchLen = Text:len(), Search:len()
    if SearchLen > TextLen then
        return false, 0
    end

    local SearchIdx = 1
    local Score = 0
    local RunLength = 0
    local LastMatchIdx = 0

    for TextIdx = 1, TextLen do
        if SearchIdx > SearchLen then
            break
        end

        if Text:sub(TextIdx, TextIdx) == Search:sub(SearchIdx, SearchIdx) then
            local PrevChar = TextIdx > 1 and Text:sub(TextIdx - 1, TextIdx - 1) or ""
            local AtBoundary = TextIdx == 1 or PrevChar:match("[%s%p_]") ~= nil

            RunLength = (LastMatchIdx == TextIdx - 1) and (RunLength + 1) or 1
            Score += 1 + (AtBoundary and 6 or 0) + math.min(RunLength - 1, 5) * 3

            LastMatchIdx = TextIdx
            SearchIdx += 1
        end
    end

    if SearchIdx <= SearchLen then
        return false, 0 --// Not every Search character was found, in order
    end

    Score -= (LastMatchIdx - SearchLen) * 0.05 --// Slightly favour tighter matches
    return true, Score
end

local function NormalizeSearch(Search: string): string
    return (Search:gsub("%s+", ""))
end

local function TryFuzzyMatch(Text: any, Search: string): (boolean, number)
    if typeof(Text) ~= "string" or Text == "" then
        return false, 0
    end

    return FuzzyScore(Text:lower(), Search)
end

local function FuzzyMatchScore(Text: any, Search: string): number
    if typeof(Text) ~= "string" or Text == "" then
        return 0
    end

    local Normalized = NormalizeSearch(Text:lower())
    local Matched, Score = FuzzyScore(Normalized, Search)
    if not Matched then
        return 0
    end

    if Normalized == Search then
        Score += 1000
    end

    return Score
end

local function MatchesSearch(ElementInfo, Search: string, ForceMatch: boolean?): boolean
    if not ElementInfo then
        return false
    end
    if ForceMatch then
        return true
    end

    if TryFuzzyMatch(ElementInfo.Text, Search) then
        return true
    end
    if TryFuzzyMatch(ElementInfo.Tooltip, Search) then
        return true
    end
    if TryFuzzyMatch(ElementInfo.DisabledTooltip, Search) then
        return true
    end

    --// Optional: search inside Dropdown value lists, so e.g. searching a specific option name reveals the Dropdown that contains it \\--
    if typeof(ElementInfo.Values) == "table" then
        local Checked = 0
        for Key, Value in ElementInfo.Values do
            Checked += 1
            if Checked > 200 then
                break
            end

            if TryFuzzyMatch(Value, Search) or (typeof(Value) ~= "string" and TryFuzzyMatch(tostring(Value), Search)) then
                return true
            end
            if typeof(Key) == "string" and TryFuzzyMatch(Key, Search) then
                return true
            end
        end
    end

    return false
end

local function GetPlayers(ExcludeLocalPlayer: boolean?)
    local PlayerList = Players:GetPlayers()

    if ExcludeLocalPlayer then
        local Idx = table.find(PlayerList, LocalPlayer)
        if Idx then
            table.remove(PlayerList, Idx)
        end
    end

    table.sort(PlayerList, function(Player1, Player2)
        return Player1.Name:lower() < Player2.Name:lower()
    end)

    return PlayerList
end
local function GetTeams()
    local TeamList = Teams:GetTeams()

    table.sort(TeamList, function(Team1, Team2)
        return Team1.Name:lower() < Team2.Name:lower()
    end)

    return TeamList
end

local function DepboxDependsOn(Depbox, Element)
    local Dependencies = Depbox.Dependencies
    if type(Dependencies) ~= "table" then
        return true
    end
    for _, Dependency in Dependencies do
        if Dependency[1] == Element then
            return true
        end
    end
    return false
end

function Library:UpdateDependencyBoxes(Element)
    for _, Depbox in Library.DependencyBoxes do
        if Element == nil or DepboxDependsOn(Depbox, Element) then
            Depbox:Update(true)
        end
    end

    if Library.Searching then
        Library:UpdateSearch(Library.SearchText)
    end
end

function Library:UpdateAddons(Parent)
    if not Parent or not Parent.Addons then
        return
    end

    for _, Addon in Parent.Addons do
        Addon:Update()
    end
end

local function CheckDepbox(Box, Search, ForceVisible: boolean?)
    local VisibleElements = 0
    local BestScore = 0

    for _, ElementInfo in Box.Elements do
        if ElementInfo.Type == "Divider" then
            ElementInfo.Holder.Visible = false
            continue
        elseif ElementInfo.SubButton then
            --// Check if any of the Buttons Name matches with Search
            local Visible = false

            --// Check if Search matches Element's Name and if Element is Visible
            if ElementInfo.Text:lower():find(Search, 1, true) and ElementInfo.Visible then
                Visible = true
                BestScore = math.max(BestScore, FuzzyMatchScore(ElementInfo.Text, Search))
            else
                ElementInfo.Base.Visible = false
            end
            if ElementInfo.SubButton.Text:lower():find(Search, 1, true) and ElementInfo.SubButton.Visible then
                Visible = true
                BestScore = math.max(BestScore, FuzzyMatchScore(ElementInfo.SubButton.Text, Search))
            else
                ElementInfo.SubButton.Base.Visible = false
            end
            ElementInfo.Holder.Visible = Visible
            if Visible then
                VisibleElements += 1
            end

            continue
        end

        --// Check if Search matches Element's Name and if Element is Visible
        if ElementInfo.Text and ElementInfo.Text:lower():find(Search, 1, true) and ElementInfo.Visible then
            ElementInfo.Holder.Visible = true
            VisibleElements += 1
            BestScore = math.max(BestScore, FuzzyMatchScore(ElementInfo.Text, Search))
        else
            ElementInfo.Holder.Visible = false
        end
    end

    for _, Depbox in Box.DependencyBoxes do
        if not Depbox.Visible then
            continue
        end

        local DepVisible, DepScore = CheckDepbox(Depbox, Search, ForceVisible)
        VisibleElements += DepVisible
        if DepScore > BestScore then
            BestScore = DepScore
        end
    end

    Box.Holder.Visible = VisibleElements > 0
    return VisibleElements, BestScore
end
local function RestoreDepbox(Box)
    for _, ElementInfo in Box.Elements do
        ElementInfo.Holder.Visible = ElementInfo.Visible ~= false

        if ElementInfo.SubButton then
            ElementInfo.Base.Visible = ElementInfo.Visible
            ElementInfo.SubButton.Base.Visible = ElementInfo.SubButton.Visible
        end
    end

    Box:Resize()
    Box.Holder.Visible = true

    for _, Depbox in Box.DependencyBoxes do
        if not Depbox.Visible then
            continue
        end

        RestoreDepbox(Depbox)
    end
end

local function ApplySearchToTab(Tab, Search)
    if not Tab then
        return false, 0
    end

    local HasVisible = false
    local BestScore = 0

    --// If the Tab itself matches Search (by name/description), don't filter out its contents -- pull everything in the Tab along with it \\--
    local TabMatches = TryFuzzyMatch(Tab.Name, Search) or TryFuzzyMatch(Tab.Description, Search)
    BestScore = math.max(BestScore, FuzzyMatchScore(Tab.Name, Search), FuzzyMatchScore(Tab.Description, Search))

    for _, Groupbox in Tab.Groupboxes do
        if Groupbox.Visible == false then
            continue
        end

        --// Optional: matching the Groupbox's own name/description reveals every element inside it, without needing each one to match too
        local GroupboxMatches = TabMatches or (TryFuzzyMatch(Groupbox.Name, Search) or TryFuzzyMatch(Groupbox.Description, Search))
        BestScore = math.max(BestScore, FuzzyMatchScore(Groupbox.Name, Search), FuzzyMatchScore(Groupbox.Description, Search))

        local VisibleElements = 0
        for _, ElementInfo in Groupbox.Elements do
            if ElementInfo.Type == "Divider" then
                ElementInfo.Holder.Visible = false
                continue
            elseif ElementInfo.SubButton then
                --// Check if any of the Buttons Name matches with Search
                local Visible = false

                --// Check if Search matches Element's Name and if Element is Visible
                if ElementInfo.Text:lower():find(Search, 1, true) and ElementInfo.Visible then
                    Visible = true
                    BestScore = math.max(BestScore, FuzzyMatchScore(ElementInfo.Text, Search))
                else
                    ElementInfo.Base.Visible = false
                end
                if ElementInfo.SubButton.Text:lower():find(Search, 1, true) and ElementInfo.SubButton.Visible then
                    Visible = true
                    BestScore = math.max(BestScore, FuzzyMatchScore(ElementInfo.SubButton.Text, Search))
                else
                    ElementInfo.SubButton.Base.Visible = false
                end
                ElementInfo.Holder.Visible = Visible

                if Visible then
                    VisibleElements += 1
                end

                continue
            end

            --// Check if Search matches Element's Name and if Element is Visible
            if ElementInfo.Text and ElementInfo.Text:lower():find(Search, 1, true) and ElementInfo.Visible then
                ElementInfo.Holder.Visible = true
                VisibleElements += 1
                BestScore = math.max(BestScore, FuzzyMatchScore(ElementInfo.Text, Search))
            else
                ElementInfo.Holder.Visible = false
            end
        end

        for _, Depbox in Groupbox.DependencyBoxes do
            if not Depbox.Visible then
                continue
            end

            local DepVisible, DepScore = CheckDepbox(Depbox, Search, GroupboxMatches)
            VisibleElements += DepVisible
            if DepScore > BestScore then
                BestScore = DepScore
            end
        end

        --// Update Groupbox Size and Visibility if found any element
        if VisibleElements > 0 then
            Groupbox:Resize()
            HasVisible = true
        end
        Groupbox.BoxHolder.Visible = VisibleElements > 0
    end

    for _, Tabbox in Tab.Tabboxes do
        local VisibleTabs = 0
        local VisibleElements = {}
        local SubTabScores = {}

        for _, SubTab in Tabbox.Tabs do
            VisibleElements[SubTab] = 0

            --// Optional: matching a Tabbox sub-tab's own name reveals every element inside it, without needing each one to match too
            local SubTabMatches = TabMatches or TryFuzzyMatch(SubTab.Name, Search)
            local SubScore = FuzzyMatchScore(SubTab.Name, Search)
            BestScore = math.max(BestScore, SubScore)

            for _, ElementInfo in SubTab.Elements do
                if ElementInfo.Type == "Divider" then
                    ElementInfo.Holder.Visible = false
                    continue
                elseif ElementInfo.SubButton then
                    --// Check if any of the Buttons Name matches with Search
                    local Visible = false

                    --// Check if Search matches Element's Name and if Element is Visible
                    if ElementInfo.Text:lower():find(Search, 1, true) and ElementInfo.Visible then
                        Visible = true
                        local ElementScore = FuzzyMatchScore(ElementInfo.Text, Search)
                        SubScore = math.max(SubScore, ElementScore)
                        BestScore = math.max(BestScore, ElementScore)
                    else
                        ElementInfo.Base.Visible = false
                    end
                    if ElementInfo.SubButton.Text:lower():find(Search, 1, true) and ElementInfo.SubButton.Visible then
                        Visible = true
                        local ElementScore = FuzzyMatchScore(ElementInfo.SubButton.Text, Search)
                        SubScore = math.max(SubScore, ElementScore)
                        BestScore = math.max(BestScore, ElementScore)
                    else
                        ElementInfo.SubButton.Base.Visible = false
                    end
                    ElementInfo.Holder.Visible = Visible
                    if Visible then
                        VisibleElements[SubTab] += 1
                    end

                    continue
                end

                --// Check if Search matches Element's Name and if Element is Visible
                if ElementInfo.Text and ElementInfo.Text:lower():find(Search, 1, true) and ElementInfo.Visible then
                    ElementInfo.Holder.Visible = true
                    VisibleElements[SubTab] += 1
                    local ElementScore = FuzzyMatchScore(ElementInfo.Text, Search)
                    SubScore = math.max(SubScore, ElementScore)
                    BestScore = math.max(BestScore, ElementScore)
                else
                    ElementInfo.Holder.Visible = false
                end
            end

            for _, Depbox in SubTab.DependencyBoxes do
                if not Depbox.Visible then
                    continue
                end

                local DepVisible, DepScore = CheckDepbox(Depbox, Search, SubTabMatches)
                VisibleElements[SubTab] += DepVisible
                SubScore = math.max(SubScore, DepScore)
                BestScore = math.max(BestScore, DepScore)
            end

            SubTabScores[SubTab] = SubScore
        end

        local BestSubTab = nil
        local BestSubScore = -1

        for SubTab, Visible in VisibleElements do
            SubTab.ButtonHolder.Visible = Visible > 0
            if Visible > 0 then
                VisibleTabs += 1
                HasVisible = true

                local SubScore = SubTabScores[SubTab] or 0
                if SubScore > BestSubScore then
                    BestSubScore = SubScore
                    BestSubTab = SubTab
                end
            end
        end

        local ActiveSubTab = Tabbox.ActiveTab
        local ActiveSubVisible = ActiveSubTab and (VisibleElements[ActiveSubTab] or 0) > 0
        local ActiveSubScore = ActiveSubTab and (SubTabScores[ActiveSubTab] or -1) or -1

        if ActiveSubVisible and ActiveSubScore >= BestSubScore then
            ActiveSubTab:Resize()
        elseif BestSubTab then
            BestSubTab:Show()
        end

        --// Update Tabbox Visibility if any visible
        Tabbox.BoxHolder.Visible = VisibleTabs > 0
    end

    return HasVisible, BestScore
end
local function ResetTab(Tab)
    if not Tab then
        return
    end

    for _, Groupbox in Tab.Groupboxes do
        for _, ElementInfo in Groupbox.Elements do
            ElementInfo.Holder.Visible = ElementInfo.Visible ~= false

            if ElementInfo.SubButton then
                ElementInfo.Base.Visible = ElementInfo.Visible
                ElementInfo.SubButton.Base.Visible = ElementInfo.SubButton.Visible
            end
        end

        for _, Depbox in Groupbox.DependencyBoxes do
            if not Depbox.Visible then
                continue
            end

            RestoreDepbox(Depbox)
        end

        Groupbox:Resize()
        Groupbox.BoxHolder.Visible = Groupbox.Visible ~= false
    end

    for _, Tabbox in Tab.Tabboxes do
        for _, SubTab in Tabbox.Tabs do
            for _, ElementInfo in SubTab.Elements do
                ElementInfo.Holder.Visible = ElementInfo.Visible ~= false

                if ElementInfo.SubButton then
                    ElementInfo.Base.Visible = ElementInfo.Visible
                    ElementInfo.SubButton.Base.Visible = ElementInfo.SubButton.Visible
                end
            end

            for _, Depbox in SubTab.DependencyBoxes do
                if not Depbox.Visible then
                    continue
                end

                RestoreDepbox(Depbox)
            end

            SubTab.ButtonHolder.Visible = true
        end

        if Tabbox.ActiveTab then
            Tabbox.ActiveTab:Resize()
        end
        Tabbox.BoxHolder.Visible = true
    end
end

function Library:UpdateSearch(SearchText)
    Library.SearchText = SearchText

    local TabsToSearch = {}
    for _, Tab in Library.Tabs do
        if typeof(Tab) == "table" and not Tab.IsKeyTab then
            table.insert(TabsToSearch, Tab)
        end
    end

    for _, Tab in TabsToSearch do
        ResetTab(Tab)
    end
    Library:RefreshGradVisibility()

    local Search = SearchText:lower()
    if Trim(Search) == "" then
        Library.Searching = false
        Library.LastSearchTab = nil
        return
    end
    if not Library.GlobalSearch and Library.ActiveTab and Library.ActiveTab.IsKeyTab then
        Library.Searching = false
        Library.LastSearchTab = nil
        return
    end

    Library.Searching = true

    local BestTab = nil
    local BestScore = -1
    local ActiveScore = -1
    local ActiveHasVisible = false

    for _, Tab in TabsToSearch do
        local HasVisible, Score = ApplySearchToTab(Tab, Search)
        if not HasVisible then
            continue
        end

        if Tab == Library.ActiveTab then
            ActiveHasVisible = true
            ActiveScore = Score
        end
        if Score > BestScore then
            BestScore = Score
            BestTab = Tab
        end
    end

    if not Library.GlobalSearch then
        for _, Tab in TabsToSearch do
            if Tab ~= BestTab then
                ResetTab(Tab)
            end
        end
    end

    Library:RefreshGradVisibility()
    local StayOnActive = ActiveHasVisible and ActiveScore >= BestScore
    if StayOnActive and Library.ActiveTab then
        Library.ActiveTab:RefreshSides()
    elseif BestTab then
        local SearchMarker = SearchText
        task.defer(function()
            if Library.SearchText ~= SearchMarker then
                return
            end

            if Library.ActiveTab ~= BestTab then
                BestTab:Show()
            elseif Library.ActiveTab then
                Library.ActiveTab:RefreshSides()
            end
        end)
    end

    Library.LastSearchTab = nil
end

function Library:AddToRegistry(Instance, Properties)
    Library.Registry[Instance] = Properties
end

function Library:RemoveFromRegistry(Instance)
    Library.Registry[Instance] = nil
end

local _registryPassQueued = false
local function RunRegistryPass()
    -- Walk a snapshot: writing a property can build UI, and anything that calls
    -- AddToRegistry mid-pass rehashes Registry and kills the iterator with
    -- "invalid key to 'next'".
    local Targets = table.create(64)
    for Instance in Library.Registry do
        Targets[#Targets + 1] = Instance
    end

    for _, Instance in ipairs(Targets) do
        local Properties = Library.Registry[Instance]

        if Properties then
            for Property, Index in Properties do
                local SchemeValue = GetSchemeValue(Index)

                if SchemeValue or typeof(Index) == "function" then
                    Instance[Property] = SchemeValue or Index()
                end
            end
        end
    end
end

function Library:UpdateColorsUsingRegistry(Immediate: boolean?)
    if Immediate then
        _registryPassQueued = false
        RunRegistryPass()
        return
    end
    if _registryPassQueued then
        return
    end
    _registryPassQueued = true
    task.defer(function()
        if not _registryPassQueued then
            return
        end
        _registryPassQueued = false
        if Library.Unloaded then
            return
        end
        RunRegistryPass()
    end)
end

function Library:SetDPIScale(DPIScale: number)
    Library.DPIScale = DPIScale / 100
    Library.MinSize = Library.OriginalMinSize * Library.DPIScale

    for i = #Library.Scales, 1, -1 do
        local UIScale = Library.Scales[i]
        if not UIScale.Parent then
            table.remove(Library.Scales, i)
            Library.ScalesOffset[UIScale] = nil
        else
            UIScale.Scale = Library.DPIScale - (tonumber(Library.ScalesOffset[UIScale]) or 0)
        end
    end

    for _, Option in Options do
        if Option.Type == "Dropdown" then
            Option:RecalculateListSize()
            Option:RefreshPool()
        end
    end

    for _, Notification in Library.Notifications do
        Notification:Resize()
    end

    (Library :: any):UpdateNotificationPositions(true)
end

function Library:GiveSignal(Connection: RBXScriptConnection | RBXScriptSignal)
    local ConnectionType = typeof(Connection)
    if Connection and (ConnectionType == "RBXScriptConnection" or ConnectionType == "RBXScriptSignal") then
        table.insert(Library.Signals, Connection)
    end

    return Connection
end

function IsValidCustomIcon(Icon: string)
    return typeof(Icon) == "string" and (Icon:match("^rbxasset://textures/") or Icon:match("roblox%.com/asset/%?id=") or Icon:match("rbxthumb://type="))
end

local function IsCustomAssetIcon(Icon: string, IncludeAssetId: boolean)
    return typeof(Icon) == "string" and (Icon:match("^content://") or (Icon:match("^rbxasset://%x+/") or Icon:match("^rbxasset://[^/]+/")) or (IncludeAssetId == true and Icon:match("^rbxassetid://")))
end

type Icon = {
    Url: string,
    Id: number,
    IconName: string,
    ImageRectOffset: Vector2,
    ImageRectSize: Vector2,
}

type IconModule = {
    Icons: { string },
    GetAsset: (Name: string) -> Icon?,
}

local FetchIcons, Icons = pcall(function()
    return (loadstring(
        game:HttpGet("https://raw.githubusercontent.com/swrenic/ui/main/lucide-source.lua")
    ) :: () -> IconModule)()
end)

function Library:GetIcon(IconName: string)
    if not FetchIcons or type(Icons) ~= "table" or type(Icons.GetAsset) ~= "function" then
        return { Url = "" }
    end

    local Success, Icon = pcall(Icons.GetAsset, IconName)
    if not Success or not Icon then
        return { Url = "" }
    end
    
    return Icon
end

function Library:ResolveInlineIcon(Icon)
    if Icon == nil or Icon == "" then
        return nil
    end
    if type(Icon) == "table" then
        local Art = Library:GetCustomIcon(Icon)
        return Art, true
    end
    if type(Icon) == "string" and not string.find(Icon, "://", 1, true) and not tonumber(Icon) then
        return Library:GetIcon(Icon), false
    end
    return { Url = tonumber(Icon) and ("rbxassetid://" .. tostring(Icon)) or tostring(Icon), ImageRectOffset = Vector2.zero, ImageRectSize = Vector2.zero }, true
end

function Library:GetCustomIcon(IconName: string): any
    if not IconName then
        return { Url = "" }
    end

    if type(IconName) == "table" and type(IconName.Url) == "string" then
        return {
            Url = IconName.Url,
            ImageRectOffset = IconName.ImageRectOffset or Vector2.zero,
            ImageRectSize = IconName.ImageRectSize or Vector2.zero,
            Custom = IconName.Custom ~= false,
        }
    end

    if tonumber(IconName) then
        IconName = string.format("rbxassetid://%s", tostring(IconName))
    end

    if IsCustomAssetIcon(IconName, true) then
        return {
            Url = IconName,
            ImageRectOffset = Vector2.zero,
            ImageRectSize = Vector2.zero,
        }
    elseif IsValidCustomIcon(IconName) then
        return {
            Url = IconName,
            ImageRectOffset = Vector2.zero,
            ImageRectSize = Vector2.zero,
            Custom = true,
        }
    end

    local LucideIcon = Library:GetIcon(IconName)
    if LucideIcon then
        return LucideIcon
    end

    return { Url = "" }
end

function Library:Validate(Table: { [string]: any }, Template: { [string]: any }): { [string]: any }
    if typeof(Table) ~= "table" then
        return Template
    end

    for k, v in Template do
        if typeof(k) == "number" then
            continue
        end

        if typeof(v) == "table" then
            Table[k] = Library:Validate(Table[k], v)
        elseif Table[k] == nil then
            Table[k] = v
        end
    end

    return Table
end

--// Creator Functions \\--
local function FillInstance(Table: { [string]: any }, Instance: GuiObject)
    local ThemeProperties = Library.Registry[Instance] or {}

    for key, value in Table do
        if key ~= "Text" then
            local SchemeValue = GetSchemeValue(value)

            if SchemeValue or typeof(value) == "function" then
                ThemeProperties[key] = value
                value = SchemeValue or value()
            else
                ThemeProperties[key] = nil
            end
        end

        Instance[key] = value
    end

    if GetTableSize(ThemeProperties) > 0 then
        Library.Registry[Instance] = ThemeProperties
    end
end

local function New(ClassName: string, Properties: { [string]: any }): any
    if ObsIdentity and ObsSetIdentity then pcall(ObsSetIdentity, ObsIdentity) end
    local Instance = Instance.new(ClassName)

    if Templates[ClassName] then
        FillInstance(Templates[ClassName], Instance)
    end
    FillInstance(Properties, Instance)

    if Properties["Parent"] and not Properties["ZIndex"] then
        pcall(function()
            Instance.ZIndex = Properties.Parent.ZIndex
        end)
    end

    return Instance
end

--// Main Instances \\-
local function SafeParentUI(Instance: Instance, Parent: Instance | () -> Instance)
    local success, _error = pcall(function()
        if not Parent then
            Parent = CoreGui
        end

        local DestinationParent
        if typeof(Parent) == "function" then
            DestinationParent = Parent()
        else
            DestinationParent = Parent
        end

        Instance.Parent = DestinationParent
    end)

    if not (success and Instance.Parent) then
        pcall(function()
            if typeof(gethui) == "function" then
                Instance.Parent = gethui()
            end
        end)
        if not Instance.Parent then
            pcall(function()
                Instance.Parent = CoreGui
            end)
        end
    end
end

local function ParentUI(UI: Instance, SkipHiddenUI: boolean?)
    if SkipHiddenUI then
        SafeParentUI(UI, CoreGui)
        return
    end

    pcall(protectgui, UI)
    SafeParentUI(UI, gethui)
end

local function SetAlwaysOnTop(Gui: ScreenGui, Enabled: boolean)
    if not Gui then
        return
    end

    pcall(function()
        if sethiddenproperty then
            sethiddenproperty(Gui, "OnTopOfCoreBlur", Enabled)
        elseif setscriptable then
            setscriptable(Gui, "OnTopOfCoreBlur", true)
            Gui.OnTopOfCoreBlur = Enabled
            setscriptable(Gui, "OnTopOfCoreBlur", false)
        end
    end)
end

local ScreenGui = New("ScreenGui", {
    Name = "Azure",
    DisplayOrder = 998,
    ResetOnSpawn = false,
})
ParentUI(ScreenGui)
Library.ScreenGui = ScreenGui

local function ForgetCorner(Instance)
    if not Instance:IsA("UICorner") then
        return
    end
    local Idx = table.find(Library.Corners, Instance)
    if Idx then
        table.remove(Library.Corners, Idx)
    end
    Idx = table.find(Library.SpecificCorners, Instance)
    if Idx then
        table.remove(Library.SpecificCorners, Idx)
    end
end

ScreenGui.DescendantRemoving:Connect(ObsGuard(function(Instance)
    Library:RemoveFromRegistry(Instance)
    ForgetCorner(Instance)
end))

local ModalElement = New("TextButton", {
    BackgroundTransparency = 1,
    Modal = false,
    Size = UDim2.fromScale(0, 0),
    AnchorPoint = Vector2.zero,
    Text = "",
    ZIndex = -999,
    Parent = ScreenGui,
})

--// Cursor
local Cursor
local CursorCross
local InnerCross = {}
local CursorCustomImage
do
    Cursor = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(1, 1),
        Visible = false,
        ZIndex = 11000,
        Parent = ScreenGui,
    })

    CursorCross = New("Frame", {
        AnchorPoint = Vector2.new(1, 1),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(11, 11),
        Parent = Cursor,
    })

    New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "DarkColor",
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 0, 0, 3),
        ZIndex = 1,
        Parent = CursorCross,
    })
    table.insert(InnerCross, New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "WhiteColor",
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, -2, 0, 1),
        ZIndex = 2,
        Parent = CursorCross,
    }))

    New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "DarkColor",
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0, 3, 1, 0),
        ZIndex = 1,
        Parent = CursorCross,
    })
    table.insert(InnerCross, New("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = "WhiteColor",
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0, 1, 1, -2),
        ZIndex = 2,
        Parent = CursorCross,
    }))

    CursorCustomImage = New("ImageLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(20, 20),
        ZIndex = 11000,
        Visible = false,
        Parent = Cursor
    })
end

--// Notification \\--
local NotificationArea
local NotifyOrder = {}
do
    NotificationArea = New("Frame", {
        AnchorPoint = Vector2.new(1, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -6, 0, 6),
        Size = UDim2.new(0, 300, 1, -6),
        Parent = ScreenGui,
    })
    table.insert(
        Library.Scales,
        New("UIScale", {
            Scale = Library.DPIScale,
            Parent = NotificationArea,
        })
    )
end

--// Lib Functions \\--
Library.Cursor = {}

function Library.Cursor:ResetCross()
    for _, Inner in InnerCross do
        Library.Registry[Inner].BackgroundColor3 = "WhiteColor"
        Inner.BackgroundColor3 = Library.Scheme.WhiteColor
    end
end

function Library.Cursor:ResetIcon()
    CursorCross.Visible = true
    CursorCustomImage.Visible = false
    CursorCustomImage.ImageColor3 = Color3.new(1, 1, 1)
    CursorCustomImage.Size = UDim2.fromOffset(20, 20)
end

function Library.Cursor:ResetCursor()
    Library.Cursor:ResetCross()
    Library.Cursor:ResetIcon()
end

function Library.Cursor:ChangeCrossColor(Color: Color3)
    assert(typeof(Color) == "Color3", "Color3 expected.")
    for _, Inner in InnerCross do
        Inner.BackgroundColor3 = Color
        Library.Registry[Inner].BackgroundColor3 = nil
    end
end

function Library.Cursor:ChangeIcon(ImageId: string)
    if not ImageId or ImageId == "" then
        Library.Cursor:ResetIcon()
        return
    end

    local Icon = Library:GetCustomIcon(ImageId)
    assert(Icon, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

    CursorCross.Visible = false
    CursorCustomImage.Visible = true
    CursorCustomImage.Image = Icon.Url
    CursorCustomImage.ImageRectOffset = Icon.ImageRectOffset or Vector2.zero
    CursorCustomImage.ImageRectSize = Icon.ImageRectSize or Vector2.zero
end

function Library.Cursor:ChangeIconColor(Color: Color3)
    assert(typeof(Color) == "Color3", "Color3 expected.")
    CursorCustomImage.ImageColor3 = Color
end

function Library.Cursor:ChangeIconSize(Size: UDim2)
    assert(typeof(Size) == "UDim2", "UDim2 expected.")
    CursorCustomImage.Size = Size
end

--// DEPRECATED
function Library:ChangeCursorCrossColor(Color: Color3)
    do end
    Library.Cursor:ChangeCrossColor(Color)
end

--// DEPRECATED
function Library:ResetCursorCross()
    do end
    Library.Cursor:ResetCross()
end

--// DEPRECATED
function Library:ChangeCursorIcon(ImageId: string)
    do end
    Library.Cursor:ChangeIcon(ImageId)
end

--// DEPRECATED
function Library:ChangeCursorIconColor(Color: Color3)
    do end
    Library.Cursor:ChangeIconColor(Color)
end

--// DEPRECATED
function Library:ChangeCursorIconSize(Size: UDim2)
    do end
    Library.Cursor:ChangeIconSize(Size)
end

--// DEPRECATED
function Library:ResetCursorIcon()
    do end
    Library.Cursor:ResetIcon()
end

--// Colors \\--
function Library:GetBetterColor(Color: Color3, Add: number): Color3
    Add = Add * (Library.IsLightTheme and -4 or 2)
    return Color3.fromRGB(
        math.clamp(Color.R * 255 + Add, 0, 255),
        math.clamp(Color.G * 255 + Add, 0, 255),
        math.clamp(Color.B * 255 + Add, 0, 255)
    )
end

function Library:GetLighterColor(Color: Color3): Color3
    local H, S, V = Color:ToHSV()
    return Color3.fromHSV(H, math.max(0, S - 0.1), math.min(1, V + 0.1))
end

function Library:GetDarkerColor(Color: Color3): Color3
    local H, S, V = Color:ToHSV()
    return Color3.fromHSV(H, S, V / 2)
end

function Library:GetKeyString(KeyCode: Enum.KeyCode)
    if KeyCode.EnumType == Enum.KeyCode and KeyCode.Value > 33 and KeyCode.Value < 127 then
        return string.char(KeyCode.Value)
    end

    return KeyCode.Name
end

function Library:GetTextBounds(Text: string, Font: Font, Size: number, Width: number?): (number, number)
    local Params = Instance.new("GetTextBoundsParams")
    Params.Text = Text
    Params.RichText = true
    Params.Font = Font
    Params.Size = Size
    Params.Width = Width or workspace.CurrentCamera.ViewportSize.X - 32

    local Ok, Bounds = pcall(TextService.GetTextBoundsAsync, TextService, Params)
    if not Ok then
        Library.BrokenFont = true
        Params.Font = RobloxFont.fromEnum(Enum.Font.Gotham)
        Bounds = TextService:GetTextBoundsAsync(Params)
    end
    return Bounds.X, Bounds.Y
end

function Library:MouseIsOverFrame(Frame: GuiObject, Mouse: Vector2): boolean
    local AbsPos, AbsSize = Frame.AbsolutePosition, Frame.AbsoluteSize
    return Mouse.X >= AbsPos.X
        and Mouse.X <= AbsPos.X + AbsSize.X
        and Mouse.Y >= AbsPos.Y
        and Mouse.Y <= AbsPos.Y + AbsSize.Y
end

function Library:IsInsideFrame(ParentFrame: GuiObject, Frame: GuiObject)
    local GuiPos = Frame.AbsolutePosition
	local GuiSize = Frame.AbsoluteSize

	local FramePos = ParentFrame.AbsolutePosition
	local FrameSize = ParentFrame.AbsoluteSize

	return GuiPos.X >= FramePos.X
		and GuiPos.X + GuiSize.X <= FramePos.X + FrameSize.X
		and GuiPos.Y >= FramePos.Y
		and GuiPos.Y + GuiSize.Y <= FramePos.Y + FrameSize.Y
end

function Library:SafeCallback(Func: (...any) -> ...any, ...: any)
    if not (Func and typeof(Func) == "function") then
        return
    end

    local Result = table.pack(xpcall(Func, function(Error)
        Library.LastCallbackError = debug.traceback(Error, 2)
        ObsReportError("callback", tostring(Error), Library.LastCallbackError)
        if Library.NotifyOnError and Library.Notify then
            Library:Notify(Error)
        end

        return Error
    end, ...))

    if not Result[1] then
        return nil
    end

    return table.unpack(Result, 2, Result.n)
end

function GetOverlappingDraggable(UI: GuiObject, TargetPos: Vector2?)
    local Pos1 = TargetPos or UI.AbsolutePosition
    local Size1 = UI.AbsoluteSize
    
    for _, Other in ipairs(Library.DraggableElements) do
        if Other == UI or not Other.Visible or not Other.Parent then
            continue
        end

        local Pos2 = Other.AbsolutePosition
        local Size2 = Other.AbsoluteSize
        
        if Pos1.X < Pos2.X + Size2.X and
            Pos1.X + Size1.X > Pos2.X and
            Pos1.Y < Pos2.Y + Size2.Y and
            Pos1.Y + Size1.Y > Pos2.Y then
            return Other
        end
    end
    
    return nil
end

function GetNonOverlappingPosition(UI: GuiObject, StartPos: UDim2?)
    local ScreenSize = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)) - Vector2.new(100, 100)
    local Start = StartPos and Vector2.new(StartPos.X.Offset, StartPos.Y.Offset) or Vector2.new(6, 6)
    local Padding = 6
    
    local CurrentX = Start.X
    local CurrentY = Start.Y
    
    local Size = UI.AbsoluteSize
    if Size.X == 0 and Size.Y == 0 then
        RunService.RenderStepped:Wait()
        Size = UI.AbsoluteSize
    end
    
    if Size.X == 0 then Size = Vector2.new(150, 40) end

    local MaxXInColumn = Size.X

    while true do
        local Obstacle = GetOverlappingDraggable(UI, Vector2.new(CurrentX, CurrentY))
        if not Obstacle then
            break
        end
        
        if Obstacle.AbsoluteSize.X > MaxXInColumn then
            MaxXInColumn = Obstacle.AbsoluteSize.X
        end
        
        local NextY = Obstacle.AbsolutePosition.Y + Obstacle.AbsoluteSize.Y + Padding
        if NextY + Size.Y > ScreenSize.Y - Padding then
            local NextX = CurrentX + MaxXInColumn + Padding
            
            if NextX + Size.X > ScreenSize.X - Padding then
                break
            end
            
            CurrentY = Start.Y
            CurrentX = NextX
            MaxXInColumn = Size.X
        else
            CurrentY = NextY
        end
    end
    
    return UDim2.fromOffset(CurrentX, CurrentY)
end

function PositionDraggable(UI: GuiObject, StartPos: UDim2?)
    UI.Position = GetNonOverlappingPosition(UI, StartPos)
end

function Library:ClampToScreen(UI: GuiObject)
    if not (UI and UI.Parent and ScreenGui and ScreenGui.Parent) then
        return
    end

    local Screen = ScreenGui.AbsoluteSize
    if Screen.X <= 0 or Screen.Y <= 0 then
        return
    end

    local Pos = UI.AbsolutePosition - ScreenGui.AbsolutePosition
    local Size = UI.AbsoluteSize
    local Margin = 4
    local DX, DY = 0, 0
    local TopInset = 0
    if not ScreenGui.IgnoreGuiInset then
        pcall(function()
            TopInset = game:GetService("GuiService"):GetGuiInset().Y
        end)
    end
    local MinY = Margin - TopInset

    if Size.X + Margin * 2 <= Screen.X then
        if Pos.X < Margin then
            DX = Margin - Pos.X
        elseif Pos.X + Size.X > Screen.X - Margin then
            DX = (Screen.X - Margin) - (Pos.X + Size.X)
        end
    else
        DX = Margin - Pos.X
    end

    if Size.Y + Margin * 2 <= Screen.Y + TopInset then
        if Pos.Y < MinY then
            DY = MinY - Pos.Y
        elseif Pos.Y + Size.Y > Screen.Y - Margin then
            DY = (Screen.Y - Margin) - (Pos.Y + Size.Y)
        end
    else
        DY = MinY - Pos.Y
    end

    if math.abs(DX) >= 0.5 or math.abs(DY) >= 0.5 then
        Library:SpringStop(UI, "Position")
        UI.Position = UI.Position + UDim2.fromOffset(math.round(DX), math.round(DY))
    end
end

function Library:DragBounds(UI: GuiObject)
    local Screen = ScreenGui.AbsoluteSize
    local Origin = (UI.AbsolutePosition - ScreenGui.AbsolutePosition) - Vector2.new(UI.Position.X.Offset, UI.Position.Y.Offset)
    local Size = UI.AbsoluteSize
    local Margin = 4
    local TopInset = 0
    if not ScreenGui.IgnoreGuiInset then
        pcall(function()
            TopInset = game:GetService("GuiService"):GetGuiInset().Y
        end)
    end
    local MinY = Margin - TopInset

    local MinX = Margin - Origin.X
    local MaxX = math.max(MinX, Screen.X - Margin - Size.X - Origin.X)
    local MinOffY = MinY - Origin.Y
    local MaxOffY = math.max(MinOffY, Screen.Y - Margin - Size.Y - Origin.Y)

    return function(Point: Vector2): Vector2
        return Vector2.new(math.clamp(Point.X, MinX, MaxX), math.clamp(Point.Y, MinOffY, MaxOffY))
    end
end

function Library:EnterDragShell(Shell: GuiObject)
    if not (Shell and Shell.Parent) then
        return function() end
    end
    local Locked = nil
    if Shell.AutomaticSize ~= Enum.AutomaticSize.None then
        local Scale = 1
        for _, Child in ipairs(Shell:GetChildren()) do
            if Child:IsA("UIScale") then
                Scale *= Child.Scale
            end
        end
        local Absolute = Shell.AbsoluteSize
        Locked = { Auto = Shell.AutomaticSize, Size = Shell.Size }
        Shell.AutomaticSize = Enum.AutomaticSize.None
        Shell.Size = UDim2.fromOffset(Absolute.X / math.max(Scale, 0.01), Absolute.Y / math.max(Scale, 0.01))
    end
    local Hidden = {}
    for _, Part in ipairs(Shell:GetChildren()) do
        if Part:IsA("GuiObject") and Part.Visible then
            Part.Visible = false
            table.insert(Hidden, Part)
        end
    end
    local Saved = { Background = Shell.BackgroundTransparency }
    if Shell:IsA("TextLabel") or Shell:IsA("TextButton") then
        Saved.Text = Shell.TextTransparency
        Shell.TextTransparency = 1
    end
    if Shell:IsA("ImageLabel") or Shell:IsA("ImageButton") then
        Saved.Image = Shell.ImageTransparency
        Shell.ImageTransparency = 1
    end
    Shell.BackgroundTransparency = math.max(Saved.Background, 0.35)
    local Restored = false
    return function()
        if Restored then
            return
        end
        Restored = true
        for _, Part in ipairs(Hidden) do
            if Part.Parent then
                Part.Visible = true
            end
        end
        if Shell.Parent then
            if Locked then
                Shell.Size = Locked.Size
                Shell.AutomaticSize = Locked.Auto
            end
            Shell.BackgroundTransparency = Saved.Background
            if Saved.Text then
                Shell.TextTransparency = Saved.Text
            end
            if Saved.Image then
                Shell.ImageTransparency = Saved.Image
            end
        end
    end
end

function Library:CreateGlide(UI: GuiObject, Apply, OnDone)
    local Glide = {
        Held = false,
        Target = Vector2.zero,
        Current = Vector2.zero,
        Velocity = Vector2.zero,
        History = {},
        Connection = nil,
    }

    local function Finish()
        if Glide.Connection then
            Glide.Connection:Disconnect()
            Glide.Connection = nil
        end
        Glide.Velocity = Vector2.zero
        if OnDone then
            OnDone()
        end
    end

    local function Step(Delta)
        if Library.Unloaded or not (UI and UI.Parent) then
            Finish()
            return
        end

        Delta = math.clamp(tonumber(Delta) or 0.016, 0.001, 0.05)

        if Glide.Held then
            return
        end

        if not Glide.Held then
            Glide.Velocity *= math.exp(-Delta * 8)
            Glide.Target += Glide.Velocity * Delta
        end

        if Glide.Held then
            Glide.Current = Glide.Target
        else
            Glide.Current = Glide.Current:Lerp(Glide.Target, 1 - math.exp(-Delta * 16))
        end

        local Actual = Apply(Glide.Current)
        if Actual then
            local Fix = Actual - Glide.Current
            if math.abs(Fix.X) > 1.5 then
                Glide.Velocity = Vector2.new(0, Glide.Velocity.Y)
                if not Glide.Held then
                    Glide.Target = Vector2.new(Actual.X, Glide.Target.Y)
                end
                Glide.Current = Vector2.new(Actual.X, Glide.Current.Y)
            end
            if math.abs(Fix.Y) > 1.5 then
                Glide.Velocity = Vector2.new(Glide.Velocity.X, 0)
                if not Glide.Held then
                    Glide.Target = Vector2.new(Glide.Target.X, Actual.Y)
                end
                Glide.Current = Vector2.new(Glide.Current.X, Actual.Y)
            end
        end

        if not Glide.Held and Glide.Velocity.Magnitude < 6 and (Glide.Target - Glide.Current).Magnitude < 0.5 then
            Apply(Glide.Target)
            Finish()
        end
    end

    local function Run()
        if not Glide.Connection then
            Glide.Connection = RunService.RenderStepped:Connect(ObsGuard(Step))
        end
    end

    function Glide:Hold(Point: Vector2)
        Glide.Held = true
        Glide.Current = Point
        Glide.Target = Point
        Glide.Velocity = Vector2.zero
        Glide.History = { { os.clock(), Point } }
    end

    function Glide:Move(Target: Vector2)
        local Now = os.clock()
        Glide.Target = Target
        if Glide.Held and UI and UI.Parent then
            local Actual = Apply(Target)
            Glide.Current = Actual or Target
        end
        table.insert(Glide.History, { Now, Target })
        while #Glide.History > 2 and Now - Glide.History[1][1] > 0.09 do
            table.remove(Glide.History, 1)
        end
        if not Glide.Held then
            Run()
        end
    end

    function Glide:Release()
        Glide.Held = false
        Glide.Velocity = Vector2.zero
        Glide.Target = Glide.Current
        Glide.History = {}
        Run()
    end

    function Glide:Stop()
        Glide.Held = false
        Finish()
    end

    return Glide
end

function Library:MakeDraggable(UI: GuiObject, DragFrame: GuiObject, IgnoreToggled: boolean?, IsMainWindow: boolean?)
    if not UI or not DragFrame then return end
    local StartPos
    local FramePos
    local Dragging = false
    local Changed
    local DragTween
    local InputBegan
    local InputChanged
    local GlideScale = UI.Position
    local HiddenParts = nil

    local Bounds = nil
    local ShellTransparency = nil

    local function HideContents()
        if HiddenParts then
            return
        end
        if IsMainWindow then
            Library:CloseCurrentMenu()
        end
        local Shell = IsMainWindow and Library.DragShell or UI
        HiddenParts = Library:EnterDragShell(Shell)
    end

    local function ShowContents()
        if not HiddenParts then
            return
        end
        local Restore = HiddenParts
        HiddenParts = nil
        Restore()
    end

    local Glide = Library:CreateGlide(UI, function(Point)
        local Clamped = Bounds and Bounds(Point) or Point
        UI.Position = UDim2.new(GlideScale.X.Scale, math.round(Clamped.X), GlideScale.Y.Scale, math.round(Clamped.Y))
        return Clamped
    end, function()
        if not Dragging and UI and UI.Parent then
            UI:SetAttribute("Dragging", nil)
            Library:ClampToScreen(UI)
        end
        if not Dragging then
            ShowContents()
        end
    end)

    local function StopDrag()
        local WasDragging = Dragging
        Dragging = false
        if WasDragging then
            Glide:Release()
        end
        if Changed and Changed.Connected then
            Changed:Disconnect()
        end
        Changed = nil
        if InputChanged and InputChanged.Connected then
            InputChanged:Disconnect()
        end
        InputChanged = nil
    end

    local function OnMove(Input: InputObject)
        if
            (not IgnoreToggled and not Library.Toggled)
            or (IsMainWindow and Library.CantDragForced)
            or not (ScreenGui and ScreenGui.Parent)
            or not UI
        then
            StopDrag()
            return
        end

        if Dragging and Input.UserInputType == Enum.UserInputType.MouseMovement and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
            StopDrag()
            return
        end

        if Dragging and IsHoverInput(Input) then
            local Delta = Input.Position - StartPos
            if DragTween then
                DragTween:Cancel()
                DragTween = nil
            end
            if not HiddenParts and Delta.Magnitude > 3 then
                HideContents()
            end
            Glide:Move(Vector2.new(FramePos.X.Offset + Delta.X, FramePos.Y.Offset + Delta.Y))
        end
    end

    if not UI:GetAttribute("ObsClampHooked") then
        UI:SetAttribute("ObsClampHooked", true)
        local function Reclamp()
            if UI and UI.Parent and UI.Visible and not UI:GetAttribute("Dragging") and UI:GetAttribute("RecedeHomePosition") == nil then
                Library:ClampToScreen(UI)
            end
        end
        Library:GiveSignal(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ObsGuard(Reclamp)))
        Library:GiveSignal(UI:GetPropertyChangedSignal("Visible"):Connect(ObsGuard(function()
            task.defer(Reclamp)
        end)))
        task.delay(1, function()
            pcall(Reclamp)
        end)
    end

    InputBegan = DragFrame.InputBegan:Connect(ObsGuard(function(Input: InputObject)
        if not IsClickInput(Input) or IsMainWindow and Library.CantDragForced then
            return
        end
        if not UI or UI:GetAttribute("DragLocked") then return end

        StopDrag()
        Library:SpringStop(UI, "Position")
        StartPos = Input.Position
        FramePos = UI.Position
        GlideScale = FramePos
        Bounds = Library:DragBounds(UI)
        Dragging = true
        UI:SetAttribute("Dragging", true)
        Glide:Hold(Vector2.new(FramePos.X.Offset, FramePos.Y.Offset))
        InputChanged = UserInputService.InputChanged:Connect(OnMove)

        Changed = Input.Changed:Connect(ObsGuard(function()
            if Input.UserInputState ~= Enum.UserInputState.End and Input.UserInputState ~= Enum.UserInputState.Cancel then
                return
            end
            StopDrag()
        end))
    end))

    Library:GiveSignal(UserInputService.WindowFocusReleased:Connect(ObsGuard(function()
        if Dragging then
            StopDrag()
        end
    end)))

    Library:GiveSignal(InputBegan)

    UI.Destroying:Once(ObsGuard(function()
        StopDrag()
        Glide:Stop()
        ShowContents()

        if InputBegan and InputBegan.Connected then
            InputBegan:Disconnect()
        end

        local IdxBegan = table.find(Library.Signals, InputBegan)
        if IdxBegan then
            table.remove(Library.Signals, IdxBegan)
        end
    end))
end

function Library:MakeResizable(UI: GuiObject, DragFrame: GuiObject, Callback: () -> ()?)
    local StartPos
    local FrameSize
    local Dragging = false
    local Changed
    local InputBegan
    local InputChanged

    local function StopDrag()
        Dragging = false
        if Changed and Changed.Connected then
            Changed:Disconnect()
        end
        Changed = nil
        if InputChanged and InputChanged.Connected then
            InputChanged:Disconnect()
        end
        InputChanged = nil
    end

    local function OnMove(Input: InputObject)
        if not UI.Visible or not (ScreenGui and ScreenGui.Parent) then
            StopDrag()
            return
        end

        if Dragging and IsHoverInput(Input) then
            local Delta = Input.Position - StartPos
            UI.Size = UDim2.new(
                FrameSize.X.Scale,
                math.clamp(FrameSize.X.Offset + Delta.X, Library.MinSize.X, math.huge),
                FrameSize.Y.Scale,
                math.clamp(FrameSize.Y.Offset + Delta.Y, Library.MinSize.Y, math.huge)
            )
            if Callback then
                Library:SafeCallback(Callback)
            end
        end
    end

    InputBegan = DragFrame.InputBegan:Connect(ObsGuard(function(Input: InputObject)
        if not IsClickInput(Input) then
            return
        end

        StartPos = Input.Position
        FrameSize = UI.Size
        StopDrag()
        Dragging = true
        InputChanged = UserInputService.InputChanged:Connect(OnMove)

        Changed = Input.Changed:Connect(ObsGuard(function()
            if Input.UserInputState ~= Enum.UserInputState.End then
                return
            end
            StopDrag()
        end))
    end))

    Library:GiveSignal(InputBegan)

    UI.Destroying:Once(ObsGuard(function()
        StopDrag()

        if InputBegan and InputBegan.Connected then
            InputBegan:Disconnect()
        end

        local IdxBegan = table.find(Library.Signals, InputBegan)
        if IdxBegan then
            table.remove(Library.Signals, IdxBegan)
        end
    end))
end

function Library:MakeCover(Holder: GuiObject, Place: string)
    local Pos = Places[Place] or { 0, 0 }
    local Size = Sizes[Place] or { 1, 0.5 }

    local Cover = New("Frame", {
        AnchorPoint = Vector2.new(Pos[1], Pos[2]),
        BackgroundColor3 = Holder.BackgroundColor3,
        Position = UDim2.fromScale(Pos[1], Pos[2]),
        Size = UDim2.fromScale(Size[1], Size[2]),
        Parent = Holder,
    })

    return Cover
end

function Library:MakeLine(Frame: GuiObject, Info)
    local Line = New("Frame", {
        AnchorPoint = Info.AnchorPoint or Vector2.zero,
        BackgroundColor3 = "OutlineColor",
        Position = Info.Position,
        Size = Info.Size,
        ZIndex = Info.ZIndex or Frame.ZIndex,
        Parent = Frame,
    })

    return Line
end

function Library:AddOutline(Frame: GuiObject)
    local OutlineStroke = New("UIStroke", {
        Color = "OutlineColor",
        Thickness = 1,
        ZIndex = 2,
        Parent = Frame,
    })
    local ShadowStroke = New("UIStroke", {
        Color = "DarkColor",
        Thickness = 1.5,
        ZIndex = 1,
        Parent = Frame,
    })
    return OutlineStroke, ShadowStroke
end

-- Soft neon accent glow: stacked accent UIStrokes (thin+brighter -> thick+fainter) that
-- fake a soft outer glow. No animation; "AccentColor" scheme key keeps it synced to accent.
Library.Glows = {}
function Library:AddGlow(Frame: GuiObject)
    if not Frame then return end
    -- Smooth soft glow: many thin accent strokes, gradually increasing thickness +
    -- transparency, so they BLEND into one soft halo. (3 far-spaced layers rendered as
    -- distinct lines instead of a glow.) Inner = brighter, outer = fades out.
    local LAYERS = Library.IsMobile and 3 or 5
    for i = 1, LAYERS do
        local frac = i / LAYERS
        local Glow = New("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Color = "AccentColor",
            Thickness = frac * 8,
            Transparency = 0.70 + 0.26 * frac,
            ZIndex = 0,
            Parent = Frame,
        })
        table.insert(Library.Glows, Glow)
    end
end

function Library:DockToggleButton()
    local TB, WM = self.ToggleButton, self.WatermarkContainer
    if not TB or not TB.Button or not WM then return end
    if self._ToggleDock then
        for _, c in self._ToggleDock do pcall(function() c:Disconnect() end) end
    end
    local Btn = TB.Button
    local Dock = {}
    local Placed = nil
    self._ToggleDock = Dock

    local function undock()
        for _, c in Dock do pcall(function() c:Disconnect() end) end
        if self._ToggleDock == Dock then
            self._ToggleDock = nil
        end
    end

    local function place()
        if self._ToggleDock ~= Dock then return end
        if not WM.Parent or not Btn.Parent then return end
        if Btn:GetAttribute("Dragging") then return end
        Btn.AnchorPoint = Vector2.new(0, 0.5)
        local origin = Btn.Parent.AbsolutePosition
        local x = WM.AbsolutePosition.X + WM.AbsoluteSize.X + 8 - origin.X
        local y = WM.AbsolutePosition.Y + WM.AbsoluteSize.Y / 2 - origin.Y
        Placed = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
        pcall(function() Library:SpringStop(Btn, "Position") end)
        Btn.Position = Placed
    end

    table.insert(Dock, WM:GetPropertyChangedSignal("AbsolutePosition"):Connect(ObsGuard(place)))
    table.insert(Dock, WM:GetPropertyChangedSignal("AbsoluteSize"):Connect(ObsGuard(place)))
    table.insert(Dock, Btn:GetPropertyChangedSignal("Position"):Connect(ObsGuard(function()
        if Btn:GetAttribute("Dragging") and Placed and Btn.Position ~= Placed then
            undock()
        end
    end)))
    table.insert(Dock, Btn:GetAttributeChangedSignal("Dragging"):Connect(ObsGuard(function()
        if not Btn:GetAttribute("Dragging") then
            place()
        end
    end)))
    place()
    task.delay(0.1, place)
    task.delay(0.5, place)
end

function Library:AddBlank(Frame: GuiObject, Size: UDim2)
    return New("Frame", {
        BackgroundTransparency = 1,
        Size = Size or UDim2.fromScale(0, 0),
        Parent = Frame,
    })
end

--// Animations \\--
local TransparencyCache = {}
local ActiveTabTweens = setmetatable({}, { __mode = "k" })

function Library:PlayTabAnimation(Tab, Showing: boolean, OnComplete: (() -> ())?)
    if type(Tab) ~= "table" or not Tab.Container then
        if OnComplete then
            OnComplete()
        end

        return
    end

    local TabContainer = Tab.Container :: Frame
    local Existing = ActiveTabTweens[TabContainer]
    if Existing then
        StopTween(Existing, true)
        ActiveTabTweens[TabContainer] = nil
    end

    Library:SpringStop(TabContainer, "Position")
    local BaseZIndex = TabContainer.ZIndex
    if not (Library.Animations and Library.Animations.TabSwitch) then
        TabContainer.Visible = Showing
        TabContainer.Position = UDim2.fromScale(0, 0)
        TabContainer.ZIndex = BaseZIndex

        if OnComplete then
            OnComplete()
        end

        return
    end

    if Showing then
        local TweenInfo = Library.TabTransitionInfo or TweenInfo.new(0.18, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
        local Rise = tonumber(Library.TabRiseOffset) or 10

        local Fade = TabContainer:FindFirstChild("TabFade")
        if not Fade then
            Fade = New("Frame", {
                Name = "TabFade",
                BackgroundColor3 = "BackgroundColor",
                BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 1),
                Visible = false,
                ZIndex = BaseZIndex + 40,
                Parent = TabContainer,
            })
        end
        local ExistingFade = ActiveTabTweens[Fade]
        if ExistingFade then
            StopTween(ExistingFade, true)
            ActiveTabTweens[Fade] = nil
        end

        Fade.BackgroundTransparency = 0
        Fade.Visible = true
        TabContainer.ZIndex = BaseZIndex + 1
        TabContainer.Position = UDim2.fromOffset(0, Rise)
        TabContainer.Visible = true

        local Tween = TweenService:Create(TabContainer, TweenInfo, {
            Position = UDim2.fromScale(0, 0)
        })
        local FadeTween = TweenService:Create(Fade, TweenInfo, {
            BackgroundTransparency = 1
        })

        ActiveTabTweens[TabContainer] = Tween
        ActiveTabTweens[Fade] = FadeTween
        FadeTween:Play()
        Library:Spring(TabContainer, "Position", UDim2.fromScale(0, 0), 30, 0.78)

        FadeTween.Completed:Once(ObsGuard(function(PlaybackState)
            if ActiveTabTweens[TabContainer] == Tween then
                ActiveTabTweens[TabContainer] = nil
            end
            if ActiveTabTweens[Fade] == FadeTween then
                ActiveTabTweens[Fade] = nil
            end

            if PlaybackState == Enum.PlaybackState.Cancelled then
                return
            end

            Fade.Visible = false
            TabContainer.ZIndex = BaseZIndex
            if OnComplete then
                OnComplete()
            end
        end))
    else
        local Fade = TabContainer:FindFirstChild("TabFade")
        if Fade then
            local ExistingFade = ActiveTabTweens[Fade]
            if ExistingFade then
                StopTween(ExistingFade, true)
                ActiveTabTweens[Fade] = nil
            end
            Fade.Visible = false
        end
        TabContainer.Visible = false
        TabContainer.Position = UDim2.fromScale(0, 0)
        TabContainer.ZIndex = BaseZIndex

        if OnComplete then
            OnComplete()
        end
    end
end

--// Deprecated \\--
function Library:MakeOutline(Frame: GuiObject, Corner: number?, ZIndex: number?)
    do end
    local Holder = New("Frame", {
        BackgroundColor3 = "DarkColor",
        Position = UDim2.fromOffset(-2, -2),
        Size = UDim2.new(1, 4, 1, 4),
        ZIndex = ZIndex,
        Parent = Frame,
    })

    local Outline = New("Frame", {
        BackgroundColor3 = "OutlineColor",
        Position = UDim2.fromOffset(1, 1),
        Size = UDim2.new(1, -2, 1, -2),
        ZIndex = ZIndex,
        Parent = Holder,
    })

    if Corner and Corner > 0 then
        New("UICorner", {
            CornerRadius = UDim.new(0, Corner + 1),
            Parent = Holder,
        })
        New("UICorner", {
            CornerRadius = UDim.new(0, Corner),
            Parent = Outline,
        })
    end

    return Holder, Outline
end

function Library:AddDraggableLabel(...)
    local Params = select(1, ...)
    local Text
    local Icon
    local IconPosition = "left"

    if typeof(Params) == "table" then
        Text = Params.Text
        Icon = Params.Icon
        IconPosition = Params.IconPosition or "left"
    elseif typeof(Params) == "string" then
        Text = Params
        Icon = select(2, ...)
        IconPosition = select(3, ...) or "left"
    end

    if typeof(IconPosition) ~= "string" then
        IconPosition = "left"
    end

    IconPosition = string.lower(IconPosition)
    assert(IconPosition == "left" or IconPosition == "right", "Icon Position needs to be either 'left' or 'right'.")

    local DraggableLabel = {
        Connections = {},
        Destroyed = false
    }

    local IconImage
    local Label = New("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundColor3 = "BackgroundColor",
        Size = UDim2.fromOffset(0, 0),
        Position = UDim2.fromOffset(6, 6),
        Text = Text,
        TextSize = 15,
        ZIndex = 10,
        Parent = ScreenGui,
    })

    table.insert(
        Library.Corners, 
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = Label,
        })
    )

    local Padding = New("UIPadding", {
        PaddingBottom = UDim.new(0, 6),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 6),
        Parent = Label,
    })
    table.insert(
        Library.Scales,
        New("UIScale", {
            Scale = Library.DPIScale,
            Parent = Label,
        })
    )

    Library:AddOutline(Label)
    Library:AddGlow(Label)
    Library:MakeDraggable(Label, Label, true)
    DraggableLabel.Frame = Label

    function DraggableLabel:SetText(Text: string)
        Label.Text = Text
    end

    function DraggableLabel:SetIcon(NewIcon: string)
        Icon = NewIcon

        local IsNotEmpty = Icon and Trim(tostring(Icon)) ~= ""
        if IsNotEmpty then
            local CustomIcon = Library:GetCustomIcon(Icon)
            assert(CustomIcon, "Icon must be a valid Roblox asset or a valid URL or a valid lucide icon.")

            IconImage = IconImage or New("ImageLabel", {
                BackgroundTransparency = 1,
                ImageColor3 = "FontColor",
                Size = UDim2.fromOffset(16, 16),
                ZIndex = 11,
                Parent = Label,
            })

            IconImage.Image = CustomIcon.Url
            IconImage.ImageRectOffset = CustomIcon.ImageRectOffset or Vector2.zero
            IconImage.ImageRectSize = CustomIcon.ImageRectSize or Vector2.zero
        end

        if IconImage then IconImage.Visible = IsNotEmpty end
        DraggableLabel:SetIconPosition(IconPosition)
    end

    function DraggableLabel:SetIconPosition(NewPosition: string)
        IconPosition = string.lower(NewPosition)
        assert(IconPosition == "left" or IconPosition == "right", "Icon Position needs to be either 'left' or 'right'.")

        local IsNotEmpty = Icon and Trim(tostring(Icon)) ~= ""
        Padding.PaddingLeft = UDim.new(0, (IsNotEmpty and IconPosition == "left") and 34 or 12)
        Padding.PaddingRight = UDim.new(0, (IsNotEmpty and IconPosition == "right") and 34 or 12)

        if IconImage then
            if IconPosition == "left" then
                IconImage.AnchorPoint = Vector2.new(0, 0.5)
                IconImage.Position = UDim2.new(0, -22, 0.5, 0)
            else
                IconImage.AnchorPoint = Vector2.new(1, 0.5)
                IconImage.Position = UDim2.new(1, 22, 0.5, 0)
            end
        end
    end

    function DraggableLabel:SetVisible(Visible: boolean)
        Label.Visible = Visible
    end
    
    DraggableLabel:SetIcon(Icon)
    DraggableLabel.Label = Label

    if not table.find(Library.DraggableElements, Label) then
        table.insert(Library.DraggableElements, Label)
    end

    PositionDraggable(Label, Label.Position)

    function DraggableLabel:Destroy()
        DraggableLabel.Destroyed = true

        if DraggableLabel.Connections then
            for _, connection in DraggableLabel.Connections do
                connection:Disconnect()
            end
        end

        local ElemIdx = table.find(Library.DraggableElements, Label)
        if ElemIdx then
            table.remove(Library.DraggableElements, ElemIdx)
        end

        if Label then
            Label:Destroy()
        end
    end

    return DraggableLabel
end

--// TVL Watermark (FPS + ping + inline icon) — call once from a script, self-updating \\--
--// Icon-to-divider spacing is computed automatically from the live font/text size and
--// icon footprint via TextService, so callers never hand-tune space characters again.
function Library:CreateWatermark(...)
    local Params = select(1, ...)
    local Title, IconAsset
    if typeof(Params) == "table" then
        Title = Params.Title or "Watermark"
        IconAsset = Params.Icon
    else
        Title = tostring(Params or "Watermark")
        IconAsset = select(3, ...)
    end
    Title = tostring(Title)

    local Stats = game:GetService("Stats")
    local DL = Library:AddDraggableLabel("")
    local Watermark = { DraggableLabel = DL, Destroyed = false }
    local Holder = DL.Label
    Holder.Text = ""
    Holder.RichText = false

    local Column = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 0),
        Parent = Holder,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 1),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = Column,
    })

    local Row = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundTransparency = 1,
        LayoutOrder = 1,
        Size = UDim2.fromOffset(0, 20),
        Parent = Column,
    })
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = Row,
    })

    local Order = 0
    local function NextOrder()
        Order += 1
        return Order
    end

    if IconAsset ~= nil and tostring(IconAsset) ~= "" then
        local Source = tonumber(IconAsset) and ("rbxassetid://" .. tostring(IconAsset)) or tostring(IconAsset)
        local Parsed = nil
        pcall(function()
            Parsed = Library:GetCustomIcon(Source)
        end)
        local Logo = New("ImageLabel", {
            Name = "WatermarkLogo",
            BackgroundTransparency = 1,
            Image = Parsed and Parsed.Url or Source,
            ImageColor3 = Color3.new(1, 1, 1),
            ImageRectOffset = Parsed and Parsed.ImageRectOffset or Vector2.zero,
            ImageRectSize = Parsed and Parsed.ImageRectSize or Vector2.zero,
            LayoutOrder = NextOrder(),
            ScaleType = Enum.ScaleType.Fit,
            Size = UDim2.fromOffset(19, 19),
            Parent = Row,
        })
        pcall(function()
            Library:AddSharedGradient(Logo, {})
        end)
    end

    local Brand = New("TextLabel", {
        Name = "WatermarkBrand",
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        LayoutOrder = NextOrder(),
        Size = UDim2.fromOffset(0, 20),
        Text = Title,
        TextSize = 15,
        Parent = Row,
    })
    pcall(function()
        Library:RemoveFromRegistry(Brand)
        Brand.TextColor3 = Color3.new(1, 1, 1)
        local Entry = Library:AddSharedGradient(Brand, { isRgb = false })
        if Entry then
            Entry.alwaysUpdate = true
        end
    end)

    local function AddDivider()
        New("Frame", {
            BackgroundColor3 = "FontColor",
            BackgroundTransparency = 0.82,
            BorderSizePixel = 0,
            LayoutOrder = NextOrder(),
            Size = UDim2.fromOffset(1, 14),
            Parent = Row,
        })
    end

    local function AddStat(Unit)
        local Group = New("Frame", {
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            LayoutOrder = NextOrder(),
            Size = UDim2.fromOffset(0, 20),
            Parent = Row,
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Parent = Group,
        })

        local Dot = New("Frame", {
            BackgroundColor3 = Color3.fromRGB(74, 222, 128),
            BorderSizePixel = 0,
            LayoutOrder = 1,
            Size = UDim2.fromOffset(6, 6),
            Parent = Group,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = Dot,
        })
        local Halo = New("UIStroke", {
            Color = Color3.fromRGB(74, 222, 128),
            Thickness = 2,
            Transparency = 0.75,
            Parent = Dot,
        })

        local Value = New("TextLabel", {
            BackgroundTransparency = 1,
            LayoutOrder = 2,
            Size = UDim2.fromOffset(0, 20),
            Text = "0",
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = Group,
        })
        pcall(function()
            Library:RemoveFromRegistry(Value)
        end)
        Value.TextColor3 = Color3.fromRGB(74, 222, 128)
        local DigitCount, HeldWidth = nil, 0
        local function FitValue()
            local Count = #Value.Text
            local Width = math.ceil(Value.TextBounds.X)
            if Count == DigitCount then
                if Width <= HeldWidth then
                    return
                end
            else
                DigitCount = Count
            end
            HeldWidth = Width
            if Value.Size.X.Offset == 0 then
                Value.Size = UDim2.fromOffset(Width, 20)
            else
                Library:Spring(Value, "Size", UDim2.fromOffset(Width, 20), 24, 0.9)
            end
        end
        Value:GetPropertyChangedSignal("TextBounds"):Connect(ObsGuard(FitValue))
        task.defer(FitValue)

        New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            LayoutOrder = 3,
            Size = UDim2.fromOffset(0, 20),
            Text = Unit,
            TextSize = 12,
            TextTransparency = 0.45,
            Parent = Group,
        })

        return { Dot = Dot, Halo = Halo, Value = Value, Shade = nil }
    end

    AddDivider()
    local FpsStat = AddStat("FPS")
    AddDivider()
    local PingStat = AddStat("ms")

    local Extra = New("TextLabel", {
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        LayoutOrder = 2,
        RichText = true,
        Size = UDim2.fromOffset(0, 16),
        Text = "",
        TextSize = 13,
        TextTransparency = 0.3,
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = false,
        Parent = Column,
    })

    local Good = Color3.fromRGB(74, 222, 128)
    local Okay = Color3.fromRGB(250, 204, 21)
    local Bad = Color3.fromRGB(248, 113, 113)
    local ShadeInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

    local function Paint(Stat, Number, Shade)
        Stat.Target = Number
        if Stat.Shade ~= Shade then
            Stat.Shade = Shade
            TweenService:Create(Stat.Value, ShadeInfo, { TextColor3 = Shade }):Play()
            TweenService:Create(Stat.Dot, ShadeInfo, { BackgroundColor3 = Shade }):Play()
            TweenService:Create(Stat.Halo, ShadeInfo, { Color = Shade }):Play()
        end
    end

    local FrameCount, FrameTimer, Fps = 0, os.clock(), 60
    local ExtraProvider = nil
    local UserVisible = true

    local function Refresh()
        local Ping = 0
        pcall(function()
            Ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue())
        end)
        Paint(FpsStat, Fps, Fps >= 55 and Good or Fps >= 30 and Okay or Bad)
        Paint(PingStat, Ping, Ping <= 80 and Good or Ping <= 150 and Okay or Bad)

        local Line = nil
        if ExtraProvider then
            local Ok, Result = pcall(ExtraProvider)
            if Ok and typeof(Result) == "string" and Result ~= "" then
                Line = Result
            end
        end
        Extra.Text = Line or ""
        Extra.Visible = Line ~= nil
    end

    local StatList = { FpsStat, PingStat }
    local Clock = 0
    local Connection
    local HaloTick = false
    local HaloAt = 0
    Connection = RunService.Heartbeat:Connect(ObsGuard(function(Delta)
        if Library.Unloaded or not Holder.Parent then
            if Connection then
                Connection:Disconnect()
            end
            return
        end
        Delta = math.min(tonumber(Delta) or 0.016, 0.1)
        Clock += Delta
        FrameCount += 1
        local Now = os.clock()
        if Now - FrameTimer >= 1 then
            Fps = math.floor(FrameCount / (Now - FrameTimer) + 0.5)
            FrameCount, FrameTimer = 0, Now
            pcall(Refresh)
        end

        if not Holder.Visible then
            return
        end

        local Ease = 1 - math.exp(-Delta * 9)
        HaloTick = Clock - HaloAt >= 1 / 20
        if HaloTick then
            HaloAt = Clock
        end
        for Index, Stat in ipairs(StatList) do
            if Stat.Target then
                Stat.Shown = Stat.Shown and (Stat.Shown + (Stat.Target - Stat.Shown) * Ease) or Stat.Target
                if math.abs(Stat.Target - Stat.Shown) < 0.5 then
                    Stat.Shown = Stat.Target
                end
                local Text = tostring(math.floor(Stat.Shown + 0.5))
                if Stat.Value.Text ~= Text and (Stat.Shown == Stat.Target or Clock - (Stat.WroteAt or 0) >= 1 / 30) then
                    Stat.WroteAt = Clock
                    Stat.Value.Text = Text
                end
            end
            if HaloTick then
                local Wave = math.sin(Clock * 2.6 + Index * 1.3)
                Stat.Halo.Transparency = 0.62 + 0.25 * Wave
                Stat.Halo.Thickness = 2.2 + 0.8 * Wave
            end
        end
    end))
    if DL.Connections then
        table.insert(DL.Connections, Connection)
    end

    task.defer(function()
        pcall(function()
            Holder.AnchorPoint = Vector2.new(0.5, 0)
            Holder.Position = UDim2.new(0.5, 0, 0, -16)
            Library:Spring(Holder, "Position", UDim2.new(0.5, 0, 0, 2), 20, 0.62)
            Library.WatermarkContainer = Holder
            Library:DockToggleButton()
        end)
    end)

    pcall(Refresh)
    Library.Watermark = Watermark
    pcall(function()
        local existing = Toggles.TVLShowWatermark
        if existing then
            if existing.Value == false then task.defer(function() pcall(function() Watermark:SetVisible(false) end) end) end
            return
        end
        local win = Library.Window
        if win and win.MenuGroup and win.MenuGroup.AddToggle then
            win.MenuGroup:AddToggle("TVLShowWatermark", {
                Text = "Show Watermark",
                Default = true,
                Tooltip = "Shows/hides the FPS & ping watermark label.",
                Callback = function(value)
                    pcall(function() Watermark:SetVisible(value) end)
                end,
            })
        end
    end)

    function Watermark:SetText(Text)
        Brand.Text = tostring(Text)
    end
    function Watermark:SetExtraLine(Provider)
        ExtraProvider = (typeof(Provider) == "function") and Provider
            or (typeof(Provider) == "string" and function() return Provider end)
            or nil
        pcall(Refresh)
    end
    function Watermark:SetVisible(Visible)
        local Was = UserVisible and Holder.Visible
        UserVisible = Visible == true
        DL:SetVisible(UserVisible)
        if UserVisible and not Was and not Holder:GetAttribute("Dragging") then
            local Home = Holder.Position
            Library:SpringStop(Holder, "Position")
            Holder.Position = Home + UDim2.fromOffset(0, -16)
            Library:Spring(Holder, "Position", Home, 20, 0.62)
        end
    end
    function Watermark:Destroy()
        Watermark.Destroyed = true
        if Connection then
            pcall(function() Connection:Disconnect() end)
        end
        pcall(function() DL:Destroy() end)
    end

    return Watermark
end

--// Accent RGB driver + reusable accent/rainbow gradient (call from any script) \\--
-- Library:SetRgbAccent(true/false [, speed])  -> cycles Library.Scheme.AccentColor through the hue
--   wheel and writes every registered AccentColor prop; exposes Library.RgbEnabled / Library.RgbHue.
--   Mirrors hue to getgenv().__tvlRgbHue / __tvlRgbConn for backward-compat readers.
function Library:SetRgbAccent(...)
    local Params = select(1, ...)
    local enabled, speed
    if typeof(Params) == "table" then
        enabled = Params.Enabled
        speed = Params.Speed
    else
        enabled = Params
        speed = select(2, ...)
    end
    speed = tonumber(speed) or 0.0015
    local _genv = (type(getgenv) == "function" and getgenv()) or _G

    if self._rgbConn then pcall(function() self._rgbConn:Disconnect() end); self._rgbConn = nil end
    if not enabled then
        self.RgbEnabled = false
        _genv.__tvlRgbConn = nil
        local orig = self._rgbOrigAccent
        if orig then
            self.Scheme.AccentColor = orig
            local restoreTargets = table.create(64)
            for inst in pairs(self.Registry) do
                restoreTargets[#restoreTargets + 1] = inst
            end
            for _, inst in ipairs(restoreTargets) do
                local props = self.Registry[inst]
                if type(props) == "table" then
                    for prop, colorName in pairs(props) do
                        if colorName == "AccentColor" then pcall(function() inst[prop] = orig end) end
                    end
                end
            end
            pcall(function() local p = self.Options and self.Options.AccentColor; if p then p:SetValue(orig) end end)
            pcall(function() self:UpdateColorsUsingRegistry() end)
            self._rgbOrigAccent = nil
        end
        return
    end

    if not self.RgbEnabled or not self._rgbOrigAccent then
        self._rgbOrigAccent = self.Scheme.AccentColor
    end
    self.RgbEnabled = true
    local hue, frame, bindings, rebuildAt = 0, 0, {}, 0
    local outside, stale = {}, false
    local function shown(inst)
        local node = inst
        while node do
            if node:IsA("GuiObject") then
                if not node.Visible then return false end
            elseif node:IsA("LayerCollector") then
                return node.Enabled and node.Parent ~= nil
            end
            node = node.Parent
        end
        return false
    end
    local function rebuild()
        table.clear(bindings)
        table.clear(outside)
        local win = self.WindowContainer
        for inst, props in pairs(self.Registry) do
            if type(props) == "table" then
                for prop, colorName in pairs(props) do
                    if colorName == "AccentColor" then
                        local b = { inst, prop }
                        bindings[#bindings + 1] = b
                        if not (win and inst:IsDescendantOf(win)) and shown(inst) then outside[#outside + 1] = b end
                    end
                end
            end
        end
    end
    local function _setBound(inst, prop, value)
        local props = self.Registry[inst]
        if props and props[prop] == "AccentColor" then
            inst[prop] = value
        end
    end
    do
        local ok, startHue = pcall(function()
            return (self.Scheme.AccentColor:ToHSV())
        end)
        hue = ok and tonumber(startHue) or 0
        self.RgbHue = hue
        _genv.__tvlRgbHue = hue
        local col = Color3.fromHSV(hue, 1, 1)
        self.Scheme.AccentColor = col
        rebuild()
        rebuildAt = os.clock()
        pcall(function() for _, b in ipairs(bindings) do _setBound(b[1], b[2], col) end end)
        pcall(function()
            local p = self.Options and self.Options.AccentColor
            if p then
                p.Hue = hue; p.Sat = 1; p.Vib = 1
                if p.Preview then p:Preview() end
            end
        end)
    end
    self._rgbConn = game:GetService("RunService").Heartbeat:Connect(ObsGuard(function()
        frame = frame + 1
        if frame % 3 ~= 0 then return end
        hue = (hue + speed) % 1
        self.RgbHue = hue
        _genv.__tvlRgbHue = hue
        local col = Color3.fromHSV(hue, 1, 1)
        self.Scheme.AccentColor = col
        local now = os.clock()
        local visible = self.Toggled and self.ScreenGui and self.ScreenGui.Parent
        if now - rebuildAt > 2 or (visible and stale) or self.RgbDirty then self.RgbDirty = false; rebuildAt = now; rebuild() end
        if not visible then
            stale = true
            pcall(function() for _, b in ipairs(outside) do _setBound(b[1], b[2], col) end end)
            return
        end
        stale = false
        pcall(function() for _, b in ipairs(bindings) do _setBound(b[1], b[2], col) end end)
        pcall(function()
            local p = self.Options and self.Options.AccentColor
            if p then
                p.Hue = hue; p.Sat = 1; p.Vib = 1
                if p.Preview then p:Preview() else p:Update() end
            end
        end)
    end))
    _genv.__tvlRgbConn = self._rgbConn
end

-- Library:AddAccentGradient(guiObject [, opts]) -> attaches a scrolling gradient that follows the
--   accent color and goes rainbow while SetRgbAccent is on. opts: Rotation, Transparency (NumberSequence),
--   Scroll (bool, default true), ScrollSpeed (default 1.8). Returns { Gradient, Destroy }.
local function _gradOnScreen(inst)
    local node = inst
    while node do
        if node:IsA("GuiObject") then
            if not node.Visible then return false end
        elseif node:IsA("LayerCollector") then
            return node.Enabled and node.Parent ~= nil
        end
        node = node.Parent
    end
    return false
end
Library.SmoothScrollers = {}
Library.SmoothScrollStep = 150

local function SmoothScrollMax(Frame)
    return math.max(0, Frame.AbsoluteCanvasSize.Y - Frame.AbsoluteWindowSize.Y)
end

local function SmoothScrollTarget()
    if not Mouse then
        return nil
    end
    local Point = Vector2.new(Mouse.X, Mouse.Y)
    local Best = nil
    for Frame in pairs(Library.SmoothScrollers) do
        if Frame.Parent and _gradOnScreen(Frame) then
            local Position, Size = Frame.AbsolutePosition, Frame.AbsoluteSize
            if Point.X >= Position.X and Point.X <= Position.X + Size.X and Point.Y >= Position.Y and Point.Y <= Position.Y + Size.Y then
                if not Best or Frame:IsDescendantOf(Best) then
                    Best = Frame
                end
            end
        end
    end
    return Best
end

function Library:_ensureSmoothScroll()
    if Library.SmoothScrollReady then
        return
    end
    Library.SmoothScrollReady = true

    local Connection = nil
    local function Step(Delta)
        Delta = math.clamp(tonumber(Delta) or 0.016, 0.001, 0.05)
        local Busy = false
        for Frame, State in pairs(Library.SmoothScrollers) do
            if not Frame.Parent then
                Library.SmoothScrollers[Frame] = nil
            elseif State.Moving then
                State.Target = math.clamp(State.Target, 0, SmoothScrollMax(Frame))
                local Current = Frame.CanvasPosition.Y
                local Next = Current + (State.Target - Current) * (1 - math.exp(-Delta * 16))
                if math.abs(State.Target - Next) < 0.5 then
                    Next = State.Target
                    State.Moving = false
                else
                    Busy = true
                end
                State.Last = Next
                Frame.CanvasPosition = Vector2.new(Frame.CanvasPosition.X, Next)
            end
        end
        if not Busy and Connection then
            Connection:Disconnect()
            Connection = nil
        end
    end

    Library.SmoothScrollKick = function()
        if not Connection then
            Connection = RunService.Heartbeat:Connect(ObsGuard(Step))
        end
    end

    Library:GiveSignal(UserInputService.InputChanged:Connect(ObsGuard(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.MouseWheel or Library.Unloaded then
            return
        end
        if Library:MouseIsOverMenu() then
            return
        end
        local Frame = SmoothScrollTarget()
        local State = Frame and Library.SmoothScrollers[Frame]
        if not State then
            return
        end
        local Wheel = Input.Position.Z
        if Wheel == 0 then
            return
        end
        local Base = State.Moving and State.Target or Frame.CanvasPosition.Y
        State.Target = math.clamp(Base - Wheel * Library.SmoothScrollStep, 0, SmoothScrollMax(Frame))
        State.Moving = true
        Library.SmoothScrollKick()
    end)))

    pcall(function()
        local Actions = game:GetService("ContextActionService")
        Actions:BindActionAtPriority("AzureSmoothScroll" .. tostring(Library.ShowCursorBinding), ObsGuard(function()
            if Library.Unloaded or Library:MouseIsOverMenu() then
                return Enum.ContextActionResult.Pass
            end
            return SmoothScrollTarget() and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
        end), false, 3000, Enum.UserInputType.MouseWheel)
        table.insert(Library.UnloadSignals, function()
            pcall(function()
                Actions:UnbindAction("AzureSmoothScroll" .. tostring(Library.ShowCursorBinding))
            end)
        end)
    end)
end

function Library:AddSmoothScroll(Frame: ScrollingFrame)
    if typeof(Frame) ~= "Instance" or not Frame:IsA("ScrollingFrame") or Library.SmoothScrollers[Frame] then
        return
    end
    if not UserInputService.MouseEnabled or Library.IsMobile then
        return
    end
    local State = { Target = Frame.CanvasPosition.Y, Last = Frame.CanvasPosition.Y, Moving = false }
    Library.SmoothScrollers[Frame] = State
    Frame.ScrollingEnabled = false
    Frame:GetPropertyChangedSignal("CanvasPosition"):Connect(ObsGuard(function()
        if math.abs(Frame.CanvasPosition.Y - State.Last) > 1 then
            State.Target = Frame.CanvasPosition.Y
            State.Last = State.Target
            State.Moving = false
        end
    end))
    Frame.Destroying:Once(function()
        Library.SmoothScrollers[Frame] = nil
    end)
    Library:_ensureSmoothScroll()
end

function Library:RefreshGradVisibility()
    for _, Entry in ipairs(self._sharedGrads or {}) do
        Entry._visAt = nil
    end
end

function Library:_ensureGradLoop()
    if self._sharedGradConn then return end
    self._sharedGrads = self._sharedGrads or {}
    local RS = game:GetService("RunService")
    local _scrollFrame = 0
    self._sharedGradConn = RS.Heartbeat:Connect(ObsGuard(function()
        local grads = self._sharedGrads
        if not grads or #grads == 0 then return end
        _scrollFrame = _scrollFrame + 1
        local now = os.clock()
        local _scrollTick = now - (self._gradScrollAt or 0) >= 1 / 30
        if _scrollTick then
            self._gradScrollAt = now
        end
        local accent = (self.Scheme and self.Scheme.AccentColor) or Color3.fromRGB(40, 76, 177)
        local rgbOn = self.RgbEnabled and true or false
        local rgbHue = self.RgbHue or 0
        local secHue = (now * 0.4) % 1
        local secRgbSeq, rgbModeSeq, accentSeq16, accentSeq17
        for i = #grads, 1, -1 do
            local e = grads[i]
            if not e.gradient or not e.gradient.Parent then
                table.remove(grads, i)
            elseif e.lbl and e.lbl.Parent then
                if e._visAt == nil or _scrollFrame - e._visAt >= 10 then
                    e._visAt = e._visAt == nil and (_scrollFrame - (i % 10)) or _scrollFrame
                    e._vis = _gradOnScreen(e.lbl)
                    if e.isImage == nil then
                        e.isImage = e.lbl:IsA("ImageLabel")
                    end
                    if e.isImage and e._vis and e.lbl.ImageColor3 ~= Color3.new(1, 1, 1) then
                        e.lbl.ImageColor3 = Color3.new(1, 1, 1)
                    end
                end
                local _upd = e._vis and e.gradient.Enabled
                if _upd then
                if e.kind == "section" and e.isRgb then
                    if not secRgbSeq then
                        secRgbSeq = ColorSequence.new({
                            ColorSequenceKeypoint.new(0,   Color3.fromHSV((secHue + 0)   % 1, 1, 1)),
                            ColorSequenceKeypoint.new(1/6, Color3.fromHSV((secHue + 1/6) % 1, 1, 1)),
                            ColorSequenceKeypoint.new(2/6, Color3.fromHSV((secHue + 2/6) % 1, 1, 1)),
                            ColorSequenceKeypoint.new(3/6, Color3.fromHSV((secHue + 3/6) % 1, 1, 1)),
                            ColorSequenceKeypoint.new(4/6, Color3.fromHSV((secHue + 4/6) % 1, 1, 1)),
                            ColorSequenceKeypoint.new(5/6, Color3.fromHSV((secHue + 5/6) % 1, 1, 1)),
                            ColorSequenceKeypoint.new(1,   Color3.fromHSV((secHue + 0)   % 1, 1, 1)),
                        })
                    end
                    e.gradient.Color = secRgbSeq
                elseif e.kind == "accent" and rgbOn and e.rainbow then
                    if math.abs(rgbHue - (e.lastHue or -1)) > 0.005 or (e.lastHue or -1) < 0 then
                        e.lastHue = rgbHue; e.lastAccent = nil
                        if not rgbModeSeq then
                            rgbModeSeq = ColorSequence.new({
                                ColorSequenceKeypoint.new(0,   Color3.fromHSV((rgbHue + 0)   % 1, 1, 1)),
                                ColorSequenceKeypoint.new(1/6, Color3.fromHSV((rgbHue + 1/6) % 1, 1, 1)),
                                ColorSequenceKeypoint.new(2/6, Color3.fromHSV((rgbHue + 2/6) % 1, 1, 1)),
                                ColorSequenceKeypoint.new(3/6, Color3.fromHSV((rgbHue + 3/6) % 1, 1, 1)),
                                ColorSequenceKeypoint.new(4/6, Color3.fromHSV((rgbHue + 4/6) % 1, 1, 1)),
                                ColorSequenceKeypoint.new(5/6, Color3.fromHSV((rgbHue + 5/6) % 1, 1, 1)),
                                ColorSequenceKeypoint.new(1,   Color3.fromHSV((rgbHue + 0)   % 1, 1, 1)),
                            })
                        end
                        e.gradient.Color = rgbModeSeq
                    end
                else
                    e.lastHue = -1
                    if accent ~= e.lastAccent then
                        e.lastAccent = accent
                        if e.kind == "accent" then
                            if not accentSeq17 then
                                local l = accent:Lerp(Color3.new(1, 1, 1), 0.42)
                                accentSeq17 = ColorSequence.new({
                                    ColorSequenceKeypoint.new(0,   accent),
                                    ColorSequenceKeypoint.new(0.5, l),
                                    ColorSequenceKeypoint.new(1,   accent),
                                })
                            end
                            e.gradient.Color = accentSeq17
                        else
                            if not accentSeq16 then
                                local l = accent:Lerp(Color3.new(1, 1, 1), 0.36)
                                accentSeq16 = ColorSequence.new({
                                    ColorSequenceKeypoint.new(0,   accent),
                                    ColorSequenceKeypoint.new(0.5, l),
                                    ColorSequenceKeypoint.new(1,   accent),
                                })
                            end
                            e.gradient.Color = accentSeq16
                        end
                    end
                end
                if e.scroll ~= false and _scrollTick then
                    local ox = ((now * (e.scrollSpeed or 1.8)) % 2) - 1
                    if ox ~= e.lastOff then e.lastOff = ox; e.gradient.Offset = Vector2.new(ox, 0) end
                end
                end
            end
        end
    end))
end

function Library:AddAccentGradient(obj, opts)
    if typeof(obj) ~= "Instance" then return end
    opts = opts or {}
    self._sharedGrads = self._sharedGrads or {}
    local grad = Instance.new("UIGradient")
    grad.Rotation = tonumber(opts.Rotation) or 0
    if opts.Transparency then grad.Transparency = opts.Transparency end
    grad.Parent = obj
    local entry = {
        lbl = obj, gradient = grad, kind = "accent", rainbow = opts.Rainbow == true,
        scroll = opts.Scroll ~= false,
        scrollSpeed = tonumber(opts.ScrollSpeed) or 1.8,
        lastAccent = nil, lastHue = -1, lastOff = nil,
    }
    table.insert(self._sharedGrads, entry)
    self:_ensureGradLoop()
    return {
        Gradient = grad,
        Destroy = function()
            for k = #self._sharedGrads, 1, -1 do
                if self._sharedGrads[k] == entry then table.remove(self._sharedGrads, k); break end
            end
            pcall(function() grad:Destroy() end)
        end,
    }
end

function Library:AddSharedGradient(obj, opts)
    if typeof(obj) ~= "Instance" then return end
    opts = opts or {}
    self._sharedGrads = self._sharedGrads or {}
    for k = #self._sharedGrads, 1, -1 do
        local old = self._sharedGrads[k]
        if old and old.lbl == obj and old.kind == "section" then
            table.remove(self._sharedGrads, k)
        end
    end
    local existing = obj:FindFirstChildOfClass("UIGradient")
    if existing then pcall(function() existing:Destroy() end) end
    if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        local reg = self.Registry and self.Registry[obj]
        if reg then
            reg.ImageColor3 = nil
            if next(reg) == nil then
                pcall(function() self:RemoveFromRegistry(obj) end)
            end
        end
        obj.ImageColor3 = Color3.new(1, 1, 1)
    end
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = tonumber(opts.Rotation) or 0
    gradient.Parent = obj
    local entry = {
        lbl = obj, gradient = gradient, kind = "section",
        isRgb = opts.isRgb and true or false,
        scroll = true, scrollSpeed = 1.8,
        lastAccent = nil, lastHue = -1, lastOff = nil,
    }
    table.insert(self._sharedGrads, entry)
    self:_ensureGradLoop()
    return entry
end

function Library:AddDraggableButton(...)
    local Params = select(1, ...)

    local Text
    local Func
    local ExcludeScaling
    local ExcludeDragging

    if typeof(Params) == "table" then
        Text = Params.Text
        Func = Params.Callback or Params.Func
        ExcludeScaling = Params.ExcludeScaling
        ExcludeDragging = Params.ExcludeDragging
    elseif typeof(Params) == "string" then
        Text = Params
        Func = select(2, ...)
        ExcludeScaling = select(3, ...)
        ExcludeDragging = select(4, ...)
    end

    local DraggableButton = {
        Connections = {},
        Destroyed = false
    }

    local Button = New("TextButton", {
        BackgroundColor3 = "BackgroundColor",
        Position = UDim2.fromOffset(6, 6),
        TextSize = 16,
        ZIndex = 10,
        Parent = ScreenGui,
    })
    table.insert(
        Library.Corners, 
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = Button,
        })
    )
    if not ExcludeScaling then
        table.insert(
            Library.Scales,
            New("UIScale", {
                Scale = Library.DPIScale,
                Parent = Button,
            })
        )
    end
    Library:AddOutline(Button)

    local DragThreshold = if ExcludeDragging then 10 else math.huge
    Button.InputBegan:Connect(ObsGuard(function(Input: InputObject)
        if not IsClickInput(Input) then
            return
        end
        
        local function PointerPos()
            if Input.UserInputType == Enum.UserInputType.Touch then
                return Vector2.new(Input.Position.X, Input.Position.Y)
            end
            return UserInputService:GetMouseLocation()
        end
        local StartPos = PointerPos()

        local Changed
        Changed = Input.Changed:Connect(ObsGuard(function()
            if Input.UserInputState ~= Enum.UserInputState.End then
                return
            end

            local IsLikelyDragging = (PointerPos() - StartPos).Magnitude > DragThreshold
            if Button:GetAttribute("SuppressClick") then
                Button:SetAttribute("SuppressClick", nil)
                IsLikelyDragging = true
            end
            if IsLikelyDragging then
                if Changed and Changed.Connected then Changed:Disconnect() end
                return
            end

            Library:SafeCallback(Func, DraggableButton)

            if Changed and Changed.Connected then
                Changed:Disconnect()
                Changed = nil
            end
        end))
    end))

    function DraggableButton:SetText(Text: string)
        local X, Y = Library:GetTextBounds(Text, Library.Scheme.Font, 16)

        Button.Text = Text
        Button.Size = UDim2.fromOffset(X * 2, Y * 2)
    end

    Library:MakeDraggable(Button, Button, true)
    DraggableButton:SetText(Text)
    DraggableButton.Button = Button

    if not table.find(Library.DraggableElements, Button) then
        table.insert(Library.DraggableElements, Button)
    end

    PositionDraggable(Button, Button.Position)

    function DraggableButton:Destroy()
        DraggableButton.Destroyed = true

        if DraggableButton.Connections then
            for _, connection in DraggableButton.Connections do
                connection:Disconnect()
            end
        end

        local ElemIdx = table.find(Library.DraggableElements, Button)
        if ElemIdx then
            table.remove(Library.DraggableElements, ElemIdx)
        end

        if Button then
            Button:Destroy()
        end
    end

    return DraggableButton
end

function Library:AddDraggableMenu(Name: string)
    local Holder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.XY,
        BackgroundColor3 = "BackgroundColor",
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(0, 0),
        ZIndex = 10,
        Parent = ScreenGui,
    })
    table.insert(
        Library.Corners,
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = Holder,
        })
    )
    table.insert(
        Library.Scales,
        New("UIScale", {
            Scale = Library.DPIScale,
            Parent = Holder,
        })
    )
    Library:AddOutline(Holder)

    local HeaderLine = Library:MakeLine(Holder, {
        Position = UDim2.fromOffset(0, 34),
        Size = UDim2.new(1, 0, 0, 1),
    })
    New("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, 0.2),
            NumberSequenceKeypoint.new(0.8, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Parent = HeaderLine,
    })

    local Label = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 34),
        Text = Name,
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = Holder,
    })
    New("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        Parent = Label,
    })

    local Container = New("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 35),
        Size = UDim2.new(1, 0, 1, -35),
        Parent = Holder,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 7),
        Parent = Container,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 7),
        PaddingLeft = UDim.new(0, 7),
        PaddingRight = UDim.new(0, 7),
        PaddingTop = UDim.new(0, 7),
        Parent = Container,
    })

    Library:MakeDraggable(Holder, Label, true)

    if not table.find(Library.DraggableElements, Holder) then
        table.insert(Library.DraggableElements, Holder)
    end

    PositionDraggable(Holder, Holder.Position)

    return Holder, Container
end

function Library:AddDraggableImageButton(...)
    local Params = select(1, ...)

    local Icon
    local IconSize
    local Func
    local ExcludeScaling
    local ExcludeDragging

    if typeof(Params) == "table" then
        Icon = Params.Icon
        IconSize = Params.IconSize or 24
        Func = Params.Callback or Params.Func
        ExcludeScaling = Params.ExcludeScaling
        ExcludeDragging = Params.ExcludeDragging
    elseif typeof(Params) == "string" or typeof(Params) == "number" then
        Icon = Params
        IconSize = select(2, ...)
        Func = select(3, ...)
        ExcludeScaling = select(4, ...)
        ExcludeDragging = select(5, ...)
    end

    local DraggableImageButton = {}

    local Button = New("TextButton", {
        BackgroundColor3 = "BackgroundColor",
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.fromOffset(IconSize + 12, IconSize + 12),
        Text = "",
        ZIndex = 10,
        Parent = ScreenGui,
    })
    
    local IconImage = New("ImageLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(IconSize, IconSize),
        ImageColor3 = "FontColor",
        ZIndex = 11,
        Parent = Button,
    })

    table.insert(
        Library.Corners, 
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = Button,
        })
    )
    if not ExcludeScaling then
        table.insert(
            Library.Scales,
            New("UIScale", {
                Scale = Library.DPIScale,
                Parent = Button,
            })
        )
    end
    Library:AddOutline(Button)

    local DragThreshold = if ExcludeDragging then 10 else math.huge
    Button.InputBegan:Connect(ObsGuard(function(Input: InputObject)
        if not IsClickInput(Input) then
            return
        end
        
        local function PointerPos()
            if Input.UserInputType == Enum.UserInputType.Touch then
                return Vector2.new(Input.Position.X, Input.Position.Y)
            end
            return UserInputService:GetMouseLocation()
        end
        local StartPos = PointerPos()

        local Changed
        Changed = Input.Changed:Connect(ObsGuard(function()
            if Input.UserInputState ~= Enum.UserInputState.End then
                return
            end

            local IsLikelyDragging = (PointerPos() - StartPos).Magnitude > DragThreshold
            if Button:GetAttribute("SuppressClick") then
                Button:SetAttribute("SuppressClick", nil)
                IsLikelyDragging = true
            end
            if IsLikelyDragging then
                if Changed and Changed.Connected then Changed:Disconnect() end
                return
            end

            if Changed and Changed.Connected then
                Changed:Disconnect()
                Changed = nil
            end
        end))
    end))

    function DraggableImageButton:SetIcon(NewIcon: string)
        Icon = NewIcon or Icon
        
        local CustomIcon = Library:GetCustomIcon(Icon)
        assert(CustomIcon, "Icon must be a valid Roblox asset or a valid URL or a valid lucide icon.")

        IconImage.Image = CustomIcon.Url
        IconImage.ImageRectOffset = CustomIcon.ImageRectOffset or Vector2.zero
        IconImage.ImageRectSize = CustomIcon.ImageRectSize or Vector2.zero
    end

    function DraggableImageButton:SetIconSize(NewSize: number)
        IconSize = NewSize
        IconImage.Size = UDim2.fromOffset(IconSize, IconSize)
        Button.Size = UDim2.fromOffset(IconSize + 12, IconSize + 12)
    end

    Library:MakeDraggable(Button, Button, true)
    DraggableImageButton:SetIcon(Icon)
    DraggableImageButton.Button = Button

    if not table.find(Library.DraggableElements, Button) then
        table.insert(Library.DraggableElements, Button)
    end

    PositionDraggable(Button, Button.Position)

    return DraggableImageButton
end

--// Watermark - Deprecated \\--
do
    local WatermarkLabel = Library:AddDraggableLabel("")
    WatermarkLabel:SetVisible(false)

    function Library:SetWatermark(Text: string)
        do end
        WatermarkLabel:SetText(Text)
    end

    function Library:SetWatermarkVisibility(Visible: boolean)
        do end
        WatermarkLabel:SetVisible(Visible)
    end
end

--// Context Menu \\--
local CurrentMenu
function Library:CloseCurrentMenu()
    if CurrentMenu then
        pcall(function()
            CurrentMenu:Close()
        end)
    end
end
function Library:MouseIsOverMenu()
    local Open = CurrentMenu
    if not (Open and Open.Menu and Open.Menu.Visible and Mouse) then
        return false
    end
    return Library:MouseIsOverFrame(Open.Menu, Vector2.new(Mouse.X, Mouse.Y))
end
function Library:AddContextMenu(
    Holder: GuiObject,
    Size: UDim2 | () -> (),
    Offset: { [number]: number } | () -> {},
    List: number?,
    ActiveCallback: (Active: boolean) -> ()?,
    IgnoreCornerRadius: boolean?,
    SpecificCornersOnly: ("top" | "bottom" | "no_left" | "no_top_left")?, -- stupid way of doing this
    AnimationType: ("Dropdown" | "KeyPicker" | "none")?
)
    local Menu
    local ParentGui = Holder:FindFirstAncestorOfClass("ScreenGui")
    local MenuZIndex = math.max(10, Holder.ZIndex + 1)
    if ParentGui ~= ScreenGui and (Library.ActiveLoading and ParentGui ~= Library.ActiveLoading.ScreenGui) then
        ParentGui = ScreenGui
    end

    if List then
        Menu = New("ScrollingFrame", {
            Active = true,
            AutomaticCanvasSize = Enum.AutomaticSize.None,
            AutomaticSize = List == 1 and Enum.AutomaticSize.Y or Enum.AutomaticSize.None,
            BackgroundColor3 = "BackgroundColor",
            BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
            CanvasSize = UDim2.fromOffset(0, 0),
            ScrollBarImageColor3 = "OutlineColor",
            ScrollBarThickness = List == 2 and 2 or 0,
            Size = typeof(Size) == "function" and Size() or Size,
            TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
            Visible = false,
            ZIndex = MenuZIndex,
            Parent = ParentGui,
        })
    else
        Menu = New("Frame", {
            Active = true,
            BackgroundColor3 = "BackgroundColor",
            Size = typeof(Size) == "function" and Size() or Size,
            Visible = false,
            ZIndex = MenuZIndex,
            Parent = ParentGui,
        })
    end
    table.insert(
        Library.Scales,
        New("UIScale", {
            Scale = Library.DPIScale,
            Parent = Menu,
        })
    )

    New("UIStroke", {
        Color = "OutlineColor",
        Parent = Menu,
    })

    local Corner;
    if IgnoreCornerRadius ~= true then
        if SpecificCornersOnly == "top" then
            Corner = New("UICorner", {
                TopLeftRadius = UDim.new(0, Library.CornerRadius / 2),
                TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomRightRadius = UDim.new(0, 0),
                BottomLeftRadius = UDim.new(0, 0),
                Parent = Menu,
            }); table.insert(Library.SpecificCorners, Corner)
        elseif SpecificCornersOnly == "bottom" then
            Corner = New("UICorner", {
                TopLeftRadius = UDim.new(0, 0),
                TopRightRadius = UDim.new(0, 0),
                BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Menu,
            }); table.insert(Library.SpecificCorners, Corner)
        elseif SpecificCornersOnly == "no_left" then
            Corner = New("UICorner", {
                TopLeftRadius = UDim.new(0, 0),
                TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomLeftRadius = UDim.new(0, 0),
                Parent = Menu,
            }); table.insert(Library.SpecificCorners, Corner)
        elseif SpecificCornersOnly == "no_top_left" then
            Corner = New("UICorner", {
                TopLeftRadius = UDim.new(0, 0),
                TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Menu,
            }); table.insert(Library.SpecificCorners, Corner)
        else
            Corner = New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Menu,
            }); table.insert(Library.Corners, Corner)
        end
    end

    local Table = {
        Connections = {},
        Destroyed = false,

        Active = false,
        Holder = Holder,
        Menu = Menu,
        List = nil,
        Signal = nil,

        Size = Size,

        AutoSizeY = List == 1,
        OpenCloseTween = nil,
        Animated = function()
            if not AnimationType or AnimationType == "none" then
                return false
            end

            if not (Library.Animations and Library.Animations[AnimationType] == true) then
                return false
            end
            
            return true, Library[string.format("%sTransitionInfo", AnimationType)] or TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
    }

    if List == 1 then
        Table.List = New("UIListLayout", {
            Parent = Menu,
        })
    end

    Table.PressedAt = 0
    table.insert(Table.Connections, Menu.InputBegan:Connect(ObsGuard(function(Input: InputObject)
        if IsClickInput(Input, true) then
            Table.PressedAt = os.clock()
        end
    end)))
    table.insert(Table.Connections, Holder.InputBegan:Connect(ObsGuard(function(Input: InputObject)
        if IsClickInput(Input, true) then
            Table.PressedAt = os.clock()
        end
    end)))

    function Table:Open()
        if CurrentMenu == Table then
            return
        elseif CurrentMenu then
            CurrentMenu:Close()
        end

        CurrentMenu = Table
        Table.Active = true

        local function PlaceMenu(TargetSize)
            local O = typeof(Offset) == "function" and Offset() or Offset
            Menu.AnchorPoint = Vector2.new(0, 0)
            Menu.Position = UDim2.fromOffset(
                math.floor(Holder.AbsolutePosition.X + O[1]),
                math.floor(Holder.AbsolutePosition.Y + O[2])
            )
            pcall(function()
                local Root = Menu.Parent
                local ViewY = (Root and Root:IsA("LayerCollector")) and Root.AbsoluteSize.Y or (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y) or 0
                if ViewY <= 0 then
                    return
                end
                local Size = TargetSize or (typeof(Table.Size) == "function" and Table.Size() or Table.Size)
                local MenuScale = Menu:FindFirstChildOfClass("UIScale")
                local S = MenuScale and MenuScale.Scale or 1
                local H = (Size.Y.Offset > 0 and Size.Y.Offset or Menu.AbsoluteSize.Y / math.max(S, 0.01)) * S
                if Menu.Position.Y.Offset + H > ViewY - 8 then
                    local Above = Holder.AbsolutePosition.Y - H - 4
                    if Above >= 8 then
                        Menu.AnchorPoint = Vector2.new(0, 1)
                        Menu.Position = UDim2.fromOffset(Menu.Position.X.Offset, math.floor(Holder.AbsolutePosition.Y - 4))
                    else
                        Menu.Position = UDim2.fromOffset(Menu.Position.X.Offset, math.floor(math.max(8, ViewY - 8 - H)))
                    end
                end
            end)
            pcall(function()
                local Root = Menu.Parent
                local ViewX = (Root and Root:IsA("LayerCollector")) and Root.AbsoluteSize.X or (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X) or 0
                local Flipped = false
                if ViewX > 0 then
                    local Size = TargetSize or (typeof(Table.Size) == "function" and Table.Size() or Table.Size)
                    local MenuScale = Menu:FindFirstChildOfClass("UIScale")
                    local S = MenuScale and MenuScale.Scale or 1
                    local W = (Size.X.Offset > 0 and Size.X.Offset or Menu.AbsoluteSize.X / math.max(S, 0.01)) * S
                    local Left = Menu.Position.X.Offset
                    if Left + W > ViewX - 8 then
                        local Right = math.floor(Holder.AbsolutePosition.X + Holder.AbsoluteSize.X)
                        if Right - W >= 8 then
                            Flipped = true
                            Menu.AnchorPoint = Vector2.new(1, Menu.AnchorPoint.Y)
                            Menu.Position = UDim2.fromOffset(Right, Menu.Position.Y.Offset)
                        else
                            Menu.Position = UDim2.fromOffset(math.floor(math.max(8, ViewX - 8 - W)), Menu.Position.Y.Offset)
                        end
                    end
                end
                if Corner and SpecificCornersOnly == "no_top_left" then
                    local Radius = UDim.new(0, Library.CornerRadius / 2)
                    Corner.TopLeftRadius = Flipped and Radius or UDim.new(0, 0)
                    Corner.TopRightRadius = Flipped and UDim.new(0, 0) or Radius
                end
            end)
        end

        if typeof(ActiveCallback) == "function" then
            Library:SafeCallback(ActiveCallback, true)
        end

        local TargetSize = typeof(Table.Size) == "function" and Table.Size() or Table.Size
        PlaceMenu(TargetSize)

        if Table.OpenCloseTween then
            StopTween(Table.OpenCloseTween, true)
            Table.OpenCloseTween = nil
        end

        local IsAnimated, TweenInfo = Table.Animated()
        if IsAnimated == true then
            local OpenSize = TargetSize
            if Table.AutoSizeY then
                local FullHeight = Menu.AbsoluteSize.Y

                Menu.AutomaticSize = Enum.AutomaticSize.None
                OpenSize = UDim2.new(TargetSize.X.Scale, TargetSize.X.Offset, 0, FullHeight)
            end

            Menu.Size = UDim2.new(OpenSize.X.Scale, OpenSize.X.Offset, 0, 0)
            Menu.Visible = true

            local Tween = TweenService:Create(Menu, TweenInfo, { Size = OpenSize })
            Table.OpenCloseTween = Tween

            Tween.Completed:Once(ObsGuard(function()
                if Table.OpenCloseTween == Tween then
                    StopTween(Table.OpenCloseTween, true)
                    Table.OpenCloseTween = nil

                    if Table.AutoSizeY then
                        Menu.AutomaticSize = Enum.AutomaticSize.Y
                    end
                end
            end))

            Tween:Play()
        else
            Menu.Size = TargetSize
            Menu.Visible = true
        end

        Table.Signal = Holder:GetPropertyChangedSignal("AbsolutePosition"):Connect(ObsGuard(function()
            PlaceMenu(nil)

            if not Library:IsInsideFrame(Library.WindowContainer, Holder) and Table.Active then
                Table:Close()
            end
        end))
    end

    function Table:Close()
        if CurrentMenu ~= Table then
            return
        end

        if Table.Signal then
            Table.Signal:Disconnect()
            Table.Signal = nil
        end

        Table.Active = false
        CurrentMenu = nil

        if typeof(ActiveCallback) == "function" then
            Library:SafeCallback(ActiveCallback, false)
        end

        if Table.OpenCloseTween then
            StopTween(Table.OpenCloseTween, true)
            Table.OpenCloseTween = nil
        end

        local IsAnimated, TweenInfo = Table.Animated()
        if IsAnimated == true then
            if Table.AutoSizeY then
                Menu.AutomaticSize = Enum.AutomaticSize.None
            end

            local CurrentSize = Menu.Size
            local CollapsedSize = UDim2.new(CurrentSize.X.Scale, CurrentSize.X.Offset, 0, 0)

            local Tween = TweenService:Create(Menu, TweenInfo, { Size = CollapsedSize })
            Table.OpenCloseTween = Tween

            Tween.Completed:Once(ObsGuard(function(PlaybackState)
                if Table.OpenCloseTween == Tween then
                    StopTween(Table.OpenCloseTween, true)
                    Table.OpenCloseTween = nil

                    Menu.Visible = false
                    if Table.AutoSizeY then
                        Menu.AutomaticSize = Enum.AutomaticSize.Y
                    end
                end
            end))

            Tween:Play()
        else
            Menu.Visible = false
        end
    end

    function Table:Toggle()
        if Table.Active then
            Table:Close()
        else
            Table:Open()
        end
    end

    function Table:SetSize(Size)
        Table.Size = Size

        if not Table.Active then
            if not Menu.Visible then
                Menu.Size = typeof(Size) == "function" and Size() or Size
            end
            return
        end

        local Target = typeof(Size) == "function" and Size() or Size

        if Table.OpenCloseTween then
            StopTween(Table.OpenCloseTween, false)
            Table.OpenCloseTween = nil
        end

        if Table.ResizeTween then
            pcall(function()
                Table.ResizeTween:Cancel()
            end)
        end

        Table.ResizeTween = TweenService:Create(Menu, TweenInfo.new(0.14, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Target })
        Table.ResizeTween:Play()
    end

    function Table:Destroy()
        Table.Destroyed = true

        if Table.Connections then
            for _, Connection in Table.Connections do
                Connection:Disconnect()
            end
        end

        if CurrentMenu == Table then
            Table:Close()
        end

        if Table.OpenCloseTween then
            StopTween(Table.OpenCloseTween, true)
            Table.OpenCloseTween = nil
        end

        if Menu then
            Menu:Destroy()
        end
    end

    return Table
end

Library:GiveSignal(UserInputService.InputBegan:Connect(ObsGuard(function(Input: InputObject)
    if Library.Unloaded then
        return
    end

    if IsClickInput(Input, true) then
        local Location = Input.Position

        if
            CurrentMenu
            and not (
                Library:MouseIsOverFrame(CurrentMenu.Menu, Location)
                or Library:MouseIsOverFrame(CurrentMenu.Holder, Location)
            )
        then
            local Menu = CurrentMenu
            task.defer(function()
                if Library.Unloaded or CurrentMenu ~= Menu then
                    return
                end
                if os.clock() - (Menu.PressedAt or 0) < 0.1 then
                    return
                end
                Menu:Close()
            end)
        end
    end
end)))

--// Tooltip \\--
local TooltipLabel = New("TextLabel", {
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundColor3 = "BackgroundColor",
    TextSize = 14,
    TextWrapped = true,
    Visible = false,
    ZIndex = 20,
    Parent = ScreenGui,
})
New("UIPadding", {
    PaddingBottom = UDim.new(0, 2),
    PaddingLeft = UDim.new(0, 4),
    PaddingRight = UDim.new(0, 4),
    PaddingTop = UDim.new(0, 2),
    Parent = TooltipLabel,
})
table.insert(
    Library.Scales,
    New("UIScale", {
        Scale = Library.DPIScale,
        Parent = TooltipLabel,
    })
)
local TooltipStroke = New("UIStroke", {
    Color = "OutlineColor",
    Parent = TooltipLabel,
})
table.insert(
    Library.Corners,
    New("UICorner", {
        CornerRadius = UDim.new(0, Library.CornerRadius / 2),
        Parent = TooltipLabel,
    })
)
local TooltipMaxWidth = 260
local function GetViewportSize()
    local Camera = workspace.CurrentCamera
    return (Camera and Camera.ViewportSize) or Vector2.new(1920, 1080)
end

local function UpdateTooltipSize()
    if Library.Unloaded then
        return
    end

    local Viewport = GetViewportSize()
    local Cap = math.max(80, math.min(TooltipMaxWidth, Viewport.X - 16)) / Library.DPIScale

    local X, _ = Library:GetTextBounds(TooltipLabel.Text, TooltipLabel.FontFace, TooltipLabel.TextSize, Cap)

    TooltipLabel.Size = UDim2.fromOffset(math.min(X + 8, Cap), 0)
end

TooltipLabel:GetPropertyChangedSignal("Text"):Connect(ObsGuard(UpdateTooltipSize))

local CurrentHoverInstance
function Library:AddTooltip(InfoStr: string, DisabledInfoStr: string, HoverInstance: GuiObject)
    local TooltipTable = {
        Disabled = false,
        Hovering = false,
        Signals = {},
    }

    local function DoHover()
        if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
            return
        end
        if Library:MouseIsOverMenu() then
            return
        end
        if
            CurrentHoverInstance == HoverInstance
            or Library.ActiveDialog
            or CurrentMenu
            or (TooltipTable.Disabled and typeof(DisabledInfoStr) ~= "string")
            or (not TooltipTable.Disabled and typeof(InfoStr) ~= "string")
        then
            return
        end
        CurrentHoverInstance = HoverInstance

        task.wait(0.25)
        if CurrentHoverInstance ~= HoverInstance or CurrentMenu or Library.ActiveDialog then return end

        local ParentGui = HoverInstance:FindFirstAncestorOfClass("ScreenGui")
        if ParentGui ~= ScreenGui and (Library.ActiveLoading and ParentGui ~= Library.ActiveLoading.ScreenGui) then
            ParentGui = ScreenGui
        end
        TooltipLabel.Parent = ParentGui

        TooltipLabel.Text = TooltipTable.Disabled and DisabledInfoStr or InfoStr
        UpdateTooltipSize()
        TooltipLabel.TextTransparency = 1
        TooltipLabel.BackgroundTransparency = 1
        TooltipStroke.Transparency = 1
        TooltipLabel.Visible = true
        do
            local FadeIn = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            TweenService:Create(TooltipLabel, FadeIn, { TextTransparency = 0, BackgroundTransparency = 0 }):Play()
            TweenService:Create(TooltipStroke, FadeIn, { Transparency = 0 }):Play()
        end

        while
            (Library.Toggled or Library.ActiveLoading)
            and not Library.Unloaded
            and HoverInstance.Parent
            and not Library.ActiveDialog
            and not CurrentMenu
            and Library:MouseIsOverFrame(HoverInstance, Mouse)
        do
            local Viewport = GetViewportSize()
            local Bounds = TooltipLabel.AbsoluteSize
            local PosX = Mouse.X + (Library.ShowCustomCursor and 8 or 14)
            local PosY = Mouse.Y + (Library.ShowCustomCursor and 8 or 12)

            if PosX + Bounds.X > Viewport.X - 4 then
                PosX = math.max(4, Mouse.X - Bounds.X - 4)
            end

            if PosY + Bounds.Y > Viewport.Y - 4 then
                PosY = math.max(4, Mouse.Y - Bounds.Y - 4)
            end

            TooltipLabel.Position = UDim2.fromOffset(PosX, PosY)

            RunService.RenderStepped:Wait()
        end

        TooltipLabel.Visible = false
        CurrentHoverInstance = nil
    end

    local function GiveSignal(Connection: RBXScriptConnection | RBXScriptSignal)
        local ConnectionType = typeof(Connection)
        if Connection and (ConnectionType == "RBXScriptConnection" or ConnectionType == "RBXScriptSignal") then
            table.insert(TooltipTable.Signals, Connection)
        end

        return Connection
    end

    GiveSignal(HoverInstance.InputBegan:Connect(ObsGuard(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        local Text = TooltipTable.Disabled and DisabledInfoStr or InfoStr
        if typeof(Text) ~= "string" or Library.ActiveDialog or CurrentMenu then
            return
        end
        TooltipTable.TouchToken = (TooltipTable.TouchToken or 0) + 1
        local Token = TooltipTable.TouchToken
        local Start = Vector2.new(Input.Position.X, Input.Position.Y)
        task.delay(0.45, function()
            if TooltipTable.TouchToken ~= Token or Input.UserInputState == Enum.UserInputState.End then
                return
            end
            local Now = Vector2.new(Input.Position.X, Input.Position.Y)
            if (Now - Start).Magnitude > 12 then
                return
            end
            CurrentHoverInstance = HoverInstance
            local ParentGui = HoverInstance:FindFirstAncestorOfClass("ScreenGui")
            if ParentGui ~= ScreenGui and (Library.ActiveLoading and ParentGui ~= Library.ActiveLoading.ScreenGui) then
                ParentGui = ScreenGui
            end
            TooltipLabel.Parent = ParentGui
            TooltipLabel.Text = Text
            UpdateTooltipSize()
            local Viewport = GetViewportSize()
            local Bounds = TooltipLabel.AbsoluteSize
            local PosX = math.clamp(Now.X - Bounds.X / 2, 4, math.max(4, Viewport.X - Bounds.X - 4))
            local PosY = Now.Y - Bounds.Y - 28
            if PosY < 4 then
                PosY = Now.Y + 28
            end
            TooltipLabel.Position = UDim2.fromOffset(PosX, PosY)
            TooltipLabel.Visible = true
            while TooltipTable.TouchToken == Token and Input.UserInputState ~= Enum.UserInputState.End do
                task.wait()
            end
            task.wait(1.2)
            if TooltipTable.TouchToken == Token and CurrentHoverInstance == HoverInstance then
                TooltipLabel.Visible = false
                CurrentHoverInstance = nil
            end
        end)
    end)))
    GiveSignal(HoverInstance.MouseEnter:Connect(ObsGuard(DoHover)))
    GiveSignal(HoverInstance.MouseMoved:Connect(ObsGuard(DoHover)))
    GiveSignal(HoverInstance.MouseLeave:Connect(ObsGuard(function()
        if CurrentHoverInstance ~= HoverInstance then
            return
        end

        TooltipLabel.Visible = false
        CurrentHoverInstance = nil
    end)))

    function TooltipTable:Destroy()
        local TooltipIndex = table.find(Tooltips, TooltipTable)
        if TooltipIndex then
            table.remove(Tooltips, TooltipIndex)
        end
        for Index = #TooltipTable.Signals, 1, -1 do
            local Connection = table.remove(TooltipTable.Signals, Index)
            if Connection and Connection.Connected then
                Connection:Disconnect()
            end
        end

        if CurrentHoverInstance == HoverInstance then
            if TooltipLabel then
                TooltipLabel.Visible = false
            end

            CurrentHoverInstance = nil
        end
    end

    table.insert(Tooltips, TooltipTable)
    return TooltipTable
end

function Library:PlayTabSound()
    local Id = Library.TabSwitchSound
    if type(Id) ~= "string" or Id == "" then
        return
    end
    local Sound = Library.TabSoundInstance
    if not Sound or not Sound.Parent then
        Sound = New("Sound", {
            Name = "TabSwitch",
            Parent = ScreenGui,
        })
        Library.TabSoundInstance = Sound
    end
    if Sound.SoundId ~= Id then
        Sound.SoundId = Id
    end
    Sound.Volume = tonumber(Library.TabSwitchVolume) or 0.35
    pcall(function()
        Sound.TimePosition = 0
        Sound:Play()
    end)
end

Library.NotifySoundEnabled = true
Library.NotifySoundName = "Bamboo"
Library.NotifySoundVolume = 0.75
Library.NotifySoundList = { "Bamboo", "Kalimba", "Popup", "Classic", "Chime", "Bubble", "Pop", "Ding", "Soft", "Alert" }
Library.NotifySoundCache = {}

function Library:GetNotifySound(Name)
    Name = tostring(Name or Library.NotifySoundName or "Classic")

    local Cached = Library.NotifySoundCache[Name]
    if type(Cached) == "string" then
        return Cached
    end
    if type(Cached) == "number" and os.clock() - Cached < 30 then
        return nil
    end

    local GetAsset = getcustomasset or getsynasset
    if type(GetAsset) ~= "function" or type(writefile) ~= "function" or type(isfile) ~= "function" then
        Library.NotifySoundCache[Name] = os.clock()
        return nil
    end

    local File = Name:lower()
    local Path = "Azure/assets/sounds/" .. File .. "-v2.mp3"

    local function SoundBytesOk(Bytes)
        if type(Bytes) ~= "string" or #Bytes < 500 then
            return false
        end
        local First, Second = string.byte(Bytes, 1, 2)
        return Bytes:sub(1, 3) == "ID3" or (First == 0xFF and Second ~= nil and Second >= 0xE0)
    end

    Library.NotifySoundCache[Name] = os.clock()

    local Ok, Id = pcall(function()
        if type(makefolder) == "function" then
            pcall(makefolder, "Azure")
            pcall(makefolder, "Azure/assets")
            pcall(makefolder, "Azure/assets/sounds")
        end

        local Cached = false
        if isfile(Path) then
            local ReadOk, Bytes = pcall(readfile, Path)
            Cached = ReadOk and SoundBytesOk(Bytes)
            if not Cached and type(delfile) == "function" then
                pcall(delfile, Path)
            end
        end
        if not Cached then
            local Data = game:HttpGet("https://raw.githubusercontent.com/swrenic/ui/main/assets/sounds/" .. File .. ".mp3?v=2")
            if not SoundBytesOk(Data) then
                error("download failed")
            end
            writefile(Path, Data)
        end

        return GetAsset(Path)
    end)

    if Ok and type(Id) == "string" and Id ~= "" then
        Library.NotifySoundCache[Name] = Id
        return Id
    end

    Library.NotifySoundCache[Name] = os.clock()
    return nil
end

function Library:PlayNotifySound(Name, Volume)
    task.spawn(function()
        local Id = Library:GetNotifySound(Name)
        if not Id or Library.Unloaded then
            return
        end

        local Sound = Instance.new("Sound")
        Sound.Name = "NotifySound"
        Sound.SoundId = Id
        Sound.Volume = tonumber(Volume) or tonumber(Library.NotifySoundVolume) or 0.75
        Sound.Parent = SoundService
        Sound.Ended:Once(function()
            Sound:Destroy()
        end)
        Sound:Play()

        task.delay(5, function()
            if Sound.Parent then
                Sound:Destroy()
            end
        end)
    end)
end

function Library:AddNotificationSettings(Tab, Side)
    local Group
    if Side == "Right" then
        Group = Tab:AddRightGroupbox("Notification Sound", "bell")
    else
        Group = Tab:AddLeftGroupbox("Notification Sound", "bell")
    end

    Group:AddToggle("TVLNotifySound", {
        Text = "Notification Sound",
        Default = Library.NotifySoundEnabled ~= false,
        Tooltip = "Plays a sound when a notification shows up.",
        Callback = function(Value)
            Library.NotifySoundEnabled = Value == true
        end,
    })

    Group:AddDropdown("TVLNotifySoundName", {
        Text = "Sound",
        Values = Library.NotifySoundList,
        Default = Library.NotifySoundName,
        Callback = function(Value)
            if type(Value) == "string" and Value ~= "" then
                Library.NotifySoundName = Value
                task.spawn(function()
                    Library:GetNotifySound(Value)
                end)
            end
        end,
    })

    Group:AddSlider("TVLNotifyVolume", {
        Text = "Notification Volume",
        Default = 50,
        Min = 0,
        Max = 100,
        Rounding = 0,
        Suffix = "%",
        Callback = function(Value)
            Library.NotifySoundVolume = (tonumber(Value) or 50) / 100 * 1.5
        end,
    })

    Group:AddButton({
        Text = "Test Sound",
        Func = function()
            Library:PlayNotifySound()
        end,
    })

    task.spawn(function()
        Library:GetNotifySound(Library.NotifySoundName)
    end)

    return Group
end

function Library:OnUnload(Callback)
    table.insert(Library.UnloadSignals, Callback)
end

local CheckIcon = Library:GetIcon("check")
local ArrowIcon = Library:GetIcon("chevron-up")
local ResizeIcon = Library:GetIcon("move-diagonal-2")
local KeyIcon = Library:GetIcon("key")
local MoveIcon = Library:GetIcon("move")
local PopOutIcon = Library:GetIcon("square-arrow-down-left")
local CloseIcon = Library:GetIcon("x")

function Library:SetIconModule(module: IconModule)
    FetchIcons = true
    Icons = module

    -- Top ten fixes 🚀
    CheckIcon = Library:GetIcon("check")
    ArrowIcon = Library:GetIcon("chevron-up")
    PopOutIcon = Library:GetIcon("square-arrow-down-left")
    ResizeIcon = Library:GetIcon("move-diagonal-2")
    KeyIcon = Library:GetIcon("key")
    MoveIcon = Library:GetIcon("move")
    CloseIcon = Library:GetIcon("x")
end

local BaseAddons = {}
do
    local Funcs = {}

    function Funcs:AddKeyPicker(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.KeyPicker)

        local ParentObj = self
        local ToggleLabel = ParentObj.TextLabel

        if ParentObj.Type == "Button" or ParentObj.Type == "SubButton" then
            assert(Info.Mode == "Press", "KeyPicker on Buttons can only be applied with the 'Press' mode.")

            ToggleLabel = ParentObj.Base
        end

        local KeyPicker = {
            Connections = {},

            Text = Info.Text,
            Value = Info.Default, -- Key
            Modifiers = Info.DefaultModifiers, -- Modifiers
            DisplayValue = Info.Default, -- Picker Text

            Blacklisted = Info.Blacklisted,
            BlacklistedModifiers = Info.BlacklistedModifiers,
            Whitelisted = Info.Whitelisted,
            WhitelistedModifiers = Info.WhitelistedModifiers,

            Toggled = (Info.SyncToggleState and ParentObj.Type == "Toggle" and ParentObj.Value) or false,
            Mode = Info.Mode,
            SyncToggleState = Info.SyncToggleState,

            Callback = Info.Callback,
            ChangedCallback = Info.ChangedCallback,
            Changed = Info.Changed,
            Clicked = Info.Clicked,

            Type = "KeyPicker",
        }

        if KeyPicker.Mode == "Press" then
            assert(ParentObj.Type == "Label" or ParentObj.Type == "Button" or ParentObj.Type == "SubButton", "KeyPicker with the mode 'Press' can be only applied on Labels and Buttons.")

            KeyPicker.SyncToggleState = false
            Info.Modes = { "Press" }
            Info.Mode = "Press"
        end

        if KeyPicker.SyncToggleState then
            Info.Modes = { "Toggle", "Hold" }

            if not table.find(Info.Modes, Info.Mode) then
                Info.Mode = "Toggle"
            end
        end

        local Picking = false
        local IsForButton = ParentObj.Type == "Button" or ParentObj.Type == "SubButton"

        -- Special Keys
        local SpecialKeys = {
            ["MB1"] = Enum.UserInputType.MouseButton1,
            ["MB2"] = Enum.UserInputType.MouseButton2,
            ["MB3"] = Enum.UserInputType.MouseButton3,
        }

        local SpecialKeysInput = {
            [Enum.UserInputType.MouseButton1] = "MB1",
            [Enum.UserInputType.MouseButton2] = "MB2",
            [Enum.UserInputType.MouseButton3] = "MB3",
        }

        -- Modifiers
        local Modifiers = {
            ["LAlt"] = Enum.KeyCode.LeftAlt,
            ["RAlt"] = Enum.KeyCode.RightAlt,

            ["LCtrl"] = Enum.KeyCode.LeftControl,
            ["RCtrl"] = Enum.KeyCode.RightControl,

            ["LShift"] = Enum.KeyCode.LeftShift,
            ["RShift"] = Enum.KeyCode.RightShift,

            ["Tab"] = Enum.KeyCode.Tab,
            ["CapsLock"] = Enum.KeyCode.CapsLock,
        }

        local ModifiersInput = {
            [Enum.KeyCode.LeftAlt] = "LAlt",
            [Enum.KeyCode.RightAlt] = "RAlt",

            [Enum.KeyCode.LeftControl] = "LCtrl",
            [Enum.KeyCode.RightControl] = "RCtrl",

            [Enum.KeyCode.LeftShift] = "LShift",
            [Enum.KeyCode.RightShift] = "RShift",

            [Enum.KeyCode.Tab] = "Tab",
            [Enum.KeyCode.CapsLock] = "CapsLock",
        }

        local IsModifierInput = function(Input)
            return Input.UserInputType == Enum.UserInputType.Keyboard and ModifiersInput[Input.KeyCode] ~= nil
        end

        local GetActiveModifiers = function()
            local ActiveModifiers = {}

            for Name, Input in Modifiers do
                if table.find(ActiveModifiers, Name) then
                    continue
                end
                if not UserInputService:IsKeyDown(Input) then
                    continue
                end

                table.insert(ActiveModifiers, Name)
            end

            return ActiveModifiers
        end

        local AreModifiersHeld = function(Required)
            if not (typeof(Required) == "table" and GetTableSize(Required) > 0) then
                return true
            end

            local ActiveModifiers = GetActiveModifiers()
            local Holding = true

            for _, Name in Required do
                if table.find(ActiveModifiers, Name) then
                    continue
                end

                Holding = false
                break
            end

            return Holding
        end

        local IsInputDown = function(Input)
            if not Input then
                return false
            end

            if SpecialKeysInput[Input.UserInputType] ~= nil then
                return UserInputService:IsMouseButtonPressed(Input.UserInputType)
                    and not UserInputService:GetFocusedTextBox()
            elseif Input.UserInputType == Enum.UserInputType.Keyboard then
                return UserInputService:IsKeyDown(Input.KeyCode) and not UserInputService:GetFocusedTextBox()
            else
                return false
            end
        end

        local ConvertToInputModifiers = function(CurrentModifiers)
            local InputModifiers = {}

            for _, name in CurrentModifiers do
                table.insert(InputModifiers, Modifiers[name])
            end

            return InputModifiers
        end

        local VerifyModifiers = function(CurrentModifiers)
            if typeof(CurrentModifiers) ~= "table" then
                return {}
            end

            local ValidModifiers = {}

            for _, name in CurrentModifiers do
                if not Modifiers[name] then
                    continue
                end

                table.insert(ValidModifiers, name)
            end

            return ValidModifiers
        end

        KeyPicker.Modifiers = VerifyModifiers(KeyPicker.Modifiers)

        local SlideOverflow = true
        local MaxPickerWidth = 75
        local SlidingLabel

        local LastPickerWidth = 0
        local SlideForwardTween
        local SlideBackTween
        local HandleForwardTween = function(State)
            if State ~= Enum.PlaybackState.Completed then
                return
            end

            task.wait(1.5)
            if SlideBackTween then
                SlideBackTween:Play()
            end
        end

        local HandleBackTween = function(State)
            if State ~= Enum.PlaybackState.Completed then
                return
            end

            task.wait(1.5)
            if SlideForwardTween then
                SlideForwardTween:Play()
            end
        end

        local SlideForwardConn, SlideBackConn
        local CancelSlidingTweens = function()
            if SlideForwardConn then
                SlideForwardConn:Disconnect()
                SlideForwardConn = nil
            end

            if SlideBackConn then
                SlideBackConn:Disconnect()
                SlideBackConn = nil
            end

            if SlideForwardTween then
                StopTween(SlideForwardTween, true)
                SlideForwardTween = nil
            end

            if SlideBackTween then
                StopTween(SlideBackTween, true)
                SlideBackTween = nil
            end
        end

        local Picker = New("TextButton", {
            BackgroundColor3 = "MainColor",
            Size = UDim2.fromOffset(18, 18),
            Text = (IsForButton and SlideOverflow) and "" or KeyPicker.Value,
            TextSize = 14,
            TextTransparency = 0.4,
            Parent = ToggleLabel,
        })

        if IsForButton and SlideOverflow then
            Picker.ClipsDescendants = true

            SlidingLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Position = UDim2.new(0, 0, 0, 0),
                Text = KeyPicker.Value,
                TextSize = 14,
                FontFace = Picker.FontFace,
                TextXAlignment = Enum.TextXAlignment.Center,
                Parent = Picker,
            })

            Library:AddToRegistry(SlidingLabel, {
                TextColor3 = "FontColor",
            })
        end

        New("UIStroke", {
            Color = "OutlineColor",
            Parent = Picker,
        })

        local PickerCorner = New("UICorner", {
            TopLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            Parent = Picker,
        }); table.insert(Library.SpecificCorners, PickerCorner)

        local PickerHoverTween = nil

        local function ApplyPickerTextTransparency(Transparency: number)
            StopTween(PickerHoverTween)
            PickerHoverTween = nil

            Picker.TextTransparency = Transparency
            if SlidingLabel then
                SlidingLabel.TextTransparency = Transparency
            end
        end

        local function TweenPickerTextTransparency(Transparency: number)
            StopTween(PickerHoverTween)

            PickerHoverTween = TweenService:Create(Picker, Library.TweenInfo, {
                TextTransparency = Transparency,
            })
            PickerHoverTween:Play()

            if SlidingLabel then
                TweenService:Create(SlidingLabel, Library.TweenInfo, {
                    TextTransparency = Transparency,
                }):Play()
            end
        end

        table.insert(KeyPicker.Connections, Picker.MouseEnter:Connect(ObsGuard(function()
            if Library:MouseIsOverMenu() then
                return
            end
            if ParentObj.Disabled then
                return
            end

            TweenPickerTextTransparency(0)
        end)))

        table.insert(KeyPicker.Connections, Picker.MouseLeave:Connect(ObsGuard(function()
            if ParentObj.Disabled then
                return
            end

            TweenPickerTextTransparency(0.4)
        end)))

        if IsForButton then
            local Holder = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 21),
                Parent = ToggleLabel.Parent,
            })

            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalFlex = Enum.UIFlexAlignment.Fill,
                Padding = UDim.new(0, 9),
                Parent = Holder,
            })

            ToggleLabel.Parent = Holder
            Picker.Parent = Holder

            Picker.Size = UDim2.new(0, 18, 1, 0)
        end

        local KeybindsToggle = { Normal = KeyPicker.Mode ~= "Toggle" }
        do
            local Holder = New("TextButton", {
                AutoButtonColor = false,
                BackgroundColor3 = function()
                    return Library.Scheme.MainColor:Lerp(Library.Scheme.BackgroundColor, 0.65)
                end,
                BackgroundTransparency = 0,
                Size = UDim2.new(1, 0, 0, 24),
                Text = "",
                Visible = not Info.NoUI,
                Parent = Library.KeybindContainer,
            })
            KeyPicker.KeybindRow = Holder
            Holder:GetPropertyChangedSignal("Visible"):Connect(ObsGuard(function()
                if KeyPicker.ForceHidden and Holder.Visible then
                    Holder.Visible = false
                end
            end))

            New("UICorner", {
                CornerRadius = UDim.new(0, 4),
                Parent = Holder,
            })
            New("UIGradient", {
                Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.78, 0.78, 0.78)),
                Rotation = 90,
                Parent = Holder,
            })
            local RowStroke = New("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Color = "OutlineColor",
                Transparency = 1,
                Parent = Holder,
            })

            local RowGlow = New("Frame", {
                BackgroundColor3 = "AccentColor",
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 1),
                Parent = Holder,
            })
            New("UICorner", {
                CornerRadius = UDim.new(0, 4),
                Parent = RowGlow,
            })
            New("UIGradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 0.9),
                }),
                Parent = RowGlow,
            })

            local RowMarker = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = "AccentColor",
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(0, 3, 0.55, 0),
                ZIndex = 3,
                Parent = Holder,
            })
            New("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = RowMarker,
            })

            local Content = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                ZIndex = 2,
                Parent = Holder,
            })
            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Parent = Content,
            })
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 10),
                PaddingRight = UDim.new(0, 6),
                Parent = Content,
            })

            local KeyChip = New("TextLabel", {
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = function()
                    return Library:GetBetterColor(Library.Scheme.MainColor, 4)
                end,
                LayoutOrder = 1,
                Size = UDim2.fromOffset(0, 18),
                Text = "",
                TextSize = 11,
                ZIndex = 2,
                Parent = Content,
            })
            New("UICorner", {
                CornerRadius = UDim.new(0, 4),
                Parent = KeyChip,
            })
            local ChipStroke = New("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Color = "OutlineColor",
                Parent = KeyChip,
            })
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 5),
                PaddingRight = UDim.new(0, 5),
                Parent = KeyChip,
            })
            New("UISizeConstraint", {
                MinSize = Vector2.new(20, 18),
                Parent = KeyChip,
            })

            local Label = New("TextLabel", {
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                LayoutOrder = 2,
                Size = UDim2.new(0, 0, 1, 0),
                Text = "",
                TextSize = 14,
                TextTransparency = 0.3,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 2,
                Parent = Content,
            })

            local EmojiLabel = New("TextLabel", {
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                LayoutOrder = 3,
                Size = UDim2.new(0, 0, 1, 0),
                Text = "",
                TextSize = 14,
                TextTransparency = 0.3,
                TextXAlignment = Enum.TextXAlignment.Left,
                Visible = false,
                ZIndex = 2,
                Parent = Content,
            })
            local ModeTag = New("TextLabel", {
                AnchorPoint = Vector2.new(1, 0.5),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = "BackgroundColor",
                Position = UDim2.new(1, -6, 0.5, 0),
                Size = UDim2.fromOffset(0, 15),
                Text = "",
                TextSize = 11,
                TextTransparency = 0.4,
                Visible = false,
                ZIndex = 2,
                Parent = Holder,
            })
            New("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = ModeTag,
            })
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 6),
                PaddingRight = UDim.new(0, 6),
                Parent = ModeTag,
            })

            local Checkbox = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = function()
                    return Library:GetBetterColor(Library.Scheme.MainColor, 18)
                end,
                Position = UDim2.new(1, -6, 0.5, 0),
                Size = UDim2.fromOffset(28, 13),
                ZIndex = 2,
                Parent = Holder,
            })
            New("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = Checkbox,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 2),
                PaddingLeft = UDim.new(0, 2),
                PaddingRight = UDim.new(0, 2),
                PaddingTop = UDim.new(0, 2),
                Parent = Checkbox,
            })
            local SwitchStroke = New("UIStroke", {
                Color = "OutlineColor",
                Parent = Checkbox,
            })
            local Knob = New("Frame", {
                BackgroundColor3 = Color3.new(1, 1, 1),
                Size = UDim2.new(0, 15, 1, 0),
                ZIndex = 3,
                Parent = Checkbox,
            })
            New("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = Knob,
            })
            local KbKnobShadow = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = 0.86,
                BorderSizePixel = 0,
                Position = UDim2.new(0.5, 0, 0.5, 0.75),
                Size = UDim2.new(1, -3, 1, -1),
                ZIndex = 2,
                Parent = Knob,
            })
            New("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = KbKnobShadow,
            })
            SwitchStroke.Transparency = 1
            Library.Registry[SwitchStroke] = nil

            local Tail = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Position = UDim2.new(1, -6, 0.5, 0),
                Size = UDim2.new(0, 0, 1, 0),
                ZIndex = 2,
                Parent = Holder,
            })
            New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 6),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = Tail,
            })
            KeyChip.LayoutOrder = 1
            KeyChip.Parent = Tail
            ModeTag.AnchorPoint = Vector2.zero
            ModeTag.AutomaticSize = Enum.AutomaticSize.None
            ModeTag.Size = UDim2.fromOffset(40, 15)
            ModeTag.TextXAlignment = Enum.TextXAlignment.Center
            ModeTag.LayoutOrder = 2
            ModeTag.Parent = Tail
            local SwitchSlot = New("Frame", {
                BackgroundTransparency = 1,
                LayoutOrder = 3,
                Size = UDim2.fromOffset(40, 15),
                ZIndex = 2,
                Parent = Tail,
            })
            Checkbox.AnchorPoint = Vector2.new(1, 0.5)
            Checkbox.Position = UDim2.new(1, 0, 0.5, 0)
            Checkbox.Parent = SwitchSlot
            SwitchSlot.Visible = Checkbox.Visible
            Checkbox:GetPropertyChangedSignal("Visible"):Connect(ObsGuard(function()
                SwitchSlot.Visible = Checkbox.Visible
            end))

            local function PaintChip(State)
                local Unbound = KeyChip.Text == "—"
                local Lit = State == true and not Unbound
                local function IdleFill()
                    return Library:GetBetterColor(Library.Scheme.MainColor, 4)
                end
                KeyChip.BackgroundTransparency = Unbound and 1 or 0
                ChipStroke.Transparency = Unbound and 1 or 0
                Library.Registry[KeyChip] = Library.Registry[KeyChip] or {}
                Library.Registry[KeyChip].BackgroundColor3 = Lit and "AccentColor" or IdleFill
                Library.Registry[KeyChip].TextColor3 = Lit and "BackgroundColor" or "FontColor"
                Library.Registry[ChipStroke] = Library.Registry[ChipStroke] or {}
                Library.Registry[ChipStroke].Color = Lit and "AccentColor" or "OutlineColor"
                KeyChip.BackgroundColor3 = Lit and Library.Scheme.AccentColor or IdleFill()
                KeyChip.TextColor3 = Lit and Library.Scheme.BackgroundColor or Library.Scheme.FontColor
                ChipStroke.Color = Lit and Library.Scheme.AccentColor or Library.Scheme.OutlineColor
                KeyChip.TextTransparency = Unbound and 0.6 or (Lit and 0 or 0.15)
                Library.RgbDirty = true
            end

            local RowTween = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            local RowAccent = nil

            Holder.MouseEnter:Connect(ObsGuard(function()
                if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
                    return
                end
                if not KeybindsToggle.Normal then
                    TweenService:Create(RowStroke, RowTween, { Transparency = 0.45 }):Play()
                end
            end))
            Holder.MouseLeave:Connect(ObsGuard(function()
                TweenService:Create(RowStroke, RowTween, { Transparency = 1 }):Play()
            end))

            function KeybindsToggle:Display(State)
                State = State == true
                if KeybindsToggle.Shown == State then
                    return
                end
                KeybindsToggle.Shown = State

                pcall(function()
                    if State and not RowAccent then
                        RowAccent = {
                            Library:AddAccentGradient(Label, {}),
                        }
                    elseif not State and RowAccent then
                        for _, Handle in ipairs(RowAccent) do
                            if Handle then
                                Handle.Destroy()
                            end
                        end
                        RowAccent = nil
                    end
                end)

                pcall(function()
                    TweenService:Create(Label, RowTween, { TextTransparency = State and 0 or 0.35 }):Play()
                    TweenService:Create(EmojiLabel, RowTween, { TextTransparency = State and 0 or 0.35 }):Play()
                    if KeybindsToggle.RowIcon then
                        TweenService:Create(KeybindsToggle.RowIcon, RowTween, { ImageTransparency = State and 0 or 0.35 }):Play()
                    end
                    TweenService:Create(RowGlow, RowTween, { BackgroundTransparency = State and 0.88 or 1 }):Play()
                    TweenService:Create(RowMarker, RowTween, { BackgroundTransparency = State and 0 or 1 }):Play()
                    Checkbox.BackgroundColor3 = State and Library.Scheme.AccentColor or Library:GetBetterColor(Library.Scheme.MainColor, 18)
                    Knob.BackgroundColor3 = State and Color3.new(1, 1, 1) or Color3.new(1, 1, 1):Lerp(Library.Scheme.MainColor, 0.12)
                    PaintChip(State)
                    if Library.Registry[Checkbox] then
                        Library.Registry[Checkbox].BackgroundColor3 = State and "AccentColor" or function()
                            return Library:GetBetterColor(Library.Scheme.MainColor, 18)
                        end
                    end
                    Library.RgbDirty = true
                    TweenService:Create(Knob, Library.TweenInfo, {
                        AnchorPoint = Vector2.new(State and 1 or 0, 0),
                        Position = UDim2.fromScale(State and 1 or 0, 0),
                    }):Play()
                end)
            end

            function KeybindsToggle:SetParts(Key, Name, Mode)
                pcall(function()
                    local Unbound = Key == nil or Key == "" or Key == "None"
                    KeyChip.Text = Unbound and "—" or Key
                    PaintChip(KeybindsToggle.Shown)
                    local Plain, Emoji = Name or "", ""
                    pcall(function()
                        local PlainParts, EmojiParts = {}, {}
                        for _, Code in utf8.codes(Plain) do
                            if Code >= 0x2190 or Code == 0x200D then
                                table.insert(EmojiParts, utf8.char(Code))
                            else
                                table.insert(PlainParts, utf8.char(Code))
                            end
                        end
                        Plain = (table.concat(PlainParts):gsub("%s+$", ""))
                        Emoji = table.concat(EmojiParts)
                    end)
                    Label.Text = Plain
                    EmojiLabel.Text = Emoji
                    EmojiLabel.Visible = Emoji ~= ""
                    ModeTag.Text = Mode or ""
                    ModeTag.Visible = KeybindsToggle.Normal and ModeTag.Text ~= ""
                end)
                Library:QueueKeybindWidth()
            end

            local FlashInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
            function KeybindsToggle:Flash()
                if KeybindsToggle.Shown then
                    return
                end
                pcall(function()
                    local Accent = Library.Scheme.AccentColor
                    RowGlow.BackgroundTransparency = 0.66
                    TweenService:Create(RowGlow, FlashInfo, { BackgroundTransparency = 1 }):Play()
                    if KeyChip.Text ~= "—" then
                        ChipStroke.Color = Accent
                        TweenService:Create(ChipStroke, FlashInfo, { Color = Library.Scheme.OutlineColor }):Play()
                    end
                    ModeTag.BackgroundColor3 = Accent
                    ModeTag.TextTransparency = 0
                    TweenService:Create(ModeTag, FlashInfo, {
                        BackgroundColor3 = Library.Scheme.BackgroundColor,
                        TextTransparency = 0.4,
                    }):Play()
                end)
            end

            function KeybindsToggle:SetText(Text)
                Text = tostring(Text)
                local Key, Name, Mode = Text:match("^%[(.-)%]%s*(.-)%s*%((%w+)%)$")
                if Key then
                    KeybindsToggle:SetParts(Key, Name, Mode)
                else
                    KeybindsToggle:SetParts("", Text, "")
                end
            end

            function KeybindsToggle:SetVisibility(Visibility)
                pcall(function() Holder.Visible = Visibility end)
                Library:QueueKeybindWidth()
            end

            function KeybindsToggle:SetNormal(Normal)
                KeybindsToggle.Normal = Normal

                pcall(function()
                    Holder.Active = not Normal or KeyPicker.Mode == "Press" or KeyPicker.Mode == "Hold"
                    Checkbox.Visible = not Normal
                    ModeTag.Visible = Normal and ModeTag.Text ~= ""
                end)
                Library:QueueKeybindWidth()
            end

            KeyPicker.DoClick = function(...) end --// make luau lsp shut up
            table.insert(KeyPicker.Connections, Holder.MouseButton1Click:Connect(ObsGuard(function()
                if KeybindsToggle.Normal then
                    if KeyPicker.Mode == "Press" and not ParentObj.Disabled then
                        KeyPicker:DoClick()
                        KeyPicker:Update()
                    end
                    return
                end

                KeyPicker.Toggled = not KeyPicker.Toggled
                KeyPicker:DoClick()
                KeyPicker:Update()
            end)))

            local function ReleaseTouchHold()
                if KeyPicker.TouchHeld then
                    KeyPicker.TouchHeld = false
                    Library.TouchHeldPickers[KeyPicker] = nil
                    KeyPicker:Update()
                end
            end
            KeyPicker.ReleaseTouchHold = ReleaseTouchHold
            if not Library.TouchHeldPickers then
                Library.TouchHeldPickers = {}
                Library:GiveSignal(UserInputService.InputEnded:Connect(ObsGuard(function(Input)
                    if Input.UserInputType ~= Enum.UserInputType.Touch and Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                    end
                    for Held in pairs(Library.TouchHeldPickers) do
                        Held.ReleaseTouchHold()
                    end
                end)))
            end
            table.insert(KeyPicker.Connections, Holder.MouseButton1Down:Connect(ObsGuard(function()
                if KeybindsToggle.Normal and KeyPicker.Mode == "Hold" and not ParentObj.Disabled then
                    KeyPicker.TouchHeld = true
                    Library.TouchHeldPickers[KeyPicker] = true
                    KeyPicker:Update()
                end
            end)))
            table.insert(KeyPicker.Connections, Holder.MouseButton1Up:Connect(ObsGuard(ReleaseTouchHold)))
            table.insert(KeyPicker.Connections, Holder.MouseLeave:Connect(ObsGuard(ReleaseTouchHold)))

            KeybindsToggle.Holder = Holder
            KeybindsToggle.Label = Label
            KeybindsToggle.Checkbox = Checkbox
            KeybindsToggle.KeyChip = KeyChip
            KeybindsToggle.EmojiLabel = EmojiLabel
            if Info.Icon ~= nil then
                pcall(function()
                    local Art, FullColor = Library:ResolveInlineIcon(Info.Icon)
                    if not Art or not Art.Url or Art.Url == "" then
                        return
                    end
                    local RowIcon = New("ImageLabel", {
                        BackgroundTransparency = 1,
                        Image = Art.Url,
                        ImageRectOffset = Art.ImageRectOffset or Vector2.zero,
                        ImageRectSize = Art.ImageRectSize or Vector2.zero,
                        ImageTransparency = 0.35,
                        LayoutOrder = 4,
                        Size = UDim2.fromOffset(12, 12),
                        ZIndex = 2,
                        Parent = EmojiLabel.Parent,
                    })
                    if FullColor then
                        pcall(function()
                            Library:RemoveFromRegistry(RowIcon)
                        end)
                        RowIcon.ImageColor3 = Color3.new(1, 1, 1)
                    else
                        RowIcon.ImageColor3 = Library.Scheme.FontColor
                        Library.Registry[RowIcon] = { ImageColor3 = "FontColor" }
                    end
                    KeybindsToggle.RowIcon = RowIcon
                    Library:QueueKeybindWidth()
                end)
            end
            KeybindsToggle.ModeTag = ModeTag
            KeybindsToggle.Loaded = true
            table.insert(Library.KeybindToggles, KeybindsToggle)
            if Library.HideKeyChips == nil then
                Library.HideKeyChips = Library.IsMobile
            end
            KeyChip.Visible = not Library.HideKeyChips
            for _, Measured in ipairs({ Label, EmojiLabel, ModeTag }) do
                Measured:GetPropertyChangedSignal("TextBounds"):Connect(ObsGuard(function()
                    if Library.QueueKeybindWidth then
                        Library:QueueKeybindWidth()
                    end
                end))
            end
        end

        local ModeButtons = {}
        local TotalModeButtons = GetTableSize(Info.Modes)
        local MenuTable = Library:AddContextMenu(Picker, UDim2.fromOffset(62, 0), function()
            return { Picker.AbsoluteSize.X + 1.5, 0.5 }
        end, 1, function(Active: boolean)
            PickerCorner.TopRightRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
            PickerCorner.BottomRightRadius = Active and UDim.new(0, 0) or UDim.new(0, Library.CornerRadius / 2)
        end, false, if TotalModeButtons == 1 then "no_left" else "no_top_left", "KeyPicker")
        KeyPicker.Menu = MenuTable

        for Index, Mode in Info.Modes do
            local ModeButton = {}

            local Button = New("TextButton", {
                BackgroundColor3 = "MainColor",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, IsForButton and 21 or (TotalModeButtons == 1 and 18 or 19)),
                Text = Mode,
                TextSize = 14,
                TextTransparency = 0.5,
                Parent = MenuTable.Menu,
            })
            
            if Index == 1 and TotalModeButtons == 1 then
                table.insert(Library.SpecificCorners, New("UICorner", {
                    TopLeftRadius = UDim.new(0, 0),
                    TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
                    BottomLeftRadius = UDim.new(0, 0),
                    BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Button,
                }))
            elseif Index == 1 then
                table.insert(Library.SpecificCorners, New("UICorner", {
                    TopLeftRadius = UDim.new(0, 0),
                    TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
                    BottomLeftRadius = UDim.new(0, 0),
                    BottomRightRadius = UDim.new(0, 0),
                    Parent = Button,
                }))
            elseif Index == TotalModeButtons then
                table.insert(Library.SpecificCorners, New("UICorner", {
                    TopLeftRadius = UDim.new(0, 0),
                    TopRightRadius = UDim.new(0, 0),
                    BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
                    BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Button,
                }))
            end

            function ModeButton:Select()
                for _, Button in ModeButtons do
                    Button:Deselect()
                end

                KeyPicker.Mode = Mode

                Button.BackgroundTransparency = 0
                Button.TextTransparency = 0

                MenuTable:Close()
                if KeyPicker.Update then
                    KeyPicker:Update()
                end
            end

            function ModeButton:Deselect()
                KeyPicker.Mode = nil

                Button.BackgroundTransparency = 1
                Button.TextTransparency = 0.5
            end

            table.insert(KeyPicker.Connections, Button.MouseButton1Click:Connect(ObsGuard(function()
                ModeButton:Select()
            end)))

            table.insert(KeyPicker.Connections, Button.MouseEnter:Connect(ObsGuard(function()
                if KeyPicker.Mode == Mode then
                    return
                end

                TweenService:Create(Button, Library.TweenInfo, {
                    BackgroundTransparency = 0.7,
                    TextTransparency = 0.1,
                }):Play()
            end)))

            table.insert(KeyPicker.Connections, Button.MouseLeave:Connect(ObsGuard(function()
                if KeyPicker.Mode == Mode then
                    return
                end

                TweenService:Create(Button, Library.TweenInfo, {
                    BackgroundTransparency = 1,
                    TextTransparency = 0.5,
                }):Play()
            end)))

            if KeyPicker.Mode == Mode then
                ModeButton:Select()
            end

            ModeButtons[Mode] = ModeButton
        end

        local SetPickingState = function(State, SkipUpdate: boolean?)
            Picking = State
            Library.IsPicking = State

            pcall(function()
                local Target = (IsForButton and SlideOverflow and SlidingLabel) or Picker
                if State then
                    Library:AddTextShimmer(Target)
                else
                    Library:RemoveTextShimmer(Target)
                end
            end)

            if ParentObj then
                ParentObj.AnyKeyPickerPicking = Picking
            end

            if IsForButton then
                ToggleLabel.Visible = not Picking
                LastDisplayText = nil
                RunService.RenderStepped:Wait()
            end

            if SkipUpdate ~= true then
                (KeyPicker :: any):Update()
            end
        end

        function KeyPicker:Display(PickerText)
            if Library.Unloaded then
                return
            end

            local DisplayText = PickerText or KeyPicker.DisplayValue
            if IsForButton and SlideOverflow then
                if LastPickerWidth == Picker.AbsoluteSize.X then
                    return
                end

                local X, _Y = Library:GetTextBounds(
                    DisplayText,
                    Picker.FontFace,
                    Picker.TextSize,
                    10000
                )

                SlidingLabel.Text = DisplayText

                local OffsetScale = X + 9
                local PickerWidth = math.min(OffsetScale, MaxPickerWidth)
                Picker.Size = UDim2.new(0, PickerWidth, 1, 0)

                if OffsetScale > PickerWidth then
                    SlidingLabel.TextXAlignment = Enum.TextXAlignment.Left
                    SlidingLabel.Size = UDim2.new(0, OffsetScale, 1, 0)
                    SlidingLabel.Position = UDim2.fromOffset(4.5, 0)

                    RunService.RenderStepped:Wait()

                    local RealPickerWidth = Picker.AbsoluteSize.X
                    if RealPickerWidth <= 0 then RealPickerWidth = PickerWidth end

                    LastPickerWidth = RealPickerWidth

                    local OverflowDistance = OffsetScale - RealPickerWidth - 4.5
                    if OverflowDistance > 0 then
                        CancelSlidingTweens()

                        local Duration = OverflowDistance / 25
                        local TweenInfo = TweenInfo.new(
                            Duration,
                            Enum.EasingStyle.Linear, Enum.EasingDirection.InOut
                        )

                        SlideForwardTween = TweenService:Create(SlidingLabel, TweenInfo, {
                            Position = UDim2.fromOffset(-OverflowDistance, 0)
                        })

                        SlideBackTween = TweenService:Create(SlidingLabel, TweenInfo, {
                            Position = UDim2.fromOffset(4.5, 0)
                        })

                        SlideForwardTween:Play()

                        if SlideForwardConn then
                            SlideForwardConn:Disconnect()
                        end
                        if SlideBackConn then
                            SlideBackConn:Disconnect()
                        end
                        SlideForwardConn = SlideForwardTween.Completed:Connect(ObsGuard(HandleForwardTween))
                        SlideBackConn = SlideBackTween.Completed:Connect(ObsGuard(HandleBackTween))
                    else
                        CancelSlidingTweens()

                        SlidingLabel.TextXAlignment = Enum.TextXAlignment.Center
                        SlidingLabel.Size = UDim2.new(1, 0, 1, 0)
                        SlidingLabel.Position = UDim2.new(0, 0, 0, 0)
                    end
                else
                    CancelSlidingTweens()

                    SlidingLabel.TextXAlignment = Enum.TextXAlignment.Center
                    SlidingLabel.Size = UDim2.new(1, 0, 1, 0)
                    SlidingLabel.Position = UDim2.new(0, 0, 0, 0)
                end
            else
                local X, Y = Library:GetTextBounds(
                    DisplayText,
                    Picker.FontFace,
                    Picker.TextSize,
                    ToggleLabel.AbsoluteSize.X
                )
                Picker.Text = DisplayText
                Picker.Size = IsForButton and UDim2.new(0, X + 9, 1, 0) or UDim2.fromOffset((X + 9), (Y + 4))
            end
        end

        function KeyPicker:Update()
            local Disabled = ParentObj.Disabled == true

            if Disabled and Picking then
                SetPickingState(false, true)
            end

            KeyPicker:Display()

            Picker.Active = not Disabled
            ApplyPickerTextTransparency(Disabled and 0.8 or 0.4)

            if Disabled then
                if MenuTable.Active then
                    MenuTable:Close()
                end
            end

            if Info.NoUI then
                return
            end

            -- Official escape hatch for hosts that want this keybind row hidden
            -- in the Keybinds menu while the linked feature is off, instead of
            -- always showing every registered keybind regardless of feature
            -- state. Set KeyPicker.ForceHidden = true/false and call :Update()
            -- (or rely on the next Update() this function already gets called
            -- from elsewhere) to apply -- no external polling/signal-watching
            -- needed to fight this function's own SetVisibility(true) below.
            if KeyPicker.ForceHidden then
                KeybindsToggle:SetVisibility(false)
                return
            end

            if KeyPicker.Mode == "Toggle" and ParentObj.Type == "Toggle" and ParentObj.Disabled then
                KeybindsToggle:SetVisibility(false)
                return
            end

            local State = KeyPicker:GetState()
            local ShowToggle = Library.ShowToggleFrameInKeybinds and KeyPicker.Mode == "Toggle"

            if KeyPicker.SyncToggleState and ParentObj.Value ~= State then
                ParentObj:SetValue(State)
            end

            if KeybindsToggle.Loaded then
                if ShowToggle then
                    KeybindsToggle:SetNormal(false)
                else
                    KeybindsToggle:SetNormal(true)
                end

                KeybindsToggle:SetText(("[%s] %s (%s)"):format(KeyPicker.DisplayValue, KeyPicker.Text, KeyPicker.Mode))
                KeybindsToggle:SetVisibility(true)
                if KeyPicker.Mode == "Toggle" and ParentObj.Type == "Toggle" then
                    KeybindsToggle:Display(ParentObj.Value == true)
                else
                    KeybindsToggle:Display(State)
                end
            end
        end

        function KeyPicker:GetState()
            if KeyPicker.Mode == "Always" then
                return true
            elseif KeyPicker.Mode == "Hold" then
                if KeyPicker.TouchHeld then
                    return true
                end
                local Key = KeyPicker.Value
                if Key == "None" then
                    return false
                end

                if not AreModifiersHeld(KeyPicker.Modifiers) then
                    return false
                end

                if Picking then
                    return false
                end

                if SpecialKeys[Key] ~= nil then
                    if Library.Toggled then
                        return false
                    end

                    return UserInputService:IsMouseButtonPressed(SpecialKeys[Key])
                        and not UserInputService:GetFocusedTextBox()
                else
                    return UserInputService:IsKeyDown(Enum.KeyCode[Key] :: any) and not UserInputService:GetFocusedTextBox()
                end
            else
                return KeyPicker.Toggled
            end
        end

        function KeyPicker:OnChanged(Func)
            KeyPicker.Changed = Func
        end

        function KeyPicker:OnClick(Func)
            KeyPicker.Clicked = Func
        end

        function KeyPicker:DoClick()
            if Picking or ParentObj.Disabled then
                return
            end

            if KeyPicker.Mode == "Press" then
                if KeyPicker.Toggled and Info.WaitForCallback == true then
                    return
                end

                KeyPicker.Toggled = true
                if KeybindsToggle and KeybindsToggle.Flash then
                    KeybindsToggle:Flash()
                end
            end

            Library:SafeCallback(KeyPicker.Callback, KeyPicker.Toggled)
            Library:SafeCallback(KeyPicker.Clicked, KeyPicker.Toggled)

            if IsForButton then
                Library:SafeCallback(ParentObj.Func, KeyPicker.Toggled)
			end
			
			if Library.ToggleKeybind == KeyPicker and Library.Toggle then
                Library:Toggle()
            end

            if KeyPicker.Mode == "Press" then
                KeyPicker.Toggled = false
            end
        end

        function KeyPicker:RunChanged(IsKeyValid, KeyCode)
            if ParentObj.Disabled then
                return
            end

            if IsKeyValid == nil or KeyCode == nil then
                IsKeyValid, KeyCode = pcall(function()
                    if KeyPicker.Value == "None" then
                        return nil
                    end

                    if SpecialKeys[KeyPicker.Value] == nil then
                        return Enum.KeyCode[KeyPicker.Value]
                    end

                    return SpecialKeys[KeyPicker.Value]
                end)
            end

            local NewModifiers = ConvertToInputModifiers(KeyPicker.Modifiers)
            Library:SafeCallback(KeyPicker.ChangedCallback, KeyCode, NewModifiers)
            Library:SafeCallback(KeyPicker.Changed, KeyCode, NewModifiers)
        end

        function KeyPicker:SetValue(Data)
            local Key, Mode, Modifiers = Data[1], Data[2], Data[3]

            local IsKeyValid, KeyCode = pcall(function()
                if Key == "None" then
                    Key = nil
                    return nil
                end

                if SpecialKeys[Key] == nil then
                    return Enum.KeyCode[Key]
                end

                return SpecialKeys[Key]
            end)

            if Key == nil then
                KeyPicker.Value = "None"
            elseif IsKeyValid then
                KeyPicker.Value = Key
            else
                KeyPicker.Value = "Unknown"
            end

            KeyPicker.Modifiers =
                VerifyModifiers(if typeof(Modifiers) == "table" then Modifiers else KeyPicker.Modifiers)
            KeyPicker.DisplayValue = if GetTableSize(KeyPicker.Modifiers) > 0
                then (table.concat(KeyPicker.Modifiers, " + ") .. " + " .. KeyPicker.Value)
                else KeyPicker.Value

            if ModeButtons[Mode] then
                ModeButtons[Mode]:Select()
            end

            KeyPicker:Update()
            KeyPicker:RunChanged(IsKeyValid, KeyCode)
        end

        function KeyPicker:SetText(Text)
            KeybindsToggle:SetText(Text)
            KeyPicker:Update()
        end

        local function RunPick()
            if Picking or Library.IsPicking or ParentObj.Disabled then
                return
            end

            SetPickingState(true)

            if IsForButton and SlideOverflow then
                KeyPicker:Display("Press key")
            else
                Picker.Text = "Press key"
                Picker.Size = IsForButton and UDim2.new(0, 62, 1, 0) or UDim2.fromOffset(62, 18)
            end

            -- Wait for any input --
            local ActiveModifiers = {}
            local CurrentInput = nil

            local IsValidInput = function(InputObj)
                if InputObj.KeyCode == Enum.KeyCode.Escape then
                    return true
                end

                local IsMod = IsModifierInput(InputObj)
                local KeyName
                if SpecialKeysInput[InputObj.UserInputType] ~= nil then
                    KeyName = SpecialKeysInput[InputObj.UserInputType]
                elseif InputObj.UserInputType == Enum.UserInputType.Keyboard then
                    if IsMod then
                        KeyName = ModifiersInput[InputObj.KeyCode]
                    else
                        KeyName = InputObj.KeyCode.Name
                    end
                end

                if KeyName then
                    if IsMod then
                        if KeyPicker.WhitelistedModifiers and #KeyPicker.WhitelistedModifiers > 0 and not table.find(KeyPicker.WhitelistedModifiers, KeyName) then
                            return false
                        end

                        if KeyPicker.BlacklistedModifiers and table.find(KeyPicker.BlacklistedModifiers, KeyName) then
                            return false
                        end
                    else
                        if KeyPicker.Whitelisted and #KeyPicker.Whitelisted > 0 and not table.find(KeyPicker.Whitelisted, KeyName) then
                            return false
                        end

                        if KeyPicker.Blacklisted and table.find(KeyPicker.Blacklisted, KeyName) then
                            return false
                        end
                    end
                end

                return true
            end

            -- Wait for the first valid InputBegan --
            while true do
                local InputObj = UserInputService.InputBegan:Wait()
                if Library.Unloaded or KeyPicker.Destroyed then
                    return
                end
                if InputObj.UserInputType == Enum.UserInputType.Touch or InputObj.UserInputType.Name:find("^Gamepad") then
                    SetPickingState(false)
                    return
                end
                if UserInputService:GetFocusedTextBox() ~= nil then
                    SetPickingState(false)
                    return
                end

                if IsValidInput(InputObj) then
                    CurrentInput = InputObj
                    break
                end
            end

            -- If it's a modifier key, we wait for either its release or another input --
            while IsModifierInput(CurrentInput) do
                if CurrentInput.KeyCode == Enum.KeyCode.Escape then
                    break
                end

                -- Display the current state including the current modifier key --
                local ModName = ModifiersInput[CurrentInput.KeyCode]
                if ModName then
                    local text = if #ActiveModifiers > 0 then table.concat(ActiveModifiers, " + ") .. " + " .. ModName .. " + ..." else ModName .. " + ..."
                    KeyPicker:Display(text)
                end

                local NextInput = nil
                local Released = false

                local BeganConn
                local EndedConn

                BeganConn = UserInputService.InputBegan:Connect(function(InputObj)
                    if UserInputService:GetFocusedTextBox() ~= nil then
                        return
                    end
                    if IsValidInput(InputObj) then
                        NextInput = InputObj
                    end
                end)

                EndedConn = UserInputService.InputEnded:Connect(function(InputObj)
                    if InputObj.KeyCode == CurrentInput.KeyCode then
                        Released = true
                    end
                end)

                repeat
                    task.wait()
                until Released or NextInput or UserInputService:GetFocusedTextBox() ~= nil or Library.Unloaded

                if BeganConn then BeganConn:Disconnect() end
                if EndedConn then EndedConn:Disconnect() end

                if UserInputService:GetFocusedTextBox() ~= nil or Library.Unloaded then
                    SetPickingState(false)
                    return
                end

                if Released then
                    break -- Use modifier key as bind
                elseif NextInput then
                    -- Add another modifier or continue to normal key
                    local OldModName = ModifiersInput[CurrentInput.KeyCode]
                    if OldModName and not table.find(ActiveModifiers, OldModName) then
                        ActiveModifiers[#ActiveModifiers + 1] = OldModName
                    end

                    CurrentInput = NextInput
                    if CurrentInput.KeyCode == Enum.KeyCode.Escape then
                        break
                    end
                end
            end

            if CurrentInput.KeyCode == Enum.KeyCode.Escape then
                SetPickingState(false)
                return
            end

            local Key = "Unknown"
            if SpecialKeysInput[CurrentInput.UserInputType] ~= nil then
                Key = SpecialKeysInput[CurrentInput.UserInputType]
            elseif CurrentInput.UserInputType == Enum.UserInputType.Keyboard then
                Key = CurrentInput.KeyCode == Enum.KeyCode.Backspace and "None" or CurrentInput.KeyCode.Name
            end

            ActiveModifiers = if CurrentInput.KeyCode == Enum.KeyCode.Backspace or Key == "Unknown" then {} else ActiveModifiers

            KeyPicker.Toggled = if ParentObj.Type == "Toggle" then ParentObj.Value else false
            KeyPicker:SetValue({ Key, KeyPicker.Mode, ActiveModifiers })

            repeat
                task.wait()
            until not IsInputDown(CurrentInput) or UserInputService:GetFocusedTextBox()

            SetPickingState(false)
        end

        table.insert(KeyPicker.Connections, Picker.MouseButton1Click:Connect(ObsGuard(function()
            local PickOk = xpcall(RunPick, ObsErrorHandler)
            if not PickOk and Picking then
                pcall(SetPickingState, false, true)
            end
        end)))

        table.insert(KeyPicker.Connections, Picker.MouseButton2Click:Connect(ObsGuard(function()
            if ParentObj.Disabled then
                return
            end

            MenuTable:Toggle()
        end)))

        table.insert(KeyPicker.Connections, UserInputService.InputBegan:Connect(ObsGuard(function(Input: InputObject)
            if Library.Unloaded then
                return
            end

            local IsMouse = IsMouseClickInput(Input)
            if
                ParentObj.Disabled
                or KeyPicker.Mode == "Always"
                or KeyPicker.Value == "Unknown"
                or KeyPicker.Value == "None"
                or Picking
                or Library.IsPicking
                or UserInputService:GetFocusedTextBox()
                or (IsMouse and Library.Toggled)
            then
                return
            end

            local Key = KeyPicker.Value
            local HoldingModifiers = AreModifiersHeld(KeyPicker.Modifiers)
            local HoldingKey = false

            if
                Key
                and HoldingModifiers == true
                and (
                    SpecialKeysInput[Input.UserInputType] == Key
                    or (Input.UserInputType == Enum.UserInputType.Keyboard and Input.KeyCode.Name == Key)
                )
            then
                HoldingKey = true
            end

            if HoldingKey then
                if KeyPicker.Mode == "Toggle" then
                    KeyPicker.Toggled = not KeyPicker.Toggled
                    KeyPicker:DoClick()
                elseif KeyPicker.Mode == "Press" then
                    KeyPicker:DoClick()
                elseif KeyPicker.Mode == "Hold" then
                    InputChanged = Input.Changed:Connect(ObsGuard(function()
                        if KeyPicker:GetState() then
                            return
                        end

                        KeyPicker:Update()
                        if InputChanged and InputChanged.Connected then
                            InputChanged:Disconnect()
                            InputChanged = nil
                        end
                    end))
                end

                KeyPicker:Update()
            end
        end)))

        KeyPicker:Update()

        if not ParentObj.Addons then
            ParentObj.Addons = {}
        end

        table.insert(ParentObj.Addons, KeyPicker)

        KeyPicker.Default = KeyPicker.Value
        KeyPicker.DefaultModifiers = table.clone(KeyPicker.Modifiers or {})

        function KeyPicker:Destroy()
            KeyPicker.Destroyed = true
            if Picking then
                Picking = false
                Library.IsPicking = false
            end
            KeyPicker.TouchHeld = false
            if Library.TouchHeldPickers then
                Library.TouchHeldPickers[KeyPicker] = nil
            end

            if SlideForwardConn then
                SlideForwardConn:Disconnect()
                SlideForwardConn = nil
            end

            if SlideBackConn then
                SlideBackConn:Disconnect()
                SlideBackConn = nil
            end

            if KeyPicker.Connections then
                for _, Connection in KeyPicker.Connections do
                    Connection:Disconnect()
                end
            end

            if KeybindsToggle and KeybindsToggle.Loaded then
                if KeybindsToggle.Holder then 
                    KeybindsToggle.Holder:Destroy()
                end
                local KTIdx = table.find(Library.KeybindToggles, KeybindsToggle)
                if KTIdx then
                    table.remove(Library.KeybindToggles, KTIdx)
                end
            end

            if MenuTable then 
                MenuTable:Destroy() 
            end

            if IsForButton and SlideOverflow then
                if SlideForwardTween then 
                    SlideForwardTween:Destroy() 
                end

                if SlideBackTween then 
                    SlideBackTween:Destroy() 
                end
            end

            if Picker then
                Picker:Destroy()
            end

            if ParentObj and ParentObj.Addons then
                local AddonIdx = table.find(ParentObj.Addons, KeyPicker)
                
                if AddonIdx then 
                    table.remove(ParentObj.Addons, AddonIdx) 
                end
            end

            Options[Idx] = nil
        end

        Options[Idx] = KeyPicker

        return self
    end

    local HueSequenceTable = {}
    for Hue = 0, 1, 0.1 do
        table.insert(HueSequenceTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)))
    end
    function Funcs:AddColorPicker(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.ColorPicker)

        local ParentObj = self
        local ToggleLabel = ParentObj.TextLabel

        local ColorPicker = {
            Connections = {},
            Destroyed = false,

            Value = Info.Default,

            Transparency = Info.Transparency or 0,
            Title = Info.Title,

            Callback = Info.Callback,
            Changed = Info.Changed,

            Type = "ColorPicker",
        }
        ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = ColorPicker.Value:ToHSV()

        local Holder = New("TextButton", {
            BackgroundColor3 = ColorPicker.Value,
            Size = UDim2.fromOffset(18, 18),
            Text = "",
            Parent = ToggleLabel,
        })

        local HolderStroke = New("UIStroke", {
            Color = Library:GetDarkerColor(ColorPicker.Value),
            Parent = Holder,
        })

        local ColorPickerCorner = New("UICorner", {
            TopLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            Parent = Holder,
        }); table.insert(Library.SpecificCorners, ColorPickerCorner)

        local HolderTransparency = New("ImageLabel", {
            Image = CustomImageManager.GetAsset("TransparencyTexture"),
            ImageTransparency = (1 - ColorPicker.Transparency),
            ScaleType = Enum.ScaleType.Tile,
            Position = UDim2.new(0, -1, 0, -1),
            Size = UDim2.new(1, 2, 1, 2),
            TileSize = UDim2.fromOffset(9, 9),
            Parent = Holder,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = HolderTransparency,
            })
        )

        --// Color Menu \\--
        local MapSize = Library.IsMobile and 120 or 160
        local BarWidth = 14
        local MenuWidth = MapSize + BarWidth + 6 + 12
        if Info.Transparency then
            MenuWidth += BarWidth + 6
        end

        local ColorMenu
        local FooterCorner
        ColorMenu = Library:AddContextMenu(
            Holder,
            UDim2.fromOffset(MenuWidth, 0),
            function()
                return { 0.5, Holder.AbsoluteSize.Y + 1.5 }
            end,
            1, function(Active: boolean)
                if Active then
                    ColorPicker.OpenedValue = ColorPicker.Value
                    if ColorPicker.RefreshRecents then
                        ColorPicker.RefreshRecents()
                    end
                elseif ColorPicker.OpenedValue and ColorPicker.Value ~= ColorPicker.OpenedValue then
                    ColorClipboard.Remember(ColorPicker.Value)
                end
            end, false, "no_top_left", "Dropdown")
        ColorMenu.List.Padding = UDim.new(0, 0)
        ColorPicker.ColorMenu = ColorMenu

        --// Content Holder \\--
        local ContentHolder = New("Frame", {
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            Parent = ColorMenu.Menu,
        })
        New("UIListLayout", {
            Padding = UDim.new(0, 8),
            Parent = ContentHolder,
        })
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 6),
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6),
            PaddingTop = UDim.new(0, 6),
            Parent = ContentHolder,
        })

        --// Footer \\--
        local FooterHeight = Library.IsMobile and 30 or 22

        local FooterBackground = New("Frame", {
            BackgroundColor3 = function()
                return Library:GetBetterColor(Library.Scheme.BackgroundColor, 4)
            end,
            Size = UDim2.new(1, 0, 0, FooterHeight),
            Parent = ColorMenu.Menu,
        })
        table.insert(
            Library.SpecificCorners,
            New("UICorner", {
                TopLeftRadius = UDim.new(0, 0),
                TopRightRadius = UDim.new(0, 0),
                BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
                BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = FooterBackground,
            })
        )
        Library:MakeLine(FooterBackground, {
            Position = UDim2.fromScale(0, 0),
            Size = UDim2.new(1, 0, 0, 1),
        })

        local FooterBar = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Parent = FooterBackground,
        })
        New("UIPadding", {
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, Info.Resizable and (FooterHeight + 4) or 6),
            Parent = FooterBar,
        })

        local FooterInfoLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            TextSize = 14,
            TextTransparency = 0.5,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = FooterBar,
        })

        local function RefreshFooterInfo()
            FooterInfoLabel.Text = string.format(
                "#%s • %d, %d, %d",
                ColorPicker.Value:ToHex(),
                math.floor(ColorPicker.Value.R * 255),
                math.floor(ColorPicker.Value.G * 255),
                math.floor(ColorPicker.Value.B * 255)
            )
        end
        RefreshFooterInfo()
        FooterInfoLabel.Visible = false

        local RecentRow = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Parent = FooterBar,
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 4),
            SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Parent = RecentRow,
        })
        local RecentHint = New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            LayoutOrder = 99,
            Size = UDim2.new(0, 0, 1, 0),
            Text = "Recent colours show here",
            TextSize = 12,
            TextTransparency = 0.6,
            Parent = RecentRow,
        })

        function ColorPicker.RefreshRecents()
            for _, Child in ipairs(RecentRow:GetChildren()) do
                if Child:IsA("TextButton") then
                    Child:Destroy()
                end
            end
            local List = ColorClipboard.Recents()
            RecentHint.Visible = #List == 0
            local MenuScale = 1
            pcall(function()
                local Found = ColorMenu.Menu:FindFirstChildOfClass("UIScale")
                if Found then
                    MenuScale = math.max(Found.Scale, 0.01)
                end
            end)
            local Room = RecentRow.AbsoluteSize.X / MenuScale
            local Fit = Room > 0 and math.max(1, math.floor((Room + 4) / 18)) or 5
            for Index, Hex in ipairs(List) do
                if Index > Fit then
                    break
                end
                local Ok, Color = pcall(Color3.fromHex, Hex)
                if Ok then
                    local Swatch = New("TextButton", {
                        AutoButtonColor = false,
                        BackgroundColor3 = Color,
                        LayoutOrder = Index,
                        Size = UDim2.fromOffset(14, 14),
                        Text = "",
                        Parent = RecentRow,
                    })
                    New("UICorner", {
                        CornerRadius = UDim.new(0, 3),
                        Parent = Swatch,
                    })
                    New("UIStroke", {
                        Color = "OutlineColor",
                        Parent = Swatch,
                    })
                    Swatch.MouseButton1Click:Connect(ObsGuard(function()
                        ColorPicker:SetValueRGB(Color, ColorPicker.Transparency)
                    end))
                end
            end
        end
        ColorPicker.RefreshRecents()

        if typeof(ColorPicker.Title) == "string" then
            New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 8),
                Text = ColorPicker.Title,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = ContentHolder,
            })
        end

        local ColorHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, MapSize),
            Parent = ContentHolder,
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 6),
            Parent = ColorHolder,
        })

        --// Sat Map
        local SatVipMap = New("ImageButton", {
            BackgroundColor3 = ColorPicker.Value,
            Image = CustomImageManager.GetAsset("SaturationMap"),
            Size = UDim2.fromOffset(MapSize, MapSize),
            Parent = ColorHolder,
        })
        New("UICorner", {
            CornerRadius = UDim.new(0, 6),
            Parent = SatVipMap,
        })

        local SatVibCursor = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = ColorPicker.Value,
            Size = UDim2.fromOffset(12, 12),
            ZIndex = SatVipMap.ZIndex + 2,
            Parent = SatVipMap,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = SatVibCursor,
        })
        local SatVibRing = Instance.new("UIStroke")
        SatVibRing.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        SatVibRing.Color = Color3.new(1, 1, 1)
        SatVibRing.Thickness = 2
        SatVibRing.Parent = SatVibCursor
        local SatVibShadow = Instance.new("Frame")
        SatVibShadow.AnchorPoint = Vector2.new(0.5, 0.5)
        SatVibShadow.BackgroundTransparency = 1
        SatVibShadow.Position = UDim2.fromScale(0.5, 0.5)
        SatVibShadow.Size = UDim2.new(1, 6, 1, 6)
        SatVibShadow.ZIndex = SatVibCursor.ZIndex - 1
        SatVibShadow.Parent = SatVibCursor
        local SatVibShadowCorner = Instance.new("UICorner")
        SatVibShadowCorner.CornerRadius = UDim.new(1, 0)
        SatVibShadowCorner.Parent = SatVibShadow
        local SatVibShadowStroke = Instance.new("UIStroke")
        SatVibShadowStroke.Color = Color3.new(0, 0, 0)
        SatVibShadowStroke.Transparency = 0.55
        SatVibShadowStroke.Thickness = 1
        SatVibShadowStroke.Parent = SatVibShadow

        --// Hue
        local HueSelector = New("TextButton", {
            Size = UDim2.fromOffset(BarWidth, MapSize),
            Text = "",
            Parent = ColorHolder,
        })
        New("UIGradient", {
            Color = ColorSequence.new(HueSequenceTable),
            Rotation = 90,
            Parent = HueSelector,
        })
        New("UICorner", {
            CornerRadius = UDim.new(0, 5),
            Parent = HueSelector,
        })

        local HueCursor = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = "WhiteColor",
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.5, ColorPicker.Hue),
            Size = UDim2.new(1, 4, 0, 6),
            Parent = HueSelector,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = HueCursor,
        })
        New("UIStroke", {
            Color = "DarkColor",
            Thickness = 1.5,
            Parent = HueCursor,
        })

        --// Alpha
        local TransparencySelector, TransparencyColor, TransparencyCursor
        if Info.Transparency then
            TransparencySelector = New("ImageButton", {
                Image = CustomImageManager.GetAsset("TransparencyTexture"),
                ScaleType = Enum.ScaleType.Tile,
                Size = UDim2.fromOffset(BarWidth, MapSize),
                TileSize = UDim2.fromOffset(8, 8),
                Parent = ColorHolder,
            })
            New("UICorner", {
                CornerRadius = UDim.new(0, 5),
                Parent = TransparencySelector,
            })

            TransparencyColor = New("Frame", {
                BackgroundColor3 = ColorPicker.Value,
                Size = UDim2.fromScale(1, 1),
                Parent = TransparencySelector,
            })
            New("UICorner", {
                CornerRadius = UDim.new(0, 5),
                Parent = TransparencyColor,
            })
            New("UIGradient", {
                Rotation = 90,
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(1, 1),
                }),
                Parent = TransparencyColor,
            })

            TransparencyCursor = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = "WhiteColor",
                BorderSizePixel = 0,
                Position = UDim2.fromScale(0.5, ColorPicker.Transparency),
                Size = UDim2.new(1, 4, 0, 6),
                Parent = TransparencySelector,
            })
            New("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = TransparencyCursor,
            })
            New("UIStroke", {
                Color = "DarkColor",
                Thickness = 1.5,
                Parent = TransparencyCursor,
            })
        end

        local DarkBar = New("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = Color3.new(1, 1, 1),
            Size = UDim2.new(1, 0, 0, Library.IsMobile and 14 or 10),
            Text = "",
            Parent = ContentHolder,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = DarkBar,
        })
        local DarkGradient = New("UIGradient", {
            Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, 1)),
            Parent = DarkBar,
        })
        local DarkCursor = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = "WhiteColor",
            BorderSizePixel = 0,
            Position = UDim2.fromScale(ColorPicker.Vib, 0.5),
            Size = UDim2.new(0, 6, 1, 4),
            ZIndex = DarkBar.ZIndex + 1,
            Parent = DarkBar,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = DarkCursor,
        })
        New("UIStroke", {
            Color = "DarkColor",
            Thickness = 1.5,
            Parent = DarkCursor,
        })

        --// Resizing \\--
        local ResizeGrabber
        if Info.Resizable then
            local BaseMapSize = 200
            local BaseBarWidth = BarWidth
            local BasePadding = 6
            local MinMapSize = 140

            ColorPicker.MapWidth = MapSize
            ColorPicker.MapHeight = MapSize

            local function GetBarWidth(MapWidth)
                return math.clamp(math.floor((MapWidth / BaseMapSize) * BaseBarWidth + 0.5), 12, 24)
            end

            local function GetContentWidth(MapWidth)
                local CurrentBarWidth = GetBarWidth(MapWidth)
                local Width = MapWidth + CurrentBarWidth + BasePadding
                if Info.Transparency then
                    Width += (CurrentBarWidth + BasePadding)
                end

                return Width + 12
            end

            local FixedVerticalOverhead = 6 + 6 + 8 + 20 + 8 + 20 + 8 + (Library.IsMobile and 14 or 10) + 8 + (Library.IsMobile and 20 or 16) + FooterHeight
            if typeof(ColorPicker.Title) == "string" then
                FixedVerticalOverhead += 8 + 8
            end

            local function ClampToViewport(NewWidth, NewHeight)
                local Camera = workspace.CurrentCamera
                if not Camera then
                    return NewWidth, NewHeight
                end

                local ViewportSize = Camera.ViewportSize
                local ScreenMargin = 12

                local MaxWidth = ViewportSize.X - ColorMenu.Menu.AbsolutePosition.X - ScreenMargin
                local MaxHeight = ViewportSize.Y - ColorMenu.Menu.AbsolutePosition.Y - ScreenMargin - FixedVerticalOverhead

                while NewWidth > MinMapSize and GetContentWidth(NewWidth) > MaxWidth do
                    NewWidth -= 4
                end

                if NewHeight > MaxHeight then
                    NewHeight = math.max(MinMapSize, math.floor(MaxHeight))
                end

                return NewWidth, NewHeight
            end

            local function UpdateColorMenuSize(NewWidth, NewHeight)
                NewWidth = math.max(MinMapSize, math.floor(NewWidth + 0.5))
                NewHeight = math.max(MinMapSize, math.floor(NewHeight + 0.5))
                NewWidth, NewHeight = ClampToViewport(NewWidth, NewHeight)

                if NewWidth == ColorPicker.MapWidth and NewHeight == ColorPicker.MapHeight then
                    return
                end

                local CurrentBarWidth = GetBarWidth(NewWidth)
                local CursorSize = math.clamp(math.floor((math.min(NewWidth, NewHeight) / BaseMapSize) * 12 + 0.5), 10, 16)

                ColorHolder.Size = UDim2.new(1, 0, 0, NewHeight)
                SatVipMap.Size = UDim2.fromOffset(NewWidth, NewHeight)
                SatVibCursor.Size = UDim2.fromOffset(CursorSize, CursorSize)
                HueSelector.Size = UDim2.new(0, CurrentBarWidth, 0, NewHeight)

                if TransparencySelector then
                    TransparencySelector.Size = UDim2.new(0, CurrentBarWidth, 0, NewHeight)
                end

                ColorPicker.MapWidth = NewWidth
                ColorPicker.MapHeight = NewHeight
                ColorMenu:SetSize(UDim2.new(0, GetContentWidth(NewWidth), 0, 0))
            end

            ResizeGrabber = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Position = UDim2.new(1, -Library.CornerRadius / 4, 0, 0),
                Size = UDim2.fromScale(1, 1),
                SizeConstraint = Enum.SizeConstraint.RelativeYY,
                Text = "",
                Parent = FooterBackground,
            })
            New("ImageLabel", {
                Image = ResizeIcon and ResizeIcon.Url or "",
                ImageColor3 = "FontColor",
                ImageRectOffset = ResizeIcon and ResizeIcon.ImageRectOffset or Vector2.zero,
                ImageRectSize = ResizeIcon and ResizeIcon.ImageRectSize or Vector2.zero,
                ImageTransparency = 0.5,
                Position = UDim2.fromOffset(2, 2),
                Size = UDim2.new(1, -4, 1, -4),
                Parent = ResizeGrabber,
            })
            if Library.IsMobile then
                ResizeGrabber.AnchorPoint = Vector2.new(1, 1)
                ResizeGrabber.Position = UDim2.new(1, 0, 1, 0)
                ResizeGrabber.SizeConstraint = Enum.SizeConstraint.RelativeXY
                ResizeGrabber.Size = UDim2.fromOffset(40, 40)
                for _, Icon in ipairs(ResizeGrabber:GetChildren()) do
                    if Icon:IsA("ImageLabel") then
                        Icon.AnchorPoint = Vector2.new(1, 1)
                        Icon.Position = UDim2.new(1, -4, 1, -6)
                        Icon.Size = UDim2.fromOffset(16, 16)
                    end
                end
            end

            table.insert(ColorPicker.Connections, ResizeGrabber.InputBegan:Connect(ObsGuard(function(Input: InputObject)
                if not IsClickInput(Input) then
                    return
                end
                local WasLocked = Library.CantDragForced
                Library.CantDragForced = true
                local StartMouse = (Input.UserInputType == Enum.UserInputType.Touch) and Vector2.new(Input.Position.X, Input.Position.Y) or Vector2.new(Mouse.X, Mouse.Y)
                local StartWidth = ColorPicker.MapWidth
                local StartHeight = ColorPicker.MapHeight

                while IsDragInput(Input) and not ColorPicker.Destroyed do
                    local Delta = ((Input.UserInputType == Enum.UserInputType.Touch) and Vector2.new(Input.Position.X, Input.Position.Y) or Vector2.new(Mouse.X, Mouse.Y)) - StartMouse
                    UpdateColorMenuSize(StartWidth + Delta.X, StartHeight + Delta.Y)

                    RunService.RenderStepped:Wait()
                end

                Library.CantDragForced = WasLocked
            end)))
        end

        local RainbowButton, RainbowTrack, RainbowKnob, RainbowLabel
        if Info.Rainbow ~= false then
            RainbowButton = New("TextButton", {
                AutoButtonColor = false,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, Library.IsMobile and 20 or 16),
                Text = "",
                Parent = ContentHolder,
            })

            RainbowLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -46, 1, 0),
                Text = "Rainbow",
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = RainbowButton,
            })

            RainbowTrack = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = "MainColor",
                BorderSizePixel = 0,
                Position = UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(36, 16),
                Parent = RainbowButton,
            })
            pcall(function()
                Library:RemoveFromRegistry(RainbowTrack)
            end)
            New("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = RainbowTrack,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 2),
                PaddingLeft = UDim.new(0, 2),
                PaddingRight = UDim.new(0, 2),
                PaddingTop = UDim.new(0, 2),
                Parent = RainbowTrack,
            })

            RainbowKnob = New("Frame", {
                BackgroundColor3 = "WhiteColor",
                BorderSizePixel = 0,
                Size = UDim2.new(0, 20, 1, 0),
                ZIndex = RainbowTrack.ZIndex + 1,
                Parent = RainbowTrack,
            })
            pcall(function()
                Library:RemoveFromRegistry(RainbowKnob)
            end)
            New("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = RainbowKnob,
            })
        end

        local InfoHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            Parent = ContentHolder,
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalFlex = Enum.UIFlexAlignment.Fill,
            Padding = UDim.new(0, 8),
            Parent = InfoHolder,
        })

        local HueBox = New("TextBox", {
            BackgroundColor3 = "MainColor",
            ClearTextOnFocus = false,
            Size = UDim2.fromScale(1, 1),
            Text = "#??????",
            TextSize = 14,
            Parent = InfoHolder,
        })

        local HueBoxStroke = New("UIStroke", {
            Color = "OutlineColor",
            Parent = HueBox,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = HueBox,
            })
        )

        local RgbBox = New("TextBox", {
            BackgroundColor3 = "MainColor",
            ClearTextOnFocus = false,
            Size = UDim2.fromScale(1, 1),
            Text = "?, ?, ?",
            TextSize = 14,
            Parent = InfoHolder,
        })

        local RgbBoxStroke = New("UIStroke", {
            Color = "OutlineColor",
            Parent = RgbBox,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = RgbBox,
            })
        )

        --// Context Menu \\--
        local ContextMenu = Library:AddContextMenu(Holder, UDim2.fromOffset(93, 0), function()
            return { Holder.AbsoluteSize.X + 1.5, 0.5 }
        end, 1, function(Active: boolean)
        end, false, "no_top_left", "Dropdown")
        ColorPicker.ContextMenu = ContextMenu
        ContextMenu.List.Padding = UDim.new(0, 6)
        do
            local function CreateButton(Text, Func)
                local Button = New("TextButton", {
                    BackgroundColor3 = "MainColor",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 21),
                    Text = Text,
                    TextSize = 14,
                    Parent = ContextMenu.Menu,
                })

                table.insert(ColorPicker.Connections, Button.MouseButton1Click:Connect(ObsGuard(function()
                    Library:SafeCallback(Func)
                    ContextMenu:Close()
                end)))

                table.insert(ColorPicker.Connections, Button.MouseEnter:Connect(ObsGuard(function()
                    TweenService:Create(Button, Library.TweenInfo, {
                        BackgroundTransparency = 0.7,
                    }):Play()
                end)))

                table.insert(ColorPicker.Connections, Button.MouseLeave:Connect(ObsGuard(function()
                    TweenService:Create(Button, Library.TweenInfo, {
                        BackgroundTransparency = 1,
                    }):Play()
                end)))
            end

            CreateButton("Copy color", function()
                ColorClipboard.Write(ColorPicker.Value, ColorPicker.Transparency)
            end)

            ColorPicker.SetValueRGB = function(...) end --// make luau lsp shut up
            CreateButton("Paste color", function()
                local Color, Transparency = ColorClipboard.Read()
                if Color then
                    ColorPicker:SetValueRGB(Color, Transparency or ColorPicker.Transparency)
                end
            end)

            if setclipboard then
                CreateButton("Copy Hex", function()
                    setclipboard(tostring(ColorPicker.Value:ToHex()))
                end)

                CreateButton("Copy RGB", function()
                    setclipboard(table.concat({
                        math.floor(ColorPicker.Value.R * 255),
                        math.floor(ColorPicker.Value.G * 255),
                        math.floor(ColorPicker.Value.B * 255),
                    }, ", "))
                end)
            end
        end

        --// Copy/Paste Buttons \\--
        local ActionHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            Parent = ContentHolder,
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalFlex = Enum.UIFlexAlignment.Fill,
            Padding = UDim.new(0, 8),
            Parent = ActionHolder,
        })

        local CopyColorButton = New("TextButton", {
            BackgroundColor3 = "MainColor",
            Size = UDim2.fromScale(1, 1),
            Text = "Copy color",
            TextSize = 14,
            Parent = ActionHolder,
        })
        New("UIStroke", {
            Color = "OutlineColor",
            Parent = CopyColorButton,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = CopyColorButton,
            })
        )

        local PasteColorButton = New("TextButton", {
            BackgroundColor3 = "MainColor",
            Size = UDim2.fromScale(1, 1),
            Text = "Paste color",
            TextSize = 14,
            Parent = ActionHolder,
        })
        New("UIStroke", {
            Color = "OutlineColor",
            Parent = PasteColorButton,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = PasteColorButton,
            })
        )

        local CopyColorOriginalText = CopyColorButton.Text
        local PasteColorOriginalText = PasteColorButton.Text
        local CopyColorResetId = 0
        local PasteColorResetId = 0

        table.insert(ColorPicker.Connections, CopyColorButton.MouseEnter:Connect(ObsGuard(function()
            TweenService:Create(CopyColorButton, Library.TweenInfo, {
                BackgroundColor3 = Library:GetBetterColor(Library.Scheme.MainColor, 10),
            }):Play()
        end)))

        table.insert(ColorPicker.Connections, CopyColorButton.MouseLeave:Connect(ObsGuard(function()
            TweenService:Create(CopyColorButton, Library.TweenInfo, {
                BackgroundColor3 = Library.Scheme.MainColor,
            }):Play()
        end)))

        table.insert(ColorPicker.Connections, PasteColorButton.MouseEnter:Connect(ObsGuard(function()
            TweenService:Create(PasteColorButton, Library.TweenInfo, {
                BackgroundColor3 = Library:GetBetterColor(Library.Scheme.MainColor, 10),
            }):Play()
        end)))

        table.insert(ColorPicker.Connections, PasteColorButton.MouseLeave:Connect(ObsGuard(function()
            TweenService:Create(PasteColorButton, Library.TweenInfo, {
                BackgroundColor3 = Library.Scheme.MainColor,
            }):Play()
        end)))

        table.insert(ColorPicker.Connections, CopyColorButton.MouseButton1Click:Connect(ObsGuard(function()
            ColorClipboard.Write(ColorPicker.Value, ColorPicker.Transparency)

            CopyColorResetId += 1
            local ThisResetId = CopyColorResetId
            CopyColorButton.Text = "Copied #" .. ColorPicker.Value:ToHex()

            task.delay(1, function()
                if ColorPicker.Destroyed or ThisResetId ~= CopyColorResetId then
                    return
                end

                CopyColorButton.Text = CopyColorOriginalText
            end)
        end)))

        table.insert(ColorPicker.Connections, PasteColorButton.MouseButton1Click:Connect(ObsGuard(function()
            PasteColorResetId += 1
            local ThisResetId = PasteColorResetId

            local Color, Transparency = ColorClipboard.Read()
            if not Color then
                PasteColorButton.Text = "Ctrl+V into the box"
                task.defer(function()
                    pcall(function()
                        HueBox:CaptureFocus()
                        HueBox.SelectionStart = 1
                        HueBox.CursorPosition = #HueBox.Text + 1
                    end)
                end)
            else
                ColorPicker:SetValueRGB(Color, Transparency or ColorPicker.Transparency)
                PasteColorButton.Text = "Pasted #" .. Color:ToHex()
            end

            task.delay(1, function()
                if ColorPicker.Destroyed or ThisResetId ~= PasteColorResetId then
                    return
                end

                PasteColorButton.Text = PasteColorOriginalText
            end)
        end)))

        --// End \\--
        function ColorPicker:SetHSVFromRGB(Color)
            ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib = Color:ToHSV()
        end

        function ColorPicker:Display()
            if Library.Unloaded then
                return
            end

            ColorPicker.Value = Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, ColorPicker.Vib)

            SatVipMap.BackgroundColor3 = Color3.fromHSV(ColorPicker.Hue, 1, 1)
            if TransparencyColor then
                TransparencyColor.BackgroundColor3 = ColorPicker.Value
            end

            SatVibCursor.Position = UDim2.fromScale(ColorPicker.Sat, 1 - ColorPicker.Vib)
            SatVibCursor.BackgroundColor3 = ColorPicker.Value
            DarkGradient.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(ColorPicker.Hue, ColorPicker.Sat, 1))
            DarkCursor.Position = UDim2.fromScale(ColorPicker.Vib, 0.5)
            HueCursor.Position = UDim2.fromScale(0.5, ColorPicker.Hue)
            if TransparencyCursor then
                TransparencyCursor.Position = UDim2.fromScale(0.5, ColorPicker.Transparency)
            end

            if not HueBox:IsFocused() then
                HueBox.Text = "#" .. ColorPicker.Value:ToHex()
            end
            if not RgbBox:IsFocused() then
                RgbBox.Text = table.concat({
                    math.floor(ColorPicker.Value.R * 255),
                    math.floor(ColorPicker.Value.G * 255),
                    math.floor(ColorPicker.Value.B * 255),
                }, ", ")
            end

            RefreshFooterInfo()
        end

        local function ApplyHolderVisual(Disabled: boolean)
            Holder.Active = not Disabled
            HolderStroke.Transparency = Disabled and 0.5 or 0
            Holder.BackgroundTransparency = Disabled and 0.5 or 0

            if Disabled then
                Holder.BackgroundColor3 = ColorPicker.Value:Lerp(Library.Scheme.BackgroundColor, 0.5)
                HolderTransparency.ImageTransparency = math.clamp((1 - ColorPicker.Transparency) + 0.5, 0, 1)
            else
                Holder.BackgroundColor3 = ColorPicker.Value
                HolderStroke.Color = Library:GetDarkerColor(ColorPicker.Value)
                HolderTransparency.ImageTransparency = (1 - ColorPicker.Transparency)
            end
        end

        function ColorPicker:RunChanged()
            if ParentObj.Disabled then
                return
            end

            Library:SafeCallback(ColorPicker.Callback, ColorPicker.Value)
            Library:SafeCallback(ColorPicker.Changed, ColorPicker.Value)
        end

        function ColorPicker:Update()
            ColorPicker:Display()

            local Disabled = ParentObj.Disabled == true
            ApplyHolderVisual(Disabled)

            if Disabled then
                if ColorMenu.Active then
                    ColorMenu:Close()
                end

                if ContextMenu.Active then
                    ContextMenu:Close()
                end
            end

            ColorPicker:RunChanged()
        end

        function ColorPicker:Preview()
            ColorPicker:Display()
            ApplyHolderVisual(ParentObj.Disabled == true)
        end

        function ColorPicker:OnChanged(Func)
            ColorPicker.Changed = Func
        end

        function ColorPicker:SetValue(HSV, Transparency)
            if typeof(HSV) == "Color3" then
                ColorPicker:SetValueRGB(HSV, Transparency)
                return
            end

            local Color = Color3.fromHSV(HSV[1], HSV[2], HSV[3])
            ColorPicker.Transparency = Info.Transparency and Transparency or 0
            ColorPicker:SetHSVFromRGB(Color)
            ColorPicker:Update()
        end

        function ColorPicker:SetValueRGB(Color, Transparency)
            ColorPicker.Transparency = Info.Transparency and Transparency or 0
            ColorPicker:SetHSVFromRGB(Color)
            ColorPicker:Update()
        end

        ColorPicker.Rainbow = false

        local function PaintRainbowButton(Animate)
            if not RainbowButton then
                return
            end

            local On = ColorPicker.Rainbow == true
            local function OffTrack()
                return Library:GetBetterColor(Library.Scheme.MainColor, 18)
            end
            local function OffKnob()
                return Color3.new(1, 1, 1):Lerp(Library.Scheme.MainColor, 0.12)
            end
            local Track = On and Library.Scheme.AccentColor or OffTrack()
            local Knob = On and Color3.new(1, 1, 1) or OffKnob()
            local Offset = On and 1 or 0
            local Previous = Library.Registry[RainbowTrack] and Library.Registry[RainbowTrack].BackgroundColor3
            Library.Registry[RainbowTrack] = { BackgroundColor3 = On and "AccentColor" or OffTrack }
            Library.Registry[RainbowKnob] = { BackgroundColor3 = On and function() return Color3.new(1, 1, 1) end or OffKnob }
            if (Previous == "AccentColor") ~= On then
                Library.RgbDirty = true
            end

            if Animate then
                TweenService:Create(RainbowTrack, Library.TweenInfo, { BackgroundColor3 = Track }):Play()
                TweenService:Create(RainbowKnob, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    AnchorPoint = Vector2.new(Offset, 0),
                    BackgroundColor3 = Knob,
                    Position = UDim2.fromScale(Offset, 0),
                }):Play()
                TweenService:Create(RainbowLabel, Library.TweenInfo, { TextTransparency = On and 0 or 0.25 }):Play()
            else
                RainbowTrack.BackgroundColor3 = Track
                RainbowKnob.BackgroundColor3 = Knob
                RainbowKnob.AnchorPoint = Vector2.new(Offset, 0)
                RainbowKnob.Position = UDim2.fromScale(Offset, 0)
                RainbowLabel.TextTransparency = On and 0 or 0.25
            end
        end

        function ColorPicker:SetRainbow(Value)
            Value = Value == true

            if ColorPicker.RainbowConn then
                ColorPicker.RainbowConn:Disconnect()
                ColorPicker.RainbowConn = nil
            end

            local Changed = ColorPicker.Rainbow ~= Value
            ColorPicker.Rainbow = Value
            PaintRainbowButton(true)

            if Value then
                local Hue = ColorPicker.Hue
                local Frame = 0

                ColorPicker.Sat = 1
                if ColorPicker.Vib < 0.05 then
                    ColorPicker.Vib = 1
                end
                ColorPicker:Update()

                ColorPicker.RainbowConn = RunService.Heartbeat:Connect(ObsGuard(function()
                    if ColorPicker.Destroyed or Library.Unloaded then
                        if ColorPicker.RainbowConn then
                            ColorPicker.RainbowConn:Disconnect()
                            ColorPicker.RainbowConn = nil
                        end
                        return
                    end

                    Frame += 1
                    if Frame % 3 ~= 0 then
                        return
                    end

                    if Library.RgbEnabled and type(Library.RgbHue) == "number" then
                        Hue = Library.RgbHue
                    else
                        Hue = ((tonumber(ColorPicker.Hue) or Hue) + 0.0015) % 1
                    end

                    ColorPicker.Hue = Hue
                    ColorPicker.Sat = 1
                    if Library.Toggled or ColorMenu.Active then
                        ColorPicker:Update()
                    else
                        ColorPicker.Value = Color3.fromHSV(Hue, 1, ColorPicker.Vib)
                        ColorPicker:RunChanged()
                    end
                end))
                table.insert(ColorPicker.Connections, ColorPicker.RainbowConn)
            end

            if Changed then
                Library:SafeCallback(Info.RainbowChanged, Value)
            end
        end

        if RainbowButton then
            PaintRainbowButton(false)

            table.insert(ColorPicker.Connections, RainbowButton.MouseButton1Click:Connect(ObsGuard(function()
                if ParentObj.Disabled then
                    return
                end

                ColorPicker:SetRainbow(not ColorPicker.Rainbow)
            end)))

        end

        table.insert(ColorPicker.Connections, Holder.MouseButton1Click:Connect(ObsGuard(function()
            if ParentObj.Disabled then
                return
            end

            ColorMenu:Toggle()
        end)))

        table.insert(ColorPicker.Connections, Holder.MouseButton2Click:Connect(ObsGuard(function()
            if ParentObj.Disabled then
                return
            end

            ContextMenu:Toggle()
        end)))

        table.insert(ColorPicker.Connections, SatVipMap.InputBegan:Connect(ObsGuard(function(Input: InputObject)
            while IsDragInput(Input) and not ColorPicker.Destroyed do
                local MinX = SatVipMap.AbsolutePosition.X
                local MaxX = MinX + SatVipMap.AbsoluteSize.X
                local Pointer = (Input.UserInputType == Enum.UserInputType.Touch) and Vector2.new(Input.Position.X, Input.Position.Y) or Vector2.new(Mouse.X, Mouse.Y)
                local LocationX = math.clamp(Pointer.X, MinX, MaxX)

                local MinY = SatVipMap.AbsolutePosition.Y
                local MaxY = MinY + SatVipMap.AbsoluteSize.Y
                local LocationY = math.clamp(Pointer.Y, MinY, MaxY)

                local OldSat = ColorPicker.Sat
                local OldVib = ColorPicker.Vib
                ColorPicker.Sat = (LocationX - MinX) / (MaxX - MinX)
                ColorPicker.Vib = 1 - ((LocationY - MinY) / (MaxY - MinY))

                if ColorPicker.Sat ~= OldSat or ColorPicker.Vib ~= OldVib then
                    ColorPicker:Update()
                end

                RunService.RenderStepped:Wait()
            end
        end)))

        table.insert(ColorPicker.Connections, DarkBar.InputBegan:Connect(ObsGuard(function(Input: InputObject)
            while IsDragInput(Input) and not ColorPicker.Destroyed do
                local Min = DarkBar.AbsolutePosition.X
                local Max = Min + DarkBar.AbsoluteSize.X
                local Pointer = (Input.UserInputType == Enum.UserInputType.Touch) and Input.Position.X or Mouse.X
                local Old = ColorPicker.Vib
                ColorPicker.Vib = math.clamp((math.clamp(Pointer, Min, Max) - Min) / math.max(Max - Min, 1), 0, 1)

                if ColorPicker.Vib ~= Old then
                    ColorPicker:Update()
                end

                RunService.RenderStepped:Wait()
            end
        end)))

        table.insert(ColorPicker.Connections, HueSelector.InputBegan:Connect(ObsGuard(function(Input: InputObject)
            if ColorPicker.Rainbow and IsDragInput(Input) then
                ColorPicker:SetRainbow(false)
            end

            while IsDragInput(Input) and not ColorPicker.Destroyed do
                local Min = HueSelector.AbsolutePosition.Y
                local Max = Min + HueSelector.AbsoluteSize.Y
                local Location = math.clamp(((Input.UserInputType == Enum.UserInputType.Touch) and Vector2.new(Input.Position.X, Input.Position.Y) or Vector2.new(Mouse.X, Mouse.Y)).Y, Min, Max)

                local OldHue = ColorPicker.Hue
                ColorPicker.Hue = (Location - Min) / (Max - Min)

                if ColorPicker.Hue ~= OldHue then
                    ColorPicker:Update()
                end

                RunService.RenderStepped:Wait()
            end
        end)))
        
        if TransparencySelector then
            table.insert(ColorPicker.Connections, TransparencySelector.InputBegan:Connect(ObsGuard(function(Input: InputObject)
                while IsDragInput(Input) and not ColorPicker.Destroyed do
                    local Min = TransparencySelector.AbsolutePosition.Y
                    local Max = TransparencySelector.AbsolutePosition.Y + TransparencySelector.AbsoluteSize.Y
                    local Location = math.clamp(((Input.UserInputType == Enum.UserInputType.Touch) and Vector2.new(Input.Position.X, Input.Position.Y) or Vector2.new(Mouse.X, Mouse.Y)).Y, Min, Max)

                    local OldTransparency = ColorPicker.Transparency
                    ColorPicker.Transparency = (Location - Min) / (Max - Min)

                    if ColorPicker.Transparency ~= OldTransparency then
                        ColorPicker:Update()
                    end

                    RunService.RenderStepped:Wait()
                end
            end)))
        end

        table.insert(ColorPicker.Connections, HueBox.FocusLost:Connect(ObsGuard(function()
            local Color = ColorClipboard.Parse(HueBox.Text)
            if Color then
                if ColorPicker.Rainbow then
                    ColorPicker:SetRainbow(false)
                end
                ColorPicker:SetHSVFromRGB(Color)
            end

            ColorPicker:Update()
        end)))

        table.insert(ColorPicker.Connections, RgbBox.FocusLost:Connect(ObsGuard(function()
            local Color = ColorClipboard.Parse(RgbBox.Text)
            if Color then
                if ColorPicker.Rainbow then
                    ColorPicker:SetRainbow(false)
                end
                ColorPicker:SetHSVFromRGB(Color)
            end

            ColorPicker:Update()
        end)))

        for _, BoxPair in { 
            { HueBox, HueBoxStroke }, 
            { RgbBox, RgbBoxStroke } 
        } do
            local TextBoxInstance, Stroke = BoxPair[1], BoxPair[2]

            table.insert(ColorPicker.Connections, TextBoxInstance.Focused:Connect(ObsGuard(function()
                Library.Registry[Stroke].Color = "AccentColor"
                TweenService:Create(Stroke, Library.TweenInfo, {
                    Color = Library.Scheme.AccentColor,
                }):Play()
            end)))

            table.insert(ColorPicker.Connections, TextBoxInstance.FocusLost:Connect(ObsGuard(function()
                Library.Registry[Stroke].Color = "OutlineColor"
                TweenService:Create(Stroke, Library.TweenInfo, {
                    Color = Library.Scheme.OutlineColor,
                }):Play()
            end)))
        end

        ColorPicker:Update()

        if not ParentObj.Addons then
            ParentObj.Addons = {}
        end

        table.insert(ParentObj.Addons, ColorPicker)

        ColorPicker.Default = ColorPicker.Value

        function ColorPicker:Destroy()
            ColorPicker.Destroyed = true

            if ColorPicker.Connections then
                for _, Connection in ColorPicker.Connections do
                    Connection:Disconnect()
                end
            end

            if ColorMenu then 
                ColorMenu:Destroy() 
            end

            if ResizeGrabber then
                ResizeGrabber:Destroy()
            end

            if ContextMenu then 
                ContextMenu:Destroy() 
            end

            if Holder then 
                Holder:Destroy() 
            end

            if ParentObj and ParentObj.Addons then
                local AddonIdx = table.find(ParentObj.Addons, ColorPicker)
                
                if AddonIdx then 
                    table.remove(ParentObj.Addons, AddonIdx) 
                end
            end

            Options[Idx] = nil
        end

        Options[Idx] = ColorPicker

        return self
    end

    BaseAddons.__index = Funcs
    BaseAddons.__namecall = function(_, Key, ...)
        return Funcs[Key](...)
    end
end

local BaseGroupbox = {}
do
    local Funcs = {}

    function Funcs:AddDivider(...)
        if self.Destroyed then return nil end

        local Params = select(1, ...)
        local Text
        local MarginTop = 0
        local MarginBottom = 0

        if typeof(Params) == "table" then
            Text = Params.Text
            MarginTop = Params.MarginTop or Params.Margin or 0
            MarginBottom = Params.MarginBottom or Params.Margin or 0
        elseif typeof(Params) == "string" then
            Text = Params
        end

        local Groupbox = self
        local Container = Groupbox.Container

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 6 + MarginTop + MarginBottom),
            Parent = Container,
        })

        local InnerHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingTop = UDim.new(0, MarginTop),
            PaddingBottom = UDim.new(0, MarginBottom),
            Parent = Holder,
        })

        if Text then
            local TextLabel = New("TextLabel", {
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 0),
                Text = Text,
                TextSize = 14,
                TextTransparency = 0.5,
                TextXAlignment = Enum.TextXAlignment.Center,
                Parent = InnerHolder,
            })

            local X, _ = Library:GetTextBounds(Text, TextLabel.FontFace, TextLabel.TextSize, TextLabel.AbsoluteSize.X)
            local SizeX = X // 2 + 10

            local LeftLine = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = function()
                    return Library:GetBetterColor(Library.Scheme.OutlineColor, 9)
                end,
                BorderSizePixel = 0,
                Position = UDim2.fromScale(0, 0.5),
                Size = UDim2.new(0.5, -SizeX, 0, 1),
                Parent = InnerHolder,
            })
            New("UIGradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.85),
                    NumberSequenceKeypoint.new(0.18, 0),
                    NumberSequenceKeypoint.new(1, 0),
                }),
                Parent = LeftLine,
            })
            local RightLine = New("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundColor3 = function()
                    return Library:GetBetterColor(Library.Scheme.OutlineColor, 9)
                end,
                BorderSizePixel = 0,
                Position = UDim2.fromScale(1, 0.5),
                Size = UDim2.new(0.5, -SizeX, 0, 1),
                Parent = InnerHolder,
            })
            New("UIGradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(0.82, 0),
                    NumberSequenceKeypoint.new(1, 0.85),
                }),
                Parent = RightLine,
            })
        else
            local Line = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = function()
                    return Library:GetBetterColor(Library.Scheme.OutlineColor, 9)
                end,
                BorderSizePixel = 0,
                Position = UDim2.fromScale(0, 0.5),
                Size = UDim2.new(1, 0, 0, 1),
                Parent = InnerHolder,
            })
            New("UIGradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.85),
                    NumberSequenceKeypoint.new(0.1, 0),
                    NumberSequenceKeypoint.new(0.9, 0),
                    NumberSequenceKeypoint.new(1, 0.85),
                }),
                Parent = Line,
            })
        end

        Groupbox:Resize()

        local Divider = {
            Connections = {},
            Destroyed = false,

            Holder = Holder,
            Text = Text,
            MarginTop = MarginTop,
            MarginBottom = MarginBottom,
            Type = "Divider",

            Parent = Groupbox,
        }

        function Divider:SetVisible(Value)
            Holder.Visible = Value == true
            Groupbox:Resize()
        end

        function Divider:Destroy()
            Divider.Destroyed = true

            if Divider.Connections then
                for _, Connection in Divider.Connections do
                    Connection:Disconnect()
                end
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Divider)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
        end

        table.insert(Groupbox.Elements, Divider)
        return Divider
    end

    function Funcs:AddLabel(...)
        if self.Destroyed then return nil end

        local Data = {}
        local Addons = {}

        local First = select(1, ...)
        local Second = select(2, ...)

        if typeof(First) == "table" or typeof(Second) == "table" then
            local Params = typeof(First) == "table" and First or Second

            Data.Text = Params.Text or ""
            Data.DoesWrap = Params.DoesWrap or false
            Data.Size = Params.Size or 14
            Data.Icon = Params.Icon
            Data.Visible = if typeof(Params.Visible) == "boolean" then Params.Visible else true
            Data.Idx = typeof(Second) == "table" and First or nil
        else
            Data.Text = First or ""
            Data.DoesWrap = Second or false
            Data.Size = 14
            Data.Visible = true
            Data.Idx = select(3, ...) or nil
        end

        local Groupbox = self
        local Container = Groupbox.Container

        local Label = {
            Connections = {},
            Destroyed = false,

            Text = Data.Text,
            DoesWrap = Data.DoesWrap,

            Addons = Addons,

            Visible = Data.Visible,
            Type = "Label",

            Parent = Groupbox,
        }

        local TextLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Text = Label.Text,
            TextSize = Data.Size,
            TextWrapped = Label.DoesWrap,
            TextXAlignment = Groupbox.IsKeyTab and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
            Visible = Label.Visible,
            Parent = Container,
        })


        function Label:Display()
            if not Label.DoesWrap then
                return
            end

            local Width = TextLabel.AbsoluteSize.X
            if Width <= 0 then return end

            local _, Y = Library:GetTextBounds(Label.Text, TextLabel.FontFace, TextLabel.TextSize, Width)
            TextLabel.Size = UDim2.new(1, 0, 0, Y + 4)
        end

        function Label:SetVisible(Visible: boolean)
            Label.Visible = Visible

            TextLabel.Visible = Label.Visible
            Groupbox:Resize()
        end

        function Label:SetText(Text: string)
            Label.Text = Text
            TextLabel.Text = Text

            Label:Display()
            Groupbox:Resize()
        end

        if Label.DoesWrap then
            Label:Display()

            local Last = TextLabel.AbsoluteSize
            table.insert(Label.Connections, TextLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(ObsGuard(function()
                if TextLabel.AbsoluteSize == Last then
                    return
                end

                Label:Display()
                Last = TextLabel.AbsoluteSize

                Groupbox:Resize()
            end)))
        else
            local LabelLayout = New("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                Padding = UDim.new(0, 6),
                Parent = TextLabel,
            })

            if Data.Icon ~= nil then
                pcall(function()
                    local Art, FullColor = Library:ResolveInlineIcon(Data.Icon)
                    if not Art or not Art.Url or Art.Url == "" then
                        return
                    end
                    LabelLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
                    LabelLayout.VerticalAlignment = Enum.VerticalAlignment.Center
                    LabelLayout.SortOrder = Enum.SortOrder.LayoutOrder
                    local TextGap = New("Frame", {
                        BackgroundTransparency = 1,
                        LayoutOrder = -3,
                        Size = UDim2.fromOffset(0, 1),
                        Parent = TextLabel,
                    })
                    local InlineIcon = New("ImageLabel", {
                        BackgroundTransparency = 1,
                        Image = Art.Url,
                        ImageRectOffset = Art.ImageRectOffset or Vector2.zero,
                        ImageRectSize = Art.ImageRectSize or Vector2.zero,
                        LayoutOrder = -2,
                        Size = UDim2.fromOffset(13, 13),
                        ZIndex = TextLabel.ZIndex,
                        Parent = TextLabel,
                    })
                    local Filler = New("Frame", {
                        BackgroundTransparency = 1,
                        LayoutOrder = -1,
                        Size = UDim2.fromOffset(0, 1),
                        Parent = TextLabel,
                    })
                    New("UIFlexItem", {
                        FlexMode = Enum.UIFlexMode.Fill,
                        Parent = Filler,
                    })
                    if FullColor then
                        pcall(function()
                            Library:RemoveFromRegistry(InlineIcon)
                        end)
                        InlineIcon.ImageColor3 = Color3.new(1, 1, 1)
                    else
                        InlineIcon.ImageColor3 = Library.Scheme.FontColor
                        Library.Registry[InlineIcon] = { ImageColor3 = "FontColor" }
                    end
                    local function PlaceInline()
                        local Scale = InlineIcon.AbsoluteSize.X > 0 and (InlineIcon.AbsoluteSize.X / 13) or 1
                        TextGap.Size = UDim2.fromOffset(math.max(0, math.ceil(TextLabel.TextBounds.X / math.max(Scale, 0.01)) - 2), 1)
                    end
                    PlaceInline()
                    TextLabel:GetPropertyChangedSignal("TextBounds"):Connect(ObsGuard(PlaceInline))
                    InlineIcon:GetPropertyChangedSignal("AbsoluteSize"):Connect(ObsGuard(PlaceInline))
                    Label.InlineIcon = InlineIcon
                end)
            end
        end

        Groupbox:Resize()

        Label.TextLabel = TextLabel
        Label.Container = Container
        if not Data.DoesWrap then
            setmetatable(Label, BaseAddons)
        end

        Label.Holder = TextLabel
        table.insert(Groupbox.Elements, Label)

        if Data.Idx then
            Labels[Data.Idx] = Label
        else
            table.insert(Labels, Label)
        end

        function Label:Destroy()
            Label.Destroyed = true

            if Label.Connections then
                for _, Connection in Label.Connections do
                    Connection:Disconnect()
                end
            end

            if Label.Addons then
                for Index = #Label.Addons, 1, -1 do
                    local Addon = table.remove(Label.Addons, Index)
                    if Addon and Addon.Destroy then
                        Addon:Destroy()
                    end
                end
            end

            if TextLabel then 
                TextLabel:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Label)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()

            if Data.Idx then
                Labels[Data.Idx] = nil
            else
                local LblIdx = table.find(Labels, Label)
                
                if LblIdx then 
                    table.remove(Labels, LblIdx) 
                end
            end
        end

        return Label
    end

    function Funcs:AddButton(...)
        if self.Destroyed then return nil end

        local function GetInfo(...)
            local Info = {}

            local First = select(1, ...)
            local Second = select(2, ...)

            if typeof(First) == "table" or typeof(Second) == "table" then
                local Params = typeof(First) == "table" and First or Second

                Info.Text = Params.Text or ""
                Info.Func = Params.Func or Params.Callback or function() end
                Info.DoubleClick = Params.DoubleClick

                Info.Tooltip = Params.Tooltip
                Info.DisabledTooltip = Params.DisabledTooltip

                Info.Risky = Params.Risky or false
                Info.Disabled = Params.Disabled or false
                Info.Visible = if typeof(Params.Visible) == "boolean" then Params.Visible else true
                Info.Idx = typeof(Second) == "table" and First or nil
            else
                Info.Text = First or ""
                Info.Func = Second or function() end
                Info.DoubleClick = false

                Info.Tooltip = nil
                Info.DisabledTooltip = nil

                Info.Risky = false
                Info.Disabled = false
                Info.Visible = true
                Info.Idx = select(3, ...) or nil
            end

            return Info
        end
        local Info = GetInfo(...)

        local Groupbox = self
        local Container = Groupbox.Container

        local Button = {
            Connections = {},
            Destroyed = false,

            Text = Info.Text,
            Func = Info.Func,
            DoubleClick = Info.DoubleClick,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Risky = Info.Risky,
            Disabled = Info.Disabled,
            Visible = Info.Visible,

            Tween = nil,
            Type = "Button",

            Parent = Groupbox,
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 21),
            Parent = Container,
        })

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalFlex = Enum.UIFlexAlignment.Fill,
            Padding = UDim.new(0, 9),
            Parent = Holder,
        })

        local function CreateButton(Button)
            local Base = New("TextButton", {
                Active = not Button.Disabled,
                BackgroundColor3 = Button.Disabled and "BackgroundColor" or "MainColor",
                ClipsDescendants = true,
                Size = UDim2.fromScale(1, 1),
                Text = Button.Text,
                TextSize = 14,
                TextTransparency = 0.4,
                Visible = Button.Visible,
                Parent = Holder,
            })

            local Stroke = New("UIStroke", {
                Color = "OutlineColor",
                Transparency = Button.Disabled and 0.5 or 0,
                Parent = Base,
            })

            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Base,
                })
            )

            return Base, Stroke
        end

        local function InitEvents(Button)
            table.insert(Button.Connections, Button.Base.MouseEnter:Connect(ObsGuard(function()
                if Library:MouseIsOverMenu() then
                    return
                end
                if Button.Disabled then
                    return
                end

                Button.Tween = TweenService:Create(Button.Base, Library.TweenInfo, {
                    TextTransparency = 0,
                })
                Button.Tween:Play()
            end)))
            table.insert(Button.Connections, Button.Base.MouseLeave:Connect(ObsGuard(function()
                if Button.Disabled then
                    return
                end

                Button.Tween = TweenService:Create(Button.Base, Library.TweenInfo, {
                    TextTransparency = 0.4,
                })
                Button.Tween:Play()
            end)))

            table.insert(Button.Connections, Button.Base.MouseButton1Click:Connect(ObsGuard(function()
                if Button.Disabled or Button.Locked then
                    return
                end

                local _rp = Instance.new("Frame")
                _rp.AnchorPoint = Vector2.new(0.5, 0.5)
                _rp.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                _rp.BackgroundTransparency = 0.82
                _rp.BorderSizePixel = 0
                _rp.Size = UDim2.fromOffset(0, 0)
                _rp.Position = UDim2.fromScale(0.5, 0.5)
                _rp.ZIndex = Button.Base.ZIndex + 5
                Instance.new("UICorner", _rp).CornerRadius = UDim.new(1, 0)
                _rp.Parent = Button.Base
                local _sz = math.max(Button.Base.AbsoluteSize.X, Button.Base.AbsoluteSize.Y) * 2.5
                TweenService:Create(_rp, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Size = UDim2.fromOffset(_sz, _sz),
                    BackgroundTransparency = 1,
                }):Play()
                task.delay(0.4, function() _rp:Destroy() end)

                if Button.DoubleClick then
                    Button.Locked = true

                    Button.Base.Text = "Are you sure?"
                    Button.Base.TextColor3 = Library.Scheme.AccentColor
                    Library.Registry[Button.Base].TextColor3 = "AccentColor"

                    local Clicked = WaitForEvent(Button.Base.MouseButton1Click, 0.5)

                    Button.Base.Text = Button.Text
                    Button.Base.TextColor3 = Button.Risky and Library.Scheme.RedColor or Library.Scheme.FontColor
                    Library.Registry[Button.Base].TextColor3 = Button.Risky and "RedColor" or "FontColor"

                    if Clicked then
                        Library:SafeCallback(Button.Func)
                    end

                    RunService.RenderStepped:Wait() --// Mouse Button fires without waiting (i hate roblox)
                    Button.Locked = false
                    return
                end

                Library:SafeCallback(Button.Func)
            end)))
        end

        Button.Base, Button.Stroke = CreateButton(Button)
        InitEvents(Button)

        function Button:AddButton(...)
            local Info = GetInfo(...)

            local SubButton = {
                Connections = {},
                Destroyed = false,

                Text = Info.Text,
                Func = Info.Func,
                DoubleClick = Info.DoubleClick,

                Tooltip = Info.Tooltip,
                DisabledTooltip = Info.DisabledTooltip,
                TooltipTable = nil,

                Risky = Info.Risky,
                Disabled = Info.Disabled,
                Visible = Info.Visible,

                Tween = nil,
                Type = "SubButton",
            }

            Button.SubButton = SubButton
            SubButton.Base, SubButton.Stroke = CreateButton(SubButton)
            InitEvents(SubButton)

            function SubButton:UpdateColors()
                if Library.Unloaded then
                    return
                end

                StopTween(SubButton.Tween)

                SubButton.Base.BackgroundColor3 = SubButton.Disabled and Library.Scheme.BackgroundColor
                    or Library.Scheme.MainColor
                SubButton.Base.TextTransparency = SubButton.Disabled and 0.8 or 0.4
                SubButton.Stroke.Transparency = SubButton.Disabled and 0.5 or 0

                Library.Registry[SubButton.Base].BackgroundColor3 = SubButton.Disabled and "BackgroundColor"
                    or "MainColor"
            end

            function SubButton:SetDisabled(Disabled: boolean)
                SubButton.Disabled = Disabled

                if SubButton.TooltipTable then
                    SubButton.TooltipTable.Disabled = SubButton.Disabled
                end

                SubButton.Base.Active = not SubButton.Disabled
                SubButton:UpdateColors()
                Library:UpdateAddons(SubButton)
            end

            function SubButton:SetVisible(Visible: boolean)
                SubButton.Visible = Visible

                SubButton.Base.Visible = SubButton.Visible
                Groupbox:Resize()
            end

            function SubButton:SetText(Text: string)
                SubButton.Text = Text
                SubButton.Base.Text = Text
            end

            if typeof(SubButton.Tooltip) == "string" or typeof(SubButton.DisabledTooltip) == "string" then
                SubButton.TooltipTable =
                    Library:AddTooltip(SubButton.Tooltip, SubButton.DisabledTooltip, SubButton.Base)
                SubButton.TooltipTable.Disabled = SubButton.Disabled
            end

            if SubButton.Risky then
                SubButton.Base.TextColor3 = Library.Scheme.RedColor
                Library.Registry[SubButton.Base].TextColor3 = "RedColor"
            end

            SubButton:UpdateColors()

            if Info.Idx then
                Buttons[Info.Idx] = SubButton
            else
                table.insert(Buttons, SubButton)
            end

            SubButton.AddKeyPicker = BaseAddons.__index.AddKeyPicker

            function SubButton:Destroy()
                SubButton.Destroyed = true

                if SubButton.Connections then
                    for _, Connection in SubButton.Connections do
                        Connection:Disconnect()
                    end
                end

                if SubButton.TooltipTable then
                    SubButton.TooltipTable:Destroy()
                end

                if SubButton.Tween then 
                    SubButton.Tween:Destroy() 
                end

                if SubButton.Base then 
                    SubButton.Base:Destroy() 
                end

                if Info.Idx then
                    Buttons[Info.Idx] = nil
                else
                    local BIdx = table.find(Buttons, SubButton)
                    
                    if BIdx then 
                        table.remove(Buttons, BIdx) 
                    end
                end
            end

            return SubButton
        end

        function Button:UpdateColors()
            if Library.Unloaded then
                return
            end

            StopTween(Button.Tween)

            Button.Base.BackgroundColor3 = Button.Disabled and Library.Scheme.BackgroundColor
                or Library.Scheme.MainColor
            Button.Base.TextTransparency = Button.Disabled and 0.8 or 0.4
            Button.Stroke.Transparency = Button.Disabled and 0.5 or 0

            Library.Registry[Button.Base].BackgroundColor3 = Button.Disabled and "BackgroundColor" or "MainColor"
        end

        function Button:SetDisabled(Disabled: boolean)
            Button.Disabled = Disabled

            if Button.TooltipTable then
                Button.TooltipTable.Disabled = Button.Disabled
            end

            Button.Base.Active = not Button.Disabled
            Button:UpdateColors()
            Library:UpdateAddons(Button)
        end

        function Button:SetVisible(Visible: boolean)
            Button.Visible = Visible

            Holder.Visible = Button.Visible
            Groupbox:Resize()
        end

        function Button:SetText(Text: string)
            Button.Text = Text
            Button.Base.Text = Text
        end

        if typeof(Button.Tooltip) == "string" or typeof(Button.DisabledTooltip) == "string" then
            Button.TooltipTable = Library:AddTooltip(Button.Tooltip, Button.DisabledTooltip, Button.Base)
            Button.TooltipTable.Disabled = Button.Disabled
        end

        if Button.Risky then
            Button.Base.TextColor3 = Library.Scheme.RedColor
            Library.Registry[Button.Base].TextColor3 = "RedColor"
        end

        Button:UpdateColors()
        Groupbox:Resize()

        Button.Holder = Holder
        table.insert(Groupbox.Elements, Button)

        if Info.Idx then
            Buttons[Info.Idx] = Button
        else
            table.insert(Buttons, Button)
        end

        Button.AddKeyPicker = BaseAddons.__index.AddKeyPicker

        function Button:Destroy()
            Button.Destroyed = true

            if Button.Connections then
                for _, Connection in Button.Connections do
                    Connection:Disconnect()
                end
            end

            if Button.TooltipTable then
                Button.TooltipTable:Destroy()
            end

            if Button.Tween then 
                Button.Tween:Destroy() 
            end

            if Button.Addons then
                for _, Addon in table.clone(Button.Addons) do
                    if Addon and Addon.Destroy then
                        Addon:Destroy()
                    end
                end
            end

            if Button.SubButton then 
                Button.SubButton:Destroy() 
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Button)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()

            if Info.Idx then
                Buttons[Info.Idx] = nil
            else
                local BIdx = table.find(Buttons, Button)
                
                if BIdx then 
                    table.remove(Buttons, BIdx) 
                end
            end
        end

        return Button
    end

    function Funcs:AddCheckbox(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Toggle)

        local Groupbox = self
        local Container = Groupbox.Container

        local Toggle = {
            Connections = {},
            Destroyed = false,

            Text = Info.Text,
            Value = Info.Default,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Callback = Info.Callback,
            Changed = Info.Changed,

            Risky = Info.Risky,
            Disabled = Info.Disabled,
            Visible = Info.Visible,

            Addons = {},
            AnyKeyPickerPicking = false,

            Variant = "Checkbox",
            Type = "Toggle",

            Parent = Groupbox,
        }

        local Button = New("TextButton", {
            Active = not Toggle.Disabled,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Text = "",
            Visible = Toggle.Visible,
            Parent = Container,
        })

        local Label = New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(26, 0),
            Size = UDim2.new(1, -26, 1, 0),
            Text = Toggle.Text,
            TextSize = 14,
            TextTransparency = 0.4,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Button,
        })

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Padding = UDim.new(0, 6),
            Parent = Label,
        })

        local Checkbox = New("Frame", {
            BackgroundColor3 = "MainColor",
            Size = UDim2.fromScale(1, 1),
            SizeConstraint = Enum.SizeConstraint.RelativeYY,
            Parent = Button,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Checkbox,
            })
        )

        local CheckboxStroke = New("UIStroke", {
            Color = "OutlineColor",
            Parent = Checkbox,
        })

        local CheckImage = New("ImageLabel", {
            Image = CheckIcon and CheckIcon.Url or "",
            ImageColor3 = "FontColor",
            ImageRectOffset = CheckIcon and CheckIcon.ImageRectOffset or Vector2.zero,
            ImageRectSize = CheckIcon and CheckIcon.ImageRectSize or Vector2.zero,
            ImageTransparency = 1,
            Position = UDim2.fromOffset(2, 2),
            Size = UDim2.new(1, -4, 1, -4),
            Parent = Checkbox,
        })

        function Toggle:UpdateColors()
            Toggle:Display()
        end

        function Toggle:Display()
            if Library.Unloaded then
                return
            end

            CheckboxStroke.Transparency = Toggle.Disabled and 0.5 or 0

            if Toggle.Disabled then
                Label.TextTransparency = 0.8
                CheckImage.ImageTransparency = Toggle.Value and 0.8 or 1

                Checkbox.BackgroundColor3 = Library.Scheme.BackgroundColor
                Library.Registry[Checkbox].BackgroundColor3 = "BackgroundColor"

                return
            end

            TweenService:Create(Label, Library.TweenInfo, {
                TextTransparency = Toggle.Value and 0 or 0.4,
            }):Play()

            local On = Toggle.Value and true or false
            CheckImage.AnchorPoint = Vector2.new(0.5, 0.5)
            CheckImage.Position = UDim2.fromScale(0.5, 0.5)
            if Library.Registry[CheckImage] then
                Library.Registry[CheckImage].ImageColor3 = "WhiteColor"
            end
            CheckImage.ImageColor3 = Library.Scheme.WhiteColor or Color3.new(1, 1, 1)

            Library.Registry[Checkbox].BackgroundColor3 = On and "AccentColor" or "MainColor"
            if Library.Registry[CheckboxStroke] then
                Library.Registry[CheckboxStroke].Color = On and "AccentColor" or "OutlineColor"
            end
            TweenService:Create(Checkbox, Library.TweenInfo, {
                BackgroundColor3 = On and Library.Scheme.AccentColor or Library.Scheme.MainColor,
            }):Play()
            TweenService:Create(CheckboxStroke, Library.TweenInfo, {
                Color = On and Library.Scheme.AccentColor or Library.Scheme.OutlineColor,
            }):Play()

            if Toggle.ShownValue ~= On then
                local First = Toggle.ShownValue == nil
                Toggle.ShownValue = On
                if On and not First then
                    CheckImage.Size = UDim2.new(0.3, 0, 0.3, 0)
                    CheckImage.ImageTransparency = 0
                    Library:Spring(CheckImage, "Size", UDim2.new(1, -4, 1, -4), 30, 0.55)
                else
                    Library:SpringStop(CheckImage, "Size")
                    CheckImage.Size = UDim2.new(1, -4, 1, -4)
                    TweenService:Create(CheckImage, Library.TweenInfo, {
                        ImageTransparency = On and 0 or 1,
                    }):Play()
                end
            end
        end

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func
        end

        function Toggle:RunChanged()
            if Toggle.Disabled then
                return
            end

            Library:SafeCallback(Toggle.Callback, Toggle.Value)
            Library:SafeCallback(Toggle.Changed, Toggle.Value)
        end

        function Toggle:SetValue(Value)
            Toggle.Value = Value
            Toggle:Display()

            for _, Addon in Toggle.Addons do
                if Addon.Type == "KeyPicker" then
                    if Addon.SyncToggleState then
                        Addon.Toggled = Toggle.Value
                    end
                    Addon:Update()
                end
            end

            if not Toggle.Disabled then
                Library:UpdateDependencyBoxes(Toggle)
            end

            if not Toggle.AnyKeyPickerPicking then
                Toggle:RunChanged()
            end
        end

        function Toggle:SetDisabled(Disabled: boolean)
            Toggle.Disabled = Disabled

            if Toggle.TooltipTable then
                Toggle.TooltipTable.Disabled = Toggle.Disabled
            end

            Library:UpdateAddons(Toggle)

            Button.Active = not Toggle.Disabled
            Toggle:Display()

            Library:UpdateDependencyBoxes(Toggle)
        end

        function Toggle:SetVisible(Visible: boolean)
            Toggle.Visible = Visible

            Button.Visible = Toggle.Visible
            Groupbox:Resize()
        end

        function Toggle:SetText(Text: string)
            Toggle.Text = Text
            Label.Text = Text
        end

        table.insert(Toggle.Connections, Button.MouseButton1Click:Connect(ObsGuard(function()
            if Toggle.Disabled then
                return
            end

            Toggle:SetValue(not Toggle.Value)
        end)))

        if typeof(Toggle.Tooltip) == "string" or typeof(Toggle.DisabledTooltip) == "string" then
            Toggle.TooltipTable = Library:AddTooltip(Toggle.Tooltip, Toggle.DisabledTooltip, Button)
            Toggle.TooltipTable.Disabled = Toggle.Disabled
        end

        if Toggle.Risky then
            Label.TextColor3 = Library.Scheme.RedColor
            Library.Registry[Label].TextColor3 = "RedColor"
        end

        Toggle:Display()
        Groupbox:Resize()

        Toggle.TextLabel = Label
        Toggle.Container = Container
        setmetatable(Toggle, BaseAddons)

        Toggle.Holder = Button
        table.insert(Groupbox.Elements, Toggle)

        Toggle.Default = Toggle.Value

        Toggles[Idx] = Toggle

        function Toggle:Destroy()
            Toggle.Destroyed = true

            if Toggle.Connections then
                for _, Connection in Toggle.Connections do
                    Connection:Disconnect()
                end
            end

            if Toggle.TooltipTable then 
                Toggle.TooltipTable:Destroy() 
            end

            if Button then 
                Button:Destroy() 
            end

            if Toggle.Addons then
                for Index = #Toggle.Addons, 1, -1 do
                    local Addon = table.remove(Toggle.Addons, Index)
                    if Addon and Addon.Destroy then
                        Addon:Destroy()
                    end
                end
            end

            local ElemIdx = table.find(Groupbox.Elements, Toggle)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Toggles[Idx] = nil
        end

        return Toggle
    end

    function Funcs:AddToggle(Idx, Info)
        if self.Destroyed then return nil end

        if Library.ForceCheckbox then
            return Funcs.AddCheckbox(self, Idx, Info)
        end

        Info = Library:Validate(Info, Templates.Toggle)

        local Groupbox = self
        local Container = Groupbox.Container

        local Toggle = {
            Connections = {},
            Destroyed = false,

            Text = Info.Text,
            Value = Info.Default,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Callback = Info.Callback,
            Changed = Info.Changed,

            Risky = Info.Risky,
            Disabled = Info.Disabled,
            Visible = Info.Visible,

            Addons = {},
            AnyKeyPickerPicking = false,

            Variant = "Switch",
            Type = "Toggle",

            Parent = Groupbox,
        }

        local Button = New("TextButton", {
            Active = not Toggle.Disabled,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            Text = "",
            Visible = Toggle.Visible,
            Parent = Container,
        })

        local Label = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -40, 1, 0),
            Text = Toggle.Text,
            TextSize = 14,
            TextTransparency = 0.4,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Button,
        })

        if Info.Icon ~= nil then
            pcall(function()
                local IconSize = tonumber(Info.IconSize) or 15
                local LabelIcon

                if typeof(Info.Icon) == "Instance" and Info.Icon:IsA("GuiObject") then
                    LabelIcon = Info.Icon
                    LabelIcon.AnchorPoint = Vector2.new(0, 0.5)
                    LabelIcon.Size = UDim2.fromOffset(IconSize, IconSize)
                    LabelIcon.Parent = Button
                    LabelIcon.ZIndex = Label.ZIndex
                    for _, Child in ipairs(LabelIcon:GetDescendants()) do
                        if Child:IsA("GuiObject") then
                            Child.ZIndex = Label.ZIndex
                        end
                    end
                else
                    LabelIcon = New("ImageLabel", {
                        AnchorPoint = Vector2.new(0, 0.5),
                        BackgroundTransparency = 1,
                        ScaleType = Enum.ScaleType.Fit,
                        Size = UDim2.fromOffset(IconSize, IconSize),
                        Parent = Button,
                    })

                    local Art = nil
                    if type(Info.Icon) == "string" and not string.find(Info.Icon, "://", 1, true) then
                        Art = Library:GetIcon(Info.Icon)
                    end

                    if type(Art) == "table" and type(Art.Url) == "string" and Art.Url ~= "" then
                        LabelIcon.Image = Art.Url
                        if typeof(Art.ImageRectOffset) == "Vector2" then
                            LabelIcon.ImageRectOffset = Art.ImageRectOffset
                        end
                        if typeof(Art.ImageRectSize) == "Vector2" then
                            LabelIcon.ImageRectSize = Art.ImageRectSize
                        end
                    else
                        LabelIcon.Image = tostring(Info.Icon)
                    end

                    LabelIcon.ImageColor3 = typeof(Info.IconColor) == "Color3" and Info.IconColor or Color3.new(1, 1, 1)
                end

                local function PlaceIcon()
                    local Scale = LabelIcon.AbsoluteSize.X > 0 and (LabelIcon.AbsoluteSize.X / IconSize) or 1
                    LabelIcon.Position = UDim2.new(0, math.ceil(Label.TextBounds.X / math.max(Scale, 0.01)) + 5, 0.5, 0)
                end

                local function FadeIcon()
                    if LabelIcon:IsA("ImageLabel") or LabelIcon:IsA("ImageButton") or LabelIcon:IsA("ViewportFrame") then
                        LabelIcon.ImageTransparency = Label.TextTransparency
                    end
                end

                PlaceIcon()
                FadeIcon()
                Label:GetPropertyChangedSignal("TextBounds"):Connect(ObsGuard(PlaceIcon))
                Label:GetPropertyChangedSignal("AbsoluteSize"):Connect(ObsGuard(PlaceIcon))
                LabelIcon:GetPropertyChangedSignal("AbsoluteSize"):Connect(ObsGuard(PlaceIcon))
                Label:GetPropertyChangedSignal("TextTransparency"):Connect(ObsGuard(FadeIcon))
                Toggle.LabelIcon = LabelIcon
            end)
        end

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Padding = UDim.new(0, 6),
            Parent = Label,
        })

        local Switch = New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = "MainColor",
            Position = UDim2.fromScale(1, 0),
            Size = UDim2.fromOffset(32, 18),
            Parent = Button,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = Switch,
        })
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 2),
            PaddingLeft = UDim.new(0, 2),
            PaddingRight = UDim.new(0, 2),
            PaddingTop = UDim.new(0, 2),
            Parent = Switch,
        })
        local SwitchStroke = New("UIStroke", {
            Color = "OutlineColor",
            Parent = Switch,
        })

        local Ball = New("Frame", {
            BackgroundColor3 = "FontColor",
            Size = UDim2.fromScale(1, 1),
            SizeConstraint = Enum.SizeConstraint.RelativeYY,
            Parent = Switch,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = Ball,
        })

        local IOSStyle = Library.SwitchStyle ~= "Classic"
        local IOSKnobWidth = 20
        local IOSShadow = nil
        local IOSHover, IOSPressing = false, false
        if IOSStyle then
            Switch.AnchorPoint = Vector2.new(1, 0.5)
            Switch.Position = UDim2.new(1, 0, 0.5, 0)
            Switch.Size = UDim2.fromOffset(36, 16)
            Label.Size = UDim2.new(1, -48, 1, 0)
            local SwitchPadding = Switch:FindFirstChildOfClass("UIPadding")
            if SwitchPadding then
                SwitchPadding.PaddingTop = UDim.new(0, 2)
                SwitchPadding.PaddingBottom = UDim.new(0, 2)
                SwitchPadding.PaddingLeft = UDim.new(0, 2)
                SwitchPadding.PaddingRight = UDim.new(0, 2)
            end
            SwitchStroke.Transparency = 1
            Ball.SizeConstraint = Enum.SizeConstraint.RelativeXY
            Ball.Size = UDim2.new(0, IOSKnobWidth, 1, 0)
            Ball.ZIndex = Switch.ZIndex + 2
            IOSShadow = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.new(0, 0, 0),
                BackgroundTransparency = 0.86,
                BorderSizePixel = 0,
                Position = UDim2.new(0.5, 0, 0.5, 0.75),
                Size = UDim2.new(1, -3, 1, -1),
                ZIndex = Switch.ZIndex + 1,
                Parent = Ball,
            })
            New("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = IOSShadow,
            })

            local function Repaint()
                if Toggle.IOSTrackColor and not Toggle.Disabled then
                    TweenService:Create(Switch, Library.TweenInfo, { BackgroundColor3 = Toggle.IOSTrackColor() }):Play()
                end
            end
            local function Unstretch(Bouncy)
                TweenService:Create(Ball, TweenInfo.new(Bouncy and 0.36 or 0.2, Bouncy and Enum.EasingStyle.Back or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, IOSKnobWidth, 1, 0),
                }):Play()
            end
            Button.MouseEnter:Connect(ObsGuard(function()
                if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
                    return
                end
                if Library:MouseIsOverMenu() then
                    return
                end
                IOSHover = true
                Repaint()
            end))
            Button.MouseLeave:Connect(ObsGuard(function()
                IOSHover = false
                Repaint()
                if IOSPressing then
                    IOSPressing = false
                    Unstretch(false)
                end
            end))
            Button.InputBegan:Connect(ObsGuard(function(Input)
                if Toggle.Disabled or not IsClickInput(Input) then
                    return
                end
                IOSPressing = true
                TweenService:Create(Ball, TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, IOSKnobWidth + 6, 1, 0),
                }):Play()
            end))
            Button.InputEnded:Connect(ObsGuard(function()
                if not IOSPressing then
                    return
                end
                IOSPressing = false
                task.defer(Unstretch, true)
            end))
        end

        function Toggle:UpdateColors()
            Toggle:Display()
        end

        function Toggle:Display()
            if Library.Unloaded then
                return
            end

            local Offset = Toggle.Value and 1 or 0

            if IOSStyle then
                local On = Toggle.Value and true or false
                local Disabled = Toggle.Disabled == true
                local function TrackColor()
                    local Base
                    if On then
                        Base = Info.OnColor or Library.SwitchOnColor or Library.Scheme.AccentColor
                    else
                        Base = Library:GetBetterColor(Library.Scheme.MainColor, 18)
                    end
                    if IOSHover and not Disabled then
                        Base = Base:Lerp(Color3.new(1, 1, 1), 0.08)
                    end
                    return Base
                end
                local function KnobColor()
                    if Disabled then
                        return Color3.new(1, 1, 1):Lerp(Library.Scheme.MainColor, 0.45)
                    end
                    if On then
                        return Color3.new(1, 1, 1)
                    end
                    return Color3.new(1, 1, 1):Lerp(Library.Scheme.MainColor, 0.12)
                end
                Toggle.IOSTrackColor = TrackColor
                Library.Registry[Switch] = Library.Registry[Switch] or {}
                local AccentBound = On and not Info.OnColor and not Library.SwitchOnColor
                local Previous = Library.Registry[Switch].BackgroundColor3
                Library.Registry[Switch].BackgroundColor3 = AccentBound and "AccentColor" or TrackColor
                if (Previous == "AccentColor") ~= AccentBound then
                    Library.RgbDirty = true
                end
                Library.Registry[SwitchStroke] = nil
                SwitchStroke.Transparency = 1
                Library.Registry[Ball] = Library.Registry[Ball] or {}
                Library.Registry[Ball].BackgroundColor3 = KnobColor
                Switch.BackgroundTransparency = Disabled and 0.5 or 0
                Ball.BackgroundTransparency = 0
                if IOSShadow then
                    IOSShadow.Visible = not Disabled
                end

                local Changed = Toggle.IOSShown ~= nil and Toggle.IOSShown ~= On
                Toggle.IOSShown = On

                if Disabled or not Changed then
                    Label.TextTransparency = Disabled and 0.8 or (On and 0 or 0.4)
                    Switch.BackgroundColor3 = TrackColor()
                    Ball.BackgroundColor3 = KnobColor()
                    Ball.AnchorPoint = Vector2.new(Offset, 0)
                    Ball.Position = UDim2.fromScale(Offset, 0)
                    return
                end

                local Slide = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                local Fade = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                TweenService:Create(Label, Library.TweenInfo, { TextTransparency = On and 0 or 0.4 }):Play()
                if AccentBound and Library.RgbEnabled then
                    Switch.BackgroundColor3 = TrackColor()
                else
                    TweenService:Create(Switch, Fade, { BackgroundColor3 = TrackColor() }):Play()
                end
                TweenService:Create(Ball, Fade, { BackgroundColor3 = KnobColor() }):Play()
                TweenService:Create(Ball, Slide, {
                    AnchorPoint = Vector2.new(Offset, 0),
                    Position = UDim2.fromScale(Offset, 0),
                }):Play()
                if not IOSPressing then
                    Ball.Size = UDim2.new(0, IOSKnobWidth + 6, 1, 0)
                    TweenService:Create(Ball, TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                        Size = UDim2.new(0, IOSKnobWidth, 1, 0),
                    }):Play()
                end
                return
            end

            Switch.BackgroundTransparency = Toggle.Disabled and 0.75 or 0
            SwitchStroke.Transparency = Toggle.Disabled and 0.75 or 0

            Switch.BackgroundColor3 = Toggle.Value and Library.Scheme.AccentColor or Library.Scheme.MainColor
            SwitchStroke.Color = Toggle.Value and Library.Scheme.AccentColor or Library.Scheme.OutlineColor

            Library.Registry[Switch].BackgroundColor3 = Toggle.Value and "AccentColor" or "MainColor"
            Library.Registry[SwitchStroke].Color = Toggle.Value and "AccentColor" or "OutlineColor"

            if Toggle.Disabled then
                Label.TextTransparency = 0.8
                Ball.AnchorPoint = Vector2.new(Offset, 0)
                Ball.Position = UDim2.fromScale(Offset, 0)

                Ball.BackgroundColor3 = Library:GetDarkerColor(Library.Scheme.FontColor)
                Library.Registry[Ball].BackgroundColor3 = function()
                    return Library:GetDarkerColor(Library.Scheme.FontColor)
                end

                return
            end

            TweenService:Create(Label, Library.TweenInfo, {
                TextTransparency = Toggle.Value and 0 or 0.4,
            }):Play()
            TweenService:Create(Ball, Library.TweenInfo, {
                AnchorPoint = Vector2.new(Offset, 0),
                Position = UDim2.fromScale(Offset, 0),
            }):Play()

            Ball.BackgroundColor3 = Library.Scheme.FontColor
            Library.Registry[Ball].BackgroundColor3 = "FontColor"
        end

        function Toggle:OnChanged(Func)
            Toggle.Changed = Func
        end

        function Toggle:RunChanged()
            if Toggle.Disabled then
                return
            end

            Library:SafeCallback(Toggle.Callback, Toggle.Value)
            Library:SafeCallback(Toggle.Changed, Toggle.Value)
        end

        function Toggle:SetValue(Value)
            Toggle.Value = Value
            Toggle:Display()

            for _, Addon in Toggle.Addons do
                if Addon.Type == "KeyPicker" then
                    if Addon.SyncToggleState then
                        Addon.Toggled = Toggle.Value
                    end
                    Addon:Update()
                end
            end

            if not Toggle.Disabled then
                Library:UpdateDependencyBoxes(Toggle)
            end

            if not Toggle.AnyKeyPickerPicking then
                Toggle:RunChanged()
            end
        end

        function Toggle:SetDisabled(Disabled: boolean)
            Toggle.Disabled = Disabled

            if Toggle.TooltipTable then
                Toggle.TooltipTable.Disabled = Toggle.Disabled
            end

            Library:UpdateAddons(Toggle)

            Button.Active = not Toggle.Disabled
            Toggle:Display()

            Library:UpdateDependencyBoxes(Toggle)
        end

        function Toggle:SetVisible(Visible: boolean)
            Toggle.Visible = Visible

            Button.Visible = Toggle.Visible
            Groupbox:Resize()
        end

        function Toggle:SetText(Text: string)
            Toggle.Text = Text
            Label.Text = Text
        end

        table.insert(Toggle.Connections, Button.MouseButton1Click:Connect(ObsGuard(function()
            if Toggle.Disabled then
                return
            end

            Toggle:SetValue(not Toggle.Value)
        end)))

        if typeof(Toggle.Tooltip) == "string" or typeof(Toggle.DisabledTooltip) == "string" then
            Toggle.TooltipTable = Library:AddTooltip(Toggle.Tooltip, Toggle.DisabledTooltip, Button)
            Toggle.TooltipTable.Disabled = Toggle.Disabled
        end

        if Toggle.Risky then
            Label.TextColor3 = Library.Scheme.RedColor
            Library.Registry[Label].TextColor3 = "RedColor"
        end

        Toggle:Display()
        Groupbox:Resize()

        Toggle.TextLabel = Label
        Toggle.Container = Container
        setmetatable(Toggle, BaseAddons)

        Toggle.Holder = Button
        table.insert(Groupbox.Elements, Toggle)

        Toggle.Default = Toggle.Value

        Toggles[Idx] = Toggle

        function Toggle:Destroy()
            Toggle.Destroyed = true

            if Toggle.Connections then
                for _, Connection in Toggle.Connections do
                    Connection:Disconnect()
                end
            end

            if Toggle.TooltipTable then 
                Toggle.TooltipTable:Destroy() 
            end

            if Button then 
                Button:Destroy() 
            end

            if Toggle.Addons then
                for Index = #Toggle.Addons, 1, -1 do
                    local Addon = table.remove(Toggle.Addons, Index)
                    if Addon and Addon.Destroy then
                        Addon:Destroy()
                    end
                end
            end

            local ElemIdx = table.find(Groupbox.Elements, Toggle)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Toggles[Idx] = nil
        end

        if Info.Text == "Show Sidebar" and not Library.SidebarLayoutAdded and Library.SetTabDockLayout and Groupbox.AddDropdown then
            Library.SidebarLayoutAdded = true
            pcall(function()
                Groupbox:AddDropdown("ObsSidebarLayout", {
                    Text = "Sidebar Layout",
                    Values = { "Vertical", "Horizontal" },
                    Default = Library.TabDockLayout or "Vertical",
                    Tooltip = "Lay the sidebar out down the side or along the bottom of your screen.",
                    Callback = function(Value)
                        Library:SetTabDockLayout(Value)
                    end,
                })
            end)
        end

        return Toggle
    end

    function Funcs:AddInput(Idx, Info)
        if self.Destroyed then return nil end

        if typeof(Info) == "table" and (typeof(Info.VerifyValue) == "function" and Info.Finished ~= true) then
            Info.Finished = true
        end

        Info = Library:Validate(Info, Templates.Input)

        local Groupbox = self
        local Container = Groupbox.Container

        local Input = {
            Connections = {},
            Destroyed = false,

            Text = Info.Text,
            Value = Info.Default,

            Finished = Info.Finished,
            Numeric = Info.Numeric,
            ClearTextOnFocus = Info.ClearTextOnFocus,
            ClearTextOnBlur = Info.ClearTextOnBlur,
            Placeholder = Info.Placeholder,
            AllowEmpty = Info.AllowEmpty,
            EmptyReset = Info.EmptyReset,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Callback = Info.Callback,
            Changed = Info.Changed,
            VerifyValue = Info.VerifyValue,

            Disabled = Info.Disabled,
            Visible = Info.Visible,

            Type = "Input",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 39),
            Visible = Input.Visible,
            Parent = Container,
        })

        local Label = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            Text = Input.Text,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Holder,
        })

        local Box = New("TextBox", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            ClearTextOnFocus = not Input.Disabled and Input.ClearTextOnFocus,
            PlaceholderText = Input.Placeholder,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 21),
            Text = Input.Value,
            TextEditable = not Input.Disabled,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 11),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        local BoxStroke = New("UIStroke", {
            Color = "OutlineColor",
            Parent = Box,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                Parent = Box,
            })
        )

        function Input:UpdateColors()
            if Library.Unloaded then
                return
            end

            Label.TextTransparency = Input.Disabled and 0.8 or 0
            Box.TextTransparency = Input.Disabled and 0.8 or 0
            BoxStroke.Transparency = Input.Disabled and 0.5 or 0

            Box.BackgroundColor3 = Input.Disabled and Library.Scheme.BackgroundColor or Library.Scheme.MainColor
            Library.Registry[Box].BackgroundColor3 = Input.Disabled and "BackgroundColor" or "MainColor"
        end

        function Input:OnChanged(Func)
            Input.Changed = Func
        end

        function Input:RunChanged()
            if Input.Disabled then
                return
            end

            Library:SafeCallback(Input.Callback, Input.Value)
            Library:SafeCallback(Input.Changed, Input.Value)
        end

        function Input:SetValue(Text)
            if not Input.AllowEmpty and Trim(Text) == "" then
                Text = Input.EmptyReset
            end

            if Info.MaxLength and #Text > Info.MaxLength then
                Text = Text:sub(1, Info.MaxLength)
            end

            if Input.Numeric then
                if #tostring(Text) > 0 and not tonumber(Text) then
                    Text = Input.Value
                end
            end

            if typeof(Info.VerifyValue) == "function" and (Text ~= Input.EmptyReset and Info.VerifyValue(Text) ~= true) then
                Text = Input.EmptyReset
            end

            Input.Value = Text
            Box.Text = Text

            Input:RunChanged()
        end

        function Input:SetDisabled(Disabled: boolean)
            Input.Disabled = Disabled

            if Input.TooltipTable then
                Input.TooltipTable.Disabled = Input.Disabled
            end

            Box.ClearTextOnFocus = not Input.Disabled and Input.ClearTextOnFocus
            Box.TextEditable = not Input.Disabled
            Input:UpdateColors()
        end

        function Input:SetVisible(Visible: boolean)
            Input.Visible = Visible

            Holder.Visible = Input.Visible
            Groupbox:Resize()
        end

        function Input:SetText(Text: string)
            Input.Text = Text
            Label.Text = Text
        end

        if Input.Finished then
            table.insert(Input.Connections, Box.FocusLost:Connect(ObsGuard(function(Enter)
                if not Enter then
                    if Input.ClearTextOnBlur then
                        Box.Text = Input.Value
                    end

                    return
                end

                Input:SetValue(Box.Text)
            end)))
        else
            table.insert(Input.Connections, Box:GetPropertyChangedSignal("Text"):Connect(ObsGuard(function()
                if Box.Text == Input.Value then return end
                
                Input:SetValue(Box.Text)
            end)))
        end

        table.insert(Input.Connections, Box.Focused:Connect(ObsGuard(function()
            if Input.Disabled then
                return
            end

            Library.Registry[BoxStroke].Color = "AccentColor"
            TweenService:Create(BoxStroke, Library.TweenInfo, {
                Color = Library.Scheme.AccentColor,
            }):Play()
        end)))

        table.insert(Input.Connections, Box.FocusLost:Connect(ObsGuard(function()
            if Input.Disabled then
                return
            end

            Library.Registry[BoxStroke].Color = "OutlineColor"
            TweenService:Create(BoxStroke, Library.TweenInfo, {
                Color = Library.Scheme.OutlineColor,
            }):Play()
        end)))

        if typeof(Input.Tooltip) == "string" or typeof(Input.DisabledTooltip) == "string" then
            Input.TooltipTable = Library:AddTooltip(Input.Tooltip, Input.DisabledTooltip, Box)
            Input.TooltipTable.Disabled = Input.Disabled
        end

        Groupbox:Resize()

        Input.Holder = Holder
        table.insert(Groupbox.Elements, Input)

        Input.Default = Input.Value
        if typeof(Info.VerifyValue) == "function" and (Input.Default ~= Input.EmptyReset and Info.VerifyValue(Input.Default) ~= true) then
            Input:SetValue(Input.EmptyReset)
            Input.Default = Input.EmptyReset
        end

        Input:UpdateColors()
        Options[Idx] = Input

        function Input:Destroy()
            Input.Destroyed = true

            if Input.Connections then
                for _, Connection in Input.Connections do
                    Connection:Disconnect()
                end
            end

            if Input.TooltipTable then 
                Input.TooltipTable:Destroy() 
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Input)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Input
    end

    function Funcs:AddSlider(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Slider)
        Info.AllowRightClickInput = Info.AllowRightClickInput ~= false

        local Groupbox = self
        local Container = Groupbox.Container

        local Slider = {
            Connections = {},
            Destroyed = false,

            Text = Info.Text,
            Value = Info.Default,

            Min = Info.Min,
            Max = Info.Max,

            Prefix = Info.Prefix,
            Suffix = Info.Suffix,
            Compact = Info.Compact,
            Rounding = Info.Rounding,
            HideMax = Info.HideMax,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Callback = Info.Callback,
            Changed = Info.Changed,

            Disabled = Info.Disabled,
            Visible = Info.Visible,

            AllowRightClickInput = Info.AllowRightClickInput,

            Levels = Info.Levels,

            Type = "Slider",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Library.IsMobile and 40 or 32),
            Visible = Slider.Visible,
            Parent = Container,
        })

        local SliderLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -64, 0, 14),
            Text = Slider.Text,
            TextSize = 14,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = Holder,
        })

        local DisplayLabel = New("TextLabel", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(1, 0),
            Size = UDim2.new(0, 64, 0, 14),
            Text = "",
            TextSize = 13,
            TextTransparency = 0.35,
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent = Holder,
        })

        local Bar = New("TextButton", {
            Active = not Slider.Disabled,
            AnchorPoint = Vector2.new(0, 1),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, Library.IsMobile and 24 or 14),
            Text = "",
            Parent = Holder,
        })

        local Track = New("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = "OutlineColor",
            BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.new(1, 0, 0, 4),
            Parent = Bar,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = Track,
        })

        local SliderRange = Slider.Max - Slider.Min
        local MinimumStep = 10 ^ -(tonumber(Slider.Rounding) or 0)

        local function OnGrid(Value)
            local Units = Value / MinimumStep
            return math.abs(Units - math.floor(Units + 0.5)) < 1e-6
        end

        local function NiceStep(Raw)
            if not Raw or Raw <= 0 then
                return nil
            end
            local Power = 10 ^ math.floor(math.log10(Raw))
            local Unit = Raw / Power
            for _, Candidate in ipairs({ 1, 2, 2.5, 5, 10 }) do
                local Step = Candidate * Power
                if Unit <= Candidate and Step >= MinimumStep and OnGrid(Step) then
                    return Step
                end
            end
            return math.max(10 * Power, MinimumStep)
        end

        local MarkStep = (tonumber(Info.Ticks) and Info.Ticks > 0 and SliderRange / Info.Ticks) or NiceStep(SliderRange / 10)
        local SnapStep = tonumber(Info.SnapStep)
        if not SnapStep and MarkStep then
            for _, Divisor in ipairs({ 2, 5, 1 }) do
                local Step = MarkStep / Divisor
                if Step >= MinimumStep and OnGrid(Step) then
                    SnapStep = Step
                    break
                end
            end
        end

        local function RecomputeSteps()
            SliderRange = Slider.Max - Slider.Min
            MarkStep = (tonumber(Info.Ticks) and Info.Ticks > 0 and SliderRange / Info.Ticks) or NiceStep(SliderRange / 10)
            SnapStep = tonumber(Info.SnapStep)
            if not SnapStep and MarkStep then
                for _, Divisor in ipairs({ 2, 5, 1 }) do
                    local Step = MarkStep / Divisor
                    if Step >= MinimumStep and OnGrid(Step) then
                        SnapStep = Step
                        break
                    end
                end
            end
        end

        local TickMarks = {}
        if tonumber(Info.Ticks) and MarkStep and SliderRange > 0 then
            local Value = math.ceil((Slider.Min + MarkStep * 0.001) / MarkStep) * MarkStep
            while Value < Slider.Max - MarkStep * 0.001 and #TickMarks < 24 do
                local At = (Value - Slider.Min) / SliderRange
                local Mark = New("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = "FontColor",
                    BackgroundTransparency = 0.75,
                    BorderSizePixel = 0,
                    Position = UDim2.fromScale(At, 0.5),
                    Size = UDim2.fromOffset(2, 2),
                    ZIndex = Track.ZIndex + 2,
                    Parent = Track,
                })
                New("UICorner", {
                    CornerRadius = UDim.new(1, 0),
                    Parent = Mark,
                })
                table.insert(TickMarks, { Mark = Mark, At = At, Lit = nil })
                Value += MarkStep
            end
        end

        local InputTextBox
        local InputTextBoxStroke
        if Info.AllowRightClickInput then
            InputTextBox = New("TextBox", {
                AnchorPoint = Vector2.new(1, 0),
                BackgroundColor3 = "MainColor",
                BackgroundTransparency = 0,
                Position = UDim2.new(1, 0, 0, -2),
                Size = UDim2.new(0, 64, 0, 18),
                Text = "",
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Right,
                Visible = false,
                ClearTextOnFocus = false,
                ZIndex = 4,
                Parent = Holder,
            })
            New("UICorner", {
                CornerRadius = UDim.new(0, 3),
                Parent = InputTextBox,
            })
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 5),
                PaddingRight = UDim.new(0, 5),
                Parent = InputTextBox,
            })
            InputTextBoxStroke = New("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                Color = "OutlineColor",
                Parent = InputTextBox,
            })

            local ValueButton = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Position = UDim2.fromScale(1, 0),
                Size = UDim2.new(0, 64, 0, 14),
                Text = "",
                ZIndex = 3,
                Parent = Holder,
            })
            table.insert(Slider.Connections, ValueButton.MouseButton1Click:Connect(ObsGuard(function()
                if Slider.Disabled or InputTextBox.Visible then
                    return
                end
                InputTextBox.Text = tostring(Slider.Value)
                InputTextBox.Visible = true
                DisplayLabel.Visible = false
                task.spawn(InputTextBox.CaptureFocus, InputTextBox)
            end)))
            table.insert(Slider.Connections, ValueButton.MouseEnter:Connect(ObsGuard(function()
                if Library:MouseIsOverMenu() then
                    return
                end
                if Slider.Disabled or UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
                    return
                end
                TweenService:Create(DisplayLabel, Library.TweenInfo, { TextTransparency = 0 }):Play()
            end)))
            table.insert(Slider.Connections, ValueButton.MouseLeave:Connect(ObsGuard(function()
                if Slider.Disabled then
                    return
                end
                TweenService:Create(DisplayLabel, Library.TweenInfo, { TextTransparency = 0.35 }):Play()
            end)))
        end

        local Fill = New("Frame", {
            BackgroundColor3 = "AccentColor",
            BorderSizePixel = 0,
            Size = UDim2.fromScale(0.5, 1),
            ZIndex = Track.ZIndex + 1,
            Parent = Track,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = Fill,
        })

        local Knob = New("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = "FontColor",
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(Library.IsMobile and 16 or 12, Library.IsMobile and 16 or 12),
            ZIndex = Track.ZIndex + 3,
            Parent = Track,
        })
        New("UICorner", {
            CornerRadius = UDim.new(1, 0),
            Parent = Knob,
        })
        local KnobRing = New("UIStroke", {
            Color = "AccentColor",
            Thickness = 0,
            Transparency = 0.55,
            Parent = Knob,
        })

        local Dragging = false
        local Hovering = false
        local function KnobState()
            local Big = (Dragging or Hovering) and not Slider.Disabled
            local Base = Library.IsMobile and 16 or 12
            local Grown = Big and Base + 3 or Base
            Library:Spring(Knob, "Size", UDim2.fromOffset(Grown, Grown), 32, 0.7)
            TweenService:Create(KnobRing, Library.TweenInfo, { Thickness = Dragging and 4 or (Big and 2 or 0) }):Play()
        end
        table.insert(Slider.Connections, Bar.MouseEnter:Connect(ObsGuard(function()
            if Library:MouseIsOverMenu() then
                return
            end
            if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
                return
            end
            Hovering = true
            KnobState()
        end)))
        table.insert(Slider.Connections, Bar.MouseLeave:Connect(ObsGuard(function()
            Hovering = false
            KnobState()
        end)))

        local LevelIcon = nil
        local LevelIconKey = nil
        local LevelTinted = false

        local function LevelTint(Color)
            if typeof(Color) == "Color3" then
                return Color
            end
            if type(Color) == "string" and typeof(Library.Scheme[Color]) == "Color3" then
                return Library.Scheme[Color]
            end
            return Library.Scheme.AccentColor
        end

        local function LevelFor(Value)
            local Levels = Slider.Levels
            if type(Levels) ~= "table" or #Levels == 0 then
                return nil
            end
            local Current, Next = nil, nil
            for Index, Level in ipairs(Levels) do
                if type(Level) == "table" and Value >= (tonumber(Level.Value) or -math.huge) then
                    Current = Level
                    Next = Levels[Index + 1]
                end
            end
            if not Current then
                return LevelTint(Levels[1].Color), nil
            end
            local Color = LevelTint(Current.Color)
            if type(Next) == "table" and Next.Fade ~= false then
                local From, To = tonumber(Current.Value) or 0, tonumber(Next.Value) or 0
                if To > From then
                    Color = Color:Lerp(LevelTint(Next.Color), math.clamp((Value - From) / (To - From), 0, 1))
                end
            end
            return Color, Current.Icon
        end

        function Slider:PaintLevels()
            if Library.Unloaded then
                return
            end

            local Color, Icon = LevelFor(tonumber(Slider.Value) or 0)

            if not Color then
                if LevelTinted then
                    LevelTinted = false
                    if Library.Registry[Fill] then
                        Library.Registry[Fill].BackgroundColor3 = Slider.Disabled and "OutlineColor" or "AccentColor"
                    end
                    Fill.BackgroundColor3 = Slider.Disabled and Library.Scheme.OutlineColor or Library.Scheme.AccentColor
                    if Library.Registry[KnobRing] then
                        Library.Registry[KnobRing].Color = "AccentColor"
                    end
                    KnobRing.Color = Library.Scheme.AccentColor
                    if Library.Registry[SliderLabel] then
                        Library.Registry[SliderLabel].TextColor3 = "FontColor"
                    end
                    SliderLabel.TextColor3 = Library.Scheme.FontColor
                end
                if LevelIcon then
                    LevelIcon.Visible = false
                end
                return
            end

            LevelTinted = true
            if Library.Registry[Fill] then
                Library.Registry[Fill].BackgroundColor3 = nil
            end
            if Library.Registry[KnobRing] then
                Library.Registry[KnobRing].Color = nil
            end
            if Library.Registry[SliderLabel] then
                Library.Registry[SliderLabel].TextColor3 = nil
            end
            Fill.BackgroundColor3 = Slider.Disabled and Library.Scheme.OutlineColor or Color
            KnobRing.Color = Color
            SliderLabel.TextColor3 = Color

            if Icon == nil or Icon == "" then
                if LevelIcon then
                    LevelIcon.Visible = false
                end
                return
            end

            if not LevelIcon then
                LevelIcon = New("ImageLabel", {
                    AnchorPoint = Vector2.new(0, 0.5),
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(14, 14),
                    Visible = false,
                    ZIndex = SliderLabel.ZIndex + 1,
                    Parent = SliderLabel,
                })
                pcall(function()
                    Library:RemoveFromRegistry(LevelIcon)
                end)
                local function PlaceLevelIcon()
                    local Scale = LevelIcon.AbsoluteSize.X > 0 and (LevelIcon.AbsoluteSize.X / 14) or 1
                    LevelIcon.Position = UDim2.new(0, math.ceil(SliderLabel.TextBounds.X / math.max(Scale, 0.01)) + 5, 0.5, 0)
                end
                PlaceLevelIcon()
                table.insert(Slider.Connections, SliderLabel:GetPropertyChangedSignal("TextBounds"):Connect(ObsGuard(PlaceLevelIcon)))
                table.insert(Slider.Connections, LevelIcon:GetPropertyChangedSignal("AbsoluteSize"):Connect(ObsGuard(PlaceLevelIcon)))
            end

            local FullColor = false
            if LevelIconKey ~= Icon then
                local Art, Full = Library:ResolveInlineIcon(Icon)
                if not Art or not Art.Url or Art.Url == "" then
                    LevelIcon.Visible = false
                    return
                end
                LevelIconKey = Icon
                LevelIcon.Image = Art.Url
                LevelIcon.ImageRectOffset = Art.ImageRectOffset or Vector2.zero
                LevelIcon.ImageRectSize = Art.ImageRectSize or Vector2.zero
                LevelIcon:SetAttribute("FullColor", Full == true)
            end
            FullColor = LevelIcon:GetAttribute("FullColor") == true
            LevelIcon.ImageColor3 = FullColor and Color3.new(1, 1, 1) or Color
            LevelIcon.ImageTransparency = Slider.Disabled and 0.8 or 0
            LevelIcon.Visible = true
        end

        function Slider:SetLevels(Levels)
            Slider.Levels = Levels
            Slider:UpdateColors()
        end

        function Slider:UpdateColors()
            if Library.Unloaded then
                return
            end

            SliderLabel.TextTransparency = Slider.Disabled and 0.8 or 0
            DisplayLabel.TextTransparency = Slider.Disabled and 0.8 or 0.35
            Knob.BackgroundTransparency = Slider.Disabled and 0.6 or 0
            
            if Info.AllowRightClickInput then
                InputTextBox.TextTransparency = Slider.Disabled and 0.8 or 0
            end

            if Slider.Levels or LevelTinted then
                Slider:PaintLevels()
            else
                Fill.BackgroundColor3 = Slider.Disabled and Library.Scheme.OutlineColor or Library.Scheme.AccentColor
                Library.Registry[Fill].BackgroundColor3 = Slider.Disabled and "OutlineColor" or "AccentColor"
            end
        end

        function Slider:Display()
            if Library.Unloaded then
                return
            end

            local CustomDisplayText = nil
            if Info.FormatDisplayValue then
                CustomDisplayText = Info.FormatDisplayValue(Slider, Slider.Value)
            end

            if CustomDisplayText then
                DisplayLabel.Text = tostring(CustomDisplayText)
            else
                DisplayLabel.Text = string.format("%s%s%s", Slider.Prefix, Slider.Value, Slider.Suffix)
            end

            local Range = Slider.Max - Slider.Min
            local X = Range > 0 and math.clamp((Slider.Value - Slider.Min) / Range, 0, 1) or 0
            if Dragging and Slider.DragX then
                X = Slider.DragX
            end
            for _, Tick in ipairs(TickMarks) do
                local Lit = Tick.At <= X + 0.0001
                if Tick.Lit ~= Lit then
                    Tick.Lit = Lit
                    TweenService:Create(Tick.Mark, Library.TweenInfo, {
                        BackgroundTransparency = Lit and 0.3 or 0.75,
                        Size = Lit and UDim2.fromOffset(3, 3) or UDim2.fromOffset(2, 2),
                    }):Play()
                end
            end
            if Slider.Shown and not Dragging then
                Library:Spring(Fill, "Size", UDim2.fromScale(X, 1), 30, 0.92)
                Library:Spring(Knob, "Position", UDim2.fromScale(X, 0.5), 30, 0.92)
            else
                Slider.Shown = true
                Library:SpringStop(Fill, "Size")
                Library:SpringStop(Knob, "Position")
                Fill.Size = UDim2.fromScale(X, 1)
                Knob.Position = UDim2.fromScale(X, 0.5)
            end
            if Slider.Levels then
                Slider:PaintLevels()
            end
        end

        function Slider:OnChanged(Func)
            Slider.Changed = Func
        end

        function Slider:SetMax(Value)
            assert(Value > Slider.Min, "Max value cannot be less than the current min value.")

            Slider:SetValue(math.clamp(Slider.Value, Slider.Min, Value))
            Slider.Max = Value
            RecomputeSteps()
            Slider:Display()
        end

        function Slider:SetMin(Value)
            assert(Value < Slider.Max, "Min value cannot be greater than the current max value.")

            Slider:SetValue(math.clamp(Slider.Value, Value, Slider.Max))
            Slider.Min = Value
            RecomputeSteps()
            Slider:Display()
        end

        function Slider:RunChanged()
            if Slider.Disabled then
                return
            end

            Library:SafeCallback(Slider.Callback, Slider.Value)
            Library:SafeCallback(Slider.Changed, Slider.Value)
        end

        function Slider:SetValue(Str)
            local Num = tonumber(Str)
            if not Num or Num == Slider.Value then
                return
            end

            Num = math.clamp(Num, Slider.Min, Slider.Max)

            Slider.Value = Num
            Slider:Display()

            Slider:RunChanged()
        end

        function Slider:SetDisabled(Disabled: boolean)
            Slider.Disabled = Disabled

            if Slider.TooltipTable then
                Slider.TooltipTable.Disabled = Slider.Disabled
            end

            Bar.Active = not Slider.Disabled
            Slider:UpdateColors()
        end

        function Slider:SetVisible(Visible: boolean)
            Slider.Visible = Visible

            Holder.Visible = Slider.Visible
            Groupbox:Resize()
        end

        function Slider:SetText(Text: string)
            Slider.Text = Text
            SliderLabel.Text = Text
        end

        function Slider:SetPrefix(Prefix: string)
            Slider.Prefix = Prefix
            Slider:Display()
        end

        function Slider:SetSuffix(Suffix: string)
            Slider.Suffix = Suffix
            Slider:Display()
        end

        if Info.AllowRightClickInput then
            local LastValidText = ""
            table.insert(Slider.Connections, InputTextBox:GetPropertyChangedSignal("Text"):Connect(ObsGuard(function()
                local Text = InputTextBox.Text
                local AsNum = tonumber(Text)

                if #tostring(Text) > 0 and not AsNum and Text ~= "-" then
                    InputTextBox.Text = LastValidText
                else
                    if Slider.Rounding == 0 and Text:find("%.") then
                        InputTextBox.Text = Text:sub(1, Text:find("%.") - 1)
                        return
                    end

                    local DecimalPos = Text:find("%.")
                    if DecimalPos and Slider.Rounding > 0 then
                        local Decimals = #Text - DecimalPos
                        if Decimals > Slider.Rounding then
                            InputTextBox.Text = Text:sub(1, DecimalPos + Slider.Rounding)
                            return
                        end
                    end

                    LastValidText = Text

                    if AsNum then
                        if AsNum > Slider.Max then
                            InputTextBox.Text = tostring(Slider.Max)
                        elseif AsNum < Slider.Min then
                            InputTextBox.Text = tostring(Slider.Min)
                        end
                    end
                end
            end)))

            table.insert(Slider.Connections, InputTextBox.FocusLost:Connect(ObsGuard(function()
                InputTextBox.Visible = false
                DisplayLabel.Visible = true

                local Num = tonumber(InputTextBox.Text)
                if not Num then
                    return
                end

                Num = Round(Num, Slider.Rounding)
                Slider:SetValue(Num)
            end)))

            table.insert(Slider.Connections, InputTextBox.Focused:Connect(ObsGuard(function()
                if Slider.Disabled then
                    return
                end

                Library.Registry[InputTextBoxStroke].Color = "AccentColor"
                TweenService:Create(InputTextBoxStroke, Library.TweenInfo, {
                    Color = Library.Scheme.AccentColor,
                }):Play()
            end)))

            table.insert(Slider.Connections, InputTextBox.FocusLost:Connect(ObsGuard(function()
                if Slider.Disabled then
                    return
                end

                Library.Registry[InputTextBoxStroke].Color = "OutlineColor"
                TweenService:Create(InputTextBoxStroke, Library.TweenInfo, {
                    Color = Library.Scheme.OutlineColor,
                }):Play()
            end)))
        end

        local LastTap = 0
        table.insert(Slider.Connections, Bar.InputBegan:Connect(ObsGuard(function(Input: InputObject)
            local ValidInput = IsClickInput(Input) or Input.UserInputType == Enum.UserInputType.MouseButton2
            if not ValidInput or Slider.Disabled then
                return
            end

            if Info.AllowRightClickInput then
                local IsRightClick = Input.UserInputType == Enum.UserInputType.MouseButton2
                local IsDoubleTap = false

                if Library.IsMobile and Input.UserInputType == Enum.UserInputType.Touch then
                    if tick() - LastTap < 0.3 then
                        IsDoubleTap = true
                    end
                    
                    LastTap = tick()
                end

                if IsRightClick or IsDoubleTap then
                    InputTextBox.Text = tostring(Slider.Value)
                    InputTextBox.Visible = true
                    DisplayLabel.Visible = false

                    task.spawn(InputTextBox.CaptureFocus, InputTextBox)
                    return
                end
            end

            if not IsClickInput(Input) then
                return
            end

            if Library.ActiveTab then
                for _, Side in Library.ActiveTab.Sides do
                    Side.ScrollingEnabled = false
                end
            end

            if Library.ActiveLoading and Library.ActiveLoading.Sidebar then
                Library.ActiveLoading.Sidebar.Container.ScrollingEnabled = false
            end

            Dragging = true
            KnobState()

            while IsDragInput(Input) and not Slider.Destroyed do
                local Location = (Input.UserInputType == Enum.UserInputType.Touch) and Input.Position.X or Mouse.X
                local Scale = math.clamp((Location - Track.AbsolutePosition.X) / math.max(Track.AbsoluteSize.X, 1), 0, 1)
                local Raw = Slider.Min + ((Slider.Max - Slider.Min) * Scale)
                if SnapStep and Info.Snap ~= false then
                    local Nearest = math.floor(Raw / SnapStep + 0.5) * SnapStep
                    if Nearest >= Slider.Min and Nearest <= Slider.Max and math.abs(Raw - Nearest) <= SnapStep * 0.4 then
                        Raw = Nearest
                        if Slider.SnappedAt ~= Nearest then
                            Slider.SnappedAt = Nearest
                            Library:Spring(Knob, "Size", UDim2.fromOffset(18, 18), 40, 0.5)
                            task.delay(0.07, KnobState)
                        end
                    else
                        Slider.SnappedAt = nil
                    end
                end

                local OldValue = Slider.Value
                Slider.DragX = math.clamp((Raw - Slider.Min) / math.max(Slider.Max - Slider.Min, 1e-9), 0, 1)
                Slider.Value = Round(Raw, Slider.Rounding)

                Slider:Display()
                if Slider.Value ~= OldValue then
                    Slider:RunChanged()
                end

                RunService.RenderStepped:Wait()
            end

            Dragging = false
            Slider.DragX = nil
            KnobState()
            Slider:Display()

            if Library.ActiveTab then
                for _, Side in Library.ActiveTab.Sides do
                    Side.ScrollingEnabled = Library.SmoothScrollers[Side] == nil
                end
            end

            if Library.ActiveLoading and Library.ActiveLoading.Sidebar then
                Library.ActiveLoading.Sidebar.Container.ScrollingEnabled = true
            end
        end)))

        if typeof(Slider.Tooltip) == "string" or typeof(Slider.DisabledTooltip) == "string" then
            Slider.TooltipTable = Library:AddTooltip(Slider.Tooltip, Slider.DisabledTooltip, Bar)
            Slider.TooltipTable.Disabled = Slider.Disabled
        end

        Slider:UpdateColors()
        Slider:Display()
        Groupbox:Resize()

        Slider.Holder = Holder
        table.insert(Groupbox.Elements, Slider)

        Slider.Default = Slider.Value

        Options[Idx] = Slider

        function Slider:Destroy()
            Slider.Destroyed = true

            if Slider.Connections then
                for _, Connection in Slider.Connections do
                    Connection:Disconnect()
                end
            end

            if Slider.TooltipTable then 
                Slider.TooltipTable:Destroy() 
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Slider)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Slider
    end

    function Funcs:AddDropdown(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Dropdown)

        local Groupbox = self
        local Container = Groupbox.Container

        if Info.SpecialType == "Player" then
            Info.Values = GetPlayers(Info.ExcludeLocalPlayer)
            Info.AllowNull = true
        elseif Info.SpecialType == "Team" then
            Info.Values = GetTeams()
            Info.AllowNull = true
        end

        local Dropdown = {
            Connections = {},
            Destroyed = false,

            Text = typeof(Info.Text) == "string" and Info.Text or nil,

            Value = Info.Multi and {} or nil,
            Values = Info.Values,
            DisabledValues = Info.DisabledValues,
            ValueImages = Info.ValueImages,
            ValueImageColor = Info.ValueImageColor,
            ValueSuffixImages = Info.ValueSuffixImages,
            ValueColors = Info.ValueColors,
            SuffixAfterText = Info.SuffixAfterText,

            Multi = Info.Multi,
            DragSelect = Info.Multi and not Library.IsMobile and Info.DragSelect == true,

            SpecialType = Info.SpecialType,
            ExcludeLocalPlayer = Info.ExcludeLocalPlayer,
            EnablePlayerImages = Info.EnablePlayerImages,

            Tooltip = Info.Tooltip,
            DisabledTooltip = Info.DisabledTooltip,
            TooltipTable = nil,

            Callback = Info.Callback,
            Changed = Info.Changed,

            Disabled = Info.Disabled,
            Visible = Info.Visible,

            Type = "Dropdown",
            Loading = Info.Loading == true,
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Dropdown.Text and 39 or 21),
            Visible = Dropdown.Visible,
            Parent = Container,
        })

        local Label = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            Text = Dropdown.Text,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Visible = not not Info.Text,
            ZIndex = 3,
            Parent = Holder,
        })

        local DisplayContainer = New("TextButton", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 21),
            Text = "",
            TextTransparency = 1,
            ZIndex = 2,
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingLeft = UDim.new(0, 11),
            PaddingRight = UDim.new(0, 4),
            Parent = DisplayContainer,
        })

        local DisplayStroke = New("UIStroke", {
            Color = "OutlineColor",
            Parent = DisplayContainer,
        })

        local DropdownCorner = New("UICorner", {
            TopLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            TopRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomRightRadius = UDim.new(0, Library.CornerRadius / 2),
            BottomLeftRadius = UDim.new(0, Library.CornerRadius / 2),
            Parent = DisplayContainer,
        }); table.insert(Library.SpecificCorners, DropdownCorner)

        local DisplayImage = New("ImageLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 2),
            Size = UDim2.fromOffset(17, 17),
            ScaleType = Enum.ScaleType.Fit,
            Image = "",
            ImageTransparency = 1,
            ZIndex = 2,
            Parent = DisplayContainer,
        })
        New("UICorner", {
            CornerRadius = UDim.new(0, 4),
            Parent = DisplayImage,
        })

        local DisplaySuffix = New("ImageLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 4),
            Size = UDim2.fromOffset(14, 14),
            ScaleType = Enum.ScaleType.Fit,
            Image = "",
            Visible = false,
            ZIndex = 3,
            Parent = DisplayContainer,
        })

        local DisplayRow = New("Frame", {
            BackgroundTransparency = 1,
            ClipsDescendants = true,
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(1, -20, 0, 21),
            Visible = false,
            ZIndex = 3,
            Parent = DisplayContainer,
        })

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Padding = UDim.new(0, 3),
            Parent = DisplayRow,
        })

        local DisplayButton = New("TextButton", {
            Active = not Dropdown.Disabled,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -18, 0, 21),
            Text = "---",
            RichText = true,
            TextSize = 14,
            TextTruncate = Enum.TextTruncate.SplitWord,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 2,
            Parent = DisplayContainer,
        })

        local ArrowImage = New("ImageLabel", {
            AnchorPoint = Vector2.new(1, 0.5),
            Image = ArrowIcon and ArrowIcon.Url or "",
            ImageColor3 = "FontColor",
            ImageRectOffset = ArrowIcon and ArrowIcon.ImageRectOffset or Vector2.zero,
            ImageRectSize = ArrowIcon and ArrowIcon.ImageRectSize or Vector2.zero,
            ImageTransparency = 0.5,
            Position = UDim2.fromScale(1, 0.5),
            Rotation = 180,
            Size = UDim2.fromOffset(16, 16),
            ZIndex = 6,
            Parent = DisplayContainer,
        })

        local DisplayDim = New("Frame", {
            BackgroundColor3 = "MainColor",
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(-11, 0),
            Size = UDim2.new(1, 15, 1, 0),
            ZIndex = 5,
            Parent = DisplayContainer,
        })
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius / 2),
            Parent = DisplayDim,
        })

        local DisplaySuffixText = New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(0, 0, 0, 21),
            Text = "",
            TextColor3 = "FontColor",
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Visible = false,
            ZIndex = 3,
            Parent = DisplayContainer,
        })

        local function PlaceDisplaySuffix()
            if not DisplaySuffix.Visible then
                DisplaySuffixText.Visible = false
                return
            end
            local X = DisplayButton.Position.X.Offset + math.ceil(DisplayButton.TextBounds.X) + 4
            DisplaySuffix.Position = UDim2.fromOffset(X, 4)
            local After = Dropdown.SuffixAfterText
            if type(After) == "string" and After ~= "" then
                DisplaySuffixText.Text = After
                DisplaySuffixText.TextTransparency = DisplaySuffix.ImageTransparency
                DisplaySuffixText.Position = UDim2.fromOffset(X + 16, 0)
                DisplaySuffixText.Visible = true
            else
                DisplaySuffixText.Visible = false
            end
        end
        table.insert(Dropdown.Connections, DisplayButton:GetPropertyChangedSignal("TextBounds"):Connect(ObsGuard(PlaceDisplaySuffix)))

        local SearchBox
        if Info.Searchable then
            SearchBox = New("TextBox", {
                BackgroundTransparency = 1,
                ClipsDescendants = true,
                TextTruncate = Enum.TextTruncate.AtEnd,
                PlaceholderText = "Search...",
                Position = UDim2.fromOffset(-8, 0),
                Size = UDim2.new(1, -12, 1, 0),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Visible = false,
                Parent = DisplayButton,
            })
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 8),
                Parent = SearchBox,
            })

            table.insert(Dropdown.Connections, SearchBox.Focused:Connect(ObsGuard(function()
                Library.Registry[DisplayStroke].Color = "AccentColor"
                TweenService:Create(DisplayStroke, Library.TweenInfo, {
                    Color = Library.Scheme.AccentColor,
                }):Play()
            end)))

            table.insert(Dropdown.Connections, SearchBox.FocusLost:Connect(ObsGuard(function()
                Library.Registry[DisplayStroke].Color = "OutlineColor"
                TweenService:Create(DisplayStroke, Library.TweenInfo, {
                    Color = Library.Scheme.OutlineColor,
                }):Play()
            end)))
        end

        local GetValueImage = function(Value, RawValue)
            if not Value then
                return nil
            end

            local ValueImage = nil
            if Dropdown.SpecialType == "Player" and Dropdown.EnablePlayerImages == true then
                local PlayerValue = Value
                if typeof(PlayerValue) ~= "Instance" and RawValue ~= nil then
                    PlayerValue = RawValue
                end

                if typeof(PlayerValue) == "Instance" and PlayerValue:IsA("Player") then
                    ValueImage = { Url = string.format("rbxthumb://type=AvatarHeadShot&id=%s&w=48&h=48", tostring(PlayerValue.UserId)) }
                end
            else
                if Info.ValueImages then
                    local IconRef = Info.ValueImages[Value]
                    if IconRef == nil and RawValue ~= nil then
                        IconRef = Info.ValueImages[RawValue]
                    end

                    if IconRef then
                        ValueImage = Library:GetCustomIcon(IconRef)
                    end
                end
            end

            return ValueImage
        end

        local function GetValueSuffixImage(Value, RawValue)
            local Map = Dropdown.ValueSuffixImages or Info.ValueSuffixImages
            if type(Map) ~= "table" then
                return nil
            end
            local IconRef = Map[Value]
            if IconRef == nil and RawValue ~= nil then
                IconRef = Map[RawValue]
            end
            if IconRef == nil then
                return nil
            end
            if type(IconRef) == "table" and IconRef.Url then
                return IconRef
            end
            local Icon = Library:GetCustomIcon(IconRef)
            if Icon and Icon.Url and Icon.Url ~= "" then
                return Icon
            end
            return nil
        end

        local function GetValueColor(Value, RawValue)
            local Map = Dropdown.ValueColors
            if Value == nil then
                return nil
            end
            local Color = nil
            if type(Map) == "function" then
                local Ok, Result = pcall(Map, Value, RawValue)
                Color = Ok and Result or nil
            elseif type(Map) == "table" then
                Color = Map[Value]
                if Color == nil and RawValue ~= nil then
                    Color = Map[RawValue]
                end
            else
                return nil
            end
            if typeof(Color) == "Color3" then
                return Color
            end
            if type(Color) == "string" then
                local Ok, Parsed = pcall(Color3.fromHex, Color)
                if Ok then
                    return Parsed
                end
            end
            return nil
        end

        local function ImageTint(Value)
            local Tint = Dropdown.ValueImageColor
            if type(Tint) == "function" then
                local Ok, Result = pcall(Tint, Value)
                Tint = Ok and Result or nil
            end
            return typeof(Tint) == "Color3" and Tint or Color3.new(1, 1, 1)
        end

        function Dropdown:SetValueImageColor(Tint)
            Dropdown.ValueImageColor = Tint
            Dropdown:Display()
            pcall(function()
                Dropdown:RefreshPool()
            end)
        end

        local function PaintColor(Object, Property, Color, Fallback)
            Library.Registry[Object] = Library.Registry[Object] or {}
            if Color then
                Library.Registry[Object][Property] = function()
                    return Color
                end
                Object[Property] = Color
            else
                Library.Registry[Object][Property] = Fallback
                Object[Property] = Library.Scheme[Fallback]
            end
        end

        function Dropdown:SetValueColors(Colors)
            Dropdown.ValueColors = Colors
            Dropdown:Display()
            pcall(function()
                Dropdown:RefreshPool()
            end)
        end

        local MenuTable = Library:AddContextMenu(
            DisplayContainer,
            function()
                return UDim2.fromOffset((DisplayContainer.AbsoluteSize.X / Library.DPIScale), 0)
            end,
            function()
                return { 0, DisplayContainer.AbsoluteSize.Y + 5 }
            end,
            2,
            function(Active: boolean)
                DisplayButton.TextTransparency = (Active and SearchBox) and 1 or 0
                Dropdown.SearchOpen = (Active and SearchBox) and true or false
                if Dropdown.Skeleton then
                    Dropdown.Skeleton.Visible = Dropdown.ShowingSkeleton == true and not Dropdown.SearchOpen
                end
                if SearchBox then
                    if Active then
                        DisplayRow.Visible = false
                    else
                        DisplayImage.Visible = true
                        pcall(function() Dropdown:Display() end)
                    end
                end
                if Active and type(Dropdown.BuildDropdownList) == "function" then
                    pcall(function() Dropdown:BuildDropdownList() end)
                end
                if Active and Dropdown.AnimateOpen then
                    task.defer(function()
                        pcall(function() Dropdown:AnimateOpen() end)
                    end)
                end

                TweenService:Create(ArrowImage, Library.TweenInfo, {
                    ImageTransparency = Active and 0 or 0.5,
                    Rotation = Active and 0 or 180,
                }):Play()
                TweenService:Create(DisplayDim, Library.TweenInfo, {
                    BackgroundTransparency = (Active and not SearchBox) and 0.45 or 1,
                }):Play()

                if SearchBox then
                    SearchBox.Text = ""
                    SearchBox.Visible = Active
                end

                if Dropdown.SetKeyboard then
                    Dropdown.SetKeyboard(Active)
                end
            end,
            false,
            nil,
            "Dropdown"
        )
        Dropdown.Menu = MenuTable
        Library.Registry[MenuTable.Menu] = Library.Registry[MenuTable.Menu] or {}
        Library.Registry[MenuTable.Menu].BackgroundColor3 = "MainColor"
        MenuTable.Menu.BackgroundColor3 = Library.Scheme.MainColor
        MenuTable.Menu.ScrollBarThickness = Library.IsMobile and 5 or 4
        MenuTable.Menu.ScrollBarImageTransparency = 0.55
        MenuTable.Menu.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
        Library.Registry[MenuTable.Menu] = Library.Registry[MenuTable.Menu] or {}
        Library.Registry[MenuTable.Menu].ScrollBarImageColor3 = "FontColor"
        MenuTable.Menu.ScrollBarImageColor3 = Library.Scheme.FontColor
        pcall(function()
            local MenuCorner = MenuTable.Menu:FindFirstChildOfClass("UICorner")
            if MenuCorner then
                MenuCorner.CornerRadius = UDim.new(0, 6)
            end
        end)

        local ItemHeight = 26
        local EmptyLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 4),
            Size = UDim2.new(1, 0, 0, ItemHeight),
            Text = "No results",
            TextSize = 13,
            TextTransparency = 0.55,
            Visible = false,
            Parent = MenuTable.Menu,
        })
        local PoolSize = math.max(1, Info.MaxVisibleDropdownItems + 2)
        local Pool = {}
        local FilteredEntries = {}

        function Dropdown:RecalculateListSize(Count)
            local ItemCount = Count or #FilteredEntries
            local Empty = ItemCount == 0 and Dropdown.ShowingSkeleton ~= true
            EmptyLabel.Visible = Empty
            local Y = math.clamp(math.max(ItemCount, Empty and 1 or 0) * ItemHeight, 0, Info.MaxVisibleDropdownItems * ItemHeight) + 8

            MenuTable.Menu.CanvasSize = UDim2.fromOffset(0, ItemCount * ItemHeight + 8)

            MenuTable:SetSize(function()
                return UDim2.fromOffset((DisplayContainer.AbsoluteSize.X / Library.DPIScale), Y)
            end)
        end

        function Dropdown:UpdateColors()
            if Library.Unloaded then
                return
            end

            Label.TextTransparency = Dropdown.Disabled and 0.8 or 0
            DisplayButton.TextTransparency = Dropdown.Disabled and 0.8 or 0
            DisplayImage.ImageTransparency = Dropdown.Disabled and 0.8 or 0
            ArrowImage.ImageTransparency = Dropdown.Disabled and 0.8 or MenuTable.Active and 0 or 0.5
        end

        function Dropdown:Display()
            if Library.Unloaded then
                return
            end

            local LoadingProbe = Dropdown.Value
            if typeof(LoadingProbe) ~= "string" and typeof(Dropdown.Values) == "table" and IsSequentialArray(Dropdown.Values) and #Dropdown.Values == 1 then
                LoadingProbe = Dropdown.Values[1]
            end
            local IsLoading = Dropdown.Loading == true
                or (typeof(LoadingProbe) == "string" and LoadingProbe:match("^%s*[Ll]oading[^%w]*$") ~= nil)
            local WasLoading = Dropdown.ShowingSkeleton
            Dropdown.ShowingSkeleton = IsLoading
            if WasLoading ~= nil and WasLoading ~= IsLoading and MenuTable.Active then
                task.defer(function()
                    pcall(function()
                        Dropdown:RefreshPool()
                    end)
                end)
            end

            if IsLoading then
                if not Dropdown.Skeleton then
                    Dropdown.Skeleton = Library:CreateShimmer(DisplayContainer, 0.4 + math.random() * 0.2)
                end
                Dropdown.Skeleton.Visible = not Dropdown.SearchOpen
                DisplayButton.Text = ""
                DisplayRow.Visible = false
                DisplayImage.Image = ""
                DisplayImage.ImageTransparency = 1
                DisplaySuffix.Visible = false
                DisplaySuffixText.Visible = false
                if SearchBox then
                    SearchBox.PlaceholderText = "Search..."
                end
                return
            elseif Dropdown.Skeleton then
                Dropdown.Skeleton.Visible = false
            end

            local Str = ""
            local SelectedEntries = {}
            local ValueImage = nil
            local IsDictionary = not IsSequentialArray(Dropdown.Values)

            if Info.Multi then
                for Key, RawValue in Dropdown.Values do
                    local Value = IsDictionary and Key or RawValue

                    if Dropdown.Value[Value] then
                        local EntryImage = GetValueImage(Value, RawValue)
                        if not ValueImage then
                            ValueImage = EntryImage
                        end

                        local EntryText = Info.FormatDisplayValue
                                and tostring(Info.FormatDisplayValue(RawValue))
                            or tostring(RawValue)

                        table.insert(SelectedEntries, { Text = EntryText, Image = EntryImage, Color = GetValueColor(Value, RawValue) })
                        Str = Str .. EntryText .. ", "
                    end
                end
            else
                local DisplayValue = Dropdown.Value
                if IsDictionary and Dropdown.Value ~= nil then
                    DisplayValue = Dropdown.Values[Dropdown.Value]
                end

                ValueImage = GetValueImage(Dropdown.Value, DisplayValue)
                Str = DisplayValue and tostring(DisplayValue) or ""

                if Str ~= "" and Info.FormatDisplayValue then
                    Str = tostring(Info.FormatDisplayValue(Str))
                end
            end

            local Plain = Str:gsub("<[^<>]->", "")

            if Info.Multi then
                Str = Str:gsub(",%s*$", "")
            end
            DisplayButton.Text = (Str == "" and "---" or Str)
            if not Info.Multi then
                PaintColor(DisplayButton, "TextColor3", GetValueColor(Dropdown.Value, IsDictionary and Dropdown.Value ~= nil and Dropdown.Values[Dropdown.Value] or nil), "FontColor")
            end
            if SearchBox then
                local Shown = Plain:gsub(",%s*$", "")
                if Info.Multi then
                    Shown = #SelectedEntries > 0 and (#SelectedEntries .. " selected · Search...") or ""
                end
                SearchBox.PlaceholderText = (Shown ~= "" and Shown) or "Search..."
            end

            for _, Child in DisplayRow:GetChildren() do
                if not Child:IsA("UIListLayout") then
                    Child:Destroy()
                end
            end

            local UseRow = Info.Multi and #SelectedEntries > 0

            if UseRow then
                local Order = 0
                local Faded = Dropdown.Disabled and 0.8 or 0
                local Shown = math.min(#SelectedEntries, 12)
                local ChipList = {}
                Dropdown.ChipToken = (Dropdown.ChipToken or 0) + 1
                local Token = Dropdown.ChipToken

                local function AddChip(Text, Image, Extra, Color, Fresh)
                    Order = Order + 1
                    local Chip = New("Frame", {
                        AutomaticSize = Enum.AutomaticSize.X,
                        BackgroundColor3 = Extra and "MainColor" or (Color and function() return Color end) or "AccentColor",
                        BackgroundTransparency = Extra and 0 or 0.8,
                        BorderSizePixel = 0,
                        LayoutOrder = Order,
                        Size = UDim2.fromOffset(0, 16),
                        ZIndex = 3,
                        Parent = DisplayRow,
                    })
                    New("UICorner", {
                        CornerRadius = UDim.new(0, 3),
                        Parent = Chip,
                    })
                    New("UIPadding", {
                        PaddingLeft = UDim.new(0, Image and 2 or 5),
                        PaddingRight = UDim.new(0, 5),
                        Parent = Chip,
                    })
                    New("UIListLayout", {
                        FillDirection = Enum.FillDirection.Horizontal,
                        Padding = UDim.new(0, 4),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                        Parent = Chip,
                    })
                    if Image then
                        local Icon = New("ImageLabel", {
                            BackgroundTransparency = 1,
                            Image = Image.Url,
                            ImageRectOffset = Image.ImageRectOffset or Vector2.zero,
                            ImageRectSize = Image.ImageRectSize or Vector2.zero,
                            ImageTransparency = Faded,
                            LayoutOrder = 1,
                            ScaleType = Enum.ScaleType.Fit,
                            Size = UDim2.fromOffset(13, 13),
                            ZIndex = 3,
                            Parent = Chip,
                        })
                        New("UICorner", {
                            CornerRadius = UDim.new(0, 3),
                            Parent = Icon,
                        })
                    end
                    New("TextLabel", {
                        AutomaticSize = Enum.AutomaticSize.X,
                        BackgroundTransparency = 1,
                        LayoutOrder = 2,
                        Size = UDim2.fromOffset(0, 16),
                        RichText = true,
                        Text = Text,
                        TextColor3 = (Color and function() return Color:Lerp(Color3.new(1, 1, 1), 0.45) end) or "FontColor",
                        TextSize = 12,
                        TextTransparency = Extra and math.max(Faded, 0.35) or Faded,
                        ZIndex = 3,
                        Parent = Chip,
                    })
                    if Fresh then
                        local PopInfo = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
                        local ChipGoal = Chip.BackgroundTransparency
                        Chip.BackgroundTransparency = 1
                        TweenService:Create(Chip, PopInfo, { BackgroundTransparency = ChipGoal }):Play()
                        for _, Part in ipairs(Chip:GetChildren()) do
                            if Part:IsA("TextLabel") then
                                local Goal = Part.TextTransparency
                                Part.TextTransparency = 1
                                TweenService:Create(Part, PopInfo, { TextTransparency = Goal }):Play()
                            elseif Part:IsA("ImageLabel") then
                                local Goal = Part.ImageTransparency
                                Part.ImageTransparency = 1
                                TweenService:Create(Part, PopInfo, { ImageTransparency = Goal }):Play()
                            end
                        end
                    end
                    return Chip
                end

                local Previous = Dropdown.LastChips
                local Current = {}
                for Index = 1, Shown do
                    local Entry = SelectedEntries[Index]
                    Current[Entry.Text] = true
                    ChipList[Index] = AddChip(Entry.Text, Entry.Image, false, Entry.Color, Previous ~= nil and not Previous[Entry.Text])
                end
                Dropdown.LastChips = Current

                local Total = #SelectedEntries
                task.defer(function()
                    if Dropdown.ChipToken ~= Token or not DisplayRow.Parent then
                        return
                    end
                    local Available = DisplayRow.AbsoluteSize.X
                    local Gap = 3 * Library.DPIScale
                    local Widths, Sum = {}, 0
                    for Index, Chip in ipairs(ChipList) do
                        Widths[Index] = Chip.AbsoluteSize.X
                        Sum += Widths[Index] + (Index > 1 and Gap or 0)
                    end

                    if Sum <= Available and Total == #ChipList then
                        return
                    end

                    local Plus = AddChip("+" .. tostring(Total), nil, true)
                    local PlusWidth = math.max(Plus.AbsoluteSize.X, ((#tostring(Total) + 1) * 7 + 10) * Library.DPIScale) + Gap

                    local Keep, Used = 0, 0
                    for Index, Width in ipairs(Widths) do
                        local Next = Used + (Index > 1 and Gap or 0) + Width
                        local Rest = Total - Index
                        if Next + (Rest > 0 and PlusWidth or 0) > Available and Index > 1 then
                            break
                        end
                        Keep, Used = Index, Next
                    end
                    Keep = math.max(Keep, 1)

                    for Index = Keep + 1, #ChipList do
                        ChipList[Index]:Destroy()
                    end
                    local Hidden = Total - Keep
                    if Hidden > 0 then
                        local Label = Plus:FindFirstChildOfClass("TextLabel")
                        if Label then
                            Label.Text = "+" .. tostring(Hidden)
                        end
                    else
                        Plus:Destroy()
                    end
                end)

                DisplayRow.Visible = not Dropdown.SearchOpen
                DisplayButton.Text = ""
                DisplayButton.Size = UDim2.new(1, 0, 0, 21)
                DisplayButton.Position = UDim2.fromOffset(0, 0)
                DisplayImage.Image = ""
                DisplayImage.ImageTransparency = 1
                DisplaySuffix.Visible = false
                DisplaySuffixText.Visible = false
                return
            end

            DisplayRow.Visible = false
            
            if ValueImage then
                DisplayImage.Image = ValueImage.Url
                DisplayImage.ImageRectOffset = ValueImage.ImageRectOffset or Vector2.zero
                DisplayImage.ImageRectSize = ValueImage.ImageRectSize or Vector2.zero
                DisplayImage.ImageColor3 = ImageTint(Dropdown.Value)
                DisplayImage.ImageTransparency = 0
            else
                DisplayImage.Image = ""
                DisplayImage.ImageTransparency = 1
            end

            DisplayButton.Size = ValueImage and UDim2.new(1, -44, 0, 21) or UDim2.new(1, -18, 0, 21)
            DisplayButton.Position = ValueImage and UDim2.fromOffset(26, 0) or UDim2.fromOffset(0, 0)

            local SuffixImage = nil
            if not Info.Multi and Dropdown.Value ~= nil and Str ~= "" and not Dropdown.SearchOpen then
                local RawForSuffix = Dropdown.Value
                if IsDictionary then
                    RawForSuffix = Dropdown.Values[Dropdown.Value]
                end
                SuffixImage = GetValueSuffixImage(Dropdown.Value, RawForSuffix)
            end
            if SuffixImage then
                DisplaySuffix.Image = SuffixImage.Url
                DisplaySuffix.ImageRectOffset = SuffixImage.ImageRectOffset or Vector2.zero
                DisplaySuffix.ImageRectSize = SuffixImage.ImageRectSize or Vector2.zero
                DisplaySuffix.ImageTransparency = Dropdown.Disabled and 0.8 or 0
                DisplaySuffix.Visible = true
                PlaceDisplaySuffix()
            else
                DisplaySuffix.Visible = false
                DisplaySuffixText.Visible = false
            end
        end

        function Dropdown:OnChanged(Func)
            Dropdown.Changed = Func
        end

        function Dropdown:SetLoading(State)
            Dropdown.Loading = State == true
            Dropdown:Display()
        end

        function Dropdown:GetActiveValues(ReturnCount)
            local Table = {}

            if Info.Multi then
                for Value, _ in Dropdown.Value do
                    table.insert(Table, Value)
                end
            else
                if Dropdown.Value then
                    table.insert(Table, Dropdown.Value)
                end
            end

            return ReturnCount == true and GetTableSize(Table) or Table
        end

        local DragSelecting = false
        local DragStartIndex = nil
        local DragPrevMin = nil
        local DragPrevMax = nil
        local DragLastIndex = nil
        local DragInitialValues = {}
        local DragInputEndedConn = nil
        local DragInputChangedConn = nil

        local function RecomputeFilteredEntries()
            local Values = Dropdown.Values
            local DisabledValues = Dropdown.DisabledValues
            local IsDictionary = not IsSequentialArray(Values)

            local EnabledList, DisabledList = {}, {}
            local Pending = {}

            for Key, RawValue in Values do
                local Value = IsDictionary and Key or RawValue

                local FormattedValue = tostring(Info.FormatListValue and Info.FormatListValue(RawValue) or RawValue)
                if SearchBox and not FormattedValue:lower():find(SearchBox.Text:lower(), 1, true) then
                    continue
                end

                local IsDisabled = table.find(DisabledValues, Value) ~= nil
                    or (RawValue ~= nil and RawValue ~= Value and table.find(DisabledValues, RawValue) ~= nil)

                local Entry = {
                    Value = Value,
                    RawValue = RawValue,
                    FormattedValue = FormattedValue,
                    IsDisabled = IsDisabled,
                    ValueImage = GetValueImage(Value, RawValue),
                    SortKey = Key,
                }

                table.insert(Pending, Entry)
            end

            if not IsDictionary then
                table.sort(Pending, function(A, B)
                    return A.SortKey < B.SortKey
                end)
            end

            for _, Entry in Pending do
                if Entry.IsDisabled then
                    table.insert(DisabledList, Entry)
                else
                    table.insert(EnabledList, Entry)
                end
            end

            table.clear(FilteredEntries)
            Dropdown.KeyIndex = nil
            for _, Entry in EnabledList do
                table.insert(FilteredEntries, Entry)
            end
            for _, Entry in DisabledList do
                table.insert(FilteredEntries, Entry)
            end
        end

        local function GetFirstVisibleIndex()
            local Total = #FilteredEntries
            if Total <= PoolSize then
                return 1
            end

            local MaxFirst = Total - PoolSize + 1
            local ScrollY = MenuTable.Menu.CanvasPosition.Y / Library.DPIScale
            local Index = math.floor(ScrollY / ItemHeight) + 1
            return math.clamp(Index, 1, MaxFirst)
        end

        function Dropdown:RefreshPool()
            local Total = #FilteredEntries
            local First = GetFirstVisibleIndex()

            for SlotIndex, Row in Pool do
                local DataIndex = First + SlotIndex - 1
                local Entry = FilteredEntries[DataIndex]

                Row.Entry = Entry
                Row.Index = Entry and DataIndex or nil

                if not Entry then
                    Row.Container.Visible = false
                    continue
                end

                Row.Container.Visible = true
                if Row.OpenTweens then
                    for _, Tween in Row.OpenTweens do
                        Tween:Cancel()
                    end
                    Row.OpenTweens = nil
                end
                Row.Container.Position = UDim2.fromOffset(4, 5 + (DataIndex - 1) * ItemHeight)

                Row.Button.Text = Entry.FormattedValue
                if Dropdown.ShowingSkeleton == true then
                    if not Row.Skeleton then
                        Row.Skeleton = Library:CreateShimmer(Row.Container, 0.45 + math.random() * 0.25)
                        Row.Skeleton.Position = UDim2.fromOffset(9, 0)
                        Row.Skeleton.Size = UDim2.new(1, -18, 1, 0)
                        Row.Skeleton.ZIndex = Row.Container.ZIndex + 1
                        for _, Part in ipairs(Row.Skeleton:GetDescendants()) do
                            if Part:IsA("GuiObject") then
                                Part.ZIndex = Row.Container.ZIndex + 2
                            end
                        end
                    end
                    Row.Skeleton.Visible = true
                    Row.Button.Text = ""
                elseif Row.Skeleton then
                    Row.Skeleton.Visible = false
                end

                if Entry.ValueImage then
                    Row.Image.Visible = true
                    Row.Image.Image = Entry.ValueImage.Url
                    Row.Image.ImageRectOffset = Entry.ValueImage.ImageRectOffset or Vector2.zero
                    Row.Image.ImageRectSize = Entry.ValueImage.ImageRectSize or Vector2.zero
                    Row.Image.ImageColor3 = ImageTint(Entry.Value)
                    Row.Button.Size = UDim2.new(1, -54, 1, 0)
                    Row.Button.Position = UDim2.fromOffset(32, 0)
                else
                    Row.Image.Visible = false
                    Row.Button.Size = UDim2.new(1, -22, 1, 0)
                    Row.Button.Position = UDim2.fromOffset(0, 0)
                end

                local Suffix = GetValueSuffixImage(Entry.Value, Entry.RawValue)
                if Suffix and Row.Suffix then
                    Row.Suffix.Image = Suffix.Url
                    Row.Suffix.ImageRectOffset = Suffix.ImageRectOffset or Vector2.zero
                    Row.Suffix.ImageRectSize = Suffix.ImageRectSize or Vector2.zero
                    Row.Suffix.Visible = true
                    Row.PlaceSuffix()
                elseif Row.Suffix then
                    Row.Suffix.Visible = false
                    if Row.SuffixText then Row.SuffixText.Visible = false end
                end

                Row:UpdateButton()
            end
            if Dropdown.ApplyKeyHighlight then
                Dropdown.ApplyKeyHighlight()
            end
        end

        function Dropdown:AnimateOpen()
            local Rows = {}
            for _, Row in Pool do
                if Row.Container.Visible and Row.Index then
                    table.insert(Rows, Row)
                end
            end
            table.sort(Rows, function(A, B)
                return A.Index < B.Index
            end)

            for Order, Row in ipairs(Rows) do
                local Delay = math.min(Order - 1, 10) * 0.022
                local Info = TweenInfo.new(0.26, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, Delay)
                local Home = Row.Container.Position
                local TextGoal = Row.Button.TextTransparency

                Row.Container.Position = Home + UDim2.fromOffset(0, 6)
                Row.Button.TextTransparency = 1
                local Tweens = {
                    TweenService:Create(Row.Container, Info, { Position = Home }),
                    TweenService:Create(Row.Button, Info, { TextTransparency = TextGoal }),
                }

                if Row.Image.Visible then
                    local ImageGoal = Row.Image.ImageTransparency
                    Row.Image.ImageTransparency = 1
                    table.insert(Tweens, TweenService:Create(Row.Image, Info, { ImageTransparency = ImageGoal }))
                end

                Row.OpenTweens = Tweens
                for _, Tween in Tweens do
                    Tween:Play()
                end
            end
        end

        function Dropdown.ApplyKeyHighlight()
            for _, Row in Pool do
                if Row.Container.Visible and Row.Index then
                    if Row.Index == Dropdown.KeyIndex then
                        Row.Container.BackgroundTransparency = 0.35
                        Row.KeyLit = true
                    elseif Row.KeyLit then
                        Row.Container.BackgroundTransparency = 1
                        Row.KeyLit = false
                    end
                end
            end
        end

        local function KeyScrollTo(Index)
            local Menu = MenuTable.Menu
            local Scale = Library.DPIScale
            local RowTop = 5 + (Index - 1) * ItemHeight
            local View = Menu.AbsoluteSize.Y / Scale
            local Current = Menu.CanvasPosition.Y / Scale
            if RowTop < Current then
                Menu.CanvasPosition = Vector2.new(0, math.max(RowTop - 5, 0) * Scale)
            elseif RowTop + ItemHeight > Current + View then
                Menu.CanvasPosition = Vector2.new(0, (RowTop + ItemHeight - View + 5) * Scale)
            end
        end

        local function KeyPick(Entry)
            if not Entry or Entry.IsDisabled or Dropdown.ShowingSkeleton == true then
                return
            end
            if Info.Multi then
                local Selected = Dropdown.Value[Entry.Value] and true or false
                if Selected and Dropdown:GetActiveValues(true) == 1 and not Info.AllowNull then
                    return
                end
                Dropdown.Value[Entry.Value] = (not Selected) and true or nil
            else
                Dropdown.Value = Entry.Value
            end
            for _, Row in Pool do
                Row:UpdateButton()
            end
            Dropdown:Display()
            Library:UpdateDependencyBoxes(Dropdown)
            Dropdown:RunChanged()
            if not Info.Multi then
                MenuTable:Close()
            end
        end

        local function KeyMove(Step)
            local Total = #FilteredEntries
            if Total == 0 then
                return
            end
            local Index = Dropdown.KeyIndex
            if not Index then
                local Scale = Library.DPIScale
                local Top = MenuTable.Menu.CanvasPosition.Y / Scale
                local View = MenuTable.Menu.AbsoluteSize.Y / Scale
                local First = math.clamp(math.ceil((Top - 5) / ItemHeight) + 1, 1, Total)
                local Last = math.clamp(math.floor((Top + View - 5) / ItemHeight), 1, Total)
                Index = Step == 1 and First - 1 or Last + 1
            end
            Index = ((Index - 1 + Step) % Total) + 1
            Dropdown.KeyIndex = Index
            KeyScrollTo(Index)
            Dropdown.ApplyKeyHighlight()
        end

        local KeyActionName = "AzureDropdownKeys" .. tostring(math.random(1, 1e9))
        function Dropdown.SetKeyboard(Active)
            if Dropdown.KeyConn then
                Dropdown.KeyConn:Disconnect()
                Dropdown.KeyConn = nil
            end
            pcall(function()
                game:GetService("ContextActionService"):UnbindAction(KeyActionName)
            end)
            Dropdown.KeyIndex = nil
            if not Active then
                Dropdown.ApplyKeyHighlight()
                return
            end

            for Index, Entry in FilteredEntries do
                local Selected
                if Info.Multi then
                    Selected = Dropdown.Value[Entry.Value]
                else
                    Selected = Dropdown.Value == Entry.Value
                end
                if Selected then
                    Dropdown.KeyIndex = Index
                    break
                end
            end

            pcall(function()
                game:GetService("ContextActionService"):BindActionAtPriority(KeyActionName, ObsGuard(function(_, State, Input)
                    if State ~= Enum.UserInputState.Begin or not MenuTable.Active or Library.Unloaded or Dropdown.Destroyed then
                        return Enum.ContextActionResult.Pass
                    end
                    local Focused = UserInputService:GetFocusedTextBox()
                    if Focused and Focused ~= SearchBox then
                        return Enum.ContextActionResult.Pass
                    end
                    if Input.KeyCode == Enum.KeyCode.Down then
                        KeyMove(1)
                    elseif Input.KeyCode == Enum.KeyCode.Up then
                        KeyMove(-1)
                    elseif Dropdown.KeyIndex then
                        KeyPick(FilteredEntries[Dropdown.KeyIndex])
                    elseif SearchBox and SearchBox.Text ~= "" and FilteredEntries[1] then
                        KeyPick(FilteredEntries[1])
                    end
                    return Enum.ContextActionResult.Sink
                end), false, 3000, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter)
            end)

            Dropdown.KeyConn = UserInputService.InputBegan:Connect(ObsGuard(function(Input)
                if Input.UserInputType ~= Enum.UserInputType.Keyboard or not MenuTable.Active then
                    return
                end
                if UserInputService:GetFocusedTextBox() ~= nil then
                    return
                end
                local Letter = Input.KeyCode.Name:match("^%a$")
                if not Letter or Letter == "W" or Letter == "A" or Letter == "S" or Letter == "D" then
                    return
                end
                Letter = Letter:lower()
                local Total = #FilteredEntries
                for Offset = 1, Total do
                    local Index = (((Dropdown.KeyIndex or 0) + Offset - 1) % Total) + 1
                    local Plain = tostring(FilteredEntries[Index].FormattedValue or ""):gsub("<[^<>]->", "")
                    if Plain:sub(1, 1):lower() == Letter then
                        Dropdown.KeyIndex = Index
                        KeyScrollTo(Index)
                        Dropdown.ApplyKeyHighlight()
                        break
                    end
                end
            end))
        end

        function Dropdown:RunChanged()
            if Dropdown.Disabled then
                return
            end

            Library:SafeCallback(Dropdown.Callback, Dropdown.Value)
            Library:SafeCallback(Dropdown.Changed, Dropdown.Value)
        end      

        local function StopDragSelect()
            DragSelecting = false
            DragStartIndex = nil
            DragPrevMin = nil
            DragPrevMax = nil
            DragLastIndex = nil
            table.clear(DragInitialValues)

            if DragInputEndedConn then
                DragInputEndedConn:Disconnect()
                DragInputEndedConn = nil
            end

            if DragInputChangedConn then
                DragInputChangedConn:Disconnect()
                DragInputChangedConn = nil
            end
        end

        local DragActiveCount = 0

        local function ApplyDragIndex(Index, InRange)
            local Entry = FilteredEntries[Index]
            if not Entry or Entry.IsDisabled then
                return
            end

            local Try = DragInitialValues[Entry.Value]
            if InRange then
                Try = not Try
            end

            local WantActive = Try and true or false
            local IsActive = Dropdown.Value[Entry.Value] and true or false
            if WantActive == IsActive then
                return
            end

            if not WantActive and DragActiveCount == 1 and not Info.AllowNull then
                return
            end

            Dropdown.Value[Entry.Value] = WantActive and true or nil
            DragActiveCount += WantActive and 1 or -1
        end

        local function ApplyDragRange(From, To, InRange)
            for Index = From, To do
                ApplyDragIndex(Index, InRange)
            end
        end

        local function UpdateDrag(CurrentIndex)
            if CurrentIndex == nil or CurrentIndex == DragLastIndex then
                return
            end

            DragLastIndex = CurrentIndex

            local Min = math.min(DragStartIndex, CurrentIndex)
            local Max = math.max(DragStartIndex, CurrentIndex)
            DragActiveCount = Dropdown:GetActiveValues(true)

            if DragPrevMin == nil then
                ApplyDragRange(Min, Max, true)
            else
                if DragPrevMin < Min then
                    ApplyDragRange(DragPrevMin, Min - 1, false)
                end
                if DragPrevMax > Max then
                    ApplyDragRange(Max + 1, DragPrevMax, false)
                end
                if Min < DragPrevMin then
                    ApplyDragRange(Min, DragPrevMin - 1, true)
                end
                if Max > DragPrevMax then
                    ApplyDragRange(DragPrevMax + 1, Max, true)
                end
            end

            DragPrevMin = Min
            DragPrevMax = Max

            for _, OtherRow in Pool do
                OtherRow:UpdateButton()
            end
        end

        local function CreatePoolRow()
            local Row = {
                Entry = nil,
                Index = nil
            }

            local Container = New("Frame", {
                BackgroundColor3 = function()
                    return Library:GetBetterColor(Library.Scheme.MainColor, 10)
                end,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -8, 0, ItemHeight - 2),
                Visible = false,
                Parent = MenuTable.Menu,
            })

            local Corner = New("UICorner", {
                CornerRadius = UDim.new(0, 5),
                Parent = Container,
            })

            local Tint = New("Frame", {
                BackgroundColor3 = "AccentColor",
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 1),
                Parent = Container,
            })
            New("UICorner", {
                CornerRadius = UDim.new(0, 5),
                Parent = Tint,
            })

            local Marker = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = "AccentColor",
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Position = UDim2.new(0, 3, 0.5, 0),
                Size = UDim2.fromOffset(3, 12),
                Parent = Container,
            })
            New("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = Marker,
            })

            local Check = New("ImageLabel", {
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundTransparency = 1,
                Image = CheckIcon and CheckIcon.Url or "",
                ImageColor3 = "AccentColor",
                ImageRectOffset = CheckIcon and CheckIcon.ImageRectOffset or Vector2.zero,
                ImageRectSize = CheckIcon and CheckIcon.ImageRectSize or Vector2.zero,
                ImageTransparency = 1,
                Position = UDim2.new(1, -6, 0.5, 0),
                Size = UDim2.fromOffset(14, 14),
                Parent = Container,
            })

            local Image = New("ImageLabel", {
                BackgroundTransparency = 1,
                Image = "",
                ImageTransparency = 0,
                Position = UDim2.fromOffset(10, math.floor((ItemHeight - 2 - 18) / 2)),
                ScaleType = Enum.ScaleType.Fit,
                Size = UDim2.fromOffset(18, 18),
                Visible = false,
                Parent = Container,
            })
            New("UICorner", {
                CornerRadius = UDim.new(0, 4),
                Parent = Image,
            })

            local Button = New("TextButton", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -22, 1, 0),
                Text = "",
                RichText = true,
                TextSize = 14,
                TextTruncate = Enum.TextTruncate.SplitWord,
                TextTransparency = 0.5,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Container,
            })
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 11),
                PaddingRight = UDim.new(0, 7),
                Parent = Button,
            })

            local Suffix = New("ImageLabel", {
                BackgroundTransparency = 1,
                Image = "",
                ImageTransparency = 0.25,
                ScaleType = Enum.ScaleType.Fit,
                Size = UDim2.fromOffset(14, 14),
                Position = UDim2.fromOffset(0, 4),
                Visible = false,
                ZIndex = Button.ZIndex + 1,
                Parent = Container,
            })
            local SuffixText = New("TextLabel", {
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 0, 0, ItemHeight),
                Text = "",
                TextColor3 = "FontColor",
                TextSize = 14,
                TextTransparency = 0.25,
                TextXAlignment = Enum.TextXAlignment.Left,
                Visible = false,
                ZIndex = Button.ZIndex + 1,
                Parent = Container,
            })
            local function PlaceSuffix()
                if not Suffix.Visible then
                    SuffixText.Visible = false
                    return
                end
                local X = Button.Position.X.Offset + 11 + math.ceil(Button.TextBounds.X) + 4
                Suffix.Position = UDim2.fromOffset(X, math.floor((ItemHeight - 14) / 2))
                local After = Dropdown.SuffixAfterText
                if type(After) == "string" and After ~= "" then
                    SuffixText.Text = After
                    SuffixText.Position = UDim2.fromOffset(X + 16, 0)
                    SuffixText.Visible = true
                else
                    SuffixText.Visible = false
                end
            end
            table.insert(Dropdown.Connections, Button:GetPropertyChangedSignal("TextBounds"):Connect(ObsGuard(PlaceSuffix)))

            Row.Container = Container
            Row.Corner = Corner
            Row.Image = Image
            Row.Button = Button
            Row.Suffix = Suffix
            Row.SuffixText = SuffixText
            Row.PlaceSuffix = PlaceSuffix

            function Row:UpdateButton()
                local Entry = Row.Entry
                if not Entry then
                    return
                end

                if Dropdown.ShowingSkeleton == true then
                    Row.Selected = false
                    Container.BackgroundTransparency = 1
                    Tint.BackgroundTransparency = 1
                    Marker.BackgroundTransparency = 1
                    Check.ImageTransparency = 1
                    return
                end

                local Selected
                if Info.Multi then
                    Selected = Dropdown.Value[Entry.Value]
                else
                    Selected = Dropdown.Value == Entry.Value
                end

                local WasSelected = Row.Selected
                Row.Selected = Selected and true or false
                local SameItem = Row.ShownValue == Entry.Value
                Row.ShownValue = Entry.Value

                local Animate = SameItem and WasSelected ~= nil and WasSelected ~= Row.Selected
                local function Apply(Object, Goal)
                    if Animate then
                        TweenService:Create(Object, Library.TweenInfo, Goal):Play()
                    else
                        for Property, Value in Goal do
                            Object[Property] = Value
                        end
                    end
                end

                Container.BackgroundTransparency = 1
                local RowColor = GetValueColor(Entry.Value, Entry.RawValue)
                PaintColor(Button, "TextColor3", RowColor, "FontColor")
                PaintColor(Tint, "BackgroundColor3", RowColor, "AccentColor")
                PaintColor(Check, "ImageColor3", RowColor, "AccentColor")
                PaintColor(Marker, "BackgroundColor3", RowColor, "AccentColor")
                Apply(Tint, { BackgroundTransparency = Selected and 0.86 or 1 })
                Apply(Marker, { BackgroundTransparency = Selected and 0 or 1 })
                Apply(Check, { ImageTransparency = Selected and 0 or 1 })
                Button.TextTransparency = Entry.IsDisabled and 0.8 or Selected and 0 or 0.2

                if Entry.ValueImage then
                    Image.ImageTransparency = Entry.IsDisabled and 0.6 or 0
                end
            end

            table.insert(Dropdown.Connections, Button.MouseButton1Click:Connect(ObsGuard(function()
                local Entry = Row.Entry
                if not Entry or Entry.IsDisabled or DragSelecting or Dropdown.ShowingSkeleton == true then
                    return
                end

                local Selected
                if Info.Multi then
                    Selected = Dropdown.Value[Entry.Value]
                else
                    Selected = Dropdown.Value == Entry.Value
                end

                local Try = not Selected
                if not (Dropdown:GetActiveValues(true) == 1 and not Try and not Info.AllowNull) then
                    Selected = Try
                    if Info.Multi then
                        Dropdown.Value[Entry.Value] = Selected and true or nil
                    else
                        Dropdown.Value = Selected and Entry.Value or nil
                    end

                    for _, OtherRow in Pool do
                        OtherRow:UpdateButton()
                    end
                end

                Row:UpdateButton()
                Dropdown:Display()

                Library:UpdateDependencyBoxes(Dropdown)
                Dropdown:RunChanged()
            end)))

            table.insert(Dropdown.Connections, Button.MouseEnter:Connect(ObsGuard(function()
                local Entry = Row.Entry
                if not Entry or Entry.IsDisabled then
                    return
                end

                if Row.Selected or UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
                    return
                end

                TweenService:Create(Container, Library.TweenInfo, {
                    BackgroundTransparency = 0.1,
                }):Play()
                TweenService:Create(Button, Library.TweenInfo, {
                    TextTransparency = 0,
                }):Play()
            end)))

            table.insert(Dropdown.Connections, Button.MouseLeave:Connect(ObsGuard(function()
                local Entry = Row.Entry
                if not Entry or Entry.IsDisabled then
                    return
                end

                if Row.Selected then
                    return
                end

                TweenService:Create(Container, Library.TweenInfo, {
                    BackgroundTransparency = 1,
                }):Play()
                TweenService:Create(Button, Library.TweenInfo, {
                    TextTransparency = 0.2,
                }):Play()
            end)))

            table.insert(Dropdown.Connections, Button.InputBegan:Connect(ObsGuard(function(StartInput)
                if not (Info.Multi and Dropdown.DragSelect and not Library.IsMobile) then
                    return
                end

                local Entry = Row.Entry
                if not Entry or Entry.IsDisabled then
                    return
                end

                if not IsMouseInput(StartInput) then
                    return
                end

                DragSelecting = true
                DragStartIndex = Row.Index
                table.clear(DragInitialValues)

                for _, FilteredEntry in FilteredEntries do
                    DragInitialValues[FilteredEntry.Value] = Dropdown.Value[FilteredEntry.Value]
                end

                UpdateDrag(Row.Index)

                if DragInputEndedConn then DragInputEndedConn:Disconnect() end
                if DragInputChangedConn then DragInputChangedConn:Disconnect() end

                DragInputChangedConn = UserInputService.InputChanged:Connect(ObsGuard(function(ChangeInput)
                    if not IsMovementInput(ChangeInput) and ChangeInput ~= StartInput then
                        return
                    end

                    local Pos = ChangeInput.Position
                    for _, OtherRow in Pool do
                        if OtherRow.Entry and Library:MouseIsOverFrame(OtherRow.Button, Pos) then
                            UpdateDrag(OtherRow.Index)
                            break
                        end
                    end
                end))

                DragInputEndedConn = UserInputService.InputEnded:Connect(function(EndInput)
                    if EndInput ~= StartInput and not (IsMouseInput(EndInput) and EndInput.UserInputType == StartInput.UserInputType) then
                        return
                    end

                    Dropdown:Display()
                    Library:UpdateDependencyBoxes(Dropdown)
                    Dropdown:RunChanged()

                    StopDragSelect()
                end)
            end)))

            return Row
        end

        function Dropdown:BuildDropdownList()
            StopDragSelect()

            RecomputeFilteredEntries()

            Dropdown.Rebuilding = true

            local Searching = SearchBox and SearchBox.Text ~= ""
            local Saved = Dropdown.SavedScroll
            local Restore = not Searching and Saved and Saved.Count == #FilteredEntries

            MenuTable.Menu.CanvasPosition = Vector2.new(0, 0)

            Dropdown:RefreshPool()
            Dropdown:RecalculateListSize(#FilteredEntries)

            if Restore then
                MenuTable.Menu.CanvasPosition = Vector2.new(0, Saved.Y)
                Dropdown:RefreshPool()
            end

            Dropdown.Rebuilding = false
        end

        for _ = 1, PoolSize do
            table.insert(Pool, CreatePoolRow())
        end

        table.insert(Dropdown.Connections, MenuTable.Menu:GetPropertyChangedSignal("CanvasPosition"):Connect(ObsGuard(function()
            Dropdown:RefreshPool()
            if MenuTable.Active and not Dropdown.Rebuilding and not (SearchBox and SearchBox.Text ~= "") then
                Dropdown.SavedScroll = { Y = MenuTable.Menu.CanvasPosition.Y, Count = #FilteredEntries }
            end
        end)))

        local function ValueExists(Val)
            if IsSequentialArray(Dropdown.Values) then
                for _, Existing in Dropdown.Values do
                    if Existing == Val then
                        return true
                    end
                end

                return false
            end

            return Dropdown.Values[Val] ~= nil
        end

        function Dropdown:SetValue(Value)
            if Info.Multi then
                if typeof(Value) == "string" then
                    Value = if Value == "" then {} else { [Value] = true }
                end

                local Table = {}
				
                for Val, Active in Value or {} do
                    if typeof(Active) ~= "boolean" then
                        Table[Active] = true
                    elseif Active and ValueExists(Val) then
                        Table[Val] = true
                    end
                end

                Dropdown.Value = Table
            else
                if ValueExists(Value) then
                    Dropdown.Value = Value
                elseif not Value then
                    Dropdown.Value = nil
                end
            end

            Dropdown:Display()
            for _, Row in Pool do
                Row:UpdateButton()
            end

            if not Dropdown.Disabled then
                Library:UpdateDependencyBoxes(Dropdown)
            end

            Dropdown:RunChanged()
        end

        function Dropdown:SetValues(Values)
            Dropdown.Values = Values

            local Changed = false
            if Info.Multi then
                for Val in Dropdown.Value do
                    if not ValueExists(Val) then
                        Dropdown.Value[Val] = nil
                        Changed = true
                    end
                end

            elseif Dropdown.Value ~= nil and not ValueExists(Dropdown.Value) then
                Dropdown.Value = nil
                Changed = true
            end

            Dropdown:BuildDropdownList()
            Dropdown:Display()

            if Changed and not Dropdown.Disabled then
                Library:UpdateDependencyBoxes(Dropdown)
            end

            if Changed then
                Dropdown:RunChanged()
            end
        end

        function Dropdown:AddValues(Values)
            if typeof(Values) ~= "table" and typeof(Values) ~= "string" then
                return
            end

            local IsDictionary = not IsSequentialArray(Dropdown.Values)
            if IsDictionary then
                if typeof(Values) == "string" then
                    Dropdown.Values[Values] = Values

                elseif IsSequentialArray(Values) then
                    for _, Val in Values do
                        Dropdown.Values[Val] = Val
                    end

                else
                    for Key, Val in Values do
                        Dropdown.Values[Key] = Val
                    end
                end
            else
                if typeof(Values) == "table" then
                    for _, Val in Values do
                        table.insert(Dropdown.Values, Val)
                    end
                else
                    table.insert(Dropdown.Values, Values)
                end
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetDisabledValues(DisabledValues)
            Dropdown.DisabledValues = DisabledValues
            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddDisabledValues(DisabledValues)
            if typeof(DisabledValues) == "table" then
                for _, val in DisabledValues do
                    table.insert(Dropdown.DisabledValues, val)
                end
            elseif typeof(DisabledValues) == "string" then
                table.insert(Dropdown.DisabledValues, DisabledValues)
            else
                return
            end

            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetValueSuffixImages(ValueSuffixImages, AfterText)
            if typeof(ValueSuffixImages) ~= "table" then
                return
            end

            Dropdown.ValueSuffixImages = ValueSuffixImages
            if type(AfterText) == "string" then
                Dropdown.SuffixAfterText = AfterText
            end
            Dropdown:BuildDropdownList()
            Dropdown:Display()
        end

        function Dropdown:SetValueImages(ValueImages)
            if typeof(ValueImages) ~= "table" then
                return
            end
            
            Dropdown.ValueImages = ValueImages
            Dropdown:BuildDropdownList()
        end

        function Dropdown:AddValueImages(ValueImages)
            if typeof(ValueImages) ~= "table" then
                return
            end
            
            for key, val in ValueImages do
                Dropdown.ValueImages[key] = val
            end
            
            Dropdown:BuildDropdownList()
        end

        function Dropdown:SetDisabled(Disabled: boolean)
            Dropdown.Disabled = Disabled

            if Dropdown.TooltipTable then
                Dropdown.TooltipTable.Disabled = Dropdown.Disabled
            end

            MenuTable:Close()
            DisplayButton.Active = not Dropdown.Disabled
            Dropdown:UpdateColors()

            Library:UpdateDependencyBoxes(Dropdown)
        end

        function Dropdown:SetVisible(Visible: boolean)
            Dropdown.Visible = Visible

            Holder.Visible = Dropdown.Visible
            Groupbox:Resize()
        end

        function Dropdown:SetText(Text: string)
            Dropdown.Text = Text
            Holder.Size = UDim2.new(1, 0, 0, Text and 39 or 21)

            Label.Text = Text and Text or ""
            Label.Visible = not not Text
        end

        function Dropdown:SetDragSelect(Value: boolean)
            if not Info.Multi or Library.IsMobile then 
                Value = false
            end

            Dropdown.DragSelect = Value == true
            Dropdown:BuildDropdownList()
        end

        local ToggleDropdown = function()
            if Dropdown.Disabled then
                return
            end

            MenuTable:Toggle()
        end

        table.insert(Dropdown.Connections, DisplayContainer.MouseButton1Click:Connect(ObsGuard(ToggleDropdown)))
        table.insert(Dropdown.Connections, DisplayButton.MouseButton1Click:Connect(ObsGuard(ToggleDropdown)))

        if SearchBox then
            table.insert(Dropdown.Connections, SearchBox:GetPropertyChangedSignal("Text"):Connect(ObsGuard(Dropdown.BuildDropdownList)))
        end

        local Defaults = (function()
            local Resolved = {}
            local Default = Info.Default
            if Default == nil then
                return Resolved
            end

            local IsDictionary = not IsSequentialArray(Dropdown.Values)
            local function ResolveOne(Candidate)
                if IsDictionary then
                    return Dropdown.Values[Candidate] ~= nil and Candidate or nil
                end

                for _, Existing in Dropdown.Values do
                    if Existing == Candidate then
                        return Existing
                    end
                end

                return nil
            end

            local DefaultType = typeof(Default)
            if DefaultType == "string" then
                local Value = ResolveOne(Default)
                if Value ~= nil then
                    table.insert(Resolved, Value)
                end

            elseif DefaultType == "table" then
                for _, Candidate in Default do
                    local Value = ResolveOne(Candidate)
                    if Value ~= nil then
                        table.insert(Resolved, Value)
                    end
                end

            elseif Dropdown.Values[Default] ~= nil then
                table.insert(Resolved, IsDictionary and Default or Dropdown.Values[Default])
            end

            return Resolved
        end)()

        for _, SelectValue in Defaults do
            if Info.Multi then
                Dropdown.Value[SelectValue] = true
            else
                Dropdown.Value = SelectValue
                break
            end
        end

        if typeof(Dropdown.Tooltip) == "string" or typeof(Dropdown.DisabledTooltip) == "string" then
            Dropdown.TooltipTable = Library:AddTooltip(Dropdown.Tooltip, Dropdown.DisabledTooltip, DisplayContainer)
            Dropdown.TooltipTable.Disabled = Dropdown.Disabled
        end

        Dropdown:UpdateColors()
        Dropdown:Display()
        Dropdown:BuildDropdownList()
        Groupbox:Resize()

        Dropdown.Holder = Holder
        table.insert(Groupbox.Elements, Dropdown)

        Dropdown.Default = Defaults
        Dropdown.DefaultValues = Dropdown.Values

        Options[Idx] = Dropdown

        function Dropdown:Destroy()
            Dropdown.Destroyed = true

            StopDragSelect()

            if Dropdown.Connections then
                for _, Connection in Dropdown.Connections do
                    Connection:Disconnect()
                end
            end

            if Dropdown.TooltipTable then 
                Dropdown.TooltipTable:Destroy() 
            end

            if MenuTable then 
                MenuTable:Destroy() 
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Dropdown)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Dropdown
    end

    function Funcs:AddViewport(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Viewport)

        local Groupbox = self
        local Container = Groupbox.Container

        local Dragging, Pinching = false, false
        local LastMousePos, LastPinchDist = nil, 0

        local ViewportObject = Info.Object
        if Info.Clone and typeof(Info.Object) == "Instance" then
            if Info.Object.Archivable then
                ViewportObject = ViewportObject:Clone()
            else
                Info.Object.Archivable = true
                ViewportObject = ViewportObject:Clone()
                Info.Object.Archivable = false
            end
        end

        local Viewport = {
            Connections = {},
            Destroyed = false,

            Object = ViewportObject :: PVInstance,
            Camera = if not Info.Camera then Instance.new("Camera") else Info.Camera,
            Interactive = Info.Interactive,
            AutoFocus = Info.AutoFocus,
            Visible = Info.Visible,
            Type = "Viewport",
        }

        assert(
            typeof(Viewport.Object) == "Instance" and (Viewport.Object:IsA("BasePart") or Viewport.Object:IsA("Model")),
            "Instance must be a BasePart or Model."
        )

        assert(
            typeof(Viewport.Camera) == "Instance" and Viewport.Camera:IsA("Camera"),
            "Camera must be a valid Camera instance."
        )

        local function GetModelSize(model)
            if model:IsA("BasePart") then
                return model.Size
            end

            return select(2, model:GetBoundingBox())
        end

        local function FocusCamera()
            local ModelSize = GetModelSize(Viewport.Object)
            local MaxExtent = math.max(ModelSize.X, ModelSize.Y, ModelSize.Z)
            local CameraDistance = MaxExtent * 2
            local ModelPosition = (Viewport.Object :: PVInstance):GetPivot().Position

            Viewport.Camera.CFrame = CFrame.new(ModelPosition + Vector3.new(0, MaxExtent / 2, CameraDistance), ModelPosition)
        end

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Info.Height),
            Visible = Viewport.Visible,
            Parent = Container,
        })

        local Box = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            BorderColor3 = "OutlineColor",
            BorderSizePixel = 1,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.fromScale(1, 1),
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        local ViewportFrame = New("ViewportFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Parent = Box,
            CurrentCamera = Viewport.Camera,
            Active = Viewport.Interactive,
        })

        table.insert(Viewport.Connections, ViewportFrame.MouseEnter:Connect(ObsGuard(function()
            if not Viewport.Interactive then
                return
            end

            for _, Side in Groupbox.Tab.Sides do
                Side.ScrollingEnabled = false
            end
        end)))

        table.insert(Viewport.Connections, ViewportFrame.MouseLeave:Connect(ObsGuard(function()
            if not Viewport.Interactive then
                return
            end

            for _, Side in Groupbox.Tab.Sides do
                Side.ScrollingEnabled = Library.SmoothScrollers[Side] == nil
            end
        end)))

        table.insert(Viewport.Connections, ViewportFrame.InputBegan:Connect(ObsGuard(function(input)
            if not Viewport.Interactive then
                return
            end

            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                Dragging = true
                LastMousePos = input.Position
            elseif input.UserInputType == Enum.UserInputType.Touch and not Pinching then
                Dragging = true
                LastMousePos = input.Position
            end
        end)))

        table.insert(Viewport.Connections, UserInputService.InputEnded:Connect(ObsGuard(function(input)
            if Library.Unloaded then
                return
            end

            if not Viewport.Interactive then
                return
            end

            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                Dragging = false
            elseif input.UserInputType == Enum.UserInputType.Touch then
                Dragging = false
            end
        end)))

        table.insert(Viewport.Connections, UserInputService.InputChanged:Connect(ObsGuard(function(input)
            if Library.Unloaded then
                return
            end

            if not Viewport.Interactive or not Dragging or Pinching then
                return
            end

            if
                input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
            then
                local MouseDelta = input.Position - LastMousePos
                LastMousePos = input.Position

                local Position = (Viewport.Object :: PVInstance):GetPivot().Position
                local Camera = Viewport.Camera

                local RotationY = CFrame.fromAxisAngle(Vector3.new(0, 1, 0), -MouseDelta.X * 0.01)
                Camera.CFrame = CFrame.new(Position) * RotationY * CFrame.new(-Position) * Camera.CFrame

                local RotationX = CFrame.fromAxisAngle(Camera.CFrame.RightVector, -MouseDelta.Y * 0.01)
                local PitchedCFrame = CFrame.new(Position) * RotationX * CFrame.new(-Position) * Camera.CFrame

                if PitchedCFrame.UpVector.Y > 0.1 then
                    Camera.CFrame = PitchedCFrame
                end
            end
        end)))

        table.insert(Viewport.Connections, ViewportFrame.InputChanged:Connect(ObsGuard(function(input)
            if not Viewport.Interactive then
                return
            end

            if input.UserInputType == Enum.UserInputType.MouseWheel then
                local ZoomAmount = input.Position.Z * 2
                Viewport.Camera.CFrame += Viewport.Camera.CFrame.LookVector * ZoomAmount
            end
        end)))

        table.insert(Viewport.Connections, UserInputService.TouchPinch:Connect(ObsGuard(function(touchPositions, scale, velocity, state)
            if Library.Unloaded then
                return
            end

            if not Viewport.Interactive or not Library:MouseIsOverFrame(ViewportFrame, touchPositions[1]) then
                return
            end

            if state == Enum.UserInputState.Begin then
                Pinching = true
                Dragging = false
                LastPinchDist = (touchPositions[1] - touchPositions[2]).Magnitude
            elseif state == Enum.UserInputState.Change then
                local currentDist = (touchPositions[1] - touchPositions[2]).Magnitude
                local delta = (currentDist - LastPinchDist) * 0.1
                LastPinchDist = currentDist
                Viewport.Camera.CFrame += Viewport.Camera.CFrame.LookVector * delta
            elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
                Pinching = false
            end
        end)))

        ;(Viewport.Object :: PVInstance).Parent = ViewportFrame
        if Viewport.AutoFocus then
            FocusCamera()
        end

        function Viewport:SetObject(Object: Instance, Clone: boolean?)
            assert(Object, "Object cannot be nil.")

            if Clone then
                Object = Object:Clone()
            end

            if Viewport.Object then
                Viewport.Object:Destroy()
            end

            Viewport.Object = Object
            ;(Viewport.Object :: PVInstance).Parent = ViewportFrame

            Groupbox:Resize()
        end

        function Viewport:SetHeight(Height: number)
            assert(Height > 0, "Height must be greater than 0.")

            Holder.Size = UDim2.new(1, 0, 0, Height)
            Groupbox:Resize()
        end

        function Viewport:Focus()
            if not Viewport.Object then
                return
            end

            FocusCamera()
        end

        function Viewport:SetCamera(Camera: Instance)
            assert(
                Camera and typeof(Camera) == "Instance" and Camera:IsA("Camera"),
                "Camera must be a valid Camera instance."
            )

            Viewport.Camera = Camera
            ViewportFrame.CurrentCamera = Camera
        end

        function Viewport:SetInteractive(Interactive: boolean)
            Viewport.Interactive = Interactive
            ViewportFrame.Active = Interactive
        end

        function Viewport:SetVisible(Visible: boolean)
            Viewport.Visible = Visible

            Holder.Visible = Viewport.Visible
            Groupbox:Resize()
        end

        Groupbox:Resize()

        Viewport.Holder = Holder
        table.insert(Groupbox.Elements, Viewport)

        Options[Idx] = Viewport

        function Viewport:Destroy()
            Viewport.Destroyed = true

            if Viewport.Connections then
                for _, Connection in Viewport.Connections do
                    Connection:Disconnect()
                end
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Viewport)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Viewport
    end

    function Funcs:AddImage(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Image)

        local Groupbox = self
        local Container = Groupbox.Container

        local Image = {
            Connections = {},
            Destroyed = false,

            Image = Info.Image,
            Color = Info.Color,
            RectOffset = Info.RectOffset,
            RectSize = Info.RectSize,
            Height = Info.Height,
            ScaleType = Info.ScaleType,
            Transparency = Info.Transparency,
            BackgroundTransparency = Info.BackgroundTransparency,

            Visible = Info.Visible,
            Type = "Image",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Info.Height),
            Visible = Image.Visible,
            Parent = Container,
        })

        local Box = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            BorderColor3 = "OutlineColor",
            BorderSizePixel = 1,
            BackgroundTransparency = Image.BackgroundTransparency,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.fromScale(1, 1),
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        local ImageProperties = {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = Image.Image,
            ImageTransparency = Image.Transparency,
            ImageColor3 = Image.Color,
            ImageRectOffset = Image.RectOffset,
            ImageRectSize = Image.RectSize,
            ScaleType = Image.ScaleType,
            Parent = Box,
        }

        local Icon = Library:GetCustomIcon(ImageProperties.Image)
        assert(Icon, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

        ImageProperties.Image = Icon.Url
        ImageProperties.ImageRectOffset = Icon.ImageRectOffset or Vector2.zero
        ImageProperties.ImageRectSize = Icon.ImageRectSize or Vector2.zero

        local ImageLabel = New("ImageLabel", ImageProperties)

        function Image:SetHeight(Height: number)
            assert(Height > 0, "Height must be greater than 0.")

            Image.Height = Height
            Holder.Size = UDim2.new(1, 0, 0, Height)
            Groupbox:Resize()
        end

        function Image:SetImage(NewImage: string)
            assert(typeof(NewImage) == "string", "Image must be a string.")

            local Icon = Library:GetCustomIcon(NewImage)
            assert(Icon, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

            NewImage = Icon.Url
            Image.RectOffset = Icon.ImageRectOffset
            Image.RectSize = Icon.ImageRectSize

            ImageLabel.Image = NewImage
            Image.Image = NewImage
        end

        function Image:SetColor(Color: Color3)
            assert(typeof(Color) == "Color3", "Color must be a Color3 value.")

            ImageLabel.ImageColor3 = Color
            Image.Color = Color
        end

        function Image:SetRectOffset(RectOffset: Vector2)
            assert(typeof(RectOffset) == "Vector2", "RectOffset must be a Vector2 value.")

            ImageLabel.ImageRectOffset = RectOffset
            Image.RectOffset = RectOffset
        end

        function Image:SetRectSize(RectSize: Vector2)
            assert(typeof(RectSize) == "Vector2", "RectSize must be a Vector2 value.")

            ImageLabel.ImageRectSize = RectSize
            Image.RectSize = RectSize
        end

        function Image:SetScaleType(ScaleType: Enum.ScaleType)
            assert(
                typeof(ScaleType) == "EnumItem" and ScaleType:IsA("ScaleType"),
                "ScaleType must be a valid Enum.ScaleType."
            )

            ImageLabel.ScaleType = ScaleType
            Image.ScaleType = ScaleType
        end

        function Image:SetTransparency(Transparency: number)
            assert(typeof(Transparency) == "number", "Transparency must be a number between 0 and 1.")
            assert(Transparency >= 0 and Transparency <= 1, "Transparency must be between 0 and 1.")

            ImageLabel.ImageTransparency = Transparency
            Image.Transparency = Transparency
        end

        function Image:SetVisible(Visible: boolean)
            Image.Visible = Visible

            Holder.Visible = Image.Visible
            Groupbox:Resize()
        end

        Groupbox:Resize()

        Image.Holder = Holder
        table.insert(Groupbox.Elements, Image)

        Options[Idx] = Image

        function Image:Destroy()
            Image.Destroyed = true

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Image)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Image
    end

    function Funcs:AddVideo(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.Video)

        local Groupbox = self
        local Container = Groupbox.Container

        local Video = {
            Connections = {},
            Destroyed = false,

            Video = Info.Video,
            Looped = Info.Looped,
            Playing = Info.Playing,
            Volume = Info.Volume,
            Height = Info.Height,
            Visible = Info.Visible,

            Type = "Video",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Info.Height),
            Visible = Video.Visible,
            Parent = Container,
        })

        local Box = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = "MainColor",
            BorderColor3 = "OutlineColor",
            BorderSizePixel = 1,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.fromScale(1, 1),
            Parent = Holder,
        })

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 3),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 4),
            Parent = Box,
        })

        local VideoFrameInstance = New("VideoFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Video = Video.Video,
            Looped = Video.Looped,
            Volume = Video.Volume,
            Parent = Box,
        })

        VideoFrameInstance.Playing = Video.Playing

        function Video:SetHeight(Height: number)
            assert(Height > 0, "Height must be greater than 0.")

            Video.Height = Height
            Holder.Size = UDim2.new(1, 0, 0, Height)
            Groupbox:Resize()
        end

        function Video:SetVideo(NewVideo: string)
            assert(typeof(NewVideo) == "string", "Video must be a string.")

            VideoFrameInstance.Video = NewVideo
            Video.Video = NewVideo
        end

        function Video:SetLooped(Looped: boolean)
            assert(typeof(Looped) == "boolean", "Looped must be a boolean.")

            VideoFrameInstance.Looped = Looped
            Video.Looped = Looped
        end

        function Video:SetVolume(Volume: number)
            assert(typeof(Volume) == "number", "Volume must be a number between 0 and 10.")

            VideoFrameInstance.Volume = Volume
            Video.Volume = Volume
        end

        function Video:SetPlaying(Playing: boolean)
            assert(typeof(Playing) == "boolean", "Playing must be a boolean.")

            VideoFrameInstance.Playing = Playing
            Video.Playing = Playing
        end

        function Video:Play()
            VideoFrameInstance.Playing = true
            Video.Playing = true
        end

        function Video:Pause()
            VideoFrameInstance.Playing = false
            Video.Playing = false
        end

        function Video:SetVisible(Visible: boolean)
            Video.Visible = Visible

            Holder.Visible = Video.Visible
            Groupbox:Resize()
        end

        Groupbox:Resize()

        Video.Holder = Holder
        Video.VideoFrame = VideoFrameInstance
        table.insert(Groupbox.Elements, Video)

        Options[Idx] = Video

        function Video:Destroy()
            Video.Destroyed = true

            if Video.Connections then
                for _, Connection in Video.Connections do
                    Connection:Disconnect()
                end
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Video)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Video
    end

    function Funcs:AddUIPassthrough(Idx, Info)
        if self.Destroyed then return nil end

        Info = Library:Validate(Info, Templates.UIPassthrough)

        local Groupbox = self
        local Container = Groupbox.Container

        assert(Info.Instance, "Instance must be provided.")
        assert(
            typeof(Info.Instance) == "Instance" and Info.Instance:IsA("GuiBase2d"),
            "Instance must inherit from GuiBase2d."
        )
        assert(typeof(Info.Height) == "number" and Info.Height > 0, "Height must be a number greater than 0.")

        local Passthrough = {
            Connections = {},
            Destroyed = false,

            Instance = Info.Instance,
            Height = Info.Height,
            Visible = Info.Visible,

            Type = "UIPassthrough",
        }

        local Holder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, Info.Height),
            Visible = Passthrough.Visible,
            Parent = Container,
        })

        Passthrough.Instance.Parent = Holder

        Groupbox:Resize()

        function Passthrough:SetHeight(Height: number)
            assert(typeof(Height) == "number" and Height > 0, "Height must be a number greater than 0.")

            Passthrough.Height = Height
            Holder.Size = UDim2.new(1, 0, 0, Height)
            Groupbox:Resize()
        end

        function Passthrough:SetInstance(Instance: Instance)
            assert(Instance, "Instance must be provided.")
            assert(
                typeof(Instance) == "Instance" and Instance:IsA("GuiBase2d"),
                "Instance must inherit from GuiBase2d."
            )

            if Passthrough.Instance then
                Passthrough.Instance.Parent = nil
            end

            Passthrough.Instance = Instance
            Passthrough.Instance.Parent = Holder
        end

        function Passthrough:SetVisible(Visible: boolean)
            Passthrough.Visible = Visible

            Holder.Visible = Passthrough.Visible
            Groupbox:Resize()
        end

        Passthrough.Holder = Holder
        table.insert(Groupbox.Elements, Passthrough)

        Options[Idx] = Passthrough

        function Passthrough:Destroy()
            Passthrough.Destroyed = true

            if Passthrough.Connections then
                for _, Connection in Passthrough.Connections do
                    Connection:Disconnect()
                end
            end

            if Holder then 
                Holder:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.Elements, Passthrough)
            if ElemIdx then 
                table.remove(Groupbox.Elements, ElemIdx) 
            end

            Groupbox:Resize()
            Options[Idx] = nil
        end

        return Passthrough
    end

    function Funcs:AddDependencyBox()
        if self.Destroyed then return nil end

        local Groupbox = self
        local Container = Groupbox.Container

        local DepboxContainer
        local DepboxList

        do
            DepboxContainer = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Visible = false,
                Parent = Container,
            })

            DepboxList = New("UIListLayout", {
                Padding = UDim.new(0, 8),
                Parent = DepboxContainer,
            })
        end

        local Depbox = {
            Connections = {},
            Destroyed = false,

            Visible = false,
            Dependencies = {},

            Holder = DepboxContainer,
            Container = DepboxContainer,

            Elements = {},
            DependencyBoxes = {}
        }

        function Depbox:Resize()
            DepboxContainer.Size = UDim2.new(1, 0, 0, DepboxList.AbsoluteContentSize.Y / Library.DPIScale)
            Groupbox:Resize()
        end

        function Depbox:Update(CancelSearch)
            for _, Dependency in Depbox.Dependencies do
                local Element = Dependency[1]
                local Value = Dependency[2]

                if Element.Disabled then
                    DepboxContainer.Visible = false
                    Depbox.Visible = false
                    return
                end

                if Element.Type == "Toggle" and Element.Value ~= Value then
                    DepboxContainer.Visible = false
                    Depbox.Visible = false
                    return
                elseif Element.Type == "Dropdown" then
                    if typeof(Element.Value) == "table" then
                        if not Element.Value[Value] then
                            DepboxContainer.Visible = false
                            Depbox.Visible = false
                            return
                        end
                    else
                        if Element.Value ~= Value then
                            DepboxContainer.Visible = false
                            Depbox.Visible = false
                            return
                        end
                    end
                end
            end

            Depbox.Visible = true
            DepboxContainer.Visible = true
            if not Library.Searching then
                task.defer(function()
                    Depbox:Resize()
                end)
            elseif not CancelSearch then
                Library:UpdateSearch(Library.SearchText)
            end
        end

        table.insert(Depbox.Connections, DepboxList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(ObsGuard(function()
            if not Depbox.Visible then
                return
            end

            Depbox:Resize()
        end)))

        function Depbox:SetupDependencies(Dependencies)
            for _, Dependency in Dependencies do
                assert(typeof(Dependency) == "table", "Dependency should be a table.")
                assert(Dependency[1] ~= nil, "Dependency is missing element.")
                assert(Dependency[2] ~= nil, "Dependency is missing expected value.")
            end

            Depbox.Dependencies = Dependencies
            Depbox:Update()
        end

        table.insert(Depbox.Connections, DepboxContainer:GetPropertyChangedSignal("Visible"):Connect(ObsGuard(function()
            Depbox:Resize()
        end)))

        setmetatable(Depbox, BaseGroupbox)

        table.insert(Groupbox.DependencyBoxes, Depbox)
        table.insert(Library.DependencyBoxes, Depbox)

        function Depbox:Destroy()
            Depbox.Destroyed = true

            if Depbox.Connections then
                for _, Connection in Depbox.Connections do
                    Connection:Disconnect()
                end
            end

            for _, Element in table.clone(Depbox.Elements) do
                if Element.Destroy then
                    Element:Destroy()
                end
            end

            for _, SubDepbox in table.clone(Depbox.DependencyBoxes) do
                if SubDepbox.Destroy then
                    SubDepbox:Destroy()
                end
            end

            if DepboxContainer then 
                DepboxContainer:Destroy() 
            end

            local ElemIdx = table.find(Groupbox.DependencyBoxes, Depbox)
            if ElemIdx then 
                table.remove(Groupbox.DependencyBoxes, ElemIdx)
            end

            local LibIdx = table.find(Library.DependencyBoxes, Depbox)
            if LibIdx then 
                table.remove(Library.DependencyBoxes, LibIdx) 
            end
        end

        return Depbox
    end

    function Funcs:AddDependencyGroupbox()
        if self.Destroyed then return nil end

        local Groupbox = self
        local Tab = Groupbox.Tab
        local BoxHolder = Groupbox.BoxHolder

        local DepGroupboxContainer
        local DepGroupboxList

        do
            DepGroupboxContainer = New("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = "BackgroundColor",
                Size = UDim2.fromScale(1, 0),
                Visible = false,
                Parent = BoxHolder,
            })
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius),
                    Parent = DepGroupboxContainer,
                })
            )
            Library:AddOutline(DepGroupboxContainer)

            DepGroupboxList = New("UIListLayout", {
                Padding = UDim.new(0, 8),
                Parent = DepGroupboxContainer,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 7),
                PaddingLeft = UDim.new(0, 7),
                PaddingRight = UDim.new(0, 7),
                PaddingTop = UDim.new(0, 7),
                Parent = DepGroupboxContainer,
            })
        end

        local DepGroupbox = {
            Connections = {},
            Destroyed = false,

            Visible = false,
            Dependencies = {},

            BoxHolder = BoxHolder,
            Holder = DepGroupboxContainer,
            Container = DepGroupboxContainer,

            Tab = Tab,
            Elements = {},
            DependencyBoxes = {},
        }

        function DepGroupbox:Resize()
            DepGroupboxContainer.Size = UDim2.new(1, 0, 0, (DepGroupboxList.AbsoluteContentSize.Y / Library.DPIScale) + 18)
        end

        function DepGroupbox:Update(CancelSearch)
            for _, Dependency in DepGroupbox.Dependencies do
                local Element = Dependency[1]
                local Value = Dependency[2]

                if Element.Disabled then
                    DepGroupboxContainer.Visible = false
                    DepGroupbox.Visible = false
                    return
                end

                if Element.Type == "Toggle" and Element.Value ~= Value then
                    DepGroupboxContainer.Visible = false
                    DepGroupbox.Visible = false
                    return
                elseif Element.Type == "Dropdown" then
                    if typeof(Element.Value) == "table" then
                        if not Element.Value[Value] then
                            DepGroupboxContainer.Visible = false
                            DepGroupbox.Visible = false
                            return
                        end
                    else
                        if Element.Value ~= Value then
                            DepGroupboxContainer.Visible = false
                            DepGroupbox.Visible = false
                            return
                        end
                    end
                end
            end

            DepGroupbox.Visible = true
            if not Library.Searching then
                DepGroupboxContainer.Visible = true
                DepGroupbox:Resize()
            elseif not CancelSearch then
                Library:UpdateSearch(Library.SearchText)
            end
        end

        function DepGroupbox:SetupDependencies(Dependencies)
            for _, Dependency in Dependencies do
                assert(typeof(Dependency) == "table", "Dependency should be a table.")
                assert(Dependency[1] ~= nil, "Dependency is missing element.")
                assert(Dependency[2] ~= nil, "Dependency is missing expected value.")
            end

            DepGroupbox.Dependencies = Dependencies
            DepGroupbox:Update()
        end

        setmetatable(DepGroupbox, BaseGroupbox)

        table.insert(Tab.DependencyGroupboxes, DepGroupbox)
        table.insert(Library.DependencyBoxes, DepGroupbox :: any)

        function DepGroupbox:Destroy()
            DepGroupbox.Destroyed = true

            if DepGroupbox.Connections then
                for _, Connection in DepGroupbox.Connections do
                    Connection:Disconnect()
                end
            end

            for _, Element in DepGroupbox.Elements do
                if Element.Destroy then
                    Element:Destroy()
                end
            end

            for _, SubDepbox in DepGroupbox.DependencyBoxes do
                if SubDepbox.Destroy then
                    SubDepbox:Destroy()
                end
            end

            if DepGroupboxContainer then 
                DepGroupboxContainer:Destroy() 
            end

            local ElemIdx = table.find(Tab.DependencyGroupboxes, DepGroupbox)
            if ElemIdx then 
                table.remove(Tab.DependencyGroupboxes, ElemIdx) 
            end

            local LibIdx = table.find(Library.DependencyBoxes, DepGroupbox)
            if LibIdx then 
                table.remove(Library.DependencyBoxes, LibIdx) 
            end
        end

        return DepGroupbox
    end

    BaseGroupbox.__index = Funcs
    BaseGroupbox.__namecall = function(_, Key, ...)
        return Funcs[Key](...)
    end
end


local Floats = New("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.fromOffset(0, 0),
    ZIndex = 10,
    Active = false,
    Parent = ScreenGui,
})
Library.Floats = Floats

local function IsScreenPointOutsideMain(Point: Vector2): boolean
    local MainFrame = Library.Window and Library.Window.MainFrame
    if not MainFrame or not Library.Toggled or not MainFrame.Visible then
        return true
    end

    return not Library:MouseIsOverFrame(MainFrame, Point)
end

local function GetTopFloatAt(Point: Vector2): GuiObject?
    local Best: GuiObject? = nil
    local BestOrder = -math.huge
    local Floats = Library.Floats

    for _, Surface in Library.DraggableElements do
        if not Surface or not Surface.Parent or not Surface.Visible then
            continue
        end
        if Floats and Surface.Parent ~= Floats then
            continue
        end
        if not Library:MouseIsOverFrame(Surface, Point) then
            continue
        end

        local SiblingIndex = tonumber(select(2, pcall(function() return Surface:GetSiblingIndex() end))) or 0
        local Order = Surface.ZIndex * 100000 + SiblingIndex
        if Order >= BestOrder then
            BestOrder = Order
            Best = Surface
        end
    end

    return Best
end

function Library:ApplyLucideIcon(Object: ImageLabel & ImageButton, Icon: any, Rotation: number?)
    if not (Object and Icon) then
        return
    end

    Object.Image = Icon.Url or ""
    Object.ImageRectOffset = Icon.ImageRectOffset or Vector2.zero
    Object.ImageRectSize = Icon.ImageRectSize or Vector2.zero

    if Rotation then
        Object.Rotation = Rotation
    end
end

function SyncPopOutVisibility(Box: any)
    if not Box.PopOutFloat then
        return
    end

    Box.PopOutFloat.Visible = Box.BoxHolder.Visible ~= false and Box.Visible ~= false
end

local function DimPopOutClone(Root: GuiObject)
    for _, Descendant in Root:QueryDescendants("TextLabel, TextButton, TextBox") do
        Descendant.TextTransparency = math.max(Descendant.TextTransparency, 0.45)
    end

    for _, Descendant in Root:QueryDescendants("ImageLabel, ImageButton") do
        Descendant.ImageTransparency = math.max(Descendant.ImageTransparency, 0.45)
    end

    for _, Descendant in Root:QueryDescendants("GuiButton") do
        Descendant.Active = false
        Descendant.AutoButtonColor = false
    end
end

local function GetPopOutBodyMaxHeight(Box: any, Reserved: number): number
    local Float = Box.PopOutFloat
    local ScreenGui = Library.ScreenGui
    if not Float or not ScreenGui then
        return math.huge
    end

    local Gap = 12 * Library.DPIScale
    local MaxBottom = ScreenGui.AbsolutePosition.Y + ScreenGui.AbsoluteSize.Y - Gap
    local Available = math.min(MaxBottom - Float.AbsolutePosition.Y, ScreenGui.AbsoluteSize.Y * 0.9)

    return math.max(0, Available / Library.DPIScale - Reserved)
end

function Library:MakeBoxPopOut(Box: any, Options: {
    Enabled: boolean?,
    Header: GuiObject?,
    Children: (() -> { GuiObject })?,
    Before: (() -> ())?,
    After: (() -> ())?,
})
    Box.PoppedOut = false
    Box.PopOutEnabled = Options.Enabled ~= false
    Box.PopOutFloat = nil
    Box.PopOutPlaceholder = nil

    if not Box.PopOutEnabled then
        function Box:SetPoppedOut(_Value: boolean, _SetPoppedOut: UDim2) end
        function Box:TogglePoppedOut() end
        function Box:RefreshPopOutPlaceholder() end
        return
    end

    local BoxHolder = Box.BoxHolder
    local Holder = Box.Holder
    local Header = Options.Header

    local Placeholder
    local PlaceholderHeader
    local Float
    local FloatScale

    local HandledChildren: { GuiObject } = {}
    local OriginalParents: { [GuiObject]: Instance? } = {}
    local OriginalLayoutOrders: { [GuiObject]: number } = {}

    local DragState: "Idle" | "Holding" | "Dragging" = "Idle"
    local FloatDragTween
    local DragInput: InputObject?
    local PressMouse: Vector2?

    local DragStartPos: UDim2?
    local DragChanged: RBXScriptConnection?
    local DragDidMove = false

    --// UI Handler
    local function RaiseFloat()
        if not Float or not Floats then
            return
        end

        local MaxZ = Float.ZIndex
        for _, Child in Floats:GetChildren() do
            if Child:IsA("GuiObject") and Child ~= Float then
                MaxZ = math.max(MaxZ, Child.ZIndex)
            end
        end

        Float.ZIndex = MaxZ + 1
        if Float.Parent == Floats then
            Float.Parent = Overlay
        end
        Float.Parent = Floats
    end

    local function CreatePlaceholder()
        local Frame = New("Frame", {
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = "BackgroundColor",
            BackgroundTransparency = 0.12,
            ClipsDescendants = true,
            Size = UDim2.new(1, 0, 0, 0),
            Parent = BoxHolder,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, Library.CornerRadius),
                Parent = Frame,
            })
        )
        Library:AddOutline(Frame)

        PlaceholderHeader = Header:Clone()
        PlaceholderHeader.Parent = Frame
        DimPopOutClone(PlaceholderHeader)

        if PopOutIcon then
            local PlaceholderDockIcon = New("ImageButton", {
                AutoButtonColor = false,
                AnchorPoint = Vector2.new(1, 0.5),
                BackgroundTransparency = 1,
                ImageColor3 = "WhiteColor",
                Position = UDim2.new(1, -8, 0.5, 0),
                Size = UDim2.fromOffset(22, 22),
                ZIndex = PlaceholderHeader.ZIndex + 1,
                Parent = Frame,
            })
            Library:ApplyLucideIcon(PlaceholderDockIcon, PopOutIcon)
            PlaceholderDockIcon.MouseButton1Click:Connect(ObsGuard(function()
                Box:SetPoppedOut(false)
            end))
        end

        return Frame
    end

    function Box:RefreshPopOutPlaceholder()
        if not Box.PoppedOut or not Placeholder or not Header then
            return
        end

        if PlaceholderHeader then
            PlaceholderHeader:Destroy()
            PlaceholderHeader = nil
        end

        PlaceholderHeader = Header:Clone()
        PlaceholderHeader.Parent = Placeholder
        DimPopOutClone(PlaceholderHeader)
    end

    function Box:SetPoppedOut(Value: boolean, FloatPosition: UDim2?)
        if not Box.PopOutEnabled or Box.Destroyed then
            return
        end

        Value = Value == true
        if Box.PoppedOut == Value then
            if Value and FloatPosition and Float then
                Float.Position = FloatPosition
            end
            return
        end

        if Value then
            if Options.Before then
                Options.Before()
            end

            local BoxChildren = if Options.Children then Options.Children() else { Holder }
            HandledChildren = {}

            table.clear(OriginalParents)
            table.clear(OriginalLayoutOrders)

            for _, Child in BoxChildren do
                if not Child or not Child.Parent then
                    continue
                end

                table.insert(HandledChildren, Child)
                OriginalParents[Child] = Child.Parent
                OriginalLayoutOrders[Child] = Child.LayoutOrder
            end

            if #HandledChildren == 0 then
                return
            end

            local Width = Holder.AbsoluteSize.X / Library.DPIScale
            if Width < 50 then
                Width = 200
            end

            local AbsolutePosition = Holder.AbsolutePosition
            Placeholder = CreatePlaceholder()
            Box.PopOutPlaceholder = Placeholder

            Float = New("Frame", {
                Active = true,
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Position = FloatPosition or UDim2.fromOffset(
                    AbsolutePosition.X / Library.DPIScale,
                    AbsolutePosition.Y / Library.DPIScale
                ),
                Size = UDim2.fromOffset(Width, 0),
                ZIndex = 1,
                Parent = Floats,
            })
            FloatScale = New("UIScale", {
                Parent = Float,
            })
            table.insert(Library.Scales, FloatScale)
            FloatScale.Scale = Library.DPIScale - (tonumber(Library.ScalesOffset[FloatScale]) or 0)

            New("UIListLayout", {
                Padding = UDim.new(0, 6),
                Parent = Float,
            })

            for _, Child in HandledChildren do
                Child.Parent = Float
            end

            if not table.find(Library.DraggableElements, Float) then
                table.insert(Library.DraggableElements, Float)
            end

            Box.PopOutFloat = Float
            Box.PoppedOut = true
            SyncPopOutVisibility(Box)
            RaiseFloat()

            Float:GetPropertyChangedSignal("AbsolutePosition"):Connect(ObsGuard(function()
                Box:Resize()
            end))

            if Options.After then
                Options.After()
            end

            return
        end

        if Float then
            local DraggableIndex = table.find(Library.DraggableElements, Float)
            if DraggableIndex then
                table.remove(Library.DraggableElements, DraggableIndex)
            end
        end

        if FloatScale then
            local ScaleIndex = table.find(Library.Scales, FloatScale)
            if ScaleIndex then
                table.remove(Library.Scales, ScaleIndex)
            end

            FloatScale = nil
        end

        for _, Child in HandledChildren do
            if not Child or not Child.Parent then
                continue
            end

            Child.Parent = OriginalParents[Child] or BoxHolder
            Child.LayoutOrder = OriginalLayoutOrders[Child] or 0
        end

        if Placeholder then
            Placeholder:Destroy()
            Placeholder = nil
        end
        
        PlaceholderHeader = nil

        if Float then
            Float:Destroy()
            Float = nil
        end

        Box.PopOutFloat = nil
        Box.PopOutPlaceholder = nil
        Box.PoppedOut = false
        table.clear(HandledChildren)
        table.clear(OriginalParents)
        table.clear(OriginalLayoutOrders)

        if Options.After then
            Options.After()
        end
    end

    function Box:TogglePoppedOut()
        Box:SetPoppedOut(not Box.PoppedOut)
    end

    --// Drag Handler
    local MoveConn, ConnectMove = nil, nil
    local function StopDrag()
        if DragState == "Idle" then
            return
        end

        local WasDragging = DragState == "Dragging"
        local DidMove = DragDidMove
        DragState = "Idle"
        DragInput = nil
        PressMouse = nil
        DragStartPos = nil
        DragDidMove = false

        if FloatDragTween then
            FloatDragTween:Cancel()
            FloatDragTween = nil
        end

        if DragChanged and DragChanged.Connected then
            DragChanged:Disconnect()
            DragChanged = nil
        end

        if MoveConn and MoveConn.Connected then
            MoveConn:Disconnect()
        end
        MoveConn = nil

        if not WasDragging or not Box.PoppedOut or not Float then
            return
        end

        local FloatCenter = Float.AbsolutePosition + (Float.AbsoluteSize * 0.5)
        local NearPlaceholder = false
        if Library.Toggled and Placeholder and Placeholder.Parent then
            local PlaceholderCenter = Placeholder.AbsolutePosition + (Placeholder.AbsoluteSize * 0.5)
            NearPlaceholder = (FloatCenter - PlaceholderCenter).Magnitude <= Library.PopOutSnapDistance
        end

        if NearPlaceholder or (DidMove and not IsScreenPointOutsideMain(FloatCenter)) then
            Box:SetPoppedOut(false)
        end
    end

    local function BeginDrag(Input: InputObject)
        if DragState ~= "Idle" or Box.Destroyed or not (ScreenGui and ScreenGui.Parent) then
            return
        end

        local Point = Vector2.new(Input.Position.X, Input.Position.Y)
        local Top = GetTopFloatAt(Point)
        if Box.PoppedOut then
            if not Float or Top ~= Float then
                return
            end
        elseif Top ~= nil and not Header:IsDescendantOf(Top) then
            return
        end

        DragState = "Holding"
        DragInput = Input
        PressMouse = Vector2.new(Input.Position.X, Input.Position.Y)
        DragStartPos = nil
        DragDidMove = false
        if ConnectMove then ConnectMove() end

        if Box.PoppedOut and Float then
            RaiseFloat()
        end

        DragChanged = Input.Changed:Connect(ObsGuard(function()
            if Input.UserInputState == Enum.UserInputState.End then
                StopDrag()
            end
        end))

        task.delay(Library.PopOutHoldTime, function()
            if (DragState :: any) ~= "Holding" or DragInput ~= Input then
                return
            end

            DragState = "Dragging"
            if Box.PoppedOut and Float then
                RaiseFloat()
                DragStartPos = Float.Position
            end
        end)
    end

    local function UpdateDrag(Input: InputObject)
        if DragState ~= "Dragging" or not PressMouse then
            return
        end
        if not (ScreenGui and ScreenGui.Parent) then
            StopDrag()
            return
        end

        local MousePosition = Vector2.new(Input.Position.X, Input.Position.Y)
        local Delta = MousePosition - PressMouse

        if not Box.PoppedOut then
            if Delta.Magnitude < Library.PopOutDragThreshold then
                return
            end

            Box:SetPoppedOut(true)
            if not Float then
                return
            end

            RaiseFloat()
            DragStartPos = Float.Position
            DragDidMove = true
        elseif Delta.Magnitude >= Library.PopOutDragThreshold then
            DragDidMove = true
        end

        if Float and DragStartPos then
            local NewPos = UDim2.new(
                DragStartPos.X.Scale,
                DragStartPos.X.Offset + Delta.X,
                DragStartPos.Y.Scale,
                DragStartPos.Y.Offset + Delta.Y
            )

            if FloatDragTween then
                FloatDragTween:Cancel()
            end

            FloatDragTween = TweenService:Create(Float, TweenInfo.new(0.05, Enum.EasingStyle.Linear), { Position = NewPos })
            FloatDragTween:Play()
        end
    end

    local function BindDragSource(Gui: GuiObject)
        Library:GiveSignal(Gui.InputBegan:Connect(ObsGuard(function(Input: InputObject)
            if IsClickInput(Input) then
                BeginDrag(Input)
            end
        end)))
    end

    BindDragSource(Header)
    for _, Descendant in Header:QueryDescendants("GuiObject:not(ImageButton)") do
        BindDragSource(Descendant)
    end

    Library:GiveSignal(Header.DescendantAdded:Connect(ObsGuard(function(Descendant)
        if Descendant:IsA("GuiObject") and not Descendant:IsA("ImageButton") then
            BindDragSource(Descendant)
        end
    end)))

    ConnectMove = function()
        if MoveConn and MoveConn.Connected then MoveConn:Disconnect() end
        MoveConn = UserInputService.InputChanged:Connect(ObsGuard(function(Input: InputObject)
            if IsHoverInput(Input) then
                UpdateDrag(Input)
            end
        end))
    end
end
function Library:SetFont(FontFace)
    if typeof(FontFace) == "EnumItem" then
        FontFace = Font.fromEnum(FontFace :: any)
    end

    Library.Scheme.Font = FontFace
    Library:UpdateColorsUsingRegistry()
end

function Library:SetBackgroundImage(Image: string | number)
    assert(typeof(Image) == "string" or typeof(Image) == "number", "Expected string/number got " .. typeof(Image))
    
    Library.Scheme.BackgroundImage = Image
    if Library.Window then
        Library.Window:SetBackgroundImage(Image)
    end

    Library:UpdateColorsUsingRegistry()
end

do
    local SpringJobs = {}
    local SpringConnection = nil
    local SPRING_STEP = 1 / 240

    local function SpringPack(Value)
        local Kind = typeof(Value)
        if Kind == "number" then
            return { Value }, Kind, { 0.001 }
        elseif Kind == "UDim2" then
            return { Value.X.Scale, Value.X.Offset, Value.Y.Scale, Value.Y.Offset }, Kind, { 0.0005, 0.25, 0.0005, 0.25 }
        elseif Kind == "Vector2" then
            return { Value.X, Value.Y }, Kind, { 0.25, 0.25 }
        elseif Kind == "UDim" then
            return { Value.Scale, Value.Offset }, Kind, { 0.0005, 0.25 }
        end
        return nil, Kind, nil
    end

    local function SpringUnpack(Values, Kind)
        if Kind == "number" then
            return Values[1]
        elseif Kind == "UDim2" then
            return UDim2.new(Values[1], Values[2], Values[3], Values[4])
        elseif Kind == "Vector2" then
            return Vector2.new(Values[1], Values[2])
        elseif Kind == "UDim" then
            return UDim.new(Values[1], Values[2])
        end
    end

    local function SpringAssign(Object, Property, Value)
        Object[Property] = Value
    end

    local function SpringUpdate(Delta)
        Delta = math.min(Delta, 0.1)

        for Object, Properties in pairs(SpringJobs) do
            if not Object.Parent then
                SpringJobs[Object] = nil
                continue
            end

            for Property, Job in pairs(Properties) do
                Job.Carry += Delta

                while Job.Carry >= SPRING_STEP do
                    Job.Carry -= SPRING_STEP
                    for Index = 1, #Job.Values do
                        local Force = -Job.Omega * Job.Omega * (Job.Values[Index] - Job.Goal[Index]) - 2 * Job.Zeta * Job.Omega * Job.Velocity[Index]
                        Job.Velocity[Index] += Force * SPRING_STEP
                        Job.Values[Index] += Job.Velocity[Index] * SPRING_STEP
                    end
                end

                local Settled = true
                for Index = 1, #Job.Values do
                    if math.abs(Job.Values[Index] - Job.Goal[Index]) > Job.Epsilon[Index]
                        or math.abs(Job.Velocity[Index]) > Job.Epsilon[Index] * 10
                    then
                        Settled = false
                        break
                    end
                end

                if Settled then
                    for Index = 1, #Job.Values do
                        Job.Values[Index] = Job.Goal[Index]
                    end
                end

                pcall(SpringAssign, Object, Property, SpringUnpack(Job.Values, Job.Kind))

                if Settled then
                    Properties[Property] = nil
                    if Job.OnDone then
                        task.spawn(Job.OnDone)
                    end
                end
            end

            if next(Properties) == nil then
                SpringJobs[Object] = nil
            end
        end

        if next(SpringJobs) == nil and SpringConnection then
            SpringConnection:Disconnect()
            SpringConnection = nil
        end
    end

    function Library:Spring(Object, Property, Goal, Omega, Zeta, OnDone)
        if typeof(Object) ~= "Instance" then
            return
        end

        local GoalValues, Kind, Epsilon = SpringPack(Goal)
        if not GoalValues then
            pcall(function()
                Object[Property] = Goal
            end)
            return
        end

        local Properties = SpringJobs[Object]
        if not Properties then
            Properties = {}
            SpringJobs[Object] = Properties
        end

        local Job = Properties[Property]
        if Job and Job.Kind == Kind then
            Job.Goal = GoalValues
            Job.Omega = Omega or Job.Omega
            Job.Zeta = Zeta or Job.Zeta
            Job.OnDone = OnDone
        else
            local Current = SpringPack(Object[Property])
            local Velocity = {}
            for Index = 1, #GoalValues do
                Velocity[Index] = 0
            end
            Properties[Property] = {
                Values = Current or table.clone(GoalValues),
                Goal = GoalValues,
                Velocity = Velocity,
                Epsilon = Epsilon,
                Kind = Kind,
                Omega = Omega or 26,
                Zeta = Zeta or 0.8,
                Carry = 0,
                OnDone = OnDone,
            }
        end

        if not SpringConnection then
            SpringConnection = RunService.Heartbeat:Connect(SpringUpdate)
        end
    end

    function Library:SpringStop(Object, Property)
        local Properties = SpringJobs[Object]
        if Properties then
            Properties[Property] = nil
            if next(Properties) == nil then
                SpringJobs[Object] = nil
            end
        end
    end

end

function Library:UpdateNotificationPositions(Snap: boolean?)
    local IsLeft = Library.NotifySide:lower() == "left"
    local XScale = IsLeft and 0 or 1
    local RunningY = 0

    for _, FakeBackground in NotifyOrder do
        local Data = Library.Notifications[FakeBackground]
        if not (Data and FakeBackground.Parent) then continue end

        local Target = UDim2.new(XScale, 0, 0, RunningY)
        if Snap or not Data.PositionInitialized then
            Library:SpringStop(FakeBackground, "Position")
            FakeBackground.Position = Target
            Data.PositionInitialized = true

        elseif FakeBackground.Position ~= Target then
            Library:Spring(FakeBackground, "Position", Target, 26, 0.85)
        end

        RunningY = RunningY + FakeBackground.AbsoluteSize.Y / Library.DPIScale + 8
    end
end

function Library:SetNotifySide(Side: string)
    Side = Side or "Right"
    Library.NotifySide = Side

    local IsLeft = Side:lower() == "left"
    if IsLeft then
        NotificationArea.AnchorPoint = Vector2.new(0, 0)
        NotificationArea.Position = UDim2.fromOffset(6, 6)
    else
        NotificationArea.AnchorPoint = Vector2.new(1, 0)
        NotificationArea.Position = UDim2.new(1, -6, 0, 6)
    end

    for FakeBackground in Library.Notifications do
        if not (FakeBackground and FakeBackground.Parent) then continue end
        FakeBackground.AnchorPoint = if IsLeft then Vector2.new(0, 0) else Vector2.new(1, 0)
    end

    if Library.UpdateNotificationPositions then
        Library:UpdateNotificationPositions(true)
    end
end

-- The brand mark is white art meant to be tinted, so it takes the accent
-- wherever it appears. Everything else keeps its own colours: the staff and
-- tester badges are real images and would be ruined by a multiply.
Library.BrandIcon = 139353964655616
Library.NotifyLogo = "rbxassetid://131199175256589"

local function IsBrandIcon(Icon)
    if not Icon or not Library.BrandIcon then return false end
    local id = tostring(Icon):match("(%d+)")
    return id ~= nil and id == tostring(Library.BrandIcon):match("(%d+)")
end

do
    local ShimmerItems = {}
    local ShimmerConnection = nil
    local ShimmerSamples = 7
    local ShimmerSigma = 0.13
    local ShimmerPeriod = 1.45
    local ShimmerGap = 0.035

    local function ShimmerWave(X, Center, Sigma)
        local Distance = (X - Center) / (Sigma or ShimmerSigma)
        return math.exp(-Distance * Distance)
    end

    local function ShimmerStep()
        local Clock = os.clock()
        local Scheme = Library.Scheme or {}
        local Dim = Scheme.FontColor or Color3.new(1, 1, 1)
        local Glow = Scheme.AccentColor or Color3.fromRGB(125, 85, 255)
        local Phase = (Clock % ShimmerPeriod) / ShimmerPeriod
        local Eased = Phase < 0.5 and 2 * Phase * Phase or 1 - ((-2 * Phase + 2) ^ 2) / 2
        local Alive = false

        for Root, Item in pairs(ShimmerItems) do
            if not Root.Parent then
                ShimmerItems[Root] = nil
                continue
            end
            if not Root.Visible then
                continue
            end
            Alive = true

            if Item.Kind then
                local Center = -0.4 + 1.8 * Eased
                if Item.Kind == "Text" then
                    local Base = Dim:Lerp(Scheme.BackgroundColor or Color3.new(0, 0, 0), 0.38)
                    local Peak = Glow:Lerp(Color3.new(1, 1, 1), 0.2)
                    local Colors = table.create(9)
                    for Sample = 0, 8 do
                        local T = Sample / 8
                        Colors[Sample + 1] = ColorSequenceKeypoint.new(T, Base:Lerp(Peak, ShimmerWave(T, Center, 0.2)))
                    end
                    Item.Gradient.Color = ColorSequence.new(Colors)
                else
                    local Alphas = table.create(9)
                    for Sample = 0, 8 do
                        local T = Sample / 8
                        Alphas[Sample + 1] = NumberSequenceKeypoint.new(T, 1 - 0.45 * ShimmerWave(T, Center, 0.16))
                    end
                    Item.Gradient.Transparency = NumberSequence.new(Alphas)
                end
                continue
            end

            local Widths, Total = {}, 0
            for Index, Segment in ipairs(Item.Segments) do
                local Width = Segment.Base * (1 + 0.12 * math.sin(Clock * Segment.Speed + Segment.Seed))
                Widths[Index] = Width
                Total += Width + (Index > 1 and ShimmerGap or 0)
            end

            local Center = -ShimmerSigma * 2 + (Total + ShimmerSigma * 4) * Eased
            local Cursor = 0

            for Index, Segment in ipairs(Item.Segments) do
                local Width = Widths[Index]
                Segment.Frame.Position = UDim2.new(Cursor, 0, 0.5, 0)
                Segment.Frame.Size = UDim2.new(Width, 0, 0, 8)

                local Colors, Alphas = table.create(ShimmerSamples), table.create(ShimmerSamples)
                for Sample = 0, ShimmerSamples - 1 do
                    local T = Sample / (ShimmerSamples - 1)
                    local Wave = ShimmerWave(Cursor + T * Width, Center)
                    Colors[Sample + 1] = ColorSequenceKeypoint.new(T, Dim:Lerp(Glow, Wave))
                    Alphas[Sample + 1] = NumberSequenceKeypoint.new(T, 0.87 - 0.7 * Wave)
                end
                Segment.Gradient.Color = ColorSequence.new(Colors)
                Segment.Gradient.Transparency = NumberSequence.new(Alphas)

                Cursor += Width + ShimmerGap
            end
        end

        if not Alive and ShimmerConnection then
            ShimmerConnection:Disconnect()
            ShimmerConnection = nil
        end
    end

    function Library:CreateShimmer(Parent, Width)
        local Root = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -22, 1, 0),
            Visible = false,
            ZIndex = 3,
            Parent = Parent,
        })

        local Span = math.clamp((Width or 0.55) + 0.12, 0.5, 0.78)
        local Count = math.random() < 0.45 and 3 or 2
        local Weights, WeightSum = {}, 0
        for Index = 1, Count do
            Weights[Index] = (Index == 1 and 1.7 or 0.95) + math.random() * 0.7
            WeightSum += Weights[Index]
        end

        local Segments = {}
        for Index = 1, Count do
            local Frame = New("Frame", {
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
                Size = UDim2.new(0, 0, 0, 7),
                ZIndex = 3,
                Parent = Root,
            })
            New("UICorner", {
                CornerRadius = UDim.new(1, 0),
                Parent = Frame,
            })
            Segments[Index] = {
                Frame = Frame,
                Gradient = New("UIGradient", { Parent = Frame }),
                Base = (Span - ShimmerGap * (Count - 1)) * Weights[Index] / WeightSum,
                Seed = math.random() * math.pi * 2,
                Speed = 0.9 + math.random() * 0.8,
            }
        end

        ShimmerItems[Root] = { Segments = Segments }
        Root:GetPropertyChangedSignal("Visible"):Connect(function()
            if Root.Visible and not ShimmerConnection then
                ShimmerConnection = RunService.Heartbeat:Connect(ShimmerStep)
            end
        end)
        if not ShimmerConnection then
            ShimmerConnection = RunService.Heartbeat:Connect(ShimmerStep)
        end

        return Root
    end

    local function StartShimmerLoop()
        if not ShimmerConnection then
            ShimmerConnection = RunService.Heartbeat:Connect(ShimmerStep)
        end
    end

    function Library:AddTextShimmer(Label)
        if typeof(Label) ~= "Instance" or not Label:IsA("GuiObject") then
            return
        end
        if Library.Registry[Label] then
            Library.Registry[Label].TextColor3 = nil
        end
        Label.TextColor3 = Color3.new(1, 1, 1)
        local Existing = Label:FindFirstChildOfClass("UIGradient")
        if Existing then
            Existing:Destroy()
        end
        ShimmerItems[Label] = { Kind = "Text", Gradient = New("UIGradient", { Parent = Label }) }
        StartShimmerLoop()
    end

    function Library:AddSheen(Target, Radius)
        if typeof(Target) ~= "Instance" or not Target:IsA("GuiObject") then
            return
        end
        local Sheen = New("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            Parent = Target,
        })
        New("UICorner", {
            CornerRadius = Radius or UDim.new(0, Library.CornerRadius / 2),
            Parent = Sheen,
        })
        ShimmerItems[Sheen] = {
            Kind = "Sheen",
            Gradient = New("UIGradient", {
                Transparency = NumberSequence.new(1),
                Parent = Sheen,
            }),
        }
        StartShimmerLoop()
        return Sheen
    end

    function Library:RaiseLayer(Root, Base)
        if typeof(Root) ~= "Instance" or not Root:IsA("GuiObject") then
            return
        end

        local function Lift(Object)
            if Object:IsA("GuiObject") and Object.Parent and not Object:GetAttribute("LayerLifted") then
                Object:SetAttribute("LayerLifted", true)
                if Object.ZIndex < Base then
                    Object.ZIndex = Base + Object.ZIndex
                end
            end
        end

        Root:SetAttribute("LayerLifted", true)
        Root.ZIndex = Base
        for _, Object in ipairs(Root:GetDescendants()) do
            Lift(Object)
        end
        Library:GiveSignal(Root.DescendantAdded:Connect(function(Object)
            task.defer(Lift, Object)
        end))
    end

    if NotificationArea then
        Library:RaiseLayer(NotificationArea, 40)
    end

    function Library:RemoveTextShimmer(Label)
        if typeof(Label) ~= "Instance" then
            return
        end
        local Item = ShimmerItems[Label]
        ShimmerItems[Label] = nil
        if Item and Item.Gradient then
            Item.Gradient:Destroy()
        end
        Library.Registry[Label] = Library.Registry[Label] or {}
        Library.Registry[Label].TextColor3 = "FontColor"
        Label.TextColor3 = Library.Scheme.FontColor
    end

    function Library:QueueKeybindWidth()
        if Library.KeybindWidthQueued then
            return
        end
        Library.KeybindWidthQueued = true

        task.defer(function()
            Library.KeybindWidthQueued = false
            pcall(function()
                local Frame = Library.KeybindFrame
                if not Frame then
                    return
                end
                if Frame:GetAttribute("Dragging") then
                    task.delay(0.25, function()
                        Library:QueueKeybindWidth()
                    end)
                    return
                end

                local Chip = 20
                for _, Row in ipairs(Library.KeybindToggles) do
                    if Row.Holder and Row.Holder.Visible and Row.KeyChip then
                        Chip = math.max(Chip, Row.KeyChip.TextBounds.X + 10)
                    end
                end

                local Widest = 0
                for _, Row in ipairs(Library.KeybindToggles) do
                    if Row.KeyChip then
                        local ChipLimit = Row.KeyChip:FindFirstChildOfClass("UISizeConstraint")
                        if ChipLimit then
                            ChipLimit.MinSize = Vector2.new(Chip, 18)
                        end
                    end
                    if Row.Holder and Row.Holder.Visible and Row.KeyChip and Row.Label then
                        local Tail = 40
                        local ChipSpace = Library.HideKeyChips and 0 or (Chip + 8)
                        Widest = math.max(Widest, 10 + ChipSpace + math.ceil(Row.Label.TextBounds.X * 1.12) + (Row.EmojiLabel and Row.EmojiLabel.Visible and Row.EmojiLabel.TextBounds.X + 8 or 0) + (Row.RowIcon and 20 or 0) + 20 + Tail + 6)
                    end
                end

                for _, Child in ipairs(Frame:GetChildren()) do
                    if Child:IsA("TextLabel") and Child.Text == "Keybinds" then
                        Widest = math.max(Widest, Child.TextBounds.X + 136)
                        break
                    end
                end

                Frame.AutomaticSize = Enum.AutomaticSize.Y
                Frame.Size = UDim2.fromOffset(math.max(math.ceil(Widest + 14), 160), 0)
            end)
        end)
    end
end

function Library:Notify(...)
    if Library.RgbEnabled then
        Library.RgbDirty = true
    end
    local Data = {}
    local Info = select(1, ...)

    if typeof(Info) == "table" then
        Data.Title = Info.Title ~= nil and tostring(Info.Title) or nil
        Data.TitleColor = Info.TitleColor

        Data.Description = Info.Description ~= nil and tostring(Info.Description) or nil
        Data.DescriptionColor = Info.DescriptionColor

        Data.Time = Info.Time or 5
        Data.SoundId = Info.SoundId
        Data.Steps = Info.Steps
        Data.Persist = Info.Persist

        Data.Callback = typeof(Info.Callback) == "function" and Info.Callback or nil
        Data.Closable = Info.Closable == true

        Data.Icon = Info.Icon
        Data.BigIcon = Info.BigIcon
        Data.IconColor = Info.IconColor

        Data.Volume = tonumber(Info.Volume) or 3
        Data.DescriptionSuffixImage = typeof(Info.DescriptionSuffixImage) == "table" and Info.DescriptionSuffixImage or nil
        Data.DescriptionAfterText = Info.DescriptionAfterText
    else
        Data.Description = tostring(Info)
        Data.Time = select(2, ...) or 5
        Data.SoundId = select(3, ...)
        Data.Volume = select(4, ...) or 3
    end
    Data.Destroyed = false

    local DeletedInstance = false
    local DeleteConnection = nil
    if typeof(Data.Time) == "Instance" then
        DeleteConnection = Data.Time.Destroying:Connect(ObsGuard(function()
            DeletedInstance = true

            DeleteConnection:Disconnect()
            DeleteConnection = nil
        end))
    end

    local FakeBackground = New("Frame", {
        AnchorPoint = Library.NotifySide:lower() == "left" and Vector2.new(0, 0) or Vector2.new(1, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(0, 0),
        Visible = false,
        Parent = NotificationArea,
    })

    local Holder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = "BackgroundColor",
        Position = (Library.NotifySide or "Right"):lower() == "left" and UDim2.new(-1, -8, 0, 0) or UDim2.new(1, 8, 0, 0),
        Size = UDim2.new(1, 0, 0, 0),
        ZIndex = 5,
        Parent = FakeBackground,
    })
    if not Library.IsMobile then Library:AddGlow(Holder) end
    table.insert(
        Library.Corners,
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = Holder,
        })
    )
    Library:AddOutline(Holder)

    local ContentHolder = New("Frame", {
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = Holder,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 4),
        Parent = ContentHolder,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 10),
        Parent = ContentHolder,
    })

    local CloseButton
    if Data.Closable then
        CloseButton = New("ImageButton", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundTransparency = 1,
            Image = CloseIcon and CloseIcon.Url or "",
            ImageColor3 = "FontColor",
            ImageRectOffset = CloseIcon and CloseIcon.ImageRectOffset or Vector2.zero,
            ImageRectSize = CloseIcon and CloseIcon.ImageRectSize or Vector2.zero,
            ImageTransparency = 0.5,
            Position = UDim2.new(1, -8, 0, 8),
            Size = UDim2.fromOffset(14, 14),
            ZIndex = 6,
            Parent = Holder,
        })

        CloseButton.MouseEnter:Connect(ObsGuard(function()
            TweenService:Create(CloseButton, Library.TweenInfo, {
                ImageTransparency = 0,
            }):Play()
        end))
        CloseButton.MouseLeave:Connect(ObsGuard(function()
            TweenService:Create(CloseButton, Library.TweenInfo, {
                ImageTransparency = 0.5,
            }):Play()
        end))
        CloseButton.MouseButton1Click:Connect(ObsGuard(function()
            Data:Destroy("user")
        end))
    end

    local ContentContainer = New("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.fromOffset(0, 0),
        Parent = ContentHolder,
    })
    
    if Data.BigIcon then
        New("UIListLayout", {
            Padding = UDim.new(0, 8),
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Parent = ContentContainer,
        })
    end

    local BigIconLabel
    if Data.BigIcon then
        local ParsedIcon = Library:GetCustomIcon(Data.BigIcon)
        if ParsedIcon then
            BigIconLabel = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(38, 38),
                Parent = ContentContainer,
            })
            local BadgeIcon = New("ImageLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundTransparency = 1,
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(30, 30),
                Image = ParsedIcon.Url,
                ImageColor3 = Data.IconColor or Color3.new(1, 1, 1),
                ImageRectOffset = ParsedIcon.ImageRectOffset,
                ImageRectSize = ParsedIcon.ImageRectSize,
                ScaleType = Enum.ScaleType.Fit,
                Parent = BigIconLabel,
            })
            if not Data.IconColor then
                pcall(function()
                    Library:AddSharedGradient(BadgeIcon, {})
                end)
            end
        end
    end

    local Header = { Mode = BigIconLabel == nil, Line = 22, Gap = 8, Icon = 16 }

    local TextContainer = New("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.XY,
        Size = UDim2.fromOffset(0, 0),
        Parent = ContentContainer,
    })
    New("UIListLayout", {
        HorizontalAlignment = Header.Mode and Enum.HorizontalAlignment.Center or Enum.HorizontalAlignment.Left,
        Padding = UDim.new(0, Header.Mode and 5 or 4),
        Parent = TextContainer,
    })
    
    local TitleContainer
    if Data.Title or Header.Mode then
        TitleContainer = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromOffset(0, 0),
            Parent = TextContainer,
        })
    end

    local IconLabel
    local NotifyIcon = Data.Icon or (Header.Mode and Library.NotifyLogo) or nil
    if NotifyIcon and TitleContainer then
        local ParsedIcon = Library:GetCustomIcon(NotifyIcon)
        if ParsedIcon and Header.Mode then
            local Branded = Data.IconColor == nil and (NotifyIcon == Library.NotifyLogo or IsBrandIcon(NotifyIcon))
            IconLabel = New("ImageLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(Header.Icon, Header.Icon),
                Image = ParsedIcon.Url,
                ImageColor3 = Data.IconColor or (Branded and Color3.new(1, 1, 1) or "FontColor"),
                ImageRectOffset = ParsedIcon.ImageRectOffset,
                ImageRectSize = ParsedIcon.ImageRectSize,
                ScaleType = Enum.ScaleType.Fit,
                Parent = TitleContainer,
            })
            if Branded then
                pcall(function()
                    Library:AddSharedGradient(IconLabel, {})
                end)
            end
        elseif ParsedIcon then
            IconLabel = New("ImageLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, 0, 0.5, 1),
                Size = UDim2.fromOffset(15, 15),
                Image = ParsedIcon.Url,
                ImageColor3 = Data.IconColor or (IsBrandIcon(Data.Icon) and "AccentColor" or "FontColor"),
                ImageRectOffset = ParsedIcon.ImageRectOffset,
                ImageRectSize = ParsedIcon.ImageRectSize,
                Parent = TitleContainer,
            })
        end
    end

    if Header.Mode and TitleContainer then
        local function MakeHeaderLine(FadeLeft)
            local HeaderLine = New("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = "AccentColor",
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(Header.Line, 1),
                Parent = TitleContainer,
            })
            New("UIGradient", {
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, FadeLeft and 1 or 0.15),
                    NumberSequenceKeypoint.new(1, FadeLeft and 0.15 or 1),
                }),
                Parent = HeaderLine,
            })
            return HeaderLine
        end
        Header.Left = MakeHeaderLine(true)
        Header.Right = MakeHeaderLine(false)
    end

    local Title
    local Desc
    local TitleX = 0
    local DescX = 0

    local TimerFill

    if Data.Title then
        Title = New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.None,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, (IconLabel and 21 or 0), 0.5, 0),
            Size = UDim2.fromScale(0, 0),
            Text = Data.Title,
            TextColor3 = Data.TitleColor or "FontColor",
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            TextWrapped = false,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Parent = TitleContainer,
        })
        if not Data.TitleColor then
            pcall(function()
                Library:RemoveFromRegistry(Title)
                Title.TextColor3 = Color3.new(1, 1, 1)
                local reg = Library:AddSharedGradient(Title, { isRgb = false })
                if reg then reg.alwaysUpdate = true end
            end)
        end
    end

    local DescSuffix, DescAfter
    if Data.Description then
        Desc = New("TextLabel", {
            AutomaticSize = Enum.AutomaticSize.None,
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(0, 0),
            Text = Data.Description,
            TextColor3 = Data.DescriptionColor or "FontColor",
            TextSize = 14,
            TextTransparency = 0.2,
            TextXAlignment = (Header.Mode and not Data.DescriptionSuffixImage) and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
            TextWrapped = true,
            Parent = TextContainer,
        })
        local SI = Data.DescriptionSuffixImage
        if SI and SI.Url then
            DescSuffix = New("ImageLabel", {
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundTransparency = 1,
                Image = SI.Url,
                ImageRectOffset = SI.ImageRectOffset or Vector2.zero,
                ImageRectSize = SI.ImageRectSize or Vector2.zero,
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.fromOffset(14, 14),
                Parent = Desc,
            })
            if type(Data.DescriptionAfterText) == "string" and Data.DescriptionAfterText ~= "" then
                DescAfter = New("TextLabel", {
                    AutomaticSize = Enum.AutomaticSize.None,
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(0, 0),
                    Text = Data.DescriptionAfterText,
                    TextColor3 = Data.DescriptionColor or "FontColor",
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = Desc,
                })
            end
        end
    end

    function Data:Resize()
        local ExtraWidth = BigIconLabel and 46 or 0
        local IconWidth = IconLabel and 21 or 0
        -- NotificationArea is a fixed 300px-wide container, but Frames don't clip
        -- their children by default -- FakeBackground/Holder below are sized from
        -- the text's own natural bounds, not from NotificationArea's width. The only
        -- thing that was forcing titles/descriptions to wrap was capping GetTextBounds
        -- to NotificationArea's width here. Use a generous bound instead so normal
        -- single-line text never wraps, while still containing genuinely long text.
        local MaxTextWidth = 560
        local CloseWidth = Data.Closable and 20 or 0

        if Title then
            local X, Y =
                Library:GetTextBounds(Title.Text, Title.FontFace, Title.TextSize, MaxTextWidth - ExtraWidth - IconWidth - CloseWidth)
            local singleLineH = math.ceil(Title.TextSize * 1.4)
            Y = math.min(Y, singleLineH)
            Title.Size = UDim2.fromOffset(X + 2, Y)
            TitleX = X + 2 + IconWidth
            TitleContainer.Size = UDim2.fromOffset(TitleX, math.max(Y, IconLabel and 16 or 0))
        end

        if Desc then
            local X, Y =
                Library:GetTextBounds(Desc.Text, Desc.FontFace, Desc.TextSize, MaxTextWidth - ExtraWidth)
            local Extra = 0
            if DescSuffix then
                DescSuffix.Position = UDim2.new(0, X + 4, 0.5, 0)
                Extra = 18
                if DescAfter then
                    local AX = Library:GetTextBounds(DescAfter.Text, DescAfter.FontFace, DescAfter.TextSize, 200)
                    DescAfter.Position = UDim2.fromOffset(X + 4 + 14 + 1, 0)
                    DescAfter.Size = UDim2.fromOffset(AX + 2, Y)
                    Extra = Extra + AX + 3
                end
            end
            Desc.Size = UDim2.fromOffset(X + 2 + Extra, Y)
            DescX = X + 2 + Extra
        end

        if Header.Mode and TitleContainer then
            local TextWidth = Title and Title.Size.X.Offset or 0
            local IconSpan = IconLabel and (Header.Icon + (Title and 6 or 0)) or 0
            local GroupWidth = Header.Line * 2 + Header.Gap * 2 + IconSpan + TextWidth
            TitleContainer.Size = UDim2.fromOffset(GroupWidth, math.max(Title and Title.Size.Y.Offset or 0, 18))
            local Cursor = Header.Line + Header.Gap
            Header.Left.Position = UDim2.new(0, Header.Line / 2, 0.5, 0)
            if IconLabel then
                IconLabel.Position = UDim2.new(0, Cursor + Header.Icon / 2, 0.5, 0)
                Cursor += IconSpan
            end
            if Title then
                Title.Position = UDim2.new(0, Cursor, 0.5, 0)
                Cursor += TextWidth
            end
            Header.Right.Position = UDim2.new(0, Cursor + Header.Gap + Header.Line / 2, 0.5, 0)
            TitleX = GroupWidth
        end

        FakeBackground.Size = UDim2.fromOffset(math.max(TitleX, DescX) + 26 + ExtraWidth + CloseWidth, 0)

        if Library.Notifications[FakeBackground] then
            task.defer(function()
                if Data.Destroyed or not FakeBackground.Parent then
                    return
                end

                Library:UpdateNotificationPositions(true)
            end)
        end
    end

    function Data:ChangeTitle(Text)
        if Title then
            Data.Title = tostring(Text)
            Title.Text = Data.Title
            Data:Resize()
        end
    end

    function Data:ChangeDescription(Text)
        if Desc then
            Data.Description = tostring(Text)
            Desc.Text = Data.Description
            Data:Resize()
        end
    end

    function Data:ChangeStep(NewStep)
        if TimerFill and Data.Steps then
            NewStep = math.clamp(NewStep or 0, 0, Data.Steps)
            TimerFill.Size = UDim2.fromScale(NewStep / Data.Steps, 1)
        end
    end

    function Data:Destroy(Reason)
        if Data.Destroyed then
            return
        end

        Reason = Reason or "script"
        Data.Destroyed = true

        if Data.Callback then
            pcall(Data.Callback, Reason)
        end

        if typeof(Data.Time) == "Instance" then
            pcall(Data.Time.Destroy, Data.Time)
        end

        if DeleteConnection then
            DeleteConnection:Disconnect()
        end

        if FakeBackground then
            local Idx = table.find(NotifyOrder, FakeBackground)
            if Idx then
                table.remove(NotifyOrder, Idx)
            end
        end

        Library:UpdateNotificationPositions()

        Library:Spring(Holder, "Position", (Library.NotifySide or "Right"):lower() == "left" and UDim2.new(-1, -8, 0, -2) or UDim2.new(1, 8, 0, -2), 26, 1)

        task.delay(0.45, function()
            Library.Notifications[FakeBackground] = nil
            FakeBackground:Destroy()
        end)
    end

    local TimerHolder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 8),
        Visible = (Data.Persist ~= true and typeof(Data.Time) ~= "Instance") or typeof(Data.Steps) == "number",
        Parent = ContentHolder,
    })
    local TimerBar = New("Frame", {
        BackgroundColor3 = "MainColor",
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 4),
        Size = UDim2.new(1, 0, 0, 3),
        Parent = TimerHolder,
    })
    New("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = TimerBar,
    })
    TimerFill = New("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Parent = TimerBar,
    })
    New("UICorner", {
        CornerRadius = UDim.new(1, 0),
        Parent = TimerFill,
    })
    pcall(function()
        Library:AddAccentGradient(TimerFill, {})
    end)

    if typeof(Data.Time) == "Instance" then
        TimerFill.Size = UDim2.fromScale(0, 1)
    end
    if Data.SoundId then
        local SoundId = Data.SoundId
        if typeof(SoundId) == "number" then
            SoundId = string.format("rbxassetid://%d", SoundId)
        end

        New("Sound", {
            SoundId = SoundId,
            Volume = tonumber(Data.Volume) or 3,
            PlayOnRemove = true,
            Parent = SoundService,
        }):Destroy()
    elseif Library.NotifySoundEnabled and not Data.Silent then
        Library:PlayNotifySound()
    end

    Data.Holder = Holder

    table.insert(NotifyOrder, FakeBackground)
    Library.Notifications[FakeBackground] = Data

    do
        local Cap = math.max(tonumber(Library.MaxNotifications) or 5, 1)
        local Active = 0
        for _, Other in NotifyOrder do
            local OtherData = Library.Notifications[Other]
            if OtherData and not OtherData.Destroyed then
                Active += 1
            end
        end
        for _, Other in table.clone(NotifyOrder) do
            if Active <= Cap then
                break
            end
            local OtherData = Library.Notifications[Other]
            if Other ~= FakeBackground and OtherData and not OtherData.Destroyed and not OtherData.Persist then
                OtherData:Destroy("overflow")
                Active -= 1
            end
        end
    end

    Holder.InputBegan:Connect(ObsGuard(function(Input)
        if Input.UserInputType ~= Enum.UserInputType.Touch or Data.Destroyed then
            return
        end
        local StartX = Input.Position.X
        Library:SpringStop(Holder, "Position")
        local SwipeConn
        SwipeConn = Input.Changed:Connect(ObsGuard(function()
            if Data.Destroyed then
                SwipeConn:Disconnect()
                return
            end
            local Dx = (Input.Position.X - StartX) / math.max(Library.DPIScale, 0.01)
            Holder.Position = UDim2.fromOffset(Dx, 0)
            if Input.UserInputState == Enum.UserInputState.End then
                SwipeConn:Disconnect()
                if math.abs(Dx) > 70 then
                    Data:Destroy("swipe")
                else
                    Library:Spring(Holder, "Position", UDim2.fromOffset(0, 0), 26, 0.8)
                end
            end
        end))
    end))

    Data:Resize()

    FakeBackground.Visible = true
    Library:Spring(Holder, "Position", UDim2.fromOffset(0, 0), 24, 0.68)

    task.defer(function()
        if not Data.Destroyed then
            Library:UpdateNotificationPositions(true)
        end
    end)

    task.delay(Library.NotifyTweenInfo.Time, function()
        if Data.Persist then
            return
        elseif typeof(Data.Time) == "Instance" then
            repeat
                task.wait(0.25)
            until DeletedInstance or Data.Destroyed or Library.Unloaded or not Data.Time.Parent
        else
            TweenService
                :Create(TimerFill, TweenInfo.new(Data.Time, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {
                    Size = UDim2.fromScale(0, 1),
                })
                :Play()
            task.wait(Data.Time)
        end

        if Library.Unloaded then
            return
        end
        Data:Destroy("timer")
    end)

    return Data
end

function Library:CreateWindow(WindowInfo)
    WindowInfo = Library:Validate(WindowInfo, Templates.Window)
    local ViewportSize: Vector2 = workspace.CurrentCamera.ViewportSize
    if RunService:IsStudio() and ViewportSize.X <= 5 and ViewportSize.Y <= 5 then
        repeat
            ViewportSize = workspace.CurrentCamera.ViewportSize
            task.wait()
        until ViewportSize.X > 5 and ViewportSize.Y > 5
    end

    local MaxX = ViewportSize.X - 64
    local MaxY = ViewportSize.Y - 64

    Library.OriginalMinSize =
        Vector2.new(math.min(Library.OriginalMinSize.X, MaxX), math.min(Library.OriginalMinSize.Y, MaxY))
    Library.MinSize = Vector2.new(math.min(WindowInfo.MinContainerWidth, MaxX), Library.OriginalMinSize.Y)

    WindowInfo.Size = UDim2.fromOffset(
        math.clamp(WindowInfo.Size.X.Offset, Library.MinSize.X, MaxX),
        math.clamp(WindowInfo.Size.Y.Offset, Library.MinSize.Y, MaxY)
    )
    if typeof(WindowInfo.Font) == "EnumItem" then
        WindowInfo.Font = Font.fromEnum(WindowInfo.Font :: any)
    end
    WindowInfo.CornerRadius = math.min(WindowInfo.CornerRadius, 20)

    local TabButtonsStyle = WindowInfo.TabButtonsStyle

    --// Old Naming \\--
    if WindowInfo.Compact ~= nil then
        WindowInfo.SidebarCompacted = WindowInfo.Compact
    end
    if WindowInfo.SidebarMinWidth ~= nil then
        WindowInfo.MinSidebarWidth = WindowInfo.SidebarMinWidth
    end
    WindowInfo.MinSidebarWidth = math.max(64 + TabButtonsStyle.Padding * 2, WindowInfo.MinSidebarWidth)
    WindowInfo.SidebarCompactWidth = math.max(40 + TabButtonsStyle.Padding * 2, WindowInfo.SidebarCompactWidth)
    WindowInfo.SidebarCollapseThreshold = math.clamp(WindowInfo.SidebarCollapseThreshold, 0.1, 0.9)
    WindowInfo.CompactWidthActivation = math.max(40 + TabButtonsStyle.Padding * 2, WindowInfo.CompactWidthActivation)
    WindowInfo.SnapDistance = math.max(0, WindowInfo.SnapDistance)
    WindowInfo.SnapMargin = math.max(0, WindowInfo.SnapMargin)

    Library.CornerRadius = WindowInfo.CornerRadius
    Library:SetNotifySide(WindowInfo.NotifySide)
    Library.ShowCustomCursor = WindowInfo.ShowCustomCursor
    Library.Scheme.Font = WindowInfo.Font
    Library.ToggleKeybind = WindowInfo.ToggleKeybind
    Library.GlobalSearch = WindowInfo.GlobalSearch
    
    Library.Animations = WindowInfo.Animations
    Library.TabTransitionInfo = TweenInfo.new(
        math.max(0, WindowInfo.TabTransitionTime or 0.22),
        Enum.EasingStyle.Quad,
        Enum.EasingDirection.Out
    )
    Library.TabSwipeOffset = math.max(1, WindowInfo.TabSwipeOffset or 26)
    Library.TabSwipeFrom = WindowInfo.TabSwipeFrom or "right"

    local IsDefaultSearchbarSize = WindowInfo.SearchbarSize == UDim2.fromScale(1, 1)
    local _toggleAnimTween = nil
    local MainFrameWrapper
    local MainFrameWrapperScale
    local MainFrame
    local DividerLine
    local TitleHolder
    local WindowTitle
    local WindowIcon
    local RightWrapper
    local SearchBox
    local CurrentTabInfo
    local CurrentTabLabel
    local CurrentTabDescription
    local ResizeButton
    local Tabs
    local Container
    local BackgroundImage
    local BottomBackground
    local FooterLabel
    local TopBar

    local InitialLeftWidth = math.ceil(WindowInfo.Size.X.Offset * 0.3)
    local IsCompact = WindowInfo.SidebarCompacted
    local LastExpandedWidth = InitialLeftWidth

    local WindowRecede = nil
    do
        Library.KeybindFrame, Library.KeybindContainer = Library:AddDraggableMenu("Keybinds")
        pcall(function()
            local KeybindScale = Library.KeybindFrame:FindFirstChildOfClass("UIScale")
            if KeybindScale then
                Library.ScalesOffset[KeybindScale] = (tonumber(Library.ScalesOffset[KeybindScale]) or 0) + 0.05
                KeybindScale.Scale = Library.DPIScale - Library.ScalesOffset[KeybindScale]
            end
        end)
        if Library.HideKeyChips == nil then
            Library.HideKeyChips = Library.IsMobile
        end
        if UserInputService.TouchEnabled then
            local KeyboardCheck = 0
            Library:GiveSignal(UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(ObsGuard(function()
                KeyboardCheck += 1
                local Mine = KeyboardCheck
                task.wait(0.6)
                if Mine ~= KeyboardCheck or Library.Unloaded then
                    return
                end
                local Hide = not UserInputService.KeyboardEnabled
                if Hide == Library.HideKeyChips then
                    return
                end
                Library.HideKeyChips = Hide
                for _, Row in ipairs(Library.KeybindToggles) do
                    if Row.KeyChip then
                        Row.KeyChip.Visible = not Hide
                    end
                end
                if Library.QueueKeybindWidth then
                    Library:QueueKeybindWidth()
                end
                local MenuOption = Options and Options.KeybindMenuOpen
                if MenuOption and MenuOption.SetValue then
                    MenuOption:SetValue(not Hide)
                elseif Library.KeybindFrame then
                    Library.KeybindFrame.Visible = not Hide
                end
            end)))
        end
        Library.KeybindFrame.AnchorPoint = Vector2.new(0, 0.5)
        Library.KeybindFrame.Position = UDim2.new(0, 6, 0.5, 0)
        Library.KeybindFrame.Visible = false
        Library:AddGlow(Library.KeybindFrame)
        New("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(0.4, Color3.new(0.94, 0.94, 0.94)),
                ColorSequenceKeypoint.new(1, Color3.new(0.55, 0.55, 0.55)),
            }),
            Rotation = 90,
            Parent = Library.KeybindFrame,
        })
        Library.KeybindFrame.ZIndex = 5
        for _, KeybindLayout in ipairs(Library.KeybindContainer:GetChildren()) do
            if KeybindLayout:IsA("UIListLayout") then
                KeybindLayout.Padding = UDim.new(0, 4)
            elseif KeybindLayout:IsA("UIPadding") then
                KeybindLayout.PaddingLeft = UDim.new(0, 7)
                KeybindLayout.PaddingRight = UDim.new(0, 7)
                KeybindLayout.PaddingTop = UDim.new(0, 7)
                KeybindLayout.PaddingBottom = UDim.new(0, 7)
            end
        end
        for _, KeybindPart in ipairs(Library.KeybindFrame:GetDescendants()) do
            if KeybindPart:IsA("GuiObject") then
                KeybindPart.ZIndex = 0
            end
        end
        Library:RaiseLayer(Library.KeybindFrame, 20)
        do
            local Holder = Library.KeybindFrame
            local Title = nil

            for _, Child in ipairs(Holder:GetChildren()) do
                if Child:IsA("TextLabel") and Child.Text == "Keybinds" then
                    Title = Child
                end
            end

            if Title then
                local TitleIcon = WindowInfo.Icon and Library:GetCustomIcon(WindowInfo.Icon) or nil
                if TitleIcon then
                    Library.NotifyLogo = WindowInfo.Icon
                end
                local IconSize, IconGap, LineWidth, LineGap = 16, 6, 36, 9
                local Shift = TitleIcon and (IconSize + IconGap) / 2 or 0

                Title.TextXAlignment = Enum.TextXAlignment.Center
                local TitlePadding = Title:FindFirstChildOfClass("UIPadding")
                if TitlePadding then
                    TitlePadding.PaddingLeft = UDim.new(0, 12 + Shift * 2)
                    TitlePadding.PaddingRight = UDim.new(0, 12)
                end

                local Logo = nil
                if TitleIcon then
                    Logo = New("ImageLabel", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundTransparency = 1,
                        Image = TitleIcon.Url,
                        ImageColor3 = Color3.new(1, 1, 1),
                        ImageRectOffset = TitleIcon.ImageRectOffset or Vector2.zero,
                        ImageRectSize = TitleIcon.ImageRectSize or Vector2.zero,
                        ScaleType = Enum.ScaleType.Fit,
                        Size = UDim2.fromOffset(IconSize, IconSize),
                        ZIndex = 0,
                        Parent = Holder,
                    })
                end

                local function MakeTitleLine(FadeLeft)
                    local TitleLine = New("Frame", {
                        AnchorPoint = Vector2.new(0.5, 0.5),
                        BackgroundColor3 = "AccentColor",
                        BorderSizePixel = 0,
                        Size = UDim2.fromOffset(LineWidth, 1),
                        ZIndex = 0,
                        Parent = Holder,
                    })
                    New("UIGradient", {
                        Transparency = NumberSequence.new({
                            NumberSequenceKeypoint.new(0, FadeLeft and 1 or 0.15),
                            NumberSequenceKeypoint.new(1, FadeLeft and 0.15 or 1),
                        }),
                        Parent = TitleLine,
                    })
                    return TitleLine
                end

                local LeftLine = MakeTitleLine(true)
                local RightLine = MakeTitleLine(false)

                local function PlaceTitleDecor()
                    local TextWidth = Title.TextBounds.X
                    local TextLeft = Shift - TextWidth / 2
                    local TextRight = Shift + TextWidth / 2
                    local LeftEdge = TextLeft

                    if Logo then
                        local LogoCenter = TextLeft - IconGap - IconSize / 2
                        Logo.Position = UDim2.new(0.5, LogoCenter, 0, 17)
                        LeftEdge = LogoCenter - IconSize / 2
                    end

                    LeftLine.Position = UDim2.new(0.5, LeftEdge - LineGap - LineWidth / 2, 0, 17)
                    RightLine.Position = UDim2.new(0.5, TextRight + LineGap + LineWidth / 2, 0, 17)
                end

                PlaceTitleDecor()
                Title:GetPropertyChangedSignal("TextBounds"):Connect(ObsGuard(PlaceTitleDecor))

                pcall(function()
                    Library:RemoveFromRegistry(Title)
                end)
                Title.TextColor3 = Color3.new(1, 1, 1)
                pcall(function()
                    Library:AddSharedGradient(Title, {})
                end)
                if Logo then
                    pcall(function()
                        Library:AddSharedGradient(Logo, {})
                    end)
                end
            end
        end

        local function AddRecede(GetFrame)
            task.spawn(function()
                local Receded, Home, HomeRect, Tracked = false, nil, nil, nil
                local RecedeInfo = TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

                local function Overlaps(APosition, ASize, BPosition, BSize)
                    return APosition.X < BPosition.X + BSize.X and BPosition.X < APosition.X + ASize.X
                        and APosition.Y < BPosition.Y + BSize.Y and BPosition.Y < APosition.Y + ASize.Y
                end

                while not Library.Unloaded do
                    pcall(function()
                        local Frame = GetFrame()
                        if Frame ~= Tracked then
                            Tracked, Receded, Home, HomeRect = Frame, false, nil, nil
                        end

                        if not Frame or not Frame.Parent or not MainFrame then
                            return
                        end

                        if not (Frame.Visible or Receded) then
                            return
                        end

                        if Frame:GetAttribute("LayoutAnimating") then
                            if Receded then
                                Receded = false
                                HomeRect = nil
                                Frame:SetAttribute("RecedeHomePosition", nil)
                            end
                            return
                        end

                        if Frame:GetAttribute("Dragging") then
                            Frame:SetAttribute("UserPlaced", true)
                            if Receded then
                                Receded = false
                                HomeRect = nil
                                Frame:SetAttribute("RecedeHomePosition", nil)
                            end
                            return
                        end

                        if not Library.Toggled and not Receded then
                            return
                        end

                        local KeyPosition = HomeRect and HomeRect[1] or Frame.AbsolutePosition
                        local KeySize = HomeRect and HomeRect[2] or Frame.AbsoluteSize
                        local Hit = Library.Toggled and Frame.Visible
                            and Overlaps(KeyPosition, KeySize, MainFrame.AbsolutePosition, MainFrame.AbsoluteSize)

                        if Frame:GetAttribute("UserPlaced") and not Receded then
                            if not Hit then
                                Frame:SetAttribute("UserPlaced", nil)
                            end
                            return
                        end

                        if Hit and not Receded then
                            Receded = true
                            Home = Frame.Position
                            HomeRect = { Frame.AbsolutePosition, Frame.AbsoluteSize }
                            Frame:SetAttribute("RecedeHomePosition", HomeRect[1])

                            local Screen = ScreenGui.AbsoluteSize
                            local Left, Right = KeyPosition.X + KeySize.X, Screen.X - KeyPosition.X
                            local Up, Down = KeyPosition.Y + KeySize.Y, Screen.Y - KeyPosition.Y
                            local Travel = math.min(Left, Right, Up, Down)
                            local Offset
                            if Travel == Left then
                                Offset = UDim2.fromOffset(-(Left + 24), 0)
                            elseif Travel == Right then
                                Offset = UDim2.fromOffset(Right + 24, 0)
                            elseif Travel == Up then
                                Offset = UDim2.fromOffset(0, -(Up + 24))
                            else
                                Offset = UDim2.fromOffset(0, Down + 24)
                            end

                            Library:SpringStop(Frame, "Position")
                            TweenService:Create(Frame, RecedeInfo, { Position = Home + Offset }):Play()
                        elseif Receded and not Hit then
                            Receded = false
                            HomeRect = nil
                            Frame:SetAttribute("RecedeHomePosition", nil)
                            Library:SpringStop(Frame, "Position")
                            TweenService:Create(Frame, RecedeInfo, { Position = Home }):Play()
                        end
                    end)

                    task.wait(0.1)
                end
            end)
        end

        WindowRecede = AddRecede
        AddRecede(function()
            return Library.KeybindFrame
        end)
        AddRecede(function()
            local Mark = Library.Watermark
            return Mark and not Mark.Destroyed and Mark.DraggableLabel and Mark.DraggableLabel.Frame or nil
        end)

        local _wrapW = WindowInfo.Size.X.Offset
        local _wrapH = WindowInfo.Size.Y.Offset
        local _wrapPos
        if WindowInfo.Center then
            _wrapPos = UDim2.fromScale(0.5, 0.5)
        else
            _wrapPos = UDim2.new(
                WindowInfo.Position.X.Scale,
                WindowInfo.Position.X.Offset + _wrapW / 2,
                WindowInfo.Position.Y.Scale,
                WindowInfo.Position.Y.Offset + _wrapH / 2
            )
        end
        MainFrameWrapper = New("Frame", {
            Name = "MainWrapper",
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Position = _wrapPos,
            Size = WindowInfo.Size,
            Visible = false,
            Parent = ScreenGui,
        })
        MainFrameWrapperScale = New("UIScale", {
            Scale = 1,
            Parent = MainFrameWrapper,
        })
        MainFrame = New("TextButton", {
            BackgroundColor3 = function()
                return Library:GetBetterColor(Library.Scheme.BackgroundColor, -1)
            end,
            Name = "Main",
            Text = "",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = WindowInfo.Size,
            Visible = true,
            Parent = MainFrameWrapper,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                Parent = MainFrame,
            })
        )
        table.insert(
            Library.Scales,
            New("UIScale", {
                Scale = Library.DPIScale,
                Parent = MainFrame,
            })
        )
        Library:AddOutline(MainFrame)
        Library:AddGlow(MainFrame)
        Library.DragShell = MainFrame
        Library:MakeLine(MainFrame, {
            Position = UDim2.fromOffset(0, 48),
            Size = UDim2.new(1, 0, 0, 1),
        })

        DividerLine = New("Frame", {
            BackgroundColor3 = "OutlineColor",
            Position = UDim2.fromOffset(InitialLeftWidth, 0),
            Size = UDim2.new(0, 1, 1, -21),
            Parent = MainFrame,
            ZIndex = 2
        })

        local BackgroundIcon = Library:GetCustomIcon(WindowInfo.BackgroundImage)
        BackgroundImage = New("ImageLabel", {
            Image = BackgroundIcon and BackgroundIcon.Url or "",
            ImageRectOffset = BackgroundIcon and BackgroundIcon.ImageRectOffset or Vector2.zero,
            ImageRectSize = BackgroundIcon and BackgroundIcon.ImageRectSize or Vector2.zero,
            Position = UDim2.fromScale(0, 0),
            Size = UDim2.fromScale(1, 1),
            ScaleType = Enum.ScaleType.Stretch,
            ZIndex = 999,
            BackgroundTransparency = 1,
            ImageTransparency = 0.75,
            Visible = BackgroundIcon ~= nil,
            Parent = MainFrame,
        })

        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                Parent = BackgroundImage,
            })
        )

        --// Top Bar \\-
        TopBar = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 48),
            Parent = MainFrame,
        })
        Library:MakeDraggable(MainFrameWrapper, TopBar, false, true)

        --// Title \\--
        TitleHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, InitialLeftWidth, 1, 0),
            Parent = TopBar,
        })
        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6),
            Parent = TitleHolder,
        })

        if WindowInfo.Icon then
            local Icon = Library:GetCustomIcon(WindowInfo.Icon)
            WindowIcon = New("ImageLabel", {
                Image = Icon and Icon.Url or "",
                ImageRectOffset = Icon and Icon.ImageRectOffset or Vector2.zero,
                ImageRectSize = Icon and Icon.ImageRectSize or Vector2.zero,
                ImageColor3 = Color3.new(1, 1, 1),
                Size = WindowInfo.IconSize,
                Parent = TitleHolder,
            })
            pcall(function()
                Library:AddSharedGradient(WindowIcon, {})
            end)
        else
            WindowIcon = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = WindowInfo.IconSize,
                Text = WindowInfo.Title:sub(1, 1),
                TextScaled = true,
                Visible = false,
                Parent = TitleHolder,
            })
        end

        local X = Library:GetTextBounds(
            WindowInfo.Title,
            Library.Scheme.Font,
            20,
            TitleHolder.AbsoluteSize.X - (WindowInfo.Icon and WindowInfo.IconSize.X.Offset + 6 or 0) - 12
        )
        WindowTitle = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, X, 1, 0),
            Text = WindowInfo.Title,
            TextSize = 20,
            Parent = TitleHolder,
        })
        pcall(function()
            Library:RemoveFromRegistry(WindowTitle)
        end)
        WindowTitle.TextColor3 = Color3.new(1, 1, 1)
        pcall(function()
            Library:AddSharedGradient(WindowTitle, {})
        end)

        --// Top Right Bar \\--
        RightWrapper = New("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -49, 0.5, 0),
            Size = UDim2.new(1, -InitialLeftWidth - 57 - 1, 1, -16),
            Parent = TopBar,
        })

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 8),
            Parent = RightWrapper,
        })

        CurrentTabInfo = New("Frame", {
            Size = UDim2.fromScale(WindowInfo.DisableSearch and 1 or 0.5, 1),
            Visible = false,
            BackgroundTransparency = 1,
            Parent = RightWrapper,
        })

        New("UIFlexItem", {
            FlexMode = Enum.UIFlexMode.Grow,
            Parent = CurrentTabInfo,
        })

        New("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Parent = CurrentTabInfo,
        })

        New("UIPadding", {
            PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 8),
            Parent = CurrentTabInfo,
        })

        CurrentTabLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = "",
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = CurrentTabInfo,
        })

        CurrentTabDescription = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = "",
            TextWrapped = true,
            TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTransparency = 0.5,
            Parent = CurrentTabInfo,
        })

        SearchBox = New("TextBox", {
            BackgroundColor3 = "MainColor",
            PlaceholderText = "Search",
            Size = WindowInfo.SearchbarSize,
            TextSize = 14,
            Visible = not (WindowInfo.DisableSearch or false),
            Parent = RightWrapper,
        })
        New("UIFlexItem", {
            FlexMode = Enum.UIFlexMode.Shrink,
            Parent = SearchBox,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                Parent = SearchBox,
            })
        )
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 8),
            PaddingLeft = UDim.new(0, 8),
            PaddingRight = UDim.new(0, 8),
            PaddingTop = UDim.new(0, 8),
            Parent = SearchBox,
        })
        local SearchBoxStroke = New("UIStroke", {
            Color = "OutlineColor",
            Parent = SearchBox,
        })

        Library:GiveSignal(SearchBox.Focused:Connect(ObsGuard(function()
            Library.Registry[SearchBoxStroke].Color = "AccentColor"
            TweenService:Create(SearchBoxStroke, Library.TweenInfo, {
                Color = Library.Scheme.AccentColor,
            }):Play()
        end)))

        Library:GiveSignal(SearchBox.FocusLost:Connect(ObsGuard(function()
            Library.Registry[SearchBoxStroke].Color = "OutlineColor"
            TweenService:Create(SearchBoxStroke, Library.TweenInfo, {
                Color = Library.Scheme.OutlineColor,
            }):Play()
        end)))

        local SearchIcon = Library:GetIcon("search")
        if SearchIcon then
            New("ImageLabel", {
                Image = SearchIcon.Url,
                ImageColor3 = "FontColor",
                ImageRectOffset = SearchIcon.ImageRectOffset,
                ImageRectSize = SearchIcon.ImageRectSize,
                ImageTransparency = 0.5,
                Size = UDim2.fromScale(1, 1),
                SizeConstraint = Enum.SizeConstraint.RelativeYY,
                Parent = SearchBox,
            })
        end

        if MoveIcon then
            New("ImageLabel", {
                AnchorPoint = Vector2.new(1, 0.5),
                Image = MoveIcon.Url,
                ImageColor3 = "OutlineColor",
                ImageRectOffset = MoveIcon.ImageRectOffset,
                ImageRectSize = MoveIcon.ImageRectSize,
                Position = UDim2.new(1, -10, 0.5, 0),
                Size = UDim2.fromOffset(28, 28),
                SizeConstraint = Enum.SizeConstraint.RelativeYY,
                Parent = TopBar,
            })
        end

        --// Bottom Bar \\--
        BottomBackground = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = function()
                return Library:GetBetterColor(Library.Scheme.BackgroundColor, 4)
            end,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 20 + WindowInfo.CornerRadius),
            Parent = MainFrame
        })
        Library:MakeLine(MainFrame, {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, -20),
            Size = UDim2.new(1, 0, 0, 1),
        })

        local BottomBar = New("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 20),
            Parent = MainFrame,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                Parent = BottomBackground,
            })
        )

        --// Footer \\-
        FooterLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = WindowInfo.Footer,
            TextSize = 14,
            TextTransparency = 0.5,
            Parent = BottomBar,
        })

        --// Resize Button \\--
        if WindowInfo.Resizable then
            ResizeButton = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0),
                BackgroundTransparency = 1,
                Position = UDim2.new(1, -WindowInfo.CornerRadius / 4, 0, 0),
                Size = UDim2.fromScale(1, 1),
                SizeConstraint = Enum.SizeConstraint.RelativeYY,
                Text = "",
                Parent = BottomBar,
            })

            Library:MakeResizable(MainFrame, ResizeButton, function()
                for _, Tab in Library.Tabs do
                    Tab:Resize(true)
                end
            end)
        end

        New("ImageLabel", {
            Image = ResizeIcon and ResizeIcon.Url or "",
            ImageColor3 = "FontColor",
            ImageRectOffset = ResizeIcon and ResizeIcon.ImageRectOffset or Vector2.zero,
            ImageRectSize = ResizeIcon and ResizeIcon.ImageRectSize or Vector2.zero,
            ImageTransparency = 0.5,
            Position = UDim2.fromOffset(2, 2),
            Size = UDim2.new(1, -4, 1, -4),
            Parent = ResizeButton,
        })
        if Library.IsMobile and ResizeButton then
            ResizeButton.AnchorPoint = Vector2.new(1, 1)
            ResizeButton.Position = UDim2.new(1, -WindowInfo.CornerRadius / 4, 1, 0)
            ResizeButton.SizeConstraint = Enum.SizeConstraint.RelativeXY
            ResizeButton.Size = UDim2.fromOffset(40, 40)
            for _, Icon in ipairs(ResizeButton:GetChildren()) do
                if Icon:IsA("ImageLabel") then
                    Icon.AnchorPoint = Vector2.new(1, 1)
                    Icon.Position = UDim2.new(1, -2, 1, -2)
                    Icon.Size = UDim2.fromOffset(16, 16)
                end
            end
        end

        --// Tabs \\--
        Tabs = New("ScrollingFrame", {
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            BackgroundColor3 = "BackgroundColor",
            CanvasSize = UDim2.fromScale(0, 0),
            Position = UDim2.fromOffset(0, 49),
            ScrollBarThickness = 0,
            Size = UDim2.new(0, InitialLeftWidth, 1, -70),
            Parent = MainFrame,
        })
        New("UIListLayout", {
            Padding = UDim.new(0, TabButtonsStyle.Gap),
            Parent = Tabs,
        })
        Library:AddSmoothScroll(Tabs)
        New("UIPadding", {
            PaddingBottom = UDim.new(0, TabButtonsStyle.Padding),
            PaddingLeft = UDim.new(0, TabButtonsStyle.Padding),
            PaddingRight = UDim.new(0, TabButtonsStyle.Padding),
            PaddingTop = UDim.new(0, TabButtonsStyle.Padding),
            Parent = Tabs,
        })

        --// Container \\--
        Container = New("Frame", {
            AnchorPoint = Vector2.new(1, 0),
            BackgroundColor3 = function()
                return Library:GetBetterColor(Library.Scheme.BackgroundColor, 1)
            end,
            ClipsDescendants = true,
            Name = "Container",
            Position = UDim2.new(1, 0, 0, 49),
            Size = UDim2.new(1, -InitialLeftWidth - 1, 1, -70),
            Parent = MainFrame,
        })
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 0),
            PaddingLeft = UDim.new(0, 6),
            PaddingRight = UDim.new(0, 6),
            PaddingTop = UDim.new(0, 0),
            Parent = Container,
        })

        Library.WindowContainer = Container
    end

    --// Window Table \\--
    local Window = {}
    local Fading = false

    local function SetUICorner(UICorner, Corner, HalfCurrent, HalfValue, Value)
        local Current = UICorner[Corner]
        if Current.Offset == 0 and Current.Scale == 0 then
            return
        end

        UICorner[Corner] = Current.Offset == HalfCurrent and HalfValue or Value
    end

    function Window:ChangeTitle(title)
        assert(typeof(title) == "string", "Expected string for title got: " .. typeof(title))

        WindowTitle.Text = title
        WindowInfo.Title = title
    end

    function Window:SetBackgroundImage(Image: string)
        local ValidIcon = false

        if typeof(Image) == "string" then
            local BackgroundIcon = Library:GetCustomIcon(Image)

            if BackgroundIcon then
                ValidIcon = true

                BackgroundImage.Image = BackgroundIcon.Url
                BackgroundImage.ImageRectOffset = BackgroundIcon.ImageRectOffset or Vector2.zero
                BackgroundImage.ImageRectSize = BackgroundIcon.ImageRectSize or Vector2.zero
                BackgroundImage.Visible = true
            elseif Image:match("http://") or Image:match("https://") then
                local RawFileName = Image:match("(.+)%..+$")
                local _, Domain = Image:match("^(https?://)([^/]+)"); 

                if RawFileName and Domain then
                    local Extention = string.sub(Image, #RawFileName + 1, #Image)
                    local FileNamePos = RawFileName:gsub("\\", "/"):find("/[^/]*$")
                    local FileName = FileNamePos and Image:sub(FileNamePos + 1) or nil

                    if FileName then
                        ValidIcon = true

                        local AssetName = Domain .. FileName
                        if #AssetName > 255 then
                            local NewLength = 255 - #Domain - #Extention
                            if NewLength < 0 then
                                AssetName = Domain .. Extention
                            else
                                AssetName = Domain .. string.sub(FileName:sub(1, #FileName - #Extention), 1, NewLength) .. Extention
                            end
                        end

                        if CustomImageManagerAssets[FileName] == nil then
                            CustomImageManager.AddAsset(FileName, 0, Image)
                        else
                            CustomImageManager.DownloadAsset(FileName, true)
                        end

                        BackgroundImage.Image = CustomImageManager.GetAsset(FileName)
                        BackgroundImage.ImageRectOffset = Vector2.zero
                        BackgroundImage.ImageRectSize = Vector2.zero
                        BackgroundImage.Visible = true
                    end
                end
            end
        end

        if not ValidIcon then
            BackgroundImage.Image = ""
            BackgroundImage.ImageRectOffset = Vector2.zero
            BackgroundImage.ImageRectSize = Vector2.zero
            BackgroundImage.Visible = false
        end
    
        WindowInfo.BackgroundImage = Image
    end

    function Window:SetFooter(Footer: string)
        assert(typeof(Footer) == "string", "Expected string for footer got: " .. typeof(Footer))

        FooterLabel.Text = Footer
        WindowInfo.Footer = Footer
    end

    function Window:SetAlwaysOnTop(Enabled: boolean)
        WindowInfo.AlwaysOnTop = Enabled == true
        SetAlwaysOnTop(Library.ScreenGui, WindowInfo.AlwaysOnTop)
    end

    function Window:SetCornerRadius(Radius: number)
        assert(typeof(Radius) == "number", "Expected number for Radius got: " .. typeof(Radius))
        Radius = math.min(Radius, 20)

        local RadiusHalf = UDim.new(0, Radius / 2)
        local RadiusUDim = UDim.new(0, Radius)
        local HalfCurrent = Library.CornerRadius / 2

        for i = #Library.Corners, 1, -1 do
            local UICorner = Library.Corners[i]
            if not UICorner.Parent then
                table.remove(Library.Corners, i)
            elseif UICorner.CornerRadius.Offset == HalfCurrent then
                UICorner.CornerRadius = RadiusHalf
            else
                UICorner.CornerRadius = RadiusUDim
            end
        end

        for _, UICorner in Library.SpecificCorners do
            SetUICorner(UICorner, "TopRightRadius", HalfCurrent, RadiusHalf, RadiusUDim)
            SetUICorner(UICorner, "TopLeftRadius", HalfCurrent, RadiusHalf, RadiusUDim)
            SetUICorner(UICorner, "BottomRightRadius", HalfCurrent, RadiusHalf, RadiusUDim)
            SetUICorner(UICorner, "BottomLeftRadius", HalfCurrent, RadiusHalf, RadiusUDim)
        end

        Library.CornerRadius = Radius
        WindowInfo.CornerRadius = Radius

        ResizeButton.Position = UDim2.new(1, -Radius / 4, 0, 0)
        BottomBackground.Size = UDim2.new(1, 0, 0, 20 + Radius)

        for _, Tab in Library.Tabs do
            if Tab.IsKeyTab then
                continue
            end

            for _, Tabbox in Tab.Tabboxes do
                Tabbox:UpdateCorners()
            end
        end
    end

    function Window:SetAnimations(Animations: { [string]: boolean }?, TabTransitionTime: number?, TabSwipeOffset: number?, TabSwipeFrom: ("left" | "right" | "top" | "bottom" | string)?)
        if typeof(Animations) == "table" then
            WindowInfo.Animations = Animations
            Library.Animations = Animations
        end

        if typeof(TabTransitionTime) == "number" then
            local TweenInfo = TweenInfo.new(
                math.max(0, TabTransitionTime or 0.22),
                Enum.EasingStyle.Quad,
                Enum.EasingDirection.Out
            )

            WindowInfo.TabTransitionInfo = TweenInfo
            Library.TabTransitionInfo = TweenInfo
        end

        if typeof(TabSwipeOffset) == "number" then
            TabSwipeOffset = math.max(1, TabSwipeOffset)

            WindowInfo.TabSwipeOffset = TabSwipeOffset
            Library.TabSwipeOffset = TabSwipeOffset
        end

        if typeof(TabSwipeFrom) == "string" then
            TabSwipeFrom = string.lower(TabSwipeFrom)

            WindowInfo.TabSwipeFrom = TabSwipeFrom
            Library.TabSwipeFrom = TabSwipeFrom
        end
    end

    local function ApplyCompact()
        IsCompact = Window:GetSidebarWidth() == WindowInfo.SidebarCompactWidth
        if WindowInfo.DisableCompactingSnap then
            IsCompact = Window:GetSidebarWidth() <= WindowInfo.CompactWidthActivation
        end

        WindowTitle.Visible = not IsCompact
        if not WindowInfo.Icon then
            WindowIcon.Visible = IsCompact
        end

        for _, Button in Library.TabButtons do
            if not Button.Icon then
                continue
            end

            Button.Label.Visible = not IsCompact
            Button.Padding.PaddingBottom = UDim.new(0, IsCompact and 6 or 11)
            Button.Padding.PaddingLeft = UDim.new(0, IsCompact and 6 or 12)
            Button.Padding.PaddingRight = UDim.new(0, IsCompact and 6 or 12)
            Button.Padding.PaddingTop = UDim.new(0, IsCompact and 6 or 11)
            Button.Icon.SizeConstraint = IsCompact and Enum.SizeConstraint.RelativeXY or Enum.SizeConstraint.RelativeYY
        end
    end

    function Window:IsSidebarCompacted()
        return IsCompact
    end

    function Window:SetCompact(State)
        Window:SetSidebarWidth(State and WindowInfo.SidebarCompactWidth or LastExpandedWidth)
    end

    function Window:GetSidebarWidth()
        return Tabs.Size.X.Offset
    end

    function Window:SetSidebarWidth(Width)
        Width = math.clamp(Width, 48, MainFrame.Size.X.Offset - WindowInfo.MinContainerWidth - 1)

        DividerLine.Position = UDim2.fromOffset(Width, 0)

        TitleHolder.Size = UDim2.new(0, Width, 1, 0)
        RightWrapper.Size = UDim2.new(1, -Width - 57 - 1, 1, -16)
        Tabs.Size = UDim2.new(0, Width, 1, -70)
        Container.Size = UDim2.new(1, -Width - 1, 1, -70)

        if WindowInfo.EnableCompacting then
            ApplyCompact()
        end
        if not IsCompact then
            LastExpandedWidth = Width
        end
    end

    function Window:ShowTabInfo(Name, Description)
        CurrentTabLabel.Text = Name
        CurrentTabDescription.Text = Description

        if IsDefaultSearchbarSize then
            SearchBox.Size = UDim2.fromScale(0.5, 1)
        end
        CurrentTabInfo.Visible = true
    end

    function Window:HideTabInfo()
        CurrentTabInfo.Visible = false
        if IsDefaultSearchbarSize then
            SearchBox.Size = UDim2.fromScale(1, 1)
        end
    end

    local TabDock = nil
    local TabDockButtons = {}
    local TabDockDrag = {}

    local function RefreshTabDock()
        for DockTab, Entry in pairs(TabDockButtons) do
            local Active = Library.ActiveTab == DockTab

            Library.Registry[Entry.Button] = Library.Registry[Entry.Button] or {}
            Library.Registry[Entry.Button].BackgroundColor3 = Active and "AccentColor" or "MainColor"
            TweenService:Create(Entry.Button, Library.TweenInfo, {
                BackgroundColor3 = Active and Library.Scheme.AccentColor or Library.Scheme.MainColor,
                BackgroundTransparency = Active and 0.15 or (Entry.Hovered and 0.3 or 0.65),
            }):Play()

            Library.Registry[Entry.Stroke] = Library.Registry[Entry.Stroke] or {}
            Library.Registry[Entry.Stroke].Color = "OutlineColor"
            Entry.Stroke.Color = Library.Scheme.OutlineColor
            Entry.Stroke.Transparency = Active and 1 or 0

            if Entry.Icon then
                Library.Registry[Entry.Icon] = Library.Registry[Entry.Icon] or {}
                Library.Registry[Entry.Icon].ImageColor3 = not Entry.Custom and "FontColor" or nil

                TweenService:Create(Entry.Icon, Library.TweenInfo, {
                    ImageTransparency = (Active or Entry.Hovered) and 0 or 0.35,
                    ImageColor3 = Entry.Custom and Color3.new(1, 1, 1) or Library.Scheme.FontColor,
                }):Play()
            end
        end

        Library.RgbDirty = true
    end
    Window.RefreshTabDock = RefreshTabDock

    function Library:SetTabDockVisible(Value)
        Library.TabDockVisible = Value ~= false
        if TabDock then
            TabDock.Visible = Library.TabDockVisible
        end
    end

    function Library:SetTabDockLayout(Mode)
        local Next = Mode == "Horizontal" and "Horizontal" or "Vertical"
        local Changed = Library.TabDockLayout ~= Next and (Library.TabDockLayout ~= nil or Next ~= "Vertical")
        Library.TabDockLayout = Next

        local function Apply()
            if TabDockDrag.List then
                TabDockDrag.List.FillDirection = Next == "Horizontal" and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
            end
            if TabDock then
                TabDock:SetAttribute("DockMoved", nil)
                TabDock:SetAttribute("UserPlaced", nil)
                if TabDockDrag.HugEdge then
                    TabDockDrag.HugEdge()
                end
            end
        end

        local Scale = TabDockDrag.Scale
        if not (Changed and TabDock and TabDock.Visible and Scale and Scale.Parent) then
            Apply()
            return
        end

        TabDockDrag.LayoutId = (TabDockDrag.LayoutId or 0) + 1
        local Id = TabDockDrag.LayoutId
        TabDock:SetAttribute("LayoutAnimating", true)
        local Shrink = TweenService:Create(Scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
        Shrink:Play()
        Shrink.Completed:Once(function()
            if Id ~= TabDockDrag.LayoutId or Library.Unloaded then
                return
            end
            Apply()
            task.defer(function()
                if Id ~= TabDockDrag.LayoutId or Library.Unloaded or not Scale.Parent then
                    return
                end
                if TabDockDrag.HugEdge then
                    TabDockDrag.HugEdge()
                end
                local Grow = TweenService:Create(Scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                    Scale = Library.DPIScale,
                })
                Grow:Play()
                Grow.Completed:Once(function()
                    if Id ~= TabDockDrag.LayoutId or Library.Unloaded or not TabDock.Parent then
                        return
                    end
                    TabDock:SetAttribute("LayoutAnimating", nil)
                    if TabDockDrag.HugEdge then
                        TabDockDrag.HugEdge()
                    end
                end)
            end)
        end)
    end

    local function EnsureTabDock()
        if TabDock then
            return TabDock
        end

        if WindowInfo.TabDock == false then
            return nil
        end

        local Left = WindowInfo.TabDockSide == "Left"

        TabDock = New("Frame", {
            Name = "TabDock",
            ZIndex = 5,
            AnchorPoint = Vector2.new(Left and 0 or 1, 0.5),
            AutomaticSize = Enum.AutomaticSize.XY,
            BackgroundColor3 = "BackgroundColor",
            BackgroundTransparency = 0,
            Position = UDim2.new(Left and 0 or 1, Left and 10 or -10, 0.5, 0),
            Visible = Library.TabDockVisible ~= false,
            Size = UDim2.fromOffset(0, 0),
            Parent = ScreenGui,
        })
        New("UICorner", {
            CornerRadius = UDim.new(0, 10),
            Parent = TabDock,
        })
        Library:AddOutline(TabDock)
        Library:RaiseLayer(TabDock, 20)
        if WindowRecede then
            WindowRecede(function()
                return TabDock
            end)
        end
        pcall(function()
            Library:AddGlow(TabDock)
        end)
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 7),
            PaddingLeft = UDim.new(0, 7),
            PaddingRight = UDim.new(0, 7),
            PaddingTop = UDim.new(0, 7),
            Parent = TabDock,
        })
        TabDockDrag.List = New("UIListLayout", {
            FillDirection = Library.TabDockLayout == "Horizontal" and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = TabDock,
        })

        local DockScale = New("UIScale", {
            Scale = Library.DPIScale,
            Parent = TabDock,
        })
        table.insert(Library.Scales, DockScale)
        TabDockDrag.Scale = DockScale

        do
            local EdgeMargin = Library.IsMobile and 4 or 8
            local function HugEdge()
                local Cam = workspace.CurrentCamera
                if not (Cam and TabDock and TabDock.Parent) then
                    return
                end
                if TabDock:GetAttribute("DockMoved") then
                    if TabDockDrag.Clamp then
                        TabDockDrag.Clamp()
                    end
                    return
                end
                if TabDock:GetAttribute("RecedeHomePosition") ~= nil or TabDock:GetAttribute("UserPlaced") then
                    return
                end
                local View = Cam.ViewportSize
                local GuiPos, GuiSize = ScreenGui.AbsolutePosition, ScreenGui.AbsoluteSize
                local Horizontal = Library.TabDockLayout == "Horizontal"
                local Anchor = Horizontal and Vector2.new(0.5, 0) or Vector2.new(Left and 0 or 1, 0.5)
                if TabDock.AnchorPoint ~= Anchor then
                    TabDock.AnchorPoint = Anchor
                end
                local Target
                if Horizontal then
                    local TopInset = 0
                    if not ScreenGui.IgnoreGuiInset then
                        pcall(function()
                            TopInset = game:GetService("GuiService"):GetGuiInset().Y
                        end)
                    end
                    local DockSize = TabDock.AbsoluteSize
                    local DockScaleNow = TabDockDrag.Scale and TabDockDrag.Scale.Scale or Library.DPIScale
                    if DockScaleNow > 0.05 then
                        DockSize = DockSize / DockScaleNow * Library.DPIScale
                    end
                    local Top = math.max(4 - TopInset, math.floor((TopInset - DockSize.Y) / 2) - TopInset)
                    local Mark = Library.Watermark
                    local MarkFrame = Mark and not Mark.Destroyed and Mark.DraggableLabel and Mark.DraggableLabel.Frame
                    if MarkFrame and MarkFrame.Parent and MarkFrame.Visible then
                        local MarkPos = MarkFrame.AbsolutePosition - GuiPos
                        local MarkSize = MarkFrame.AbsoluteSize
                        local Center = GuiSize.X / 2
                        local OverlapsX = MarkPos.X < Center + DockSize.X / 2 and MarkPos.X + MarkSize.X > Center - DockSize.X / 2
                        local OverlapsY = MarkPos.Y < Top + DockSize.Y and MarkPos.Y + MarkSize.Y > Top
                        if OverlapsX and OverlapsY then
                            Top = MarkPos.Y + MarkSize.Y + 8
                        end
                    end
                    Target = UDim2.new(0.5, 0, 0, Top)
                elseif Left then
                    Target = UDim2.new(0, EdgeMargin - GuiPos.X, 0.5, 0)
                else
                    Target = UDim2.new(1, (View.X - (GuiPos.X + GuiSize.X)) - EdgeMargin, 0.5, 0)
                end
                if TabDock.Position ~= Target then
                    TabDock.Position = Target
                end
            end
            TabDockDrag.HugEdge = HugEdge
            Library:GiveSignal(TabDock:GetPropertyChangedSignal("AbsoluteSize"):Connect(ObsGuard(function()
                if Library.TabDockLayout == "Horizontal" and not TabDock:GetAttribute("LayoutAnimating") then
                    HugEdge()
                end
            end)))
            HugEdge()
            task.defer(HugEdge)
            Library:GiveSignal(ScreenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(ObsGuard(HugEdge)))
            Library:GiveSignal(ScreenGui:GetPropertyChangedSignal("AbsolutePosition"):Connect(ObsGuard(HugEdge)))
            local function WatchCamera()
                local Cam = workspace.CurrentCamera
                if Cam then
                    Library:GiveSignal(Cam:GetPropertyChangedSignal("ViewportSize"):Connect(ObsGuard(HugEdge)))
                end
                HugEdge()
            end
            WatchCamera()
            Library:GiveSignal(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(ObsGuard(WatchCamera)))
            Library:GiveSignal(TabDock:GetAttributeChangedSignal("RecedeHomePosition"):Connect(ObsGuard(function()
                if TabDock:GetAttribute("RecedeHomePosition") == nil then
                    task.delay(0.4, HugEdge)
                end
            end)))
        end

        do
            local function DockPoint()
                local Size = TabDock.AbsoluteSize
                local Anchor = TabDock.AnchorPoint
                local Corner = TabDock.AbsolutePosition - ScreenGui.AbsolutePosition
                return Vector2.new(Corner.X + Size.X * Anchor.X, Corner.Y + Size.Y * Anchor.Y)
            end

            local function ClampPoint(Point, CachedSize, CachedScreen)
                local Screen = CachedScreen or ScreenGui.AbsoluteSize
                local Size = CachedSize or TabDock.AbsoluteSize
                local Anchor = TabDock.AnchorPoint
                local Edge = 8
                local TopInset = 0
                if not ScreenGui.IgnoreGuiInset then
                    pcall(function()
                        TopInset = game:GetService("GuiService"):GetGuiInset().Y
                    end)
                end
                local MinX, MinY = Size.X * Anchor.X + Edge, Size.Y * Anchor.Y + Edge - TopInset
                return Vector2.new(
                    math.clamp(Point.X, MinX, math.max(MinX, Screen.X - Size.X * (1 - Anchor.X) - Edge)),
                    math.clamp(Point.Y, MinY, math.max(MinY, Screen.Y - Size.Y * (1 - Anchor.Y) - Edge))
                )
            end

            TabDockDrag.Clamp = function()
                if TabDockDrag.Active or TabDock:GetAttribute("RecedeHomePosition") ~= nil then
                    return
                end
                local Point = ClampPoint(DockPoint())
                local Target = UDim2.fromOffset(Point.X, Point.Y)
                if TabDock.Position ~= Target then
                    Library:SpringStop(TabDock, "Position")
                    TabDock.Position = Target
                end
            end

            TabDockDrag.Begin = function(Input)
                if TabDockDrag.Active or not IsClickInput(Input) or TabDock:GetAttribute("RecedeHomePosition") ~= nil then
                    return
                end

                TabDockDrag.Active = true
                TabDockDrag.Suppress = false

                local StartInput = Vector2.new(Input.Position.X, Input.Position.Y)
                local StartPoint = DockPoint()
                local Moved = false
                local Moving, Ended

                if not TabDockDrag.Glide then
                    TabDockDrag.Glide = Library:CreateGlide(TabDock, function(Point)
                        local Clamped = ClampPoint(Point, TabDockDrag.CachedSize, TabDockDrag.CachedScreen)
                        TabDock.Position = UDim2.fromOffset(math.round(Clamped.X), math.round(Clamped.Y))
                        return Clamped
                    end, function()
                        if not TabDockDrag.Active and TabDock and TabDock.Parent then
                            TabDock:SetAttribute("Dragging", nil)
                        end
                        if not TabDockDrag.Active and TabDockDrag.RestoreShell then
                            local Restore = TabDockDrag.RestoreShell
                            TabDockDrag.RestoreShell = nil
                            Restore()
                        end
                    end)
                end
                local Glide = TabDockDrag.Glide
                if Glide.Connection then
                    Glide:Stop()
                    StartPoint = DockPoint()
                end

                local function Stop()
                    TabDockDrag.Active = false
                    if Moving then
                        Moving:Disconnect()
                    end
                    if Ended then
                        Ended:Disconnect()
                    end
                    if Moved then
                        Glide:Release()
                    elseif TabDock and TabDock.Parent and not Glide.Connection then
                        TabDock:SetAttribute("Dragging", nil)
                        if TabDockDrag.RestoreShell then
                            local Restore = TabDockDrag.RestoreShell
                            TabDockDrag.RestoreShell = nil
                            Restore()
                        end
                    end
                end

                Moving = UserInputService.InputChanged:Connect(ObsGuard(function(Change)
                    if not IsHoverInput(Change) then
                        return
                    end
                    if not (TabDock and TabDock.Parent and ScreenGui and ScreenGui.Parent) then
                        Stop()
                        return
                    end

                    local Delta = Vector2.new(Change.Position.X, Change.Position.Y) - StartInput

                    if not Moved then
                        if Delta.Magnitude < 6 then
                            return
                        end
                        Moved = true
                        TabDockDrag.Suppress = true
                        TabDock:SetAttribute("Dragging", true)
                        TabDock:SetAttribute("DockMoved", true)
                        if TabDockDrag.Hide then
                            TabDockDrag.Hide()
                        end
                        Library:SpringStop(TabDock, "Position")
                        TabDockDrag.CachedSize = TabDock.AbsoluteSize
                        TabDockDrag.CachedScreen = ScreenGui.AbsoluteSize
                        if not TabDockDrag.RestoreShell then
                            TabDockDrag.RestoreShell = Library:EnterDragShell(TabDock)
                        end
                        Glide:Hold(StartPoint)
                    end

                    Glide:Move(StartPoint + Delta)
                end))

                Ended = Input.Changed:Connect(ObsGuard(function()
                    if Input.UserInputState == Enum.UserInputState.End then
                        Stop()
                    end
                end))
            end

            Library:GiveSignal(TabDock.InputBegan:Connect(ObsGuard(TabDockDrag.Begin)))
        end

        return TabDock
    end

    local DockHint = nil

    local function ShowDockHint(Text, Button)
        if not DockHint then
            DockHint = New("TextLabel", {
                AnchorPoint = Vector2.new(1, 0.5),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = "BackgroundColor",
                Size = UDim2.fromOffset(0, 26),
                Text = "",
                TextSize = 14,
                Visible = false,
                ZIndex = 0,
                Parent = ScreenGui,
            })
            New("UICorner", {
                CornerRadius = UDim.new(0, 7),
                Parent = DockHint,
            })
            Library:AddOutline(DockHint)
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 10),
                PaddingRight = UDim.new(0, 10),
                Parent = DockHint,
            })
        end

        local Left = WindowInfo.TabDockSide == "Left"
        local Horizontal = Library.TabDockLayout == "Horizontal"
        local Origin = ScreenGui.AbsolutePosition
        local ButtonPosition, ButtonSize = Button.AbsolutePosition - Origin, Button.AbsoluteSize
        local X = Left and (ButtonPosition.X + ButtonSize.X + 16) or (ButtonPosition.X - 16)
        local Y = ButtonPosition.Y + ButtonSize.Y / 2
        if Horizontal then
            X = ButtonPosition.X + ButtonSize.X / 2
            Y = ButtonPosition.Y + ButtonSize.Y + 16
        end

        DockHint.AnchorPoint = Horizontal and Vector2.new(0.5, 0) or Vector2.new(Left and 0 or 1, 0.5)
        DockHint.Text = Text
        if not DockHint.Visible then
            Library:SpringStop(DockHint, "Position")
            DockHint.Position = Horizontal and UDim2.fromOffset(X, Y - 8) or UDim2.fromOffset(X + (Left and -8 or 8), Y)
        end
        DockHint.Visible = true
        Library:Spring(DockHint, "Position", UDim2.fromOffset(X, Y), 34, 0.8)
    end

    local function HideDockHint()
        if DockHint then
            DockHint.Visible = false
        end
    end
    TabDockDrag.Hide = HideDockHint

    local function AddTabDockButton(DockTab, Name, Icon, Order)
        if not Icon or not EnsureTabDock() then
            return
        end

        local Count = 0
        for _ in pairs(TabDockButtons) do
            Count += 1
        end

        local DockButton = New("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = "MainColor",
            BackgroundTransparency = 0.65,
            LayoutOrder = Order or Count,
            Size = UDim2.fromOffset(36, 36),
            Text = "",
            Parent = TabDock,
        })
        New("UICorner", {
            CornerRadius = UDim.new(0, 8),
            Parent = DockButton,
        })
        local DockStroke = New("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Color = Library.Scheme.OutlineColor,
            Thickness = 1,
            Parent = DockButton,
        })
        local DockScale = New("UIScale", {
            Parent = DockButton,
        })
        local DockIcon = New("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = Icon.Url,
            ImageColor3 = Icon.Custom and Color3.new(1, 1, 1) or Library.Scheme.FontColor,
            ImageRectOffset = Icon.ImageRectOffset,
            ImageRectSize = Icon.ImageRectSize,
            ImageTransparency = 0.35,
            Position = UDim2.fromScale(0.5, 0.5),
            ScaleType = Enum.ScaleType.Fit,
            Size = UDim2.fromOffset(18, 18),
            Parent = DockButton,
        })

        local Entry = {
            Button = DockButton,
            Icon = DockIcon,
            Stroke = DockStroke,
            Custom = Icon.Custom,
            Hovered = false,
        }
        TabDockButtons[DockTab] = Entry

        DockButton.InputBegan:Connect(ObsGuard(function(Input)
            if TabDockDrag.Begin then
                TabDockDrag.Begin(Input)
            end
        end))
        DockButton.MouseEnter:Connect(ObsGuard(function()
            Entry.Hovered = true
            RefreshTabDock()
            Library:Spring(DockScale, "Scale", 1.12, 34, 0.55)
            if not TabDockDrag.Active or not TabDockDrag.Suppress then
                ShowDockHint(Name, DockButton)
            end
        end))
        DockButton.MouseLeave:Connect(ObsGuard(function()
            Entry.Hovered = false
            RefreshTabDock()
            Library:Spring(DockScale, "Scale", 1, 34, 0.7)
            HideDockHint()
        end))
        DockButton.MouseButton1Down:Connect(ObsGuard(function()
            Library:Spring(DockScale, "Scale", 0.92, 40, 0.7)
        end))
        DockButton.MouseButton1Up:Connect(ObsGuard(function()
            Library:Spring(DockScale, "Scale", Entry.Hovered and 1.12 or 1, 34, 0.55)
        end))
        DockButton.MouseButton1Click:Connect(ObsGuard(function()
            if TabDockDrag.Suppress then
                TabDockDrag.Suppress = false
                return
            end
            if not Library.Toggled then
                Library:Toggle(true)
            end
            DockTab:Show()
            RefreshTabDock()
        end))

        RefreshTabDock()
    end

    function Window:AddTab(...)
        local Name = nil
        local Icon = nil
        local Description = nil
        local Tooltip = nil
        local Order = nil

        if select("#", ...) == 1 and typeof(...) == "table" then
            local Info = select(1, ...)
            Name = Info.Name or "Tab"
            Icon = Info.Icon
            Description = Info.Description
            Tooltip = Info.Tooltip
            Order = Info.Order
        else
            Name = select(1, ...)
            Icon = select(2, ...)
            Description = select(3, ...)
            Order = select(4, ...)
        end

        local TabButton: TextButton
        local TabIndicator
        local TabLabel
        local TabIcon
        local TabSelStroke

        local TabContainer
        local TabLeft
        local TabRight

        Icon = Library:GetCustomIcon(Icon)
        do
            TabButton = New("TextButton", {
                BackgroundColor3 = "MainColor",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 40),
                Text = "",
                LayoutOrder = Order,
                Parent = Tabs,
            })
            New("UICorner", {
                CornerRadius = UDim.new(0, TabButtonsStyle.CornerRadius),
                Parent = TabButton,
            })

            if TabButtonsStyle.Indicator then
                TabIndicator = New("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundColor3 = "AccentColor",
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, -TabButtonsStyle.IndicatorOffset, 0.5, 0),
                    Size = UDim2.fromOffset(TabButtonsStyle.IndicatorWidth, TabButtonsStyle.IndicatorHeight),
                    Parent = TabButton,
                })

                New("UICorner", {
                    CornerRadius = UDim.new(1, 0),
                    Parent = TabIndicator,
                })
            end

            local ButtonHolder = New("Frame", {
                BackgroundTransparency = 1,
                ClipsDescendants = true,
                Size = UDim2.fromScale(1, 1),
                Parent = TabButton,
            })
            local ButtonPadding = New("UIPadding", {
                PaddingBottom = UDim.new(0, IsCompact and 6 or 11),
                PaddingLeft = UDim.new(0, IsCompact and 6 or 12),
                PaddingRight = UDim.new(0, IsCompact and 6 or 12),
                PaddingTop = UDim.new(0, IsCompact and 6 or 11),
                Parent = ButtonHolder,
            })
            TabLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(30, 0),
                Size = UDim2.new(1, -30, 1, 0),
                Text = Name,
                TextSize = 16,
                TextTransparency = 0.5,
                TextXAlignment = Enum.TextXAlignment.Left,
                Visible = not IsCompact,
                Parent = ButtonHolder,
            })

            if Icon then
                TabIcon = New("ImageLabel", {
                    Image = Icon.Url,
                    ImageColor3 = Icon.Custom and "WhiteColor" or "AccentColor",
                    ImageRectOffset = Icon.ImageRectOffset,
                    ImageRectSize = Icon.ImageRectSize,
                    ImageTransparency = 0.5,
                    ScaleType = Enum.ScaleType.Fit,
                    Size = UDim2.fromScale(1, 1),
                    SizeConstraint = IsCompact and Enum.SizeConstraint.RelativeXY or Enum.SizeConstraint.RelativeYY,
                    Parent = ButtonHolder,
                })
            end

            table.insert(Library.TabButtons, {
                Label = TabLabel,
                Padding = ButtonPadding,
                Icon = TabIcon,
            })

            --// Tab Container \\--
            TabContainer = New("Frame", {
                BackgroundTransparency = 1,
                Position = UDim2.fromScale(0, 0),
                Size = UDim2.fromScale(1, 1),
                Visible = false,
                Parent = Container,
            })

            TabLeft = New("ScrollingFrame", {
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                CanvasSize = UDim2.fromScale(0, 0),
                ScrollBarImageTransparency = 1,
                ScrollBarThickness = 0,
                Size = UDim2.new(0.5, -3, 1, 0),
                Parent = TabContainer,
            })
            New("UIListLayout", {
                Padding = UDim.new(0, 2),
                Parent = TabLeft,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 2),
                PaddingLeft = UDim.new(0, 2),
                PaddingRight = UDim.new(0, 2),
                PaddingTop = UDim.new(0, 2),
                Parent = TabLeft,
            })
            do
                New("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = -1,
                    Parent = TabLeft,
                })
                New("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = 1,
                    Parent = TabLeft,
                })
            end

            TabRight = New("ScrollingFrame", {
                AnchorPoint = Vector2.new(1, 0),
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                CanvasSize = UDim2.fromScale(0, 0),
                Position = UDim2.fromScale(1, 0),
                ScrollBarImageTransparency = 1,
                ScrollBarThickness = 0,
                Size = UDim2.new(0.5, -3, 1, 0),
                Parent = TabContainer,
            })
            New("UIListLayout", {
                Padding = UDim.new(0, 2),
                Parent = TabRight,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 2),
                PaddingLeft = UDim.new(0, 2),
                PaddingRight = UDim.new(0, 2),
                PaddingTop = UDim.new(0, 2),
                Parent = TabRight,
            })
            do
                New("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = -1,
                    Parent = TabRight,
                })
                New("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = 1,
                    Parent = TabRight,
                })
            end

            for Index, Side in ipairs({ TabLeft, TabRight }) do
                Library:AddSmoothScroll(Side)
                local Fade = New("Frame", {
                    Active = false,
                    AnchorPoint = Vector2.new(Index - 1, 1),
                    BackgroundColor3 = function()
                        return Library.Scheme.BackgroundColor:Lerp(Color3.new(0, 0, 0), 0.35)
                    end,
                    BorderSizePixel = 0,
                    Position = UDim2.fromScale(Index - 1, 1),
                    Size = UDim2.new(0.5, -3, 0, 46),
                    ZIndex = 8,
                    Parent = TabContainer,
                })
                New("UIGradient", {
                    Rotation = 90,
                    Transparency = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 1),
                        NumberSequenceKeypoint.new(0.55, 0.55),
                        NumberSequenceKeypoint.new(1, 0.05),
                    }),
                    Parent = Fade,
                })
                local function UpdateFade()
                    local Remaining = Side.AbsoluteCanvasSize.Y - (Side.CanvasPosition.Y + Side.AbsoluteWindowSize.Y)
                    Fade.BackgroundTransparency = 1 - math.clamp(Remaining / 40, 0, 1)
                end
                Side:GetPropertyChangedSignal("CanvasPosition"):Connect(ObsGuard(UpdateFade))
                Side:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(ObsGuard(UpdateFade))
                Side:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(ObsGuard(UpdateFade))
                task.defer(UpdateFade)
            end
        end

        --// Tab Table \\--
        local Tab = {
            Name = Name,
            Description = Description,

            Tooltip = Tooltip,
            TooltipTable = nil,

            Connections = {},
            Destroyed = false,

            Window = Window,
            Button = TabButton,
            Container = TabContainer,
            Sides = {
                TabLeft,
                TabRight,
            },
            WarningBox = {
                IsNormal = false,
                LockSize = false,
                Visible = false,
                Title = "WARNING",
                Text = "",
            },

            Groupboxes = {},
            Tabboxes = {},
            DependencyGroupboxes = {},
        }

        --// Warning Box \\--
        local WarningBoxHolder = New("Frame", {
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 7),
            Size = UDim2.fromScale(1, 0),
            Visible = false,
            Parent = TabContainer,
        })

        local WarningBox
        local WarningBoxOutline
        local WarningBoxShadowOutline
        local WarningBoxScrollingFrame
        local WarningTitle
        local WarningStroke
        local WarningText
        do
            WarningBox = New("Frame", {
                BackgroundColor3 = "BackgroundColor",
                Position = UDim2.fromOffset(2, 0),
                Size = UDim2.new(1, -5, 0, 0),
                Parent = WarningBoxHolder,
            })
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                    Parent = WarningBox,
                })
            )
            WarningBoxOutline, WarningBoxShadowOutline = Library:AddOutline(WarningBox)

            WarningBoxScrollingFrame = New("ScrollingFrame", {
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 1),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                ScrollBarThickness = 3,
                ScrollingDirection = Enum.ScrollingDirection.Y,
                Parent = WarningBox,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 4),
                PaddingLeft = UDim.new(0, 6),
                PaddingRight = UDim.new(0, 6),
                PaddingTop = UDim.new(0, 4),
                Parent = WarningBoxScrollingFrame,
            })

            WarningTitle = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, -4, 0, 14),
                Text = "",
                TextColor3 = Color3.fromRGB(255, 50, 50),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = WarningBoxScrollingFrame,
            })

            WarningStroke = New("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                Color = Color3.fromRGB(169, 0, 0),
                LineJoinMode = Enum.LineJoinMode.Miter,
                Parent = WarningTitle,
            })

            WarningText = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(0, 16),
                Size = UDim2.new(1, -4, 0, 0),
                Text = "",
                TextSize = 14,
                TextWrapped = true,
                Parent = WarningBoxScrollingFrame,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
            })

            New("UIStroke", {
                ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                Color = "DarkColor",
                LineJoinMode = Enum.LineJoinMode.Miter,
                Parent = WarningText,
            })
        end

        --// Tab Table \\--

        function Tab:UpdateWarningBox(Info)
            if typeof(Info.IsNormal) == "boolean" then
                Tab.WarningBox.IsNormal = Info.IsNormal
            end
            if typeof(Info.LockSize) == "boolean" then
                Tab.WarningBox.LockSize = Info.LockSize
            end
            if typeof(Info.Visible) == "boolean" then
                Tab.WarningBox.Visible = Info.Visible
            end
            if typeof(Info.Title) == "string" then
                Tab.WarningBox.Title = Info.Title
            end
            if typeof(Info.Text) == "string" then
                Tab.WarningBox.Text = Info.Text
            end

            WarningBoxHolder.Visible = Tab.WarningBox.Visible
            WarningTitle.Text = Tab.WarningBox.Title
            WarningText.Text = Tab.WarningBox.Text
            Tab:Resize(true)

            WarningBox.BackgroundColor3 = Tab.WarningBox.IsNormal == true and Library.Scheme.BackgroundColor
                or Color3.fromRGB(127, 0, 0)

            WarningBoxShadowOutline.Color = Tab.WarningBox.IsNormal == true and Library.Scheme.DarkColor
                or Color3.fromRGB(85, 0, 0)
            WarningBoxOutline.Color = Tab.WarningBox.IsNormal == true and Library.Scheme.OutlineColor
                or Color3.fromRGB(255, 50, 50)

            WarningTitle.TextColor3 = Tab.WarningBox.IsNormal == true and Library.Scheme.FontColor
                or Color3.fromRGB(255, 50, 50)
            WarningStroke.Color = Tab.WarningBox.IsNormal == true and Library.Scheme.OutlineColor
                or Color3.fromRGB(169, 0, 0)

            if not Library.Registry[WarningBox] then
                Library:AddToRegistry(WarningBox, {})
            end
            if not Library.Registry[WarningBoxShadowOutline] then
                Library:AddToRegistry(WarningBoxShadowOutline, {})
            end
            if not Library.Registry[WarningBoxOutline] then
                Library:AddToRegistry(WarningBoxOutline, {})
            end
            if not Library.Registry[WarningTitle] then
                Library:AddToRegistry(WarningTitle, {})
            end
            if not Library.Registry[WarningStroke] then
                Library:AddToRegistry(WarningStroke, {})
            end

            Library.Registry[WarningBox].BackgroundColor3 = function()
                return Tab.WarningBox.IsNormal == true and Library.Scheme.BackgroundColor or Color3.fromRGB(127, 0, 0)
            end

            Library.Registry[WarningBoxShadowOutline].Color = function()
                return Tab.WarningBox.IsNormal == true and Library.Scheme.DarkColor or Color3.fromRGB(85, 0, 0)
            end

            Library.Registry[WarningBoxOutline].Color = function()
                return Tab.WarningBox.IsNormal == true and Library.Scheme.OutlineColor or Color3.fromRGB(255, 50, 50)
            end

            Library.Registry[WarningTitle].TextColor3 = function()
                return Tab.WarningBox.IsNormal == true and Library.Scheme.FontColor or Color3.fromRGB(255, 50, 50)
            end

            Library.Registry[WarningStroke].Color = function()
                return Tab.WarningBox.IsNormal == true and Library.Scheme.OutlineColor or Color3.fromRGB(169, 0, 0)
            end
        end

        function Tab:RefreshSides()
            local Offset = WarningBoxHolder.Visible and WarningBox.Size.Y.Offset + 8 or 0
            for _, Side in Tab.Sides do
                Side.Position = UDim2.new(Side.Position.X.Scale, 0, 0, Offset)
                Side.Size = UDim2.new(0.5, -3, 1, -Offset)
            end
        end

        function Tab:Resize(ResizeWarningBox: boolean?)
            if ResizeWarningBox then
                local MaximumSize = math.floor(TabContainer.AbsoluteSize.Y / 3.25)
                local _, YText = Library:GetTextBounds(
                    WarningText.Text,
                    Library.Scheme.Font,
                    WarningText.TextSize,
                    WarningText.AbsoluteSize.X
                )

                local YBox = 24 + YText
                if Tab.WarningBox.LockSize == true and YBox >= MaximumSize then
                    WarningBoxScrollingFrame.CanvasSize = UDim2.fromOffset(0, YBox)
                    YBox = MaximumSize
                else
                    WarningBoxScrollingFrame.CanvasSize = UDim2.fromOffset(0, 0)
                end

                WarningText.Size = UDim2.new(1, -4, 0, YText)
                WarningBox.Size = UDim2.new(1, -5, 0, YBox + 4)
            end

            Tab:RefreshSides()
        end

        local function AddTabbox(self, Info)
            local ParentObj = self

            local BoxHolder = New("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 0),
                Parent = if ParentObj.Type == "Groupbox" then ParentObj.Container else (Info.Side == 1 and TabLeft or TabRight),
            })
            New("UIListLayout", {
                Padding = UDim.new(0, 6),
                Parent = BoxHolder,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 4),
                Parent = BoxHolder,
            })

            local TabboxHolder
            local TabboxButtons

            do
                TabboxHolder = New("Frame", {
                    BackgroundColor3 = "BackgroundColor",
                    Size = UDim2.fromScale(1, 0),
                    Parent = BoxHolder,
                })
                table.insert(
                    Library.Corners,
                    New("UICorner", {
                        CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                        Parent = TabboxHolder,
                    })
                )
                Library:AddOutline(TabboxHolder)

                TabboxButtons = New("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 34),
                    Parent = TabboxHolder,
                })
                New("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalFlex = Enum.UIFlexAlignment.Fill,
                    Parent = TabboxButtons,
                })
            end

            local TotalTabs = 0
            local FirstTab
            local LastTab

            local Tabbox = {
                Connections = {},
                Destroyed = false,

                ActiveTab = nil,

                BoxHolder = BoxHolder,
                Holder = TabboxHolder,
                Tabs = {}
            }

            function Tabbox:UpdateCorners()
                for _, Tab in Tabbox.Tabs do
                    Tab:UpdateCorners()
                end
            end

            function Tabbox:AddTab(Name, IconName)
                TotalTabs = TotalTabs + 1
                local TabIndex = TotalTabs

                LastTab = TabIndex
                if not FirstTab then
                    FirstTab = TabIndex
                end

                local IsNameEmpty = Name == nil or Trim(tostring(Name)) == ""
                local TabStoringIndex = IsNameEmpty and tostring(TabIndex) or Name

                local Button = New("TextButton", {
                    BackgroundColor3 = "MainColor",
                    BackgroundTransparency = 0,
                    Size = UDim2.fromOffset(0, 34),
                    Text = "",
                    Parent = TabboxButtons,
                })

                local ButtonCorner = New("UICorner", {
                    TopLeftRadius = UDim.new(0, WindowInfo.CornerRadius),
                    TopRightRadius = UDim.new(0, WindowInfo.CornerRadius),
                    BottomRightRadius = UDim.new(0, 0),
                    BottomLeftRadius = UDim.new(0, 0),
                    Parent = Button,
                }); table.insert(Library.SpecificCorners, ButtonCorner)

                local ButtonContent = New("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundTransparency = 1,
                    Position = UDim2.fromScale(0.5, 0.5),
                    Size = UDim2.fromOffset(0, 16),
                    Parent = Button,
                })
                New("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDim.new(0, 8),
                    Parent = ButtonContent,
                })

                local ButtonIcon                
                local BoxIcon = Library:GetCustomIcon(IconName)
                if BoxIcon then
                    ButtonIcon = New("ImageLabel", {
                        Image = BoxIcon.Url,
                        ImageColor3 = BoxIcon.Custom and "WhiteColor" or "AccentColor",
                        ImageRectOffset = BoxIcon.ImageRectOffset,
                        ImageRectSize = BoxIcon.ImageRectSize,
                        ImageTransparency = 0.5,
                        Size = IsNameEmpty and UDim2.fromOffset(16, 16) or UDim2.fromOffset(18, 18),
                        Parent = ButtonContent,
                    })
                end

                local ButtonLabel
                if not IsNameEmpty then
                    ButtonLabel = New("TextLabel", {
                        AutomaticSize = Enum.AutomaticSize.X,
                        BackgroundTransparency = 1,
                        Size = UDim2.fromOffset(0, 16),
                        Text = Name,
                        TextSize = 15,
                        TextTransparency = 0.5,
                        Parent = ButtonContent,
                    })
                end

                local Line = Library:MakeLine(Button, {
                    AnchorPoint = Vector2.new(0, 1),
                    Position = UDim2.new(0, 0, 1, 1),
                    Size = UDim2.new(1, 0, 0, 1),
                })

                local Container = New("Frame", {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(0, 35),
                    Size = UDim2.new(1, 0, 1, -35),
                    Visible = false,
                    Parent = TabboxHolder,
                })
                local List = New("UIListLayout", {
                    Padding = UDim.new(0, 8),
                    Parent = Container,
                })
                New("UIPadding", {
                    PaddingBottom = UDim.new(0, 7),
                    PaddingLeft = UDim.new(0, 7),
                    PaddingRight = UDim.new(0, 7),
                    PaddingTop = UDim.new(0, 7),
                    Parent = Container,
                })

                local Tab = {
                    Connections = {},
                    Destroyed = false,

                    ButtonHolder = Button,
                    Container = Container,
                    ButtonCorner = ButtonCorner,

                    Tab = Tab,
                    Tabbox = Tabbox,

                    Elements = {},
                    DependencyBoxes = {},
                }

                local LabelGradient = nil
                Tab.Index = TabIndex

                local function Fade(Object, Goal, Animate)
                    if Animate then
                        TweenService:Create(Object, Library.TweenInfo, Goal):Play()
                    else
                        for Property, Value in Goal do
                            Object[Property] = Value
                        end
                    end
                end

                function Tab:Show()
                    Library:RefreshGradVisibility()
                    local Previous = Tabbox.ActiveTab
                    if Previous == Tab then
                        return
                    end
                    if CurrentMenu then
                        pcall(function()
                            CurrentMenu:Close()
                        end)
                    end
                    if Previous then
                        Previous:Hide()
                    end

                    local Animate = Previous ~= nil and Library.Toggled

                    Fade(Button, { BackgroundTransparency = 1 }, Animate)

                    if ButtonLabel then
                        Library.Registry[ButtonLabel] = Library.Registry[ButtonLabel] or {}
                        Library.Registry[ButtonLabel].TextColor3 = nil
                        ButtonLabel.TextColor3 = Color3.new(1, 1, 1)
                        if LabelGradient and LabelGradient.Parent == ButtonLabel then
                            LabelGradient.Enabled = true
                        else
                            pcall(function()
                                local Entry = Library:AddSharedGradient(ButtonLabel, { isRgb = false })
                                LabelGradient = Entry and Entry.gradient or nil
                            end)
                        end
                        Fade(ButtonLabel, { TextTransparency = 0 }, Animate)
                    end
                    if ButtonIcon then
                        Fade(ButtonIcon, { ImageTransparency = 0 }, Animate)
                    end

                    Line.Visible = true
                    Fade(Line, { BackgroundTransparency = 1 }, Animate)

                    Container.Visible = true
                    if Animate then
                        local Direction = (Tab.Index or 0) >= (Previous.Index or 0) and 1 or -1
                        Library:SpringStop(Container, "Position")
                        Container.Position = UDim2.fromOffset(18 * Direction, 35)
                        Library:Spring(Container, "Position", UDim2.fromOffset(0, 35), 26, 0.86)
                    else
                        Library:SpringStop(Container, "Position")
                        Container.Position = UDim2.fromOffset(0, 35)
                    end

                    Tabbox.ActiveTab = Tab
                    Tab:Resize()
                end

                function Tab:Hide()
                    local Animate = Library.Toggled

                    Fade(Button, { BackgroundTransparency = 0 }, Animate)

                    if ButtonLabel then
                        if LabelGradient then
                            LabelGradient.Enabled = false
                        end
                        Library.Registry[ButtonLabel] = Library.Registry[ButtonLabel] or {}
                        Library.Registry[ButtonLabel].TextColor3 = "FontColor"
                        ButtonLabel.TextColor3 = Library.Scheme.FontColor
                        Fade(ButtonLabel, { TextTransparency = 0.5 }, Animate)
                    end
                    if ButtonIcon then
                        Fade(ButtonIcon, { ImageTransparency = 0.5 }, Animate)
                    end
                    Line.Visible = true
                    Fade(Line, { BackgroundTransparency = 0 }, Animate)
                    Library:SpringStop(Container, "Position")
                    Container.Position = UDim2.fromOffset(0, 35)
                    Container.Visible = false

                    Tabbox.ActiveTab = nil
                end

                function Tab:Resize()
                    if Tabbox.ActiveTab ~= Tab then
                        return
                    end

                    TabboxHolder.Size = UDim2.new(1, 0, 0, (List.AbsoluteContentSize.Y / Library.DPIScale) + 49)
                    if ParentObj.Type == "Groupbox" then
                        ParentObj:Resize()
                    end
                end

                function Tab:UpdateCorners()
                    local Radius = WindowInfo.CornerRadius

                    ButtonCorner.TopLeftRadius = UDim.new(0, TabIndex == FirstTab and Radius or 0)
                    ButtonCorner.TopRightRadius = UDim.new(0, TabIndex == LastTab and Radius or 0)
                end

                function Tab:Destroy()
                    Tab.Destroyed = true

                    if Tab.Connections then
                        for _, Connection in Tab.Connections do
                            Connection:Disconnect()
                        end
                    end

                    for _, Element in table.clone(Tab.Elements) do
                        if Element.Destroy then
                            Element:Destroy()
                        end
                    end

                    for _, SubDepbox in table.clone(Tab.DependencyBoxes) do
                        if SubDepbox.Destroy then
                            SubDepbox:Destroy()
                        end
                    end

                    if Container then
                        Container:Destroy()
                    end

                    if Button then
                        Button:Destroy()
                    end
                end

                --// Execution \\--
                if not Tabbox.ActiveTab then
                    Tab:Show()
                end

                Button.MouseButton1Click:Connect(ObsGuard(Tab.Show))

                setmetatable(Tab, BaseGroupbox)

                Tabbox.Tabs[TabStoringIndex] = Tab
                Tabbox:UpdateCorners()

                return Tab, TabStoringIndex
            end

            function Tabbox:Destroy()
                Tabbox.Destroyed = true

                if Tabbox.Connections then
                    for _, Connection in Tabbox.Connections do
                        Connection:Disconnect()
                    end
                end

                for _, Tab in Tabbox.Tabs do
                    if Tab.Destroy then
                        Tab:Destroy()
                    end
                end

                if TabboxHolder then
                    TabboxHolder:Destroy()
                end

                if BoxHolder then
                    BoxHolder:Destroy()
                end
            end

            if Info.Name then
                Tab.Tabboxes[Info.Name] = Tabbox
            else
                table.insert(Tab.Tabboxes, Tabbox)
            end

            return Tabbox
        end

        Tab.AddTabbox = AddTabbox

        function Tab:AddLeftTabbox(Name)
            return Tab:AddTabbox({ Side = 1, Name = Name })
        end

        function Tab:AddRightTabbox(Name)
            return Tab:AddTabbox({ Side = 2, Name = Name })
        end

        function Tab:AddGroupbox(Info)
            local BoxHolder = New("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 0),
                Parent = Info.Side == 1 and TabLeft or TabRight,
            })
            New("UIListLayout", {
                Padding = UDim.new(0, 6),
                Parent = BoxHolder,
            })
            New("UIPadding", {
                PaddingBottom = UDim.new(0, 4),
                PaddingTop = UDim.new(0, 4),
                Parent = BoxHolder,
            })

            local GroupboxHolder
            local GroupboxLabel

            local GroupboxContainer
            local GroupboxList

            local GroupboxCollapseArrow
            local GroupboxLine
            local GroupboxTop
            local GroupboxPopOutButton

            do
                GroupboxHolder = New("Frame", {
                    BackgroundColor3 = "BackgroundColor",
                    Size = UDim2.fromScale(1, 0),
                    Parent = BoxHolder,
                })
                table.insert(
                    Library.Corners,
                    New("UICorner", {
                        CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                        Parent = GroupboxHolder,
                    })
                )
                Library:AddOutline(GroupboxHolder)

                GroupboxLine = Library:MakeLine(GroupboxHolder, {
                    Position = UDim2.fromOffset(0, 34),
                    Size = UDim2.new(1, 0, 0, 1),
                })

                GroupboxTop = New("Frame", {
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 34),
                    Parent = GroupboxHolder,
                })

                local BoxIcon = Library:GetCustomIcon(Info.IconName)
                if BoxIcon then
                    New("ImageLabel", {
                        Image = BoxIcon.Url,
                        ImageColor3 = BoxIcon.Custom and "WhiteColor" or "AccentColor",
                        ImageRectOffset = BoxIcon.ImageRectOffset,
                        ImageRectSize = BoxIcon.ImageRectSize,
                        Position = UDim2.fromOffset(6, 6),
                        Size = UDim2.fromOffset(22, 22),
                        Parent = GroupboxHolder,
                    })
                end

                GroupboxLabel = New("TextLabel", {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(BoxIcon and 24 or 0, 0),
                    Size = UDim2.new(1, 0, 0, 34),
                    Text = Info.Name,
                    TextSize = 15,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = GroupboxHolder,
                })
                New("UIPadding", {
                    PaddingLeft = UDim.new(0, 12),
                    PaddingRight = UDim.new(0, 12),
                    Parent = GroupboxLabel,
                })

                if Info.PopOut == true or (Info.PopOut ~= false and Library.GroupboxPopOut == true) then
                    GroupboxPopOutButton = New("ImageButton", {
                        Image = PopOutIcon and PopOutIcon.Url or "",
                        ImageColor3 = "WhiteColor",
                        ImageRectOffset = PopOutIcon and PopOutIcon.ImageRectOffset or Vector2.zero,
                        ImageRectSize = PopOutIcon and PopOutIcon.ImageRectSize or Vector2.zero,
                        ImageTransparency = 0.5,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(1, -(22 + 6 + 22 + 2), 0, 6),
                        Size = UDim2.fromOffset(22, 22),
                        Parent = GroupboxHolder,
                    })
                end

                if Info.DisableCollapsing ~= true then
                    GroupboxCollapseArrow = New("ImageButton", {
                        Image = ArrowIcon and ArrowIcon.Url or "",
                        ImageColor3 = "WhiteColor",
                        ImageRectOffset = ArrowIcon and ArrowIcon.ImageRectOffset or Vector2.zero,
                        ImageRectSize = ArrowIcon and ArrowIcon.ImageRectSize or Vector2.zero,
                        BackgroundTransparency = 1,
                        Rotation = 180,
                        Position = UDim2.new(1, -(22 + 6), 0, 6),
                        Size = UDim2.fromOffset(22, 22),
                        Parent = GroupboxHolder,
                    })
                end

                GroupboxContainer = New("Frame", {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(0, 35),
                    Size = UDim2.new(1, 0, 1, -35),
                    Parent = GroupboxHolder,
                })

                GroupboxList = New("UIListLayout", {
                    Padding = UDim.new(0, 8),
                    Parent = GroupboxContainer,
                })
                New("UIPadding", {
                    PaddingBottom = UDim.new(0, 7),
                    PaddingLeft = UDim.new(0, 7),
                    PaddingRight = UDim.new(0, 7),
                    PaddingTop = UDim.new(0, 7),
                    Parent = GroupboxContainer,
                })
            end

            local Groupbox = {
                Type = "Groupbox",

                Connections = {},
                Destroyed = false,

                Visible = true,
                Collapsed = false,

                BoxHolder = BoxHolder,
                Holder = GroupboxHolder,
                Container = GroupboxContainer,

                Tab = Tab,
                DependencyBoxes = {},
                Elements = {}
            }

            local ResizeTween
            local CollapseArrowTween

            function Groupbox:Resize()
                if ResizeTween then
                    StopTween(ResizeTween, true)
                    ResizeTween = nil
                end

                local BodySize = (GroupboxList.AbsoluteContentSize.Y / Library.DPIScale) + 49
                if Groupbox.PoppedOut then
                    BodySize = math.min(BodySize, GetPopOutBodyMaxHeight(Groupbox, 35))
                end

                local TargetSize = UDim2.new(1, 0, 0, if Groupbox.Collapsed then 34 else BodySize)

                GroupboxLine.Visible = not Groupbox.Collapsed
                if Library.Animations and Library.Animations.Groupbox and Library.Toggled and TabContainer.Visible and GroupboxHolder.Size ~= TargetSize then
                    local TweenInfo = Library.GroupboxTweenInfo or TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    local Tween = TweenService:Create(GroupboxHolder, TweenInfo, { Size = TargetSize })
                    ResizeTween = Tween

                    Tween.Completed:Once(ObsGuard(function()
                        if ResizeTween == Tween then
                            StopTween(ResizeTween, true)
                            ResizeTween = nil
                        end
                    end))

                    Tween:Play()
                else
                    GroupboxHolder.Size = TargetSize
                end
            end

            function Groupbox:SetCollapsed(Collapsed: boolean)
                if Info.DisableCollapsing == true then return end
                Groupbox.Collapsed = Collapsed

                if CollapseArrowTween then
                    StopTween(CollapseArrowTween, true)
                    CollapseArrowTween = nil
                end

                local TargetRotation = if Collapsed then 0 else 180

                GroupboxContainer.Visible = not Collapsed
                if Library.Animations and Library.Animations.Groupbox then
                    local TweenInfo = Library.GroupboxTweenInfo or TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
                    local Tween = TweenService:Create(GroupboxCollapseArrow, TweenInfo, { Rotation = TargetRotation })
                    CollapseArrowTween = Tween

                    Tween.Completed:Once(ObsGuard(function()
                        if CollapseArrowTween == Tween then
                            StopTween(CollapseArrowTween, true)
                            CollapseArrowTween = nil
                        end
                    end))

                    Tween:Play()
                else
                    GroupboxCollapseArrow.Rotation = TargetRotation
                end

                Groupbox:Resize()
            end

            function Groupbox:ToggleCollapsed()
                if Info.DisableCollapsing == true then return end
                Groupbox:SetCollapsed(not Groupbox.Collapsed)
            end

            Library:MakeBoxPopOut(Groupbox, {
                Enabled = Info.PopOut == true or (Info.PopOut ~= false and Library.GroupboxPopOut == true),

                Header = GroupboxTop,
                Children = function()
                    local Children = {}
                    for _, Child in BoxHolder:GetChildren() do
                        if Child:IsA("GuiObject") and Child ~= Groupbox.PopOutPlaceholder then
                            table.insert(Children, Child)
                        end
                    end
                    return Children
                end,

                Before = function()
                    if GroupboxCollapseArrow then
                        GroupboxCollapseArrow.Visible = false
                    end
                end,
                After = function()
                    if GroupboxCollapseArrow then
                        GroupboxCollapseArrow.Visible = Info.DisableCollapsing ~= true
                    end
                    Groupbox:Resize()
                end,
            })

            function Groupbox:Destroy()
                if Groupbox.PoppedOut then
                    Groupbox:SetPoppedOut(false)
                end

                Groupbox.Destroyed = true

                if ResizeTween then
                    StopTween(ResizeTween, true)
                    ResizeTween = nil
                end

                if CollapseArrowTween then
                    StopTween(CollapseArrowTween, true)
                    CollapseArrowTween = nil
                end

                if Groupbox.Connections then
                    for _, Connection in Groupbox.Connections do
                        Connection:Disconnect()
                    end
                end

                for _, Element in table.clone(Groupbox.Elements) do
                    if Element.Destroy then
                        Element:Destroy()
                    end
                end
                table.clear(Groupbox.Elements)

                for _, SubDepbox in table.clone(Groupbox.DependencyBoxes) do
                    if SubDepbox.Destroy then
                        SubDepbox:Destroy()
                    end
                end
                table.clear(Groupbox.DependencyBoxes)

                if GroupboxHolder then 
                    GroupboxHolder:Destroy() 
                end

                if BoxHolder then
                    BoxHolder:Destroy()
                end
            end

            function Groupbox:SetVisible(Visible: boolean)
                Groupbox.Visible = Visible
                BoxHolder.Visible = Visible

                if Visible == true and Library.Searching then
                    Library:UpdateSearch(Library.SearchText)
                end
            end

            function Groupbox:Show()
                Groupbox:SetVisible(true) 
            end

            function Groupbox:Hide()
                Groupbox:SetVisible(false) 
            end

            if Info.DisableCollapsing ~= true then
                GroupboxCollapseArrow.MouseButton1Click:Connect(ObsGuard(function()
                    Groupbox:ToggleCollapsed()
                end))
            end

            if GroupboxPopOutButton then
                -- Upstream only offers a hold-and-drag gesture, which collides
                -- with the collapse chevron and is not discoverable.
                GroupboxPopOutButton.MouseButton1Click:Connect(ObsGuard(function()
                    if Groupbox.PoppedOut then
                        Groupbox:SetPoppedOut(false)
                        return
                    end

                    -- Drop it near the box it came from. The position argument
                    -- alone does not stick, so place the float afterwards too.
                    local Origin = GroupboxHolder.AbsolutePosition
                    local Target = UDim2.fromOffset(Origin.X + 24, Origin.Y + 24)

                    Groupbox:SetPoppedOut(true, Target)

                    if Groupbox.PopOutFloat then
                        Groupbox.PopOutFloat.Position = Target
                    end
                end))

                GroupboxPopOutButton.MouseEnter:Connect(ObsGuard(function()
                    GroupboxPopOutButton.ImageTransparency = 0
                end))
                GroupboxPopOutButton.MouseLeave:Connect(ObsGuard(function()
                    GroupboxPopOutButton.ImageTransparency = 0.5
                end))
            end

            Groupbox.AddTabbox = AddTabbox
            setmetatable(Groupbox, BaseGroupbox)

            Groupbox:Resize()
            Tab.Groupboxes[Info.Name] = Groupbox

            if Info.Visible == false then
                Groupbox:Hide()
            end

            if Info.DisableCollapsing ~= true and Info.Collapsed == true then
                Groupbox:SetCollapsed(true)
            end

            return Groupbox
        end

        function Tab:AddLeftGroupbox(Name, IconName, Visible, Collapsed, DisableCollapsing)
            return Tab:AddGroupbox({ Side = 1, Name = Name, IconName = IconName, Visible = Visible, Collapsed = Collapsed, DisableCollapsing = DisableCollapsing })
        end

        function Tab:AddRightGroupbox(Name, IconName, Visible, Collapsed, DisableCollapsing)
            return Tab:AddGroupbox({ Side = 2, Name = Name, IconName = IconName, Visible = Visible, Collapsed = Collapsed, DisableCollapsing = DisableCollapsing })
        end

        function Tab:Hover(Hovering)
            if Library.ActiveTab == Tab then
                return
            end

            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = Hovering and 0.25 or 0.5,
            }):Play()
            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = Hovering and 0.25 or 0.5,
                }):Play()
            end
        end

        function Tab:Show()
            Library:RefreshGradVisibility()
            if Library.ActiveTab == Tab then
                return
            end

            if CurrentMenu then
                pcall(function()
                    CurrentMenu:Close()
                end)
            end

            if Library.ActiveTab then
                Library.ActiveTab:Hide()
                Library:PlayTabSound()
            end

            TweenService:Create(TabButton, Library.TweenInfo, {
                BackgroundTransparency = TabButtonsStyle.SelectedTransparency,
            }):Play()
            if TabIndicator then
                TweenService:Create(TabIndicator, Library.TweenInfo, {
                    BackgroundTransparency = 0,
                }):Play()
            end
            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = 0,
            }):Play()
            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = 0,
                }):Play()
            end

            if Description then
                Window:ShowTabInfo(Name, Description)
            end

            Library:PlayTabAnimation(Tab, true)
            Tab:RefreshSides()

            Library.ActiveTab = Tab
            RefreshTabDock()

            if Library.Searching then
                Library:UpdateSearch(Library.SearchText)
            end
        end

        function Tab:Hide()
            TweenService:Create(TabButton, Library.TweenInfo, {
                BackgroundTransparency = 1,
            }):Play()

            if TabIndicator then
                TweenService:Create(TabIndicator, Library.TweenInfo, {
                    BackgroundTransparency = 1,
                }):Play()
            end

            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = 0.5,
            }):Play()

            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = 0.5,
                }):Play()
            end

            Library:PlayTabAnimation(Tab, false)
            Window:HideTabInfo()

            Library.PreviousTab = Tab
            Library.ActiveTab = nil
            RefreshTabDock()
        end

        function Tab:SetVisible(Visible: boolean)
            TabButton.Visible = Visible
            if TabDockButtons[Tab] then
                TabDockButtons[Tab].Button.Visible = Visible
            end

            if not Visible and Library.ActiveTab == Tab then
                Tab:Hide()
            end
        end

        function Tab:SetOrder(Order: number)
            TabButton.LayoutOrder = Order
            if TabDockButtons[Tab] then
                TabDockButtons[Tab].Button.LayoutOrder = Order
            end
        end

        function Tab:SetTooltip(Text: string?)
            Tab.Tooltip = Text

            if Tab.TooltipTable then
                Tab.TooltipTable:Destroy()
                Tab.TooltipTable = nil
            end

            if typeof(Text) == "string" then
                Tab.TooltipTable = Library:AddTooltip(Text, nil, TabButton)
            end
        end

        function Tab:Destroy()
            Tab.Destroyed = true

            if Tab.Connections then
                for _, Connection in Tab.Connections do
                    Connection:Disconnect()
                end
            end

            if Tab.TooltipTable then
                Tab.TooltipTable:Destroy()
                Tab.TooltipTable = nil
            end

            for _, Groupbox in table.clone(Tab.Groupboxes) do
                if Groupbox.Destroy then
                    Groupbox:Destroy()
                end
            end
            table.clear(Tab.Groupboxes)

            for _, Tabbox in table.clone(Tab.Tabboxes) do
                if Tabbox.Destroy then
                    Tabbox:Destroy()
                end
            end
            table.clear(Tab.Tabboxes)

            for _, DepGroupbox in table.clone(Tab.DependencyGroupboxes) do
                if DepGroupbox.Destroy then
                    DepGroupbox:Destroy()
                end
            end

            if TabContainer then
                TabContainer:Destroy()
            end

            if TabButton then
                for Index, Entry in Library.TabButtons do
                    if typeof(Entry) == "table" and Entry.Button == TabButton then
                        table.remove(Library.TabButtons, Index)
                        break
                    end
                end
                
                TabButton:Destroy()
            end
            
            if TabDockButtons[Tab] then
                TabDockButtons[Tab].Button:Destroy()
                TabDockButtons[Tab] = nil
            end

            Library.Tabs[Name] = nil
        end

        --// Execution \\--
        if typeof(Tooltip) == "string" then
            Tab.TooltipTable = Library:AddTooltip(Tooltip, nil, TabButton)
        end

        if not Library.ActiveTab then
            Tab:Show()
        end

        TabButton.MouseEnter:Connect(ObsGuard(function()
            if Library:MouseIsOverMenu() then
                return
            end
            Tab:Hover(true)
        end))
        TabButton.MouseLeave:Connect(ObsGuard(function()
            Tab:Hover(false)
        end))
        TabButton.MouseButton1Click:Connect(ObsGuard(function()
            Tab.Show()
        end))

        Library.Tabs[Name] = Tab
        AddTabDockButton(Tab, Name, Icon, Order)

        return Tab
    end

    function Window:AddKeyTab(...)
        local Name = nil
        local Icon = nil
        local Description = nil
        local Tooltip = nil
        local Order = nil

        if select("#", ...) == 1 and typeof(...) == "table" then
            local Info = select(1, ...)
            Name = Info.Name or "Tab"
            Icon = Info.Icon
            Description = Info.Description
            Tooltip = Info.Tooltip
            Order = Info.Order
        else
            Name = select(1, ...) or "Tab"
            Icon = select(2, ...)
            Description = select(3, ...)
        end

        Icon = Icon or "key"

        local TabButton: TextButton
        local TabIndicator
        local TabLabel
        local TabIcon
        local TabSelStroke

        local TabContainer

        Icon = if Icon == "key" then KeyIcon else Library:GetCustomIcon(Icon)
        do
            TabButton = New("TextButton", {
                BackgroundColor3 = "MainColor",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 40),
                Text = "",
                Parent = Tabs,
            })
            New("UICorner", {
                CornerRadius = UDim.new(0, TabButtonsStyle.CornerRadius),
                Parent = TabButton,
            })

            if TabButtonsStyle.Indicator then
                TabIndicator = New("Frame", {
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundColor3 = "AccentColor",
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, -TabButtonsStyle.IndicatorOffset, 0.5, 0),
                    Size = UDim2.fromOffset(TabButtonsStyle.IndicatorWidth, TabButtonsStyle.IndicatorHeight),
                    Parent = TabButton,
                })

                New("UICorner", {
                    CornerRadius = UDim.new(1, 0),
                    Parent = TabIndicator,
                })
            end

            local ButtonHolder = New("Frame", {
                BackgroundTransparency = 1,
                ClipsDescendants = true,
                Size = UDim2.fromScale(1, 1),
                Parent = TabButton,
            })
            local ButtonPadding = New("UIPadding", {
                PaddingBottom = UDim.new(0, IsCompact and 6 or 11),
                PaddingLeft = UDim.new(0, IsCompact and 6 or 12),
                PaddingRight = UDim.new(0, IsCompact and 6 or 12),
                PaddingTop = UDim.new(0, IsCompact and 6 or 11),
                Parent = ButtonHolder,
            })

            TabLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(30, 0),
                Size = UDim2.new(1, -30, 1, 0),
                Text = Name,
                TextSize = 16,
                TextTransparency = 0.5,
                TextXAlignment = Enum.TextXAlignment.Left,
                Visible = not IsCompact,
                Parent = ButtonHolder,
            })

            if Icon then
                TabIcon = New("ImageLabel", {
                    Image = Icon.Url,
                    ImageColor3 = Icon.Custom and "WhiteColor" or "AccentColor",
                    ImageRectOffset = Icon.ImageRectOffset,
                    ImageRectSize = Icon.ImageRectSize,
                    ImageTransparency = 0.5,
                    ScaleType = Enum.ScaleType.Fit,
                    Size = UDim2.fromScale(1, 1),
                    SizeConstraint = IsCompact and Enum.SizeConstraint.RelativeXY or Enum.SizeConstraint.RelativeYY,
                    Parent = ButtonHolder,
                })
            end

            table.insert(Library.TabButtons, {
                Label = TabLabel,
                Padding = ButtonPadding,
                Icon = TabIcon,
            })

            --// Tab Container \\--
            TabContainer = New("ScrollingFrame", {
                AutomaticCanvasSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                CanvasSize = UDim2.fromScale(0, 0),
                ScrollBarThickness = 0,
                Position = UDim2.fromScale(0, 0),
                Size = UDim2.fromScale(1, 1),
                Visible = false,
                Parent = Container,
            })
            New("UIListLayout", {
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                Padding = UDim.new(0, 8),
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Parent = TabContainer,
            })
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 1),
                PaddingRight = UDim.new(0, 1),
                Parent = TabContainer,
            })
        end

        --// Tab Table \\--
        local Tab = {
            Description = Description,
            IsKeyTab = true,

            Tooltip = Tooltip,
            TooltipTable = nil,

            Elements = {},

            Window = Window,
            Button = TabButton,
            Container = TabContainer
        }

        function Tab:AddKeyBox(Callback)
            assert(typeof(Callback) == "function", "Callback must be a function")

            local Holder = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(0.75, 0, 0, 21),
                Parent = TabContainer,
            })

            local Box = New("TextBox", {
                BackgroundColor3 = "MainColor",
                PlaceholderText = "Key",
                Size = UDim2.new(1, -71, 1, 0),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = Holder,
            })
            New("UIPadding", {
                PaddingLeft = UDim.new(0, 8),
                PaddingRight = UDim.new(0, 8),
                Parent = Box,
            })
            local BoxStroke = New("UIStroke", {
                Color = "OutlineColor",
                Parent = Box,
            })
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Box,
                })
            )

            Box.Focused:Connect(ObsGuard(function()
                Library.Registry[BoxStroke].Color = "AccentColor"
                TweenService:Create(BoxStroke, Library.TweenInfo, {
                    Color = Library.Scheme.AccentColor,
                }):Play()
            end))

            Box.FocusLost:Connect(ObsGuard(function()
                Library.Registry[BoxStroke].Color = "OutlineColor"
                TweenService:Create(BoxStroke, Library.TweenInfo, {
                    Color = Library.Scheme.OutlineColor,
                }):Play()
            end))

            local Button = New("TextButton", {
                AnchorPoint = Vector2.new(1, 0),
                BackgroundColor3 = "MainColor",
                Position = UDim2.fromScale(1, 0),
                Size = UDim2.new(0, 63, 1, 0),
                Text = "Execute",
                TextSize = 14,
                TextTransparency = 0.4,
                Parent = Holder,
            })
            New("UIStroke", {
                Color = "OutlineColor",
                Parent = Button,
            })
            table.insert(
                Library.Corners,
                New("UICorner", {
                    CornerRadius = UDim.new(0, Library.CornerRadius / 2),
                    Parent = Button,
                })
            )

            Button.MouseEnter:Connect(ObsGuard(function()
                TweenService:Create(Button, Library.TweenInfo, {
                    TextTransparency = 0,
                }):Play()
            end))

            Button.MouseLeave:Connect(ObsGuard(function()
                TweenService:Create(Button, Library.TweenInfo, {
                    TextTransparency = 0.4,
                }):Play()
            end))

            Button.InputBegan:Connect(ObsGuard(function(Input)
                if not IsClickInput(Input) then
                    return
                end

                if not Library:MouseIsOverFrame(Button, Input.Position) then
                    return
                end

                Callback(Box.Text)
            end))
        end
        
        function Tab:Destroy()
            if TabContainer then
                TabContainer:Destroy()
            end

            if TabButton then
                for Index, Entry in Library.TabButtons do
                    if typeof(Entry) == "table" and Entry.Button == TabButton then
                        table.remove(Library.TabButtons, Index)
                        break
                    end
                end
                
                TabButton:Destroy()
            end
            
            Library.Tabs[Name] = nil
        end

        function Tab:RefreshSides() end
        function Tab:Resize() end
        function Tab:UpdateCorners() end

        function Tab:Hover(Hovering)
            if Library.ActiveTab == Tab then
                return
            end

            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = Hovering and 0.25 or 0.5,
            }):Play()
            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = Hovering and 0.25 or 0.5,
                }):Play()
            end
        end

        function Tab:Show()
            Library:RefreshGradVisibility()
            if Library.ActiveTab == Tab then
                return
            end

            if CurrentMenu then
                pcall(function()
                    CurrentMenu:Close()
                end)
            end

            if Library.ActiveTab then
                Library.ActiveTab:Hide()
                Library:PlayTabSound()
            end

            TweenService:Create(TabButton, Library.TweenInfo, {
                BackgroundTransparency = TabButtonsStyle.SelectedTransparency,
            }):Play()

            if TabIndicator then
                TweenService:Create(TabIndicator, Library.TweenInfo, {
                    BackgroundTransparency = 0,
                }):Play()
            end

            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = 0,
            }):Play()

            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = 0,
                }):Play()
            end

            Library:PlayTabAnimation(Tab, true)

            if Description then
                Window:ShowTabInfo(Name, Description)
            end

            Tab:RefreshSides()

            Library.ActiveTab = Tab

            if Library.Searching then
                Library:UpdateSearch(Library.SearchText)
            end
        end

        function Tab:Hide()
            TweenService:Create(TabButton, Library.TweenInfo, {
                BackgroundTransparency = 1,
            }):Play()

            if TabIndicator then
                TweenService:Create(TabIndicator, Library.TweenInfo, {
                    BackgroundTransparency = 1,
                }):Play()
            end

            TweenService:Create(TabLabel, Library.TweenInfo, {
                TextTransparency = 0.5,
            }):Play()

            if TabIcon then
                TweenService:Create(TabIcon, Library.TweenInfo, {
                    ImageTransparency = 0.5,
                }):Play()
            end

            Library:PlayTabAnimation(Tab, false)
            Window:HideTabInfo()

            Library.PreviousTab = Tab
            Library.ActiveTab = nil
        end

        function Tab:SetVisible(Visible: boolean)
            TabButton.Visible = Visible

            if not Visible and Library.ActiveTab == Tab then
                Tab:Hide()
            end
        end

        function Tab:SetTooltip(Text: string?)
            Tab.Tooltip = Text

            if Tab.TooltipTable then
                Tab.TooltipTable:Destroy()
                Tab.TooltipTable = nil
            end

            if typeof(Text) == "string" then
                Tab.TooltipTable = Library:AddTooltip(Text, nil, TabButton)
            end
        end

        --// Execution \\--
        if typeof(Tooltip) == "string" then
            Tab.TooltipTable = Library:AddTooltip(Tooltip, nil, TabButton)
        end

        if not Library.ActiveTab then
            Tab:Show()
        end

        TabButton.MouseEnter:Connect(ObsGuard(function()
            if Library:MouseIsOverMenu() then
                return
            end
            Tab:Hover(true)
        end))
        TabButton.MouseLeave:Connect(ObsGuard(function()
            Tab:Hover(false)
        end))
        TabButton.MouseButton1Click:Connect(ObsGuard(function()
            Tab.Show()
        end))

        Tab.Container = TabContainer
        setmetatable(Tab, BaseGroupbox)

        Library.Tabs[Name] = Tab

        return Tab
    end

    function Window:AddDialog(Idx, Info)
        Info = Library:Validate(Info, Templates.Dialog)

        local DialogFrame
        local DialogOverlay
        local DialogContainer
        local ButtonsHolder
        local FooterButtonsList = {}

        DialogOverlay = New("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = "DarkColor",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Text = "",
            Active = false,
            ZIndex = 9000,
            Visible = true,
            Parent = MainFrame,
        })
        TweenService:Create(DialogOverlay, Library.TweenInfo, {
            BackgroundTransparency = 0.5,
        }):Play()

        DialogFrame = New("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = "BackgroundColor",
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(300, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 9001,
            Parent = DialogOverlay,
        })
        table.insert(
            Library.Corners,
            New("UICorner", {
                CornerRadius = UDim.new(0, WindowInfo.CornerRadius),
                Parent = DialogFrame,
            })
        )
        Library:AddOutline(DialogFrame)

        local InnerContainer = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            ZIndex = 9002,
            Parent = DialogFrame,
        })
        local DialogScale = New("UIScale", {
            Scale = 0.95,
            Parent = DialogFrame,
        })
        TweenService:Create(DialogScale, Library.TweenInfo, {
            Scale = 1
        }):Play()
        local _InnerPadding = New("UIPadding", {
            PaddingBottom = UDim.new(0, 15),
            PaddingLeft = UDim.new(0, 15),
            PaddingRight = UDim.new(0, 15),
            PaddingTop = UDim.new(0, 15),
            Parent = InnerContainer,
        })
        local _InnerLayout = New("UIListLayout", {
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = InnerContainer,
        })

        local HeaderContainer = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1,
            ZIndex = 9002,
            Parent = InnerContainer,
        })
        New("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = HeaderContainer,
        })
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 5),
            Parent = HeaderContainer,
        })

        local TitleRow = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 20),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1,
            ZIndex = 9002,
            Parent = HeaderContainer,
        })
        New("UIListLayout", {
            Padding = UDim.new(0, 6),
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = TitleRow,
        })

        if Info.Icon then
            local ParsedIcon = Library:GetCustomIcon(Info.Icon)
            if ParsedIcon then
                local _IconImg = New("ImageLabel", {
                    BackgroundTransparency = 1,
                    Size = UDim2.fromOffset(16, 16),
                    Image = ParsedIcon.Url,
                    ImageColor3 = Info.TitleColor or "FontColor",
                    ImageRectOffset = ParsedIcon.ImageRectOffset,
                    ImageRectSize = ParsedIcon.ImageRectSize,
                    LayoutOrder = 1,
                    ZIndex = 9002,
                    Parent = TitleRow,
                })
            end
        end

        local TitleLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 18),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = Info.Title,
            TextSize = 18,
            TextColor3 = Info.TitleColor or "FontColor",
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 2,
            ZIndex = 9002,
            Parent = TitleRow,
        })

        local DescriptionLabel = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14),
            AutomaticSize = Enum.AutomaticSize.Y,
            Text = Info.Description,
            TextSize = 14,
            TextTransparency = Info.DescriptionColor and 0 or 0.2,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextColor3 = Info.DescriptionColor or "FontColor",
            TextWrapped = true,
            LayoutOrder = 2,
            ZIndex = 9002,
            Parent = HeaderContainer,
        })

        DialogContainer = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 4,
            ZIndex = 9002,
            Parent = InnerContainer,
        })
        local _DialogContainerLayout = New("UIListLayout", {
            Padding = UDim.new(0, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = DialogContainer,
        })
        New("UIPadding", {
            PaddingBottom = UDim.new(0, 5),
            Parent = DialogContainer,
        })
        
        local _Sep2 = New("Frame", {
            BackgroundColor3 = "OutlineColor",
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 1),
            LayoutOrder = 5,
            ZIndex = 9002,
            Parent = InnerContainer,
        })

        ButtonsHolder = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 6,
            ZIndex = 9002,
            Parent = InnerContainer,
        })
        New("UIListLayout", {
            Padding = UDim.new(0, 8),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Right,
            Wraps = true,
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = ButtonsHolder,
        })
        New("UIPadding", {
            PaddingTop = UDim.new(0, 5),
            Parent = ButtonsHolder,
        })

        local Dialog = {
            Destroyed = false,
            Elements = {},
            Container = DialogContainer,
            OutsideClickDismiss = Info.OutsideClickDismiss,
        }

        function Dialog:Resize()
            local MaxWidth = MainFrame.AbsoluteSize.X * 0.75
            local MinWidth = 400

            local TotalButtonWidth = 0
            local ButtonCount = 0
            local HasButtons = false

            for _, BtnWrap in FooterButtonsList do
                HasButtons = true
                ButtonCount = ButtonCount + 1
                TotalButtonWidth = TotalButtonWidth + BtnWrap.Container.Size.X.Offset
            end

            local TargetWidth = MinWidth
            if HasButtons then
                local RequiredWidth = TotalButtonWidth + ((ButtonCount - 1) * 8) + 30
                TargetWidth = math.max(MinWidth, math.min(RequiredWidth, MaxWidth))
            end

            DialogFrame.Size = UDim2.fromOffset(TargetWidth, 0)

            local _DescX, DescY = Library:GetTextBounds(DescriptionLabel.Text, Library.Scheme.Font, 14, TargetWidth - 30)
            DescriptionLabel.Size = UDim2.new(1, 0, 0, DescY)

            local HasElements = false
            for _, v in DialogContainer:GetChildren() do
                if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then
                    HasElements = true
                    break
                end
            end
            DialogContainer.Visible = HasElements

            ButtonsHolder.Visible = HasButtons
            _Sep2.Visible = HasButtons
        end

        function Dialog:SetTitle(Title)
            TitleLabel.Text = Title
            Dialog:Resize()
        end

        function Dialog:SetDescription(Description)
            DescriptionLabel.Text = Description
            Dialog:Resize()
        end

        function Dialog:Dismiss()
            if Dialog.Destroyed then
                return
            end

            Dialog.Destroyed = true

            if Library.ActiveDialog == Dialog then
                Library.ActiveDialog = nil
            end

            for Index = #Dialog.Elements, 1, -1 do
                local Element = Dialog.Elements[Index]
                if Element and Element.Destroy then
                    Element:Destroy()
                end
            end
            table.clear(Dialog.Elements)

            local CloseTween = TweenService:Create(DialogScale, Library.TweenInfo, { Scale = 0.95 })
            TweenService:Create(DialogOverlay, Library.TweenInfo, { BackgroundTransparency = 1 }):Play()
            CloseTween:Play()
            
            task.delay(Library.TweenInfo.Time, function()
                DialogOverlay:Destroy()
            end)
            Library.Dialogues[Idx] = nil
        end

        DialogOverlay.MouseButton1Click:Connect(ObsGuard(function()
            if Info.OutsideClickDismiss then
                Dialog:Dismiss()
            end
        end))

        function Dialog:RemoveFooterButton(ButtonIdx)
            if FooterButtonsList[ButtonIdx] then
                FooterButtonsList[ButtonIdx].Container:Destroy()
                FooterButtonsList[ButtonIdx] = nil
            end
        end

        function Dialog:SetButtonDisabled(ButtonIdx, Disabled)
            if FooterButtonsList[ButtonIdx] and type(FooterButtonsList[ButtonIdx].SetDisabled) == "function" then
                FooterButtonsList[ButtonIdx]:SetDisabled(Disabled)
            end
        end

        function Dialog:SetButtonOrder(ButtonIdx, Order)
            if FooterButtonsList[ButtonIdx] and FooterButtonsList[ButtonIdx].Container then
                FooterButtonsList[ButtonIdx].Container.LayoutOrder = Order
            end
        end

        function Dialog:AddFooterButton(ButtonIdx, ButtonInfo)
            Dialog:RemoveFooterButton(ButtonIdx)

            local WaitTime = ButtonInfo.WaitTime or 0

            local ButtonContainer = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(0, 26),
                LayoutOrder = ButtonInfo.Order or 0,
                ZIndex = 9002,
                Parent = ButtonsHolder,
            })
            
            local BtnColor = "MainColor"
            local BtnOutline = "OutlineColor"
            local Variant = ButtonInfo.Variant or "Primary"
            
            if Variant == "Primary" then
                BtnColor = "FontColor"
                BtnOutline = "FontColor"
            elseif Variant == "Secondary" then
                BtnColor = "MainColor"
                BtnOutline = "OutlineColor"
            elseif Variant == "Destructive" then
                BtnColor = "DestructiveColor"
                BtnOutline = "DestructiveColor"
            elseif Variant == "Ghost" then
                BtnColor = "BackgroundColor"
                BtnOutline = "BackgroundColor"
            end

            local TextBtn = New("TextButton", {
                BackgroundColor3 = BtnColor,
                BorderColor3 = BtnOutline,
                BackgroundTransparency = WaitTime > 0 and 0.5 or 0,
                Size = UDim2.fromOffset(0, 26),
                Text = "",
                AutoButtonColor = false,
                ZIndex = 9002,
                Parent = ButtonContainer,
            })
            Library:AddOutline(TextBtn)
            table.insert(
                Library.Corners,
                New("UICorner", { 
                    CornerRadius = UDim.new(0, Library.CornerRadius), 
                    Parent = TextBtn 
                })
            )

            local _BtnPadding = New("UIPadding", {
                PaddingLeft = UDim.new(0, 15),
                PaddingRight = UDim.new(0, 15),
                Parent = TextBtn,
            })

            local TextColor = Library.Scheme.FontColor
            if Variant == "Primary" then
                TextColor = Library.Scheme.BackgroundColor
            elseif Variant == "Destructive" then
                TextColor = Color3.new(1, 1, 1)
            end
            
            local BtnLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Text = ButtonInfo.Title or ButtonIdx,
                TextColor3 = TextColor,
                TextTransparency = WaitTime > 0 and 0.5 or 0,
                TextSize = 14,
                ZIndex = 9002,
                Parent = TextBtn,
            })
            
            local LabelX, _ = Library:GetTextBounds(BtnLabel.Text, Library.Scheme.Font, 14, 250)
            ButtonContainer.Size = UDim2.fromOffset(LabelX + 30, 26)
            TextBtn.Size = UDim2.fromOffset(LabelX + 30, 26)

            local ProgressBar
            if WaitTime > 0 then
                ProgressBar = New("Frame", {
                    BackgroundColor3 = "AccentColor",
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 0, 1, -2),
                    Size = UDim2.new(0, 0, 0, 2),
                    ZIndex = 2,
                    Parent = TextBtn,
                })
                table.insert(
                    Library.Corners,
                    New("UICorner", { 
                        CornerRadius = UDim.new(0, Library.CornerRadius), 
                        Parent = ProgressBar 
                    })
                )
            end

            local IsActive = WaitTime <= 0

            local ButtonWrap = {
                Container = ButtonContainer,
                SetDisabled = function(self, Disabled)
                    IsActive = not Disabled
                    if Disabled then
                        TweenService:Create(TextBtn, Library.TweenInfo, { BackgroundTransparency = 0.5 }):Play()
                        TweenService:Create(BtnLabel, Library.TweenInfo, { TextTransparency = 0.5 }):Play()
                    else
                        TweenService:Create(TextBtn, Library.TweenInfo, { BackgroundTransparency = 0 }):Play()
                        TweenService:Create(BtnLabel, Library.TweenInfo, { TextTransparency = 0 }):Play()
                    end
                end
            }

            local ActiveColor = typeof(BtnColor) == "Color3" and BtnColor or Library.Scheme[BtnColor]
            local HoverColor = Variant == "Ghost" and Library.Scheme.MainColor or Library:GetBetterColor(ActiveColor, 10)

            TextBtn.MouseEnter:Connect(ObsGuard(function()
                if not IsActive then return end
                TweenService:Create(TextBtn, Library.TweenInfo, {
                    BackgroundColor3 = HoverColor
                }):Play()
            end))
            TextBtn.MouseLeave:Connect(ObsGuard(function()
                if not IsActive then return end
                TweenService:Create(TextBtn, Library.TweenInfo, {
                    BackgroundColor3 = ActiveColor
                }):Play()
            end))

            TextBtn.MouseButton1Click:Connect(ObsGuard(function()
                if not IsActive then return end
                if ButtonInfo.Callback then
                    ButtonInfo.Callback(Dialog)
                end
                if Info.AutoDismiss then
                    Dialog:Dismiss()
                end
            end))

            if WaitTime > 0 then
                TweenService:Create(ProgressBar, TweenInfo.new(WaitTime, Enum.EasingStyle.Linear), {
                    Size = UDim2.new(1, 0, 0, 2)
                }):Play()
                
                task.delay(WaitTime, function()
                    ButtonWrap:SetDisabled(false)
                    if ProgressBar then
                        TweenService:Create(ProgressBar, Library.TweenInfo, {
                            BackgroundTransparency = 1
                        }):Play()
                    end
                end)
            end

            FooterButtonsList[ButtonIdx] = ButtonWrap
        end

        for BIdx, BInfo in Info.FooterButtons do
            if type(BIdx) == "number" and BInfo.Id then BIdx = BInfo.Id end
            Dialog:AddFooterButton(BIdx, BInfo)
        end

        setmetatable(Dialog, BaseGroupbox)
        Library.Dialogues[Idx] = Dialog

        Dialog:Resize()
        
        Library.ActiveDialog = Dialog
        return Dialog
    end

    -- Azure-style toggle fade (ported from upstream deividcomsono/Azure): tween the transparency
    -- of every MainFrame descendant on open/close (0.35s Quad Out), caching each element's visible value.
    local _tvlTransCache = {}
    local _tvlWindowAnimInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local _tvlWindowAnimInfoClose = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local _tvlWindowAnimInfoBase = TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    local _tvlGuiProps = { "BackgroundTransparency" }
    local _tvlImgProps = { "BackgroundTransparency", "ImageTransparency" }
    local _tvlTxtProps = { "BackgroundTransparency", "TextTransparency" }
    local _tvlStrokeProps = { "Transparency" }
    local function _tvlFadeInstance(Desc, Props)
        local cache = _tvlTransCache[Desc]
        if not cache then
            cache = {}
            _tvlTransCache[Desc] = cache
        end
        for _, Prop in Props do
            -- Capture on close only, when the element is fully visible. The
            -- Fading guard in Window:Toggle now prevents a close landing
            -- mid-fade, which is what used to poison this with a partial value.
            if not Library.Toggled then
                cache[Prop] = Desc[Prop]
            end
            if cache[Prop] ~= nil and cache[Prop] ~= 1 then
                TweenService:Create(Desc, Library.Toggled and _tvlWindowAnimInfo or _tvlWindowAnimInfoClose, { [Prop] = Library.Toggled and cache[Prop] or 1 }):Play()
            end
        end
    end

    local WindowMorph = nil
    local WindowMorphStroke = nil
    local MorphTweens = {}
    local MorphConnection = nil
    local MorphRevealInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local MORPH_STEP = 1 / 240
    local MORPH_OPEN_OMEGA, MORPH_OPEN_ZETA = 30, 0.82
    local MORPH_CLOSE_OMEGA, MORPH_CLOSE_ZETA = 34, 1

    local WindowPrewarmed = false

    Library.PrewarmWindow = function()
        if Library.Toggled or WindowPrewarmed or not MainFrameWrapper then
            return
        end
        WindowPrewarmed = true
        local Home = MainFrameWrapper.Position
        MainFrameWrapper.Position = UDim2.fromOffset(-20000, -20000)
        MainFrameWrapper.Visible = true
        RunService.RenderStepped:Wait()
        RunService.RenderStepped:Wait()
        if not Library.Toggled then
            MainFrameWrapper.Visible = false
        end
        MainFrameWrapper.Position = Home
    end

    local function StopWindowMorph()
        for _, Tween in ipairs(MorphTweens) do
            pcall(function()
                Tween:Cancel()
            end)
        end
        table.clear(MorphTweens)

        if MorphConnection then
            MorphConnection:Disconnect()
            MorphConnection = nil
        end
    end

    local function PlayMorphTween(Target, Info, Props)
        local Tween = TweenService:Create(Target, Info, Props)
        table.insert(MorphTweens, Tween)
        Tween:Play()
        return Tween
    end

    local function GetWindowMorph()
        if WindowMorph and WindowMorph.Parent then
            return WindowMorph
        end

        WindowMorph = New("Frame", {
            Name = "WindowMorph",
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 999,
            Parent = ScreenGui,
        })
        New("UICorner", {
            CornerRadius = UDim.new(0, Library.CornerRadius),
            Parent = WindowMorph,
        })
        WindowMorphStroke = New("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Color = Library.Scheme.AccentColor,
            Thickness = 1,
            Transparency = 1,
            Parent = WindowMorph,
        })

        return WindowMorph
    end

    local function WindowMorphRects()
        local Origin = ScreenGui.AbsolutePosition
        local Size = MainFrame.AbsoluteSize
        local Target = { Position = MainFrame.AbsolutePosition - Origin, Size = Size }

        local FromRect = Library.MorphFromRect
        if FromRect then
            Library.MorphFromRect = nil
            return { Position = FromRect.Position - Origin, Size = FromRect.Size }, Target
        end

        if TabDock and TabDock.Parent and TabDock.Visible then
            return { Position = (TabDock:GetAttribute("RecedeHomePosition") or TabDock.AbsolutePosition) - Origin, Size = TabDock.AbsoluteSize }, Target
        end

        local Shrunk = Size * 0.85
        return { Position = Target.Position + (Size - Shrunk) / 2, Size = Shrunk }, Target
    end

    local function RunMorphSprings(From, To, Omega, Zeta, OnFrame, OnSettled)
        local Values = { From.Position.X, From.Position.Y, From.Size.X, From.Size.Y }
        local Goals = { To.Position.X, To.Position.Y, To.Size.X, To.Size.Y }
        local Velocities = { 0, 0, 0, 0 }
        local Span = 0
        for Index = 1, 4 do
            Span += math.abs(Goals[Index] - Values[Index])
        end
        Span = math.max(Span, 1)

        local Morph = WindowMorph
        local Carry = 0

        local function Apply()
            Morph.Position = UDim2.fromOffset(Values[1], Values[2])
            Morph.Size = UDim2.fromOffset(math.max(Values[3], 0), math.max(Values[4], 0))
        end

        Apply()

        MorphConnection = RunService.RenderStepped:Connect(function(Delta)
            Carry += math.min(Delta, 0.1)

            while Carry >= MORPH_STEP do
                Carry -= MORPH_STEP
                for Index = 1, 4 do
                    local Force = -Omega * Omega * (Values[Index] - Goals[Index]) - 2 * Zeta * Omega * Velocities[Index]
                    Velocities[Index] += Force * MORPH_STEP
                    Values[Index] += Velocities[Index] * MORPH_STEP
                end
            end

            Apply()

            local Remaining, Speed = 0, 0
            for Index = 1, 4 do
                Remaining += math.abs(Goals[Index] - Values[Index])
                Speed += math.abs(Velocities[Index])
            end

            OnFrame(1 - math.clamp(Remaining / Span, 0, 1))

            if Remaining < 0.75 and Speed < 6 then
                for Index = 1, 4 do
                    Values[Index] = Goals[Index]
                end
                Apply()
                if MorphConnection then
                    MorphConnection:Disconnect()
                    MorphConnection = nil
                end
                OnSettled()
            end
        end)
    end

    local function PlayWindowMorph(Opening, Token)
        StopWindowMorph()

        local Played = pcall(function()
            local Morph = GetWindowMorph()
            local Stroke = WindowMorphStroke
            local From, Target = WindowMorphRects()

            Morph.BackgroundColor3 = MainFrame.BackgroundColor3
            Stroke.Color = Library.Scheme.AccentColor
            MainFrameWrapper.Visible = false

            if Opening then
                local Revealed = false

                Morph.BackgroundTransparency = 0
                Stroke.Transparency = 0.3
                Morph.Visible = true

                local function Reveal()
                    if Revealed then
                        return
                    end
                    Revealed = true
                    MainFrameWrapper.Visible = true
                    PlayMorphTween(Morph, MorphRevealInfo, { BackgroundTransparency = 1 })
                    PlayMorphTween(Stroke, MorphRevealInfo, { Transparency = 1 })
                    task.delay(MorphRevealInfo.Time, function()
                        if Library.MorphToken == Token and not MorphConnection then
                            Morph.Visible = false
                        end
                    end)
                end

                RunMorphSprings(From, Target, MORPH_OPEN_OMEGA, MORPH_OPEN_ZETA, function(Progress)
                    if Progress >= 0.94 and Library.MorphToken == Token and Library.Toggled then
                        Reveal()
                    end
                end, function()
                    if Library.MorphToken ~= Token or not Library.Toggled then
                        return
                    end
                    Reveal()
                    task.delay(MorphRevealInfo.Time, function()
                        if Library.MorphToken == Token then
                            Morph.Visible = false
                        end
                    end)
                end)
            else
                Morph.BackgroundTransparency = 0
                Stroke.Transparency = 0.3
                Morph.Visible = true

                RunMorphSprings(Target, From, MORPH_CLOSE_OMEGA, MORPH_CLOSE_ZETA, function(Progress)
                    Morph.BackgroundTransparency = Progress * 0.55
                    Stroke.Transparency = 0.3 + Progress * 0.7
                end, function()
                    if Library.MorphToken == Token then
                        Morph.Visible = false
                    end
                end)
            end
        end)

        if not Played then
            StopWindowMorph()
            pcall(function()
                if WindowMorph then
                    WindowMorph.Visible = false
                end
            end)
            MainFrameWrapper.Visible = Library.Toggled
        end
    end

    function Window:Toggle(Value: boolean?)
        if Fading then
            return
        end

        if Library.ActiveLoading then
            if Value == true then
                return
            end

            if not Library.Toggled then
                return
            end
        end

        if typeof(Value) == "boolean" then
            Library.Toggled = Value
        else
            Library.Toggled = not Library.Toggled
        end

        if not Library.Toggled and CurrentMenu then
            pcall(function()
                CurrentMenu:Close()
            end)
        end

        Fading = true
        task.defer(function()
            Fading = false
        end)

        for Desc, Cache in pairs(_tvlTransCache) do
            if Desc.Parent then
                for Prop, Value in pairs(Cache) do
                    pcall(function()
                        Desc[Prop] = Value
                    end)
                end
            end
        end
        table.clear(_tvlTransCache)

        pcall(function()
            MainFrameWrapperScale.Scale = 1
        end)
        Library.MorphToken = (Library.MorphToken or 0) + 1
        PlayWindowMorph(Library.Toggled, Library.MorphToken)

        if WindowInfo.UnlockMouseWhileOpen then
            ModalElement.Modal = Library.Toggled
        end

        if Library.Toggled and not Library.IsMobile then
            local OldMouseIconEnabled = UserInputService.MouseIconEnabled
            local ShowCursorBinding = Library.ShowCursorBinding
            pcall(function()
                RunService:UnbindFromRenderStep(ShowCursorBinding)
            end)
            local LastCursorX, LastCursorY = -1, -1
            RunService:BindToRenderStep(ShowCursorBinding, Enum.RenderPriority.Last.Value, function()
                UserInputService.MouseIconEnabled = not Library.ShowCustomCursor

                if Library.ShowCustomCursor then
                    local mx, my = Mouse.X, Mouse.Y
                    if mx ~= LastCursorX or my ~= LastCursorY then
                        LastCursorX, LastCursorY = mx, my
                        Cursor.Position = UDim2.fromOffset(mx, my)
                    end
                end
                Cursor.Visible = Library.ShowCustomCursor

                if not (Library.Toggled and ScreenGui and ScreenGui.Parent) then
                    UserInputService.MouseIconEnabled = OldMouseIconEnabled
                    Cursor.Visible = false
                    RunService:UnbindFromRenderStep(ShowCursorBinding)
                end
            end)
        elseif not Library.Toggled then
            TooltipLabel.Visible = false

            for _, Option in Library.Options do
                if Option.Type == "ColorPicker" then
                    Option.ColorMenu:Close()
                    Option.ContextMenu:Close()
                elseif Option.Type == "Dropdown" or Option.Type == "KeyPicker" then
                    Option.Menu:Close()
                end
            end
        end
    end

    function Library:Toggle(Value: boolean?)
        return Window:Toggle(Value)
    end

    if WindowInfo.EnableSidebarResize then
        local Threshold = (WindowInfo.MinSidebarWidth + WindowInfo.SidebarCompactWidth) * WindowInfo.SidebarCollapseThreshold
        local StartPos, StartWidth
        local Dragging = false
        local Changed

        local SidebarGrabber = New("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(0.5, 0),
            Size = UDim2.new(0, 8, 1, 0),
            Text = "",
            Parent = DividerLine,
        })
        SidebarGrabber.MouseEnter:Connect(ObsGuard(function()
            TweenService:Create(DividerLine, Library.TweenInfo, {
                BackgroundColor3 = Library:GetLighterColor(Library.Scheme.OutlineColor),
            }):Play()
        end))
        SidebarGrabber.MouseLeave:Connect(ObsGuard(function()
            if Dragging then
                return
            end
            TweenService:Create(DividerLine, Library.TweenInfo, {
                BackgroundColor3 = Library.Scheme.OutlineColor,
            }):Play()
        end))

        SidebarGrabber.InputBegan:Connect(ObsGuard(function(Input: InputObject)
            if not IsClickInput(Input) then
                return
            end

            Library.CantDragForced = true

            StartPos = Input.Position
            StartWidth = Window:GetSidebarWidth()
            Dragging = true

            Changed = Input.Changed:Connect(ObsGuard(function()
                if Input.UserInputState ~= Enum.UserInputState.End then
                    return
                end

                Library.CantDragForced = false
                TweenService:Create(DividerLine, Library.TweenInfo, {
                    BackgroundColor3 = Library.Scheme.OutlineColor,
                }):Play()

                Dragging = false
                if Changed and Changed.Connected then
                    Changed:Disconnect()
                    Changed = nil
                end
            end))
        end))

        Library:GiveSignal(UserInputService.InputChanged:Connect(ObsGuard(function(Input: InputObject)
            if not Library.Toggled or not (ScreenGui and ScreenGui.Parent) then
                Dragging = false
                if Changed and Changed.Connected then
                    Changed:Disconnect()
                    Changed = nil
                end

                return
            end

            if Dragging and IsHoverInput(Input) then
                local Delta = Input.Position - StartPos
                local Width = StartWidth + Delta.X

                if WindowInfo.DisableCompactingSnap then
                    Window:SetSidebarWidth(Width)
                    return
                end

                if Width > Threshold then
                    Window:SetSidebarWidth(math.max(Width, WindowInfo.MinSidebarWidth))
                else
                    Window:SetSidebarWidth(WindowInfo.SidebarCompactWidth)
                end
            end
        end)))
    end

    Window:SetAlwaysOnTop(WindowInfo.AlwaysOnTop)
    if WindowInfo.EnableCompacting and WindowInfo.SidebarCompacted then
        Window:SetSidebarWidth(WindowInfo.SidebarCompactWidth)
    end
    if WindowInfo.AutoShow and not Library.ActiveLoading then
        task.spawn(Library.Toggle)
    end

    if Library.IsMobile or WindowInfo.ShowToggleButton == true then
        local ToggleButton = Library:AddDraggableButton(WindowInfo.ToggleButtonText or "Toggle", function()
            Library:Toggle()
        end, true, true)
        if WindowInfo.ToggleButtonIcon then
            local Btn = ToggleButton.Button
            local TBIcon = Library:GetCustomIcon(WindowInfo.ToggleButtonIcon)
            local Icon = New("ImageLabel", {
                Name = "Icon",
                BackgroundTransparency = 1,
                Image = TBIcon and TBIcon.Url or "",
                ImageRectOffset = TBIcon and TBIcon.ImageRectOffset or Vector2.zero,
                ImageRectSize = TBIcon and TBIcon.ImageRectSize or Vector2.zero,
                ImageColor3 = "AccentColor",
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = Btn.ZIndex + 1,
                Parent = Btn,
            })
            if WindowInfo.ToggleButtonText then
                local IconSize, Pad = 18, 8
                Btn.TextXAlignment = Enum.TextXAlignment.Left
                New("UIPadding", { PaddingLeft = UDim.new(0, Pad + IconSize + 6), Parent = Btn })
                Icon.Size = UDim2.fromOffset(IconSize, IconSize)
                Icon.AnchorPoint = Vector2.new(0, 0.5)
                Icon.Position = UDim2.new(0, -(IconSize + 6), 0.5, 0)
                local OrigSetText = ToggleButton.SetText
                function ToggleButton:SetText(Text)
                    OrigSetText(self, Text)
                    Btn.Size = UDim2.fromOffset(Btn.Size.X.Offset + IconSize + 6, Btn.Size.Y.Offset)
                end
                ToggleButton:SetText(WindowInfo.ToggleButtonText)
            else
                local Side = WindowInfo.ToggleButtonSize or (Library.IsMobile and 48 or 40)
                Btn.Text = ""
                Btn.Size = UDim2.fromOffset(Side, Side)
                Icon.Size = UDim2.fromOffset(Side - 18, Side - 18)
                Icon.AnchorPoint = Vector2.new(0.5, 0.5)
                Icon.Position = UDim2.fromScale(0.5, 0.5)
                function ToggleButton:SetText() end
            end
        end
        if WindowInfo.ToggleButtonGlow ~= false then
            pcall(function() Library:AddGlow(ToggleButton.Button) end)
        end
        Library.ToggleButton = ToggleButton
        if WindowInfo.ToggleButtonBelowWatermark ~= false then
            pcall(function() Library:DockToggleButton() end)
        end

        local LongPressLock = WindowInfo.ToggleButtonLongPressLock ~= false
        if LongPressLock then
            local Btn = ToggleButton.Button
            local Icon = Btn:FindFirstChild("Icon")
            local LockIcon = Library:GetIcon("lock")
            local LockSide = math.max(16, math.floor(Btn.Size.Y.Offset * 0.55))
            local Padlock = New("ImageLabel", {
                Name = "Padlock",
                BackgroundTransparency = 1,
                Image = LockIcon.Url or "",
                ImageRectOffset = LockIcon.ImageRectOffset or Vector2.zero,
                ImageRectSize = LockIcon.ImageRectSize or Vector2.zero,
                ImageColor3 = Color3.fromRGB(170, 170, 170),
                ScaleType = Enum.ScaleType.Fit,
                Size = UDim2.fromOffset(LockSide, LockSide),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Visible = false,
                ZIndex = Btn.ZIndex + 2,
                Parent = Btn,
            })
            local Grey = Color3.fromRGB(120, 120, 120)
            local function applyLock(Locked)
                Btn:SetAttribute("DragLocked", Locked)
                Padlock.Visible = Locked
                if Icon then
                    Icon.Visible = not Locked
                    local Reg = Library.Registry[Icon]
                    if Locked then
                        if Reg then Reg.ImageColor3 = nil end
                        Icon.ImageColor3 = Grey
                    else
                        Library.Registry[Icon] = Reg or {}
                        Library.Registry[Icon].ImageColor3 = "AccentColor"
                        Icon.ImageColor3 = Library.Scheme.AccentColor
                    end
                end
                if Locked then
                    Btn.TextColor3 = Grey
                else
                    Btn.TextColor3 = Library.Scheme.FontColor
                end
                for _, c in Btn:GetChildren() do
                    if c:IsA("UIStroke") then
                        local R = Library.Registry[c]
                        if Locked then
                            if R and R.Color then c:SetAttribute("LockPrevColor", R.Color); R.Color = nil end
                            c.Color = Grey
                        else
                            local Key = c:GetAttribute("LockPrevColor")
                            if Key then
                                Library.Registry[c] = R or {}
                                Library.Registry[c].Color = Key
                                c.Color = Library.Scheme[Key] or c.Color
                            end
                        end
                    end
                end
            end
            Library.ToggleButtonLocked = false
            function Library:SetToggleButtonLocked(Locked)
                Library.ToggleButtonLocked = Locked == true
                applyLock(Library.ToggleButtonLocked)
            end
            local PressId = 0
            Btn.InputBegan:Connect(ObsGuard(function(Input)
                if Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch then
                    return
                end
                PressId += 1
                local MyId = PressId
                local Start = Vector2.new(Input.Position.X, Input.Position.Y)
                local Held = true
                local Conns = {}
                local function release()
                    Held = false
                    for _, c in Conns do pcall(function() c:Disconnect() end) end
                end
                table.insert(Conns, Input.Changed:Connect(ObsGuard(function()
                    if Input.UserInputState == Enum.UserInputState.End then release() end
                end)))
                table.insert(Conns, UserInputService.InputEnded:Connect(function(I)
                    if I == Input then release() end
                end))
                table.insert(Conns, UserInputService.InputChanged:Connect(ObsGuard(function(I)
                    if I == Input or (Input.UserInputType == Enum.UserInputType.MouseButton1 and I.UserInputType == Enum.UserInputType.MouseMovement) then
                        if (Vector2.new(I.Position.X, I.Position.Y) - Start).Magnitude > 12 then release() end
                    end
                end)))
                task.delay(WindowInfo.ToggleButtonLongPressTime or 1, function()
                    local WasHeld = Held
                    release()
                    if not WasHeld or MyId ~= PressId or not Btn.Parent then return end
                    Btn:SetAttribute("SuppressClick", true)
                    Library:SetToggleButtonLocked(not Library.ToggleButtonLocked)
                end)
            end))
        end

        local LockButton = nil
        if Library.IsMobile and not LongPressLock then
            LockButton = Library:AddDraggableButton("Lock", function(self)
                Library.CantDragForced = not Library.CantDragForced
                self:SetText(Library.CantDragForced and "Unlock" or "Lock")
            end, true, true)
        end

        if WindowInfo.MobileButtonsSide == "Right" then
            ToggleButton.Button.AnchorPoint = Vector2.new(1, 0)
            ToggleButton.Button.Position = UDim2.new(1, -6, 0, 6)

            if LockButton then
                LockButton.Button.AnchorPoint = Vector2.new(1, 0)
                LockButton.Button.Position = UDim2.new(1, -(ToggleButton.Button.Size.X.Offset + 12), 0, 6)
            end
        else
            ToggleButton.Button.AnchorPoint = Vector2.new(0, 0)
            ToggleButton.Button.Position = UDim2.fromOffset(6, 6)

            if LockButton then
                LockButton.Button.AnchorPoint = Vector2.new(0, 0)
                LockButton.Button.Position = UDim2.fromOffset(ToggleButton.Button.Size.X.Offset + 12, 6)
            end
        end

        if WindowInfo.ShowMobileButtons == false then
            ToggleButton.Button.Visible = false
            if LockButton then LockButton.Button.Visible = false end
        end
    end

    --// Execution \\--
    Library:GiveSignal(SearchBox:GetPropertyChangedSignal("Text"):Connect(ObsGuard(function()
        Library:UpdateSearch(SearchBox.Text)
    end)))

    Library:GiveSignal(UserInputService.InputBegan:Connect(ObsGuard(function(Input: InputObject)
        if Library.Unloaded then
            return
        end

        if Input.KeyCode == Enum.KeyCode.Escape then
            -- Releasing focus from a text input takes priority and never toggles the window --
            local FocusedBox = UserInputService:GetFocusedTextBox()
            if FocusedBox then
                FocusedBox:ReleaseFocus()
                return
            end

            -- Dismiss the topmost dialog before closing any open menu --
            if Library.ActiveDialog and Library.ActiveDialog.OutsideClickDismiss ~= false then
                Library.ActiveDialog:Dismiss()
                return
            end

            if CurrentMenu then
                CurrentMenu:Close()
                return
            end

            return
        end

        if UserInputService:GetFocusedTextBox() then
            return
        end

        if Input.KeyCode == Library.ToggleKeybind then
            Library:Toggle()
        end
    end)))

    Library:GiveSignal(UserInputService.WindowFocused:Connect(ObsGuard(function()
        Library.IsRobloxFocused = true
    end)))
    Library:GiveSignal(UserInputService.WindowFocusReleased:Connect(ObsGuard(function()
        Library.IsRobloxFocused = false
    end)))

    --// Native "Menu Settings" tab: Menu group (keybind toggle, watermark toggle wired in
    --// lazily by CreateWatermark, unload button), Background group, and the bottom-bar
    --// account widget (avatar/hide/logout). Built automatically so calling scripts don't
    --// need to hand-roll or request any of it. Opt out per-window with AutoMenu = false /
    --// AutoAccountWidget = false. \\--
    do
        Window.BackgroundImageObject = BackgroundImage

        local function applyAutoBackground()
            local bg = Window.BackgroundImageObject
            if not bg then
                return
            end

            local enabled = Toggles.TVLBackgroundImageEnabled and Toggles.TVLBackgroundImageEnabled.Value or false
            local id = tostring((Options.TVLBackgroundImageId and Options.TVLBackgroundImageId.Value) or "")
            id = id:gsub("%s+", "")

            local show = enabled and id ~= ""
            pcall(function()
                Window:SetBackgroundImage(show and id or "")
            end)

            pcall(function()
                local opacity = tonumber(Options.TVLBackgroundImageOpacity and Options.TVLBackgroundImageOpacity.Value) or 25
                bg.ImageTransparency = 1 - (math.clamp(opacity, 0, 100) / 100)

                local fit = (Options.TVLBackgroundImageFit and Options.TVLBackgroundImageFit.Value) or "Stretch"
                bg.ScaleType = Enum.ScaleType[fit] or Enum.ScaleType.Stretch
                if fit == "Tile" then
                    bg.TileSize = UDim2.fromOffset(220, 220)
                end

                bg.Visible = show and bg.Image ~= ""
            end)
        end

        if WindowInfo.AutoMenu == true then
            local MenuTab = Window:AddTab(WindowInfo.MenuTabTitle or "Menu Settings", WindowInfo.MenuTabIcon or "cog")
            Window.MenuTab = MenuTab
            do
                local origAddTab = Window.AddTab
                local firstShown = false
                Window.AddTab = function(self, ...)
                    local tab = origAddTab(self, ...)
                    if not firstShown and tab and tab ~= MenuTab and type(tab.Show) == "function" then
                        firstShown = true
                        pcall(function() tab:Show() end)
                    end
                    return tab
                end
            end

            -- Force the auto-built Menu tab to sort last in the sidebar, regardless of the
            -- fact that it was created before any tabs the calling script adds afterward.
            pcall(function()
                for _, child in ipairs(Tabs:GetChildren()) do
                    if child:IsA("TextButton") then
                        child.LayoutOrder = 1000
                    end
                end
                if TabDockButtons[MenuTab] then
                    TabDockButtons[MenuTab].Button.LayoutOrder = 1000
                end
            end)

            local MenuGroup = MenuTab:AddLeftGroupbox("Menu", "wrench")
            Window.MenuGroup = MenuGroup

            do
                local keybindLabel = MenuGroup:AddLabel("Menu Keybind")
                keybindLabel:AddKeyPicker("TVLMenuKeybind", {
                    Default = "F3",
                    NoUI = true,
                    Text = "Menu keybind",
                })

                pcall(function()
                    for _, child in ipairs(keybindLabel.TextLabel:GetChildren()) do
                        if child:IsA("TextButton") then
                            Library:AddTooltip("Press to change the keybind for hiding / opening the GUI.", nil, child)
                            break
                        end
                    end
                end)

                if Options.TVLMenuKeybind then
                    Library.ToggleKeybind = Options.TVLMenuKeybind
                end
            end

            MenuGroup:AddDivider()

            MenuGroup:AddToggle("TVLOpenKeybindMenu", {
                Text = "Open Keybind Menu",
                Default = not Library.IsMobile,
                Callback = function(value)
                    if Library.KeybindFrame then
                        Library.KeybindFrame.Visible = value
                    end
                end,
            })

            if not Library.IsMobile then
                MenuGroup:AddToggle("TVLShowToggleIcon", {
                    Text = "Show Toggle Icon",
                    Default = true,
                    Tooltip = "Shows/hides the floating button that opens the menu.",
                    Callback = function(value)
                        pcall(function() Library.ToggleButton.Button.Visible = value == true end)
                    end,
                })
            end

            if WindowInfo.TabDock ~= false then
                MenuGroup:AddToggle("TVLShowSidebar", {
                    Text = "Show Sidebar",
                    Default = Library.TabDockVisible ~= false,
                    Tooltip = "Shows the tab icons on the side of your screen.",
                    Callback = function(value)
                        if Library.SetTabDockVisible then
                            Library:SetTabDockVisible(value)
                        end
                    end,
                })
            end

            MenuGroup:AddToggle("TVLShowWatermark", {
                Text = "Show Watermark",
                Default = true,
                Tooltip = "Shows/hides the FPS & ping watermark label.",
                Callback = function(value)
                    pcall(function() if Library.Watermark then Library.Watermark:SetVisible(value) end end)
                end,
            })

            MenuGroup:AddDivider()

            MenuGroup:AddButton("TVLUnloadBtn", {
                Text = "‼️ UNLOADS EVERYTHING ‼️",
                Tooltip = "Unloads the whole GUI and all features.",
                Func = function()
                    Library:Unload()
                end,
            })

            Window.NotificationGroup = Library:AddNotificationSettings(MenuTab, "Right")

            local BackgroundGroup = MenuTab:AddRightGroupbox("Background", "image")
            Window.BackgroundGroup = BackgroundGroup

            BackgroundGroup:AddToggle("TVLBackgroundImageEnabled", {
                Text = "Background Image",
                Default = false,
                Tooltip = "Show a custom image behind the menu.",
                Callback = applyAutoBackground,
            })

            BackgroundGroup:AddInput("TVLBackgroundImageId", {
                Text = "Image ID",
                Placeholder = "rbxassetid://... or id",
                Finished = true,
                Tooltip = "Paste a Roblox IMAGE asset id (a Decal id will not render).",
                Callback = applyAutoBackground,
            })

            BackgroundGroup:AddSlider("TVLBackgroundImageOpacity", {
                Text = "Opacity",
                Default = 25,
                Min = 0,
                Max = 100,
                Rounding = 0,
                Compact = true,
                Suffix = "%",
                Callback = applyAutoBackground,
            })

            BackgroundGroup:AddDropdown("TVLBackgroundImageFit", {
                Text = "Fit",
                Values = { "Stretch", "Fit", "Crop", "Tile" },
                Default = "Stretch",
                AllowNull = false,
                Callback = applyAutoBackground,
            })

            task.defer(applyAutoBackground)
            pcall(function() BackgroundGroup:Hide() end)
        end

        if WindowInfo.AutoMenu == true then
            pcall(function()
                local plr = Library.LocalPlayer
                if not plr then
                    return
                end

                local bottomBar = FooterLabel and FooterLabel.Parent
                local mainFrame = bottomBar and bottomBar.Parent
                if not (bottomBar and mainFrame and Tabs) then
                    return
                end

                local userId = plr.UserId
                local displayName = plr.DisplayName or plr.Name

                local accountFrame = Instance.new("Frame")
                accountFrame.Name = "TVLAccountWidget"
                accountFrame.BackgroundTransparency = 1
                accountFrame.AnchorPoint = Vector2.new(0, 1)
                accountFrame.Position = UDim2.new(0, 0, 1, -21)
                accountFrame.Size = UDim2.new(Tabs.Size.X.Scale, Tabs.Size.X.Offset, 0, 44)
                accountFrame.ZIndex = 5
                accountFrame.Parent = mainFrame

                local topLine = Instance.new("Frame")
                topLine.Name = "TopDivider"
                topLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                topLine.BackgroundTransparency = 0.92
                topLine.BorderSizePixel = 0
                topLine.Size = UDim2.new(1, 0, 0, 1)
                topLine.Parent = accountFrame

                local avatar = Instance.new("ImageLabel")
                avatar.Name = "Avatar"
                avatar.BackgroundTransparency = 1
                avatar.Size = UDim2.new(0, 32, 0, 32)
                avatar.Position = UDim2.new(0, 10, 0.5, 0)
                avatar.AnchorPoint = Vector2.new(0, 0.5)
                avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150"
                avatar.Parent = accountFrame
                local avatarCorner = Instance.new("UICorner")
                avatarCorner.CornerRadius = UDim.new(1, 0)
                avatarCorner.Parent = avatar

                local nameLabel = Instance.new("TextLabel")
                nameLabel.Name = "DisplayName"
                nameLabel.BackgroundTransparency = 1
                nameLabel.Position = UDim2.new(0, 50, 0, 0)
                nameLabel.Size = UDim2.new(1, -110, 1, 0)
                nameLabel.FontFace = Library.Scheme.Font or Font.fromEnum(Enum.Font.GothamBold)
                Library.Registry[nameLabel] = { FontFace = "Font" }
                nameLabel.TextSize = 14
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
                nameLabel.Text = displayName
                nameLabel.Parent = accountFrame

                local identityHidden = false
                local avatarRealImage = avatar.Image
                local avatarRealColor = avatar.ImageColor3
                local avatarRealRectOffset = avatar.ImageRectOffset
                local avatarRealRectSize = avatar.ImageRectSize
                local avatarRealScaleType = avatar.ScaleType
                local anonIcon = Library.GetIcon and Library:GetIcon("user")

                local avatarAnonBg = Instance.new("Frame")
                avatarAnonBg.Name = "AvatarAnonBg"
                avatarAnonBg.BackgroundColor3 = Color3.fromRGB(52, 55, 63)
                avatarAnonBg.Size = avatar.Size
                avatarAnonBg.Position = avatar.Position
                avatarAnonBg.AnchorPoint = avatar.AnchorPoint
                avatarAnonBg.ZIndex = avatar.ZIndex - 1
                avatarAnonBg.Visible = false
                avatarAnonBg.Parent = accountFrame
                local avatarAnonBgCorner = Instance.new("UICorner")
                avatarAnonBgCorner.CornerRadius = UDim.new(1, 0)
                avatarAnonBgCorner.Parent = avatarAnonBg

                local eyeBtn = Instance.new("ImageButton")
                eyeBtn.Name = "PrivacyToggleButton"
                eyeBtn.AnchorPoint = Vector2.new(1, 0.5)
                eyeBtn.Position = UDim2.new(1, -34, 0.5, 0)
                eyeBtn.Size = UDim2.new(0, 20, 0, 20)
                eyeBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                eyeBtn.BackgroundTransparency = 0.92
                eyeBtn.AutoButtonColor = false
                eyeBtn.ImageColor3 = Color3.fromRGB(190, 195, 205)
                eyeBtn.ImageTransparency = 0.4
                eyeBtn.ScaleType = Enum.ScaleType.Fit
                eyeBtn.Parent = accountFrame
                local eyeCorner = Instance.new("UICorner")
                eyeCorner.CornerRadius = UDim.new(0, 8)
                eyeCorner.Parent = eyeBtn
                local eyePad = Instance.new("UIPadding")
                eyePad.PaddingLeft = UDim.new(0, 4)
                eyePad.PaddingRight = UDim.new(0, 4)
                eyePad.PaddingTop = UDim.new(0, 4)
                eyePad.PaddingBottom = UDim.new(0, 4)
                eyePad.Parent = eyeBtn
                eyeBtn.MouseEnter:Connect(ObsGuard(function() eyeBtn.BackgroundTransparency = 0.82 end))
                eyeBtn.MouseLeave:Connect(ObsGuard(function() eyeBtn.BackgroundTransparency = 0.92 end))
                pcall(function() Library:AddTooltip("Hide your account from being shown.", nil, eyeBtn) end)

                local function setIdentityHidden(hidden)
                    identityHidden = hidden
                    avatarAnonBg.Visible = hidden
                    nameLabel.Text = hidden and "Username" or displayName
                    if hidden then
                        if anonIcon then
                            avatar.Image = anonIcon.Url
                            avatar.ImageRectOffset = anonIcon.ImageRectOffset or Vector2.zero
                            avatar.ImageRectSize = anonIcon.ImageRectSize or Vector2.zero
                            avatar.ImageColor3 = Color3.fromRGB(150, 155, 165)
                            avatar.ScaleType = Enum.ScaleType.Fit
                        end
                    else
                        avatar.Image = avatarRealImage
                        avatar.ImageRectOffset = avatarRealRectOffset
                        avatar.ImageRectSize = avatarRealRectSize
                        avatar.ImageColor3 = avatarRealColor
                        avatar.ScaleType = avatarRealScaleType
                    end

                    local eyeIcon = Library.GetIcon and Library:GetIcon(hidden and "eye-off" or "eye")
                    if eyeIcon then
                        eyeBtn.Image = eyeIcon.Url
                        eyeBtn.ImageRectOffset = eyeIcon.ImageRectOffset or Vector2.zero
                        eyeBtn.ImageRectSize = eyeIcon.ImageRectSize or Vector2.zero
                    end
                end
                eyeBtn.Activated:Connect(ObsGuard(function()
                    setIdentityHidden(not identityHidden)
                end))
                setIdentityHidden(false)

                local logoutIcon = Library.GetIcon and Library:GetIcon("log-out")
                local logoutBtn = Instance.new("ImageButton")
                logoutBtn.Name = "LogoutButton"
                logoutBtn.AnchorPoint = Vector2.new(1, 0.5)
                logoutBtn.Position = UDim2.new(1, -9, 0.5, 0)
                logoutBtn.Size = UDim2.new(0, 20, 0, 20)
                logoutBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                logoutBtn.BackgroundTransparency = 0.92
                logoutBtn.AutoButtonColor = false
                if logoutIcon then
                    logoutBtn.Image = logoutIcon.Url
                    logoutBtn.ImageRectOffset = logoutIcon.ImageRectOffset or Vector2.zero
                    logoutBtn.ImageRectSize = logoutIcon.ImageRectSize or Vector2.zero
                end
                logoutBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
                logoutBtn.ImageTransparency = 0.15
                logoutBtn.ScaleType = Enum.ScaleType.Fit
                logoutBtn.Parent = accountFrame
                local function FitAccountCard()
                    local W = Tabs.Size.X.Offset
                    accountFrame.Size = UDim2.new(Tabs.Size.X.Scale, W, 0, 44)
                    local Slim = W < 110
                    accountFrame.Visible = not Slim
                    nameLabel.Visible = not Slim
                    eyeBtn.Visible = not Slim
                    logoutBtn.Visible = not Slim
                    avatar.AnchorPoint = Slim and Vector2.new(0.5, 0.5) or Vector2.new(0, 0.5)
                    avatar.Position = Slim and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(0, 10, 0.5, 0)
                    avatarAnonBg.AnchorPoint = avatar.AnchorPoint
                    avatarAnonBg.Position = avatar.Position
                end
                FitAccountCard()
                Library:GiveSignal(Tabs:GetPropertyChangedSignal("Size"):Connect(FitAccountCard))
                local logoutCorner = Instance.new("UICorner")
                logoutCorner.CornerRadius = UDim.new(0, 8)
                logoutCorner.Parent = logoutBtn
                local logoutPad = Instance.new("UIPadding")
                logoutPad.PaddingLeft = UDim.new(0, 4)
                logoutPad.PaddingRight = UDim.new(0, 4)
                logoutPad.PaddingTop = UDim.new(0, 4)
                logoutPad.PaddingBottom = UDim.new(0, 4)
                logoutPad.Parent = logoutBtn
                logoutBtn.MouseEnter:Connect(ObsGuard(function() logoutBtn.BackgroundTransparency = 0.82 end))
                logoutBtn.MouseLeave:Connect(ObsGuard(function() logoutBtn.BackgroundTransparency = 0.92 end))
                pcall(function() Library:AddTooltip("Unloads the entire GUI.", nil, logoutBtn) end)
                logoutBtn.Activated:Connect(ObsGuard(function()
                    Library:Unload()
                end))
            end)
        end
    end

    if Library.IsMobile and WindowInfo.MobileCompact ~= false then
        task.defer(function()
            pcall(function()
                if WindowInfo.EnableCompacting ~= false then
                    Window:SetCompact(true)
                end
            end)
        end)
    end

    Library.Window = Window
    return Window
end

function Library:CreateLoading(LoadingInfo)
    if Library.ActiveLoading then
        do end
        return Library.ActiveLoading
    end

    LoadingInfo = Library:Validate(LoadingInfo, Templates.Loading)

    local Loading = {
        CurrentStep = LoadingInfo.CurrentStep,
        TotalSteps = LoadingInfo.TotalSteps,

        ShowSidebar = LoadingInfo.ShowSidebar,
        AutoResizeHeight = LoadingInfo.AutoResizeHeight,
        AlwaysOnTop = LoadingInfo.AlwaysOnTop,

        IsError = false,
        Destroyed = false,

        WindowWidth = LoadingInfo.WindowWidth,
        WindowHeight = LoadingInfo.WindowHeight,
        BaseWindowHeight = LoadingInfo.WindowHeight,
        WindowErrorHeight = LoadingInfo.WindowHeight,

        ContentWidth = LoadingInfo.ContentWidth,
        SidebarWidth = LoadingInfo.SidebarWidth,
    }

    --// ScreenGui \\--
    local ScreenGui = New("ScreenGui", {
        Name = "AzureLoading",
        DisplayOrder = 999,
        ResetOnSpawn = false
    })
    ParentUI(ScreenGui)
    Loading.ScreenGui = ScreenGui
    SetAlwaysOnTop(ScreenGui, LoadingInfo.AlwaysOnTop)

    ScreenGui.DescendantRemoving:Connect(ObsGuard(function(Instance)
        Library:RemoveFromRegistry(Instance)
        ForgetCorner(Instance)
    end))

    --// Main Frame \\--
    local MainFrame = New("TextButton", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = function()
            return Library:GetBetterColor(Library.Scheme.BackgroundColor, -1)
        end,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(Loading.ShowSidebar and (Loading.ContentWidth + Loading.SidebarWidth) or Loading.WindowWidth, Loading.WindowHeight),
        ClipsDescendants = true,
        Text = "",
        AutoButtonColor = false,
        Parent = ScreenGui,
    })
    Library:AddOutline(MainFrame)
    table.insert(Library.Corners, New("UICorner", { CornerRadius = UDim.new(0, Library.CornerRadius), Parent = MainFrame }))
    
	local MainScale = New("UIScale", {
		Scale = Library.DPIScale,
		Parent = MainFrame
	})
	table.insert(Library.Scales, MainScale)

    --// Layout Containers \\--
    local Container = New("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(0, Loading.ContentWidth, 1, 0),
        Parent = MainFrame,
    })

    local SideBar = New("Frame", {
        Name = "SideBar",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(Loading.ContentWidth, 0),
        Size = UDim2.new(0, Loading.ShowSidebar and Loading.SidebarWidth or 0, 1, 0),
        ClipsDescendants = true,
        Visible = Loading.ShowSidebar,
        Parent = MainFrame,
    })
    local SidebarCorner = New("UICorner", { CornerRadius = UDim.new(0, Library.CornerRadius), Parent = SideBar })
    table.insert(Library.Corners, SidebarCorner)
    
    Library:AddOutline(SideBar)
    
    local SidebarDivider = New("Frame", {
        BackgroundColor3 = "OutlineColor",
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(0, 1, 1, 0),
        Visible = Loading.ShowSidebar,
        Parent = SideBar,
    })

    --// Top Bar \\--
    local TopBar = New("Frame", {
        Name = "TopBar",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 48),
        ZIndex = 2,
        Parent = Container,
    })
    Library:MakeDraggable(MainFrame, TopBar, true, false)

    local TitleHolder = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = TopBar,
    })
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
        Parent = TitleHolder,
    })
    New("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
        Parent = TitleHolder,
    })

    if LoadingInfo.Icon then
        local Icon = Library:GetCustomIcon(LoadingInfo.Icon)
        local _WindowIcon = New("ImageLabel", {
            Image = Icon and Icon.Url or "",
            ImageColor3 = Color3.new(1, 1, 1),
            ImageRectOffset = Icon and Icon.ImageRectOffset or Vector2.zero,
            ImageRectSize = Icon and Icon.ImageRectSize or Vector2.zero,
            Size = LoadingInfo.IconSize,
            Parent = TitleHolder,
        })
        pcall(function()
            Library:AddSharedGradient(_WindowIcon, {})
        end)
    else
        local _WindowIcon = New("TextLabel", {
            BackgroundTransparency = 1,
            Size = LoadingInfo.IconSize,
            Text = LoadingInfo.Title:sub(1, 1),
            TextScaled = true,
            Visible = false,
            Parent = TitleHolder,
        })
    end

    local TitleX = Library:GetTextBounds(
        LoadingInfo.Title,
        Library.Scheme.Font,
        20,
        TitleHolder.AbsoluteSize.X - (LoadingInfo.Icon and (LoadingInfo.IconSize.X.Offset + 6) or 0) - 12
    )
    local _WindowTitle = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, TitleX, 1, 0),
        Text = LoadingInfo.Title,
        TextSize = 20,
        Parent = TitleHolder,
    })
    pcall(function()
        Library:RemoveFromRegistry(_WindowTitle)
    end)
    _WindowTitle.TextColor3 = Color3.new(1, 1, 1)
    pcall(function()
        Library:AddSharedGradient(_WindowTitle, {})
    end)

    Library:MakeLine(Container, {
        Position = UDim2.fromOffset(0, 48),
        Size = UDim2.new(1, 0, 0, 1),
    })

    --// Loading Content Elements \\--
    local InnerContent = New("Frame", {
        Name = "InnerContent",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 49),
        Size = UDim2.new(1, 0, 1, -49),
        Parent = Container,
    })

    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 12),
        Parent = InnerContent,
    })

    local IconHolder = New("Frame", {
        Name = "IconHolder",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(64, 64),
        Parent = InnerContent,
    })

    local LoaderIcon = Library:GetCustomIcon(LoadingInfo.LoadingIcon)
    local LoadingIcon = New("ImageLabel", {
        Name = "LoaderIcon",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        Image = LoaderIcon and LoaderIcon.Url or "",
        ImageRectOffset = LoaderIcon and LoaderIcon.ImageRectOffset or Vector2.zero,
        ImageRectSize = LoaderIcon and LoaderIcon.ImageRectSize or Vector2.zero,
        ImageColor3 = LoadingInfo.LoadingIconColor or ((LoadingInfo.LoadingIcon == Templates.Loading.LoadingIcon) and "AccentColor" or "WhiteColor"),
        Parent = IconHolder,
    })

    local RotationTween
    if LoadingInfo.LoadingIconTweenTime > 0 then
        RotationTween = TweenService:Create(
            LoadingIcon,
            TweenInfo.new(LoadingInfo.LoadingIconTweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
            { Rotation = 360 }
        )
        RotationTween:Play()
    end

    local MessageLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        AutomaticSize = Loading.AutoResizeHeight and Enum.AutomaticSize.Y or Enum.AutomaticSize.XY,
        Size = Loading.AutoResizeHeight and UDim2.new(1, -60, 0, 0) or UDim2.fromOffset(0, 0),
        Text = "",
        TextSize = 18,
        TextWrapped = Loading.AutoResizeHeight,
        Parent = InnerContent,
    })
    pcall(function()
        Library:AddTextShimmer(MessageLabel)
    end)

    local DescriptionLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        AutomaticSize = Loading.AutoResizeHeight and Enum.AutomaticSize.Y or Enum.AutomaticSize.XY,
        Size = Loading.AutoResizeHeight and UDim2.new(1, -60, 0, 0) or UDim2.fromOffset(0, 0),
        Text = "",
        TextSize = 14,
        TextTransparency = 0.5,
        TextWrapped = Loading.AutoResizeHeight,
        Parent = InnerContent,
    })

    --// Progress Bar \\--
    local SliderBar = New("Frame", {
        BackgroundColor3 = "MainColor",
        Size = UDim2.new(0.7, 0, 0, 15),
        Parent = InnerContent,
    })
    Library:AddOutline(SliderBar)
    table.insert(Library.Corners, New("UICorner", { CornerRadius = UDim.new(0, Library.CornerRadius / 2), Parent = SliderBar }))

    local SliderFill = New("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
        Parent = SliderBar,
    })
    pcall(function()
        Library:AddAccentGradient(SliderFill, {})
    end)
    table.insert(Library.Corners, New("UICorner", { CornerRadius = UDim.new(0, Library.CornerRadius / 2), Parent = SliderFill }))
    pcall(function()
        Library:AddSheen(SliderFill)
    end)

    local ProgressLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Text = "",
        TextSize = 14,
        ZIndex = 2,
        Parent = SliderBar,
    })
    New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
        Color = "DarkColor",
        LineJoinMode = Enum.LineJoinMode.Miter,
        Parent = ProgressLabel,
    })

    --// Sidebar Object \\--
    local SidebarScrolling = New("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Size = UDim2.fromScale(1, 1),
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = "OutlineColor",
        Parent = SideBar,
    })
    local SidebarList = New("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = SidebarScrolling,
    })
    New("UIPadding", {
        PaddingBottom = UDim.new(0, 12),
        PaddingLeft = UDim.new(0, 12),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 12),
        Parent = SidebarScrolling,
    })

    local SidebarObject = {
        Elements = {},
        DependencyBoxes = {},
        Tabboxes = {},
        
        BoxHolder = SidebarScrolling,
        Container = SidebarScrolling,
        
        Resize = function(self)
            SidebarScrolling.CanvasSize = UDim2.fromOffset(0, SidebarList.AbsoluteContentSize.Y + 24)
        end,
        Tab = {
            Elements = {},
            DependencyBoxes = {},
            DependencyGroupboxes = {},
            Tabboxes = {},
        },
    }

    SidebarList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(ObsGuard(function()
        SidebarObject:Resize()
    end))

    setmetatable(SidebarObject, BaseGroupbox)
    Loading.Sidebar = SidebarObject

    --// Error Frame \\--
    local ErrorFrame = New("Frame", {
        Name = "Error",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 49),
        Size = UDim2.new(1, 0, 1, -49),
        ClipsDescendants = true,
        Visible = false,
        Parent = Container,
    })

    local _ErrorTitle = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(15, 15),
        Size = UDim2.new(1, -30, 0, 18),
        Text = "Error",
        TextColor3 = "RedColor",
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = ErrorFrame,
    })

    local ErrorLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(15, 39),
        Size = UDim2.new(1, -30, 1, -90),
        Text = "Error Message",
        TextSize = 14,
        TextTransparency = 0.2,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = ErrorFrame,
    })

    local ErrorButtonsDivider = New("Frame", {
        BackgroundColor3 = "OutlineColor",
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 1, -48),
        Size = UDim2.new(1, -30, 0, 1),
        Visible = false,
        Parent = ErrorFrame,
    })

    local ErrorButtonsHolder = New("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 42),
        Visible = false,
        Parent = ErrorFrame,
    })
    New("UIListLayout", {
        Padding = UDim.new(0, 8),
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = ErrorButtonsHolder,
    })
    New("UIPadding", {
        PaddingTop = UDim.new(0, 5),
        PaddingBottom = UDim.new(0, 15),
        PaddingRight = UDim.new(0, 15),
        Parent = ErrorButtonsHolder,
    })

    function Loading:UpdateLayout()
        if Loading.IsError then
            Loading:RecalculateErrorHeight()
        end

        local ShowSidebar = Loading.ShowSidebar
        local FinalWidth = ShowSidebar and (Loading.ContentWidth + Loading.SidebarWidth) or Loading.WindowWidth
        local FinalHeight = Loading.IsError and Loading.WindowErrorHeight or Loading.WindowHeight
        
        if ShowSidebar then
            SideBar.Visible = true
            SidebarDivider.Visible = true
        end

        TweenService:Create(MainFrame, Library.TweenInfo, { Size = UDim2.fromOffset(FinalWidth, FinalHeight) }):Play()
        TweenService:Create(SideBar, Library.TweenInfo, { Position = UDim2.fromOffset(Loading.ContentWidth, 0), Size = UDim2.new(0, ShowSidebar and Loading.SidebarWidth or 0, 1, 0) }):Play()
        TweenService:Create(Container, Library.TweenInfo, { Size = UDim2.new(0, ShowSidebar and Loading.ContentWidth or Loading.WindowWidth, 1, 0) }):Play()

        if not ShowSidebar then
            task.delay(Library.TweenInfo.Time, function()
                if not Loading.ShowSidebar then
                    SideBar.Visible = false
                    SidebarDivider.Visible = false
                end
            end)
        end
    end

    --// Content Page \\--
    function Loading:RecalculateLoadingHeight()
        if not Loading.AutoResizeHeight then
            return
        end

        local RequiredHeight = 
              49 -- TopBar
            + 48 -- Padding
            + InnerContent.UIListLayout.AbsoluteContentSize.Y

        Loading.WindowHeight = math.max(Loading.BaseWindowHeight, RequiredHeight)
    end

    function Loading:SetMessage(Text)
        MessageLabel.Text = Text

        if Loading.AutoResizeHeight then
            Loading:RecalculateLoadingHeight()
            Loading:UpdateLayout()
        end
    end

    function Loading:SetDescription(Text)
        DescriptionLabel.Text = Text

        if Loading.AutoResizeHeight then
            Loading:RecalculateLoadingHeight()
            Loading:UpdateLayout()
        end
    end

    function Loading:SetLoadingIcon(Icon)
        local IconData = Library:GetCustomIcon(Icon)
        assert(IconData, "Image must be a valid Roblox asset or a valid URL or a valid lucide icon.")

        LoadingIcon.Image = IconData.Url
        LoadingIcon.ImageRectOffset = IconData.ImageRectOffset or Vector2.zero
        LoadingIcon.ImageRectSize = IconData.ImageRectSize or Vector2.zero
    end

    function Loading:SetLoadingIconTweenTime(TweenTime)
        if RotationTween then
            StopTween(RotationTween, true)
            RotationTween = nil
        end

        if TweenTime > 0 then
            RotationTween = TweenService:Create(
                LoadingIcon,
                TweenInfo.new(TweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
                { Rotation = 360 }
            )
            RotationTween:Play()
        else
            LoadingIcon.Rotation = 0
        end
    end

    function Loading:SetLoadingIconColor(Color)
        LoadingIcon.ImageColor3 = Color
    end

    function Loading:SetCurrentStep(Step)
        Loading.CurrentStep = math.clamp(Step, 0, Loading.TotalSteps)

        local Progress = Loading.CurrentStep / Loading.TotalSteps
        Library:Spring(SliderFill, "Size", UDim2.fromScale(Progress, 1), 18, 0.9)

        ProgressLabel.Text = string.format("%d/%d", Loading.CurrentStep, Loading.TotalSteps)
    end

    function Loading:SetTotalSteps(Steps)
        Loading.TotalSteps = Steps
        Loading:SetCurrentStep(Loading.CurrentStep)
    end

    --// Size \\--
    function Loading:SetWindowHeight(Height)
        Loading.WindowHeight = Height
        Loading:UpdateLayout()
    end

    function Loading:SetWindowWidth(Width)
        Loading.WindowWidth = Width
        Loading:UpdateLayout()
    end

    function Loading:SetContentWidth(Width)
        Loading.ContentWidth = Width
        Loading:UpdateLayout()
    end

    function Loading:SetSidebarWidth(Width)
        Loading.SidebarWidth = Width
        Loading:UpdateLayout()
    end

    --// Sidebar \\--
    function Loading:ShowSidebarPage(Bool)
        Loading.ShowSidebar = Bool
        Loading:UpdateLayout()
    end

    --// Error Page \\--
    function Loading:ShowErrorPage(Enabled)
        Loading.IsError = Enabled
        InnerContent.Visible = not Enabled
        ErrorFrame.Visible = Enabled

        if Loading.ShowSidebar then
            Loading:ShowSidebarPage(not Enabled)
        else
            Loading:UpdateLayout()
        end
    end

    function Loading:RecalculateErrorHeight()
        local TargetWidth = (Loading.ShowSidebar and Loading.ContentWidth or Loading.WindowWidth) - 30
        local _, ErrorY = Library:GetTextBounds(ErrorLabel.Text, Library.Scheme.Font, 14, TargetWidth)

        ErrorLabel.Size = UDim2.new(1, -30, 0, ErrorY)

        local HasButtons = ErrorButtonsHolder.Visible
        local RequiredHeight =
              49                        -- TopBar
            + 15                        -- Padding Top
            + 18                        -- Title Height
            + 6                         -- Padding between Title and Label
            + ErrorY                    -- Label Height
            + 15                        -- Padding between Label and Buttons
            + (HasButtons and 48 or 0)  -- Buttons Area

        Loading.WindowErrorHeight = RequiredHeight -- math.max(Loading.WindowHeight, RequiredHeight)
    end

    function Loading:SetErrorMessage(Text)
        ErrorLabel.Text = Text
        Loading:UpdateLayout()
    end

    function Loading:SetErrorButtons(Buttons)
        assert(typeof(Buttons) == "table", "Buttons must be a table")

        for _, button in ErrorButtonsHolder:GetChildren() do
            if button:IsA("Frame") then 
                button:Destroy() 
            end
        end

        local HasButtons = GetTableSize(Buttons) > 0
        ErrorButtonsHolder.Visible = HasButtons
        ErrorButtonsDivider.Visible = HasButtons

        for Idx, ButtonInfo in Buttons do
            local ButtonContainer = New("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.fromOffset(0, 26),
                Parent = ErrorButtonsHolder,
            })
            
            local BtnColor = "MainColor"
            local BtnOutline = "OutlineColor"
            local Variant = ButtonInfo.Variant or "Primary"
            
            if Variant == "Primary" then
                BtnColor = "FontColor"
                BtnOutline = "FontColor"
            elseif Variant == "Secondary" then
                BtnColor = "MainColor"
                BtnOutline = "OutlineColor"
            elseif Variant == "Destructive" then
                BtnColor = "DestructiveColor"
                BtnOutline = "DestructiveColor"
            elseif Variant == "Ghost" then
                BtnColor = "BackgroundColor"
                BtnOutline = "BackgroundColor"
            end

            local TextBtn = New("TextButton", {
                BackgroundColor3 = BtnColor,
                BorderColor3 = BtnOutline,
                Size = UDim2.fromOffset(0, 26),
                Text = "",
                AutoButtonColor = false,
                Parent = ButtonContainer,
            })
            Library:AddOutline(TextBtn)
            table.insert(
                Library.Corners,
                New("UICorner", { 
                    CornerRadius = UDim.new(0, Library.CornerRadius), 
                    Parent = TextBtn 
                })
            )

            New("UIPadding", {
                PaddingLeft = UDim.new(0, 15),
                PaddingRight = UDim.new(0, 15),
                Parent = TextBtn,
            })

            local TextColor = Library.Scheme.FontColor
            if Variant == "Primary" then
                TextColor = Library.Scheme.BackgroundColor
            elseif Variant == "Destructive" then
                TextColor = Color3.new(1, 1, 1)
            end

            local BtnLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Text = ButtonInfo.Title or Idx,
                TextColor3 = TextColor,
                TextSize = 14,
                Parent = TextBtn,
            })
            
            local LabelX, _ = Library:GetTextBounds(BtnLabel.Text, Library.Scheme.Font, 14, 250)
            ButtonContainer.Size = UDim2.fromOffset(LabelX + 30, 26)
            TextBtn.Size = UDim2.fromOffset(LabelX + 30, 26)

            local ActiveColor = typeof(BtnColor) == "Color3" and BtnColor or Library.Scheme[BtnColor]
            local HoverColor = Variant == "Ghost" and Library.Scheme.MainColor or Library:GetBetterColor(ActiveColor, 10)

            TextBtn.MouseEnter:Connect(ObsGuard(function()
                TweenService:Create(TextBtn, Library.TweenInfo, {
                    BackgroundColor3 = HoverColor
                }):Play()
            end))
            TextBtn.MouseLeave:Connect(ObsGuard(function()
                TweenService:Create(TextBtn, Library.TweenInfo, {
                    BackgroundColor3 = ActiveColor
                }):Play()
            end))

            TextBtn.MouseButton1Click:Connect(ObsGuard(function()
                if ButtonInfo.Callback then
                    ButtonInfo.Callback(Loading)
                end
            end))
        end

        Loading:UpdateLayout()
    end

    function Loading:SetFooterButtons(Buttons)
        assert(typeof(Buttons) == "table", "Buttons must be a table")
        if SliderBar then SliderBar.Visible = false end
        if Loading._FooterRow then pcall(function() Loading._FooterRow:Destroy() end) end
        local FooterRow = New("Frame", {
            Name = "FooterRow",
            BackgroundTransparency = 1,
            LayoutOrder = 1000,
            Size = UDim2.new(1, -40, 0, 32),
            Parent = InnerContent,
        })
        Loading._FooterRow = FooterRow
        for _, Info in ipairs(Buttons) do
            local IsLeft = Info.Align == "Left"
            local TextBtn = New("TextButton", {
                BackgroundColor3 = "MainColor",
                BorderColor3 = "OutlineColor",
                AutoButtonColor = false,
                Text = "",
                AnchorPoint = IsLeft and Vector2.new(0, 0.5) or Vector2.new(1, 0.5),
                Position = IsLeft and UDim2.new(0, 0, 0.5, 0) or UDim2.new(1, 0, 0.5, 0),
                Size = UDim2.fromOffset(80, 32),
                Parent = FooterRow,
            })
            Library:AddOutline(TextBtn)
            table.insert(Library.Corners, New("UICorner", { CornerRadius = UDim.new(0, Library.CornerRadius), Parent = TextBtn }))
            local BtnLabel = New("TextLabel", {
                BackgroundTransparency = 1,
                Size = UDim2.fromScale(1, 1),
                Text = Info.Title or "",
                TextColor3 = Library.Scheme.FontColor,
                TextSize = 14,
                Parent = TextBtn,
            })
            local LabelX = Library:GetTextBounds(BtnLabel.Text, Library.Scheme.Font, 14, 300)
            TextBtn.Size = UDim2.fromOffset(LabelX + 30, 32)
            local ActiveColor = Library.Scheme.MainColor
            local HoverColor = Library:GetBetterColor(ActiveColor, 10)
            TextBtn.MouseEnter:Connect(ObsGuard(function()
                TweenService:Create(TextBtn, Library.TweenInfo, { BackgroundColor3 = HoverColor }):Play()
            end))
            TextBtn.MouseLeave:Connect(ObsGuard(function()
                TweenService:Create(TextBtn, Library.TweenInfo, { BackgroundColor3 = ActiveColor }):Play()
            end))
            TextBtn.MouseButton1Click:Connect(ObsGuard(function()
                if Info.Callback then Info.Callback(Loading) end
            end))
        end
        Loading:RecalculateLoadingHeight()
        Loading:UpdateLayout()
    end

    --// Destroy/Continue \\--
    function Loading:Destroy()
        if RotationTween then
            StopTween(RotationTween, true)
            RotationTween = nil
        end

        pcall(function()
            Library.MorphFromRect = { Position = MainFrame.AbsolutePosition, Size = MainFrame.AbsoluteSize }
        end)
        if Library.PrewarmWindow then
            pcall(Library.PrewarmWindow)
        end

        ScreenGui:Destroy()
        Loading.Destroyed = true
        Library.ActiveLoading = nil

        if Library.Toggle and Library.Toggled == false and Library.Unloaded ~= true then
            Library:Toggle(true)
        end
    end

    Loading.Continue = Loading.Destroy;

    if Library.Toggle and Library.Toggled and Library.Unloaded ~= true then
        Library:Toggle(false)
    end

    Loading:SetCurrentStep(Loading.CurrentStep)

    Library.ActiveLoading = Loading
    return Loading
end

local function OnPlayerChange()
    if Library.Unloaded then
        return
    end

    local PlayerList, ExcludedPlayerList = GetPlayers(), GetPlayers(true)
    for _, Dropdown in Options do
        if Dropdown.Type == "Dropdown" and Dropdown.SpecialType == "Player" then
            Dropdown:SetValues(Dropdown.ExcludeLocalPlayer and ExcludedPlayerList or PlayerList)
        end
    end
end

local function OnTeamChange()
    if Library.Unloaded then
        return
    end

    local TeamList = GetTeams()
    for _, Dropdown in Options do
        if Dropdown.Type == "Dropdown" and Dropdown.SpecialType == "Team" then
            Dropdown:SetValues(TeamList)
        end
    end
end

Library:GiveSignal(Players.PlayerAdded:Connect(ObsGuard(OnPlayerChange)))
Library:GiveSignal(Players.PlayerRemoving:Connect(ObsGuard(OnPlayerChange)))

Library:GiveSignal(Teams.ChildAdded:Connect(ObsGuard(OnTeamChange)))
Library:GiveSignal(Teams.ChildRemoved:Connect(ObsGuard(OnTeamChange)))

function Library:Unload()
    Library.Unloaded = true
    Library.IsPicking = false
    if CurrentMenu then
        pcall(function()
            CurrentMenu:Close()
        end)
    end
    pcall(function()
        local Genv = getgenv()
        if Genv.__tvlRgbConn and Genv.__tvlRgbConn == Library._rgbConn then
            Genv.__tvlRgbConn = nil
        end
    end)
    for _, key in ipairs({ "_sharedGradConn", "_rgbConn", "_kbGradConn" }) do
        local c = Library[key]
        if c then pcall(function() c:Disconnect() end) Library[key] = nil end
    end
    if Library._sharedGrads then table.clear(Library._sharedGrads) end
    if Library._kbGradTargets then table.clear(Library._kbGradTargets) end
    Library.RgbEnabled = false

    --// Disconnect connections
    for Index = #Library.Signals, 1, -1 do
        local Connection = table.remove(Library.Signals, Index)

        if Connection and Connection.Connected then
            Connection:Disconnect()
        end
    end

    --// Run Unload Callbacks
    for _ = 1, #Library.UnloadSignals do
        local Callback = table.remove(Library.UnloadSignals, 1)

        if Callback then
            Library:SafeCallback(Callback)
        end
    end

    --// Destroy elements
    local TabList = {}
    for _, Tab in pairs(Library.Tabs) do
        table.insert(TabList, Tab)
    end
    for _, Tab in ipairs(TabList) do
        if type(Tab) == "table" and Tab.Destroy and not Tab.Destroyed then
            Library:SafeCallback(Tab.Destroy, Tab)
        end
    end

    for Index = #Tooltips, 1, -1 do
        local Tooltip = table.remove(Tooltips, Index)

        if Tooltip and Tooltip.Destroy then
            Library:SafeCallback(Tooltip.Destroy, Tooltip)
        end
    end

    if Library.ActiveLoading then
        Library.ActiveLoading:Destroy()
    end

    if ScreenGui then
        ScreenGui:Destroy()
    end

    --// Clear tables
    table.clear(Library.Registry)

    table.clear(Options)
    table.clear(Toggles)
    table.clear(Buttons)
    table.clear(Labels)
    table.clear(Tooltips)

    table.clear(Library.Tabs)
    table.clear(Library.TabButtons)

    table.clear(Library.Scales)
    table.clear(Library.ScalesOffset)

    table.clear(Library.Corners)
    table.clear(Library.SpecificCorners)

    table.clear(Library.Notifications)
    table.clear(Library.Dialogues)
    table.clear(Library.DraggableElements)
    table.clear(Library.KeybindToggles)
    table.clear(Library.DependencyBoxes)

    table.clear(TransparencyCache)
    table.clear(ActiveTabTweens)
    
    Library.Toggle = function(...) end
    Library.ScreenGui = nil
    Library.WindowContainer = nil
    Library.KeybindFrame = nil
    Library.KeybindContainer = nil

    if rawget(getgenv(), "Library") == Library then
        getgenv().Library = nil
    end
end

getgenv().Library = Library
return Library
