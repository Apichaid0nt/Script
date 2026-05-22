if not game:IsLoaded() then game.Loaded:Wait() end

local CoreGui = game:GetService("CoreGui")
if CoreGui:FindFirstChild("FluentToggleButtonGui") or (getgenv and getgenv().NobodyHub_LOADED) then
    return
end
pcall(function() getgenv().NobodyHub_LOADED = true end)

-- ==================== SERVICES ====================
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService   = game:GetService("UserInputService")
local Players            = game:GetService("Players")
local HttpService        = game:GetService("HttpService")
local RunService         = game:GetService("RunService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Workspace          = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

-- ==================== FETCH GAME INFO ====================
local success, gameInfo = pcall(function()
    return MarketplaceService:GetProductInfo(game.PlaceId)
end)
local GameName = success and gameInfo.Name or "Unknown Game"

-- ==================== FILE SYSTEM & STATE ====================
local GAME_FOLDER = "NobodyHub/" .. game.GameId
local SAVE_FILE   = GAME_FOLDER .. "/state.json"

local function ensureFolder(path)
    pcall(function() if not isfolder(path) then makefolder(path) end end)
end

local function saveState(st)
    pcall(function()
        ensureFolder("NobodyHub")
        ensureFolder(GAME_FOLDER)
        local data = {
            AutoQuest        = st.AutoQuest,
            SelectedMonsters = st.SelectedMonsters,
            AutoFarmNearby   = st.AutoFarmNearby,
            AutoFarmAllBoss  = st.AutoFarmAllBoss,
            FarmDistance     = st.FarmDistance,
            NearbyDistance   = st.NearbyDistance,
            KillAura         = st.KillAura,
            KillAuraCD       = st.KillAuraCD,
            KillAuraRange    = st.KillAuraRange,
            -- NEW
            SelectedWeapon   = st.SelectedWeapon,
            AttackMethod     = st.AttackMethod,
            AutoFly          = st.AutoFly,
            AutoNoclip       = st.AutoNoclip,
            AutoNoclipCam    = st.AutoNoclipCam,
        }
        writefile(SAVE_FILE, HttpService:JSONEncode(data))
    end)
end

local function loadSavedState()
    local ok, raw = pcall(readfile, SAVE_FILE)
    if not ok or not raw or raw == "" then return nil end
    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
    return (ok2 and type(data) == "table") and data or nil
end

local saved = loadSavedState() or {}
_G.__NobodyHubConnections = _G.__NobodyHubConnections or {}

local State = { 
    AutoQuest        = saved.AutoQuest or false,
    SelectedMonsters = saved.SelectedMonsters or {},
    AutoFarmNearby   = saved.AutoFarmNearby or false,
    AutoFarmAllBoss  = saved.AutoFarmAllBoss or false,
    FarmDistance     = tonumber(saved.FarmDistance) or 8,
    NearbyDistance   = tonumber(saved.NearbyDistance) or 70,
    KillAura         = saved.KillAura or false,
    KillAuraCD       = tonumber(saved.KillAuraCD) or 0.5,
    KillAuraRange    = tonumber(saved.KillAuraRange) or 50,
    -- NEW
    SelectedWeapon   = saved.SelectedWeapon or "Auto (All)",
    AttackMethod     = saved.AttackMethod or "above",
    AutoFly          = saved.AutoFly or false,
    AutoNoclip       = saved.AutoNoclip or false,
    AutoNoclipCam    = saved.AutoNoclipCam or false,
}

-- ==================== HELPER FUNCTIONS & LOGIC ====================
local BossList    = {"Alucard", "Aizen", "Madoka", "Jinwoo", "Gojo", "Sukuna", "Yuji", "Cid"}
local IslandPatrol = {"Sailor", "Shibuya", "HollowIsland", "Shinjuku", "SlimeIsland", "AcademyIsland", "JudgementIsland", "SoulSociety", "NinjaIsland", "LawlessIsland"}

local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getHRP()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function teleportTo(cframe)
    local hrp = getHRP()
    if hrp then hrp.CFrame = cframe end
end

-- ==================== FAST FETCH SYSTEM ====================
local function FetchNPCS()
    local targetFolders = {"NPCs", "Enemies", "mobs", "boss", "Bosses", "Live"}
    local entities = {}
    local foundFolder = false

    for _, folderName in ipairs(targetFolders) do
        local folder = Workspace:FindFirstChild(folderName)
        if folder then
            foundFolder = true
            for _, v in ipairs(folder:GetChildren()) do
                table.insert(entities, v)
            end
        end
    end

    if not foundFolder then
        for _, v in ipairs(Workspace:GetChildren()) do
            table.insert(entities, v)
        end
    end
    return entities
end

local function FetchLocalEnemies()
    local tbl = {}
    for _, enemy in ipairs(FetchNPCS()) do
        if enemy:IsA("Model") and enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Humanoid") and enemy.Humanoid.Health > 0 and enemy ~= getCharacter() then
            local isPlayer = Players:GetPlayerFromCharacter(enemy)
            if not isPlayer then
                table.insert(tbl, enemy)
            end
        end
    end
    return tbl
end

local function DropdownEnemies()
    local tbl = {}
    for _, enemy in ipairs(FetchLocalEnemies()) do
        local cleanName = string.match(enemy.Name, "(%S*)%d")
        local finalName = cleanName or enemy.Name
        if not table.find(tbl, finalName) then
            table.insert(tbl, finalName)
        end
    end
    if #tbl == 0 then table.insert(tbl, "None") end
    return tbl
end

-- ==================== WEAPON LIST ====================
local function getWeaponList()
    local tools = {"Auto (All)"}
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if char then
        for _, v in ipairs(char:GetChildren()) do
            if v:IsA("Tool") and not table.find(tools, v.Name) then
                table.insert(tools, v.Name)
            end
        end
    end
    if backpack then
        for _, v in ipairs(backpack:GetChildren()) do
            if v:IsA("Tool") and not table.find(tools, v.Name) then
                table.insert(tools, v.Name)
            end
        end
    end
    return tools
end

-- ==================== ATTACK POSITION HELPER ====================
-- คำนวณ CFrame ตาม Method ที่เลือก (above/under/front/behind)
local function getAttackCFrame(targetRoot, distance)
    local dist    = tonumber(distance) or tonumber(State.FarmDistance) or 8
    local method  = State.AttackMethod or "above"
    if method == "above" then
        return targetRoot.CFrame * CFrame.new(0,  dist,  0) * CFrame.Angles(math.rad(-90), 0, 0)
    elseif method == "under" then
        return targetRoot.CFrame * CFrame.new(0, -dist,  0) * CFrame.Angles(math.rad(90),  0, 0)
    elseif method == "front" then
        return targetRoot.CFrame * CFrame.new(0,   0, -dist)
    elseif method == "behind" then
        return targetRoot.CFrame * CFrame.new(0,   0,  dist)
    end
    return targetRoot.CFrame * CFrame.new(0, dist, 0) * CFrame.Angles(math.rad(-90), 0, 0)
end

-- ==================== FLY / NOCLIP / NOCLIPCAM SYSTEM ====================
local FlyConnection      = nil
local NoclipConnection   = nil
local NoclipCamEnabled   = false

-- Fly: ดึง BodyVelocity เพื่อต้านแรงโน้มถ่วง ให้ลอยอยู่กับที่
local function enableFly()
    if FlyConnection then return end
    pcall(function()
        local hrp = getHRP()
        if not hrp then return end
        -- ลบของเก่าก่อน
        local old = hrp:FindFirstChild("NobodyFly_BV")
        if old then old:Destroy() end

        local bv = Instance.new("BodyVelocity")
        bv.Name       = "NobodyFly_BV"
        bv.MaxForce   = Vector3.new(1e5, 1e5, 1e5)
        bv.Velocity   = Vector3.new(0, 0, 0)
        bv.Parent     = hrp
    end)

    FlyConnection = RunService.Heartbeat:Connect(function()
        local hrp = getHRP()
        if hrp then
            local bv = hrp:FindFirstChild("NobodyFly_BV")
            if bv then
                -- รักษาแกน Y ให้นิ่ง (ต้านแรงโน้มถ่วง)
                local vel = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
            end
        end
    end)
end

local function disableFly()
    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
    end
    pcall(function()
        local hrp = getHRP()
        if hrp then
            local bv = hrp:FindFirstChild("NobodyFly_BV")
            if bv then bv:Destroy() end
        end
    end)
end

-- Noclip: ปิด CanCollide ทุก Part ของ character ในทุก frame
local function enableNoclip()
    if NoclipConnection then return end
    NoclipConnection = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if char then
            for _, child in pairs(char:GetDescendants()) do
                if child:IsA("BasePart") and child.CanCollide == true then
                    child.CanCollide = false
                end
            end
        end
    end)
end

local function disableNoclip()
    if NoclipConnection then
        NoclipConnection:Disconnect()
        NoclipConnection = nil
    end
    -- คืน collision ให้กับ character
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            for _, child in pairs(char:GetDescendants()) do
                if child:IsA("BasePart") then
                    child.CanCollide = true
                end
            end
        end
    end)
end

-- NoclipCam: แก้ค่าใน Popper ให้กล้องทะลุกำแพงได้
local function applyNoclipCam(enable)
    local sc = (debug and debug.setconstant) or (setconstant)
    local gc = (debug and debug.getconstants) or (getconstants)
    if not sc or not getgc or not gc then
        pcall(function()
            if Fluent then
                Fluent:Notify({Title = "NoclipCam", Content = "Exploit ไม่รองรับ (ต้องการ setconstant/getconstants)", Duration = 4})
            end
        end)
        return
    end
    pcall(function()
        local pop = LocalPlayer.PlayerScripts.PlayerModule.CameraModule.ZoomController.Popper
        for _, v in pairs(getgc()) do
            if type(v) == 'function' and getfenv(v).script == pop then
                for i, v1 in pairs(gc(v)) do
                    if enable then
                        -- เปิด: .25 -> 0 (กล้องทะลุ)
                        if tonumber(v1) == .25 then sc(v, i, 0) end
                    else
                        -- ปิด: 0 -> .25 (คืนค่าเดิม)
                        if tonumber(v1) == 0 then sc(v, i, .25) end
                    end
                end
            end
        end
    end)
    NoclipCamEnabled = enable
end

-- ==================== CLEANUP / UNLOAD SYSTEM (lineage.lua pattern) ====================
local _cleanupDone = false

local function _cleanupState()
    if _cleanupDone then return end
    _cleanupDone = true

    -- หยุด loop ทั้งหมด
    State.KillAura        = false
    State.AutoFarmNearby  = false
    State.AutoFarmAllBoss = false
    State.AutoQuest       = false

    -- คืนค่าระบบ fly/noclip
    disableFly()
    disableNoclip()
    if NoclipCamEnabled then applyNoclipCam(false) end

    -- คืน humanoid ปกติ
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChild("Humanoid")
            if hum then hum.PlatformStand = false end
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") then v.CanCollide = true end
            end
        end
    end)

    -- disconnect connections ที่ลงทะเบียนไว้ทั้งหมด
    if _G.__NobodyHubConnections then
        for _, conn in ipairs(_G.__NobodyHubConnections) do
            pcall(function() conn:Disconnect() end)
        end
        _G.__NobodyHubConnections = nil
    end

    -- ล้าง flag และ GUI ปุ่ม toggle
    pcall(function() getgenv().NobodyHub_LOADED = false end)
    pcall(function()
        local gui = CoreGui:FindFirstChild("FluentToggleButtonGui")
        if gui then gui:Destroy() end
    end)
    _G.__NobodyHubUnload = nil
end

-- Public unload (เรียกได้จากภายนอก เหมือน lineage.lua)
-- จะถูกกำหนดหลังจาก Window ถูกสร้างแล้ว

-- ==================== ADVANCED ATTACK (รองรับ Select Weapon) ====================
local function AdvancedAttack(targetModel, targetRoot)
    pcall(function()
        local remote = ReplicatedStorage:WaitForChild("CombatSystem"):WaitForChild("Remotes"):WaitForChild("RequestHit")
        if remote and targetRoot and targetModel then 
            remote:FireServer(targetRoot.Position, targetModel, targetRoot.CFrame) 
        end

        local char = getCharacter()
        if char then
            local selectedWeapon = State.SelectedWeapon or "Auto (All)"
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    -- ถ้าเลือก weapon เฉพาะ ให้ข้ามตัวที่ไม่ใช่
                    if selectedWeapon ~= "Auto (All)" and tool.Name ~= selectedWeapon then
                        continue
                    end
                    pcall(function() tool:Activate() end)
                    for _, v in ipairs(tool:GetDescendants()) do
                        if v:IsA("RemoteEvent") then
                            pcall(function() v:FireServer() end)
                        end
                    end
                end
            end
        end
    end)
end

local function getNearestNPC(maxDist, filter)
    maxDist = maxDist or 500
    local hrp = getHRP()
    if not hrp then return nil end

    local nearest, nearestDist = nil, maxDist
    for _, v in ipairs(FetchLocalEnemies()) do
        local npcRoot = v:FindFirstChild("HumanoidRootPart")
        if filter and not string.find(string.lower(v.Name), string.lower(filter)) then
            continue
        end
        local dist = (hrp.Position - npcRoot.Position).Magnitude
        if dist < nearestDist then
            nearestDist = dist
            nearest = v 
        end
    end
    return nearest
end

local function GetMultiTargetMonster()
    local hrp = getHRP()
    if not hrp or #State.SelectedMonsters == 0 then return nil end
    local closest = nil
    local shortestDist = tonumber(State.NearbyDistance) or 70
    
    for _, v in ipairs(FetchLocalEnemies()) do
        local cleanName = string.match(v.Name, "(%S*)%d") or v.Name
        local isSelected = false
        
        for _, selectedName in ipairs(State.SelectedMonsters) do 
            if cleanName == selectedName or v.Name == selectedName then 
                isSelected = true 
                break 
            end 
        end
        
        if isSelected then
            local targetRoot = v:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local magnitude = (hrp.Position - targetRoot.Position).Magnitude
                if magnitude <= shortestDist then 
                    closest = v 
                    shortestDist = magnitude 
                end
            end
        end
    end
    return closest
end

local function GetBossOnIsland()
    local Targets = {}
    for _, v in ipairs(FetchLocalEnemies()) do
        local nameLower = v.Name:lower()
        for _, bossName in pairs(BossList) do
            if nameLower:find(bossName:lower()) then
                if v.Humanoid.MaxHealth > 1000 then table.insert(Targets, v) break end
            end
        end
    end
    return Targets
end

local QuestTable = {
    {minLvl = 0,     maxLvl = 99,    questName = "Thief Hunter",        mobName = "thief",           island = "Starter Island"},
    {minLvl = 100,   maxLvl = 249,   questName = "Thief Boss",          mobName = "thief boss",      island = "Starter Island"},
    {minLvl = 250,   maxLvl = 499,   questName = "Monkey Hunter",       mobName = "monkey",          island = "Jungle Island"},
    {minLvl = 500,   maxLvl = 749,   questName = "Monkey Boss",         mobName = "monkey boss",     island = "Jungle Island"},
    {minLvl = 750,   maxLvl = 999,   questName = "Desert Bandit",       mobName = "bandit",          island = "Desert Island"},
    {minLvl = 1000,  maxLvl = 1499,  questName = "Desert Bandit Boss",  mobName = "bandit boss",     island = "Desert Island"},
    {minLvl = 1500,  maxLvl = 1999,  questName = "Frost Rogue Hunter",  mobName = "frost",           island = "Snow Island"},
    {minLvl = 2000,  maxLvl = 2999,  questName = "Winter Warden Boss",  mobName = "warden",          island = "Snow Island"},
    {minLvl = 3000,  maxLvl = 3999,  questName = "Sorcerer Hunter",     mobName = "sorcerer",        island = "Shibuya Station"},
    {minLvl = 4000,  maxLvl = 4999,  questName = "Panda Sorcerer Boss", mobName = "panda",           island = "Shibuya Station"},
    {minLvl = 5000,  maxLvl = 6249,  questName = "Hollow Hunter",       mobName = "hollow",          island = "Hueco Mundo"},
    {minLvl = 6250,  maxLvl = 6999,  questName = "Strong Sorcerer",     mobName = "strong sorcerer", island = "Shinjuku Island"},
    {minLvl = 7000,  maxLvl = 7999,  questName = "Curse Hunter",        mobName = "curse",           island = "Shinjuku Island"},
    {minLvl = 8000,  maxLvl = 8999,  questName = "Slime Warrior",       mobName = "slime",           island = "Slime Island"},
    {minLvl = 9000,  maxLvl = 9999,  questName = "Academy Challenge",   mobName = "academy",         island = "Academy Island"},
    {minLvl = 10000, maxLvl = 10749, questName = "Blade Masters",       mobName = "blade",           island = "Judgement Island"},
    {minLvl = 10750, maxLvl = 11499, questName = "Quincy Quest",        mobName = "quincy",          island = "Soul Society"},
    {minLvl = 11500, maxLvl = 11999, questName = "Ninja Slayer",        mobName = "ninja",           island = "Ninja Island"},
    {minLvl = 12000, maxLvl = 12750, questName = "Arena Takedown",      mobName = "arena",           island = "Lawless Island"},
}

local function getPlayerLevel()
    local level = 0
    pcall(function()
        local stats = LocalPlayer:FindFirstChild("leaderstats") or LocalPlayer:FindFirstChild("Stats") or LocalPlayer:FindFirstChild("stats")
        if stats then
            local lvlVal = stats:FindFirstChild("Level") or stats:FindFirstChild("Lvl") or stats:FindFirstChild("level")
            if lvlVal then level = tonumber(lvlVal.Value) or 0 end
        end
        if level == 0 then
            local data = LocalPlayer:FindFirstChild("Data") or LocalPlayer:FindFirstChild("data")
            if data then
                local lvlVal = data:FindFirstChild("Level") or data:FindFirstChild("Lvl")
                if lvlVal then level = tonumber(lvlVal.Value) or 0 end
            end
        end
    end)
    return level
end

local function getQuestForLevel(level)
    for _, q in ipairs(QuestTable) do
        if level >= q.minLvl and level <= q.maxLvl then return q end
    end
    return QuestTable[#QuestTable]
end

-- ==================== TOGGLE UI BUTTON ====================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "FluentToggleButtonGui"
ScreenGui.Parent         = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local ToggleButton = Instance.new("TextButton")
ToggleButton.Parent           = ScreenGui
ToggleButton.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
ToggleButton.BorderSizePixel  = 0
ToggleButton.Position         = UDim2.new(0, 10, 0, 10)
ToggleButton.Size             = UDim2.new(0, 50, 0, 50)
ToggleButton.Font             = Enum.Font.GothamBold
ToggleButton.Text             = "UI"
ToggleButton.TextColor3       = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize         = 20
ToggleButton.AutoButtonColor  = true

Instance.new("UICorner", ToggleButton).CornerRadius = UDim.new(0, 8)

local btnStroke = Instance.new("UIStroke", ToggleButton)
btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
btnStroke.Color           = Color3.fromRGB(96, 205, 255)
btnStroke.Thickness       = 2

local dragging, dragInput, dragStart, startPos

ToggleButton.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
        dragging  = true
        dragStart = inp.Position
        startPos  = ToggleButton.Position
        inp.Changed:Connect(function()
            if inp.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

ToggleButton.InputChanged:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch then
        dragInput = inp
    end
end)

UserInputService.InputChanged:Connect(function(inp)
    if inp == dragInput and dragging then
        local d = inp.Position - dragStart
        ToggleButton.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y
        )
    end
end)

-- ==================== FLUENT WINDOW SETUP ====================
local Fluent           = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title       = "Nobody | " .. GameName,
    SubTitle    = "By Dx",
    TabWidth    = 160,
    Size        = UDim2.fromOffset(580, 460),
    Acrylic     = true,
    Theme       = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

-- ==================== HOOK WINDOW DESTROY + PUBLIC UNLOAD ====================
-- Hook ปุ่มปิด UI ของ Fluent → cleanup โดยไม่ recurse
local _origDestroy = Window.Destroy
if _origDestroy then
    Window.Destroy = function(self, ...)
        _cleanupState()
        return _origDestroy(self, ...)
    end
end

-- Public unload function (ตาม lineage.lua pattern — เรียกจากปุ่ม Unload หรือภายนอกได้)
_G.__NobodyHubUnload = function()
    _cleanupState()
    pcall(function()
        if Window then
            pcall(function() Window:Destroy() end)
            pcall(function() Window.Gui:Destroy() end)
            pcall(function() Window.gui:Destroy() end)
        end
        local cg = game:GetService("CoreGui")
        for _, v in ipairs(cg:GetChildren()) do
            if v:IsA("ScreenGui") then
                local n = v.Name
                if n == "Fluent" or n:find("Fluent") or n:find("Nobody") then
                    pcall(function() v:Destroy() end)
                end
            end
        end
    end)
end

local uiVisible = true
ToggleButton.MouseButton1Click:Connect(function()
    uiVisible = not uiVisible
    Window:Minimize(not uiVisible) 
end)

local Tabs = {
    Main     = Window:AddTab({ Title = "Main", Icon = "home" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options

do
    -- ==================== COMBAT / KILL AURA SECTION ====================
    Tabs.Main:AddSection("Combat (Fast Performance)")

    local KillAuraToggle = Tabs.Main:AddToggle("KillAura", {
        Title = "KillAura (Auto Attack Nearby)",
        Description = "",
        Default = State.KillAura
    })

    Tabs.Main:AddSlider("KillAuraCD", {
        Title = "Attack Delay",
        Description = "Attack speed (seconds) - Lower is faster but may cause more lag",
        Default = State.KillAuraCD,
        Min = 0.1,
        Max = 1,
        Rounding = 1,
        Callback = function(Value)
            State.KillAuraCD = Value
            saveState(State)
        end
    })

    Tabs.Main:AddSlider("KillAuraRange", {
        Title = "Aura Radius",
        Description = "Distance(studs)",
        Default = State.KillAuraRange,
        Min = 5,
        Max = 300,
        Rounding = 0,
        Callback = function(Value)
            State.KillAuraRange = Value
            saveState(State)
        end
    })

    KillAuraToggle:OnChanged(function()
        State.KillAura = Options.KillAura.Value
        saveState(State)

        if State.KillAura then
            task.spawn(function()
                while State.KillAura do
                    task.wait(State.KillAuraCD)
                    local hrp = getHRP()
                    if hrp then
                        local radius = State.KillAuraRange
                        for _, v in ipairs(FetchLocalEnemies()) do
                            if not State.KillAura then break end
                            local targetRoot = v:FindFirstChild("HumanoidRootPart")
                            if targetRoot then
                                local dist = (hrp.Position - targetRoot.Position).Magnitude
                                if dist <= radius then
                                    AdvancedAttack(v, targetRoot)
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)

    -- ==================== AUTO QUEST SECTION ====================
    Tabs.Main:AddSection("Quest Farming (Level-Based)")

    Tabs.Main:AddButton({
        Title = "Detect My Level",
        Description = "Shows your level and the correct quest for you",
        Callback = function()
            local lvl = getPlayerLevel()
            local quest = getQuestForLevel(lvl)
            Fluent:Notify({
                Title = "Level: " .. tostring(lvl),
                Content = "Quest: " .. quest.questName .. "\nIsland: " .. quest.island .. "\nMob: " .. quest.mobName,
                Duration = 8
            })
        end
    })

    local AutoQuestToggle = Tabs.Main:AddToggle("AutoQuest", {
        Title = "Auto Quest (Level-Based)", 
        Default = State.AutoQuest 
    })
    
    AutoQuestToggle:OnChanged(function()
        State.AutoQuest = Options.AutoQuest.Value
        saveState(State)
        
        if State.AutoQuest then
            local lvl = getPlayerLevel()
            local quest = getQuestForLevel(lvl)
            Fluent:Notify({ Title = "Auto Quest Started!", Content = "Level " .. lvl .. " → " .. quest.questName, Duration = 5 })
            
            task.spawn(function()
                while State.AutoQuest do
                    local currentLvl   = getPlayerLevel()
                    local currentQuest = getQuestForLevel(currentLvl)
                    
                    pcall(function()
                        local promptFolders = {Workspace:FindFirstChild("NPCs"), Workspace:FindFirstChild("Quests"), Workspace}
                        for _, folder in ipairs(promptFolders) do
                            if folder then
                                for _, v in ipairs(folder:GetChildren()) do
                                    if not State.AutoQuest then break end
                                    local nameL = string.lower(v.Name)
                                    if v:IsA("Model") and (string.find(nameL, string.lower(currentQuest.questName)) or string.find(nameL, string.lower(currentQuest.mobName)) or string.find(nameL, "quest")) then
                                        for _, child in ipairs(v:GetDescendants()) do
                                            if child:IsA("ProximityPrompt") then
                                                local part = v:FindFirstChildWhichIsA("BasePart")
                                                if part then
                                                    teleportTo(part.CFrame * CFrame.new(0, 0, 3))
                                                    task.wait(0.5)
                                                    pcall(function() fireproximityprompt(child) end)
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)

                    pcall(function()
                        for _, v in pairs(ReplicatedStorage:GetDescendants()) do
                            if (v:IsA("RemoteEvent") or v:IsA("RemoteFunction")) and string.find(string.lower(v.Name), "quest") then
                                if v:IsA("RemoteEvent") then v:FireServer() end
                            end
                        end
                    end)

                    for i = 1, 15 do 
                        if not State.AutoQuest then break end
                        local mob = getNearestNPC(9999, currentQuest.mobName)
                        if mob then
                            local mobRoot = mob:FindFirstChild("HumanoidRootPart")
                            local hrp = getHRP()
                            if mobRoot and hrp then
                                -- ใช้ getAttackCFrame แทน hardcode
                                hrp.CFrame = getAttackCFrame(mobRoot, State.FarmDistance)
                                if not State.KillAura then
                                    AdvancedAttack(mob, mobRoot)
                                end
                            end
                        end
                        task.wait(0.25)
                    end

                    local newLvl = getPlayerLevel()
                    if newLvl > currentLvl then
                        local newQuest = getQuestForLevel(newLvl)
                        if newQuest.questName ~= currentQuest.questName then
                            Fluent:Notify({ Title = "Level Up!", Content = "Switching to: " .. newQuest.questName, Duration = 5 })
                        end
                    end
                    task.wait(1)
                end
            end)
        end
    end)

    -- ==================== NEARBY FARM SECTION ====================
    Tabs.Main:AddSection("Auto Farm Nearby (Grouped Mobs)")

    local NearbyDistSlider = Tabs.Main:AddSlider("NearbyDistance", {
        Title = "Scan Distance",
        Default = tonumber(State.NearbyDistance) or 70,
        Min = 10,
        Max = 1000,
        Rounding = 1,
        Callback = function(Value)
            State.NearbyDistance = tonumber(Value) or 70
            saveState(State)
        end
    })

    local FarmDistSlider = Tabs.Main:AddSlider("FarmDistance", {
        Title = "Attack Distance",
        Default = tonumber(State.FarmDistance) or 8,
        Min = 0,
        Max = 20,
        Rounding = 1,
        Callback = function(Value)
            State.FarmDistance = tonumber(Value) or 8
            saveState(State)
        end
    })

    local MonsterDropdown = Tabs.Main:AddDropdown("MonsterDropdown", {
        Title = "Select Monsters to Farm",
        Values = DropdownEnemies(),
        Multi = true,
        Default = State.SelectedMonsters,
    })

    MonsterDropdown:OnChanged(function(Value)
        local selectedList = {}
        for monsterName, isSelected in pairs(Value) do
            if isSelected then table.insert(selectedList, monsterName) end
        end
        State.SelectedMonsters = selectedList
        saveState(State)
    end)

    Tabs.Main:AddButton({
        Title = "Refresh Nearby Monsters",
        Callback = function()
            local newList = DropdownEnemies()
            MonsterDropdown:SetValues(newList)
            Fluent:Notify({Title = "Refreshed", Content = "Updated monster list.", Duration = 3})
        end
    })

    local AutoFarmNearbyToggle = Tabs.Main:AddToggle("AutoFarmNearby", {
        Title = "Auto Farm Selected Monsters", 
        Default = State.AutoFarmNearby 
    })
    
    AutoFarmNearbyToggle:OnChanged(function()
        State.AutoFarmNearby = Options.AutoFarmNearby.Value
        saveState(State)
        
        if State.AutoFarmNearby then
            -- เปิด Fly/Noclip/NoclipCam อัตโนมัติถ้า toggle เปิดอยู่
            if State.AutoFly   then enableFly()  end
            if State.AutoNoclip then enableNoclip() end
            if State.AutoNoclipCam then applyNoclipCam(true) end

            task.spawn(function()
                while State.AutoFarmNearby do
                    task.wait(0.1)
                    local target = GetMultiTargetMonster()
                    if target and target:FindFirstChild("HumanoidRootPart") then
                        local targetRoot     = target.HumanoidRootPart
                        local targetHumanoid = target:FindFirstChild("Humanoid")
                        while State.AutoFarmNearby and targetHumanoid and targetHumanoid.Health > 0 do
                            task.wait(0.05)
                            local hrp = getHRP()
                            if hrp and targetRoot then
                                hrp.Velocity    = Vector3.new(0, 0, 0)
                                hrp.RotVelocity = Vector3.new(0, 0, 0)
                                -- ใช้ getAttackCFrame
                                hrp.CFrame = getAttackCFrame(targetRoot, State.FarmDistance)
                                if not State.KillAura then
                                    AdvancedAttack(target, targetRoot)
                                end
                            else
                                break 
                            end
                        end
                    else
                        task.wait(0.5)
                    end
                end
                -- ปิด Fly/Noclip เมื่อหยุด farm (ถ้าไม่ได้ toggle ไว้อิสระ)
                if not State.AutoFly       then disableFly()  end
                if not State.AutoNoclip    then disableNoclip() end
                if not State.AutoNoclipCam and NoclipCamEnabled then applyNoclipCam(false) end
            end)
        end
    end)

    -- ==================== ISLAND PATROL SECTION ====================
    Tabs.Main:AddSection("Island Patrol")
    
    local PatrolToggle = Tabs.Main:AddToggle("AutoFarmAllBoss", {
        Title = "All Bosses Farm", 
        Default = State.AutoFarmAllBoss 
    })
    
    PatrolToggle:OnChanged(function()
        State.AutoFarmAllBoss = Options.AutoFarmAllBoss.Value
        saveState(State)
        
        if State.AutoFarmAllBoss then
            if State.AutoFly   then enableFly()  end
            if State.AutoNoclip then enableNoclip() end
            if State.AutoNoclipCam then applyNoclipCam(true) end

            task.spawn(function()
                local islandIndex = 1
                while State.AutoFarmAllBoss do
                    local currentIsland = IslandPatrol[islandIndex]
                    Fluent:Notify({Title = "Patrol", Content = "กำลังเดินทางไป: " .. currentIsland, Duration = 3})
                    
                    pcall(function()
                        ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TeleportToPortal"):FireServer(currentIsland)
                    end)
                    
                    task.wait(6) 
                    local BossesFound = GetBossOnIsland()
                    if #BossesFound > 0 then
                        for _, boss in pairs(BossesFound) do
                            if not State.AutoFarmAllBoss then break end
                            if boss and boss:FindFirstChild("Humanoid") and boss.Humanoid.Health > 0 then
                                while State.AutoFarmAllBoss and boss:FindFirstChild("Humanoid") and boss.Humanoid.Health > 0 do
                                    task.wait(0.05)
                                    local hrp = getHRP()
                                    if hrp and boss:FindFirstChild("HumanoidRootPart") then
                                        -- ใช้ getAttackCFrame
                                        hrp.CFrame = getAttackCFrame(boss.HumanoidRootPart, State.FarmDistance)
                                        if not State.KillAura then
                                            AdvancedAttack(boss, boss.HumanoidRootPart)
                                        end
                                    end
                                end
                                task.wait(1)
                            end
                        end
                    end
                    islandIndex = (islandIndex % #IslandPatrol) + 1
                    task.wait(2)
                end
                if not State.AutoFly       then disableFly()  end
                if not State.AutoNoclip    then disableNoclip() end
                if not State.AutoNoclipCam and NoclipCamEnabled then applyNoclipCam(false) end
            end)
        end
    end)
    
end

    -- ==================== SETTINGS: FARM UTILITIES ====================
    Tabs.Settings:AddSection("Farm Utilities (auto open when starting Farm / Boss)")

    local FlyToggle = Tabs.Settings:AddToggle("AutoFly", {
        Title = "Fly",
        Description = "",
        Default = State.AutoFly
    })
    FlyToggle:OnChanged(function()
        State.AutoFly = Options.AutoFly.Value
        saveState(State)
        if State.AutoFly then
            enableFly()
            Fluent:Notify({Title = "Fly", Content = "Open Fly", Duration = 3})
        else
            disableFly()
            Fluent:Notify({Title = "Fly", Content = "Close Fly", Duration = 3})
        end
    end)

    local NoclipToggle = Tabs.Settings:AddToggle("AutoNoclip", {
        Title = "Noclip",
        Description = "Disable character collision — auto-enable when starting Auto Farm / All Bosses",
        Default = State.AutoNoclip
    })
    NoclipToggle:OnChanged(function()
        State.AutoNoclip = Options.AutoNoclip.Value
        saveState(State)
        if State.AutoNoclip then
            enableNoclip()
            Fluent:Notify({Title = "Noclip", Content = "Open Noclip", Duration = 3})
        else
            disableNoclip()
            Fluent:Notify({Title = "Noclip", Content = "Close Noclip", Duration = 3})
        end
    end)

    local NoclipCamToggle = Tabs.Settings:AddToggle("AutoNoclipCam", {
        Title = "NoclipCam",
        Description = "",
        Default = State.AutoNoclipCam
    })
    NoclipCamToggle:OnChanged(function()
        State.AutoNoclipCam = Options.AutoNoclipCam.Value
        saveState(State)
        applyNoclipCam(State.AutoNoclipCam)
        local label = State.AutoNoclipCam and "Open NoclipCam" or "Close NoclipCam"
        Fluent:Notify({Title = "NoclipCam", Content = label, Duration = 3})
    end)

    -- ==================== SETTINGS: ATTACK OPTIONS ====================
    Tabs.Settings:AddSection("Attack Options")

    local WeaponDropdown = Tabs.Settings:AddDropdown("SelectedWeapon", {
        Title = "Select Weapon",
        Description = "Select the weapon to use for attacking — Auto (All) = use all",
        Values = getWeaponList(),
        Default = State.SelectedWeapon,
    })
    WeaponDropdown:OnChanged(function(Value)
        State.SelectedWeapon = Value
        saveState(State)
    end)

    Tabs.Settings:AddButton({
        Title = "Refresh Weapon List",
        Description = "Refresh the list of weapons in your hand and backpack",
        Callback = function()
            WeaponDropdown:SetValues(getWeaponList())
            Fluent:Notify({Title = "Weapon List", Content = "Weapon list updated", Duration = 3})
        end
    })

    local MethodDropdown = Tabs.Settings:AddDropdown("AttackMethod", {
        Title = "Attack Position (Method)",
        Description = "The position to stand while attacking — above / under / front / behind",
        Values = {"above", "under", "front", "behind"},
        Default = State.AttackMethod,
    })
    MethodDropdown:OnChanged(function(Value)
        State.AttackMethod = Value
        saveState(State)
    end)

InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder(GAME_FOLDER)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title   = "Nobody " .. Fluent.Version,
    Content = "Loaded Successfully • Optimized",
    Duration = 8
})