-- =========================================================================
--  BRO-PIXEL | WORD BOMB (EXACT SOLARIS 1:1 - TITLEBAR MINIMIZE BUTTON)
-- =========================================================================

local string_find = string.find
local string_lower = string.lower
local string_sub = string.sub
local string_gsub = string.gsub
local string_upper = string.upper
local math_random = math.random
local math_floor = math.floor
local math_huge = math.huge
local math_clamp = math.clamp
local math_max = math.max
local math_min = math.min
local table_clear = table.clear
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local task_spawn = task.spawn
local task_wait = task.wait
local os_time = os.time
local os_clock = os.clock
local pcall = pcall
local xpcall = xpcall
local type = type
local tostring = tostring
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local debug_getinfo = debug_getinfo
local debug_getupvalues = debug_getupvalues
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Vim = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- === AUTHENTICATION ===
local API_URL = "https://roblox-key-api-zxnv.onrender.com/verify"
local userProvidedKey = getgenv().PixelKey or _G.PixelKey or PixelKey
if not userProvidedKey or userProvidedKey == "" then
    if LocalPlayer then
        LocalPlayer:Kick("❌ [Bro-Pixel Auth]: Key not found! Set getgenv().PixelKey = 'YOUR_KEY' before execution.")
    end
    return
end

local function checkKey(userKey)
    local rawHwid = gethwid and gethwid() or (game:GetService("RbxAnalyticsService"):GetClientId())
    local requestUrl = string.format("%s?key=%s&hwid=%s", API_URL, tostring(userKey), tostring(rawHwid))
    local success, response = pcall(function() return game:HttpGet(requestUrl) end)
    if success and response then
        local ok, data = pcall(function() return HttpService:JSONDecode(response) end)
        if ok and type(data) == "table" then
            if data.status == "success" then
                return true, data.message or "Access Granted!"
            else
                return false, data.message or "Access Denied!"
            end
        else
            return false, "Invalid response structure from server!"
        end
    else
        return false, "Failed to connect to the authentication server!"
    end
end

local isAuthenticated, authMessage = checkKey(userProvidedKey)
if not isAuthenticated then
    if LocalPlayer then
        LocalPlayer:Kick("🔒 [Bro-Pixel Auth]: " .. tostring(authMessage))
    end
    error("[AUTH FAILED]: " .. tostring(authMessage))
    return
end

print("Premium Bro-Pixel script successfully loaded! Enjoy 💗")

-- === СТАТИСТИКА СЕССИИ ===
local myGlobalStats = {
    stolen = 0,
    winStreak = 0,
    wpm = 350
}
local lastRecordedTurnPossessor = nil

-- === ОЧИСТКА СТАРЫХ GUI ===
local targetGuiParent = pcall(function() return CoreGui end) and CoreGui or (LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui"))
if targetGuiParent then
    if targetGuiParent:FindFirstChild("BroPixelSenseGui") then targetGuiParent.BroPixelSenseGui:Destroy() end
    if targetGuiParent:FindFirstChild("CleanStatsGui") then targetGuiParent.CleanStatsGui:Destroy() end
    if targetGuiParent:FindFirstChild("PixelStealFxGui") then targetGuiParent.PixelStealFxGui:Destroy() end
end

-- === POP-UP ANIMATION FUNCTION ===
local function getStealFxContainer()
    if not targetGuiParent then return nil end
    local existing = targetGuiParent:FindFirstChild("PixelStealFxGui")
    if existing and existing:IsA("ScreenGui") then return existing end
    local gui = Instance.new("ScreenGui")
    gui.Name = "PixelStealFxGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 99999
    gui.Parent = targetGuiParent
    return gui
end

local function PlayStealWordEffect(word, stolenFrom)
    local targetGui = getStealFxContainer()
    if not targetGui then return end
    targetGui:ClearAllChildren()

    word = (word or "BANDAGE"):upper()
    stolenFrom = (stolenFrom or "Opponent"):upper()

    local wordLen = #word
    local targetFontSize = 22
    local charWidth = 15

    if wordLen > 10 then
        targetFontSize = math_clamp(math_floor(260 / wordLen * 1.2), 11, 20)
        charWidth = math_clamp(math_floor(320 / wordLen), 8, 14)
    end

    local totalWidth = wordLen * charWidth

    local container = Instance.new("Frame")
    container.Size = UDim2.fromOffset(math_max(totalWidth + 20, 200), 45)
    container.Position = UDim2.new(0.5, 0, 0.84, 0)
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.BackgroundTransparency = 1
    container.Parent = targetGui

    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(1, 0, 0, 12)
    subLabel.Position = UDim2.new(0, 0, 0, -4)
    subLabel.BackgroundTransparency = 1
    subLabel.Font = Enum.Font.Code
    subLabel.Text = "STOLEN FROM: " .. stolenFrom
    subLabel.TextColor3 = Color3.fromRGB(0, 85, 255)
    subLabel.TextSize = 12
    subLabel.TextTransparency = 1
    subLabel.Parent = container

    local lettersHolder = Instance.new("Frame")
    lettersHolder.Size = UDim2.fromOffset(totalWidth, 26)
    lettersHolder.Position = UDim2.new(0.5, 0, 0.65, 0)
    lettersHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    lettersHolder.BackgroundTransparency = 1
    lettersHolder.Parent = container

    TweenService:Create(subLabel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0 }):Play()

    local letterLabels = {}
    local strokes = {}

    for i = 1, wordLen do
        local char = string_sub(word, i, i)
        local charLabel = Instance.new("TextLabel")
        charLabel.Size = UDim2.fromOffset(charWidth, 26)
        charLabel.Position = UDim2.fromOffset((i - 1) * charWidth, 0)
        charLabel.BackgroundTransparency = 1
        charLabel.Font = Enum.Font.Code
        charLabel.Text = char
        charLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        charLabel.TextSize = 6
        charLabel.TextTransparency = 1
        charLabel.Parent = lettersHolder

        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 1.2
        stroke.Color = Color3.fromRGB(0, 85, 255)
        stroke.Transparency = 1
        stroke.Parent = charLabel

        table_insert(letterLabels, charLabel)
        table_insert(strokes, stroke)
    end

    local stepDelay = math_clamp(0.35 / wordLen, 0.015, 0.035)
    local charPopInfo = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

    task_spawn(function()
        for i = 1, wordLen do
            local lbl = letterLabels[i]
            local strk = strokes[i]
            TweenService:Create(lbl, charPopInfo, { TextSize = targetFontSize, TextTransparency = 0 }):Play()
            TweenService:Create(strk, charPopInfo, { Transparency = 0.2 }):Play()
            task_wait(stepDelay)
        end

        task_wait(0.7)

        local slowFadeInfo = TweenInfo.new(0.85, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
        TweenService:Create(container, slowFadeInfo, { Position = UDim2.new(0.5, 0, 0.78, 0) }):Play()
        TweenService:Create(subLabel, slowFadeInfo, { TextTransparency = 1 }):Play()

        for i = 1, wordLen do
            TweenService:Create(letterLabels[i], slowFadeInfo, { TextTransparency = 1, TextSize = math_max(targetFontSize - 3, 8) }):Play()
            local lastStrokeTween = TweenService:Create(strokes[i], slowFadeInfo, { Transparency = 1 })
            lastStrokeTween:Play()
            if i == wordLen then
                lastStrokeTween.Completed:Connect(function()
                    container:Destroy()
                end)
            end
        end
    end)
end

-- === ПЕРЕМЕННЫЕ ЛОГИКИ ===
local sessionUsedWords = {}
local lettercap = math_huge
local autosearch = false
local autotype = false
local instanttype = false
local autojoin = false
local autoJoinDelay = 2

local jitterEnabled = true
local jitterIntensity = 0.11
local rngVariationPercent = 25

local useFuseProgress = true
local fusePercent = 0.17
local currentFusionStats = "0.00s / 0.00s"

local typosEnabled = false
local typoChancePercent = 3

local wordPriorityMode = "Common"
local isTyping = false
local lastWord = ""
local typingSessionId = 0
local activePrompt = ""
local lastSubmittedPrompt = ""
local checkWordDelay = 1.0
local startTime = os_time()
local totalTurns = 0
local typingWPM = 350
local speedWordDelay = 60 / (typingWPM * 5)
local alphabet = "abcdefghijklmnopqrstuvwxyz"

local stealEnabled = true
local preferStolenWords = true
local stolenReadyPool = {}
local lastBuffers = {}
local lastPossessor = nil

local function applyRngVariation(baseValue)
    if rngVariationPercent <= 0 then return baseValue end
    local factor = 1 + ((math_random() * 2 - 1) * (rngVariationPercent / 100))
    local result = baseValue * factor
    return result < 0 and 0 or result
end

-- =========================================================================
--  EXACT LINORIA/SOLARIS ENGINE (THEME CONFIGURATION)
-- =========================================================================

local Theme = {
    Font = Enum.Font.Code,
    FontColor = Color3.fromRGB(255, 255, 255),
    DimColor = Color3.fromRGB(165, 165, 165),
    MainColor = Color3.fromRGB(28, 28, 28),
    BackgroundColor = Color3.fromRGB(20, 20, 20),
    AccentColor = Color3.fromRGB(0, 85, 255),
    OutlineColor = Color3.fromRGB(50, 50, 50),
    InputBackground = Color3.fromRGB(23, 23, 23),
    SliderBackground = Color3.fromRGB(24, 24, 24)
}

local MainScreenGui = Instance.new("ScreenGui")
MainScreenGui.Name = "BroPixelSenseGui"
MainScreenGui.ResetOnSpawn = false
MainScreenGui.DisplayOrder = 99999
MainScreenGui.Parent = targetGuiParent

-- Главное окно
local FULL_HEIGHT = 460
local MINIMIZED_HEIGHT = 24
local isMinimized = false

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.fromOffset(490, FULL_HEIGHT)
MainFrame.Position = UDim2.new(0.5, -245, 0.32, -230)
MainFrame.BackgroundColor3 = Theme.BackgroundColor
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = MainScreenGui

local mfStroke = Instance.new("UIStroke")
mfStroke.Thickness = 1
mfStroke.Color = Theme.OutlineColor
mfStroke.Parent = MainFrame

-- Шапка
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 24)
TitleBar.BackgroundColor3 = Theme.MainColor
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -40, 1, 0)
TitleLabel.Position = UDim2.fromOffset(8, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Theme.Font
TitleLabel.Text = "bropixel | word bomb"
TitleLabel.TextColor3 = Theme.FontColor
TitleLabel.TextSize = 13
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Кнопка сворачивания в шапке (-)
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Name = "MinimizeBtn"
MinimizeBtn.Size = UDim2.fromOffset(24, 24)
MinimizeBtn.Position = UDim2.new(1, -26, 0, 0)
MinimizeBtn.BackgroundTransparency = 1
MinimizeBtn.Font = Theme.Font
MinimizeBtn.Text = "—"
MinimizeBtn.TextColor3 = Theme.FontColor
MinimizeBtn.TextSize = 14
MinimizeBtn.Parent = TitleBar

-- Контейнер содержимого (для скрытия при сворачивании)
local BodyContainer = Instance.new("Frame")
BodyContainer.Name = "BodyContainer"
BodyContainer.Size = UDim2.new(1, 0, 1, -24)
BodyContainer.Position = UDim2.fromOffset(0, 24)
BodyContainer.BackgroundTransparency = 1
BodyContainer.BorderSizePixel = 0
BodyContainer.Parent = MainFrame

-- Вкладка Main
local TabHeader = Instance.new("Frame")
TabHeader.Size = UDim2.new(1, 0, 0, 22)
TabHeader.Position = UDim2.fromOffset(0, 0)
TabHeader.BackgroundColor3 = Theme.BackgroundColor
TabHeader.BorderSizePixel = 0
TabHeader.Parent = BodyContainer

local TabMainLabel = Instance.new("TextLabel")
TabMainLabel.Size = UDim2.fromOffset(45, 18)
TabMainLabel.Position = UDim2.fromOffset(8, 0)
TabMainLabel.BackgroundTransparency = 1
TabMainLabel.Font = Theme.Font
TabMainLabel.Text = "Main"
TabMainLabel.TextColor3 = Theme.FontColor
TabMainLabel.TextSize = 13
TabMainLabel.Parent = TabHeader

local TabMainLine = Instance.new("Frame")
TabMainLine.Size = UDim2.new(1, -16, 0, 1.5)
TabMainLine.Position = UDim2.new(0, 8, 1, -1)
TabMainLine.BackgroundColor3 = Theme.AccentColor
TabMainLine.BorderSizePixel = 0
TabMainLine.Parent = TabHeader

-- Логика сворачивания
MinimizeBtn.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        BodyContainer.Visible = false
        MainFrame.Size = UDim2.fromOffset(490, MINIMIZED_HEIGHT)
    else
        MainFrame.Size = UDim2.fromOffset(490, FULL_HEIGHT)
        BodyContainer.Visible = true
    end
end)

-- Перетаскивание окна за шапку (работает и в свернутом виде)
do
    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Колонки
local LeftCol = Instance.new("ScrollingFrame")
LeftCol.Size = UDim2.new(0.5, -10, 1, -30)
LeftCol.Position = UDim2.fromOffset(7, 26)
LeftCol.BackgroundTransparency = 1
LeftCol.BorderSizePixel = 0
LeftCol.ScrollBarThickness = 0
LeftCol.AutomaticCanvasSize = Enum.AutomaticSize.Y
LeftCol.Parent = BodyContainer

local LeftLayout = Instance.new("UIListLayout")
LeftLayout.Padding = UDim.new(0, 6)
LeftLayout.Parent = LeftCol

local RightCol = Instance.new("ScrollingFrame")
RightCol.Size = UDim2.new(0.5, -10, 1, -30)
RightCol.Position = UDim2.new(0.5, 3, 0, 26)
RightCol.BackgroundTransparency = 1
RightCol.BorderSizePixel = 0
RightCol.ScrollBarThickness = 0
RightCol.AutomaticCanvasSize = Enum.AutomaticSize.Y
RightCol.Parent = BodyContainer

local RightLayout = Instance.new("UIListLayout")
RightLayout.Padding = UDim.new(0, 6)
RightLayout.Parent = RightCol

-- Groupbox
local function createGroupbox(parent, title)
    local box = Instance.new("Frame")
    box.BackgroundColor3 = Theme.MainColor
    box.BorderSizePixel = 0
    box.Size = UDim2.new(1, -4, 0, 0)
    box.AutomaticSize = Enum.AutomaticSize.Y
    box.Parent = parent

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Theme.OutlineColor
    stroke.Parent = box

    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -12, 0, 18)
    header.Position = UDim2.fromOffset(6, 1)
    header.BackgroundTransparency = 1
    header.Font = Theme.Font
    header.Text = title
    header.TextColor3 = Theme.FontColor
    header.TextSize = 13
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = box

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, -12, 0, 1)
    line.Position = UDim2.fromOffset(6, 18)
    line.BackgroundColor3 = Theme.OutlineColor
    line.BorderSizePixel = 0
    line.Parent = box

    local content = Instance.new("Frame")
    content.Position = UDim2.fromOffset(6, 22)
    content.Size = UDim2.new(1, -12, 0, 0)
    content.BackgroundTransparency = 1
    content.AutomaticSize = Enum.AutomaticSize.Y
    content.Parent = box

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 4)
    layout.Parent = content

    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 6)
    pad.Parent = content

    return content
end

-- Controls (13px Font Code)
local function addToggle(group, text, defaultVal, callback)
    local frame = Instance.new("TextButton")
    frame.Size = UDim2.new(1, 0, 0, 16)
    frame.BackgroundTransparency = 1
    frame.Text = ""
    frame.Parent = group

    local box = Instance.new("Frame")
    box.Size = UDim2.fromOffset(10, 10)
    box.Position = UDim2.fromOffset(0, 3)
    box.BackgroundColor3 = defaultVal and Theme.AccentColor or Theme.InputBackground
    box.BorderSizePixel = 0
    box.Parent = frame

    local bStroke = Instance.new("UIStroke")
    bStroke.Thickness = 1
    bStroke.Color = Theme.OutlineColor
    bStroke.Parent = box

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -16, 1, 0)
    lbl.Position = UDim2.fromOffset(15, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Theme.Font
    lbl.Text = text
    lbl.TextColor3 = defaultVal and Theme.FontColor or Theme.DimColor
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = frame

    local state = defaultVal
    frame.MouseButton1Click:Connect(function()
        state = not state
        box.BackgroundColor3 = state and Theme.AccentColor or Theme.InputBackground
        lbl.TextColor3 = state and Theme.FontColor or Theme.DimColor
        callback(state)
    end)
end

local function addButton(group, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 20)
    btn.BackgroundColor3 = Theme.InputBackground
    btn.BorderSizePixel = 0
    btn.Font = Theme.Font
    btn.Text = text
    btn.TextColor3 = Theme.FontColor
    btn.TextSize = 13
    btn.Parent = group

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Theme.OutlineColor
    stroke.Parent = btn

    btn.MouseButton1Click:Connect(callback)
end

local function addInput(group, labelText, placeholder, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 28)
    frame.BackgroundTransparency = 1
    frame.Parent = group

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 12)
    title.BackgroundTransparency = 1
    title.Font = Theme.Font
    title.Text = labelText
    title.TextColor3 = Theme.DimColor
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local tb = Instance.new("TextBox")
    tb.Size = UDim2.new(1, 0, 0, 14)
    tb.Position = UDim2.fromOffset(0, 13)
    tb.BackgroundColor3 = Theme.InputBackground
    tb.BorderSizePixel = 0
    tb.Font = Theme.Font
    tb.Text = ""
    tb.PlaceholderText = placeholder
    tb.TextColor3 = Theme.FontColor
    tb.PlaceholderColor3 = Color3.fromRGB(90, 90, 90)
    tb.TextSize = 13
    tb.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Theme.OutlineColor
    stroke.Parent = tb

    tb.FocusLost:Connect(function() callback(tb.Text) end)
end

local function addSlider(group, text, min, max, defaultVal, step, maxValDisplay, callback)
    step = step or 1
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 24)
    frame.BackgroundTransparency = 1
    frame.Parent = group

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.6, 0, 0, 12)
    title.BackgroundTransparency = 1
    title.Font = Theme.Font
    title.Text = text
    title.TextColor3 = Theme.DimColor
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.4, 0, 0, 12)
    valLbl.Position = UDim2.new(0.6, 0, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Font = Theme.Font
    valLbl.Text = defaultVal .. "/" .. maxValDisplay
    valLbl.TextColor3 = Theme.FontColor
    valLbl.TextSize = 13
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = frame

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1, 0, 0, 8)
    bar.Position = UDim2.fromOffset(0, 14)
    bar.BackgroundColor3 = Theme.SliderBackground
    bar.BorderSizePixel = 0
    bar.Text = ""
    bar.Parent = frame

    local bStroke = Instance.new("UIStroke")
    bStroke.Thickness = 1
    bStroke.Color = Theme.OutlineColor
    bStroke.Parent = bar

    local fill = Instance.new("Frame")
    local pct = (defaultVal - min) / (max - min)
    fill.Size = UDim2.new(math_clamp(pct, 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = Theme.AccentColor
    fill.BorderSizePixel = 0
    fill.Parent = bar

    local function update(input)
        local rel = math_clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local rawVal = min + (max - min) * rel
        local val = math_floor((rawVal / step) + 0.5) * step
        val = math_clamp(val, min, max)

        local exactRel = (val - min) / (max - min)
        fill.Size = UDim2.new(exactRel, 0, 1, 0)
        valLbl.Text = val .. "/" .. maxValDisplay
        callback(val)
    end

    local sliding = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = true
            update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            update(input)
        end
    end)
end

local function addSecondsSlider(group, text, minSec, maxSec, defaultSec, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 24)
    frame.BackgroundTransparency = 1
    frame.Parent = group

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.6, 0, 0, 12)
    title.BackgroundTransparency = 1
    title.Font = Theme.Font
    title.Text = text
    title.TextColor3 = Theme.DimColor
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0.4, 0, 0, 12)
    valLbl.Position = UDim2.new(0.6, 0, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Font = Theme.Font
    valLbl.Text = string.format("%.2fs", defaultSec)
    valLbl.TextColor3 = Theme.FontColor
    valLbl.TextSize = 13
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = frame

    local bar = Instance.new("TextButton")
    bar.Size = UDim2.new(1, 0, 0, 8)
    bar.Position = UDim2.fromOffset(0, 14)
    bar.BackgroundColor3 = Theme.SliderBackground
    bar.BorderSizePixel = 0
    bar.Text = ""
    bar.Parent = frame

    local bStroke = Instance.new("UIStroke")
    bStroke.Thickness = 1
    bStroke.Color = Theme.OutlineColor
    bStroke.Parent = bar

    local fill = Instance.new("Frame")
    local pct = (defaultSec - minSec) / (maxSec - minSec)
    fill.Size = UDim2.new(math_clamp(pct, 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = Theme.AccentColor
    fill.BorderSizePixel = 0
    fill.Parent = bar

    local function update(input)
        local rel = math_clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local rawVal = minSec + (maxSec - minSec) * rel
        local rounded = math_floor(rawVal * 100 + 0.5) / 100
        rounded = math_clamp(rounded, minSec, maxSec)

        local exactRel = (rounded - minSec) / (maxSec - minSec)
        fill.Size = UDim2.new(exactRel, 0, 1, 0)
        valLbl.Text = string.format("%.2fs", rounded)
        callback(rounded)
    end

    local sliding = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = true
            update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            update(input)
        end
    end)
end

local function addStatRow(group, titleText, defaultVal, isTruncate)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 14)
    row.BackgroundTransparency = 1
    row.Parent = group

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(0.40, 0, 1, 0)
    tLbl.BackgroundTransparency = 1
    tLbl.Font = Theme.Font
    tLbl.Text = titleText
    tLbl.TextColor3 = Theme.DimColor
    tLbl.TextSize = 13
    tLbl.TextXAlignment = Enum.TextXAlignment.Left
    tLbl.Parent = row

    local vLbl = Instance.new("TextLabel")
    vLbl.Size = UDim2.new(0.60, 0, 1, 0)
    vLbl.Position = UDim2.new(0.40, 0, 0, 0)
    vLbl.BackgroundTransparency = 1
    vLbl.Font = Theme.Font
    vLbl.Text = defaultVal
    vLbl.TextColor3 = Theme.FontColor
    vLbl.TextSize = 13
    vLbl.TextXAlignment = Enum.TextXAlignment.Right
    if isTruncate then
        vLbl.TextTruncate = Enum.TextTruncate.AtEnd
    end
    vLbl.Parent = row

    return {
        SetText = function(_, val) vLbl.Text = val end
    }
end

local function addDropdown(group, text, options, defaultVal, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 28)
    frame.BackgroundTransparency = 1
    frame.Parent = group

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 12)
    title.BackgroundTransparency = 1
    title.Font = Theme.Font
    title.Text = text
    title.TextColor3 = Theme.DimColor
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 15)
    btn.Position = UDim2.fromOffset(0, 13)
    btn.BackgroundColor3 = Theme.InputBackground
    btn.BorderSizePixel = 0
    btn.Font = Theme.Font
    btn.Text = "  " .. (options[defaultVal] or options[1]) .. "  ▼"
    btn.TextColor3 = Theme.FontColor
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1
    stroke.Color = Theme.OutlineColor
    stroke.Parent = btn

    local curIdx = defaultVal
    btn.MouseButton1Click:Connect(function()
        curIdx = curIdx + 1
        if curIdx > #options then curIdx = 1 end
        btn.Text = "  " .. options[curIdx] .. "  ▼"
        callback(options[curIdx])
    end)
end

-- =========================================================================
--  НАПОЛНЕНИЕ СОДЕРЖИМЫМ
-- =========================================================================

local SolverGroup = createGroupbox(LeftCol, "Solver")
local StatsGroup = createGroupbox(RightCol, "Stats")
local StealGroup = createGroupbox(RightCol, "Steal & Dict")

-- Левая колонка (Solver)
addToggle(SolverGroup, "Auto Search", false, function(v) autosearch = v if v then task_spawn(ProcessMyTurn) end end)
addToggle(SolverGroup, "Auto Solve", false, function(v) autotype = v end)
addToggle(SolverGroup, "Instant Solve", false, function(v) instanttype = v end)
addToggle(SolverGroup, "Auto Join Game", false, function(v) autojoin = v end)

addButton(SolverGroup, "Search Word (Manual)", function()
    isTyping = false
    typingSessionId = typingSessionId + 1
    lastSubmittedPrompt = ""
    activePrompt = ""

    local detectedRaw = GetLetters()
    if not detectedRaw or detectedRaw == "" then detectedRaw = GetPassiveLetters() end
    if detectedRaw and detectedRaw ~= "" then
        local cleanPrompt = detectedRaw:lower():gsub("%s+", "")
        local word, stolenOwner = findWordForPrompt(cleanPrompt, false)
        if word then
            sessionUsedWords[word] = true
            lastWord = word:upper()
            activePrompt = cleanPrompt

            promptLabel:SetText(detectedRaw:upper())
            matchLabel:SetText(word:upper())

            if stolenOwner then
                lastStolenLabel:SetText(stolenOwner .. " (" .. word:upper() .. ")")
                task_spawn(function() PlayStealWordEffect(word, stolenOwner) end)
            end

            task_spawn(function() typeWordMobile(word, cleanPrompt) end)
        else
            matchLabel:SetText("Not Found")
        end
    end
end)

addInput(SolverGroup, "Letter Cap", "Max length...", function(v) lettercap = tonumber(v) or math_huge end)
addSlider(SolverGroup, "Typing Speed (WPM)", 100, 1000, 350, 10, "1000", function(v) typingWPM = v speedWordDelay = 60 / (typingWPM * 5) end)
addSlider(SolverGroup, "Fuse Delay %", 1, 95, 17, 1, "95", function(v) fusePercent = v / 100 end)

-- Тумблер Jitter + Ползунок секунд (от 0.01s до 0.30s)
addToggle(SolverGroup, "Human Jittering", true, function(v) jitterEnabled = v end)
addSecondsSlider(SolverGroup, "Jitter Delay", 0.01, 0.30, 0.11, function(v) jitterIntensity = v end)

addSlider(SolverGroup, "RNG Variation %", 0, 100, 25, 1, "100", function(v) rngVariationPercent = v end)
addSlider(SolverGroup, "Auto Join Delay", 1, 5, 2, 1, "5", function(v) autoJoinDelay = v end)

-- Правая колонка (Stats)
local dictStatusLabel = addStatRow(StatsGroup, "Game Dict:", "286592 (Ready)", false)
local elapsedLabel = addStatRow(StatsGroup, "Elapsed:", "00:00:00", false)
local turnsLabel = addStatRow(StatsGroup, "Turns:", "0", false)
local stolenStatLabel = addStatRow(StatsGroup, "Stolen:", "0", false)
local streakStatLabel = addStatRow(StatsGroup, "Streak:", "0", false)
local wpmStatLabel = addStatRow(StatsGroup, "Avg WPM:", "350", false)
local promptLabel = addStatRow(StatsGroup, "Prompt:", "Waiting...", false)
local solutionsLabel = addStatRow(StatsGroup, "Solutions:", "0", false)
local matchLabel = addStatRow(StatsGroup, "Match:", "Waiting...", true)
local fusionLabel = addStatRow(StatsGroup, "Fuse Progress:", "0.00s / 0.00s", false)

-- Правая колонка (Steal & Dict)
local stolenPoolLabel = addStatRow(StealGroup, "Stolen Pool:", "0 words", false)
local lastStolenLabel = addStatRow(StealGroup, "Last Stolen:", "None", true)
addToggle(StealGroup, "Enable Stealing", true, function(v) stealEnabled = v end)
addToggle(StealGroup, "Prioritize Stolen Words", true, function(v) preferStolenWords = v end)
addDropdown(StealGroup, "Word Priority", { "Common", "Hyphenated / Short", "Shortest", "Longest", "Random" }, 1, function(v) wordPriorityMode = v end)

-- === DICTIONARY INDEXING & BUFFERS ===
local globalWordsList = {}
local PromptIndex = {}
local CommonWordsMap = {}
local validCandidatesBuffer = {}
local specialMatchesBuffer = {}
local normalMatchesBuffer = {}
local commonCandidatesBuffer = {}
local fallbackCandidatesBuffer = {}

local function loadDictionaryAsync(url)
    task_spawn(function()
        local success, raw = pcall(function() return game:HttpGet(url) end)
        if not success or not raw then
            dictStatusLabel:SetText("Error!")
            return
        end

        local total = 0
        local seenSubstrings = {}
        for word in raw:gmatch("[^\r\n]+") do
            word = word:gsub("%s+", ""):lower()
            local wordLen = #word
            if wordLen >= 2 then
                total = total + 1
                table_insert(globalWordsList, word)
                table_clear(seenSubstrings)

                for len = 2, 3 do
                    for i = 1, wordLen - len + 1 do
                        local sub = string_sub(word, i, i + len - 1)
                        if not seenSubstrings[sub] then
                            seenSubstrings[sub] = true
                            local list = PromptIndex[sub]
                            if not list then
                                list = {}
                                PromptIndex[sub] = list
                            end
                            table_insert(list, word)
                        end
                    end
                end
            end
        end
        dictStatusLabel:SetText(total .. " (Ready)")
    end)
end

local function loadCommonDictionaryAsync(url)
    task_spawn(function()
        local success, raw = pcall(function() return game:HttpGet(url) end)
        if not success or not raw then return end
        local commonCount = 0
        for word in raw:gmatch("[^\r\n]+") do
            word = word:gsub("%s+", ""):lower()
            if #word >= 2 and word:match("^[a-z]+$") then
                CommonWordsMap[word] = true
                commonCount = commonCount + 1
            end
        end
    end)
end

local rawHwid = gethwid and gethwid() or (game:GetService("RbxAnalyticsService"):GetClientId())
local protectedDictUrl = string.format("https://roblox-key-api-zxnv.onrender.com/dictionary?key=%s&hwid=%s", tostring(userProvidedKey), tostring(rawHwid))
local protectedCommonDictUrl = string.format("https://roblox-key-api-zxnv.onrender.com/common-dictionary?key=%s&hwid=%s", tostring(userProvidedKey), tostring(rawHwid))

loadDictionaryAsync(protectedDictUrl)
loadCommonDictionaryAsync(protectedCommonDictUrl)

local function isValidDictionaryWord(word)
    if not word or #word < 2 then return false end
    if CommonWordsMap[word] then return true end
    local sub = string_sub(word, 1, 2)
    local list = PromptIndex[sub]
    if list then
        for i = 1, #list do
            if list[i] == word then return true end
        end
    end
    return false
end

-- === FULL ROUND RESET ===
local function resetRoundState()
    typingSessionId = typingSessionId + 1
    table_clear(sessionUsedWords)
    lastWord = ""
    activePrompt = ""
    lastSubmittedPrompt = ""
    totalTurns = 0
    lastRecordedTurnPossessor = nil
    isTyping = false
    currentFusionStats = "0.00s / 0.00s"

    for i = #stolenReadyPool, 1, -1 do
        if not Players:GetPlayerByUserId(stolenReadyPool[i].userId) then
            table_remove(stolenReadyPool, i)
        end
    end
    table_clear(lastBuffers)
    lastPossessor = nil

    stolenPoolLabel:SetText(#stolenReadyPool .. " words")
    turnsLabel:SetText("0")
    promptLabel:SetText("Waiting...")
    solutionsLabel:SetText("0")
    matchLabel:SetText("Waiting...")
    fusionLabel:SetText("0.00s / 0.00s")
end

-- === GET TURN & TEXTBOX ===
local function GetTurn()
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end
    local gameUI = playerGui:FindFirstChild("GameUI", true)
    if not gameUI then return nil end
    local typeBox = gameUI:FindFirstChild("Typebox", true)
    if typeBox and typeBox.Visible then
        return LocalPlayer.UserId
    end
    return nil
end

local function getGameTextBox()
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end
    local gameUI = playerGui:FindFirstChild("GameUI", true)
    if gameUI then
        local typeBox = gameUI:FindFirstChild("Typebox", true)
        if typeBox and typeBox:IsA("TextBox") then
            return typeBox
        end
    end
    return nil
end

local function isUserTypingInChat()
    local focused = UserInputService:GetFocusedTextBox()
    if focused then
        local gameBox = getGameTextBox()
        if gameBox and focused == gameBox then
            return false
        end
        return true
    end
    return false
end

-- === PROMPT PARSERS ===
local framesBuffer = {}
local function GetLetters()
    if GetTurn() ~= LocalPlayer.UserId then return "" end
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return "" end
    local gameUI = playerGui:FindFirstChild("GameUI", true)
    if not gameUI then return "" end

    local textFrame = gameUI:FindFirstChild("TextFrame", true)
    if textFrame then
        table_clear(framesBuffer)
        for _, child in pairs(textFrame:GetChildren()) do
            if child.Name == "LetterFrame" and child:IsA("Frame") and child.Visible then
                table_insert(framesBuffer, child)
            end
        end
        local count = #framesBuffer
        if count >= 2 then
            table_sort(framesBuffer, function(a, b)
                return a.AbsolutePosition.X < b.AbsolutePosition.X
            end)
            local assembledPrompt = ""
            for i = 1, count do
                local frame = framesBuffer[i]
                local img = frame:FindFirstChild("Letter")
                if img and img.Visible then
                    local txtLabel = img:FindFirstChildOfClass("TextLabel")
                    if txtLabel and txtLabel.Text and txtLabel.Visible and txtLabel.TextTransparency < 1 then
                        local char = txtLabel.Text
                        if char:match("%a") then
                            assembledPrompt = assembledPrompt .. char
                        end
                    end
                end
            end
            local finalPrompt = assembledPrompt:upper()
            if #finalPrompt >= 2 then
                return finalPrompt
            end
        end
    end

    local promptLbl = gameUI:FindFirstChild("PromptLabel", true)
    if promptLbl and promptLbl:IsA("TextLabel") and promptLbl.Visible then
        local txt = promptLbl.Text:gsub("%s+", ""):upper()
        if txt ~= "WAITING" and txt ~= "WAITING..." and #txt >= 2 then
            return txt
        end
    end
    return ""
end

local function GetPassiveLetters()
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return "" end
    local gameUI = playerGui:FindFirstChild("GameUI", true)
    if not gameUI then return "" end

    local textFrame = gameUI:FindFirstChild("TextFrame", true)
    if textFrame and textFrame.Visible then
        local pBuffer = {}
        for _, child in pairs(textFrame:GetChildren()) do
            if child.Name == "LetterFrame" and child:IsA("Frame") and child.Visible then
                table_insert(pBuffer, child)
            end
        end
        local count = #pBuffer
        if count >= 2 then
            table_sort(pBuffer, function(a, b)
                return a.AbsolutePosition.X < b.AbsolutePosition.X
            end)
            local assembled = ""
            for i = 1, count do
                local img = pBuffer[i]:FindFirstChild("Letter")
                if img and img.Visible then
                    local txtLabel = img:FindFirstChildOfClass("TextLabel")
                    if txtLabel and txtLabel.Text and txtLabel.Visible and txtLabel.TextTransparency < 1 then
                        local char = txtLabel.Text
                        if char:match("^%a$") then
                            assembled = assembled .. char
                        end
                    end
                end
            end
            local final = assembled:upper()
            if #final >= 2 then
                return final
            end
        end
    end

    local promptLbl = gameUI:FindFirstChild("PromptLabel", true)
    if promptLbl and promptLbl:IsA("TextLabel") and promptLbl.Visible then
        local txt = promptLbl.Text:gsub("%s+", ""):upper()
        if txt ~= "WAITING" and txt ~= "WAITING..." and #txt >= 2 and txt:match("^%a+$") then
            return txt
        end
    end
    return ""
end

-- === FUSE DATA ===
local function getInfoTable()
    local s, r = pcall(function()
        local getupvaluesFunc = debug_getupvalues or getupvalues
        local getinfoFunc = debug_getinfo or debug.getinfo
        if type(getgc) ~= "function" or type(getupvaluesFunc) ~= "function" then return nil end
        local latestTable = nil
        local latestFuseStart = -1
        for _, v in pairs(getgc()) do
            if type(v) == "function" then
                local info = getinfoFunc and getinfoFunc(v)
                if info and info.name == "updateInfoFrame" then
                    for _, vv in ipairs(getupvaluesFunc(v)) do
                        if type(vv) == "table" and vv.FuseStart ~= nil and vv.FuseRate ~= nil then
                            local fStart = tonumber(vv.FuseStart) or 0
                            local fRate = tonumber(vv.FuseRate) or 0
                            if fRate ~= 0 and fStart > latestFuseStart then
                                latestFuseStart = fStart
                                latestTable = vv
                            end
                        end
                    end
                end
            end
        end
        return latestTable
    end)
    if s and type(r) == "table" then return r end
    return nil
end

local function waitFuseProgress(targetSession)
    if not useFuseProgress then return end
    local tbl = getInfoTable()
    if not tbl or not tbl.FuseStart or tbl.FuseStart <= 1000 or not tbl.FuseRate or tbl.FuseRate == 0 then
        if checkWordDelay > 0 and not instanttype then
            task_wait(applyRngVariation(checkWordDelay))
        end
        return
    end

    local fuseRate = tbl.FuseRate
    local totalFuseTime = math.abs(1 / fuseRate)
    if totalFuseTime <= 0.1 or totalFuseTime > 30 then
        if checkWordDelay > 0 and not instanttype then
            task_wait(applyRngVariation(checkWordDelay))
        end
        return
    end

    local targetWaitSeconds = math_max(0, (totalFuseTime * fusePercent) - 0.05)
    currentFusionStats = string.format("%.2fs / %.2fs", targetWaitSeconds, totalFuseTime)
    fusionLabel:SetText(currentFusionStats)

    if targetWaitSeconds > 0 and typingSessionId == targetSession then
        task_wait(targetWaitSeconds)
    end
end

-- === SMART TYPING ===
function typeWordMobile(word, targetPrompt)
    if isTyping then return end
    isTyping = true
    typingSessionId = typingSessionId + 1
    local currentSession = typingSessionId

    local success, err = pcall(function()
        if not instanttype then
            if useFuseProgress then
                waitFuseProgress(currentSession)
            elseif checkWordDelay > 0 then
                task_wait(applyRngVariation(checkWordDelay))
            end
        end

        if currentSession ~= typingSessionId then return end

        while isUserTypingInChat() and GetTurn() == LocalPlayer.UserId and currentSession == typingSessionId do
            task_wait(0.08)
        end

        if currentSession ~= typingSessionId or GetTurn() ~= LocalPlayer.UserId then return end

        local cachedBox = getGameTextBox()
        if cachedBox then
            cachedBox:CaptureFocus()
            task_wait(0.01)
            cachedBox.Text = ""
            task_wait(0.01)
        end

        local interrupted = false
        local typeStartTime = os_clock()

        for i = 1, #word do
            if currentSession ~= typingSessionId or GetTurn() ~= LocalPlayer.UserId then
                interrupted = true
                break
            end

            local char = string_sub(word, i, i)

            if typosEnabled and not instanttype and math_random(1, 100) <= typoChancePercent then
                local wrongCharIndex = math_random(1, #alphabet)
                local wrongChar = string_sub(alphabet, wrongCharIndex, wrongCharIndex)
                if wrongChar ~= char then
                    local wrongKeyCode = Enum.KeyCode[wrongChar:upper()]
                    if wrongKeyCode then
                        Vim:SendKeyEvent(true, wrongKeyCode, false, game)
                        task_wait(0.01)
                        Vim:SendKeyEvent(false, wrongKeyCode, false, game)
                        task_wait(math_random(200, 400) / 1000)
                        Vim:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
                        task_wait(0.01)
                        Vim:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
                        task_wait(math_random(100, 250) / 1000)
                    end
                end
            end

            local keyCode = nil
            if char == "-" then
                keyCode = Enum.KeyCode.Minus
            elseif char == "'" then
                keyCode = Enum.KeyCode.Quote
            else
                keyCode = Enum.KeyCode[char:upper()]
            end

            if keyCode then
                local currentDelay = speedWordDelay
                if instanttype then
                    currentDelay = 0
                else
                    currentDelay = applyRngVariation(speedWordDelay)
                    if jitterEnabled then
                        local currentJitter = applyRngVariation(jitterIntensity)
                        local randomOffset = (math_random() * 2 - 1) * currentJitter
                        currentDelay = currentDelay + randomOffset
                    end
                    if currentDelay < 0.005 then currentDelay = 0.005 end
                end

                if i == 1 and cachedBox and cachedBox.Text ~= "" then
                    cachedBox.Text = ""
                end

                Vim:SendKeyEvent(true, keyCode, false, game)
                if currentDelay > 0 then task_wait(currentDelay / 2) end
                Vim:SendKeyEvent(false, keyCode, false, game)
                if currentDelay > 0 then task_wait(currentDelay / 2) end
            end
        end

        if not interrupted and currentSession == typingSessionId then
            local finalTurn = GetTurn()
            if finalTurn == LocalPlayer.UserId then
                if not instanttype then task_wait(0.02) end
                Vim:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                if not instanttype then task_wait(0.01) end
                Vim:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                if not instanttype then task_wait(0.03) end
                lastSubmittedPrompt = targetPrompt
                activePrompt = ""

                local timeElapsed = math_max(os_clock() - typeStartTime, 0.05)
                local calcWpm = math_floor(((#word / 5) / (timeElapsed / 60)))
                myGlobalStats.wpm = math_clamp(calcWpm, 80, 950)
                wpmStatLabel:SetText(tostring(myGlobalStats.wpm))
            else
                if cachedBox then cachedBox.Text = "" end
            end
        end
    end)

    if not success then
        warn("⚠️ [TYPE ERROR]: " .. tostring(err))
    end
    if currentSession == typingSessionId then
        isTyping = false
    end
end

-- === SEARCH WORDS LOGIC ===
function findWordForPrompt(promptLower, previewOnly)
    if not promptLower or promptLower == "" then return nil, nil end

    if preferStolenWords and #stolenReadyPool > 0 then
        for i = #stolenReadyPool, 1, -1 do
            local item = stolenReadyPool[i]
            if not Players:GetPlayerByUserId(item.userId) then
                table_remove(stolenReadyPool, i)
            end
        end

        for idx, item in ipairs(stolenReadyPool) do
            local sWord = item.word
            local ownerPlayer = Players:GetPlayerByUserId(item.userId)
            if ownerPlayer and string_find(sWord, promptLower, 1, true) and #sWord <= lettercap and not sessionUsedWords[sWord] and sWord:upper() ~= lastWord then
                local stolenFromUser = item.from
                if not previewOnly then
                    table_remove(stolenReadyPool, idx)
                    myGlobalStats.stolen = myGlobalStats.stolen + 1
                    stolenStatLabel:SetText(tostring(myGlobalStats.stolen))
                    stolenPoolLabel:SetText(#stolenReadyPool .. " words")
                end
                return sWord, stolenFromUser
            end
        end
    end

    table_clear(validCandidatesBuffer)
    table_clear(specialMatchesBuffer)
    table_clear(normalMatchesBuffer)
    table_clear(commonCandidatesBuffer)
    table_clear(fallbackCandidatesBuffer)

    local candidates = PromptIndex[promptLower]
    if candidates then
        for i = 1, #candidates do
            local candidate = candidates[i]
            if #candidate <= lettercap and not sessionUsedWords[candidate] and candidate:upper() ~= lastWord then
                table_insert(validCandidatesBuffer, candidate)
                if CommonWordsMap[candidate] then
                    table_insert(commonCandidatesBuffer, candidate)
                end
                if string_find(candidate, "-", 1, true) or string_find(candidate, "'", 1, true) then
                    table_insert(specialMatchesBuffer, candidate)
                else
                    table_insert(normalMatchesBuffer, candidate)
                end
            end
        end
    end

    if not previewOnly then
        solutionsLabel:SetText(tostring(#validCandidatesBuffer))
    end

    if #validCandidatesBuffer > 0 then
        local currentMode = wordPriorityMode
        if type(currentMode) == "table" then
            currentMode = wordPriorityMode[1] or "Common"
        end

        if currentMode == "Common" then
            if #commonCandidatesBuffer > 0 then
                return commonCandidatesBuffer[math_random(1, #commonCandidatesBuffer)], nil
            end
            local effectiveFallbackMax = math_min(15, lettercap)
            for i = 1, #validCandidatesBuffer do
                local word = validCandidatesBuffer[i]
                if #word <= effectiveFallbackMax then
                    table_insert(fallbackCandidatesBuffer, word)
                end
            end
            if #fallbackCandidatesBuffer > 0 then
                return fallbackCandidatesBuffer[math_random(1, #fallbackCandidatesBuffer)], nil
            else
                return validCandidatesBuffer[math_random(1, #validCandidatesBuffer)], nil
            end
        end

        if currentMode == "Hyphenated / Short" or currentMode == "Hyphenated/short" then
            if #specialMatchesBuffer > 0 then
                return specialMatchesBuffer[math_random(1, #specialMatchesBuffer)], nil
            elseif #normalMatchesBuffer > 0 then
                local shortest = normalMatchesBuffer[1]
                for i = 2, #normalMatchesBuffer do
                    local word = normalMatchesBuffer[i]
                    if #word < #shortest then
                        shortest = word
                    end
                end
                return shortest, nil
            end
        elseif currentMode == "Shortest" then
            local shortest = validCandidatesBuffer[1]
            for i = 2, #validCandidatesBuffer do
                local word = validCandidatesBuffer[i]
                if #word < #shortest then
                    shortest = word
                end
            end
            return shortest, nil
        elseif currentMode == "Longest" then
            local longest = validCandidatesBuffer[1]
            for i = 2, #validCandidatesBuffer do
                local word = validCandidatesBuffer[i]
                if #word > #longest then
                    longest = word
                end
            end
            return longest, nil
        end

        return validCandidatesBuffer[math_random(1, #validCandidatesBuffer)], nil
    end

    return nil, nil
end

function ProcessMyTurn()
    if not autosearch or isTyping then return end
    local detectedRaw = GetLetters()
    if not detectedRaw or detectedRaw == "" then return end

    local cleanPrompt = detectedRaw:lower():gsub("%s+", "")
    if cleanPrompt == lastSubmittedPrompt then return end
    lastSubmittedPrompt = ""

    local word, stolenOwner = findWordForPrompt(cleanPrompt, false)
    if word then
        sessionUsedWords[word] = true
        lastWord = word:upper()
        activePrompt = cleanPrompt

        promptLabel:SetText(detectedRaw:upper())
        matchLabel:SetText(word:upper())

        if stolenOwner then
            lastStolenLabel:SetText(stolenOwner .. " (" .. word:upper() .. ")")
            task_spawn(function() PlayStealWordEffect(word, stolenOwner) end)
        end

        if autotype then
            task_spawn(function()
                typeWordMobile(word, cleanPrompt)
            end)
        end
    else
        matchLabel:SetText("Not Found")
    end
end

local function UpdatePassivePromptDisplay()
    if GetTurn() == LocalPlayer.UserId or isTyping then return end
    local raw = GetPassiveLetters()
    if raw and raw ~= "" then
        local clean = raw:lower():gsub("%s+", "")
        promptLabel:SetText(raw:upper())
        local word = findWordForPrompt(clean, true)
        if word then
            matchLabel:SetText(word:upper())
        else
            matchLabel:SetText("Not Found")
        end
    end
end

-- === NETWORK EVENTS ===
local Games = ReplicatedStorage:WaitForChild("Network", 10)
if Games then
    Games = Games:WaitForChild("Games", 10)
end

local Network = ReplicatedStorage:FindFirstChild("Network")
if Network then
    local gameEvent = Network:FindFirstChild("GameEvent", true)
    if gameEvent then
        gameEvent.OnClientEvent:Connect(function(...)
            local args = {...}
            local eventType = nil
            local targetId = nil

            for _, v in ipairs(args) do
                if type(v) == "string" and (v == "TypingEvent" or v == "ChangePossessor" or v == "Winner" or v == "EndGame") then
                    eventType = v
                elseif type(v) == "number" and v > 1000 then
                    targetId = v
                end
            end

            local rawType = tostring(eventType or args[2] or args[1]):lower()

            if rawType == "typingevent" then
                local pId = targetId or args[3] or args[2]
                local text = tostring(args[4] or args[3] or args[#args])
                if pId and LocalPlayer and pId ~= LocalPlayer.UserId then
                    local clean = text:gsub("%s+", ""):lower()
                    if #clean > 0 then
                        lastBuffers[pId] = clean
                        lastPossessor = pId
                    end
                end
            elseif rawType == "changepossessor" then
                local newPossessor = targetId or args[3] or args[2]
                
                if type(newPossessor) == "number" and newPossessor > 0 and newPossessor ~= lastRecordedTurnPossessor then
                    lastRecordedTurnPossessor = newPossessor
                    totalTurns = totalTurns + 1
                    turnsLabel:SetText(tostring(totalTurns))
                end

                local pId = lastPossessor
                local word = pId and lastBuffers[pId]

                if stealEnabled and pId and word and LocalPlayer and pId ~= LocalPlayer.UserId then
                    if isValidDictionaryWord(word) then
                        sessionUsedWords[word] = true
                        local plr = Players:GetPlayerByUserId(pId)
                        local pName = plr and plr.Name or ("UserId_" .. tostring(pId))

                        table_insert(stolenReadyPool, {
                            word = word,
                            from = pName,
                            userId = pId
                        })

                        lastStolenLabel:SetText(pName .. " (" .. word:upper() .. ")")
                        stolenPoolLabel:SetText(#stolenReadyPool .. " words")
                    end
                    lastBuffers[pId] = nil
                end

                if type(newPossessor) == "number" then
                    lastPossessor = newPossessor
                end

                task_spawn(function()
                    task_wait(0.06)
                    lastSubmittedPrompt = ""
                    activePrompt = ""
                    if GetTurn() == LocalPlayer.UserId then
                        ProcessMyTurn()
                    else
                        UpdatePassivePromptDisplay()
                    end
                end)
            elseif rawType == "winner" or rawType == "endgame" then
                lastRecordedTurnPossessor = nil
                local winnerId = targetId or args[3] or args[2]
                if winnerId == LocalPlayer.UserId then
                    myGlobalStats.winStreak = myGlobalStats.winStreak + 1
                else
                    myGlobalStats.winStreak = 0
                end
                streakStatLabel:SetText(tostring(myGlobalStats.winStreak))
            end
        end)
    end
end

-- === FAST TURN WATCHER ===
task_spawn(function()
    while true do
        if GetTurn() == LocalPlayer.UserId then
            if autosearch and not isTyping then
                local currentLetters = GetLetters()
                if currentLetters ~= "" then
                    local clean = currentLetters:lower():gsub("%s+", "")
                    if (clean ~= activePrompt or activePrompt == "") and clean ~= lastSubmittedPrompt then
                        ProcessMyTurn()
                    end
                else
                    activePrompt = ""
                    lastSubmittedPrompt = ""
                end
            end
            task_wait(0.04)
        else
            activePrompt = ""
            lastSubmittedPrompt = ""
            task_wait(0.15)
        end
    end
end)

-- === BACKGROUND AUTO JOIN THREAD ===
if Games then
    local registerGame = Games:FindFirstChild("RegisterGame")
    if registerGame then
        registerGame.OnClientEvent:Connect(function(gameRoomID)
            resetRoundState()
            if autojoin then
                task_spawn(function()
                    if autoJoinDelay > 0 then task_wait(autoJoinDelay) end
                    pcall(function()
                        Games.GameEvent:FireServer(gameRoomID, "JoinGame")
                    end)
                end)
            end
            if autosearch then
                task_spawn(ProcessMyTurn)
            end
        end)
    end
end

-- === TIMER LOOP ===
task_spawn(function()
    while true do
        xpcall(function()
            while task_wait(2) do
                local elapsed = os_time() - startTime
                local hours = math_floor(elapsed / 3600)
                local minutes = math_floor((elapsed % 3600) / 60)
                local seconds = elapsed % 60
                elapsedLabel:SetText(string.format("%02d:%02d:%02d", hours, minutes, seconds))
            end
        end, function(err)
            warn("[CRASH] Timer Loop errored: " .. tostring(err))
        end)
        task_wait(2)
    end
end)
