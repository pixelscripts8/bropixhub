--[[
    WARNING: Heads up! UnpatchaBomb Pro Edition (Render Backend Dictionary)
    - Uses your Render API / dictionary endpoint just like Bro-Pixel Hub
    - Instant indexed prompt search (10k primary + 286k fallback)
    - Full removal of laggy getgc()
    - Lightweight anti-repeat listener
]]

local Services = {
    Players = game:GetService("Players"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    VirtualInputManager = game:GetService("VirtualInputManager"),
    UserInputService = game:GetService("UserInputService"),
    TweenService = game:GetService("TweenService"),
    RunService = game:GetService("RunService"),
    CoreGui = game:GetService("CoreGui"),
    HttpService = game:GetService("HttpService")
}

local LocalPlayer = Services.Players.LocalPlayer

-- === AUTH & API CONFIG ===
local _G_ENV = (type(getgenv) == "function" and getgenv()) or _G or {}
local userProvidedKey = _G_ENV.PixelKey or _G.PixelKey or (type(PixelKey) ~= "nil" and PixelKey)
if not userProvidedKey or userProvidedKey == "" then
    if LocalPlayer then
        LocalPlayer:Kick("❌ [Auth Error]: Set getgenv().PixelKey = 'YOUR_KEY' before execution.")
    end
    return
end

local rawHwid = (type(gethwid) == "function" and gethwid()) or (game:GetService("RbxAnalyticsService"):GetClientId())
local dictUrl = string.format("https://roblox-key-api-zxnv.onrender.com/dictionary?key=%s&hwid=%s", tostring(userProvidedKey), tostring(rawHwid))
local commonUrl = string.format("https://roblox-key-api-zxnv.onrender.com/common-dictionary?key=%s&hwid=%s", tostring(userProvidedKey), tostring(rawHwid))

local PrimaryPromptIndex = {}
local FallbackPromptIndex = {}
local isDictionaryReady = false

-- Функция построения индекса
local function buildIndex(sourceTbl, indexTbl)
    if type(sourceTbl) ~= "table" then return end
    local seen = {}
    for _, word in ipairs(sourceTbl) do
        if type(word) == "string" then
            word = word:lower():gsub("[%-%'%s+]", "")
            if #word >= 2 and not seen[word] then
                seen[word] = true
                local len = #word
                local seenSub = {}
                for l = 2, math.min(len, 4) do
                    for i = 1, len - l + 1 do
                        local sub = string.sub(word, i, i + l - 1)
                        if not seenSub[sub] then
                            seenSub[sub] = true
                            local list = indexTbl[sub]
                            if not list then
                                list = {}
                                indexTbl[sub] = list
                            end
                            list[#list + 1] = word
                        end
                    end
                end
            end
        end
    end
end

-- Асинхронная загрузка словарей с твоего Render сервера
task.spawn(function()
    print("⏳ [UnpatchaBomb]: Fetching dictionaries from Render server...")

    local primaryWordsList = {}
    local fallbackWordsList = {}

    -- Качаем Common (10k)
    local okCommon, rawCommon = pcall(function() return game:HttpGet(commonUrl) end)
    if okCommon and rawCommon then
        for word in rawCommon:gmatch("[^\r\n]+") do
            word = word:gsub("%s+", ""):lower()
            if #word >= 2 then table.insert(primaryWordsList, word) end
        end
    end

    -- Качаем Mega (286k)
    local okDict, rawDict = pcall(function() return game:HttpGet(dictUrl) end)
    if okDict and rawDict then
        for word in rawDict:gmatch("[^\r\n]+") do
            word = word:gsub("%s+", ""):lower()
            if #word >= 2 then table.insert(fallbackWordsList, word) end
        end
    end

    -- Страховка на случай если апишка долго отвечает
    if #fallbackWordsList == 0 then
        table.insert(fallbackWordsList, "apple")
        table.insert(fallbackWordsList, "application")
    end
    if #primaryWordsList == 0 then
        primaryWordsList = fallbackWordsList
    end

    -- Индексируем в фоне
    buildIndex(primaryWordsList, PrimaryPromptIndex)
    buildIndex(fallbackWordsList, FallbackPromptIndex)

    isDictionaryReady = true
    print("✅ [UnpatchaBomb]: Dictionaries loaded & indexed successfully!")
end)

local TypoNeighbours = {
    a="s", b="v", c="v", d="f", e="w", f="d", g="h", h="j",
    i="o", j="h", k="l", l="k", m="n", n="m", o="i", p="o",
    q="w", r="t", s="a", t="r", u="y", v="c", w="e", x="z",
    y="u", z="x",
}

local Games = Services.ReplicatedStorage:WaitForChild("Network", 10)
if Games then Games = Games:WaitForChild("Games", 10) end

local GameID  = "-1"
local UsedWords  = {}
local Typing     = false
local TypingActive = false
local LastWord   = ""

local Settings = {
    WordList      = 0,
    AutoType      = false,
    AutoJoin      = false,
    WPM           = 120,
    WordTypeDelay = 0.3,
    HumaniseWPM   = true,
    ReactionTime  = 0.35,
    TypoChance    = 0.04,
    BurstMin      = 3,
    BurstMax      = 7,
    MinLen        = 1,
    MaxLen        = 99
}

local burstCounter  = 0
local burstTarget   = math.random(3, 7)

local function GetLetterDelay()
    local base = 60 / (Settings.WPM * 5)
    if Settings.HumaniseWPM then
        local roll = math.random()
        if roll < 0.15 then
            base = base * (0.35 + math.random() * 0.25)
        elseif roll < 0.80 then
            base = base * (0.80 + math.random() * 0.40)
        else
            base = base * (1.20 + math.random() * 0.60)
        end
        burstCounter = burstCounter + 1
        if burstCounter >= burstTarget then
            burstCounter = 0
            burstTarget  = math.random(Settings.BurstMin, Settings.BurstMax)
            base = base + (0.04 + math.random() * 0.08)
        end
    end
    return math.max(base, 0.005)
end

-- Функция поиска с индексацией
local function FindWordAuto(prompt)
    if not isDictionaryReady or not prompt or prompt == "" then return nil end
    local lowerPrompt = string.lower(prompt):gsub("[%-%'%s+]", "")
    
    local function searchInIndex(index)
        local subKey = string.sub(lowerPrompt, 1, math.min(#lowerPrompt, 3))
        local candidates = index[subKey] or index[string.sub(lowerPrompt, 1, 2)]
        if not candidates then return nil end
        
        local best, bestLen = nil, 0
        for _, v in ipairs(candidates) do
            if string.find(v, lowerPrompt, 1, true)
                and not table.find(UsedWords, string.upper(v))
                and string.upper(v) ~= LastWord
                and #v >= Settings.MinLen
                and #v <= Settings.MaxLen
                and #v > bestLen
            then
                best = v
                bestLen = #v
            end
        end
        return best
    end

    local found = searchInIndex(PrimaryPromptIndex)
    if not found then
        found = searchInIndex(FallbackPromptIndex)
    end

    if found then
        local upperWord = string.upper(found)
        table.insert(UsedWords, upperWord)
        return upperWord
    end
    return nil
end

local function findWord(str)
    return FindWordAuto(str)
end

-- === УПРАВЛЕНИЕ UI БЕЗ GETGC ===
local function getGameUI()
    local playerGui = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return nil end
    return playerGui:FindFirstChild("GameUI", true)
end

local function GetTurn()
    local gameUI = getGameUI()
    if not gameUI then return nil end
    local typeBox = gameUI:FindFirstChild("Typebox", true)
    if typeBox and typeBox.Visible then
        return LocalPlayer.UserId
    end
    return nil
end

local function GetLetters()
    local gameUI = getGameUI()
    if not gameUI then return "" end

    local textFrame = gameUI:FindFirstChild("TextFrame", true)
    if textFrame then
        local assembledPrompt = ""
        for _, child in ipairs(textFrame:GetChildren()) do
            if child.Name == "LetterFrame" and child:IsA("Frame") and child.Visible then
                local img = child:FindFirstChild("Letter")
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
        end
        local finalPrompt = assembledPrompt:upper()
        if #finalPrompt >= 2 then
            return finalPrompt
        end
    end

    local PromptLbl = gameUI:FindFirstChild("PromptLabel", true)
    if PromptLbl and PromptLbl:IsA("TextLabel") and PromptLbl.Visible then
        local txt = PromptLbl.Text:gsub("%s+", ""):upper()
        if txt ~= "WAITING" and txt ~= "WAITING..." and #txt >= 2 then
            return txt
        end
    end
    return ""
end

-- === ЛЕГКИЙ СЛУШАТЕЛЬ ЧУЖИХ СЛОВ (АНТИ-ПОВТОР) ===
local Network = Services.ReplicatedStorage:FindFirstChild("Network")
if Network then
    local gameEvent = Network:FindFirstChild("GameEvent", true)
    if gameEvent then
        gameEvent.OnClientEvent:Connect(function(...)
            local args = {...}
            task.spawn(function()
                for i = 1, #args do
                    local v = args[i]
                    if type(v) == "string" and #v >= 2 and #v <= 30 then
                        local cleanWord = v:gsub("[%-%'%s+]", ""):upper()
                        if cleanWord:match("^[A-Z]+$") then
                            if not table.find(UsedWords, cleanWord) then
                                table.insert(UsedWords, cleanWord)
                            end
                        end
                    end
                end
            end)
        end)
    end
end

local function SimulateKey(character)
    local keyCode
    if character == "\n" or character == "\r" then
        keyCode = Enum.KeyCode.Return
    else
        pcall(function() keyCode = Enum.KeyCode[string.upper(character)] end)
    end
    if keyCode then
        Services.VirtualInputManager:SendKeyEvent(true,  keyCode, false, game)
        task.wait(0.01)
        Services.VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end
end

local function SimulateBackspace()
    Services.VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.Backspace, false, game)
    task.wait(0.01)
    Services.VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
end

if Services.CoreGui:FindFirstChild("Unpatchabomb") then
    Services.CoreGui.Unpatchabomb:Destroy()
end

local Unpatchabomb = Instance.new("ScreenGui")
Unpatchabomb.Name             = "Unpatchabomb"
Unpatchabomb.Parent           = Services.CoreGui
Unpatchabomb.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
Unpatchabomb.ResetOnSpawn     = false

local OuterFrame = Instance.new("Frame")
OuterFrame.Name                 = "OuterFrame"
OuterFrame.Parent               = Unpatchabomb
OuterFrame.BackgroundColor3     = Color3.fromRGB(25, 25, 30)
OuterFrame.BorderSizePixel      = 0
OuterFrame.Position             = UDim2.new(0.5, -160, 0.5, -240)
OuterFrame.Size                 = UDim2.new(0, 320, 0, 0)
OuterFrame.ClipsDescendants     = true
OuterFrame.BackgroundTransparency = 1
Instance.new("UICorner", OuterFrame).CornerRadius = UDim.new(0, 8)

local TopFrame = Instance.new("Frame")
TopFrame.Parent             = OuterFrame
TopFrame.BackgroundColor3   = Color3.fromRGB(12, 12, 12)
TopFrame.BorderSizePixel    = 0
TopFrame.Size               = UDim2.new(1, 0, 0, 28)
TopFrame.BackgroundTransparency = 1
Instance.new("UICorner", TopFrame).CornerRadius = UDim.new(0, 8)

local T1 = Instance.new("TextLabel")
T1.Parent               = TopFrame
T1.BackgroundTransparency = 1
T1.Size                 = UDim2.new(0.5, 0, 1, 0)
T1.Position             = UDim2.new(0.04, 0, 0, 0)
T1.Font                 = Enum.Font.GothamBold
T1.Text                 = "UnpatchaBomb ⚡ Pro"
T1.TextColor3           = Color3.fromRGB(255, 255, 255)
T1.TextSize             = 14
T1.TextXAlignment       = Enum.TextXAlignment.Left

local T2 = Instance.new("TextLabel")
T2.Parent               = TopFrame
T2.BackgroundTransparency = 1
T2.Size                 = UDim2.new(0.4, 0, 1, 0)
T2.Position             = UDim2.new(0.34, 0, 0, 0)
T2.Font                 = Enum.Font.Gotham
T2.TextColor3           = Color3.fromRGB(200, 200, 200)
T2.TextSize             = 14
T2.TextXAlignment       = Enum.TextXAlignment.Left

local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Parent               = TopFrame
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Position             = UDim2.new(1, -28, 0, 0)
MinimizeButton.Size                 = UDim2.new(0, 28, 1, 0)
MinimizeButton.Font                 = Enum.Font.GothamBold
MinimizeButton.Text                 = "—"
MinimizeButton.TextColor3           = Color3.fromRGB(255, 255, 255)
MinimizeButton.TextSize             = 18

local IntroFrame = Instance.new("Frame")
IntroFrame.Parent           = OuterFrame
IntroFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
IntroFrame.BorderSizePixel  = 0
IntroFrame.Position         = UDim2.new(0, 0, 0, 28)
IntroFrame.Size             = UDim2.new(1, 0, 1, -28)
IntroFrame.ZIndex           = 5

local function MakeIntroLabel(posY, sizeY, text, font)
    local l = Instance.new("TextLabel")
    l.Parent              = IntroFrame
    l.BackgroundTransparency = 1
    l.Position            = UDim2.new(0, 0, posY, 0)
    l.Size                = UDim2.new(1, 0, sizeY, 0)
    l.Font                = font or Enum.Font.Gotham
    l.Text                = text
    l.TextColor3          = Color3.fromRGB(255, 255, 255)
    l.TextScaled          = true
    l.ZIndex              = 5
    return l
end

MakeIntroLabel(0.38, 0.15, "UNPATCHABOMB", Enum.Font.GothamBold)
MakeIntroLabel(0.54, 0.08, "PRO EDITION (RENDER DICT)")
local LoadingLabel = MakeIntroLabel(0.76, 0.08, "Loading Dict...")

task.spawn(function()
    while not isDictionaryReady and LoadingLabel and LoadingLabel.Parent do
        LoadingLabel.Text = "Loading Dict."  ; task.wait(0.15)
        LoadingLabel.Text = "Loading Dict.." ; task.wait(0.15)
        LoadingLabel.Text = "Loading Dict..."; task.wait(0.15)
    end
    if LoadingLabel then LoadingLabel.Text = "Ready!" end
end)

local MainFrame = Instance.new("Frame")
MainFrame.Parent            = OuterFrame
MainFrame.BackgroundColor3  = Color3.fromRGB(22, 22, 22)
MainFrame.BorderSizePixel   = 0
MainFrame.Position          = UDim2.new(0, 0, 0, 28)
MainFrame.Size              = UDim2.new(1, 0, 1, -28)
MainFrame.ClipsDescendants  = true
MainFrame.BackgroundTransparency = 1

local PatrioticGradient = Instance.new("UIGradient")
PatrioticGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 20, 40)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 240, 240)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 60, 160))
})
PatrioticGradient.Rotation = 90
PatrioticGradient.Enabled = false
PatrioticGradient.Parent = OuterFrame

local StarOverlay = Instance.new("ImageLabel")
StarOverlay.Parent = OuterFrame
StarOverlay.BackgroundTransparency = 1
StarOverlay.Image = "rbxassetid://60768979"
StarOverlay.ImageColor3 = Color3.fromRGB(255, 255, 255)
StarOverlay.ImageTransparency = 0.4
StarOverlay.ScaleType = Enum.ScaleType.Tile
StarOverlay.TileSize = UDim2.new(0, 64, 0, 64)
StarOverlay.Size = UDim2.new(1, 0, 1, 0)
StarOverlay.Position = UDim2.new(0, 0, 0, 0)
StarOverlay.ZIndex = 0
StarOverlay.Visible = false

local FireworkOverlay = Instance.new("ImageLabel")
FireworkOverlay.Parent = OuterFrame
FireworkOverlay.BackgroundTransparency = 1
FireworkOverlay.Image = "rbxassetid://5028857084"
FireworkOverlay.ImageColor3 = Color3.fromRGB(255, 255, 255)
FireworkOverlay.ImageTransparency = 0.7
FireworkOverlay.Size = UDim2.new(1.2, 0, 1.2, 0)
FireworkOverlay.Position = UDim2.new(-0.1, 0, -0.1, 0)
FireworkOverlay.ZIndex = 1
FireworkOverlay.Visible = false

Services.TweenService:Create(
    OuterFrame,
    TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
    {Size = UDim2.new(0, 320, 0, 480),
     Position = UDim2.new(0.5, -160, 0.5, -240),
     BackgroundTransparency = 0}
):Play()

task.spawn(function()
    for i = 1, 10 do
        MainFrame.BackgroundTransparency = 1 - i/10
        TopFrame.BackgroundTransparency  = 1 - i/10
        task.wait(0.03)
    end
end)

local function MakeLabel(parent, posY, sizeY, text, font)
    local l = Instance.new("TextLabel")
    l.Parent              = parent
    l.BackgroundTransparency = 1
    l.Position            = UDim2.new(0.02, 0, posY, 0)
    l.Size                = UDim2.new(0.96, 0, sizeY, 0)
    l.Font                = font or Enum.Font.Gotham
    l.Text                = text
    l.TextColor3          = Color3.fromRGB(255, 255, 255)
    l.TextScaled          = true
    return l
end

local function MakeButton(parent, posY, sizeY, text, color)
    local b = Instance.new("TextButton")
    b.Parent            = parent
    b.BackgroundColor3  = color or Color3.fromRGB(35, 35, 35)
    b.BorderSizePixel   = 0
    b.Position          = UDim2.new(0.02, 0, posY, 0)
    b.Size              = UDim2.new(0.96, 0, sizeY, 0)
    b.Font              = Enum.Font.GothamBold
    b.Text              = text
    b.TextColor3        = Color3.fromRGB(255, 255, 255)
    b.TextScaled        = true
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    b.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            Services.TweenService:Create(b, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(0.96, 0, sizeY * 0.95, 0)}):Play()
        end
    end)
    b.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            Services.TweenService:Create(b, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(0.96, 0, sizeY, 0)}):Play()
        end
    end)
    return b
end

local function MakeTextBox(parent, posY, sizeY, placeholder)
    local tb = Instance.new("TextBox")
    tb.Parent              = parent
    tb.BackgroundColor3    = Color3.fromRGB(12, 12, 12)
    tb.BorderSizePixel     = 0
    tb.Position            = UDim2.new(0.02, 0, posY, 0)
    tb.Size                = UDim2.new(0.96, 0, sizeY, 0)
    tb.Font                = Enum.Font.GothamBold
    tb.PlaceholderText     = placeholder
    tb.Text                = ""
    tb.TextColor3          = Color3.fromRGB(255, 255, 255)
    tb.TextScaled          = true
    tb.ClearTextOnFocus    = true
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 4)
    return tb
end

local function MakeSmallTextBox(parent, posX, posY, sizeX, sizeY, placeholder)
    local tb = Instance.new("TextBox")
    tb.Parent              = parent
    tb.BackgroundColor3    = Color3.fromRGB(12, 12, 12)
    tb.BorderSizePixel     = 0
    tb.Position            = UDim2.new(posX, 0, posY, 0)
    tb.Size                = UDim2.new(sizeX, 0, sizeY, 0)
    tb.Font                = Enum.Font.GothamBold
    tb.PlaceholderText     = placeholder
    tb.Text                = ""
    tb.TextColor3          = Color3.fromRGB(255, 255, 255)
    tb.TextScaled          = true
    tb.ClearTextOnFocus    = true
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 4)
    return tb
end

local WordText     = MakeLabel(MainFrame,  0.01, 0.06, "UNPATCHABOMB", Enum.Font.GothamBold)
local LetterBox    = MakeTextBox(MainFrame, 0.08, 0.06, "Type letters + Enter to auto-type")
local StatusLabel  = MakeLabel(MainFrame,  0.15, 0.06, "Status: Waiting for round...")
StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)

local AutoTypeToggle = MakeButton(MainFrame, 0.22, 0.06, "Auto Type: OFF",   Color3.fromRGB(40, 40, 40))
local AutoJoinToggle = MakeButton(MainFrame, 0.29, 0.06, "Auto Join: OFF",   Color3.fromRGB(40, 40, 40))
local WPMBox         = MakeTextBox(MainFrame, 0.36, 0.06, "Typing WPM (default: 120)")
local JitterToggle   = MakeButton(MainFrame, 0.43, 0.06, "Humanise WPM: ON", Color3.fromRGB(40, 80, 40))

local TypoPresets   = {0, 0.02, 0.04, 0.08, 0.12, 0.20}
local TypoIndex     = 3
local TypoButton    = MakeButton(MainFrame, 0.50, 0.06,
    string.format("Typo Chance: %d%%", math.floor(TypoPresets[TypoIndex] * 100)),
    Color3.fromRGB(80, 40, 40))

local MinLenBox = MakeSmallTextBox(MainFrame, 0.02, 0.57, 0.47, 0.06, "Min Length (1)")
local MaxLenBox = MakeSmallTextBox(MainFrame, 0.51, 0.57, 0.47, 0.06, "Max Length (99)")

local OldGUIButton = MakeButton(MainFrame, 0.64, 0.06, "Switch Theme: Patriotic", Color3.fromRGB(50, 50, 50))

local HowToUseText = MakeLabel(MainFrame, 0.75, 0.1,
    "Indexed & Render Dict Active\nMin/Max len set via textboxes")
HowToUseText.TextColor3 = Color3.fromRGB(140, 140, 140)

local function SetStatus(msg) StatusLabel.Text = "Status: " .. msg end

local TypeBox

local function LinkTypeBox()
    local GameUI = LocalPlayer.PlayerGui:WaitForChild("GameUI", 5)
    if GameUI then
        TypeBox = GameUI:FindFirstChild("Typebox", true)
        GameUI.DescendantAdded:Connect(function(c)
            if c.Name == "Typebox" then
                TypeBox = c
                TypeBox:GetPropertyChangedSignal("Visible"):Connect(function()
                    if Settings.AutoType then task.spawn(TryTyping) end
                end)
            end
        end)
    end
end

task.spawn(LinkTypeBox)

local function TypeWord(word)
    if Typing then return end
    Typing = true
    burstCounter = 0
    burstTarget  = math.random(Settings.BurstMin, Settings.BurstMax)

    SetStatus(string.format("Typing '%s' @ %d WPM  (typo: %d%%)",
        word, Settings.WPM, math.floor(Settings.TypoChance * 100)))

    if TypeBox then pcall(function() TypeBox:CaptureFocus() end) end

    local i = 1
    while i <= #word do
        local char = string.sub(word, i, i)

        if Settings.TypoChance > 0 and math.random() < Settings.TypoChance then
            local lower   = string.lower(char)
            local typoKey = TypoNeighbours[lower] or lower
            SimulateKey(typoKey)
            task.wait(GetLetterDelay())
            task.wait(0.04 + math.random() * 0.08)
            SimulateBackspace()
            task.wait(0.03 + math.random() * 0.05)
            SimulateKey(char)
        else
            SimulateKey(char)
        end

        task.wait(GetLetterDelay())
        i = i + 1
    end

    task.wait(0.05)
    SimulateKey("\n")
    SetStatus("Submitted: " .. word)
    Typing = false
end

function TryTyping()
    if not Settings.AutoType or TypingActive then return end
    TypingActive = true

    while GetTurn() ~= LocalPlayer.UserId do
        if not Settings.AutoType then TypingActive = false return end
        task.wait(0.1)
    end

    if not Settings.AutoType then TypingActive = false return end

    local Word, attempts = nil, 0
    repeat
        task.wait()
        local detectedLetters = GetLetters()
        if detectedLetters and detectedLetters ~= "" then
            LetterBox.Text = detectedLetters
            Word = FindWordAuto(detectedLetters)
            attempts = attempts + 1
            if not Settings.AutoType then TypingActive = false return end
        end
    until Word or attempts >= 10

    if Word then
        LastWord = Word
        task.wait(Settings.WordTypeDelay)
        if not Typing then TypeWord(Word) end
        task.wait(Settings.WordTypeDelay)
        if GetTurn() == LocalPlayer.UserId and Settings.AutoType then
            SetStatus("Still my turn — retrying…")
            LastWord = ""
            TypingActive = false
            TryTyping()
            return
        end
    else
        SetStatus("No word found for: " .. GetLetters())
    end

    TypingActive = false
end

task.spawn(function()
    local lastPrompt = ""
    while task.wait(0.25) do
        if Settings.AutoType and GetTurn() == LocalPlayer.UserId and not Typing and not TypingActive then
            local currentPrompt = GetLetters() or ""
            if currentPrompt ~= "" and currentPrompt ~= lastPrompt then
                lastPrompt = currentPrompt
                task.spawn(TryTyping)
            end
        elseif GetTurn() ~= LocalPlayer.UserId then
            lastPrompt = ""
        end
    end
end)

LetterBox.FocusLost:Connect(function(enterPressed)
    if not enterPressed then return end
    local sub = LetterBox.Text
    if not sub or sub == "" then
        sub = GetLetters()
        if not sub or sub == "" then WordText.Text = "Error: empty input." return end
    end
    WordText.Text = sub .. " — Searching..."
    task.wait(0.1)
    local word = FindWordAuto(sub)
    if word then
        WordText.Text = "Typing: '" .. word .. "'..."
        task.spawn(function()
            TypeWord(word)
            WordText.Text = "Done: '" .. word .. "'"
        end)
    else
        WordText.Text = "No word found :("
    end
end)

AutoTypeToggle.MouseButton1Click:Connect(function()
    Settings.AutoType = not Settings.AutoType
    local on = Settings.AutoType
    AutoTypeToggle.Text           = "Auto Type: " .. (on and "ON" or "OFF")
    AutoTypeToggle.BackgroundColor3 = on and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(40, 40, 40)
    SetStatus("Auto Type " .. (on and "Enabled" or "Disabled"))
    if not on then TypingActive = false end
    if on then task.spawn(TryTyping) end
end)

AutoJoinToggle.MouseButton1Click:Connect(function()
    Settings.AutoJoin = not Settings.AutoJoin
    local on = Settings.AutoJoin
    AutoJoinToggle.Text           = "Auto Join: " .. (on and "ON" or "OFF")
    AutoJoinToggle.BackgroundColor3 = on and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(40, 40, 40)
    SetStatus("Auto Join " .. (on and "Enabled" or "Disabled"))
    if on and Games then
        pcall(function()
            for i = -1, -1000, -1 do Games.GameEvent:FireServer(i, "JoinGame") end
        end)
    end
end)

WPMBox.FocusLost:Connect(function()
    local n = tonumber(WPMBox.Text)
    if n then
        Settings.WPM = math.clamp(n, 10, 9999)
        SetStatus(string.format("WPM → %d  (%.4fs/char)", Settings.WPM, 60 / (Settings.WPM * 5)))
    else
        SetStatus("Invalid WPM — enter a number.")
    end
end)

MinLenBox.FocusLost:Connect(function()
    local n = tonumber(MinLenBox.Text)
    if n then
        Settings.MinLen = math.clamp(n, 1, 99)
        SetStatus("Min Length → " .. Settings.MinLen)
    else
        Settings.MinLen = 1
        SetStatus("Min Length → Default (1)")
    end
end)

MaxLenBox.FocusLost:Connect(function()
    local n = tonumber(MaxLenBox.Text)
    if n then
        Settings.MaxLen = math.clamp(n, 1, 99)
        SetStatus("Max Length → " .. Settings.MaxLen)
    else
        Settings.MaxLen = 99
        SetStatus("Max Length → Default (99)")
    end
end)

JitterToggle.MouseButton1Click:Connect(function()
    Settings.HumaniseWPM = not Settings.HumaniseWPM
    local on = Settings.HumaniseWPM
    JitterToggle.Text           = "Humanise WPM: " .. (on and "ON" or "OFF")
    JitterToggle.BackgroundColor3 = on and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(40, 40, 40)
    SetStatus("WPM jitter " .. (on and "ON" or "OFF"))
end)

TypoButton.MouseButton1Click:Connect(function()
    TypoIndex = (TypoIndex % #TypoPresets) + 1
    Settings.TypoChance = TypoPresets[TypoIndex]
    TypoButton.Text = string.format("Typo Chance: %d%%", math.floor(Settings.TypoChance * 100))
    StatusLabel.Text = string.format("Status: Typo chance → %d%%", math.floor(Settings.TypoChance * 100))
end)

local currentTheme = "Patriotic"

local function ApplyTheme(theme)
    currentTheme = theme
    if theme == "Patriotic" then
        PatrioticGradient.Enabled = true
        StarOverlay.Visible = true
        FireworkOverlay.Visible = true
        OuterFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
        TopFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 25)
        MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 30)
        WordText.TextColor3 = Color3.fromRGB(255, 255, 255)
        LetterBox.BackgroundColor3 = Color3.fromRGB(10, 10, 20)
        StatusLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        AutoTypeToggle.BackgroundColor3 = Color3.fromRGB(180, 30, 50)
        AutoJoinToggle.BackgroundColor3 = Color3.fromRGB(30, 80, 160)
        JitterToggle.BackgroundColor3 = Settings.HumaniseWPM and Color3.fromRGB(40, 120, 60) or Color3.fromRGB(40, 40, 40)
        TypoButton.BackgroundColor3 = Color3.fromRGB(160, 40, 60)
        WPMBox.BackgroundColor3 = Color3.fromRGB(10, 10, 25)
        MinLenBox.BackgroundColor3 = Color3.fromRGB(10, 10, 25)
        MaxLenBox.BackgroundColor3 = Color3.fromRGB(10, 10, 25)
        OldGUIButton.BackgroundColor3 = Color3.fromRGB(20, 60, 140)
        OldGUIButton.Text = "Switch Theme: Modern"
        HowToUseText.TextColor3 = Color3.fromRGB(230, 230, 230)
        HowToUseText.Text = "Patriotic UI Active (Render Dict)"
        T1.TextColor3 = Color3.fromRGB(255, 255, 255)
        T2.TextColor3 = Color3.fromRGB(230, 230, 230)
        MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    else
        PatrioticGradient.Enabled = false
        StarOverlay.Visible = false
        FireworkOverlay.Visible = false
        OuterFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
        TopFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
        MainFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
        WordText.TextColor3 = Color3.fromRGB(255, 255, 255)
        LetterBox.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
        StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        AutoTypeToggle.BackgroundColor3 = Settings.AutoType and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(40, 40, 40)
        AutoJoinToggle.BackgroundColor3 = Settings.AutoJoin and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(40, 40, 40)
        JitterToggle.BackgroundColor3 = Settings.HumaniseWPM and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(40, 40, 40)
        TypoButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
        WPMBox.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
        MinLenBox.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
        MaxLenBox.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
        OldGUIButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        OldGUIButton.Text = "Switch Theme: Patriotic"
        HowToUseText.TextColor3 = Color3.fromRGB(140, 140, 140)
        HowToUseText.Text = "Modern UI Active (Render Dict)"
        T1.TextColor3 = Color3.fromRGB(255, 255, 255)
        T2.TextColor3 = Color3.fromRGB(200, 200, 200)
        MinimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    end
end

ApplyTheme("Patriotic")

OldGUIButton.MouseButton1Click:Connect(function()
    if currentTheme == "Patriotic" then
        ApplyTheme("Modern")
        SetStatus("Switched to Modern UI")
    else
        ApplyTheme("Patriotic")
        SetStatus("Switched to Patriotic UI")
    end
end)

do
    local dragging, dragInput, dragStart, startPos
    TopFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = OuterFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    TopFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    Services.UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local d = input.Position - dragStart
            OuterFrame.Position = UDim2.new(
                startPos.X.Scale,  startPos.X.Offset + d.X,
                startPos.Y.Scale,  startPos.Y.Offset + d.Y
            )
        end
    end)
end

local minimized = false

MinimizeButton.MouseButton1Click:Connect(function()
    minimized = not minimized
    local targetSize     = minimized and UDim2.new(0, 320, 0, 28)      or UDim2.new(0, 320, 0, 480)
    local targetBodySize = minimized and UDim2.new(1, 0, 0, 0)         or UDim2.new(1, 0, 1, -28)

    local glow = Instance.new("ImageLabel")
    glow.Parent               = OuterFrame
    glow.BackgroundTransparency = 1
    glow.Image                = "rbxassetid://5028857084"
    glow.ImageColor3          = Color3.fromRGB(255, 255, 255)
    glow.Size                 = UDim2.new(1, 20, 1, 20)
    glow.Position             = UDim2.new(0, -10, 0, -10)
    glow.ImageTransparency    = 1
    Services.TweenService:Create(glow, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {ImageTransparency = 0.7}):Play()
    task.delay(0.4, function() glow:Destroy() end)

    Services.TweenService:Create(OuterFrame,  TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetSize}):Play()
    Services.TweenService:Create(MainFrame,   TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetBodySize}):Play()
    Services.TweenService:Create(IntroFrame,  TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = targetBodySize}):Play()

    MinimizeButton.Text = minimized and "+" or "—"
end)

task.delay(2, function()
    Services.TweenService:Create(IntroFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(0, 0, 1, 0)}):Play()
end)

if Games then
    local registerGame = Games:FindFirstChild("RegisterGame")
    if registerGame then
        registerGame.OnClientEvent:Connect(function(int)
            GameID    = int
            UsedWords = {}
            LastWord  = ""
            SetStatus("Game registered — ID: " + int)
            if Settings.AutoJoin then 
                pcall(function() Games.GameEvent:FireServer(int, "JoinGame") end)
            end
            task.wait(1)
            if Settings.AutoType then task.spawn(TryTyping) end
        end)
    end
end
