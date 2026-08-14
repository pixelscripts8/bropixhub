-- === LOCALIZATION OF FREQUENTLY USED FUNCTIONS AND LIBRARIES ===
local string_find   = string.find
local string_lower  = string.lower
local string_sub    = string.sub
local string_gsub   = string.gsub
local string_upper  = string.upper
local math_random   = math.random
local math_floor    = math.floor
local math_huge     = math.huge
local table_clear   = table.clear
local table_insert  = table.insert
local task_spawn    = task.spawn
local task_wait     = task.wait
local os_time       = os.time
local os_clock      = os.clock
local pcall         = pcall
local xpcall        = xpcall
local type          = type
local typeof        = typeof
local tostring      = tostring
local tonumber      = tonumber
local ipairs        = ipairs
local pairs         = pairs
local debug_getinfo = debug_getinfo
local debug_getupvalues = debug_getupvalues

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Vim = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- === AUTHENTICATION ===
local API_URL = "https://roblox-key-api-zxnv.onrender.com/verify"
local userProvidedKey = getgenv().PixelKey or _G.PixelKey or PixelKey

if not userProvidedKey or userProvidedKey == "" then
    if LocalPlayer then LocalPlayer:Kick("❌ [Bro-Pixel Auth]: Key not found! Set getgenv().PixelKey = 'YOUR_KEY' before execution.") end
    return
end

local function checkKey(userKey)
    local rawHwid = gethwid and gethwid() or (game:GetService("RbxAnalyticsService"):GetClientId())
    local requestUrl = string.format("%s?key=%s&hwid=%s", API_URL, tostring(userKey), tostring(rawHwid))
    
    local success, response = pcall(function()
        return game:HttpGet(requestUrl)
    end)
    
    if success and response then
        local ok, data = pcall(function()
            return HttpService:JSONDecode(response)
        end)
        
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
    if LocalPlayer then LocalPlayer:Kick("🔒 [Bro-Pixel Auth]: " .. tostring(authMessage)) end
    error("[AUTH FAILED]: " .. tostring(authMessage))
    return
end

print("✅ [Bro-Pixel Auth]: Authorization successful: " .. tostring(authMessage))

-- === MAIN SCRIPT & UI SETUP ===
getgenv().deletewhendupefound = true

local elapsedLabel, turnsLabel, promptLabel, solutionsLabel, matchLabel, fusionLabel

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Bro-PixelScript (wordbomb)",
    LoadingTitle = "Bro-Pixel Loader",
    LoadingSubtitle = "by Bro-Pixel",

    DisableRayfieldPrompts = true,
    DisableBuildWarnings = true,

    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
    Size = UDim2.fromOffset(340, 280),
   
    CustomTheme = {
        TextColor = Color3.fromRGB(255, 255, 255),
        Background = Color3.fromRGB(25, 10, 40),        
        MainColor = Color3.fromRGB(90, 30, 180),      
        AccentColor = Color3.fromRGB(0, 240, 200),      
        OutlineColor = Color3.fromRGB(140, 50, 255),    
        PlaceholderColor = Color3.fromRGB(180, 150, 220)
    }
})

local MainTab = Window:CreateTab("Main", nil)
local DictionaryTab = Window:CreateTab("Dictionary", nil)
local SettingsTab = Window:CreateTab("Settings", nil)

local statusLabel = MainTab:CreateLabel("Loading and indexing dictionaries...")

-- === ACTIVITY TRACKING ===
local lastActivity = os_clock()

local function updateActivity()
    lastActivity = os_clock()
end

-- === DICTIONARY INDEXING & MEMORY BUFFERS ===
local globalWordsList = {} 
local PromptIndex = {}
local CommonWordsMap = {}

local validCandidatesBuffer = {}
local specialMatchesBuffer = {}
local normalMatchesBuffer = {}
local commonCandidatesBuffer = {}

-- Загрузка базового словаря
local function loadDictionaryAsync(url)
    task_spawn(function()
        local success, raw = pcall(function() return game:HttpGet(url) end)
        if not success or not raw then 
            statusLabel:Set("Failed to load dictionary!")
            print("❌ [DEBUG]: Failed to download main dictionary!")
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
        statusLabel:Set("Dictionary: " .. total .. " words (Indexed & Ready)")
        print("✅ [DEBUG]: Main dictionary indexed with " .. total .. " words.")
    end)
end

-- Загрузка Common-словаря
local function loadCommonDictionaryAsync(url)
    task_spawn(function()
        local success, raw = pcall(function() return game:HttpGet(url) end)
        if not success or not raw then 
            print("⚠️ [DEBUG]: Failed to download common dictionary!")
            return 
        end
        
        local commonCount = 0
        for word in raw:gmatch("[^\r\n]+") do
            word = word:gsub("%s+", ""):lower()
            if #word >= 3 and word:match("^[a-z]+$") then
                CommonWordsMap[word] = true
                commonCount = commonCount + 1
            end
        end
        
        print("✅ [DEBUG]: Common dictionary indexed with " .. commonCount .. " words.")
    end)
end

local rawHwid = gethwid and gethwid() or (game:GetService("RbxAnalyticsService"):GetClientId())
local protectedDictUrl = string.format("https://roblox-key-api-zxnv.onrender.com/dictionary?key=%s&hwid=%s", tostring(userProvidedKey), tostring(rawHwid))
local protectedCommonDictUrl = string.format("https://roblox-key-api-zxnv.onrender.com/common-dictionary?key=%s&hwid=%s", tostring(userProvidedKey), tostring(rawHwid))

loadDictionaryAsync(protectedDictUrl)
loadCommonDictionaryAsync(protectedCommonDictUrl)

-- === STATE & SETTINGS ===
local sessionUsedWords = {}
local lettercap = math_huge
local autosearch = false
local autotype = false
local instanttype = false
local autojoin = false
local autoJoinDelay = 2 
local jitterEnabled = false 
local jitterIntensity = 0.05 
local rngVariationPercent = 0 

-- Fuse Delay Settings
local useFuseProgress = true
local fusePercent = 0.50          
local currentFusionStats = "0.00s / 0.00s"

-- Human Typos Settings
local typosEnabled = false
local typoChancePercent = 3

local wordPriorityMode = "Common"

local isTyping = false 
local isSubmitting = false
local typingActive = false
local lastWord = ""
local typingSessionId = 0
local lastKnownPrompt = ""

local checkWordDelay = 1.0 
local startTime = os_time()
local totalTurns = 0

local typingWPM = 500
local speedWordDelay = 60 / (typingWPM * 5)

local alphabet = "abcdefghijklmnopqrstuvwxyz"

local function applyRngVariation(baseValue)
    if rngVariationPercent <= 0 then return baseValue end
    local factor = 1 + ((math_random() * 2 - 1) * (rngVariationPercent / 100))
    local result = baseValue * factor
    return result < 0 and 0 or result
end

-- === OPTIMIZED NETWORK EVENTS INITIALIZATION ===
local Games = ReplicatedStorage:WaitForChild("Network", 10)
if Games then Games = Games:WaitForChild("Games", 10) end

local Network = ReplicatedStorage:FindFirstChild("Network")
if Network then
    local gameEvent = Network:FindFirstChild("GameEvent", true)
    if gameEvent then
        local currentTypingBuffer = ""
        gameEvent.OnClientEvent:Connect(function(...)
            local arg1, arg2 = ...
            if type(arg1) == "string" then
                local lower1 = arg1:lower()
                if lower1 == "typingevent" and type(arg2) == "string" then
                    currentTypingBuffer = arg2:lower()
                elseif lower1 == "changepossessor" then
                    if #currentTypingBuffer > 1 then
                        sessionUsedWords[currentTypingBuffer] = true
                        currentTypingBuffer = ""
                    end
                end
            end
        end)
    end
end

-- === 100% PLAYERGUI GETTURN (0% GETGC) ===
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

-- === DIRECT TEXT FRAME PARSER ===
local framesBuffer = {}

local function GetLetters()
    if GetTurn() ~= LocalPlayer.UserId then
        return ""
    end

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
        if count > 0 then
            if count == 2 then
                if framesBuffer[1].AbsolutePosition.X > framesBuffer[2].AbsolutePosition.X then
                    framesBuffer[1], framesBuffer[2] = framesBuffer[2], framesBuffer[1]
                end
            elseif count == 3 then
                if framesBuffer[1].AbsolutePosition.X > framesBuffer[2].AbsolutePosition.X then
                    framesBuffer[1], framesBuffer[2] = framesBuffer[2], framesBuffer[1]
                end
                if framesBuffer[2].AbsolutePosition.X > framesBuffer[3].AbsolutePosition.X then
                    framesBuffer[2], framesBuffer[3] = framesBuffer[3], framesBuffer[2]
                end
                if framesBuffer[1].AbsolutePosition.X > framesBuffer[2].AbsolutePosition.X then
                    framesBuffer[1], framesBuffer[2] = framesBuffer[2], framesBuffer[1]
                end
            end

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

-- === OPTIMIZED & SAFE FUSE DATA RETRIEVAL ===
local function getInfoTable()
    local s, r = pcall(function()
        local getupvaluesFunc = debug_getupvalues or getupvalues
        local getinfoFunc = debug_getinfo or debug.getinfo

        if type(getgc) ~= "function" or type(getupvaluesFunc) ~= "function" then
            return nil
        end

        for _, v in pairs(getgc()) do
            if type(v) == "function" then
                local info = getinfoFunc and getinfoFunc(v)
                if info and info.name == "updateInfoFrame" then
                    for _, vv in ipairs(getupvaluesFunc(v)) do
                        if type(vv) == "table" and vv.FuseStart ~= nil and vv.FuseRate ~= nil then 
                            return vv 
                        end
                    end
                end
            end
        end
    end)
    if s and type(r) == "table" then return r end
    return nil
end

-- === FUSE DELAY LOGIC ===
local function waitFuseProgress(targetSession)
    if not useFuseProgress then return end

    local tbl = getInfoTable()
    if not tbl or not tbl.FuseStart or tbl.FuseStart <= 1000 or not tbl.FuseRate or tbl.FuseRate == 0 then
        if checkWordDelay > 0 and not instanttype then
            task_wait(applyRngVariation(checkWordDelay))
        end
        return
    end

    local fuseStart = tbl.FuseStart
    local fuseRate = tbl.FuseRate
    local totalFuseTime = math.abs(1 / fuseRate)
    local targetWaitSeconds = math.max(0, (totalFuseTime * fusePercent) - 0.05)

    currentFusionStats = string.format("%.2fs / %.2fs", targetWaitSeconds, totalFuseTime)
    if fusionLabel then 
        fusionLabel:Set("Fusion Progress: " .. currentFusionStats) 
    end

    if targetWaitSeconds > 0 and typingSessionId == targetSession then
        task_wait(targetWaitSeconds)
    end
end

-- === FULL ROUND STATE RESET ===
local function resetRoundState()
    typingSessionId = typingSessionId + 1
    sessionUsedWords = {} 
    lastWord = ""
    lastKnownPrompt = ""
    isTyping = false
    isSubmitting = false
    typingActive = false
    updateActivity()

    if promptLabel then promptLabel:Set("Current Prompt: Waiting...") end
    if solutionsLabel then solutionsLabel:Set("Solutions Found: 0") end
    if matchLabel then matchLabel:Set("Current Match: Waiting...") end
    if fusionLabel then fusionLabel:Set("Fusion Progress: 0.00s / 0.00s") end
end

-- === ULTRA-SMART TYPING ===
local function typeWordMobile(word, targetPrompt)
    if isTyping then return end 
    isTyping = true 
    
    typingSessionId = typingSessionId + 1
    local currentSession = typingSessionId

    local success, err = pcall(function()
        if not instanttype then 
            if useFuseProgress then
                waitFuseProgress(currentSession)
            elseif checkWordDelay > 0 then 
                local finalDelay = applyRngVariation(checkWordDelay)
                task_wait(finalDelay) 
            end
        end
        
        if currentSession ~= typingSessionId then return end

        local cachedBox = getGameTextBox()
        if GetTurn() ~= LocalPlayer.UserId then return end
        
        if cachedBox then 
            cachedBox:CaptureFocus() 
            task_wait(0.01)
            cachedBox.Text = "" 
            task_wait(0.01)
        end
        
        local interrupted = false

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
                
                if i == 1 and cachedBox and cachedBox.Text ~= "" then cachedBox.Text = "" end
                
                Vim:SendKeyEvent(true, keyCode, false, game)
                if currentDelay > 0 then task_wait(currentDelay / 2) end
                Vim:SendKeyEvent(false, keyCode, false, game)
                if currentDelay > 0 then task_wait(currentDelay / 2) end
            end
        end
        
        if not interrupted and currentSession == typingSessionId then
            local finalTurn = GetTurn()
            if finalTurn == LocalPlayer.UserId then
                isSubmitting = true 

                if not instanttype then task_wait(0.02) end
                Vim:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                if not instanttype then task_wait(0.01) end
                Vim:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                if not instanttype then task_wait(0.03) end
                
                totalTurns = totalTurns + 1
                if turnsLabel then turnsLabel:Set("Total Turns: " .. totalTurns) end
                updateActivity()
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
        isSubmitting = false
    end
end

-- === SEARCH & TRY LOGIC ===
local function findWordForPrompt(promptLower)
    if not promptLower or promptLower == "" then return nil end
    
    table_clear(validCandidatesBuffer)
    table_clear(specialMatchesBuffer)
    table_clear(normalMatchesBuffer)
    table_clear(commonCandidatesBuffer)
    
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

    if solutionsLabel then solutionsLabel:Set("Solutions Found: " .. #validCandidatesBuffer) end

    if #validCandidatesBuffer > 0 then
        local currentMode = wordPriorityMode
        if type(currentMode) == "table" then
            currentMode = wordPriorityMode[1] or "Common"
        end

        if currentMode == "Common" then
            if #commonCandidatesBuffer > 0 then
                return commonCandidatesBuffer[math_random(1, #commonCandidatesBuffer)]
            end
            currentMode = "Hyphenated / Short"
        end

        if currentMode == "Hyphenated / Short" or currentMode == "Hyphenated/short" then
            if #specialMatchesBuffer > 0 then
                return specialMatchesBuffer[math_random(1, #specialMatchesBuffer)]
            elseif #normalMatchesBuffer > 0 then
                local shortest = normalMatchesBuffer[1]
                for i = 2, #normalMatchesBuffer do
                    local word = normalMatchesBuffer[i]
                    if #word < #shortest then shortest = word end
                end
                return shortest
            end
        elseif currentMode == "Shortest" then
            local shortest = validCandidatesBuffer[1]
            for i = 2, #validCandidatesBuffer do
                local word = validCandidatesBuffer[i]
                if #word < #shortest then shortest = word end
            end
            return shortest
        elseif currentMode == "Longest" then
            local longest = validCandidatesBuffer[1]
            for i = 2, #validCandidatesBuffer do
                local word = validCandidatesBuffer[i]
                if #word > #longest then longest = word end
            end
            return longest
        end
        return validCandidatesBuffer[math_random(1, #validCandidatesBuffer)]
    end
    return nil
end

local function TryTyping()
    if not autosearch then return end
    if typingActive or isTyping then return end
    typingActive = true

    local detectedRaw = GetLetters()
    if detectedRaw and detectedRaw ~= "" then
        local cleanPrompt = detectedRaw:lower():gsub("%s+", "")
        if promptLabel then promptLabel:Set("Current Prompt: " .. detectedRaw:upper()) end
        
        local word = findWordForPrompt(cleanPrompt)
        if word then
            sessionUsedWords[word] = true
            lastWord = word:upper()
            if matchLabel then matchLabel:Set("Current Match: " .. word:upper()) end
            
            if autotype then
                typeWordMobile(word, cleanPrompt)
            end
        else
            if matchLabel then matchLabel:Set("Current Match: Not Found") end
        end
    end

    typingActive = false
end

-- === PLAYERGUI REAL-TIME EVENT SUBSCRIBERS ===
local function setupUIEvents()
    pcall(function()
        local playerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
        if not playerGui then return end

        local gameUI = playerGui:WaitForChild("GameUI", 10)
        if not gameUI then return end

        local typeBox = gameUI:FindFirstChild("Typebox", true)
        local textFrame = gameUI:FindFirstChild("TextFrame", true)

        local function checkAndTrigger(source)
            if not autosearch or isTyping or typingActive then return end
            if GetTurn() ~= LocalPlayer.UserId then return end

            task_wait(0.02)
            local currentPrompt = GetLetters()

            if currentPrompt ~= "" and currentPrompt ~= lastKnownPrompt then
                lastKnownPrompt = currentPrompt
                print("⚡ [UI EVENT: " .. source .. "]: Слог подхвачен мгновенно -> [" .. currentPrompt .. "]")
                task_spawn(TryTyping)
            end
        end

        if typeBox then
            typeBox:GetPropertyChangedSignal("Visible"):Connect(function()
                if typeBox.Visible then
                    checkAndTrigger("Typebox Visible")
                end
            end)
        end

        if textFrame then
            textFrame.ChildAdded:Connect(function()
                checkAndTrigger("TextFrame ChildAdded")
            end)
        end
    end)
end

task_spawn(setupUIEvents)

-- === FAST WATCHER (0.3s SAFETY FALLBACK) ===
task_spawn(function()
    while true do
        if GetTurn() == LocalPlayer.UserId then
            if autosearch then
                local currentPrompt = GetLetters()
                if currentPrompt ~= "" and currentPrompt ~= lastKnownPrompt and not isTyping then
                    lastKnownPrompt = currentPrompt
                    typingActive = false
                    task_spawn(TryTyping)
                end
            end
            task_wait(0.1)
        else
            lastKnownPrompt = ""
            task_wait(0.3)
        end
    end
end)

-- === UI ELEMENTS (MAIN TAB) ===
MainTab:CreateInput({
   Name = "Letter Cap",
   PlaceholderText = "Enter max letter count...",
   Callback = function(Text) lettercap = tonumber(Text) or math_huge end,
})

MainTab:CreateToggle({
   Name = "Auto Search",
   CurrentValue = false,
   Callback = function(Value)
      autosearch = Value
      if autosearch then
          task_spawn(TryTyping)
      else
          typingActive = false
      end
   end,
})

MainTab:CreateToggle({ 
    Name = "Auto Type (Mobile)", 
    CurrentValue = false, 
    Callback = function(Value) autotype = Value end 
})

MainTab:CreateToggle({ 
    Name = "Instant Type (No Delay)", 
    CurrentValue = false, 
    Callback = function(Value) instanttype = Value end 
})

MainTab:CreateToggle({
    Name = "Auto Join Game",
    CurrentValue = false,
    Callback = function(Value)
        autojoin = Value
        if autojoin and Games then
            task_spawn(function()
                if autoJoinDelay > 0 then task_wait(autoJoinDelay) end
                resetRoundState()
                pcall(function()
                    for i = -1, -20, -1 do 
                        Games.GameEvent:FireServer(i, "JoinGame") 
                    end
                end)
            end)
        end
    end
})

MainTab:CreateButton({ 
    Name = "Search Word (Manual)", 
    Callback = function() 
        task_spawn(TryTyping) 
    end 
})

-- === UI ELEMENTS (DICTIONARY TAB) ===
DictionaryTab:CreateDropdown({
   Name = "Word Priority",
   Options = {"Common", "Hyphenated / Short", "Shortest", "Longest", "Random"},
   CurrentOption = {"Common"},
   MultipleOptions = false,
   Callback = function(Option)
      if type(Option) == "table" then
          wordPriorityMode = Option[1]
      else
          wordPriorityMode = Option
      end
   end,
})

-- === UI ELEMENTS (SETTINGS TAB) ===
SettingsTab:CreateSlider({
   Name = "Auto Join Delay",
   Info = "Delay before auto joining game (1s to 5s)",
   Range = {1, 5},
   Increment = 1,
   Suffix = " sec",
   CurrentValue = 2,
   Callback = function(Value) autoJoinDelay = Value end,
})

SettingsTab:CreateToggle({
   Name = "Dynamic Fuse Delay",
   CurrentValue = true,
   Info = "Waits for turn timer % before typing",
   Callback = function(Value) useFuseProgress = Value end,
})

SettingsTab:CreateSlider({
   Name = "Fuse Delay Target %",
   Info = "Target % of fuse time to wait (1% to 95%)",
   Range = {1, 95},
   Increment = 1,
   Suffix = "%",
   CurrentValue = 50,
   Callback = function(Value) fusePercent = Value / 100 end,
})

SettingsTab:CreateSlider({
   Name = "Check Word Delay (Fallback)",
   Info = "Static delay if fuse not active (0.1s to 2.0s)",
   Range = {1, 20}, 
   Increment = 1,
   Suffix = " (x0.1 sec)",
   CurrentValue = 10, 
   Callback = function(Value) checkWordDelay = Value / 10 end,
})

SettingsTab:CreateSlider({
   Name = "Typing WPM",
   Info = "Words Per Minute speed",
   Range = {100, 1000},
   Increment = 50,
   Suffix = " WPM",
   CurrentValue = 500,
   Callback = function(Value)
      typingWPM = Value
      speedWordDelay = 60 / (typingWPM * 5)
   end,
})

SettingsTab:CreateSlider({
   Name = "RNG Variation",
   Info = "Random speed & delay variation (+-0% to +-100%)",
   Range = {0, 100},
   Increment = 5,
   Suffix = "%",
   CurrentValue = 0,
   Callback = function(Value)
      rngVariationPercent = Value
   end,
})

SettingsTab:CreateToggle({
   Name = "Human Jittering",
   CurrentValue = false,
   Info = "Slight realistic delay fluctuations",
   Callback = function(Value) jitterEnabled = Value end,
})

SettingsTab:CreateSlider({
   Name = "Jitter Delay",
   Info = "Jittering strength",
   Range = {1, 20}, 
   Increment = 1,
   Suffix = " ms", 
   CurrentValue = 5, 
   Callback = function(Value) jitterIntensity = Value / 100 end,
})

SettingsTab:CreateToggle({
   Name = "Human Typos",
   CurrentValue = false,
   Info = "Simulates natural human typing mistakes",
   Callback = function(Value) typosEnabled = Value end,
})

SettingsTab:CreateSlider({
   Name = "Typo Chance",
   Info = "Chance of making a typo per character (1% to 20%)",
   Range = {1, 20},
   Increment = 1,
   Suffix = "%",
   CurrentValue = 3,
   Callback = function(Value) typoChancePercent = Value end,
})

-- === STATS PANEL ===
MainTab:CreateSection("Statistics")
elapsedLabel = MainTab:CreateLabel("Elapsed Time: 00:00:00")
turnsLabel = MainTab:CreateLabel("Total Turns: 0")
promptLabel = MainTab:CreateLabel("Current Prompt: None")
solutionsLabel = MainTab:CreateLabel("Solutions Found: 0")
matchLabel = MainTab:CreateLabel("Current Match: None")
fusionLabel = MainTab:CreateLabel("Fusion Progress: 0.00s / 0.00s")
MainTab:CreateSection("------------------")

-- === BACKGROUND AUTO JOIN THREAD & REGISTER TRIGGER ===
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
                task_spawn(TryTyping)
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
                if elapsedLabel then
                    elapsedLabel:Set(string.format("Elapsed Time: %02d:%02d:%02d", hours, minutes, seconds))
                end
            end
        end, function(err)
            warn("[CRASH] Timer Loop errored: " .. tostring(err))
        end)
        task_wait(2)
    end
end)

