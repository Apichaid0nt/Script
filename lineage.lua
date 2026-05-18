-- ============================================================
--  Nobody Hub | by Dx
--  v4 — Nested Mob + Boss Spawner + Auto Save + Unload
-- ============================================================

local Fluent           = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ── Services ─────────────────────────────────────────────────
local CoreGui          = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- ╔══════════════════════════════════════════════════════════╗
--  SAVE SYSTEM  —  NobodyHub/[GameName]/state.json
-- ╚══════════════════════════════════════════════════════════╝

local GAME_NAME   = (game.Name ~= "" and game.Name or tostring(game.PlaceId))
                        :gsub("[^%w%s%-]", ""):gsub("%s+", "_")
local GAME_FOLDER = "NobodyHub/" .. GAME_NAME
local SAVE_FILE   = GAME_FOLDER .. "/state.json"

local function ensureFolder(path)
    pcall(function() if not isfolder(path) then makefolder(path) end end)
end

local function saveState(st)
    pcall(function()
        ensureFolder("NobodyHub")
        ensureFolder(GAME_FOLDER)
        local data = {
            selectedWeapon = st.selectedWeapon,
            bringMob       = st.bringMob,
            method         = st.method,
            distance       = st.distance,
            selectedSkills = st.selectedSkills,
            autoSkill      = st.autoSkill,
            selectedMob    = st.selectedMob,
            autoMob        = st.autoMob,
            selectedBoss       = st.selectedBoss,
            autoBoss           = st.autoBoss,
            autoAttack         = st.autoAttack,
            summonSlimeAmount    = st.summonSlimeAmount,
            selectedSummonBoss  = st.selectedSummonBoss,
            autoSummonBoss      = st.autoSummonBoss,
            autoOre             = st.autoOre,
            selectedDungeonKey        = st.selectedDungeonKey,
            selectedDungeonDifficulty = st.selectedDungeonDifficulty,
            autoDungeon               = st.autoDungeon,
            autoStartReplay           = st.autoStartReplay,
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

-- ╔══════════════════════════════════════════════════════════╗
--  TOGGLE BUTTON + DRAG
-- ╚══════════════════════════════════════════════════════════╝

if CoreGui:FindFirstChild("FluentToggleButtonGui") then
    CoreGui:FindFirstChild("FluentToggleButtonGui"):Destroy()
end

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
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
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
    if inp.UserInputType == Enum.UserInputType.MouseMovement
    or inp.UserInputType == Enum.UserInputType.Touch then
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

-- ╔══════════════════════════════════════════════════════════╗
--  WINDOW
-- ╚══════════════════════════════════════════════════════════╝

local Window = Fluent:CreateWindow({
    Title       = "Nobody " .. Fluent.Version,
    SubTitle    = "by Dx",
    TabWidth    = 160,
    Size        = UDim2.fromOffset(580, 460),
    Acrylic     = true,
    Theme       = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl,
})

local uiVisible = true
ToggleButton.MouseButton1Click:Connect(function()
    uiVisible = not uiVisible
    Window:Minimize(not uiVisible)
end)

local Tabs = {
    Main     = Window:AddTab({ Title = "Main",     Icon = "book"       }),
    Summon   = Window:AddTab({ Title = "Summon",   Icon = "activity"   }),
    Dungeon  = Window:AddTab({ Title = "Dungeon",  Icon = "shield"     }),
    Teleport = Window:AddTab({ Title = "Teleport", Icon = "map-pin"    }),
    Stats    = Window:AddTab({ Title = "Stats",    Icon = "bar-chart-2" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings"   }),
}

local Options = Fluent.Options

-- ╔══════════════════════════════════════════════════════════╗
--  STATE  (โหลดค่าที่ save ไว้ หรือใช้ default)
-- ╚══════════════════════════════════════════════════════════╝

local saved = loadSavedState() or {}

local State = {
    -- Settings
    selectedWeapon = saved.selectedWeapon or "None",
    bringMob       = saved.bringMob       or false,
    method         = saved.method         or "above",
    distance       = saved.distance       or 5,

    -- Main
    selectedSkills = saved.selectedSkills or {"z"},
    autoSkill      = saved.autoSkill      or false,
    selectedMob    = saved.selectedMob    or "None",
    autoMob        = saved.autoMob        or false,
    selectedBoss   = (type(saved.selectedBoss) == "table" and saved.selectedBoss) or {"Rimuru"},
    autoBoss       = saved.autoBoss       or false,

    -- Auto Attack toggle — true by default
    autoAttack     = saved.autoAttack or false,

    -- Summon
    summonSlimeAmount     = saved.summonSlimeAmount     or "1",
    selectedSummonBoss    = saved.selectedSummonBoss    or "Verdant Hero",
    autoSummonBoss        = saved.autoSummonBoss        or false,

    -- Ore
    autoOre     = saved.autoOre     or false,

    -- Dungeon
    selectedDungeonKey        = saved.selectedDungeonKey        or "RAIDEN",
    selectedDungeonDifficulty = saved.selectedDungeonDifficulty or "Easy",
    autoDungeon               = saved.autoDungeon               or false,
    autoStartReplay           = saved.autoStartReplay           or false,
}

-- ╔══════════════════════════════════════════════════════════╗
--  DATA HELPERS
-- ╚══════════════════════════════════════════════════════════╝

local function getChar()
    return LocalPlayer.Character
end

local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function isAlive()
    local c = getChar()
    if not c then return false end
    local h = c:FindFirstChildOfClass("Humanoid")
    return h ~= nil and h.Health > 0
end

local function getWeaponList()
    local list, seen = {}, {}
    local function scan(parent)
        if not parent then return end
        for _, v in ipairs(parent:GetChildren()) do
            if v:IsA("Tool") and not seen[v.Name] then
                seen[v.Name] = true
                table.insert(list, v.Name)
            end
        end
    end
    scan(LocalPlayer:FindFirstChild("Backpack"))
    scan(getChar())
    return #list > 0 and list or {"None"}
end

-- ── Mob list (รองรับ 2 ชั้น: Enemies.[folder].[mob]) ────────
local function getMobList()
    local list, seen = {}, {}
    local f = workspace:FindFirstChild("Enemies")
    if f then
        for _, child in ipairs(f:GetChildren()) do
            if child:FindFirstChildOfClass("Humanoid") then
                -- ชั้นแรก: เป็น model เลย
                if not seen[child.Name] then
                    seen[child.Name] = true
                    table.insert(list, child.Name)
                end
            else
                -- ชั้นแรกเป็น folder → ชั้นสองเป็น mob model
                for _, mob in ipairs(child:GetChildren()) do
                    if mob:FindFirstChildOfClass("Humanoid") and not seen[mob.Name] then
                        seen[mob.Name] = true
                        table.insert(list, mob.Name)
                    end
                end
            end
        end
    end
    return #list > 0 and list or {"None"}
end

-- ── Boss list ────────────────────────────────────────────────
-- BOSS_SPAWNER = workspace.Boss.ServerTimeBossSpawner.[name]
-- BOSS_DIRECT  = workspace.Boss.[name] โดยตรง (Aizen เป็นแบบนี้)
local BOSS_LIST       = {"Rimuru", "Sung Jinwoo", "Aizen"}
local BOSS_DIRECT_SET = {Aizen = true}

-- ── Island / Questline ───────────────────────────────────────
local function getIslandList()
    local list = {}
    local fi = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Island")
    if fi then
        for _, v in ipairs(fi:GetChildren()) do table.insert(list, v.Name) end
    end
    return #list > 0 and list or {"None"}
end

local function getQuestlineList()
    local list = {}
    local f = workspace:FindFirstChild("Questline")
    if f then
        for _, v in ipairs(f:GetChildren()) do table.insert(list, v.Name) end
    end
    return #list > 0 and list or {"None"}
end

local function getQuestlineChildren(name)
    local list = {}
    local f = workspace:FindFirstChild("Questline")
    if f then
        local ql = f:FindFirstChild(name)
        if ql then
            for _, v in ipairs(ql:GetChildren()) do table.insert(list, v.Name) end
        end
    end
    return #list > 0 and list or {"None"}
end

-- ── NPC list ─────────────────────────────────────────────────
local function getNPCFolder()
    return workspace:FindFirstChild("NPC")
        or workspace:FindFirstChild("NPCs")
        or workspace:FindFirstChild("Npc")
end

local function getNPCList()
    local list = {}
    local f = getNPCFolder()
    if f then
        for _, v in ipairs(f:GetChildren()) do
            table.insert(list, v.Name)
        end
    end
    return #list > 0 and list or {"None"}
end

local function getNPCChildren(name)
    local list = {}
    local f = getNPCFolder()
    if f then
        local npc = f:FindFirstChild(name)
        if npc then
            for _, v in ipairs(npc:GetChildren()) do
                table.insert(list, v.Name)
            end
        end
    end
    return #list > 0 and list or nil  -- nil = NPC is flat (no sub-children)
end

-- ── Target finders ───────────────────────────────────────────

-- หามอนที่มีชีวิต รองรับ 2 ชั้น: Enemies.[folder].[mob]
local function findMobTarget(targetName)
    local f = workspace:FindFirstChild("Enemies")
    if not f then return nil end
    for _, child in ipairs(f:GetChildren()) do
        -- ชั้นแรก: model
        if child.Name == targetName then
            local h = child:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then return child end
        end
        -- ชั้นสอง: folder → model
        for _, mob in ipairs(child:GetChildren()) do
            if mob.Name == targetName then
                local h = mob:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then return mob end
            end
        end
    end
    return nil
end

-- หา boss ใน workspace.Boss.ServerTimeBossSpawner.[name]
local function findSpawnerBoss(bossName)
    local bossFolder = workspace:FindFirstChild("Boss")
    local spawner    = bossFolder and bossFolder:FindFirstChild("ServerTimeBossSpawner")
    if not spawner then return nil end
    local boss = spawner:FindFirstChild(bossName)
    if not boss then return nil end
    local h = boss:FindFirstChildOfClass("Humanoid")
    return (h and h.Health > 0) and boss or nil
end

-- หา Aizen ใน workspace.Boss.Aizen.[Aizen] (BasePart/Model ข้างใน — spawn แล้วเท่านั้น)
-- ตอนไม่มี boss: workspace.Boss.Aizen ว่างเปล่า → คืน nil
-- ตอน spawn:    workspace.Boss.Aizen.Aizen มีอยู่  → คืน object นั้น
local function findDirectBoss(bossName)
    local bossFolder = workspace:FindFirstChild("Boss")
    if not bossFolder then return nil end
    local container = bossFolder:FindFirstChild(bossName)
    if not container then return nil end
    -- ลงไปหา child ที่ชื่อเดียวกัน (ตัว boss จริงที่ spawn อยู่ข้างใน)
    local inner = container:FindFirstChild(bossName)
    if not inner then return nil end
    return inner
end

-- รวม: เลือก path ตาม BOSS_DIRECT_SET
local function findBossTarget(bossName)
    if BOSS_DIRECT_SET[bossName] then
        return findDirectBoss(bossName)
    end
    return findSpawnerBoss(bossName)
end

-- ── Summon Boss finder — รองรับทั้ง BossSummoner และ JJKBossSummoner ──
-- บอสที่อยู่ใน JJK_SUMMON_SET → ค้นใน workspace.Boss.JJKBossSummoner
-- บอสอื่นๆ                    → ค้นใน workspace.Boss.BossSummoner
local JJK_SUMMON_SET = {Sukuna = true, Gojo = true}

local function findSummonBoss(bossName)
    local bossFolder = workspace:FindFirstChild("Boss")
    if not bossFolder then return nil end
    local spawnerName = JJK_SUMMON_SET[bossName] and "JJKBossSummoner" or "BossSummoner"
    local spawner = bossFolder:FindFirstChild(spawnerName)
    if not spawner then return nil end
    local container = spawner:FindFirstChild(bossName)
    if not container then return nil end
    -- container มี Humanoid ตรงๆ (เป็น Model)
    local h = container:FindFirstChildOfClass("Humanoid")
    if h and h.Health > 0 then return container end
    -- container เป็น folder → หา child ที่มี Humanoid
    for _, child in ipairs(container:GetChildren()) do
        local ch = child:FindFirstChildOfClass("Humanoid")
        if ch and ch.Health > 0 then return child end
    end
    return nil
end

-- ── Ore finder — hardcode workspace.Boss.Stone1.Stone ────────
local function findOreTarget()
    local stone1 = workspace:FindFirstChild("Boss")
                   and workspace.Boss:FindFirstChild("Stone1")
    if not stone1 then return nil end
    local ore = stone1:FindFirstChild("Stone")
    return (ore and ore.Parent) and ore or nil
end

-- Find any alive mob in workspace.Enemies (used by Auto Dungeon — no name filter)
local function findAnyMobTarget()
    local f = workspace:FindFirstChild("Enemies")
    if not f then return nil end
    for _, child in ipairs(f:GetChildren()) do
        if child:FindFirstChildOfClass("Humanoid") then
            local h = child:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then return child end
        else
            for _, mob in ipairs(child:GetChildren()) do
                local h = mob:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then return mob end
            end
        end
    end
    return nil
end


-- รองรับทั้ง Humanoid model (Rimuru/SungJinwoo) และ Part โดยตรง (Aizen)
local function isTargetAlive(target)
    if not target or not target.Parent then return false end
    local h = target:FindFirstChildOfClass("Humanoid")
    if h then return h.Health > 0 end
    -- ไม่มี Humanoid → เช็คแค่ว่า Parent ยังอยู่ (Aizen)
    return true
end

-- ── Utility ──────────────────────────────────────────────────

local function findLandPart(instance)
    if not instance then return nil end
    if instance:IsA("BasePart") then return instance end
    local p = instance:FindFirstChildOfClass("BasePart")
    if p then return p end
    return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function modelRoot(m)
    -- BasePart โดยตรง (เช่น simple part) → คืนตัวมันเลย
    if m:IsA("BasePart") then return m end
    return m:FindFirstChild("HumanoidRootPart")
        or m:FindFirstChild("RootPart")
        or m.PrimaryPart
        or findLandPart(m)   -- fallback สำหรับ Aizen Model ที่ไม่มี Root/Primary
end

-- ╔══════════════════════════════════════════════════════════╗
--  [FIX 1] standPos — "above" now correctly moves UP (was RightVector)
--           [NEW]  "under" method added — moves DOWN
-- ╚══════════════════════════════════════════════════════════╝
local function standPos(targetCF)
    local p, d = targetCF.Position, State.distance
    if State.method == "above"  then return p + Vector3.new(0, d, 0)            end  -- FIX: was RightVector
    if State.method == "under"  then return p - Vector3.new(0, d, 0)            end  -- NEW
    if State.method == "behind" then return p - targetCF.LookVector * d         end
    return p + targetCF.LookVector * d  -- front
end

local function faceTarget(targetPos)
    local root = getRoot()
    if not root then return end
    local o = root.Position
    root.CFrame = CFrame.lookAt(o, Vector3.new(targetPos.X, o.Y, targetPos.Z))
end

local function teleportTo(pos)
    local root = getRoot()
    if root then root.CFrame = CFrame.new(pos) end
end

local function equipWeapon()
    local name = State.selectedWeapon
    if not name or name == "None" or name == "" then return end
    local char     = getChar()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not char or not backpack then return end
    local current = char:FindFirstChildOfClass("Tool")
    if current and current.Name == name then return end
    local tool = backpack:FindFirstChild(name)
    if tool then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:EquipTool(tool) end) end
    end
end

-- ╔══════════════════════════════════════════════════════════╗
--  FLY HELPER — เปิด/ปิด fly สำหรับ Auto Mob/Boss
--  • enabled=true  → PlatformStand + BodyVelocity ยึดตัวไว้
--  • enabled=false → คืน physics ปกติ (ป้องกันกระเด้งโดนเตะ)
-- ╚══════════════════════════════════════════════════════════╝
local _flyActive = false

local function setFly(enabled)
    pcall(function()
        local char = getChar()
        if not char then return end
        local root = getRoot()
        local hum  = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end

        if enabled and not _flyActive then
            _flyActive = true
            hum.PlatformStand = true
            if not root:FindFirstChild("_NHFlyBV") then
                local bv        = Instance.new("BodyVelocity")
                bv.Name         = "_NHFlyBV"
                bv.Velocity     = Vector3.zero
                bv.MaxForce     = Vector3.new(1e9, 1e9, 1e9)
                bv.Parent       = root
            end
        elseif not enabled and _flyActive then
            _flyActive = false
            hum.PlatformStand = false
            local bv = root:FindFirstChild("_NHFlyBV")
            if bv then bv:Destroy() end
        end
    end)
end

-- helper: หา index ของค่าใน list
local function indexOf(list, val)
    for i, v in ipairs(list) do
        if v == val then return i end
    end
    return 1
end

-- ╔══════════════════════════════════════════════════════════╗
--  TAB: SETTINGS
-- ╚══════════════════════════════════════════════════════════╝
do
    local weaponList = getWeaponList()

    local WeaponDrop = Tabs.Settings:AddDropdown("WeaponDropdown", {
        Title       = "Select Weapon",
        Description = "Choose a weapon from your Backpack. It will be auto-equipped when farming starts.",
        Values      = weaponList,
        Multi       = false,
        Default     = indexOf(weaponList, State.selectedWeapon),
    })
    WeaponDrop:OnChanged(function(v)
        State.selectedWeapon = v
        saveState(State)
    end)

    Tabs.Settings:AddButton({
        Title       = "Refresh Weapon",
        Description = "Reload weapon list from Backpack",
        Callback    = function()
            local new = getWeaponList()
            WeaponDrop:SetValues(new)
            WeaponDrop:SetValue(new[1])
            State.selectedWeapon = new[1]
            saveState(State)
            Fluent:Notify({ Title = "Weapon", Content = "Refreshed — " .. #new .. " found", Duration = 3 })
        end,
    })

    local BringToggle = Tabs.Settings:AddToggle("BringMob", {
        Title       = "Bring Mob",
        Description = "Pull mob/boss next to you before attacking",
        Default     = State.bringMob,
    })
    BringToggle:OnChanged(function()
        State.bringMob = Options.BringMob.Value
        saveState(State)
    end)

    -- [FIX 2] "under" added to method list
    local methodValues = {"above", "under", "behind", "front"}
    local MethodDrop = Tabs.Settings:AddDropdown("MethodDropdown", {
        Title       = "Position Method",
        Description = "Where to stand relative to the target",
        Values      = methodValues,
        Multi       = false,
        Default     = indexOf(methodValues, State.method),
    })
    MethodDrop:OnChanged(function(v)
        State.method = v
        saveState(State)
    end)

    Tabs.Settings:AddSlider("DistanceSlider", {
        Title       = "Distance from Mob",
        Description = "Studs away from the target",
        Default     = State.distance,
        Min         = 1,
        Max         = 50,
        Rounding    = 1,
        Callback    = function(v)
            State.distance = v
            saveState(State)
        end,
    })

    -- ── Skills (ย้ายมาจาก Main tab) ──────────────────────────
    Tabs.Settings:AddParagraph({
        Title   = "Attack & Skill Settings",
        Content = "Configure Auto Attack and Auto Skill used across all farming modes.",
    })

    local AutoAttackToggle = Tabs.Settings:AddToggle("AutoAttack", {
        Title       = "Auto Attack (M1)",
        Description = "Automatically press M1 on the target while farming. Can be toggled anytime.",
        Default     = State.autoAttack,
    })
    AutoAttackToggle:OnChanged(function(val)
        State.autoAttack = val
        saveState(State)
        Fluent:Notify({
            Title   = "Auto Attack",
            Content = State.autoAttack and "ON" or "OFF",
            Duration = 2,
        })
    end)

    local SKILL_ORDER = {z=1, x=2, c=3, v=4, r=5}

    local SkillDrop = Tabs.Settings:AddDropdown("SkillDropdown", {
        Title       = "Select Skills",
        Description = "Pick one or more skills to use automatically",
        Values      = {"z", "x", "c", "v", "r"},
        Multi       = true,
        Default     = State.selectedSkills,
    })
    SkillDrop:OnChanged(function(tbl)
        local skills = {}
        for skill, active in next, tbl do
            if active then table.insert(skills, skill) end
        end
        table.sort(skills, function(a, b)
            return (SKILL_ORDER[a] or 9) < (SKILL_ORDER[b] or 9)
        end)
        State.selectedSkills = skills
        saveState(State)
    end)

    local AutoSkillToggle = Tabs.Settings:AddToggle("AutoSkill", {
        Title       = "Auto Skill",
        Description = "Auto-use selected skills (requires farming to be ON)",
        Default     = State.autoSkill,
    })
    AutoSkillToggle:OnChanged(function()
        State.autoSkill = Options.AutoSkill.Value
        saveState(State)
    end)

    -- ── Unload Button ─────────────────────────────────────────
    Tabs.Settings:AddParagraph({
        Title   = "Danger Zone",
        Content = "Unload will stop all farming loops, destroy the UI, and reset everything back to normal.",
    })

    Tabs.Settings:AddButton({
        Title       = "🛑 Unload Script",
        Description = "Immediately stops all scripts and destroys the UI.",
        Callback    = function()
            _G.__NobodyHubUnload()
        end,
    })
end

-- ╔══════════════════════════════════════════════════════════╗
--  TAB: MAIN
-- ╚══════════════════════════════════════════════════════════╝
do
    -- ── Boss ─────────────────────────────────────────────────
    Tabs.Main:AddParagraph({
        Title   = "Boss Farming",
        Content = "Teleports to and attacks bosses in ServerTimeBossSpawner (Aizen uses a direct path). Highest priority — runs before Ore and Mob. Supports multiple selection.",
    })

    local BossDrop = Tabs.Main:AddDropdown("BossDropdown", {
        Title   = "Select Boss",
        Values  = BOSS_LIST,
        Multi   = true,
        Default = State.selectedBoss,
    })
    BossDrop:OnChanged(function(tbl)
        -- ขั้น 1: เก็บ boss ที่เลือกอยู่แล้ว (ตามลำดับเดิม) ถ้ายังติ๊กอยู่
        local newList = {}
        for _, name in ipairs(State.selectedBoss) do
            if tbl[name] then
                table.insert(newList, name)
            end
        end
        -- ขั้น 2: boss ที่เพิ่งติ๊กใหม่ (ไม่เคยอยู่ใน list เดิม) → append ท้าย
        for _, name in ipairs(BOSS_LIST) do   -- วน BOSS_LIST เพื่อให้ลำดับ stable
            if tbl[name] then
                local found = false
                for _, n in ipairs(newList) do
                    if n == name then found = true; break end
                end
                if not found then
                    table.insert(newList, name)
                end
            end
        end
        State.selectedBoss = newList
        saveState(State)
    end)

    local AutoBossToggle = Tabs.Main:AddToggle("AutoBoss", {
        Title       = "Auto Boss",
        Description = "Automatically teleport and attack the selected boss. Highest priority.",
        Default     = State.autoBoss,
    })
    AutoBossToggle:OnChanged(function(val)
        State.autoBoss = val
        if State.autoBoss then
            setFly(true)
        elseif not State.autoMob and not State.autoOre and not State.autoSummonBoss then
            setFly(false)
        end
        saveState(State)
    end)

    -- ── Ore ──────────────────────────────────────────────────
    Tabs.Main:AddParagraph({
        Title   = "Ore Farming",
        Content = "Mines Stone in workspace.Boss.Stone1. Priority 2 — only runs when no boss is active.",
    })

    local AutoOreToggle = Tabs.Main:AddToggle("AutoOre", {
        Title       = "Auto Ore",
        Description = "Automatically teleport and mine ore. Pauses when a boss spawns.",
        Default     = State.autoOre,
    })
    AutoOreToggle:OnChanged(function(val)
        State.autoOre = val
        if State.autoOre then
            setFly(true)
        else
            if not State.autoMob and not State.autoBoss and not State.autoSummonBoss then
                setFly(false)
            end
        end
        saveState(State)
    end)

    -- ── Mob ──────────────────────────────────────────────────
    Tabs.Main:AddParagraph({
        Title   = "Mob Farming",
        Content = "Farm mobs from workspace.Enemies. Lowest priority — only runs when no boss or ore is active. Supports nested folder structure.",
    })

    local mobList = getMobList()

    local MobDrop = Tabs.Main:AddDropdown("MobDropdown", {
        Title   = "Select Mob",
        Values  = mobList,
        Multi   = false,
        Default = indexOf(mobList, State.selectedMob),
    })
    MobDrop:OnChanged(function(v)
        State.selectedMob = v
        saveState(State)
    end)

    Tabs.Main:AddButton({
        Title       = "Refresh Mob",
        Description = "Reload the mob list from workspace.Enemies",
        Callback    = function()
            local new = getMobList()
            MobDrop:SetValues(new)
            MobDrop:SetValue(new[1])
            State.selectedMob = new[1]
            saveState(State)
            Fluent:Notify({ Title = "Mob", Content = "Refreshed — " .. #new .. " found", Duration = 3 })
        end,
    })

    local AutoMobToggle = Tabs.Main:AddToggle("AutoMob", {
        Title       = "Auto Mob",
        Description = "Automatically teleport and attack the selected mob. Lowest priority (runs only when no boss or ore is active).",
        Default     = State.autoMob,
    })
    AutoMobToggle:OnChanged(function(val)
        State.autoMob = val
        if State.autoMob then
            setFly(true)
        elseif not State.autoBoss and not State.autoOre and not State.autoSummonBoss then
            setFly(false)
        end
        saveState(State)
    end)
end

-- ╔══════════════════════════════════════════════════════════╗
--  TAB: SUMMON
-- ╚══════════════════════════════════════════════════════════╝
do
    local SUMMON_RE_PATH = _getNet  -- ใช้ cache จาก _getNet แทน WaitForChild ซ้ำ

    -- ── Summon Rimuru ─────────────────────────────────────────
    Tabs.Summon:AddParagraph({
        Title   = "Summon Rimuru",
        Content = "Enter the number of Rimuru you want to summon, then press the button below.",
    })

    local SlimeInput = Tabs.Summon:AddInput("SlimeAmountInput", {
        Title       = "Summon Rimuru Amount",
        Description = "How many Rimuru to summon at once",
        Default     = State.summonSlimeAmount,
        Placeholder = "Enter amount, e.g. 10",
        Numeric     = true,
    })
    SlimeInput:OnChanged(function(v)
        State.summonSlimeAmount = v
        saveState(State)
    end)

    Tabs.Summon:AddButton({
        Title       = "✦ Summon Rimuru",
        Description = "Summon the specified number of Rimuru",
        Callback    = function()
            local amount = tonumber(State.summonSlimeAmount)
            if not amount or amount <= 0 then
                Fluent:Notify({ Title = "Summon Rimuru", Content = "Enter a valid amount first", Duration = 3 })
                return
            end
            pcall(function()
                    local args = {
                            "SummonSlime",
                            {
                                Amount = amount
                            }
                        }
                        game:GetService("ReplicatedStorage")
                        :WaitForChild("Packages")
                        :WaitForChild("_Index")
                        :WaitForChild("sleitnick_net@0.2.0")
                        :WaitForChild("net")
                        :WaitForChild("RE/SummonerEvent")
                        :FireServer(unpack(args))

            end)
            Fluent:Notify({ Title = "Summon Rimuru", Content = "Summoned " .. amount .. " Rimuru", Duration = 3 })
        end,
    })

    -- ── Summon Boss ───────────────────────────────────────────
    Tabs.Summon:AddParagraph({
        Title   = "Summon Boss",
        Content = "Choose a boss and summon instantly, or enable Auto to continuously summon and attack.\nBossSummoner: Verdant Hero, Saber  •  JJKBossSummoner: Sukuna, Gojo",
    })

    local SUMMON_BOSS_LIST = {"Verdant Hero", "Saber", "Sukuna", "Gojo"}

    local SummonBossDrop = Tabs.Summon:AddDropdown("SummonBossDropdown", {
        Title   = "Select Summon Boss",
        Values  = SUMMON_BOSS_LIST,
        Multi   = false,
        Default = indexOf(SUMMON_BOSS_LIST, State.selectedSummonBoss),
    })
    SummonBossDrop:OnChanged(function(v)
        State.selectedSummonBoss = v
        saveState(State)
    end)

    Tabs.Summon:AddButton({
        Title       = "✦ Summon Boss",
        Description = "Summon the selected boss once immediately",
        Callback    = function()
            local bossName = State.selectedSummonBoss
            pcall(function()
                SUMMON_RE_PATH()
                    :WaitForChild("RE/SummonEvent")
                    :FireServer("Summon", { Boss = bossName })
            end)
            Fluent:Notify({ Title = "Summon Boss", Content = "Summoned: " .. bossName, Duration = 3 })
        end,
    })

    local AutoSummonBossToggle = Tabs.Summon:AddToggle("AutoSummonBoss", {
        Title       = "Auto Summon Boss",
        Description = "Continuously summon and attack the selected boss. Yields to ServerTimeBoss if one is active.",
        Default     = State.autoSummonBoss,
    })
    AutoSummonBossToggle:OnChanged(function(val)
        State.autoSummonBoss = val
        if State.autoSummonBoss then
            setFly(true)
        else
            if not State.autoMob and not State.autoBoss and not State.autoOre then
                setFly(false)
            end
        end
        saveState(State)
    end)
end

-- ╔══════════════════════════════════════════════════════════╗
--  TAB: DUNGEON
-- ╚══════════════════════════════════════════════════════════╝
do
    local DUNGEON_KEYS       = {"RAIDEN", "SHADOW", "ARTIFACT_01", "ARTIFACT_02", "ARTIFACT_03"}
    local keysname = {
        RAIDEN = "Shrine Key",
        SHADOW = "Cid's Key",
        ARTIFACT_01 = "Trial's Key",
        ARTIFACT_02 = "Trial's Key",
        ARTIFACT_03 = "Trial's Key",
    }
    local DUNGEON_DIFFICULTY = {"Easy", "Medium", "Hard", "Extreme"}

    Tabs.Dungeon:AddParagraph({
        Title   = "Dungeon Room",
        Content = "Select a Portal Key and Difficulty, then press Create Room to open a dungeon portal.\nEnable Auto Dungeon to automatically farm all enemies that spawn inside.",
    })

    local DungeonKeyDrop = Tabs.Dungeon:AddDropdown("DungeonKeyDropdown", {
        Title       = "Select Portal Key",
        Description = "The key (portal type) used to create the dungeon room",
        Values      = DUNGEON_KEYS,
        Multi       = false,
        Default     = indexOf(DUNGEON_KEYS, State.selectedDungeonKey),
    })
    DungeonKeyDrop:OnChanged(function(v)
        State.selectedDungeonKey = v
        saveState(State)
    end)

    local DungeonDiffDrop = Tabs.Dungeon:AddDropdown("DungeonDiffDropdown", {
        Title       = "Select Difficulty",
        Description = "Dungeon difficulty level — affects mob strength and rewards",
        Values      = DUNGEON_DIFFICULTY,
        Multi       = false,
        Default     = indexOf(DUNGEON_DIFFICULTY, State.selectedDungeonDifficulty),
    })
    DungeonDiffDrop:OnChanged(function(v)
        State.selectedDungeonDifficulty = v
        saveState(State)
    end)

    Tabs.Dungeon:AddButton({
        Title       = "⚔ Create Room",
        Description = "Opens a dungeon portal with the selected key and difficulty",
        Callback    = function()
            local keys       = State.selectedDungeonKey
            local difficulty = State.selectedDungeonDifficulty
            pcall(function()
                local args = {
                    "Use",
                    {
                        Item = keysname[keys],
                        Amount = 1
                    }
                }
                    game:GetService("ReplicatedStorage")
                    :WaitForChild("Packages")
                    :WaitForChild("_Index")
                    :WaitForChild("sleitnick_net@0.2.0")
                    :WaitForChild("net")
                    :WaitForChild("RE/MaterialEvent")
                    :FireServer(unpack(args))

                task.wait(0.5)

                local args = {
                    "Select",
                    {
                        Difficulty = difficulty,
                        Portal     = keys,
                        FriendOnly = false,
                    }
                }
                game:GetService("ReplicatedStorage")
                    :WaitForChild("Packages")
                    :WaitForChild("_Index")
                    :WaitForChild("sleitnick_net@0.2.0")
                    :WaitForChild("net")
                    :WaitForChild("RE/PortalEvent")
                    :FireServer(unpack(args))
            end)
            Fluent:Notify({
                Title    = "Dungeon",
                Content  = "Room created — " .. keys .. " | " .. difficulty,
                Duration = 4,
            })
        end,
    })

    local AutoDungeonToggle = Tabs.Dungeon:AddToggle("AutoDungeon", {
        Title       = "Auto Dungeon",
        Description = "Automatically teleport to and attack any mob that appears in workspace.Enemies. No mob selection needed — works inside dungeon rooms.",
        Default     = State.autoDungeon,
    })
    AutoDungeonToggle:OnChanged(function(val)
        State.autoDungeon = val
        if State.autoDungeon then
            setFly(true)
        else
            if not State.autoMob and not State.autoBoss
            and not State.autoOre and not State.autoSummonBoss then
                setFly(false)
            end
        end
        saveState(State)
        Fluent:Notify({
            Title   = "Auto Dungeon",
            Content = State.autoDungeon and "ON — attacking all enemies" or "OFF",
            Duration = 2,
        })
    end)


    local AutoStartReplayToggle = Tabs.Dungeon:AddToggle("AutoStartReplay", {
        Title       = "Auto Start & Replay",
        Description = "Automatically clicks Start whenever the dungeon start screen appears. Works for both first start and replay after a run ends.",
        Default     = State.autoStartReplay,
    })
    AutoStartReplayToggle:OnChanged(function(val)
        State.autoStartReplay = val
        saveState(State)
        Fluent:Notify({
            Title   = "Auto Start & Replay",
            Content = State.autoStartReplay and "ON — will auto-click Start" or "OFF",
            Duration = 2,
        })
    end)
end

-- ╔══════════════════════════════════════════════════════════╗
--  TAB: TELEPORT
-- ╚══════════════════════════════════════════════════════════╝
do
    Tabs.Teleport:AddParagraph({
        Title   = "Island Teleport",
        Content = "Pick an island → press the button to teleport.",
    })

    local selectedIsland = ""

    local IslandDrop = Tabs.Teleport:AddDropdown("IslandDropdown", {
        Title   = "Select Island",
        Values  = getIslandList(),
        Multi   = false,
        Default = 1,
    })

    IslandDrop:OnChanged(function(value)
        if value == "None" then return end
        selectedIsland = value
    end)

    Tabs.Teleport:AddButton({
        Title       = "Teleport to Island",
        Description = "Press to teleport to the selected island",
        Callback    = function()
            if selectedIsland == "" then
                Fluent:Notify({ Title = "Teleport", Content = "Select an island first", Duration = 3 })
                return
            end
            pcall(function()
                local fi     = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Island")
                local island = fi and fi:FindFirstChild(selectedIsland)
                if not island then
                    Fluent:Notify({ Title = "Teleport", Content = "Not found: " .. selectedIsland, Duration = 3 })
                    return
                end
                local part = findLandPart(island)
                if part then
                    teleportTo(part.Position + Vector3.new(0, 5, 0))
                    Fluent:Notify({ Title = "Teleport", Content = "→ Island: " .. selectedIsland, Duration = 3 })
                else
                    Fluent:Notify({ Title = "Teleport", Content = "No BasePart in: " .. selectedIsland, Duration = 3 })
                end
            end)
        end,
    })


    Tabs.Teleport:AddParagraph({
        Title   = "Questline Teleport",
        Content = "Pick a questline → pick a stage → press the button below to teleport.",
    })

    local selectedQuestline = ""
    local selectedQlStage   = ""   -- [FIX 4] track stage separately

    local SelectQlDrop = Tabs.Teleport:AddDropdown("SelectQuestline", {
        Title       = "Select Questline",
        Description = "workspace.Questline",
        Values      = getQuestlineList(),
        Multi       = false,
        Default     = 1,
    })

    local ChildQlDrop = Tabs.Teleport:AddDropdown("QuestlineChild", {
        Title       = "Select Stage",
        Description = "Populated after selecting a questline",
        Values      = {"— select questline first —"},
        Multi       = false,
        Default     = 1,
    })

    SelectQlDrop:OnChanged(function(value)
        if value == "None" then return end
        selectedQuestline = value
        selectedQlStage   = ""     -- reset stage when questline changes
        local children = getQuestlineChildren(value)
        ChildQlDrop:SetValues(children)
        ChildQlDrop:SetValue(children[1])
    end)

    ChildQlDrop:OnChanged(function(value)
        if value == "None" or value == "— select questline first —" then return end
        selectedQlStage = value
    end)

    Tabs.Teleport:AddButton({
        Title       = "Teleport to Stage",
        Description = "Press to teleport to the selected questline stage",
        Callback    = function()
            if selectedQuestline == "" then
                Fluent:Notify({ Title = "Teleport", Content = "Select a questline first", Duration = 3 })
                return
            end
            if selectedQlStage == "" then
                Fluent:Notify({ Title = "Teleport", Content = "Select a stage first", Duration = 3 })
                return
            end
            pcall(function()
                local qf    = workspace:FindFirstChild("Questline")
                local ql    = qf and qf:FindFirstChild(selectedQuestline)
                local stage = ql and ql:FindFirstChild(selectedQlStage)
                if not stage then
                    Fluent:Notify({ Title = "Teleport", Content = "Stage not found: " .. selectedQlStage, Duration = 3 })
                    return
                end
                local part = findLandPart(stage)
                if part then
                    teleportTo(part.Position + Vector3.new(0, 5, 0))
                    Fluent:Notify({ Title = "Teleport", Content = "→ " .. selectedQuestline .. " › " .. selectedQlStage, Duration = 3 })
                else
                    Fluent:Notify({ Title = "Teleport", Content = "No BasePart in: " .. selectedQlStage, Duration = 3 })
                end
            end)
        end,
    })

    -- ╔══════════════════════════════════════════════════════╗
    --  NPC Teleport
    -- ╚══════════════════════════════════════════════════════╝
    Tabs.Teleport:AddParagraph({
        Title   = "NPC Teleport",
        Content = "Pick an NPC → press the button to teleport.\nSource: workspace.NPC (auto-detected)",
    })

    local selectedNPC      = ""
    local selectedNPCSub   = ""  -- ใช้เมื่อ NPC มี sub-children (nested)
    local npcIsNested      = false

    local npcList = getNPCList()

    local NPCDrop = Tabs.Teleport:AddDropdown("NPCDropdown", {
        Title       = "Select NPC",
        Description = "workspace.NPC",
        Values      = npcList,
        Multi       = false,
        Default     = 1,
    })

    local NPCSubDrop = Tabs.Teleport:AddDropdown("NPCSubDropdown", {
        Title       = "Select NPC (Sub)",
        Description = "Populated if NPC has sub-children",
        Values      = {"— no sub-children —"},
        Multi       = false,
        Default     = 1,
    })

    NPCDrop:OnChanged(function(value)
        if value == "None" then return end
        selectedNPC    = value
        selectedNPCSub = ""

        -- ตรวจว่า NPC นี้มี sub-children ไหม
        local subs = getNPCChildren(value)
        if subs then
            npcIsNested = true
            NPCSubDrop:SetValues(subs)
            NPCSubDrop:SetValue(subs[1])
        else
            npcIsNested = false
            NPCSubDrop:SetValues({"— no sub-children —"})
            NPCSubDrop:SetValue("— no sub-children —")
        end
    end)

    NPCSubDrop:OnChanged(function(value)
        if value == "None" or value == "— no sub-children —" then return end
        selectedNPCSub = value
    end)

    Tabs.Teleport:AddButton({
        Title       = "Refresh NPC",
        Description = "Reload NPC list from workspace",
        Callback    = function()
            local new = getNPCList()
            NPCDrop:SetValues(new)
            NPCDrop:SetValue(new[1])
            selectedNPC    = ""
            selectedNPCSub = ""
            npcIsNested    = false
            NPCSubDrop:SetValues({"— no sub-children —"})
            NPCSubDrop:SetValue("— no sub-children —")
            Fluent:Notify({ Title = "NPC", Content = "Refreshed — " .. #new .. " found", Duration = 3 })
        end,
    })

    Tabs.Teleport:AddButton({
        Title       = "Teleport to NPC",
        Description = "Press to teleport to the selected NPC",
        Callback    = function()
            if selectedNPC == "" then
                Fluent:Notify({ Title = "Teleport", Content = "Select an NPC first", Duration = 3 })
                return
            end
            if npcIsNested and selectedNPCSub == "" then
                Fluent:Notify({ Title = "Teleport", Content = "Select a sub-NPC first", Duration = 3 })
                return
            end
            pcall(function()
                local f   = getNPCFolder()
                if not f then
                    Fluent:Notify({ Title = "Teleport", Content = "NPC folder not found in workspace", Duration = 3 })
                    return
                end

                local target
                if npcIsNested then
                    local group = f:FindFirstChild(selectedNPC)
                    target = group and group:FindFirstChild(selectedNPCSub)
                else
                    target = f:FindFirstChild(selectedNPC)
                end

                if not target then
                    local label = npcIsNested and (selectedNPC .. " › " .. selectedNPCSub) or selectedNPC
                    Fluent:Notify({ Title = "Teleport", Content = "Not found: " .. label, Duration = 3 })
                    return
                end

                local part = findLandPart(target)
                if part then
                    teleportTo(part.Position + Vector3.new(0, 5, 0))
                    local label = npcIsNested and (selectedNPC .. " › " .. selectedNPCSub) or selectedNPC
                    Fluent:Notify({ Title = "Teleport", Content = "→ NPC: " .. label, Duration = 3 })
                else
                    Fluent:Notify({ Title = "Teleport", Content = "No BasePart in NPC: " .. selectedNPC, Duration = 3 })
                end
            end)
        end,
    })
end

-- ╔══════════════════════════════════════════════════════════╗
--  INPUT SIMULATION
-- ╚══════════════════════════════════════════════════════════╝

-- ╔══════════════════════════════════════════════════════════╗
--  REMOTE CACHE — WaitForChild ครั้งเดียว ไม่ block ทุก call
-- ╚══════════════════════════════════════════════════════════╝
local _skillRemote  = nil
local _actionRemote = nil

local function _getNet()
    return game:GetService("ReplicatedStorage")
        :WaitForChild("Packages",            10)
        :WaitForChild("_Index",              10)
        :WaitForChild("sleitnick_net@0.2.0", 10)
        :WaitForChild("net",                 10)
end

local function getSkillRemote()
    if _skillRemote then return _skillRemote end
    local ok, r = pcall(function() return _getNet():WaitForChild("RE/SkillRemote",  10) end)
    if ok and r then _skillRemote = r end
    return _skillRemote
end

local function getActionRemote()
    if _actionRemote then return _actionRemote end
    local ok, r = pcall(function() return _getNet():WaitForChild("RE/ActionRemote", 10) end)
    if ok and r then _actionRemote = r end
    return _actionRemote
end

-- FIX: ถ้า selectedWeapon เป็น "None" → ใช้ tool ที่ equipped อยู่จริงๆ แทน
local function getActiveWeapon()
    local name = State.selectedWeapon
    if name and name ~= "None" and name ~= "" then return name end
    local char = getChar()
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then return tool.Name end
    end
    return nil
end

local function fireSkillRemote(skill)
    pcall(function()
        local remote = getSkillRemote()
        if not remote then return end
        local weapon = getActiveWeapon()
        if not weapon then return end
        remote:FireServer(weapon, string.upper(skill))
    end)
end

local function pressM1()
    pcall(function()
        local remote = getActionRemote()
        if not remote then return end
        local weapon = getActiveWeapon()
        if not weapon then return end
        remote:FireServer("M1", weapon)
    end)
end


-- รวบรวม connections ทั้งหมดไว้ใน _G เพื่อให้ Unload ตัดได้ (ต้อง init ก่อน farming loop)
_G.__NobodyHubConnections = {}

-- ╔══════════════════════════════════════════════════════════╗
--  FARMING LOOP
-- ╚══════════════════════════════════════════════════════════╝
do
    local RunService   = game:GetService("RunService")
    local ATTACK_WAIT  = 0.4   -- เร็วขึ้นนิดหน่อย
    local SKILL_WAIT   = 0.35  -- FIX: ลดลงจาก 1s → skill fire บ่อยขึ้น
    local lastSkillAt  = 0

    -- currentTarget แชร์ระหว่าง farming loop กับ Heartbeat
    local currentTarget = nil
    -- lastFloatPos: จำตำแหน่ง float ล่าสุด — ค้างไว้เมื่อ mob ตาย
    local lastFloatPos  = nil

    local function fireSkills()
        if #State.selectedSkills == 0 then return end
        task.spawn(function()
            for _, sk in ipairs(State.selectedSkills) do
                fireSkillRemote(sk)
                task.wait(0.15)  -- ลดจาก 0.25 → รวดเร็วขึ้น
            end
        end)
    end

    -- FIX LAG: Heartbeat วิ่ง ~60fps → throttle ให้เหลือ ~20fps
    -- การ set CFrame ทุก frame เป็นสาเหตุหลักของ lag
    local _lastHbTime = 0
    local _cachedTRoot = nil   -- cache tRoot ไว้ไม่ต้อง FindFirstChild ทุก frame

    local _hbConn = RunService.Heartbeat:Connect(function()
        -- throttle: ทำงานแค่ทุก 0.05s (~20fps) แทน 60fps
        local now = tick()
        if now - _lastHbTime < 0.05 then return end
        _lastHbTime = now

        if not (State.autoMob or State.autoBoss or State.autoSummonBoss
                or State.autoOre or State.autoDungeon) then
            currentTarget = nil
            lastFloatPos  = nil
            _cachedTRoot  = nil
            return
        end

        local root = getRoot()
        if not root then return end

        -- รีเฟรช tRoot cache เมื่อ target เปลี่ยน หรือทุก ~0.5s
        if currentTarget and (not _cachedTRoot or _cachedTRoot.Parent == nil) then
            _cachedTRoot = modelRoot(currentTarget)
        elseif not currentTarget then
            _cachedTRoot = nil
        end

        local isFloatMode = (State.method == "above" or State.method == "under")

        if isFloatMode then
            if currentTarget and _cachedTRoot then
                if isTargetAlive(currentTarget) then
                    lastFloatPos = standPos(_cachedTRoot.CFrame)
                    root.CFrame  = CFrame.new(lastFloatPos, _cachedTRoot.Position)
                else
                    currentTarget = nil
                    _cachedTRoot  = nil
                    if lastFloatPos then
                        root.CFrame = CFrame.new(lastFloatPos, lastFloatPos + root.CFrame.LookVector)
                    end
                end
            elseif lastFloatPos then
                root.CFrame = CFrame.new(lastFloatPos, lastFloatPos + root.CFrame.LookVector)
            end
        else
            if not currentTarget or not _cachedTRoot then return end
            if not isTargetAlive(currentTarget) then
                currentTarget = nil
                _cachedTRoot  = nil
                return
            end
            local myPos  = root.Position
            local mobPos = _cachedTRoot.Position
            root.CFrame = CFrame.lookAt(myPos, Vector3.new(mobPos.X, myPos.Y, mobPos.Z))
        end
    end)

    -- เก็บ connection ไว้ให้ Unload ตัดได้
    if _G.__NobodyHubConnections then
        table.insert(_G.__NobodyHubConnections, _hbConn)
    end

    -- farming loop ใช้ State flag ในการหยุด ไม่ต้องตัด task.spawn
    -- (while loop จะหยุดเองเมื่อ State.autoMob/autoBoss = false)
    task.spawn(function()
        while true do
            task.wait(ATTACK_WAIT)

            if not State.autoMob and not State.autoBoss and not State.autoDungeon then
                currentTarget = nil
                continue
            end            if not isAlive() then continue end
            local root = getRoot(); if not root then continue end

            -- Auto Equip Weapon
            equipWeapon()

            -- หา target: Boss priority สูงสุด → Mob ต่ำสุด
            local target = nil

            if State.autoBoss and #State.selectedBoss > 0 then
                for _, bossName in ipairs(State.selectedBoss) do
                    local t = findBossTarget(bossName)
                    if t then target = t; break end
                end
            end

            -- Mob: ทำงานเฉพาะเมื่อไม่มี boss/ore/summonboss ที่พร้อม
            if not target
            and State.autoMob
            and State.selectedMob ~= "None"
            and State.selectedMob ~= "" then
                -- ยิลด์ให้ SummonBoss และ Ore ก่อน
                local sbReady = State.autoSummonBoss and findSummonBoss(State.selectedSummonBoss)
                local oreReady = State.autoOre and findOreTarget()
                if not sbReady and not oreReady then
                    target = findMobTarget(State.selectedMob)
                end
            end

            if not target then
                currentTarget = nil
                continue
            end

            -- อัปเดต currentTarget ให้ Heartbeat loop ใช้
            currentTarget = target

            local tRoot = modelRoot(target)
            if not tRoot then continue end

            -- Bring Mob
            if State.bringMob then
                pcall(function()
                    pcall(function() tRoot:SetNetworkOwner(LocalPlayer) end)
                    tRoot.CFrame = CFrame.new(root.Position + Vector3.new(0, 0, 3))
                end)
            end

            -- Teleport ไปยัง stand position
            -- (Heartbeat จะ maintain position ต่อเนื่องระหว่าง tick สำหรับ above/under)
            teleportTo(standPos(tRoot.CFrame))
            task.wait(0.1)

            -- [FIX SYNC] ตรวจ State.autoAttack ทุกครั้งก่อน pressM1
            -- State.autoAttack ถูก set โดย OnChanged(val) โดยตรง — ไม่มี delay
            if State.autoAttack then
                pressM1()
            end

            if State.autoSkill then
                local now = tick()
                if now - lastSkillAt >= SKILL_WAIT then
                    lastSkillAt = now
                    fireSkills()
                end
            end
        end
    end)

    -- ╔════════════════════════════════════════════════════╗
    --  Auto Summon Boss
    -- ╚════════════════════════════════════════════════════╝
    task.spawn(function()
        local SUMMON_WAIT   = 0.5   -- poll rate
        local AFTER_SUMMON  = 2.5   -- รอ server spawn boss
        local lastSummonAt  = 0

        while true do
            task.wait(SUMMON_WAIT)
            if not State.autoSummonBoss then continue end
            if not isAlive() then continue end

            -- Priority: ยิลด์ให้ ServerTimeBossSpawner เท่านั้น (ทั้งคู่อยู่ระดับ Boss)
            if State.autoBoss and #State.selectedBoss > 0 then
                local found = false
                for _, n in ipairs(State.selectedBoss) do
                    if findBossTarget(n) then found = true; break end
                end
                if found then continue end
            end

            local bossName = State.selectedSummonBoss
            local boss     = findSummonBoss(bossName)

            if not boss then
                -- summon ได้ทุก 3 วิเพื่อไม่ spam server
                local now = tick()
                if now - lastSummonAt >= 3 then
                    lastSummonAt = now
                    pcall(function()
                        _getNet():WaitForChild("RE/SummonEvent", 10)
                            :FireServer("Summon", { Boss = bossName })
                    end)
                end
                task.wait(AFTER_SUMMON)
                continue
            end

            -- Boss spawn แล้ว — ส่ง currentTarget ให้ Heartbeat lock ตำแหน่ง
            currentTarget = boss

            local tRoot = modelRoot(boss)
            if not tRoot then continue end

            -- Equip weapon + teleport
            equipWeapon()
            teleportTo(standPos(tRoot.CFrame))
            task.wait(0.1)

            -- Attack
            if State.autoAttack then
                pressM1()
            end

            -- Skill
            if State.autoSkill then
                local now = tick()
                if now - lastSkillAt >= SKILL_WAIT then
                    lastSkillAt = now
                    fireSkills()
                end
            end
        end
    end)

    -- ╔════════════════════════════════════════════════════╗
    --  Auto Ore loop
    -- ╚════════════════════════════════════════════════════╝
    task.spawn(function()
        while true do
            task.wait(ATTACK_WAIT)
            if not State.autoOre then continue end
            if not isAlive() then continue end

            -- Priority: ยิลด์ให้ ServerTimeBoss
            if State.autoBoss and #State.selectedBoss > 0 then
                local found = false
                for _, n in ipairs(State.selectedBoss) do
                    if findBossTarget(n) then found = true; break end
                end
                if found then continue end
            end

            -- Priority: ยิลด์ให้ SummonBoss
            if State.autoSummonBoss
            and findSummonBoss(State.selectedSummonBoss) then
                continue
            end

            local ore = findOreTarget()
            if not ore then
                currentTarget = nil
                task.wait(1)  -- รอ ore respawn
                continue
            end

            currentTarget = ore
            local tRoot   = modelRoot(ore)
            if not tRoot then continue end

            equipWeapon()
            teleportTo(standPos(tRoot.CFrame))
            task.wait(0.1)

            if State.autoAttack then pressM1() end

            if State.autoSkill then
                local now = tick()
                if now - lastSkillAt >= SKILL_WAIT then
                    lastSkillAt = now
                    fireSkills()
                end
            end
        end
    end)

    -- ╔════════════════════════════════════════════════════╗
    --  Auto Dungeon loop
    --  Attacks every alive mob in workspace.Enemies (no filter)
    -- ╚════════════════════════════════════════════════════╝
    task.spawn(function()
        while true do
            task.wait(ATTACK_WAIT)
            if not State.autoDungeon then continue end
            if not isAlive() then continue end

            -- Yield for ServerTimeBoss if active
            if State.autoBoss and #State.selectedBoss > 0 then
                local found = false
                for _, n in ipairs(State.selectedBoss) do
                    if findBossTarget(n) then found = true; break end
                end
                if found then continue end
            end

            local mob = findAnyMobTarget()
            if not mob then
                currentTarget = nil
                task.wait(0.5)
                continue
            end

            currentTarget = mob
            local tRoot = modelRoot(mob)
            if not tRoot then continue end

            equipWeapon()
            teleportTo(standPos(tRoot.CFrame))
            task.wait(0.1)

            if State.autoAttack then pressM1() end

            if State.autoSkill then
                local now = tick()
                if now - lastSkillAt >= SKILL_WAIT then
                    lastSkillAt = now
                    fireSkills()
                end
            end
        end
    end)

    -- ╔════════════════════════════════════════════════════╗
    --  Auto Start & Replay loop
    --  Watches PortalGui.StartCanvas.Visible and fires "Start"
    -- ╚════════════════════════════════════════════════════╝
    task.spawn(function()
        local POLL_WAIT = 0.3
        while true do
            task.wait(POLL_WAIT)
            if not State.autoStartReplay then continue end

            pcall(function()
                local portalGui = LocalPlayer.PlayerGui:FindFirstChild("PortalGui")
                if not portalGui then return end
                local startCanvas = portalGui:FindFirstChild("StartCanvas")
                if not startCanvas or not startCanvas.Visible then return end

                -- StartCanvas is visible — fire Start
                _getNet():WaitForChild("RE/PortalEvent", 10):FireServer("Start")

                task.wait(1)  -- short cooldown to avoid double-firing
            end)
        end
    end)

    local _charConn = LocalPlayer.CharacterAdded:Connect(function(char)
        char:WaitForChild("HumanoidRootPart", 10)
        currentTarget = nil  -- reset เมื่อ respawn
        _flyActive = false   -- reset flag เพื่อให้ setFly เปิดใหม่ได้หลัง respawn
        -- ถ้า auto mob/boss ยังเปิดอยู่ → เปิด fly ใหม่หลัง character โหลดเสร็จ
        if State.autoMob or State.autoBoss or State.autoSummonBoss
        or State.autoOre or State.autoDungeon then
            task.delay(1, function() setFly(true) end)
        end
    end)
    if _G.__NobodyHubConnections then
        table.insert(_G.__NobodyHubConnections, _charConn)
    end
end

-- ╔══════════════════════════════════════════════════════════╗
--  UNLOAD SYSTEM
-- ╚══════════════════════════════════════════════════════════╝
_G.__NobodyHubUnload = function()
    -- 0) ปิด fly ก่อน — ป้องกันกระเด้งหลัง unload
    pcall(function() setFly(false) end)

    -- 1) ปิด flag ทุกตัว → farming/heartbeat loop จะ return ทันทีในรอบถัดไป
    State.autoMob           = false
    State.autoBoss          = false
    State.autoAttack        = false
    State.autoSkill         = false
    State.autoSummonBoss    = false
    State.autoOre           = false
    State.autoDungeon       = false
    State.autoStartReplay   = false

    -- 2) ตัด RunService connections ที่ผูกไว้
    if _G.__NobodyHubConnections then
        for _, conn in ipairs(_G.__NobodyHubConnections) do
            pcall(function() conn:Disconnect() end)
        end
        _G.__NobodyHubConnections = nil
    end

    -- 3) Destroy UI — ลอง method ต่างๆ ของ Fluent + scan CoreGui ทั้งหมด
    pcall(function()
        -- Fluent window (ลองทุก property ที่เป็นไปได้)
        if Window then
            pcall(function() Window:Destroy() end)
            pcall(function() Window.Gui:Destroy() end)
            pcall(function() Window.gui:Destroy() end)
        end
        -- Scan CoreGui หา ScreenGui ของ Fluent ที่เหลืออยู่
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
    pcall(function()
        -- ปุ่ม toggle ของเรา
        local gui = game:GetService("CoreGui"):FindFirstChild("FluentToggleButtonGui")
        if gui then gui:Destroy() end
    end)

    -- 4) ล้าง _G เพื่อให้ load ซ้ำได้สะอาด
    _G.__NobodyHubUnload      = nil
    _G.__NobodyHubConnections = nil

    print("[NobodyHub] Unloaded — script หยุดทำงานทั้งหมดแล้ว")
end

-- ╔══════════════════════════════════════════════════════════╗
--  TAB: STATS
-- ╚══════════════════════════════════════════════════════════╝
do
    -- ── Boss Spawn Timer ─────────────────────────────────────
    -- อ่าน TimerGui.BossName.Text และ TimerGui.Timer.Text
    local function getTimerGui()
        local bossFolder = workspace:FindFirstChild("Boss")
        local spawner    = bossFolder and bossFolder:FindFirstChild("ServerTimeBossSpawner")
        return spawner and spawner:FindFirstChild("TimerGui")
    end

local function readGuiText(parent, childName)
        local node = parent and parent:FindFirstChild(childName)
        if not node then return "—" end

        if node:IsA("TextLabel") then
            return (node.Text ~= "") and node.Text or "—"
        end

        local lbl = node:FindFirstChild("Text") 
                 or node:FindFirstChild("text") 
                 or node:FindFirstChildWhichIsA("TextLabel", true)
                 
        if lbl and lbl:IsA("TextLabel") then
            return (lbl.Text ~= "") and lbl.Text or "—"
        end

        return "—"
    end

    local TimerLabel = Tabs.Stats:AddParagraph({
        Title   = "⏱ Boss Spawn Timer",
        Content = "Loading...",
    })

    -- ── Boss Status — paragraph เดียว อัปเดต realtime ──────
    local StatusLabel = Tabs.Stats:AddParagraph({
        Title   = "👾 Boss Status",
        Content = "Loading...",
    })

    -- ── Helper: เช็ค Stone (มี ore อยู่ใน Stone1 ไหม) ──────
    local function checkStone()
        local stone1 = workspace:FindFirstChild("Boss")
                       and workspace.Boss:FindFirstChild("Stone1")
        return stone1 ~= nil and next(stone1:GetChildren()) ~= nil
    end

    -- ── Realtime Poll via Heartbeat (ทุก ~1 วินาที) ────────────
    local _lastStatTick = 0
    local _statConn = game:GetService("RunService").Heartbeat:Connect(function()
        local now = tick()
        if now - _lastStatTick < 1 then return end
        _lastStatTick = now

        
            -- ── Timer section ──────────────────────────
            local gui       = getTimerGui()
            local bossName  = gui and readGuiText(gui, "BossName") or "—"
            local timerText = gui and readGuiText(gui, "Timer")    or "—"

            local timerIcon = "👾"
            local bl = bossName:lower()
            if bl:find("rimuru")                         then timerIcon = "🟢" end
            if bl:find("sung") or bl:find("jinwoo")     then timerIcon = "⚔️" end

            TimerLabel:SetTitle("⏱ Boss Spawn Timer")
            TimerLabel:SetDesc(timerIcon .. " " .. bossName .. "   🕐 " .. timerText)

            -- ── Status checklist ─────────────────────
            local function ic(alive) return alive and "✅" or "❌" end

            local lines = {
                ic(findDirectBoss("Aizen"))        .. "  Aizen",
                ic(findSpawnerBoss("Rimuru"))      .. "  Rimuru",
                ic(findSpawnerBoss("Sung Jinwoo")) .. "  Sung Jinwoo",
                ic(findSummonBoss("Verdant Hero")) .. "  Verdant Hero",
                ic(findSummonBoss("Saber"))        .. "  Saber",
                ic(findSummonBoss("Sukuna"))       .. "  Sukuna",
                ic(findSummonBoss("Gojo"))         .. "  Gojo",
                ic(checkStone())                   .. "  Stone",
            }

            StatusLabel:SetTitle("👾 Boss Status")
            StatusLabel:SetDesc(table.concat(lines, "\n"))
            
    end)
    if _G.__NobodyHubConnections then
        table.insert(_G.__NobodyHubConnections, _statConn)
    end
end

-- ╔══════════════════════════════════════════════════════════╗
--  FINALIZE
-- ╚══════════════════════════════════════════════════════════╝
InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder(GAME_FOLDER)
InterfaceManager:BuildInterfaceSection(Tabs.Settings)

Window:SelectTab(1)

Fluent:Notify({
    Title   = "Nobody " .. Fluent.Version,
    Content = "v4 loaded  •  Save: " .. GAME_FOLDER,
    Duration = 5,
})