--!strict
-- LarpingHubUI
-- Faithful UI extraction of the original script's visual/UI layer.
-- Includes:
--   * Main Larping Hub window
--   * 5-tab sidebar (Overview / Settings / Keybinds / Miscs / Support)
--   * Target HUD
--   * FPS / Ping / Kills / Low HP stats sidebar
--   * Notifications
--   * Loading screen + progress API
--   * Generic confirmation modal
--   * Dragging, resizing, hover/pulse effects, keybind capture
--
-- Intentionally removed from the original:
--   * Discord URLs / invite links
--   * Webhook URLs / execution logging
--   * Remote Loading.lua fetching
--   * Gameplay/targeting/fling/recovery implementation
--
-- Gameplay features are exposed as callbacks so the UI can live in a repo as a reusable ModuleScript.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local localPlayer = Players.LocalPlayer

local UI = {}
UI.__index = UI

local PX = {
    bg = Color3.fromRGB(14, 14, 18),
    bgMid = Color3.fromRGB(20, 20, 28),
    bgLight = Color3.fromRGB(32, 32, 42),
    panel = Color3.fromRGB(18, 18, 24),
    line = Color3.fromRGB(66, 72, 102),
    lineSoft = Color3.fromRGB(40, 43, 58),
    text = Color3.fromRGB(228, 232, 248),
    dim = Color3.fromRGB(122, 130, 156),
    accent = Color3.fromRGB(122, 226, 164),
    warn = Color3.fromRGB(240, 200, 90),
    bad = Color3.fromRGB(240, 110, 110),
    special = Color3.fromRGB(200, 130, 255),
    info = Color3.fromRGB(140, 180, 255),
}

local FONT_TITLE = Enum.Font.Arcade
local FONT_BODY = Enum.Font.Code
local FONT_UI = Enum.Font.Gotham

local SOUNDS = {
    Click = "rbxassetid://139719503904449",
    Notification = "rbxassetid://7060363375",
    Close = "rbxassetid://139403951941162",
    Open = "rbxassetid://139403951941162",
    Warning = "rbxassetid://90035739456316",
}

local DEFAULT_KEYBINDS = {
    Stop = "O", CancelQ = "C", Recovery = "M",
    Q = nil, QAlt1 = "One", QAlt2 = "Two", QAlt3 = "Three", QAlt4 = "Four",
    Camera = "K", Sidebar = "N", VCycle = "V", Prediction = "P",
    InstantInteract = "I", Smart = "Y", Position = "U",
    RecoveryOnAttack = "J", HUD = "H", PreviousTarget = "E",
    CycleTarget = "R", ClearTarget = "T", HoldBack = "Five",
    LockOn = nil, FlingTarget = nil, ToggleWalkFling = nil,
    Respawn = nil, ResetDefaults = nil,
    Autocombo = nil, AutoQ = "X",
    ToggleUnderVictim = nil,
}

local KEYBIND_ORDER = {
    { "Autocombo", "AUTOCOMBO" }, { "AutoQ", "AUTO Q" },
    { "ToggleUnderVictim", "TOGGLE UNDER-VICTIM" },
    { "Q", "Q (optional)" }, { "QAlt1", "Q ALT 1" }, { "QAlt2", "Q ALT 2" },
    { "QAlt3", "Q ALT 3" }, { "QAlt4", "Q ALT 4" },
    { "LockOn", "TOGGLE LOCK-ON" }, { "FlingTarget", "FLING TARGET" },
    { "ToggleWalkFling", "TOGGLE WALKFLING" }, { "Respawn", "FORCE RESPAWN" },
    { "ResetDefaults", "RESET TO DEFAULT" }, { "Stop", "STOP" },
    { "CancelQ", "CANCEL Q" }, { "Recovery", "RECOVERY" },
    { "Camera", "CAMERA" }, { "Sidebar", "SIDEBAR" }, { "VCycle", "V CYCLE" },
    { "Prediction", "PREDICTION" }, { "InstantInteract", "INSTANT INTERACT" },
    { "Smart", "SMART" }, { "Position", "POSITION" },
    { "RecoveryOnAttack", "RECOVERY ON ATTACK" }, { "HUD", "HUD" },
    { "PreviousTarget", "PREV TARGET" }, { "CycleTarget", "CYCLE TARGET" },
    { "ClearTarget", "CLEAR TARGET" }, { "HoldBack", "HOLD BACK" },
}

local RESERVED_KEYS = {
    W = true, A = true, S = true, D = true,
    F = true, G = true, B = true, Q = true,
    RightShift = true,
}

local DEFAULTS = {
    Name = "LarpingHub",
    DisplayOrder = 1001,
    HubSize = { width = 660, height = 440 },
    HubPosition = UDim2.fromScale(0.5, 0.5),
    HubVisible = true,
    SidebarWidth = 150,
    NotificationWidth = 340,
    NotificationDuration = 3,
    EntranceDuration = 0.55,

    Title = "LARPING HUB",
    Subtitle = "V1 // WIP MADE BY LARPINGHUB!",
    LiveText = "> ACTIVE",

    Overview = {
        ThanksTitle = "THANKS FOR USING!",
        ThanksDescription = "V1 of this script! Bugs are expected and its not perfect!",
        ToggleTitle = "HUB TOGGLE",
        ToggleDescription = "Press Right Shift to open/close. Drag header to move. Drag bottom-right grip to resize.",
        TipsTitle = "TIPS if you are having problems!",
        TipsDescription = "Incase you have problems send a support message through the support tab.",
        TargetTitle = "TARGET",
        TargetDescription = "No target selected",
    },

    Support = {
        HelpTitle = "NEED HELP?",
        HelpDescription = "Use the support callback for help and updates.",
        FeedbackTitle = "SEND FEEDBACK",
        FeedbackDescription = "Bug reports, feature requests, general feedback.",
    },

    SettingsState = {
        ["Under Victim (recommended)"] = true,
        ["Lock-On / Follow"] = true,
        ["Autocombo (Auto M1)"] = false,
        ["Auto Q (Finisher)"] = false,
        ["Smart Targeting"] = true,
        ["Smart Position"] = true,
        ["Smart Recovery"] = true,
        ["Adaptive Prediction"] = true,
        ["Victim Camera"] = true,
        ["HUD"] = true,
        ["Sidebar"] = true,
        ["Prediction"] = true,
        ["Instant Interact"] = true,
        ["Recovery on Attack"] = true,
        ["Anti Fling / Anti Void"] = true,
        ["Enable Walkfling"] = false,
        ["No Block Animation"] = false,
        ["No Animations At All"] = false,
    },

    Settings = {},

    Keybinds = table.clone(DEFAULT_KEYBINDS),

    OnAction = nil,
    OnSettingChanged = nil,
    OnKeybindChanged = nil,
    OnDiscord = nil,
    OnFeedback = nil,
    OnFling = nil,
    OnRespawn = nil,
    OnStop = nil,
    OnSaveSettings = nil,
    OnResetSettings = nil,
    OnPlaySound = nil,
}

local function cloneDictionary(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = value
    end
    return result
end

local function deepMerge(base, overrides)
    local result = cloneDictionary(base)
    for key, value in pairs(overrides or {}) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = deepMerge(result[key], value)
        else
            result[key] = value
        end
    end
    return result
end

local function create(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function liftColor(color, amount)
    local scale = math.clamp(amount / 100, 0, 1)
    return color:Lerp(Color3.new(1, 1, 1), scale)
end

local function pulseElement(element, targetTransparency, duration)
    if not element or not element.Parent then return end
    local original = element.BackgroundTransparency
    local first = TweenService:Create(element, TweenInfo.new(duration or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundTransparency = targetTransparency,
    })
    local second = TweenService:Create(element, TweenInfo.new(duration or 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        BackgroundTransparency = original,
    })
    first:Play()
    first.Completed:Wait()
    second:Play()
end

local function pulseStroke(stroke, targetThickness, duration)
    if not stroke or not stroke.Parent then return end
    local original = stroke.Thickness
    local first = TweenService:Create(stroke, TweenInfo.new(duration or 0.25), { Thickness = targetThickness })
    local second = TweenService:Create(stroke, TweenInfo.new(duration or 0.25), { Thickness = original })
    first:Play()
    first.Completed:Wait()
    second:Play()
end

function UI:_connect(connection)
    table.insert(self._connections, connection)
    return connection
end

function UI:_playSound(soundId, volume, pitch)
    if not self.Options.EnableSounds or not soundId then return end
    if type(self.Options.OnPlaySound) == "function" then
        pcall(self.Options.OnPlaySound, soundId, volume or 0.5, pitch or 1)
    end
    pcall(function()
        local folder = SoundService:FindFirstChild("LarpingHubUISounds")
        if not folder then
            folder = Instance.new("Folder")
            folder.Name = "LarpingHubUISounds"
            folder.Parent = SoundService
        end
        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = volume or 0.5
        sound.PlaybackSpeed = pitch or 1
        sound.Parent = folder
        sound:Play()
        Debris:AddItem(sound, 6)
    end)
end

function UI.new(options)
    local self = setmetatable({}, UI)
    self.Options = deepMerge(DEFAULTS, options or {})
    self.Player = self.Options.Player or localPlayer
    assert(self.Player, "LarpingHubUI.new() must run on the client with LocalPlayer")

    self._destroyed = false
    self._connections = {}
    self._ownedGuis = {}
    self._notifications = {}
    self._loading = nil
    self._keybindButtons = {}
    self._settingRows = {}
    self._pages = {}
    self._selectedPage = "Main"
    self._waitingForKeybind = nil
    self.State = cloneDictionary(self.Options.SettingsState)
    self.Keybinds = cloneDictionary(self.Options.Keybinds)
    self.LastTargetInfo = self.Options.Overview.TargetDescription

    self.PlayerGui = self.Player:WaitForChild("PlayerGui")

    self.NotificationGui = self:_makeNotificationGui()
    self.NotificationHolder = self.NotificationGui:FindFirstChild("Notifications") :: Frame

    return self
end

function UI:_makeNotificationGui()
    local existing = self.PlayerGui:FindFirstChild("LarpingHubNotifications")
    if existing then existing:Destroy() end
    local gui = create("ScreenGui", {
        Name = "LarpingHubNotifications",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = self.Options.DisplayOrder + 50,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, self.PlayerGui)
    table.insert(self._ownedGuis, gui)

    local holder = create("Frame", {
        Name = "Notifications",
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -24, 1, -24),
        Size = UDim2.fromOffset(self.Options.NotificationWidth, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        ZIndex = 900,
    }, gui)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 8),
    }, holder)
    return gui
end

function UI:Notify(titleOrMessage, description, durationOrOptions)
    if self._destroyed then return end

    local options
    if type(titleOrMessage) == "table" then
        options = titleOrMessage
    else
        options = {
            Title = titleOrMessage,
            Description = description,
        }
        if type(durationOrOptions) == "number" then
            options.Duration = durationOrOptions
        elseif type(durationOrOptions) == "table" then
            options = deepMerge(options, durationOrOptions)
        end
    end

    local title = tostring(options.Title or "Notification")
    local message = tostring(options.Description or options.Message or "")
    local kind = tostring(options.Type or "Info")
    local accent = options.Color or ({
        Success = PX.accent,
        Info = PX.info,
        Warning = PX.warn,
        Error = PX.bad,
    })[kind] or PX.accent
    local duration = tonumber(options.Duration)
    if duration == nil then duration = self.Options.NotificationDuration end

    self:_playSound(SOUNDS.Notification, 0.4, 1)

    local holder = self.NotificationHolder
    local frame = create("Frame", {
        Name = "Notification",
        Size = UDim2.new(1, 0, 0, options.Height or 72),
        BackgroundColor3 = PX.bg,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        LayoutOrder = #self._notifications + 1,
    }, holder)
    table.insert(self._notifications, frame)

    create("UIStroke", { Color = accent, Thickness = 1.5, Transparency = 0.15 }, frame)
    create("Frame", { Name = "Accent", Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = accent, BorderSizePixel = 0 }, frame)
    create("TextLabel", {
        Name = "Title", Position = UDim2.fromOffset(16, 9), Size = UDim2.new(1, -28, 0, 20),
        BackgroundTransparency = 1, Font = FONT_UI, Text = title, TextColor3 = PX.text, TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }, frame)
    create("TextLabel", {
        Name = "Description", Position = UDim2.fromOffset(16, 31), Size = UDim2.new(1, -28, 1, -38),
        BackgroundTransparency = 1, Font = FONT_BODY, Text = message, TextColor3 = PX.dim, TextSize = 12,
        TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    }, frame)

    frame.Position = UDim2.fromOffset(24, 0)
    frame.BackgroundTransparency = 1
    TweenService:Create(frame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Position = UDim2.fromOffset(0, 0), BackgroundTransparency = 0.05,
    }):Play()

    task.delay(math.max(0, duration), function()
        if self._destroyed or not frame.Parent then return end
        local tween = TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.fromOffset(24, 0), BackgroundTransparency = 1,
        })
        tween:Play()
        tween.Completed:Wait()
        for index, notification in ipairs(self._notifications) do
            if notification == frame then
                table.remove(self._notifications, index)
                break
            end
        end
        if frame.Parent then frame:Destroy() end
    end)

    return frame
end

function UI:CreateFrame(parent, options)
    options = options or {}
    local frame = create("Frame", {
        Name = options.Name or "Frame",
        Size = options.Size or UDim2.new(1, 0, 0, 40),
        Position = options.Position or UDim2.new(),
        AnchorPoint = options.AnchorPoint or Vector2.zero,
        BackgroundColor3 = options.BackgroundColor3 or PX.panel,
        BackgroundTransparency = options.BackgroundTransparency or 0,
        BorderSizePixel = 0,
        LayoutOrder = options.LayoutOrder or 0,
    }, parent or self.Root or self.PlayerGui)
    if options.CornerRadius then
        create("UICorner", { CornerRadius = options.CornerRadius }, frame)
    end
    if options.StrokeColor then
        create("UIStroke", {
            Color = options.StrokeColor,
            Thickness = options.StrokeThickness or 1,
            Transparency = options.StrokeTransparency or 0,
        }, frame)
    end
    return frame
end

function UI:CreateText(parent, options)
    options = options or {}
    return create("TextLabel", {
        Name = options.Name or "Text",
        Size = options.Size or UDim2.new(1, 0, 0, 24),
        Position = options.Position or UDim2.new(),
        AnchorPoint = options.AnchorPoint or Vector2.zero,
        BackgroundTransparency = 1,
        Font = options.Font or FONT_BODY,
        Text = options.Text or "",
        TextColor3 = options.TextColor3 or PX.text,
        TextSize = options.TextSize or 14,
        TextWrapped = options.TextWrapped or false,
        TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Left,
        TextYAlignment = options.TextYAlignment or Enum.TextYAlignment.Center,
        LayoutOrder = options.LayoutOrder or 0,
    }, parent or self.Root or self.PlayerGui)
end

function UI:CreateButton(parent, options)
    options = options or {}
    local button = create("TextButton", {
        Name = options.Name or "Button",
        Size = options.Size or UDim2.new(1, 0, 0, 36),
        Position = options.Position or UDim2.new(),
        AnchorPoint = options.AnchorPoint or Vector2.zero,
        LayoutOrder = options.LayoutOrder or 0,
        BackgroundColor3 = options.BackgroundColor3 or PX.bgLight,
        BackgroundTransparency = options.BackgroundTransparency or 0,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = options.Text or "Button",
        TextColor3 = options.TextColor3 or PX.text,
        TextSize = options.TextSize or 14,
        Font = options.Font or FONT_UI,
        TextWrapped = options.TextWrapped or false,
        Parent = parent,
    }, parent)

    local stroke = create("UIStroke", {
        Color = options.StrokeColor or PX.accent,
        Thickness = options.StrokeThickness or 1,
        Transparency = options.StrokeTransparency == nil and 0.4 or options.StrokeTransparency,
    }, button)
    local base = button.BackgroundColor3
    local hover = options.HoverColor or liftColor(base, 14)

    self:_connect(button.MouseEnter:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = hover }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.12), { Transparency = 0.05 }):Play()
    end))
    self:_connect(button.MouseLeave:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.12), { Transparency = options.StrokeTransparency == nil and 0.4 or options.StrokeTransparency }):Play()
    end))
    if type(options.Callback) == "function" then
        self:_connect(button.Activated:Connect(function() options.Callback(button) end))
    end
    return button
end

function UI:CreateButtonRow(parent, buttons, options)
    options = options or {}
    local row = create("Frame", {
        Name = options.Name or "ButtonRow",
        Size = options.Size or UDim2.new(1, 0, 0, options.Height or 40),
        BackgroundTransparency = 1,
    }, parent)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = options.HorizontalAlignment or Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, options.Padding or 10),
    }, row)
    for _, buttonOptions in ipairs(buttons or {}) do
        self:CreateButton(row, buttonOptions)
    end
    return row
end

function UI:_animateEntrance(root)
    if not root then return end
    local originalSize = root.Size
    local originalTransparency = root.BackgroundTransparency
    root.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset * 0.85, originalSize.Y.Scale, originalSize.Y.Offset * 0.85)
    root.BackgroundTransparency = math.max(originalTransparency, 0.25)
    TweenService:Create(root, TweenInfo.new(self.Options.EntranceDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = originalSize, BackgroundTransparency = originalTransparency,
    }):Play()
end

function UI:_makeTab(sidebar, textValue, order)
    local button = create("TextButton", {
        LayoutOrder = order,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = PX.bg,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 7,
    }, sidebar)
    local stroke = create("UIStroke", { Color = PX.lineSoft, Thickness = 1 }, button)
    local accentBar = create("Frame", {
        Name = "AccentBar", Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = PX.accent,
        BorderSizePixel = 0, BackgroundTransparency = 1,
    }, button)
    local label = create("TextLabel", {
        Name = "TabLabel", Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1, Text = textValue, TextColor3 = PX.dim, TextSize = 14, Font = FONT_TITLE,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    }, button)

    local base = PX.bg
    self:_connect(button.MouseEnter:Connect(function()
        if self._selectedPage ~= self:_pageNameFromTab(textValue) then
            TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = liftColor(base, 14) }):Play()
        end
    end))
    self:_connect(button.MouseLeave:Connect(function()
        if self._selectedPage ~= self:_pageNameFromTab(textValue) then
            TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
        end
    end))

    return button, stroke, label, accentBar
end

function UI:_pageNameFromTab(tab)
    return ({ OVERVIEW = "Main", SETTINGS = "Settings", KEYBINDS = "Keybinds", MISCS = "Miscs", SUPPORT = "Support" })[tab]
end

function UI:_makePage(content)
    local page = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4, ScrollBarImageColor3 = PX.line, Visible = false,
    }, content)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
        PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 22),
    }, page)
    create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    return page
end

function UI:_sectionLabel(parent, textValue)
    return create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
        Text = ">> " .. textValue, TextColor3 = PX.dim, TextSize = 12, Font = FONT_BODY,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, parent)
end

function UI:_infoCard(parent, titleText, descText, height)
    local card = create("Frame", {
        Size = UDim2.new(1, 0, 0, height or 88), BackgroundColor3 = PX.panel, BorderSizePixel = 0,
    }, parent)
    create("UIStroke", { Color = PX.lineSoft, Thickness = 1 }, card)
    create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, 10),
        Text = titleText, TextColor3 = PX.text, TextSize = 14, Font = FONT_TITLE, TextXAlignment = Enum.TextXAlignment.Left,
    }, card)
    local desc = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -24, 0, (height or 88) - 38), Position = UDim2.fromOffset(12, 32),
        Text = descText, TextColor3 = PX.dim, TextSize = 12, Font = FONT_BODY, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    }, card)
    return card, desc
end

function UI:_makeToggle(parent, name, defaultValue, onChanged)
    local row = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = PX.panel, BorderSizePixel = 0,
        Text = "", AutoButtonColor = false,
    }, parent)
    local stroke = create("UIStroke", { Color = PX.lineSoft, Thickness = 1 }, row)
    create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(12, 0),
        Text = name, TextColor3 = PX.text, TextSize = 13, Font = FONT_BODY,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    }, row)
    local stateLabel = create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromOffset(56, 20), Position = UDim2.new(1, -64, 0.5, -10),
        TextSize = 14, Font = FONT_TITLE, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
    }, row)

    self.State[name] = defaultValue ~= nil and defaultValue or self.State[name] == true
    local function refresh()
        local enabled = self.State[name] == true
        stateLabel.Text = enabled and "[ON]" or "[OFF]"
        stateLabel.TextColor3 = enabled and PX.accent or PX.dim
    end

    self:_connect(row.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = liftColor(PX.panel, 14) }):Play()
    end))
    self:_connect(row.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = PX.panel }):Play()
    end))
    self:_connect(row.Activated:Connect(function()
        self:_playSound(SOUNDS.Click, 0.5, 1)
        self.State[name] = not self.State[name]
        if type(onChanged) == "function" then pcall(onChanged, self.State[name], self) end
        if type(self.Options.OnSettingChanged) == "function" then pcall(self.Options.OnSettingChanged, name, self.State[name], self) end
        refresh()
        task.spawn(pulseElement, row, 0.55, 0.12)
        task.spawn(pulseStroke, stroke, 2.5, 0.12)
    end))

    refresh()
    self._settingRows[name] = refresh
    return row
end

function UI:_makeKeybind(parent, actionName, displayName)
    local row = create("TextButton", {
        Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = PX.panel, BorderSizePixel = 0,
        Text = "", AutoButtonColor = false,
    }, parent)
    create("UIStroke", { Color = PX.lineSoft, Thickness = 1 }, row)
    create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(12, 0),
        Text = displayName, TextColor3 = PX.text, TextSize = 12, Font = FONT_BODY,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    }, row)
    local keyLabel = create("TextLabel", {
        BackgroundColor3 = PX.bgLight, Size = UDim2.fromOffset(78, 24), Position = UDim2.new(1, -90, 0.5, -12),
        TextColor3 = PX.accent, TextSize = 13, Font = FONT_TITLE,
        TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
    }, row)

    local function refresh()
        keyLabel.Text = self.Keybinds[actionName] or "NONE"
    end
    refresh()

    self:_connect(row.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = liftColor(PX.panel, 14) }):Play()
    end))
    self:_connect(row.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = PX.panel }):Play()
    end))
    self:_connect(row.Activated:Connect(function()
        self:_playSound(SOUNDS.Click, 0.5, 1)
        self._waitingForKeybind = actionName
        keyLabel.Text = "PRESS"
        self:Notify("Keybind", "Press a key to bind " .. displayName, 2)
    end))

    self._keybindButtons[actionName] = { button = row, refresh = refresh, label = keyLabel }
    return row
end

function UI:_bindKeyCapture()
    if self._keyCaptureBound then return end
    self._keyCaptureBound = true
    self:_connect(UserInputService.InputBegan:Connect(function(input, processed)
        if processed or not self._waitingForKeybind then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
        local key = input.KeyCode
        local keyName = key.Name
        if RESERVED_KEYS[keyName] then
            self:Notify("Keybind", "That key is reserved (W A S D F G B Q cannot be used).", 3, { Type = "Warning" })
            return
        end
        if key == Enum.KeyCode.Escape then
            local cancelledAction = self._waitingForKeybind
            self._waitingForKeybind = nil
            local buttonInfo = self._keybindButtons[cancelledAction]
            if buttonInfo then buttonInfo.refresh() end
            return
        end

        local actionName = self._waitingForKeybind
        self._waitingForKeybind = nil
        if not actionName then return end

        self.Keybinds[actionName] = keyName
        local buttonInfo = self._keybindButtons[actionName]
        if buttonInfo then buttonInfo.refresh() end
        if type(self.Options.OnKeybindChanged) == "function" then
            pcall(self.Options.OnKeybindChanged, actionName, keyName, self)
        end
        self:Notify("Keybind", "Keybind changed to " .. keyName .. ".", 2, { Type = "Success" })
    end))
end

function UI:_buildHub()
    if self.HubGui and self.HubGui.Parent then self.HubGui:Destroy() end

    local gui = create("ScreenGui", {
        Name = self.Options.Name, ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = self.Options.DisplayOrder,
    }, self.PlayerGui)
    table.insert(self._ownedGuis, gui)
    self.HubGui = gui

    local size = self.Options.HubSize
    local main = create("Frame", {
        Name = "Main", Size = UDim2.fromOffset(size.width, size.height), Position = self.Options.HubPosition,
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = PX.bg, BorderSizePixel = 0, ClipsDescendants = false,
    }, gui)
    self.HubMain = main
    create("UIStroke", { Color = PX.line, Thickness = 2 }, main)

    local header = create("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = PX.bgMid, BorderSizePixel = 0 }, main)
    create("Frame", { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = PX.line, BorderSizePixel = 0 }, header)
    create("Frame", { Size = UDim2.fromOffset(4, 34), Position = UDim2.new(0, 12, 0.5, -17), BackgroundColor3 = PX.accent, BorderSizePixel = 0 }, header)
    create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -160, 0, 22), Position = UDim2.fromOffset(26, 8),
        Text = self.Options.Title, TextColor3 = PX.text, TextSize = 18, Font = FONT_TITLE, TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.new(1, -160, 0, 16), Position = UDim2.fromOffset(26, 31),
        Text = self.Options.Subtitle, TextColor3 = PX.dim, TextSize = 12, Font = FONT_BODY, TextXAlignment = Enum.TextXAlignment.Left,
    }, header)
    create("TextLabel", {
        BackgroundTransparency = 1, Size = UDim2.fromOffset(70, 20), Position = UDim2.new(1, -110, 0, 9),
        Text = self.Options.LiveText, TextColor3 = PX.accent, TextSize = 12, Font = FONT_BODY, TextXAlignment = Enum.TextXAlignment.Right,
    }, header)

    local close = self:CreateButton(header, {
        Name = "Close", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -42, 0, 13),
        Text = "X", TextColor3 = PX.text, TextSize = 16, Font = FONT_TITLE,
        BackgroundColor3 = PX.bgLight, StrokeColor = PX.bgLight, StrokeTransparency = 1,
        HoverColor = liftColor(PX.bgLight, 30),
        Callback = function()
            self:SetHubVisible(false, true)
            self:_playSound(SOUNDS.Close, 0.5, 1)
        end,
    })
    close.ZIndex = 10

    local sidebar = create("Frame", {
        Name = "Sidebar", Size = UDim2.new(0, self.Options.SidebarWidth, 1, -56), Position = UDim2.fromOffset(0, 56),
        BackgroundColor3 = PX.bgMid, BorderSizePixel = 0, ZIndex = 5,
    }, main)
    create("Frame", { Size = UDim2.new(0, 2, 1, 0), Position = UDim2.new(1, -2, 0, 0), BackgroundColor3 = PX.line, BorderSizePixel = 0 }, sidebar)
    create("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 12) }, sidebar)
    create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, sidebar)

    local content = create("Frame", {
        Name = "Content", Size = UDim2.new(1, -self.Options.SidebarWidth, 1, -56), Position = UDim2.new(0, self.Options.SidebarWidth, 0, 56),
        BackgroundColor3 = PX.bg, BorderSizePixel = 0,
    }, main)

    local tabs = {}
    local tabDefinitions = {
        { "OVERVIEW", "Main" }, { "SETTINGS", "Settings" }, { "KEYBINDS", "Keybinds" },
        { "MISCS", "Miscs" }, { "SUPPORT", "Support" },
    }
    for index, definition in ipairs(tabDefinitions) do
        local tab = self:_makeTab(sidebar, definition[1], index)
        tabs[definition[2]] = tab
    end
    self._tabs = tabs

    local pages = {
        Main = self:_makePage(content), Settings = self:_makePage(content), Keybinds = self:_makePage(content),
        Miscs = self:_makePage(content), Support = self:_makePage(content),
    }
    self._pages = pages

    -- Overview
    self:_sectionLabel(pages.Main, "ABOUT")
    self:_infoCard(pages.Main, self.Options.Overview.ThanksTitle, self.Options.Overview.ThanksDescription)
    self:_infoCard(pages.Main, self.Options.Overview.ToggleTitle, self.Options.Overview.ToggleDescription)
    self:_infoCard(pages.Main, self.Options.Overview.TipsTitle, self.Options.Overview.TipsDescription)
    self:_sectionLabel(pages.Main, "CURRENT")
    local _, targetDesc = self:_infoCard(pages.Main, self.Options.Overview.TargetTitle, self.Options.Overview.TargetDescription)
    self.TargetDescriptionLabel = targetDesc

    self:CreateButton(pages.Main, {
        Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = PX.bgLight,
        Text = "JOIN DISCORD", TextColor3 = PX.accent, TextSize = 14, Font = FONT_UI,
        Callback = function()
            if type(self.Options.OnDiscord) == "function" then pcall(self.Options.OnDiscord, self) end
        end,
    })

    -- Settings
    self:_sectionLabel(pages.Settings, "COMBAT")
    for _, name in ipairs({
        "Under Victim (recommended)", "Lock-On / Follow",
        "Autocombo (Auto M1)", "Auto Q (Finisher)",
    }) do
        self:_makeToggle(pages.Settings, name, self.State[name], nil)
    end

    self:_sectionLabel(pages.Settings, "BEHAVIOR")
    for _, name in ipairs({
        "Smart Targeting", "Smart Position", "Smart Recovery", "Adaptive Prediction", "Victim Camera",
        "HUD", "Sidebar", "Prediction", "Instant Interact", "Recovery on Attack",
    }) do
        self:_makeToggle(pages.Settings, name, self.State[name], nil)
    end
    self:CreateButton(pages.Settings, {
        Text = "SAVE SETTINGS", Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = PX.bgLight,
        TextColor3 = PX.accent, TextSize = 14, Font = FONT_TITLE,
        Callback = function()
            local ok = true
            if type(self.Options.OnSaveSettings) == "function" then
                local result = self.Options.OnSaveSettings(self.State, self.Keybinds, self)
                if result == false then ok = false end
            end
            self:Notify("Settings", ok and "Settings saved." or "Settings could not be saved.", 2, { Type = ok and "Success" or "Error" })
        end,
    })
    self:CreateButton(pages.Settings, {
        Text = "RESET TO DEFAULT", Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = PX.bgLight,
        TextColor3 = PX.warn, TextSize = 14, Font = FONT_TITLE,
        Callback = function()
            self:ResetSettings()
            if type(self.Options.OnResetSettings) == "function" then pcall(self.Options.OnResetSettings, self) end
            self:Notify("Settings", "Settings reset to default.", 3, { Type = "Warning" })
        end,
    })

    -- Keybinds
    self:_sectionLabel(pages.Keybinds, "CONTROLS")
    self:_sectionLabel(pages.Keybinds, "RESERVED (W A S D F G B Q)")
    create("TextLabel", {
        Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1,
        Text = "These keys are reserved for movement and game controls. The UI will never bind them.",
        TextColor3 = PX.dim, TextSize = 11, Font = FONT_BODY, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    }, pages.Keybinds)
    for _, item in ipairs(KEYBIND_ORDER) do self:_makeKeybind(pages.Keybinds, item[1], item[2]) end
    self:_sectionLabel(pages.Keybinds, "NOTE")
    self:_infoCard(pages.Keybinds, "RIGHT SHIFT", "Reserved for opening/closing the hub.", 60)

    -- Miscs
    self:_sectionLabel(pages.Miscs, "FLING / MOVEMENT")
    for _, name in ipairs({ "Anti Fling / Anti Void", "Enable Walkfling", "No Block Animation", "No Animations At All" }) do
        self:_makeToggle(pages.Miscs, name, self.State[name], function(value)
            if name == "Enable Walkfling" then
                self:Notify("Walkfling", value and "Walkfling ON." or "Walkfling OFF.", value and 5 or 2)
            end
        end)
    end
    self:_sectionLabel(pages.Miscs, "FOLLOW MODE")
    self:_infoCard(pages.Miscs, "UNDER-VICTIM", "When ON you sit DIRECTLY BELOW your target, facing up. Their melee arc passes over your head. Toggle on the Settings tab.")
    self:_sectionLabel(pages.Miscs, "ACTIONS")
    self:CreateButton(pages.Miscs, {
        Text = "FLING CURRENT TARGET", Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = PX.bgLight,
        TextColor3 = PX.bad, TextSize = 14, Font = FONT_UI, StrokeColor = PX.bad, StrokeThickness = 2,
        Callback = function() if type(self.Options.OnFling) == "function" then pcall(self.Options.OnFling, self) end end,
    })
    self:CreateButton(pages.Miscs, {
        Text = "FORCE RESPAWN", Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = PX.bgLight,
        TextColor3 = PX.warn, TextSize = 14, Font = FONT_UI, StrokeColor = PX.warn, StrokeThickness = 2,
        Callback = function()
            local confirmed = self:ShowConfirmation("ARE YOU SURE?", "Force respawn your character?", "CANCEL", "FORCE RESPAWN", PX.warn)
            if confirmed and type(self.Options.OnRespawn) == "function" then pcall(self.Options.OnRespawn, self) end
        end,
    })
    self:CreateButton(pages.Miscs, {
        Text = "SAVE MISCS SETTINGS", Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = PX.bgLight,
        TextColor3 = PX.accent, TextSize = 14, Font = FONT_TITLE,
        Callback = function()
            local ok = true
            if type(self.Options.OnSaveSettings) == "function" then
                local result = self.Options.OnSaveSettings(self.State, self.Keybinds, self)
                if result == false then ok = false end
            end
            self:Notify("Settings", ok and "Miscs settings saved." or "Miscs settings could not be saved.", 2, { Type = ok and "Success" or "Error" })
        end,
    })

    -- Support
    self:_sectionLabel(pages.Support, "SUPPORT")
    self:_infoCard(pages.Support, self.Options.Support.HelpTitle, self.Options.Support.HelpDescription)
    self:CreateButton(pages.Support, {
        Text = "JOIN DISCORD", Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = PX.bgLight,
        TextColor3 = PX.accent, TextSize = 14, Font = FONT_UI,
        Callback = function() if type(self.Options.OnDiscord) == "function" then pcall(self.Options.OnDiscord, self) end end,
    })
    self:_sectionLabel(pages.Support, "FEEDBACK")
    self:_infoCard(pages.Support, self.Options.Support.FeedbackTitle, self.Options.Support.FeedbackDescription)
    local feedbackBox = create("TextBox", {
        Name = "FeedbackBox", Size = UDim2.new(1, 0, 0, 140), BackgroundColor3 = PX.panel, BorderSizePixel = 0,
        Text = "", PlaceholderText = "Type your feedback here...", PlaceholderColor3 = PX.dim,
        TextColor3 = PX.text, TextSize = 13, Font = FONT_BODY, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        ClearTextOnFocus = false, MultiLine = true,
    }, pages.Support)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
    }, feedbackBox)
    self.FeedbackBox = feedbackBox
    self:CreateButton(pages.Support, {
        Text = "SEND FEEDBACK", Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = PX.accent,
        TextColor3 = PX.bg, TextSize = 14, Font = FONT_TITLE, HoverColor = liftColor(PX.accent, 22), StrokeColor = PX.accent,
        Callback = function()
            if type(self.Options.OnFeedback) == "function" then
                local result = self.Options.OnFeedback(feedbackBox.Text, self)
                if result ~= false then
                    feedbackBox.Text = ""
                    self:Notify("Feedback", "Feedback sent!", 3, { Type = "Success" })
                end
            else
                self:Notify("Feedback", "Feedback callback is not configured.", 3, { Type = "Warning" })
            end
        end,
    })

    local function selectPage(name)
        self._selectedPage = name
        for pageName, page in pairs(pages) do page.Visible = pageName == name end
        local selected = tabs[name]
        for tabName, tab in pairs(tabs) do
            local selectedState = tabName == name
            tab.BackgroundColor3 = selectedState and PX.bgLight or PX.bg
            local label = tab:FindFirstChild("TabLabel")
            local accentBar = tab:FindFirstChild("AccentBar")
            if label and label:IsA("TextLabel") then label.TextColor3 = selectedState and PX.accent or PX.dim end
            if accentBar and accentBar:IsA("Frame") then accentBar.BackgroundTransparency = selectedState and 0 or 1 end
        end
        if selected then
            selected.BackgroundColor3 = PX.bgLight
        end
    end
    self.SelectPage = selectPage

    for name, tab in pairs(tabs) do
        self:_connect(tab.Activated:Connect(function()
            self:_playSound(SOUNDS.Click, 0.5, 1)
            selectPage(name)
        end))
    end

    -- Drag
    do
        local dragging = false
        local dragStart: Vector2?
        local startPosition: UDim2?
        self:_connect(header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPosition = main.Position
            end
        end))
        self:_connect(UserInputService.InputChanged:Connect(function(input)
            if not dragging or not dragStart or not startPosition then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X, startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end))
        self:_connect(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end))
    end

    -- Resize grip
    do
        local handle = create("TextButton", {
            Size = UDim2.fromOffset(24, 24), Position = UDim2.new(1, -24, 1, -24),
            BackgroundTransparency = 1, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 20,
        }, main)
        create("Frame", { Size = UDim2.fromOffset(10, 10), Position = UDim2.new(0.5, -5, 0.5, -5), BackgroundColor3 = PX.line, BorderSizePixel = 0 }, handle)
        create("Frame", { Size = UDim2.fromOffset(6, 6), Position = UDim2.new(0.5, -3, 0.5, -3), BackgroundColor3 = PX.accent, BorderSizePixel = 0 }, handle)
        local resizing = false
        local resizeStart: Vector2?
        local resizeStartSize: Vector2?
        self:_connect(handle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                resizing = true
                resizeStart = input.Position
                resizeStartSize = Vector2.new(main.AbsoluteSize.X, main.AbsoluteSize.Y)
            end
        end))
        self:_connect(UserInputService.InputChanged:Connect(function(input)
            if not resizing or not resizeStart or not resizeStartSize then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
            local delta = input.Position - resizeStart
            local width = math.clamp(resizeStartSize.X + delta.X, 480, 900)
            local height = math.clamp(resizeStartSize.Y + delta.Y, 320, 650)
            main.Size = UDim2.fromOffset(width, height)
        end))
        self:_connect(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then resizing = false end
        end))
    end

    selectPage("Main")
    self:SetHubVisible(self.Options.HubVisible, false)
    self:_animateEntrance(main)
    self:_bindKeyCapture()
    return main
end

function UI:CreateHub()
    if self._destroyed then return end
    return self:_buildHub()
end

function UI:SetHubVisible(visible, showNotification)
    if not self.HubMain then self:CreateHub() end
    self.HubVisible = visible
    if self.HubMain then self.HubMain.Visible = visible end
    self:_playSound(visible and SOUNDS.Open or SOUNDS.Close, 0.5, visible and 1.18 or 1)
    if showNotification then
        self:Notify("Hub", visible and "Hub opened." or "Hub closed. Press Right Shift to open.", 3)
    end
end

function UI:UpdateTargetInfo(text)
    if self.TargetDescriptionLabel then
        self.LastTargetInfo = tostring(text or "No target selected")
        self.TargetDescriptionLabel.Text = self.LastTargetInfo
    end
end

function UI:CreateHUD(options)
    options = options or {}
    if self.HUDGui and self.HUDGui.Parent then self.HUDGui:Destroy() end
    local gui = create("ScreenGui", {
        Name = options.Name or "ParkCamHUD", ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = options.DisplayOrder or self.Options.DisplayOrder + 10,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = options.Enabled ~= false,
    }, self.PlayerGui)
    table.insert(self._ownedGuis, gui)
    self.HUDGui = gui

    local frame = create("Frame", {
        Size = UDim2.fromOffset(580, 52), Position = UDim2.new(0.5, -290, 0, 18),
        BackgroundColor3 = PX.bg, BackgroundTransparency = 0.08, BorderSizePixel = 0,
    }, gui)
    create("UIStroke", { Color = PX.line, Thickness = 2 }, frame)
    create("Frame", { Size = UDim2.new(0, 4, 1, -20), Position = UDim2.new(0, 8, 0, 10), BackgroundColor3 = PX.accent, BorderSizePixel = 0 }, frame)
    local nameLabel = create("TextLabel", {
        Size = UDim2.fromOffset(210, 52), Position = UDim2.fromOffset(22, 0), BackgroundTransparency = 1,
        Text = options.TargetName or "NO TARGET", TextColor3 = PX.text, TextSize = 15, Font = FONT_TITLE,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
    }, frame)
    local healthTrack = create("Frame", {
        Size = UDim2.fromOffset(130, 10), Position = UDim2.new(1, -330, 0.5, -5),
        BackgroundColor3 = PX.bgLight, BorderSizePixel = 0,
    }, frame)
    create("UIStroke", { Color = PX.lineSoft, Thickness = 1 }, healthTrack)
    local healthFill = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = PX.accent, BorderSizePixel = 0 }, healthTrack)
    local statusPill = create("Frame", {
        Size = UDim2.fromOffset(160, 30), Position = UDim2.new(1, -180, 0.5, -15),
        BackgroundColor3 = PX.bgLight, BorderSizePixel = 0, ClipsDescendants = true,
    }, frame)
    create("UIStroke", { Color = PX.line, Thickness = 1 }, statusPill)
    local statusLabel = create("TextLabel", {
        Size = UDim2.new(1, -8, 1, 0), Position = UDim2.fromOffset(4, 0), BackgroundTransparency = 1,
        Text = options.Status or "READY", TextColor3 = PX.accent, TextSize = 13, Font = FONT_TITLE,
        TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
    }, statusPill)

    self.HUD = { gui = gui, frame = frame, nameLabel = nameLabel, healthFill = healthFill, statusLabel = statusLabel }
    self:_animateEntrance(frame)
    return self.HUD
end

function UI:UpdateHUD(data)
    if not self.HUD then return end
    data = data or {}
    if data.TargetName ~= nil then self.HUD.nameLabel.Text = tostring(data.TargetName) end
    if data.Status ~= nil then self.HUD.statusLabel.Text = tostring(data.Status) end
    if data.StatusColor then self.HUD.statusLabel.TextColor3 = data.StatusColor end
    if data.Health ~= nil or data.MaxHealth ~= nil then
        local health = tonumber(data.Health) or 0
        local maxHealth = math.max(tonumber(data.MaxHealth) or 1, 1)
        local pct = math.clamp(health / maxHealth, 0, 1)
        TweenService:Create(self.HUD.healthFill, TweenInfo.new(0.18), { Size = UDim2.new(pct, 0, 1, 0) }):Play()
        self.HUD.healthFill.BackgroundColor3 = pct > 0.5 and PX.accent or (pct > 0.25 and PX.warn or PX.bad)
    end
end

function UI:CreateStatsSidebar(options)
    options = options or {}
    if self.StatsGui and self.StatsGui.Parent then self.StatsGui:Destroy() end
    local gui = create("ScreenGui", {
        Name = options.Name or "ParkCamSidebar", ResetOnSpawn = false, IgnoreGuiInset = true,
        Enabled = options.Enabled ~= false, DisplayOrder = options.DisplayOrder or self.Options.DisplayOrder + 5,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, self.PlayerGui)
    table.insert(self._ownedGuis, gui)
    self.StatsGui = gui

    local frame = create("Frame", {
        Size = UDim2.fromOffset(156, 122), Position = UDim2.new(1, -172, 1, -138),
        BackgroundColor3 = PX.bg, BackgroundTransparency = 0.08, BorderSizePixel = 0,
    }, gui)
    create("UIStroke", { Color = PX.line, Thickness = 2 }, frame)

    local values = {}
    local function makeRow(y, labelText)
        local row = create("Frame", { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, y), BackgroundTransparency = 1 }, frame)
        create("TextLabel", {
            Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 1, Text = labelText,
            TextColor3 = PX.dim, TextSize = 12, Font = FONT_BODY,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        }, row)
        local value = create("TextLabel", {
            Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0), BackgroundTransparency = 1,
            Text = "--", TextColor3 = PX.text, TextSize = 14, Font = FONT_TITLE,
            TextXAlignment = Enum.TextXAlignment.Right, TextYAlignment = Enum.TextYAlignment.Center,
        }, row)
        return value
    end
    values.FPS = makeRow(12, "FPS")
    values.PING = makeRow(40, "PING")
    values.KILLS = makeRow(68, "KILLS")
    values.LOWHP = makeRow(96, "LOW HP")

    self.StatsSidebar = { gui = gui, frame = frame, values = values }
    self:_animateEntrance(frame)
    return self.StatsSidebar
end

function UI:UpdateStatsSidebar(data)
    if not self.StatsSidebar then return end
    data = data or {}
    for key, value in pairs({ FPS = data.FPS, PING = data.PING, KILLS = data.KILLS, LOWHP = data.LowHP or data.LOWHP }) do
        if value ~= nil and self.StatsSidebar.values[key] then self.StatsSidebar.values[key].Text = tostring(value) end
    end
    if data.PING ~= nil then
        local ping = tonumber(data.PING) or 0
        self.StatsSidebar.values.PING.TextColor3 = ping <= 60 and PX.accent or (ping <= 120 and PX.warn or PX.bad)
    end
    if data.LowHP ~= nil or data.LOWHP ~= nil then
        local low = tonumber(data.LowHP or data.LOWHP) or 0
        self.StatsSidebar.values.LOWHP.TextColor3 = low == 0 and PX.text or (low <= 2 and PX.warn or PX.bad)
    end
end

function UI:StartStatsUpdater(provider)
    if self._statsConnection then self._statsConnection:Disconnect() end
    self._statsConnection = self:_connect(RunService.RenderStepped:Connect(function(deltaTime)
        if type(provider) == "function" then
            local ok, data = pcall(provider, deltaTime, self)
            if ok and type(data) == "table" then self:UpdateStatsSidebar(data) end
        end
    end))
    return self._statsConnection
end

function UI:GetPing()
    local ok, value = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    if ok and value then return math.floor(value + 0.5) end
    return 0
end

function UI:ShowConfirmation(title, message, cancelText, confirmText, accentColor)
    if self._confirmModal then return false end
    local gui = create("ScreenGui", {
        Name = "LarpingHubConfirm", ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = self.Options.DisplayOrder + 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, self.PlayerGui)
    table.insert(self._ownedGuis, gui)

    create("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35,
        BorderSizePixel = 0, Text = "", AutoButtonColor = false, Active = true, ZIndex = 1,
    }, gui)
    local card = create("Frame", {
        Size = UDim2.fromOffset(500, 240), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = PX.bg, BorderSizePixel = 0, ZIndex = 2,
    }, gui)
    create("UISizeConstraint", { MinSize = Vector2.new(420, 240), MaxSize = Vector2.new(600, 240) }, card)
    local color = accentColor or PX.bad
    create("UIStroke", { Color = color, Thickness = 2 }, card)
    create("Frame", { Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3 }, card)
    create("TextLabel", {
        Size = UDim2.new(1, -40, 0, 30), Position = UDim2.fromOffset(20, 18), BackgroundTransparency = 1,
        Text = title, TextColor3 = color, TextSize = 22, Font = FONT_TITLE, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3,
    }, card)
    create("TextLabel", {
        Size = UDim2.new(1, -40, 0, 100), Position = UDim2.fromOffset(20, 60), BackgroundTransparency = 1,
        Text = message, TextColor3 = PX.text, TextSize = 14, Font = FONT_BODY, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3,
    }, card)
    local row = create("Frame", { Size = UDim2.new(1, -40, 0, 44), Position = UDim2.new(0, 20, 1, -60), BackgroundTransparency = 1, ZIndex = 3 }, card)
    create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10) }, row)

    local done = false
    local decision = false
    local cancel = self:CreateButton(row, {
        Size = UDim2.fromOffset(140, 44), Text = cancelText or "CANCEL", BackgroundColor3 = PX.bgLight,
        TextColor3 = PX.text, TextSize = 13, Font = FONT_TITLE, StrokeColor = PX.bgLight, StrokeTransparency = 1,
        Callback = function() decision = false; done = true end,
    })
    local confirm = self:CreateButton(row, {
        Size = UDim2.fromOffset(180, 44), Text = confirmText or "CONFIRM", BackgroundColor3 = color,
        TextColor3 = PX.bg, TextSize = 13, Font = FONT_TITLE, StrokeColor = color,
        HoverColor = liftColor(color, 22), Callback = function() decision = true; done = true end,
    })
    cancel.ZIndex = 4
    confirm.ZIndex = 4

    self._confirmModal = { gui = gui, card = card }
    self:_playSound(SOUNDS.Warning, 0.5, 1)
    self:_animateEntrance(card)

    while not done and not self._destroyed do task.wait() end
    if gui.Parent then gui:Destroy() end
    self._confirmModal = nil
    return decision
end


function UI:ShowDiscordPrompt()
    return self:ShowConfirmation(
        "JOIN DISCORD?",
        "The Discord action is handled by the repo callback; this module intentionally stores no invite URL.",
        "NO",
        "YES, JOIN",
        PX.accent
    )
end

function UI:BuildAll(options)
    options = options or {}
    local loading = self:ShowLoadingScreen(options.Loading or {
        Title = "LARPING HUB",
        Status = "starting up",
        Progress = 0.08,
    })
    self:SetLoadingProgress(0.18, "building hub")
    self:CreateHub()
    self:SetLoadingProgress(0.48, "building hud")
    self:CreateHUD(options.HUD or {})
    self:SetLoadingProgress(0.66, "building sidebar")
    self:CreateStatsSidebar(options.StatsSidebar or {})
    self:SetLoadingProgress(0.78, "binding controls")
    if type(options.OnBindControls) == "function" then pcall(options.OnBindControls, self) end
    self:SetLoadingProgress(0.90, "finalizing")
    if options.FinishLoading ~= false then self:FinishLoadingScreen(options.LoadingReadyText or "ready") end
    if options.WelcomeNotification ~= false then
        self:Notify("Larping Hub", "Thanks for using my script! V1!", 5, { Type = "Success" })
    end
    return { hub = self.HubMain, hud = self.HUD, sidebar = self.StatsSidebar, loading = loading }
end

function UI:ShowLoadingScreen(options)
    options = options or {}
    if self._loading and self._loading.Gui and self._loading.Gui.Parent then return self._loading end
    local name = options.Name or "LarpingHubLoading"
    local old = self.PlayerGui:FindFirstChild(name)
    if old then old:Destroy() end

    local gui = create("ScreenGui", {
        Name = name, ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = options.DisplayOrder or self.Options.DisplayOrder + 900,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    }, self.PlayerGui)
    table.insert(self._ownedGuis, gui)
    local overlay = create("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = options.OverlayColor or Color3.new(0, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
    }, gui)
    local card = create("Frame", {
        Size = options.Size or UDim2.fromOffset(430, 170), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = options.BackgroundColor or PX.bg, BackgroundTransparency = 1, BorderSizePixel = 0,
    }, gui)
    create("UIStroke", { Color = options.StrokeColor or PX.line, Thickness = options.StrokeThickness or 1, Transparency = 0.35 }, card)
    local title = create("TextLabel", {
        Position = UDim2.fromOffset(20, 22), Size = UDim2.new(1, -40, 0, 28), BackgroundTransparency = 1,
        Font = FONT_TITLE, Text = options.Title or "LOADING", TextColor3 = options.TitleColor or PX.text,
        TextSize = options.TitleSize or 20, TextXAlignment = Enum.TextXAlignment.Left,
    }, card)
    local status = create("TextLabel", {
        Position = UDim2.fromOffset(20, 55), Size = UDim2.new(1, -40, 0, 24), BackgroundTransparency = 1,
        Font = FONT_BODY, Text = options.Status or "starting up", TextColor3 = options.StatusColor or PX.dim,
        TextSize = options.StatusSize or 12, TextXAlignment = Enum.TextXAlignment.Left,
    }, card)
    local track = create("Frame", {
        Position = UDim2.fromOffset(20, 99), Size = UDim2.new(1, -40, 0, 8), BackgroundColor3 = PX.bgLight,
        BackgroundTransparency = 0.1, BorderSizePixel = 0, ClipsDescendants = true,
    }, card)
    local fill = create("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = PX.accent, BorderSizePixel = 0 }, track)
    local progressLabel = create("TextLabel", {
        Position = UDim2.fromOffset(20, 120), Size = UDim2.new(1, -40, 0, 22), BackgroundTransparency = 1,
        Font = FONT_BODY, Text = "0%", TextColor3 = PX.dim, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right,
    }, card)

    local controller = { Gui = gui, gui = gui, Card = card, card = card, Status = status, ProgressFill = fill, ProgressText = progressLabel, _destroyed = false }
    function controller:setProgress(value, text)
        if self._destroyed or not fill.Parent then return end
        local numeric = math.clamp(tonumber(value) or 0, 0, 1)
        fill.Size = UDim2.new(numeric, 0, 1, 0)
        progressLabel.Text = string.format("%d%%", math.floor(numeric * 100 + 0.5))
        if text ~= nil then status.Text = tostring(text) end
    end
    function controller:setStatus(text)
        if self._destroyed or not status.Parent then return end
        status.Text = tostring(text or "")
    end
    function controller:destroy()
        if self._destroyed then return end
        self._destroyed = true
        local overlayTween = TweenService:Create(overlay, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
        local cardTween = TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 })
        overlayTween:Play(); cardTween:Play(); cardTween.Completed:Wait()
        if gui.Parent then gui:Destroy() end
    end

    controller:setProgress(options.Progress or 0, options.Status or "starting up")
    TweenService:Create(overlay, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = options.OverlayTransparency or 0.2 }):Play()
    TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { BackgroundTransparency = options.BackgroundTransparency or 0.04 }):Play()
    self._loading = controller
    return controller
end

function UI:SetLoadingProgress(value, text)
    if self._loading then self._loading:setProgress(value, text) end
end

function UI:FinishLoadingScreen(text)
    local loading = self._loading
    if not loading then return end
    loading:setProgress(1, text or "ready")
    task.wait(0.12)
    loading:destroy()
    if self._loading == loading then self._loading = nil end
end

UI.RunLoadingScreen = UI.ShowLoadingScreen
UI.SetProgress = UI.SetLoadingProgress
UI.FinishLoading = UI.FinishLoadingScreen
UI.CreateSidebar = UI.CreateStatsSidebar

function UI:ResetSettings()
    self.State = cloneDictionary(self.Options.SettingsState)
    for _, refresh in pairs(self._settingRows) do pcall(refresh) end
end

function UI:SetSetting(name, value)
    self.State[name] = value == true
    local refresh = self._settingRows[name]
    if refresh then refresh() end
    if type(self.Options.OnSettingChanged) == "function" then pcall(self.Options.OnSettingChanged, name, self.State[name], self) end
end

function UI:GetSetting(name)
    return self.State[name] == true
end

function UI:SetKeybind(actionName, keyName)
    self.Keybinds[actionName] = keyName
    local info = self._keybindButtons[actionName]
    if info then info.refresh() end
    if type(self.Options.OnKeybindChanged) == "function" then pcall(self.Options.OnKeybindChanged, actionName, keyName, self) end
end

function UI:Destroy()
    if self._destroyed then return end
    self._destroyed = true
    for _, connection in ipairs(self._connections) do pcall(function() connection:Disconnect() end) end
    table.clear(self._connections)
    if self._loading then pcall(function() self._loading:destroy() end); self._loading = nil end
    if self._confirmModal and self._confirmModal.gui and self._confirmModal.gui.Parent then self._confirmModal.gui:Destroy() end
    for _, gui in ipairs(self._ownedGuis) do if gui and gui.Parent then gui:Destroy() end end
    table.clear(self._ownedGuis)
    table.clear(self._notifications)
end

return UI
