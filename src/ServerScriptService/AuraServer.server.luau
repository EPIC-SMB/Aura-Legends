-- Aura Legends — Server (entry point)
-- Owns the economy, receipts, pass privileges and persistence.
-- Clients only send intents; the server decides every outcome.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")
local DataStoreService = game:GetService("DataStoreService")

local Config = require(ReplicatedStorage:WaitForChild("AuraConfig"))

----------------------------------------------------------------
-- Config validation — a bad data edit fails loudly on load
----------------------------------------------------------------
local valid, validationError = pcall(function()
    return Config.validate()
end)
if not valid then
    error("[AuraLegends] Config validation failed: " .. tostring(validationError))
end
print("[AuraLegends] Config v" .. Config.VERSION .. " validated OK")

----------------------------------------------------------------
-- Remotes — created synchronously before any handler connects
----------------------------------------------------------------
local Remotes = Instance.new("Folder")
Remotes.Name = "AuraRemotes"

local function makeRemote(className, name)
    local remote = Instance.new(className)
    remote.Name = name
    remote.Parent = Remotes
    return remote
end

local TrainRemote = makeRemote("RemoteEvent", "Train")
local BuyUpgradeRemote = makeRemote("RemoteEvent", "BuyUpgrade")
local ClaimDailyRemote = makeRemote("RemoteEvent", "ClaimDaily")
local BuyCapsuleRemote = makeRemote("RemoteEvent", "BuyCapsule")
local EnterZoneRemote = makeRemote("RemoteEvent", "EnterZone")
local AttackRemote = makeRemote("RemoteEvent", "Attack")
local StateRemote = makeRemote("RemoteEvent", "State")
Remotes.Parent = ReplicatedStorage

----------------------------------------------------------------
-- Persistence — DataStore when available, in-memory fallback
----------------------------------------------------------------
local store = nil
local useDataStore = false
local memoryStore = {}

local storeOk, storeResult = pcall(function()
    return DataStoreService:GetDataStore("AuraLegends_v1")
end)
if storeOk and storeResult then
    store = storeResult
    useDataStore = true
    print("[AuraLegends] DataStore connected")
else
    warn("[AuraLegends] DataStore unavailable (" .. tostring(storeResult) .. ") — using in-memory persistence")
end

----------------------------------------------------------------
-- Session state
----------------------------------------------------------------
local sessions = {}

local RATE_LIMIT = 10
local RATE_WINDOW = 1

local function defaultProfile()
    return {
        Energy = 0,
        LifetimeEnergy = 0,
        Power = 0,
        Stamina = 0,
        Magnet = 0,
        Auras = {},
        EquippedAura = "",
        CurrentZone = 1,
        MaxZone = 1,
        BossKills = 0,
        TotalTrains = 0,
        DailyStreak = 0,
        DailyDay = 0,
        LastLoginDay = 0,
        RespawnTokens = 0,
        TotalPlaySeconds = 0,
    }
end

local function loadProfile(userId)
    local key = "player_" .. userId
    local profile = nil

    if useDataStore and store then
        local ok, data = pcall(function()
            return store:GetAsync(key)
        end)
        if ok and type(data) == "table" then
            profile = data
        end
    else
        profile = memoryStore[key]
    end

    profile = profile or defaultProfile()

    -- Forward-fill new fields onto old saves instead of resetting them.
    local base = defaultProfile()
    for field, value in pairs(base) do
        if profile[field] == nil then
            profile[field] = value
        end
    end
    return profile
end

local function saveProfile(player)
    local session = sessions[player.UserId]
    if not session then
        return
    end
    local key = "player_" .. player.UserId
    if useDataStore and store then
        local ok, err = pcall(function()
            store:SetAsync(key, session.Profile)
        end)
        if not ok then
            warn("[AuraLegends] Save failed for " .. player.Name .. ": " .. tostring(err))
        end
    else
        memoryStore[key] = session.Profile
    end
end

----------------------------------------------------------------
-- Economy helpers
----------------------------------------------------------------
local function energyMultiplier(player)
    local session = sessions[player.UserId]
    if not session then
        return 1
    end
    local multiplier = 1
    if session.Passes.VIP then
        multiplier = multiplier * Config.PASSES.VIP.EnergyMultiplier
    end
    if session.BoostExpires > os.time() then
        multiplier = multiplier * 2
    end
    return multiplier
end

local function addEnergy(player, amount, reason)
    local session = sessions[player.UserId]
    if not session then
        return 0
    end
    local gained = math.floor(amount * energyMultiplier(player))
    session.Profile.Energy = session.Profile.Energy + gained
    session.Profile.LifetimeEnergy = session.Profile.LifetimeEnergy + gained
    StateRemote:FireClient(player, "EnergyChanged", session.Profile.Energy, gained, reason or "gain")
    return gained
end

local function isRateLimited(player, action)
    local session = sessions[player.UserId]
    if not session then
        return true
    end
    local bucket = session.RateBuckets[action]
    if bucket == nil then
        bucket = { Count = 0, WindowStart = tick() }
        session.RateBuckets[action] = bucket
    end
    if tick() - bucket.WindowStart >= RATE_WINDOW then
        bucket.Count = 0
        bucket.WindowStart = tick()
    end
    bucket.Count = bucket.Count + 1
    return bucket.Count > RATE_LIMIT
end

----------------------------------------------------------------
-- Arena
----------------------------------------------------------------
local arenaFolder = Instance.new("Folder")
arenaFolder.Name = "AuraArena"
arenaFolder.Parent = workspace

local bossFolder = Instance.new("Folder")
bossFolder.Name = "AuraBosses"
bossFolder.Parent = workspace

local function buildArena()
    local base = Instance.new("Part")
    base.Name = "Baseplate"
    base.Size = Vector3.new(220, 2, 220)
    base.Position = Vector3.new(0, -1, 0)
    base.Anchored = true
    base.Material = Enum.Material.Grass
    base.Color = Color3.fromRGB(58, 138, 74)
    base.TopSurface = Enum.SurfaceType.Smooth
    base.BottomSurface = Enum.SurfaceType.Smooth
    base.Parent = arenaFolder

    -- Roblox avatars spawn facing -z, and the default camera sits behind them
    -- looking -z too. The whole arena is laid out along -z so the boss is
    -- directly in front of the player the moment a fight starts.
    local spawn = Instance.new("SpawnLocation")
    spawn.Name = "Spawn"
    spawn.Size = Vector3.new(14, 1, 14)
    spawn.Position = Vector3.new(0, 0.5, 0)
    spawn.Anchored = true
    spawn.Neutral = true
    spawn.Material = Enum.Material.Neon
    spawn.Color = Color3.fromRGB(120, 200, 255)
    spawn.TopSurface = Enum.SurfaceType.Smooth
    spawn.BottomSurface = Enum.SurfaceType.Smooth
    spawn.Parent = arenaFolder

    -- Boss platform sits directly ahead of the spawn (spawn at z=0, platform
    -- spans z=-75..5) so the fight is in view the moment it starts.
    local platform = Instance.new("Part")
    platform.Name = "BossPlatform"
    platform.Size = Vector3.new(100, 1, 80)
    platform.Position = Vector3.new(0, 0.5, -35)
    platform.Anchored = true
    platform.Material = Enum.Material.SmoothPlastic
    platform.Color = Color3.fromRGB(34, 34, 50)
    platform.TopSurface = Enum.SurfaceType.Smooth
    platform.BottomSurface = Enum.SurfaceType.Smooth
    platform.Parent = arenaFolder

    -- Beacon marks the arena from anywhere on the map.
    local beacon = Instance.new("Part")
    beacon.Name = "BossBeacon"
    beacon.Size = Vector3.new(3, 70, 3)
    beacon.Position = Vector3.new(0, 36, -70)
    beacon.Anchored = true
    beacon.Material = Enum.Material.Neon
    beacon.Color = Color3.fromRGB(255, 70, 70)
    beacon.Transparency = 0.4
    beacon.CanCollide = false
    beacon.Parent = arenaFolder

    -- Zone pads line the sides so they never sit between the player and the boss.
    for i, zone in ipairs(Config.ZONES) do
        local pad = Instance.new("Part")
        pad.Name = "ZonePad_" .. i
        pad.Size = Vector3.new(12, 1, 12)
        local side = (i % 2 == 1) and -1 or 1
        local row = math.ceil(i / 2)
        pad.Position = Vector3.new(side * 85, 0.5, -20 - (row - 1) * 35)
        pad.Anchored = true
        pad.Material = Enum.Material.Neon
        pad.Color = Color3.fromRGB(255, 200, 80)
        pad.TopSurface = Enum.SurfaceType.Smooth
        pad.BottomSurface = Enum.SurfaceType.Smooth
        pad.Parent = arenaFolder

        local label = Instance.new("BillboardGui")
        label.Size = UDim2.new(0, 280, 0, 40)
        label.StudsOffset = Vector3.new(0, 5, 0)
        label.AlwaysOnTop = true
        local text = Instance.new("TextLabel")
        text.Size = UDim2.new(1, 0, 1, 0)
        text.BackgroundTransparency = 1
        text.Font = Enum.Font.GothamBold
        text.TextSize = 20
        text.TextColor3 = Color3.fromRGB(255, 255, 255)
        text.TextStrokeTransparency = 0.5
        text.Text = i .. ". " .. zone.Name
        text.Parent = label
        label.Parent = pad
    end
end

buildArena()

----------------------------------------------------------------
-- Boss encounters
----------------------------------------------------------------
local function playerMaxHealth(session)
    return Config.STAMINA.BaseHealth + (session.Profile.Stamina * Config.STAMINA.HealthPerLevel)
end

local function playerDamage(session)
    return Config.POWER.BaseDamage + (session.Profile.Power * Config.POWER.DamagePerLevel)
end

local function despawnBoss(player)
    local existing = bossFolder:FindFirstChild("Boss_" .. player.UserId)
    if existing then
        existing:Destroy()
    end
end

local function spawnBoss(player, zone)
    despawnBoss(player)

    local model = Instance.new("Model")
    model.Name = "Boss_" .. player.UserId

    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = Vector3.new(20, 20, 20)
    body.Position = Vector3.new(0, 11, -45)
    body.Anchored = true
    body.Material = Enum.Material.Neon
    body.Color = Color3.fromRGB(255, 70, 70)
    body.CanCollide = true
    body.Parent = model

    local nameTag = Instance.new("BillboardGui")
    nameTag.Size = UDim2.new(0, 340, 0, 74)
    nameTag.StudsOffset = Vector3.new(0, 16, 0)
    nameTag.AlwaysOnTop = true

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 30)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 22
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextStrokeTransparency = 0.5
    title.Text = zone.Boss
    title.Parent = nameTag

    local hpText = Instance.new("TextLabel")
    hpText.Size = UDim2.new(1, 0, 0, 24)
    hpText.Position = UDim2.new(0, 0, 0, 34)
    hpText.BackgroundTransparency = 1
    hpText.Font = Enum.Font.GothamBold
    hpText.TextSize = 18
    hpText.TextColor3 = Color3.fromRGB(255, 210, 110)
    hpText.TextStrokeTransparency = 0.5
    hpText.Text = tostring(zone.BossHP) .. " / " .. tostring(zone.BossHP)
    hpText.Parent = nameTag

    nameTag.Parent = body
    model.PrimaryPart = body
    model.Parent = bossFolder
end

local function stopBossLoop(session)
    local thread = session.BossThread
    session.BossThread = nil
    if thread then
        -- task.cancel throws "cannot cancel thread" when the target is the
        -- thread currently running, so never call this from the boss loop.
        pcall(task.cancel, thread)
    end
end

local onPlayerDied

local function startBossLoop(player, session)
    stopBossLoop(session)
    session.BossThread = task.spawn(function()
        while true do
            local boss = session.Boss
            if boss == nil or boss.Alive ~= true then
                break
            end
            task.wait(boss.AttackInterval)
            if session.Boss ~= boss or boss.Alive ~= true then
                break
            end
            if sessions[player.UserId] ~= session then
                break
            end
            session.HP = session.HP - boss.Damage
            workspace:SetAttribute("AuraDbgPlayerHP", session.HP)
            StateRemote:FireClient(player, "PlayerDamaged", session.HP, session.MaxHP, boss.Damage)
            if session.HP <= 0 then
                onPlayerDied(player, session)
                break
            end
        end
    end)
end

onPlayerDied = function(player, session)
    if session.Dead then
        return
    end
    session.Dead = true
    session.HP = 0
    -- Deliberately NOT calling stopBossLoop here: this runs on the boss loop's
    -- own thread, and task.cancel cannot cancel the running thread. The loop
    -- breaks immediately after calling this function.
    despawnBoss(player)
    session.Boss = nil
    StateRemote:FireClient(player, "PlayerDied", Config.PLAYER.RespawnSeconds)
    task.delay(Config.PLAYER.RespawnSeconds, function()
        if sessions[player.UserId] ~= session then
            return
        end
        session.Dead = false
        session.HP = playerMaxHealth(session)
        session.MaxHP = session.HP
        pcall(function()
            player:LoadCharacter()
        end)
        StateRemote:FireClient(player, "PlayerRespawned", session.HP, session.MaxHP)
    end)
end

local function rollAura(player, session)
    local chance = Config.PLAYER.AuraDropChance
    if session.Passes.LuckyAura then
        chance = chance + Config.PASSES.LuckyAura.DropBonus
    end
    if math.random() > chance then
        return
    end

    local roll = math.random(1, 100)
    local cumulative = 0
    for _, aura in ipairs(Config.AURAS) do
        cumulative = cumulative + aura.Weight
        if roll <= cumulative then
            session.Profile.Auras[#session.Profile.Auras + 1] = aura.Id
            workspace:SetAttribute("AuraDbgAuras", table.concat(session.Profile.Auras, ","))
            StateRemote:FireClient(player, "AuraUnlocked", aura.Id, aura.Rarity, chance)
            break
        end
    end
end

----------------------------------------------------------------
-- Compliance gates
----------------------------------------------------------------
local function applyPolicyGate(player)
    local session = sessions[player.UserId]
    if not session then
        return
    end
    -- Fail closed: unknown eligibility means restricted.
    session.PaidRandomAllowed = false
    session.PaidTradingAllowed = false
    local ok, info = pcall(function()
        return PolicyService:GetPolicyInfoForPlayerAsync(player)
    end)
    if ok and type(info) == "table" then
        session.PaidRandomAllowed = (info.ArePaidRandomItemsRestricted == false)
        session.PaidTradingAllowed = (info.IsPaidItemTradingAllowed == true)
    end
    StateRemote:FireClient(player, "PolicyChanged", session.PaidRandomAllowed, session.PaidTradingAllowed)
end

local function applyPasses(player)
    local session = sessions[player.UserId]
    if not session then
        return
    end
    for key, definition in pairs(Config.PASSES) do
        local owns = false
        if definition.Id ~= 0 then
            local ok, result = pcall(function()
                return MarketplaceService:UserOwnsGamePassAsync(player.UserId, definition.Id)
            end)
            owns = (ok and result == true)
        end
        session.Passes[key] = owns
    end
    StateRemote:FireClient(player, "PassesChanged", session.Passes)
end

----------------------------------------------------------------
-- Receipts
----------------------------------------------------------------
local keyByProductId = {}
for key, definition in pairs(Config.PRODUCTS) do
    if definition.Id ~= 0 then
        keyByProductId[definition.Id] = key
    end
end

local processedReceipts = {}

local grantPaidRandomOutcome

local function grantProduct(player, productKey)
    local session = sessions[player.UserId]
    if not session then
        return false
    end
    local definition = Config.PRODUCTS[productKey]
    if not definition then
        return false
    end

    if definition.Amount then
        addEnergy(player, definition.Amount, "product:" .. productKey)
    elseif productKey == "RespawnToken" then
        session.Profile.RespawnTokens = session.Profile.RespawnTokens + 1
        StateRemote:FireClient(player, "RespawnTokensChanged", session.Profile.RespawnTokens)
    elseif productKey == "Boost2x1H" then
        session.BoostExpires = os.time() + 3600
        StateRemote:FireClient(player, "BoostChanged", session.BoostExpires)
    elseif definition.PaidRandom then
        local roll = math.random(1, 100)
        local cumulative = 0
        for _, outcome in ipairs(definition.Odds) do
            cumulative = cumulative + outcome.Weight
            if roll <= cumulative then
                grantPaidRandomOutcome(player, outcome)
                break
            end
        end
    end
    return true
end

grantPaidRandomOutcome = function(player, outcome)
    local session = sessions[player.UserId]
    if not session then
        return
    end
    if outcome.Energy then
        addEnergy(player, outcome.Energy, "capsule")
    else
        local pool = {}
        for _, aura in ipairs(Config.AURAS) do
            if aura.Rarity == outcome.Rarity then
                pool[#pool + 1] = aura.Id
            end
        end
        if #pool > 0 then
            local chosen = pool[math.random(1, #pool)]
            session.Profile.Auras[#session.Profile.Auras + 1] = chosen
            StateRemote:FireClient(player, "AuraUnlocked", chosen)
        end
    end
    StateRemote:FireClient(player, "CapsuleOpened", outcome.Outcome, outcome.Rarity)
end

local function processReceipt(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local productKey = keyByProductId[receiptInfo.ProductId]
    if not productKey then
        warn("[AuraLegends] Unknown product id: " .. tostring(receiptInfo.ProductId))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- Idempotency: a re-delivered receipt must never double-grant.
    if processedReceipts[receiptInfo.PurchaseId] then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    local granted = grantProduct(player, productKey)
    if not granted then
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    processedReceipts[receiptInfo.PurchaseId] = true
    saveProfile(player)
    return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
    if not purchased then
        return
    end
    for key, definition in pairs(Config.PASSES) do
        if definition.Id ~= 0 and definition.Id == passId then
            local session = sessions[player.UserId]
            if session then
                session.Passes[key] = true
                StateRemote:FireClient(player, "PassesChanged", session.Passes)
                saveProfile(player)
            end
        end
    end
end)

----------------------------------------------------------------
-- Player lifecycle
----------------------------------------------------------------
local function onPlayerAdded(player)
    sessions[player.UserId] = {
        Profile = loadProfile(player.UserId),
        Passes = {},
        RateBuckets = {},
        BoostExpires = 0,
        PaidRandomAllowed = false,
        PaidTradingAllowed = false,
        Boss = nil,
        BossThread = nil,
        HP = 0,
        MaxHP = 0,
        Dead = false,
        LastAttack = 0,
    }
    applyPolicyGate(player)
    applyPasses(player)

    local session = sessions[player.UserId]
    session.HP = playerMaxHealth(session)
    session.MaxHP = session.HP

    StateRemote:FireClient(player, "Loaded", {
        Energy = session.Profile.Energy,
        Power = session.Profile.Power,
        Stamina = session.Profile.Stamina,
        Magnet = session.Profile.Magnet,
        Auras = session.Profile.Auras,
        CurrentZone = session.Profile.CurrentZone,
        MaxZone = session.Profile.MaxZone,
        HP = session.HP,
        MaxHP = session.MaxHP,
        DailyStreak = session.Profile.DailyStreak,
        PaidRandomAllowed = session.PaidRandomAllowed,
        Passes = session.Passes,
    })
    print("[AuraLegends] " .. player.Name .. " joined (Energy " .. session.Profile.Energy .. ")")
end

local function onPlayerRemoving(player)
    local session = sessions[player.UserId]
    if session then
        stopBossLoop(session)
    end
    despawnBoss(player)
    saveProfile(player)
    sessions[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

----------------------------------------------------------------
-- Remote handlers
----------------------------------------------------------------
TrainRemote.OnServerEvent:Connect(function(player)
    if isRateLimited(player, "Train") then
        return
    end
    local session = sessions[player.UserId]
    if not session then
        return
    end
    local gain = Config.TRAIN.BaseGain + (session.Profile.Power * Config.TRAIN.PerPowerLevel)
    local gained = addEnergy(player, gain, "train")
    session.Profile.TotalTrains = session.Profile.TotalTrains + 1
    StateRemote:FireClient(player, "Trained", gained, session.Profile.Energy)
end)

BuyUpgradeRemote.OnServerEvent:Connect(function(player, upgradeKey)
    if type(upgradeKey) ~= "string" then
        return
    end
    if isRateLimited(player, "BuyUpgrade") then
        return
    end
    local definition = Config.UPGRADES[upgradeKey]
    if not definition then
        return
    end
    local session = sessions[player.UserId]
    if not session then
        return
    end

    local current = session.Profile[upgradeKey]
    if current >= definition.MaxLevel then
        StateRemote:FireClient(player, "UpgradeFailed", upgradeKey, "Max level reached")
        return
    end

    local cost = math.floor(definition.BaseCost + (current * definition.CostPerLevel))
    if session.Profile.Energy < cost then
        StateRemote:FireClient(player, "UpgradeFailed", upgradeKey, "Not enough Energy")
        return
    end

    session.Profile.Energy = session.Profile.Energy - cost
    session.Profile[upgradeKey] = current + 1
    StateRemote:FireClient(player, "UpgradeChanged", upgradeKey, current + 1, cost, session.Profile.Energy)
    saveProfile(player)
end)

ClaimDailyRemote.OnServerEvent:Connect(function(player)
    if isRateLimited(player, "ClaimDaily") then
        return
    end
    local session = sessions[player.UserId]
    if not session then
        return
    end

    local today = math.floor(os.time() / 86400)
    if session.Profile.LastLoginDay == today then
        StateRemote:FireClient(player, "DailyFailed", "Already claimed today")
        return
    end

    local gap = today - session.Profile.LastLoginDay
    if gap == 1 then
        session.Profile.DailyStreak = session.Profile.DailyStreak + 1
    else
        session.Profile.DailyStreak = 1
    end

    local dayIndex = ((session.Profile.DailyStreak - 1) % Config.DAILY.DayCount) + 1
    local reward = Config.DAILY.Rewards[dayIndex]
    session.Profile.DailyDay = dayIndex
    session.Profile.LastLoginDay = today
    addEnergy(player, reward, "daily")

    StateRemote:FireClient(player, "DailyClaimed", dayIndex, reward, session.Profile.DailyStreak)
    saveProfile(player)
end)

BuyCapsuleRemote.OnServerEvent:Connect(function(player)
    if isRateLimited(player, "BuyCapsule") then
        return
    end
    local session = sessions[player.UserId]
    if not session then
        return
    end

    local definition = Config.PRODUCTS.MysteryAura

    -- Paid random items policy: restricted users never get charged.
    if session.PaidRandomAllowed ~= true then
        StateRemote:FireClient(player, "CapsuleRestricted", definition.Name, definition.FreeEarnable)
        return
    end
    if definition.Id == 0 then
        StateRemote:FireClient(player, "CapsulePending", definition.Name)
        return
    end

    local ok, err = pcall(function()
        MarketplaceService:PromptProductPurchase(player, definition.Id)
    end)
    if not ok then
        warn("[AuraLegends] PromptProductPurchase failed: " .. tostring(err))
    end
end)

local function enterZone(player, zoneIndex)
    if type(zoneIndex) ~= "number" then
        return
    end
    if zoneIndex < 1 or zoneIndex > #Config.ZONES then
        return
    end
    local session = sessions[player.UserId]
    if not session then
        return
    end
    if session.Dead then
        return
    end

    local zone = Config.ZONES[zoneIndex]
    local damage = playerDamage(session)
    if zoneIndex > session.Profile.MaxZone or damage < zone.RequiredPower then
        StateRemote:FireClient(player, "ZoneLocked", zoneIndex, zone.RequiredPower, damage, session.Profile.MaxZone)
        return
    end

    stopBossLoop(session)
    despawnBoss(player)

    session.Boss = {
        Zone = zoneIndex,
        HP = zone.BossHP,
        MaxHP = zone.BossHP,
        Alive = true,
        Damage = zone.BossDamage,
        AttackInterval = zone.BossAttackInterval,
        Name = zone.Boss,
    }
    session.HP = playerMaxHealth(session)
    session.MaxHP = session.HP
    session.Profile.CurrentZone = zoneIndex

    spawnBoss(player, zone)
    startBossLoop(player, session)

    workspace:SetAttribute("AuraDbgBossHP", session.Boss.HP)
    workspace:SetAttribute("AuraDbgBossZone", zoneIndex)
    workspace:SetAttribute("AuraDbgPlayerHP", session.HP)

    StateRemote:FireClient(player, "ZoneEntered", zoneIndex, zone, session.Boss.HP, session.Boss.MaxHP, session.HP, session.MaxHP)
end

EnterZoneRemote.OnServerEvent:Connect(function(player, zoneIndex)
    if isRateLimited(player, "EnterZone") then
        return
    end
    enterZone(player, zoneIndex)
end)

AttackRemote.OnServerEvent:Connect(function(player, zoneIndex)
    if type(zoneIndex) ~= "number" then
        return
    end
    if isRateLimited(player, "Attack") then
        return
    end

    local session = sessions[player.UserId]
    if not session then
        return
    end
    if session.Dead then
        return
    end
    if session.Boss == nil or session.Boss.Alive ~= true then
        return
    end
    if session.Boss.Zone ~= zoneIndex then
        return
    end

    -- Per-action cooldown, independent of the global rate limit.
    local now = tick()
    if now - session.LastAttack < Config.PLAYER.AttackInterval then
        return
    end
    session.LastAttack = now

    local damage = playerDamage(session)
    session.Boss.HP = session.Boss.HP - damage
    workspace:SetAttribute("AuraDbgBossHP", session.Boss.HP)
    StateRemote:FireClient(player, "BossDamaged", session.Boss.HP, session.Boss.MaxHP, damage)

    if session.Boss.HP <= 0 then
        session.Boss.HP = 0
        session.Boss.Alive = false
        stopBossLoop(session)
        despawnBoss(player)
        workspace:SetAttribute("AuraDbgBossHP", 0)
        workspace:SetAttribute("AuraDbgBossZone", 0)

        local zone = Config.ZONES[zoneIndex]
        session.Profile.BossKills = session.Profile.BossKills + 1
        if zoneIndex < #Config.ZONES then
            session.Profile.MaxZone = math.max(session.Profile.MaxZone, zoneIndex + 1)
        end
        addEnergy(player, zone.Reward, "boss:" .. zone.Boss)
        rollAura(player, session)
        session.Boss = nil

        StateRemote:FireClient(player, "BossDied", zoneIndex, zone.Boss, zone.Reward, session.Profile.MaxZone)
        saveProfile(player)
    end
end)

----------------------------------------------------------------
-- Autosave
----------------------------------------------------------------
task.spawn(function()
    while true do
        task.wait(60)
        for _, player in ipairs(Players:GetPlayers()) do
            saveProfile(player)
        end
    end
end)

----------------------------------------------------------------
-- Debug attributes — used by the Studio MCP verification step.
-- REMOVE before shipping.
----------------------------------------------------------------
workspace:SetAttribute("AuraServerReady", true)
workspace:SetAttribute("AuraConfigVersion", Config.VERSION)
workspace:SetAttribute("AuraZoneCount", #Config.ZONES)
workspace:SetAttribute("AuraProductCount", (function()
    local count = 0
    for _ in pairs(Config.PRODUCTS) do
        count = count + 1
    end
    return count
end)())

print("[AuraLegends] Server ready — " .. #Config.ZONES .. " zones, " .. #Config.AURAS .. " auras")
