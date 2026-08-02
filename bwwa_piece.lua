if not game:IsLoaded() then game.Loaded:Wait() end

-- Destroy previous UI & clean up running loops when re-executing
if getgenv and getgenv().BWWA_PIECE_CLEANUP then
    pcall(getgenv().BWWA_PIECE_CLEANUP)
end

-- ── Services ──────────────────────────────────────────────────────────────────
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local VirtualUser        = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

-- ── Game info ─────────────────────────────────────────────────────────────────
local success, gameInfo = pcall(function()
    return MarketplaceService:GetProductInfo(game.PlaceId)
end)
if not success then gameInfo = { Name = tostring(game.PlaceId) } end

-- ── Fluent + Addons ───────────────────────────────────────────────────────────
local Fluent           = loadstring(game:HttpGet("https://raw.githubusercontent.com/Apichaid0nt/Fluent/83a8a91ceb86a8c6988e10da90303aee3cd5fc03/dist/main.lua"))()
local SaveManager      = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- ── Constants ─────────────────────────────────────────────────────────────────
local GAME_FOLDER  = "NobodyHub/" .. game.GameId
local AUTOSAVE_KEY = "autosave"

-- ── Auto-Save (debounced) ─────────────────────────────────────────────────────
local saveDebounce = false
local function AutoSave()
    if saveDebounce then return end
    saveDebounce = true
    task.delay(1, function()
        pcall(function() SaveManager:Save(AUTOSAVE_KEY) end)
        saveDebounce = false
    end)
end

local function Track(element)
    element:OnChanged(function() AutoSave() end)
    return element
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── GAME REFERENCES ───────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local Remotes            = ReplicatedStorage:WaitForChild("Remotes", 10)
local RemoteEvents       = Remotes:WaitForChild("RemoteEvents", 10)
local RemoteFunctions    = Remotes:WaitForChild("RemoteFunctions", 10)
local SkillsFolder       = RemoteEvents:WaitForChild("Skills", 10)
local MoveRemote         = SkillsFolder:WaitForChild("Move", 10)
local OpenChestRemote    = RemoteEvents:WaitForChild("OpenChest", 10)
local ArtifactRemoteFunc = RemoteFunctions:WaitForChild("ArtifactAction", 10)

-- Knit Haki RemoteFunctions
local Packages           = ReplicatedStorage:WaitForChild("Packages", 10)
local Knit               = Packages and Packages:WaitForChild("Knit", 10)
local Services           = Knit and Knit:WaitForChild("Services", 10)

local BusoHakiService    = Services and Services:FindFirstChild("BusoHakiService")
local BusoHakiRF         = BusoHakiService and BusoHakiService:FindFirstChild("RF")
local ToggleBusoHakiRF   = BusoHakiRF and BusoHakiRF:FindFirstChild("ToggleBusoHaki")

local KenHakiService     = Services and Services:FindFirstChild("KenHakiService")
local KenHakiRF          = KenHakiService and KenHakiService:FindFirstChild("RF")
local ToggleKenHakiRF    = KenHakiRF and KenHakiRF:FindFirstChild("ToggleKenHaki")

local SpawnEnemy      = workspace:WaitForChild("SpawnEnemy", 10)
local MapFolder       = workspace:WaitForChild("Map", 10)
local BossSpawnFolder = MapFolder:WaitForChild("Boss Spawn", 10)
local NPCFolder       = MapFolder:FindFirstChild("NPCs")
local IslandsLocation = workspace:FindFirstChild("IslandsLocation")

-- ══════════════════════════════════════════════════════════════════════════════
-- ── CHARACTER TRACKER ─────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local function getCharacter()
    return LocalPlayer.Character
end

local function getRoot()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildWhichIsA("Humanoid")
end

local function getEquippedTool()
    local char = getCharacter()
    if not char then return nil end
    return char:FindFirstChildWhichIsA("Tool")
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── WEAPON SCANNER & AUTO EQUIP ───────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local selectedWeaponName = "Auto (First Available)"
local autoEquipEnabled   = true

local function getAvailableWeapons()
    local names = {"Auto (First Available)"}
    local seen  = {}
    local char  = getCharacter()
    if char then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Tool") and not seen[child.Name] then
                seen[child.Name] = true
                table.insert(names, child.Name)
            end
        end
    end
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, child in ipairs(bp:GetChildren()) do
            if child:IsA("Tool") and not seen[child.Name] then
                seen[child.Name] = true
                table.insert(names, child.Name)
            end
        end
    end
    return names
end

local function autoEquipTool()
    if not autoEquipEnabled then return true end

    local char = getCharacter()
    local hum  = getHumanoid()
    if not char or not hum then return false end

    local equipped = getEquippedTool()

    if selectedWeaponName and selectedWeaponName ~= "Auto (First Available)" then
        if equipped and equipped.Name == selectedWeaponName then
            return true
        end
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            local targetTool = bp:FindFirstChild(selectedWeaponName)
            if targetTool then
                hum:EquipTool(targetTool)
                task.wait(0.1)
                return true
            end
        end
    else
        if equipped then return true end
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            local firstTool = bp:FindFirstChildWhichIsA("Tool")
            if firstTool then
                hum:EquipTool(firstTool)
                task.wait(0.1)
                return true
            end
        end
    end
    return false
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── TARGET RESOLUTION & HEALTH / TIMER CHECKS ────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local selectedMobs   = {} -- mobName  -> true
local selectedBosses = {} -- bossName -> true

local autoMobEnabled  = false
local autoBossEnabled = false

local function getMobHumanoid(mob)
    if not mob then return nil end
    if mob:IsA("Humanoid") then return mob end
    return mob:FindFirstChildWhichIsA("Humanoid", true)
end

-- Check 1: Auto Mob (Skip if CC_ exists or Health <= 0)
local function isMobAlive(mob)
    if not mob or not mob.Parent then return false end

    -- If CC_ child exists inside mob, it means mob is dead/respawning -> SKIP!
    if mob:FindFirstChild("CC_") then
        return false
    end

    local hum = getMobHumanoid(mob)
    if hum then
        return hum.Health > 0
    end

    -- If no Humanoid exists yet and no CC_, spawn part is still valid
    return mob.Parent ~= nil
end

-- Check 2: Auto Boss (Skip if BossTimerBillboard or CC_ exists, MUST have living Humanoid)
local function isBossAlive(boss)
    if not boss or not boss.Parent then return false end

    -- If BossTimerBillboard exists, boss is dead/cooldown timer active -> SKIP!
    if boss:FindFirstChild("BossTimerBillboard") or boss:FindFirstChild("BossTimerBillboard", true) then
        return false
    end

    -- Check CC_ just in case
    if boss:FindFirstChild("CC_") or boss:FindFirstChild("CC_", true) then
        return false
    end

    -- Boss MUST have a living Humanoid (spawned boss model) to be targetable!
    local hum = getMobHumanoid(boss)
    if hum then
        return hum.Health > 0
    end

    -- If no Humanoid spawned yet, boss is not active
    return false
end

local function isTargetAlive(targetObj, isBoss)
    if isBoss then
        return isBossAlive(targetObj)
    else
        return isMobAlive(targetObj)
    end
end

local function getTargetRootPart(targetObj)
    if not targetObj or not targetObj.Parent then return nil, nil end

    -- 1. If targetObj is a Model directly with Humanoid & RootPart
    if targetObj:IsA("Model") then
        local hum = targetObj:FindFirstChildWhichIsA("Humanoid")
        local hrp = targetObj:FindFirstChild("HumanoidRootPart") or targetObj.PrimaryPart or targetObj:FindFirstChildWhichIsA("BasePart")
        if hum and hum.Health > 0 and hrp then
            return hrp, hum
        end
    end

    -- 2. If targetObj has a child Model containing Humanoid & RootPart (spawn part -> living model)
    local childModel = targetObj:FindFirstChildWhichIsA("Model")
    if childModel then
        local hum = childModel:FindFirstChildWhichIsA("Humanoid")
        local hrp = childModel:FindFirstChild("HumanoidRootPart") or childModel.PrimaryPart or childModel:FindFirstChildWhichIsA("BasePart")
        if hum and hum.Health > 0 and hrp then
            return hrp, hum
        end
    end

    -- 3. Direct Humanoid check
    local hum = targetObj:FindFirstChildWhichIsA("Humanoid")
    local hrp = targetObj:FindFirstChild("HumanoidRootPart")
    if hum and hum.Health > 0 and hrp then
        return hrp, hum
    end

    -- 4. Fallback for Mob: If Humanoid is not spawned yet and no CC_, teleport to spawn Part to approach
    if targetObj:IsA("BasePart") then
        return targetObj, nil
    end

    return nil, nil
end

local function getUniqueMobNames()
    local names = {}
    local seen  = {}
    if not SpawnEnemy then return names end
    for _, child in ipairs(SpawnEnemy:GetChildren()) do
        if child:IsA("BasePart") and not seen[child.Name] then
            seen[child.Name] = true
            table.insert(names, child.Name)
        end
    end
    table.sort(names)
    return names
end

local function getUniqueBossNames()
    local names = {}
    local seen  = {}

    -- 1. Standard Boss Spawn folder
    if BossSpawnFolder then
        for _, child in ipairs(BossSpawnFolder:GetChildren()) do
            if not seen[child.Name] and child.Name ~= "Script" then
                seen[child.Name] = true
                table.insert(names, child.Name)
            end
        end
    end

    -- 2. Known special bosses (Dio, Mihawk, Fujitora, Shanks)
    local specialBosses = {
        "Dio Boss",
        "Mihawk Boss",
        "Fujitora Boss",
        "Shanks Boss[Lv. 950]",
    }
    for _, bName in ipairs(specialBosses) do
        if not seen[bName] then
            seen[bName] = true
            table.insert(names, bName)
        end
    end

    -- 3. Scan Workspace directly for any Model containing "Boss"
    for _, child in ipairs(workspace:GetChildren()) do
        if (child:IsA("Model") or child:IsA("BasePart")) and child.Name:find("Boss") then
            if not seen[child.Name] then
                seen[child.Name] = true
                table.insert(names, child.Name)
            end
        end
    end

    table.sort(names)
    return names
end

local function getAllBossFolderChildren()
    local allEntries = {}

    -- 1. Standard Boss Spawn folder
    if BossSpawnFolder then
        for _, child in ipairs(BossSpawnFolder:GetChildren()) do
            if child.Name ~= "Script" then
                table.insert(allEntries, { child = child, customName = nil })
            end
        end
    end

    -- 2. DioSpawnFolder
    local dioFolder = MapFolder:FindFirstChild("DioSpawnFolder")
    if dioFolder then
        for _, child in ipairs(dioFolder:GetChildren()) do
            if child.Name ~= "Script" then
                table.insert(allEntries, { child = child, customName = "Dio Boss" })
            end
        end
    end

    -- 3. MihawkSpawnFolder
    local mihawkFolder = MapFolder:FindFirstChild("MihawkSpawnFolder")
    if mihawkFolder then
        for _, child in ipairs(mihawkFolder:GetChildren()) do
            if child.Name ~= "Script" then
                table.insert(allEntries, { child = child, customName = "Mihawk Boss" })
            end
        end
    end

    return allEntries
end

local function findBossInWorkspace(bossName)
    -- Direct match in Workspace
    local directMatch = workspace:FindFirstChild(bossName)
    if directMatch and isBossAlive(directMatch) then
        return directMatch
    end

    -- Children in Workspace matching bossName
    for _, child in ipairs(workspace:GetChildren()) do
        if (child:IsA("Model") or child:IsA("BasePart")) and (child.Name == bossName or child.Name:find(bossName, 1, true)) then
            if isBossAlive(child) then
                return child
            end
        end
    end

    return nil
end

local function hasSelectedMob()
    for _, isSelected in pairs(selectedMobs) do
        if isSelected then return true end
    end
    return false
end

local function hasSelectedBoss()
    for _, isSelected in pairs(selectedBosses) do
        if isSelected then return true end
    end
    return false
end

local function findNearestBoss()
    local root = getRoot()
    if not root then return nil, math.huge end

    local nearest, nearestDist = nil, math.huge

    -- 1. Check direct Workspace bosses first (e.g. Dio Boss, Fujitora Boss, Shanks Boss[Lv. 950], etc.)
    for bossName, isSelected in pairs(selectedBosses) do
        if isSelected then
            local wsBoss = findBossInWorkspace(bossName)
            if wsBoss and wsBoss.Parent then
                local targetRoot, _ = getTargetRootPart(wsBoss)
                if targetRoot then
                    local dist = (targetRoot.Position - root.Position).Magnitude
                    if dist < nearestDist then
                        nearest     = wsBoss
                        nearestDist = dist
                    end
                end
            end
        end
    end

    if nearest then
        return nearest, nearestDist
    end

    -- 2. Check boss folders in Map
    local entries = getAllBossFolderChildren()
    for _, entry in ipairs(entries) do
        local child      = entry.child
        local customName = entry.customName
        local bossName   = customName or child.Name

        if selectedBosses[bossName] and child.Parent then
            if isBossAlive(child) then
                local targetRoot, _ = getTargetRootPart(child)
                if targetRoot then
                    local dist = (targetRoot.Position - root.Position).Magnitude
                    if dist < nearestDist then
                        nearest     = child
                        nearestDist = dist
                    end
                end
            end
        end
    end
    return nearest, nearestDist
end

local function findNearestMob()
    local root = getRoot()
    if not root or not SpawnEnemy then return nil, math.huge end

    local nearest, nearestDist = nil, math.huge
    for _, child in ipairs(SpawnEnemy:GetChildren()) do
        if child:IsA("BasePart") and selectedMobs[child.Name] and child.Parent then
            if isMobAlive(child) then
                local targetRoot, _ = getTargetRootPart(child)
                if targetRoot then
                    local dist = (targetRoot.Position - root.Position).Magnitude
                    if dist < nearestDist then
                        nearest     = child
                        nearestDist = dist
                    end
                end
            end
        end
    end
    return nearest, nearestDist
end

-- Priority: 1. Boss (only when spawned and no BossTimerBillboard), 2. Mob (only without CC_)
local function getTarget()
    -- Priority 1: Boss
    if autoBossEnabled and hasSelectedBoss() then
        local boss, _ = findNearestBoss()
        if boss then return boss, "Boss" end
    end

    -- Priority 2: Mob
    if autoMobEnabled and hasSelectedMob() then
        local mob, _ = findNearestMob()
        if mob then return mob, "Mob" end
    end

    return nil, nil
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── AUTO COLLECTIBLES (Puzzle, HakiColor, Meteor in Workspace) ────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local selectedCollectibles = {} -- itemName -> true
local autoGetEnabled        = false
local autoGetThread         = nil

local function isCollectibleItem(child, itemName)
    if not child or not child.Parent then return false end

    -- Ignore folders and spawn locations container
    if child:IsA("Folder") then return false end
    if child.Name == "MeteorSpawnLocations" or child.Name:find("Spawn") or child.Name:find("Folder") then
        return false
    end

    local nameMatch = false
    if itemName == "Meteor" then
        nameMatch = (child.Name == "Meteor" or child.Name == "Meteorite" or child.Name == "Meteor Ores")
                    or (child.Name:find("Meteor") and not child.Name:find("Spawn") and not child.Name:find("Location"))
    elseif itemName == "Puzzle" then
        nameMatch = (child.Name == "Puzzle")
    elseif itemName == "HakiColor" then
        nameMatch = (child.Name == "HakiColor" or child.Name:find("HakiColor"))
    end

    if not nameMatch then return false end

    local targetPart = child:IsA("BasePart") and child or (child:FindFirstChildWhichIsA("BasePart", true) or child.PrimaryPart)
    return targetPart ~= nil
end

local function collectItem(item)
    if not item or not item.Parent then return end
    local root = getRoot()
    if not root then return end

    local targetPart = item:IsA("BasePart") and item or (item:FindFirstChildWhichIsA("BasePart", true) or item.PrimaryPart)
    if not targetPart then return end

    -- Teleport to item
    root.CFrame = targetPart.CFrame + Vector3.new(0, 3, 0)

    -- Trigger ProximityPrompt if present (e.g. Meteor)
    local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
    if prompt then
        if fireproximityprompt then
            pcall(function() fireproximityprompt(prompt) end)
        else
            pcall(function()
                prompt:InputHoldBegin()
                task.wait(prompt.HoldDuration or 0.1)
                prompt:InputHoldEnd()
            end)
        end
    end

    -- Touch interest if present
    if firetouchinterest then
        pcall(function()
            firetouchinterest(root, targetPart, 0)
            task.wait(0.05)
            firetouchinterest(root, targetPart, 1)
        end)
    end
end

local function findNearestCollectible()
    local root = getRoot()
    if not root then return nil end

    local nearest, nearestDist = nil, math.huge

    for _, child in ipairs(workspace:GetChildren()) do
        for itemName, isSelected in pairs(selectedCollectibles) do
            if isSelected and isCollectibleItem(child, itemName) then
                local targetPart = child:IsA("BasePart") and child or (child:FindFirstChildWhichIsA("BasePart", true) or child.PrimaryPart)
                if targetPart then
                    local dist = (targetPart.Position - root.Position).Magnitude
                    if dist < nearestDist then
                        nearest     = child
                        nearestDist = dist
                    end
                end
            end
        end
    end

    return nearest
end

local function autoGetLoop()
    local activeItem = nil

    while autoGetEnabled do
        pcall(function()
            if not activeItem or not activeItem.Parent then
                activeItem = findNearestCollectible()
            end

            if activeItem and activeItem.Parent then
                collectItem(activeItem)
                task.wait(0.2)
            else
                activeItem = nil
                task.wait(0.5)
            end
        end)
        task.wait(0.2)
    end
end

local function checkAutoGetState()
    if autoGetEnabled then
        if not autoGetThread then
            autoGetThread = task.spawn(autoGetLoop)
        end
    else
        if autoGetThread then
            pcall(function() task.cancel(autoGetThread) end)
            autoGetThread = nil
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── AUTO DELETE ARTIFACTS ─────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local selectedArtifactTypes  = {} -- e.g. ["Helmet"] = true, ["Armor"] = true
local selectedArtifactGrades = {} -- e.g. ["F"] = true, ["C"] = true
local artifactKeepUpgraded   = false
local autoDeleteArtifactOn   = false
local autoDeleteThread       = nil

local function processAutoDeleteArtifacts()
    local dataV2 = LocalPlayer:FindFirstChild("DataV2")
    if not dataV2 then return end
    local artifactFolder = dataV2:FindFirstChild("Artifact")
    if not artifactFolder then return end

    for _, art in ipairs(artifactFolder:GetChildren()) do
        if not autoDeleteArtifactOn then break end
        if art:IsA("Folder") and art.Name:find("Art_") then
            local gradeObj = art:FindFirstChild("Grade")
            local typeObj  = art:FindFirstChild("Type_Artifact")
            local expObj   = art:FindFirstChild("Exp")
            local lockObj  = art:FindFirstChild("IsLocked")

            local gradeVal = gradeObj and gradeObj.Value
            local typeVal  = typeObj and typeObj.Value
            local expVal   = expObj and expObj.Value or 0
            local isLocked = lockObj and lockObj.Value

            -- Check if artifact is locked -> SKIP!
            if not isLocked then
                -- Check 1: Grade match
                local gradeMatches = selectedArtifactGrades[gradeVal] == true

                -- Check 2: Type match
                local typeMatches  = selectedArtifactTypes[typeVal] == true

                -- Check 3: Upgraded status (skip if Exp > 0 and Keep Upgraded is ON)
                local skipUpgraded = artifactKeepUpgraded and (expVal > 0)

                if gradeMatches and typeMatches and not skipUpgraded then
                    pcall(function()
                        if ArtifactRemoteFunc then
                            ArtifactRemoteFunc:InvokeServer("Delete", art.Name)
                        end
                    end)
                    task.wait(0.15)
                end
            end
        end
    end
end

local function autoDeleteLoop()
    while autoDeleteArtifactOn do
        pcall(function()
            processAutoDeleteArtifacts()
        end)
        task.wait(1)
    end
end

local function checkAutoDeleteState()
    if autoDeleteArtifactOn then
        if not autoDeleteThread then
            autoDeleteThread = task.spawn(autoDeleteLoop)
        end
    else
        if autoDeleteThread then
            pcall(function() task.cancel(autoDeleteThread) end)
            autoDeleteThread = nil
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── AUTO CHEST OPENER ─────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local selectedChests   = {} -- chestName -> true
local autoChestEnabled = false
local autoChestThread  = nil

local function getChestAmount(chestName)
    local pgui = LocalPlayer:FindFirstChildWhichIsA("PlayerGui")
    if not pgui then return 0 end

    local menu = pgui:FindFirstChild("Menu")
    if not menu then return 0 end

    local inv = menu:FindFirstChild("InventoryFrame")
    if not inv then return 0 end

    local items = inv:FindFirstChild("Items")
    if not items then return 0 end

    local chestBtn = items:FindFirstChild(chestName)
    if not chestBtn then return 0 end

    local amoutLbl = chestBtn:FindFirstChild("Amout")
    if not amoutLbl then return 0 end

    local text = amoutLbl.Text or ""
    local num  = tonumber(text:match("%d+"))
    return num or 0
end

local function autoChestLoop()
    while autoChestEnabled do
        pcall(function()
            for chestName, isSelected in pairs(selectedChests) do
                if not autoChestEnabled then break end
                if isSelected then
                    local amt = getChestAmount(chestName)
                    if amt > 0 then
                        pcall(function()
                            if OpenChestRemote then
                                OpenChestRemote:FireServer(chestName, amt)
                            end
                        end)
                        task.wait(0.5)
                    end
                end
            end
        end)
        task.wait(0.5)
    end
end

local function checkAutoChestState()
    if autoChestEnabled then
        if not autoChestThread then
            autoChestThread = task.spawn(autoChestLoop)
        end
    else
        if autoChestThread then
            pcall(function() task.cancel(autoChestThread) end)
            autoChestThread = nil
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── TOOL NAME RESOLUTION ──────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local function resolveToolName()
    local tool = getEquippedTool()
    if not tool then return nil, nil end

    local toolTip = tool.ToolTip
    local statKey = nil

    if toolTip == "Sword" then
        statKey = "Current_Sword"
    elseif toolTip == "Melee" then
        statKey = "Current_Melee"
    elseif toolTip == "DevilFruit" then
        statKey = "Current_DevilFruit"
    end

    if statKey then
        local dataV2 = LocalPlayer:FindFirstChild("DataV2")
        if dataV2 then
            local stats = dataV2:FindFirstChild("Stats")
            if stats then
                local cur = stats:FindFirstChild(statKey)
                if cur and cur.Value and cur.Value ~= "" and cur.Value ~= "Default" then
                    return cur.Value, tool
                end
            end
        end
    end

    return tool.Name, tool
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── COMBAT SYSTEM ─────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local SKILL_MAP = {
    Z = "Move1",
    X = "Move2",
    C = "Move3",
    V = "Move4",
    F = "Move5",
}

local function fireAttack()
    local toolName = resolveToolName()
    if not toolName then return end
    pcall(function()
        -- Support Sword format: {"Gravity Blade", "Gravity Blade"}
        MoveRemote:FireServer(toolName, toolName)

        -- Support Melee/Punching format: {"Sukuna", "PunchingSukuna"}
        MoveRemote:FireServer(toolName, "Punching" .. toolName)

        -- Support Generic format: {"Sukuna", "Punching"}
        MoveRemote:FireServer(toolName, "Punching")
    end)
end

local function fireSkill(key)
    local moveName = SKILL_MAP[key]
    if not moveName then return end

    local toolName, tool = resolveToolName()
    if not toolName then return end

    -- Check cooldown attribute on tool
    if tool and tool:GetAttribute(key) then return end

    pcall(function()
        local root = getRoot()
        if root then
            MoveRemote:FireServer(toolName, moveName, root)
        else
            MoveRemote:FireServer(toolName, moveName)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── POSITION HELPER ───────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local function getStandCFrame(targetPart, method, distance)
    local pos = targetPart.Position
    if method == "Above" then
        return CFrame.new(pos + Vector3.new(0, distance, 0), pos)
    elseif method == "Behind" then
        return targetPart.CFrame * CFrame.new(0, 0, distance)
    elseif method == "Front" then
        return targetPart.CFrame * CFrame.new(0, 0, -distance)
    end
    return CFrame.new(pos + Vector3.new(0, distance, 0), pos)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── ESP SYSTEM ────────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local espEnabled   = false
local espConns     = {}

local function clearESP()
    if SpawnEnemy then
        for _, child in ipairs(SpawnEnemy:GetDescendants()) do
            if child.Name == "BWWA_ESP" or child.Name == "BWWA_ESP_Label" then
                pcall(function() child:Destroy() end)
            end
        end
    end
    if MapFolder then
        for _, child in ipairs(MapFolder:GetDescendants()) do
            if child.Name == "BWWA_ESP" or child.Name == "BWWA_ESP_Label" then
                pcall(function() child:Destroy() end)
            end
        end
    end
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "BWWA_ESP" or child.Name == "BWWA_ESP_Label" then
            pcall(function() child:Destroy() end)
        end
    end
    for _, conn in ipairs(espConns) do
        pcall(function() conn:Disconnect() end)
    end
    espConns = {}
end

local function createESPFor(part)
    if not part:IsA("BasePart") then return end
    if part:FindFirstChild("BWWA_ESP") then return end

    local hl       = Instance.new("Highlight")
    hl.Name        = "BWWA_ESP"
    hl.FillColor   = Color3.fromRGB(255, 70, 70)
    hl.FillTransparency   = 0.65
    hl.OutlineColor       = Color3.fromRGB(255, 255, 80)
    hl.OutlineTransparency = 0.2
    hl.Adornee    = part
    hl.Parent     = part

    local bb       = Instance.new("BillboardGui")
    bb.Name        = "BWWA_ESP_Label"
    bb.Size        = UDim2.new(0, 200, 0, 28)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.Adornee     = part
    bb.Parent      = part

    local lbl               = Instance.new("TextLabel")
    lbl.Size                = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                = part.Name
    lbl.TextColor3          = Color3.fromRGB(255, 255, 255)
    lbl.TextStrokeTransparency = 0.4
    lbl.TextStrokeColor3    = Color3.fromRGB(0, 0, 0)
    lbl.Font                = Enum.Font.GothamBold
    lbl.TextScaled          = true
    lbl.Parent              = bb
end

local function refreshESP()
    clearESP()
    if not espEnabled then return end

    if SpawnEnemy then
        for _, child in ipairs(SpawnEnemy:GetChildren()) do
            if isMobAlive(child) then createESPFor(child) end
        end
    end
    local entries = getAllBossFolderChildren()
    for _, entry in ipairs(entries) do
        if isBossAlive(entry.child) then createESPFor(entry.child) end
    end
    for bossName, _ in pairs(selectedBosses) do
        local wsBoss = findBossInWorkspace(bossName)
        if wsBoss then createESPFor(wsBoss) end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── ANTI-DEATH ────────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local antiDeathEnabled = false
local antiDeathConn    = nil

local function startAntiDeath()
    if antiDeathConn then antiDeathConn:Disconnect() end
    antiDeathConn = RunService.Heartbeat:Connect(function()
        if not antiDeathEnabled then return end
        local hum = getHumanoid()
        if hum and hum.Health > 0 and hum.Health < hum.MaxHealth * 0.35 then
            hum.Health = hum.MaxHealth
        end
    end)
end

local function stopAntiDeath()
    if antiDeathConn then
        antiDeathConn:Disconnect()
        antiDeathConn = nil
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── HAKI SYSTEM (AUTO BUSO & AUTO KEN) ────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local busoHakiEnabled = false
local busoHakiConn    = nil

local kenHakiEnabled  = false
local kenHakiConn     = nil

local function getCharModelInWorkspace()
    local char = getCharacter()
    if char then return char end

    -- Check direct character model named LocalPlayer.Name or Danni_NT01
    local nameMatch = workspace:FindFirstChild(LocalPlayer.Name)
    if nameMatch then return nameMatch end

    for _, child in ipairs(workspace:GetChildren()) do
        if child:IsA("Model") and child:FindFirstChild("HumanoidRootPart") and child:FindFirstChild("IsHaki") then
            return child
        end
    end
    return nil
end

local function isBusoHakiActive()
    local charModel = getCharModelInWorkspace()
    if charModel then
        local isHakiVal = charModel:FindFirstChild("IsHaki")
        if isHakiVal and isHakiVal:IsA("BoolValue") then
            return isHakiVal.Value == true
        end
    end
    return false
end

local function isKenHakiActive()
    local charModel = getCharModelInWorkspace()
    if charModel then
        local kenOnVal = charModel:FindFirstChild("KenHakiOn")
        if kenOnVal and kenOnVal:IsA("BoolValue") then
            return kenOnVal.Value == true
        end
    end
    return false
end

local function toggleBusoHakiRemote()
    pcall(function()
        if ToggleBusoHakiRF then
            ToggleBusoHakiRF:InvokeServer()
        else
            -- Fallback Knit RemoteFunction path lookup
            local rf = ReplicatedStorage:WaitForChild("Packages", 2)
                        :WaitForChild("Knit", 2)
                        :WaitForChild("Services", 2)
                        :WaitForChild("BusoHakiService", 2)
                        :WaitForChild("RF", 2)
                        :WaitForChild("ToggleBusoHaki", 2)
            if rf then rf:InvokeServer() end
        end
    end)
end

local function toggleKenHakiRemote()
    pcall(function()
        if ToggleKenHakiRF then
            ToggleKenHakiRF:InvokeServer()
        else
            -- Fallback Knit RemoteFunction path lookup
            local rf = ReplicatedStorage:WaitForChild("Packages", 2)
                        :WaitForChild("Knit", 2)
                        :WaitForChild("Services", 2)
                        :WaitForChild("KenHakiService", 2)
                        :WaitForChild("RF", 2)
                        :WaitForChild("ToggleKenHaki", 2)
            if rf then rf:InvokeServer() end
        end
    end)
end

-- Auto Buso Haki Loop
local function startBusoHakiLoop()
    if busoHakiConn then busoHakiConn:Disconnect() end
    busoHakiConn = RunService.Heartbeat:Connect(function()
        if not busoHakiEnabled then return end
        if not isBusoHakiActive() then
            toggleBusoHakiRemote()
            task.wait(0.5)
        end
    end)
end

local function stopBusoHakiLoop()
    if busoHakiConn then
        busoHakiConn:Disconnect()
        busoHakiConn = nil
    end
    if isBusoHakiActive() then
        toggleBusoHakiRemote()
    end
end

-- Auto Ken Haki Loop
local function startKenHakiLoop()
    if kenHakiConn then kenHakiConn:Disconnect() end
    kenHakiConn = RunService.Heartbeat:Connect(function()
        if not kenHakiEnabled then return end
        if not isKenHakiActive() then
            toggleKenHakiRemote()
            task.wait(0.5)
        end
    end)
end

local function stopKenHakiLoop()
    if kenHakiConn then
        kenHakiConn:Disconnect()
        kenHakiConn = nil
    end
    if isKenHakiActive() then
        toggleKenHakiRemote()
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── ISLAND & NPC TELEPORT ─────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local function getIslandNames()
    local names = {}
    if not IslandsLocation then return names end
    for _, child in ipairs(IslandsLocation:GetChildren()) do
        if child:IsA("BasePart") then
            table.insert(names, child.Name)
        end
    end
    table.sort(names)
    return names
end

local function teleportToIsland(name)
    if not IslandsLocation then return end
    local part = IslandsLocation:FindFirstChild(name)
    if not part then return end
    local root = getRoot()
    if not root then return end
    root.CFrame = part.CFrame + Vector3.new(0, 10, 0)
end

local function getNPCNames()
    local names = {}
    if not NPCFolder then return names end
    for _, child in ipairs(NPCFolder:GetChildren()) do
        if child:IsA("Model") then
            table.insert(names, child.Name)
        end
    end
    table.sort(names)
    return names
end

local function teleportToNPC(name)
    if not NPCFolder then return end
    local model = NPCFolder:FindFirstChild(name)
    if not model then return end

    local hrp = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart or model:FindFirstChild("Torso") or model:FindFirstChild("Head") or model:FindFirstChildWhichIsA("BasePart")
    if not hrp then return end

    local root = getRoot()
    if not root then return end

    root.CFrame = hrp.CFrame * CFrame.new(0, 0, -3) * CFrame.Angles(0, math.rad(180), 0)
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── MAIN FARM LOOP ────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

local farmThread        = nil
local farmHBConn        = nil
local currentTarget     = nil
local currentTargetType = nil -- "Boss" or "Mob"

-- Settings driven by UI Options
local autoAttackOn   = false
local autoSkillsOn   = false
local selectedSkills = {}
local attackPosition = "Above"
local attackDistance  = 8
local skillInterval  = 0.3

local function farmLoop()
    while (autoMobEnabled or autoBossEnabled) do
        pcall(function()
            if not (autoMobEnabled or autoBossEnabled) then return end

            local root = getRoot()
            if not root or not currentTarget then
                task.wait(0.3)
                return
            end

            -- Auto equip tool
            autoEquipTool()

            -- Fire M1
            if autoAttackOn then
                fireAttack()
            end

            -- Fire selected skills
            if autoSkillsOn then
                for _, key in ipairs({"Z", "X", "C", "V", "F"}) do
                    if selectedSkills[key] and (autoMobEnabled or autoBossEnabled) then
                        fireSkill(key)
                        task.wait(skillInterval)
                    end
                end
            end
        end)

        task.wait(0.35)
    end
end

local function startFarmHeartbeat()
    if farmHBConn then farmHBConn:Disconnect() end
    farmHBConn = RunService.Heartbeat:Connect(function()
        if not (autoMobEnabled or autoBossEnabled) then return end
        local root = getRoot()
        if not root then return end

        -- Check if current target is invalid, dead, has CC_ (for Mob), or has BossTimerBillboard / no Humanoid (for Boss)
        local isAlive = false
        if currentTarget and currentTarget.Parent then
            isAlive = isTargetAlive(currentTarget, currentTargetType == "Boss")
        end

        if not currentTarget or not isAlive then
            currentTarget, currentTargetType = getTarget()
        else
            -- If currently targeting Mob, but an Auto Boss spawned, switch immediately to Boss!
            if currentTargetType == "Mob" and autoBossEnabled and hasSelectedBoss() then
                local boss, _ = findNearestBoss()
                if boss then
                    currentTarget     = boss
                    currentTargetType = "Boss"
                end
            end
        end

        if currentTarget and currentTarget.Parent and isTargetAlive(currentTarget, currentTargetType == "Boss") then
            local targetRoot, hum = getTargetRootPart(currentTarget)
            if targetRoot then
                root.CFrame = getStandCFrame(targetRoot, attackPosition, attackDistance)
            end
        else
            currentTarget     = nil
            currentTargetType = nil
        end
    end)
end

local function stopFarmHeartbeat()
    if farmHBConn then
        farmHBConn:Disconnect()
        farmHBConn = nil
    end
    currentTarget     = nil
    currentTargetType = nil
end

local function checkFarmState()
    if autoMobEnabled or autoBossEnabled then
        startFarmHeartbeat()
        if not farmThread then
            farmThread = task.spawn(farmLoop)
        end
    else
        stopFarmHeartbeat()
        if farmThread then
            pcall(function() task.cancel(farmThread) end)
            farmThread = nil
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── ANTI-AFK ──────────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

task.spawn(function()
    while true do
        task.wait(60)
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
        if Fluent and Fluent.Unloaded then break end
    end
end)

-- ══════════════════════════════════════════════════════════════════════════════
-- ══════════════════════════════════════════════════════════════════════════════
-- ── UI SETUP ──────────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════
-- ══════════════════════════════════════════════════════════════════════════════

local Window = Fluent:CreateWindow({
    Title        = "Nobody | " .. gameInfo.Name,
    SubTitle     = "by Dx  •  BWWA Piece",
    TabWidth     = 160,
    Size         = UDim2.fromOffset(580, 460),
    Acrylic      = true,
    Theme        = "Dark",
    MinimizeKey  = Enum.KeyCode.LeftControl,
    ToggleButton = true,
})

-- Reordered Tabs: Main -> Utility -> Misc -> Settings -> Config
local Tabs = {
    Main     = Window:AddTab({ Title = "Main",     Icon = "swords" }),
    Utility  = Window:AddTab({ Title = "Utility",  Icon = "wrench" }),
    Misc     = Window:AddTab({ Title = "Misc",     Icon = "box" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" }),
    Config   = Window:AddTab({ Title = "Config",   Icon = "save" }),
}

local Options = Fluent.Options

-- Register global cleanup handler for reloading
getgenv().BWWA_PIECE_CLEANUP = function()
    autoMobEnabled        = false
    autoBossEnabled       = false
    autoGetEnabled        = false
    autoDeleteArtifactOn  = false
    autoChestEnabled      = false
    busoHakiEnabled       = false
    kenHakiEnabled        = false
    checkFarmState()
    checkAutoGetState()
    checkAutoDeleteState()
    checkAutoChestState()
    stopBusoHakiLoop()
    stopKenHakiLoop()
    clearESP()
    stopAntiDeath()

    if Window then
        pcall(function() Window:Destroy() end)
    end
    if Fluent then
        pcall(function() Fluent:Destroy() end)
    end

    local coreGui = pcall(game.GetService, game, "CoreGui") and game:GetService("CoreGui")
    if coreGui then
        for _, gui in ipairs(coreGui:GetChildren()) do
            if gui:IsA("ScreenGui") and (gui.Name == "Fluent" or gui.Name:find("Nobody")) then
                pcall(function() gui:Destroy() end)
            end
        end
    end
    local playerGui = LocalPlayer:FindFirstChildWhichIsA("PlayerGui")
    if playerGui then
        for _, gui in ipairs(playerGui:GetChildren()) do
            if gui:IsA("ScreenGui") and (gui.Name == "Fluent" or gui.Name:find("Nobody")) then
                pcall(function() gui:Destroy() end)
            end
        end
    end
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── TAB: MAIN ─────────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

do
    -- ── Auto Boss Section ─────────────────────────────────────────
    Tabs.Main:AddSection("Auto Boss (Priority 1)")

    local bossNames = getUniqueBossNames()
    if #bossNames == 0 then bossNames = {"(no bosses found)"} end

    local BossDropdown = Track(Tabs.Main:AddDropdown("BossSelect", {
        Title       = "Select Bosses (Multi)",
        Description = "Pick one or multiple bosses to farm",
        Values      = bossNames,
        Multi       = true,
        Default     = {},
        Callback    = function(Value)
            selectedBosses = {}
            if type(Value) == "table" then
                for bossName, isSelected in pairs(Value) do
                    if isSelected then
                        selectedBosses[bossName] = true
                    end
                end
            end
            currentTarget     = nil
            currentTargetType = nil
        end,
    }))

    if Options.BossSelect then
        local origSetValue = Options.BossSelect.SetValue
        Options.BossSelect.SetValue = function(self, val)
            if type(val) == "string" then
                val = { [val] = true }
            elseif type(val) ~= "table" then
                val = {}
            end
            return origSetValue(self, val)
        end
    end

    Tabs.Main:AddButton({
        Title       = "Refresh Boss List",
        Description = "Rescan all boss folders and Workspace for bosses",
        Callback    = function()
            local fresh = getUniqueBossNames()
            if #fresh == 0 then fresh = {"(no bosses found)"} end
            BossDropdown:SetValues(fresh)
            Fluent:Notify({
                Title    = "Boss List",
                Content  = "Found " .. #fresh .. " boss types",
                Duration = 3,
            })
        end,
    })

    Track(Tabs.Main:AddToggle("AutoBoss", {
        Title    = "Auto Boss",
        Default  = false,
        Callback = function(Value)
            autoBossEnabled = Value
            if Value then
                task.wait(0.5)
                if not hasSelectedBoss() then
                    Fluent:Notify({
                        Title   = "Error",
                        Content = "Please select at least one boss first!",
                        Duration = 3,
                    })
                    Options.AutoBoss:SetValue(false)
                    return
                end
            end
            checkFarmState()
        end,
    }))

    -- ── Auto Mob Section ──────────────────────────────────────────
    Tabs.Main:AddSection("Auto Mob (Priority 2)")

    local mobNames = getUniqueMobNames()
    if #mobNames == 0 then mobNames = {"(no mobs found)"} end

    local MobDropdown = Track(Tabs.Main:AddDropdown("MobSelect", {
        Title       = "Select Mobs (Multi)",
        Description = "Pick one or multiple mobs to farm",
        Values      = mobNames,
        Multi       = true,
        Default     = {},
        Callback    = function(Value)
            selectedMobs = {}
            if type(Value) == "table" then
                for mobName, isSelected in pairs(Value) do
                    if isSelected then
                        selectedMobs[mobName] = true
                    end
                end
            end
            currentTarget     = nil
            currentTargetType = nil
        end,
    }))

    if Options.MobSelect then
        local origSetValue = Options.MobSelect.SetValue
        Options.MobSelect.SetValue = function(self, val)
            if type(val) == "string" then
                val = { [val] = true }
            elseif type(val) ~= "table" then
                val = {}
            end
            return origSetValue(self, val)
        end
    end

    Tabs.Main:AddButton({
        Title       = "Refresh Mob List",
        Description = "Rescan SpawnEnemy for mob names",
        Callback    = function()
            local fresh = getUniqueMobNames()
            if #fresh == 0 then fresh = {"(no mobs found)"} end
            MobDropdown:SetValues(fresh)
            Fluent:Notify({
                Title    = "Mob List",
                Content  = "Found " .. #fresh .. " mob types",
                Duration = 3,
            })
        end,
    })

    Track(Tabs.Main:AddToggle("AutoMob", {
        Title    = "Auto Mob",
        Default  = false,
        Callback = function(Value)
            autoMobEnabled = Value
            if Value then
                if not hasSelectedMob() then
                    Fluent:Notify({
                        Title   = "Error",
                        Content = "Please select at least one mob first!",
                        Duration = 3,
                    })
                    Options.AutoMob:SetValue(false)
                    return
                end
            end
            checkFarmState()
        end,
    }))

    -- ── Auto Collect Section (Puzzle, HakiColor, Meteor in Workspace) ──
    Tabs.Main:AddSection("Auto Collect (Workspace)")

    local CollectiblesDropdown = Track(Tabs.Main:AddDropdown("CollectiblesSelect", {
        Title       = "Select Collectibles (Multi)",
        Description = "Pick items spawned in Workspace to auto-get",
        Values      = {"Puzzle", "HakiColor", "Meteor"},
        Multi       = true,
        Default     = {},
        Callback    = function(Value)
            selectedCollectibles = {}
            if type(Value) == "table" then
                for itemName, isSelected in pairs(Value) do
                    if isSelected then
                        selectedCollectibles[itemName] = true
                    end
                end
            end
        end,
    }))

    if Options.CollectiblesSelect then
        local origSetValue = Options.CollectiblesSelect.SetValue
        Options.CollectiblesSelect.SetValue = function(self, val)
            if type(val) == "string" then
                val = { [val] = true }
            elseif type(val) ~= "table" then
                val = {}
            end
            return origSetValue(self, val)
        end
    end

    Track(Tabs.Main:AddToggle("AutoGetCollectibles", {
        Title       = "Auto Get",
        Description = "Auto Teleport & Collect items spawned in Workspace",
        Default     = false,
        Callback    = function(Value)
            autoGetEnabled = Value
            checkAutoGetState()
        end,
    }))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── TAB: UTILITY ──────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

do
    -- ── Teleport to Island ────────────────────────────────────────
    Tabs.Utility:AddSection("Teleport to Island")

    local islandNames = getIslandNames()
    if #islandNames == 0 then islandNames = {"(none)"} end
    local chosenIsland = islandNames[1]

    local IslandDropdown = Track(Tabs.Utility:AddDropdown("IslandSelect", {
        Title    = "Select Island",
        Values   = islandNames,
        Default  = 1,
        Callback = function(Value)
            chosenIsland = Value
        end,
    }))

    Tabs.Utility:AddButton({
        Title       = "Teleport to Island",
        Description = "Teleport to selected island",
        Callback    = function()
            teleportToIsland(chosenIsland)
            Fluent:Notify({
                Title    = "Teleport",
                Content  = "Teleported to " .. tostring(chosenIsland),
                Duration = 3,
            })
        end,
    })

    -- ── Teleport to NPC ───────────────────────────────────────────
    Tabs.Utility:AddSection("Teleport to NPC")

    local npcNames = getNPCNames()
    if #npcNames == 0 then npcNames = {"(none)"} end
    local chosenNPC = npcNames[1]

    local NPCDropdown = Track(Tabs.Utility:AddDropdown("NPCSelect", {
        Title    = "Select NPC",
        Values   = npcNames,
        Default  = 1,
        Callback = function(Value)
            chosenNPC = Value
        end,
    }))

    Tabs.Utility:AddButton({
        Title       = "Refresh NPC List",
        Description = "Rescan Workspace.Map.NPCs for NPCs",
        Callback    = function()
            local fresh = getNPCNames()
            if #fresh == 0 then fresh = {"(none)"} end
            NPCDropdown:SetValues(fresh)
            Fluent:Notify({
                Title    = "NPC List",
                Content  = "Found " .. #fresh .. " NPCs",
                Duration = 3,
            })
        end,
    })

    Tabs.Utility:AddButton({
        Title       = "Teleport to NPC",
        Description = "Teleport in front of selected NPC",
        Callback    = function()
            teleportToNPC(chosenNPC)
            Fluent:Notify({
                Title    = "Teleport",
                Content  = "Teleported to " .. tostring(chosenNPC),
                Duration = 3,
            })
        end,
    })

    -- ── Haki ──────────────────────────────────────────────────────
    Tabs.Utility:AddSection("Haki")

    Track(Tabs.Utility:AddToggle("BusoHaki", {
        Title       = "Auto Buso Haki (Armament)",
        Description = "Auto activate and keep Buso Haki active",
        Default     = false,
        Callback    = function(Value)
            busoHakiEnabled = Value
            if Value then
                startBusoHakiLoop()
            else
                stopBusoHakiLoop()
            end
        end,
    }))

    Track(Tabs.Utility:AddToggle("KenHaki", {
        Title       = "Auto Ken Haki (Observation)",
        Description = "Auto activate and keep Ken Haki active",
        Default     = false,
        Callback    = function(Value)
            kenHakiEnabled = Value
            if Value then
                startKenHakiLoop()
            else
                stopKenHakiLoop()
            end
        end,
    }))

    -- ── ESP ───────────────────────────────────────────────────────
    Tabs.Utility:AddSection("Visuals")

    Track(Tabs.Utility:AddToggle("MobESP", {
        Title       = "Mob / Boss ESP",
        Description = "Highlight all mobs and bosses",
        Default     = false,
        Callback    = function(Value)
            espEnabled = Value
            refreshESP()
        end,
    }))

    -- ── Anti-Death ────────────────────────────────────────────────
    Tabs.Utility:AddSection("Survival")

    Track(Tabs.Utility:AddToggle("AntiDeath", {
        Title       = "Anti-Death",
        Description = "Auto restore HP when below 35%",
        Default     = false,
        Callback    = function(Value)
            antiDeathEnabled = Value
            if Value then
                startAntiDeath()
            else
                stopAntiDeath()
            end
        end,
    }))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── TAB: MISC ────────────────────────────────═════════════════════════════════
-- ══════════════════════════════════════════════════════════════════════════════

do
    -- ── Auto Delete Artifact Section (Moved from Utility to Misc) ─
    Tabs.Misc:AddSection("Auto Delete Artifact")

    local ArtifactTypeDropdown = Track(Tabs.Misc:AddDropdown("ArtifactTypeSelect", {
        Title       = "Select Types (Multi)",
        Description = "Pick artifact types to delete",
        Values      = {"Helmet", "Armor", "Gloves", "Boots"},
        Multi       = true,
        Default     = {},
        Callback    = function(Value)
            selectedArtifactTypes = {}
            if type(Value) == "table" then
                for typeName, isSelected in pairs(Value) do
                    if isSelected then
                        selectedArtifactTypes[typeName] = true
                    end
                end
            end
        end,
    }))

    if Options.ArtifactTypeSelect then
        local origSetValue = Options.ArtifactTypeSelect.SetValue
        Options.ArtifactTypeSelect.SetValue = function(self, val)
            if type(val) == "string" then
                val = { [val] = true }
            elseif type(val) ~= "table" then
                val = {}
            end
            return origSetValue(self, val)
        end
    end

    local ArtifactGradeDropdown = Track(Tabs.Misc:AddDropdown("ArtifactGradeSelect", {
        Title       = "Select Grade (Multi)",
        Description = "Pick artifact grades to delete",
        Values      = {"SSS", "SS", "S", "A", "B", "C", "D", "F"},
        Multi       = true,
        Default     = {},
        Callback    = function(Value)
            selectedArtifactGrades = {}
            if type(Value) == "table" then
                for gradeName, isSelected in pairs(Value) do
                    if isSelected then
                        selectedArtifactGrades[gradeName] = true
                    end
                end
            end
        end,
    }))

    if Options.ArtifactGradeSelect then
        local origSetValue = Options.ArtifactGradeSelect.SetValue
        Options.ArtifactGradeSelect.SetValue = function(self, val)
            if type(val) == "string" then
                val = { [val] = true }
            elseif type(val) ~= "table" then
                val = {}
            end
            return origSetValue(self, val)
        end
    end

    Track(Tabs.Misc:AddToggle("ArtifactUpgradeNotDelete", {
        Title       = "Artifact Upgrade Not Delete",
        Description = "Skip deleting artifacts with Exp > 0",
        Default     = true,
        Callback    = function(Value)
            artifactKeepUpgraded = Value
        end,
    }))

    Track(Tabs.Misc:AddToggle("AutoDeleteArtifact", {
        Title       = "Auto Delete Artifact",
        Description = "Automatically delete artifacts matching criteria",
        Default     = false,
        Callback    = function(Value)
            autoDeleteArtifactOn = Value
            checkAutoDeleteState()
        end,
    }))

    -- ── Auto Chest Opener Section ─────────────────────────────────
    Tabs.Misc:AddSection("Auto Chest")

    local ChestDropdown = Track(Tabs.Misc:AddDropdown("ChestSelect", {
        Title       = "Select Chest (Multi)",
        Description = "Pick chests to auto open from Inventory",
        Values      = {"Mythic Chest","Legendary Chest", "Epic Chest", "Rare Chest", "Common Chest"},
        Multi       = true,
        Default     = {},
        Callback    = function(Value)
            selectedChests = {}
            if type(Value) == "table" then
                for chestName, isSelected in pairs(Value) do
                    if isSelected then
                        selectedChests[chestName] = true
                    end
                end
            end
        end,
    }))

    if Options.ChestSelect then
        local origSetValue = Options.ChestSelect.SetValue
        Options.ChestSelect.SetValue = function(self, val)
            if type(val) == "string" then
                val = { [val] = true }
            elseif type(val) ~= "table" then
                val = {}
            end
            return origSetValue(self, val)
        end
    end

    Track(Tabs.Misc:AddToggle("AutoChest", {
        Title       = "Auto Chest",
        Description = "Auto open selected chests when inventory amount > 0",
        Default     = false,
        Callback    = function(Value)
            autoChestEnabled = Value
            checkAutoChestState()
        end,
    }))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── TAB: SETTINGS ─────────────────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

do
    -- ── Weapon & Equipment Section ────────────────────────────────
    Tabs.Settings:AddSection("Weapon & Equipment")

    local weaponList = getAvailableWeapons()
    local WeaponDropdown = Track(Tabs.Settings:AddDropdown("WeaponSelect", {
        Title    = "Select Weapon to Equip",
        Values   = weaponList,
        Default  = 1,
        Callback = function(Value)
            selectedWeaponName = Value
            autoEquipTool()
        end,
    }))

    Tabs.Settings:AddButton({
        Title       = "Refresh Weapon List",
        Description = "Rescan Backpack & Character for tools",
        Callback    = function()
            local fresh = getAvailableWeapons()
            WeaponDropdown:SetValues(fresh)
            Fluent:Notify({
                Title    = "Weapon List",
                Content  = "Found " .. #fresh .. " weapons",
                Duration = 3,
            })
        end,
    })

    Track(Tabs.Settings:AddToggle("AutoEquipWeapon", {
        Title       = "Auto Equip Weapon",
        Description = "Automatically equip weapon continuously",
        Default     = true,
        Callback    = function(Value)
            autoEquipEnabled = Value
            if Value then autoEquipTool() end
        end,
    }))

    -- ── Position Section ──────────────────────────────────────────
    Tabs.Settings:AddSection("Position")

    Track(Tabs.Settings:AddDropdown("AttackPosition", {
        Title    = "Attack Position",
        Values   = {"Above", "Front", "Behind"},
        Default  = 1,
        Callback = function(Value)
            attackPosition = Value
        end,
    }))

    Track(Tabs.Settings:AddSlider("AttackDistance", {
        Title    = "Attack Distance",
        Min      = 3,
        Max      = 25,
        Default  = 8,
        Rounding = 0,
        Callback = function(Value)
            attackDistance = Value
        end,
    }))

    -- ── Combat Section ────────────────────────────────────────────
    Tabs.Settings:AddSection("Combat")

    Track(Tabs.Settings:AddToggle("AutoAttack", {
        Title       = "Auto Attack (M1)",
        Description = "Punching/Sword auto fire when Auto Farm is ON",
        Default     = false,
        Callback    = function(Value)
            autoAttackOn = Value
        end,
    }))

    -- ── Skills Section ────────────────────────────────────────────
    Tabs.Settings:AddSection("Skills")

    Track(Tabs.Settings:AddDropdown("SkillSelect", {
        Title       = "Auto Skills Select",
        Description = "Pick skills to auto-fire",
        Values      = {"Z", "X", "C", "V", "F"},
        Multi       = true,
        Default     = {},
        Callback    = function(Value)
            selectedSkills = {}
            if type(Value) == "table" then
                for k, v in pairs(Value) do
                    if v then selectedSkills[k] = true end
                end
            end
        end,
    }))

    Track(Tabs.Settings:AddToggle("AutoSkills", {
        Title       = "Auto Skills",
        Description = "Fire selected skills automatically when Auto Farm is ON",
        Default     = false,
        Callback    = function(Value)
            autoSkillsOn = Value
        end,
    }))

    Track(Tabs.Settings:AddSlider("SkillInterval", {
        Title    = "Skill Interval (s)",
        Description = "Delay between each skill fire",
        Min      = 0.1,
        Max      = 2.0,
        Default  = 0.3,
        Rounding = 1,
        Callback = function(Value)
            skillInterval = Value
        end,
    }))
end

-- ══════════════════════════════════════════════════════════════════════════════
-- ── TAB: CONFIG (Save/Load) ───────────────────────────────────────────────────
-- ══════════════════════════════════════════════════════════════════════════════

SaveManager:SetLibrary(Fluent)
SaveManager:SetFolder(GAME_FOLDER)

InterfaceManager:SetLibrary(Fluent)
InterfaceManager:SetFolder(GAME_FOLDER)
InterfaceManager:BuildInterfaceSection(Tabs.Config)
SaveManager:BuildConfigSection(Tabs.Config)

-- ── Load autosave ─────────────────────────────────────────────────────────────
pcall(function()
    SaveManager:Load(AUTOSAVE_KEY)
end)

-- ── Init: apply saved values ──────────────────────────────────────────────────
task.defer(function()
    if Options.BossSelect and type(Options.BossSelect.Value) == "table" then
        selectedBosses = {}
        for k, v in pairs(Options.BossSelect.Value) do
            if v then selectedBosses[k] = true end
        end
    end

    if Options.MobSelect and type(Options.MobSelect.Value) == "table" then
        selectedMobs = {}
        for k, v in pairs(Options.MobSelect.Value) do
            if v then selectedMobs[k] = true end
        end
    end

    if Options.CollectiblesSelect and type(Options.CollectiblesSelect.Value) == "table" then
        selectedCollectibles = {}
        for k, v in pairs(Options.CollectiblesSelect.Value) do
            if v then selectedCollectibles[k] = true end
        end
    end

    if Options.ArtifactTypeSelect and type(Options.ArtifactTypeSelect.Value) == "table" then
        selectedArtifactTypes = {}
        for k, v in pairs(Options.ArtifactTypeSelect.Value) do
            if v then selectedArtifactTypes[k] = true end
        end
    end

    if Options.ArtifactGradeSelect and type(Options.ArtifactGradeSelect.Value) == "table" then
        selectedArtifactGrades = {}
        for k, v in pairs(Options.ArtifactGradeSelect.Value) do
            if v then selectedArtifactGrades[k] = true end
        end
    end

    if Options.ChestSelect and type(Options.ChestSelect.Value) == "table" then
        selectedChests = {}
        for k, v in pairs(Options.ChestSelect.Value) do
            if v then selectedChests[k] = true end
        end
    end

    if Options.ArtifactUpgradeNotDelete then
        artifactKeepUpgraded = Options.ArtifactUpgradeNotDelete.Value
    end

    if Options.AutoDeleteArtifact and Options.AutoDeleteArtifact.Value then
        autoDeleteArtifactOn = true
        checkAutoDeleteState()
    end

    if Options.AutoChest and Options.AutoChest.Value then
        autoChestEnabled = true
        checkAutoChestState()
    end

    if Options.AutoGetCollectibles and Options.AutoGetCollectibles.Value then
        autoGetEnabled = true
        checkAutoGetState()
    end

    if Options.WeaponSelect    then selectedWeaponName = Options.WeaponSelect.Value   end
    if Options.AutoEquipWeapon then autoEquipEnabled   = Options.AutoEquipWeapon.Value end
    if Options.AutoAttack      then autoAttackOn       = Options.AutoAttack.Value     end
    if Options.AutoSkills      then autoSkillsOn       = Options.AutoSkills.Value     end
    if Options.AttackPosition  then attackPosition     = Options.AttackPosition.Value end
    if Options.AttackDistance  then attackDistance     = Options.AttackDistance.Value end
    if Options.SkillInterval   then skillInterval      = Options.SkillInterval.Value  end

    if Options.SkillSelect and type(Options.SkillSelect.Value) == "table" then
        selectedSkills = {}
        for k, v in pairs(Options.SkillSelect.Value) do
            if v then selectedSkills[k] = true end
        end
    end

    if Options.BusoHaki and Options.BusoHaki.Value then
        busoHakiEnabled = true
        startBusoHakiLoop()
    end

    if Options.KenHaki and Options.KenHaki.Value then
        kenHakiEnabled = true
        startKenHakiLoop()
    end

    if Options.AntiDeath and Options.AntiDeath.Value then
        antiDeathEnabled = true
        startAntiDeath()
    end

    if Options.MobESP and Options.MobESP.Value then
        espEnabled = true
        refreshESP()
    end

    if autoEquipEnabled then
        autoEquipTool()
    end
end)

-- ── Re-apply on respawn ───────────────────────────────────────────────────────
LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(1)
    if Options.BusoHaki and Options.BusoHaki.Value then
        startBusoHakiLoop()
    end
    if Options.KenHaki and Options.KenHaki.Value then
        startKenHakiLoop()
    end
    if autoEquipEnabled or autoMobEnabled or autoBossEnabled then
        task.wait(0.5)
        autoEquipTool()
    end
end)

-- ── Select first tab & notify ─────────────────────────────────────────────────
Window:SelectTab(1)

Fluent:Notify({
    Title    = "BWWA Piece  •  " .. Fluent.Version,
    Content  = "Loaded  •  " .. gameInfo.Name,
    Duration = 5,
})
