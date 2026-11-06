-- Aura Legends — Config
-- Single source of truth for every balance number, price, loot table and
-- compliance answer. Data-driven so balance changes never touch a script.
--
-- Roblox Creator Hub rules this file is built around:
--   * Passes are one-time permanent privileges.
--   * Developer products are repeatable.
--   * Paid random items must disclose every outcome with exact odds that sum
--     to exactly 100%, and restricted users need an earnable alternative.
--   * Free players must have a complete loop with a real currency sink.

local Config = {}

Config.GAME_NAME = "Aura Legends"
Config.VERSION = "0.1.0"

----------------------------------------------------------------
-- FREE CURRENCY  (Energy — earnable by playing, spendable in the shop)
----------------------------------------------------------------
Config.ENERGY = {
    WaveBaseReward = 25,
    BossBaseReward = 250,
}

Config.TRAIN = {
    BaseGain = 1,
    PerPowerLevel = 0.5,
}

----------------------------------------------------------------
-- FREE-CURRENCY SINKS  (upgrades — playing buys power)
-- Cost formula: BaseCost + (currentLevel * CostPerLevel) — linear,
-- so the grind stays predictable instead of exploding exponentially.
----------------------------------------------------------------
Config.UPGRADES = {
    Power = {
        Name = "Power",
        Description = "+8 damage per level",
        Currency = "Energy",
        MaxLevel = 100,
        BaseCost = 10,
        CostPerLevel = 5,
        EffectPerLevel = 8,
    },
    Stamina = {
        Name = "Stamina",
        Description = "+40 max health per level",
        Currency = "Energy",
        MaxLevel = 60,
        BaseCost = 15,
        CostPerLevel = 6,
        EffectPerLevel = 40,
    },
    Magnet = {
        Name = "Aura Magnet",
        Description = "+6 pickup radius per level",
        Currency = "Energy",
        MaxLevel = 25,
        BaseCost = 20,
        CostPerLevel = 6,
        EffectPerLevel = 6,
    },
}

Config.POWER = {
    BaseDamage = 10,
    DamagePerLevel = 8,
}

Config.STAMINA = {
    BaseHealth = 100,
    HealthPerLevel = 40,
}

----------------------------------------------------------------
-- AURAS  (collectible powers — drop weights must sum to exactly 100)
----------------------------------------------------------------
Config.AURAS = {
    { Id = "Flame",   Rarity = "Common",    Weight = 40, Power = "Ignite", Color = Color3.fromRGB(255,  94,  40) },
    { Id = "Frost",   Rarity = "Common",    Weight = 30, Power = "Freeze", Color = Color3.fromRGB( 90, 190, 255) },
    { Id = "Storm",   Rarity = "Uncommon",  Weight = 18, Power = "Surge",  Color = Color3.fromRGB(255, 220,  80) },
    { Id = "Shadow",  Rarity = "Rare",      Weight =  9, Power = "Phase",  Color = Color3.fromRGB(150,  90, 255) },
    { Id = "Radiant", Rarity = "Legendary", Weight =  3, Power = "Nova",   Color = Color3.fromRGB(255, 255, 255) },
}

----------------------------------------------------------------
-- ZONES & BOSSES
----------------------------------------------------------------
Config.ZONES = {
    { Name = "Ember Forest", Boss = "Cinder Wolf",    BossHP =   300, RequiredPower =  1, Reward =   300, BossDamage =  4, BossAttackInterval = 2.5 },
    { Name = "Frost Peak",   Boss = "Glacier Bear",   BossHP =  1000, RequiredPower = 15, Reward =  1200, BossDamage = 10, BossAttackInterval = 2.2 },
    { Name = "Storm Coast",  Boss = "Tempest Kraken", BossHP =  3000, RequiredPower = 35, Reward =  4000, BossDamage = 22, BossAttackInterval = 2.0 },
    { Name = "Shadow Rift",  Boss = "Umbra Revenant", BossHP =  5000, RequiredPower = 60, Reward =  8000, BossDamage = 45, BossAttackInterval = 1.8 },
    { Name = "Radiant Core", Boss = "Solar Seraph",   BossHP =  6000, RequiredPower = 90, Reward = 20000, BossDamage = 50, BossAttackInterval = 1.5 },
}

Config.PLAYER = {
    RespawnSeconds = 3,
    AttackInterval = 0.5,
    AuraDropChance = 0.15,
}

----------------------------------------------------------------
-- PASSES  (one-time permanent privileges)
----------------------------------------------------------------
Config.PASSES = {
    VIP = {
        Id = 0,
        Price = 199,
        Name = "VIP",
        Description = "2x Energy, exclusive VIP zone, golden aura trail",
        Perks = { "EnergyBoost", "VIPZone", "GoldenAura" },
        EnergyMultiplier = 2,
    },
    AutoTrain = {
        Id = 0,
        Price = 149,
        Name = "Auto Train",
        Description = "Passively generates Energy while you play",
        Perks = { "AutoTrain" },
        AutoRatePerSecond = 2,
    },
    LuckyAura = {
        Id = 0,
        Price = 99,
        Name = "Lucky Aura",
        Description = "+25% Aura drop chance (in-game odds update while active)",
        Perks = { "LuckyAura" },
        DropBonus = 0.25,
    },
    PetSlot = {
        Id = 0,
        Price = 79,
        Name = "Extra Pet Slot",
        Description = "Carry one additional companion",
        Perks = { "ExtraPetSlot" },
        ExtraSlots = 1,
    },
}

----------------------------------------------------------------
-- DEVELOPER PRODUCTS  (repeatable)
-- Paid random items carry an Odds table: Weight and DisplayPct must both
-- sum to exactly 100. Restricted users must have an earnable alternative.
----------------------------------------------------------------
Config.PRODUCTS = {
    EnergyPackSmall = { Id = 0, Price = 49,  Amount = 500,   Name = "500 Energy" },
    EnergyPackMedium = { Id = 0, Price = 149, Amount = 2000,  Name = "2,000 Energy" },
    EnergyPackLarge = { Id = 0, Price = 499, Amount = 7500,  Name = "7,500 Energy" },
    EnergyPackMega = { Id = 0, Price = 999, Amount = 20000, Name = "20,000 Energy" },
    RespawnToken = { Id = 0, Price = 25, Name = "Instant Respawn" },
    Boost2x1H = { Id = 0, Price = 69, Name = "2x Energy (1 hour)" },

    MysteryAura = {
        Id = 0,
        Price = 99,
        Name = "Mystery Aura Capsule",
        PaidRandom = true,
        FreeEarnable = true,
        BossDropChance = 0.05,
        Odds = {
            { Outcome = "500 Energy (Common Shards)",    Weight = 60, DisplayPct = 60, Rarity = "Common",    Energy = 500 },
            { Outcome = "1500 Energy (Uncommon Shards)", Weight = 25, DisplayPct = 25, Rarity = "Uncommon",  Energy = 1500 },
            { Outcome = "A random Rare Aura",            Weight = 10, DisplayPct = 10, Rarity = "Rare" },
            { Outcome = "A random Legendary Aura",       Weight =  5, DisplayPct =  5, Rarity = "Legendary" },
        },
    },
}

----------------------------------------------------------------
-- DAILY LOGIN / STREAK
----------------------------------------------------------------
Config.DAILY = {
    DayCount = 7,
    Rewards = { 50, 75, 100, 150, 200, 300, 500 },
    StreakResetHours = 36,
    StreakBonusCap = 3,
}

----------------------------------------------------------------
-- ENGAGEMENT TUNING  (psychology systems — all truthful, no fake timers)
----------------------------------------------------------------
Config.ENGAGEMENT = {
    NearMissThreshold = 0.5,
    ProgressMilestones = { 0.25, 0.5, 0.75, 0.9 },
    SocialProofMinPlayers = 1,
    DailyBonusCap = 3,
}

----------------------------------------------------------------
-- MATURITY & COMPLIANCE  (mirror of the Creator Dashboard questionnaire)
----------------------------------------------------------------
Config.MATURITY = {
    Label = "Mild",
    Answers = {
        ContainsViolence = true,
        ViolenceIntensity = "Mild, stylized, cartoonish — no blood or gore",
        ContainsFear = false,
        ContainsCrudeHumor = false,
        ContainsPaidRandomItems = true,
        ContainsPaidItemTrading = false,
        ContainsAds = false,
    },
    Notes = "Stylized cartoon combat with no realistic blood. Paid random items use disclosed odds that sum to 100% and are gated by PolicyService with a free earnable path.",
}

----------------------------------------------------------------
-- VALIDATION  (runs on load — a bad edit fails loudly instead of shipping)
----------------------------------------------------------------
local function contains(list, value)
    for _, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

function Config.validateAuras()
    local total = 0
    local seen = {}
    for _, aura in ipairs(Config.AURAS) do
        assert(aura.Id ~= nil, "Aura missing Id")
        assert(aura.Weight ~= nil, "Aura missing Weight: " .. tostring(aura.Id))
        assert(not contains(seen, aura.Id), "Duplicate aura Id: " .. tostring(aura.Id))
        seen[#seen + 1] = aura.Id
        total = total + aura.Weight
    end
    assert(total == 100, "Aura drop weights sum to " .. total .. ", expected exactly 100")
end

function Config.validateProducts()
    for key, definition in pairs(Config.PRODUCTS) do
        assert(definition.Id ~= nil, "Product missing Id: " .. tostring(key))
        assert(definition.Price >= 1, "Product price below 1 Robux: " .. tostring(key))
        if definition.PaidRandom then
            assert(type(definition.Odds) == "table", "Paid random product without Odds: " .. tostring(key))
            local weightTotal = 0
            local displayTotal = 0
            for _, outcome in ipairs(definition.Odds) do
                weightTotal = weightTotal + (outcome.Weight or 0)
                displayTotal = displayTotal + (outcome.DisplayPct or 0)
            end
            assert(weightTotal == 100, key .. " odds weights sum to " .. weightTotal .. ", expected exactly 100")
            assert(displayTotal == 100, key .. " displayed odds sum to " .. displayTotal .. ", expected exactly 100")
            assert(definition.FreeEarnable or definition.BossDropChance,
                key .. " needs a free earnable path or boss drop for restricted users")
        end
    end
end

function Config.validatePasses()
    for key, definition in pairs(Config.PASSES) do
        assert(definition.Id ~= nil, "Pass missing Id: " .. tostring(key))
        assert(definition.Price >= 1, "Pass price below 1 Robux: " .. tostring(key))
    end
end

function Config.validateUpgrades()
    for key, definition in pairs(Config.UPGRADES) do
        assert(definition.Currency == "Energy", "Upgrade " .. tostring(key) .. " must use the free Energy currency")
        assert(definition.MaxLevel > 0, "Upgrade " .. tostring(key) .. " MaxLevel must be positive")
        assert(definition.BaseCost > 0, "Upgrade " .. tostring(key) .. " BaseCost must be positive")
        assert(definition.CostPerLevel > 0, "Upgrade " .. tostring(key) .. " CostPerLevel must be positive")
    end
end

-- Design invariant: a player who meets the zone's power requirement and has
-- invested 40% of max Stamina must be able to win the fight. Catches a
-- mathematically unwinnable boss at load time instead of in playtesting.
function Config.validateBalance()
    local staminaLevel = math.floor(Config.UPGRADES.Stamina.MaxLevel * 0.4)
    local hp = Config.STAMINA.BaseHealth + (staminaLevel * Config.STAMINA.HealthPerLevel)
    for _, zone in ipairs(Config.ZONES) do
        local damage = math.max(zone.RequiredPower, Config.POWER.BaseDamage) * 1.25
        local timeToKill = (zone.BossHP / damage) * Config.PLAYER.AttackInterval
        local timeToDie = (hp / zone.BossDamage) * zone.BossAttackInterval
        assert(timeToKill < timeToDie,
            zone.Name .. " is unwinnable for a mid-investment build: kill takes "
            .. string.format("%.0f", timeToKill) .. "s but the player dies in "
            .. string.format("%.0f", timeToDie) .. "s")
    end
end

function Config.validate()
    Config.validateAuras()
    Config.validateProducts()
    Config.validatePasses()
    Config.validateUpgrades()
    Config.validateBalance()
    return true
end

Config.validate()

return Config
