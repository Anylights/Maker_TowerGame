-- ============================================================================
-- Artifact.lua — 圣器数据 / 背包管理 / 槽位系统 / 掉落逻辑 / 效果应用
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS

local M = {}

-- ============================================================================
-- 圣器数据定义 (最小原型: 6 件普通圣器)
-- 参照 data/artifacts.json + data/balance.json
-- ============================================================================

M.DEFS = {
    -- =========================================================================
    -- 攻击类 (attack) — 13 件
    -- =========================================================================

    -- 白色 ×4
    rapid_fire_module = {
        id = "rapid_fire_module",
        name = "连射模块",
        category = "attack",
        rarity = "white",
        shop_price = 100,
        description = "攻速+50%; 单发伤害-25%",
        stops_tower_attack = false,
        drop_weight = 60,
        effects = {
            { type = "stat_modifier", stat = "attack_speed", modifier = 0.5 },
        },
        downsides = {
            { type = "stat_modifier", stat = "damage", modifier = -0.25 },
        },
    },
    fire_seed = {
        id = "fire_seed",
        name = "火种圣器",
        category = "attack",
        rarity = "white",
        shop_price = 100,
        description = "命中附加燃烧(总伤80%/4秒); 单发伤害-15%",
        stops_tower_attack = false,
        drop_weight = 60,
        effects = {
            { type = "on_hit_status", status = "burn", dot_ratio = 0.20, duration = 4 },
        },
        downsides = {
            { type = "stat_modifier", stat = "damage", modifier = -0.15 },
        },
    },
    ice_crystal = {
        id = "ice_crystal",
        name = "冰晶圣器",
        category = "attack",
        rarity = "white",
        shop_price = 100,
        description = "命中附加1层冰冻; 5层冻结1.5秒; 单发伤害-15%",
        stops_tower_attack = false,
        drop_weight = 60,
        effects = {
            { type = "on_hit_status", status = "freeze", slow_per_stack = 0.3, max_stacks = 5, freeze_duration = 1.5 },
        },
        downsides = {
            { type = "stat_modifier", stat = "damage", modifier = -0.15 },
        },
    },
    corrosion = {
        id = "corrosion",
        name = "腐蚀圣器",
        category = "attack",
        rarity = "white",
        shop_price = 100,
        description = "命中附加腐蚀层破甲; 单发伤害-10%",
        stops_tower_attack = false,
        drop_weight = 60,
        effects = {
            { type = "on_hit_status", status = "corrode", first_layer = 0.25, per_layer = 0.05, cap = 0.6, duration = 8 },
        },
        downsides = {
            { type = "stat_modifier", stat = "damage", modifier = -0.10 },
        },
    },

    -- 蓝色 ×4
    thunder = {
        id = "thunder",
        name = "雷鸣圣器",
        category = "attack",
        rarity = "blue",
        shop_price = 400,
        description = "命中后跳跃到附近2个敌人, 每跳衰减35%; 单发伤害-10%",
        stops_tower_attack = false,
        drop_weight = 25,
        effects = {
            { type = "on_hit_status", status = "chain_lightning", jumps = 2, decay = 0.35, range = 2 },
        },
        downsides = {
            { type = "stat_modifier", stat = "damage", modifier = -0.10 },
        },
    },
    splinter = {
        id = "splinter",
        name = "裂片圣器",
        category = "attack",
        rarity = "blue",
        shop_price = 400,
        description = "命中后炮弹分裂为4片; 射程-20%",
        stops_tower_attack = false,
        drop_weight = 25,
        effects = {
            { type = "on_hit_status", status = "splinter", splinter_count = 4, splinter_damage_pct = 0.25 },
            { type = "stat_modifier", stat = "range", modifier = -0.20 },
        },
        downsides = {},
    },
    piercing_core = {
        id = "piercing_core",
        name = "穿透弹芯",
        category = "attack",
        rarity = "blue",
        shop_price = 400,
        description = "攻击穿透2个敌人; 单发伤害-15%",
        stops_tower_attack = false,
        drop_weight = 25,
        effects = {
            { type = "custom", logic_id = "pierce", pierce_count = 2 },
        },
        downsides = {
            { type = "stat_modifier", stat = "damage", modifier = -0.15 },
        },
    },
    sniper_mod = {
        id = "sniper_mod",
        name = "狙击改装",
        category = "attack",
        rarity = "blue",
        shop_price = 400,
        description = "射程+150%; 攻速-40%",
        stops_tower_attack = false,
        drop_weight = 25,
        effects = {
            { type = "stat_modifier", stat = "range", modifier = 1.5 },
        },
        downsides = {
            { type = "stat_modifier", stat = "attack_speed", modifier = -0.40 },
        },
    },

    -- 紫色 ×5
    prism = {
        id = "prism",
        name = "棱镜圣器",
        category = "attack",
        rarity = "purple",
        shop_price = 1500,
        description = "炮弹→持续激光(穿透到射程末端); 射速降为1/3",
        stops_tower_attack = false,
        drop_weight = 12,
        effects = {
            { type = "transform_bullet", new_form = "laser" },
        },
        downsides = {
            { type = "stat_modifier", stat = "attack_speed", modifier = -0.667 },
        },
    },
    high_explosive = {
        id = "high_explosive",
        name = "高爆圣器",
        category = "attack",
        rarity = "purple",
        shop_price = 1500,
        description = "炮弹→范围爆炸弹(半径1.5格); 射速-40%, 单发-20%",
        stops_tower_attack = false,
        drop_weight = 12,
        effects = {
            { type = "transform_bullet", new_form = "area", area_radius = 1.5 },
        },
        downsides = {
            { type = "stat_modifier", stat = "damage", modifier = -0.20 },
            { type = "stat_modifier", stat = "attack_speed", modifier = -0.40 },
        },
    },
    crit_device = {
        id = "crit_device",
        name = "暴击装置",
        category = "attack",
        rarity = "purple",
        shop_price = 1500,
        description = "25%概率暴击×3伤害",
        stops_tower_attack = false,
        drop_weight = 12,
        effects = {
            { type = "custom", logic_id = "crit", crit_chance = 0.25, crit_multiplier = 3.0 },
        },
        downsides = {},
    },
    resonance_trigger = {
        id = "resonance_trigger",
        name = "共振触发",
        category = "attack",
        rarity = "purple",
        shop_price = 1500,
        description = "释放技能时此塔下次攻击×3+穿透; 攻速-20%",
        stops_tower_attack = false,
        drop_weight = 12,
        effects = {
            { type = "custom", logic_id = "resonance_trigger", damage_mult = 3.0, piercing = true },
        },
        downsides = {
            { type = "stat_modifier", stat = "attack_speed", modifier = -0.20 },
        },
    },
    elemental_core = {
        id = "elemental_core",
        name = "元素核心",
        category = "attack",
        rarity = "purple",
        shop_price = 1500,
        description = "每装备1件状态圣器, 所有状态伤害+50%、触发率+25%",
        stops_tower_attack = false,
        drop_weight = 12,
        effects = {
            { type = "custom", logic_id = "elemental_core", status_dmg_bonus = 0.50, status_rate_bonus = 0.25 },
        },
        downsides = {},
    },

    -- =========================================================================
    -- 增益类 (buff) — 12 件
    -- =========================================================================

    -- 白色 ×3
    aura_attack_speed = {
        id = "aura_attack_speed",
        name = "攻速光环",
        category = "buff",
        rarity = "white",
        shop_price = 100,
        description = "5格内基础塔攻速+30%; 此塔不攻击",
        stops_tower_attack = true,
        drop_weight = 60,
        effects = {
            { type = "aura", stat = "attack_speed", bonus = 0.30, range = 5 },
        },
        downsides = {},
    },
    aura_damage = {
        id = "aura_damage",
        name = "伤害光环",
        category = "buff",
        rarity = "white",
        shop_price = 100,
        description = "5格内基础塔单发伤害+25%; 此塔不攻击",
        stops_tower_attack = true,
        drop_weight = 60,
        effects = {
            { type = "aura", stat = "damage", bonus = 0.25, range = 5 },
        },
        downsides = {},
    },
    aura_range = {
        id = "aura_range",
        name = "射程光环",
        category = "buff",
        rarity = "white",
        shop_price = 100,
        description = "5格内基础塔射程+2格; 此塔不攻击",
        stops_tower_attack = true,
        drop_weight = 60,
        effects = {
            { type = "aura", stat = "range_flat", bonus = 2, range = 5 },
        },
        downsides = {},
    },

    -- 蓝色 ×2
    aura_crit = {
        id = "aura_crit",
        name = "暴击光环",
        category = "buff",
        rarity = "blue",
        shop_price = 400,
        description = "5格内基础塔暴击率+15%; 此塔不攻击",
        stops_tower_attack = true,
        drop_weight = 25,
        effects = {
            { type = "aura", stat = "crit_chance", bonus = 0.15, range = 5 },
        },
        downsides = {},
    },
    range_compression = {
        id = "range_compression",
        name = "远程压缩",
        category = "buff",
        rarity = "blue",
        shop_price = 400,
        description = "距ET每多1段, 关联段线伤+12%(cap+120%); 距ET≤3段时不工作",
        stops_tower_attack = false,
        drop_weight = 25,
        effects = {
            { type = "custom", logic_id = "range_compression", per_segment = 0.12, cap = 1.2, min_segments = 4 },
        },
        downsides = {},
    },

    -- 紫色 ×7
    power_borrow = {
        id = "power_borrow",
        name = "借力圣器",
        category = "buff",
        rarity = "purple",
        shop_price = 1500,
        description = "此塔伤害 += 5格内基础塔能量总和×60%; 周围塔攻速-10%",
        stops_tower_attack = false,
        drop_weight = 12,
        effects = {
            { type = "custom", logic_id = "power_borrow", range = 5, borrow_ratio = 0.60 },
        },
        downsides = {
            { type = "custom", logic_id = "nearby_attack_speed_penalty", range = 5, penalty = -0.10 },
        },
    },
    master_tower = {
        id = "master_tower",
        name = "总管塔",
        category = "buff",
        rarity = "purple",
        shop_price = 1500,
        description = "此塔圣器槽+1(共4槽); 距其他基础塔<3格时不工作",
        stops_tower_attack = false,
        drop_weight = 12,
        effects = {
            { type = "custom", logic_id = "extra_slot", extra_slots = 1, min_distance = 3 },
        },
        downsides = {},
    },
    defense_garrison = {
        id = "defense_garrison",
        name = "防御阵地塔",
        category = "buff",
        rarity = "purple",
        shop_price = 1500,
        description = "5格内基础塔受伤-50%; 技能时自身护盾+100; 此塔不攻击",
        stops_tower_attack = true,
        drop_weight = 12,
        effects = {
            { type = "aura", stat = "damage_reduction", bonus = 0.50, range = 5 },
        },
        downsides = {},
    },
    network = {
        id = "network",
        name = "网络圣器",
        category = "buff",
        rarity = "purple",
        shop_price = 1500,
        description = "与3格内最多3座基础塔产生次级能源线(线伤=主线35%); 此塔攻速-40%",
        stops_tower_attack = false,
        drop_weight = 12,
        effects = {
            { type = "custom", logic_id = "network", secondary_range = 3, max_links = 3, line_ratio = 0.35 },
        },
        downsides = {
            { type = "stat_modifier", stat = "attack_speed", modifier = -0.40 },
        },
    },
    devour_line = {
        id = "devour_line",
        name = "吞噬线",
        category = "buff",
        rarity = "purple",
        shop_price = 1500,
        description = "此塔关联段线伤×2.5; 此塔不攻击",
        stops_tower_attack = true,
        drop_weight = 12,
        effects = {
            { type = "custom", logic_id = "line_multiplier", multiplier = 2.5 },
        },
        downsides = {},
    },
    ice_crystal_conduit = {
        id = "ice_crystal_conduit",
        name = "冰晶导管",
        category = "buff",
        rarity = "purple",
        shop_price = 1500,
        description = "关联段每秒给踩线怪+1冻结层; 关联段线伤-25%",
        stops_tower_attack = false,
        drop_weight = 12,
        effects = {
            { type = "custom", logic_id = "conduit_freeze", freeze_per_second = 1 },
        },
        downsides = {
            { type = "custom", logic_id = "line_damage_modifier", modifier = -0.25 },
        },
    },
    resonance_amplifier = {
        id = "resonance_amplifier",
        name = "共鸣放大器",
        category = "buff",
        rarity = "purple",
        shop_price = 1500,
        description = "5格内其他增益类圣器塔的光环效果×2.5; 此塔不攻击",
        stops_tower_attack = true,
        drop_weight = 12,
        effects = {
            { type = "custom", logic_id = "buff_amplifier", range = 5, amplification = 2.5 },
        },
        downsides = {},
    },
    elemental_reaction = {
        id = "elemental_reaction",
        name = "元素反应",
        category = "buff",
        rarity = "purple",
        shop_price = 1500,
        description = "燃烧+冰冻=蒸发/冰冻+感电=麻痹/感电+燃烧=过载/腐蚀+任意=侵蚀",
        stops_tower_attack = false,
        drop_weight = 12,
        effects = {
            { type = "custom", logic_id = "elemental_reaction" },
        },
        downsides = {},
    },
    overload_relay = {
        id = "overload_relay",
        name = "过载继电器",
        category = "buff",
        rarity = "purple",
        shop_price = 1500,
        description = "释放技能时, 全部段线伤+150%持续5秒; 主动能量上限-20",
        stops_tower_attack = false,
        drop_weight = 12,
        effects = {
            { type = "custom", logic_id = "overload_relay", line_dmg_bonus = 1.5, duration = 5 },
            { type = "custom", logic_id = "energy_max_penalty", penalty = -20 },
        },
        downsides = {},
    },
    energy_ammo = {
        id = "energy_ammo",
        name = "注能弹药",
        category = "buff",
        rarity = "purple",
        shop_price = 1500,
        description = "释放技能后所有基础塔攻速+100%持续5秒; 主动能量上限-15",
        stops_tower_attack = false,
        drop_weight = 12,
        effects = {
            { type = "custom", logic_id = "energy_ammo", atk_spd_bonus = 1.0, duration = 5 },
            { type = "custom", logic_id = "energy_max_penalty", penalty = -15 },
        },
        downsides = {},
    },

    -- =========================================================================
    -- 收集类 (collection) — 11 件
    -- =========================================================================

    -- 白色 ×3
    coin_magnet = {
        id = "coin_magnet",
        name = "磁币圣器",
        category = "collection",
        rarity = "white",
        shop_price = 100,
        description = "5格内金币自动吸取",
        stops_tower_attack = false,
        drop_weight = 60,
        effects = {
            { type = "custom", logic_id = "auto_pickup_gold", range = 5 },
        },
        downsides = {},
    },
    gold_refinery = {
        id = "gold_refinery",
        name = "金矿炼化",
        category = "collection",
        rarity = "white",
        shop_price = 100,
        description = "此塔击杀的敌人金币掉落+30%",
        stops_tower_attack = false,
        drop_weight = 60,
        effects = {
            { type = "custom", logic_id = "gold_drop_bonus", bonus = 0.30 },
        },
        downsides = {},
    },
    energy_matrix = {
        id = "energy_matrix",
        name = "充能矩阵",
        category = "collection",
        rarity = "white",
        shop_price = 100,
        description = "此塔击杀的敌人25%概率+1主动能量",
        stops_tower_attack = false,
        drop_weight = 60,
        effects = {
            { type = "custom", logic_id = "energy_on_kill", chance = 0.25, amount = 1 },
        },
        downsides = {},
    },

    -- 蓝色 ×3
    charged_hit = {
        id = "charged_hit",
        name = "蓄力击圣器",
        category = "collection",
        rarity = "blue",
        shop_price = 400,
        description = "此塔每命中3次产生1主动能量; 攻速-10%",
        stops_tower_attack = false,
        drop_weight = 25,
        effects = {
            { type = "custom", logic_id = "energy_per_hits", hits_per_energy = 3 },
        },
        downsides = {
            { type = "stat_modifier", stat = "attack_speed", modifier = -0.10 },
        },
    },
    condenser = {
        id = "condenser",
        name = "凝聚塔",
        category = "collection",
        rarity = "blue",
        shop_price = 400,
        description = "每秒生成1主动能量; 此塔不攻击",
        stops_tower_attack = true,
        drop_weight = 25,
        effects = {
            { type = "custom", logic_id = "passive_energy_gen", energy_per_second = 1.0 },
        },
        downsides = {},
    },
    resource_enrichment = {
        id = "resource_enrichment",
        name = "资源富集",
        category = "collection",
        rarity = "blue",
        shop_price = 400,
        description = "相邻地形物件掉落+100%; 此塔不攻击",
        stops_tower_attack = true,
        drop_weight = 25,
        effects = {
            { type = "custom", logic_id = "terrain_drop_bonus", drop_multiplier = 1.0, range = 1.5 },
        },
        downsides = {},
    },

    -- 紫色 ×2
    compound_interest = {
        id = "compound_interest",
        name = "复利圣器",
        category = "collection",
        rarity = "purple",
        shop_price = 1500,
        description = "每30秒金币掉落×1.05(无上限); 开局60秒内金币-50%",
        stops_tower_attack = false,
        drop_weight = 12,
        effects = {
            { type = "custom", logic_id = "compound_interest", interval = 30, multiplier = 1.05, penalty_duration = 60, early_penalty = -0.5 },
        },
        downsides = {},
    },
    feedback_coil = {
        id = "feedback_coil",
        name = "反馈线圈",
        category = "collection",
        rarity = "purple",
        shop_price = 1500,
        description = "能源线累计造成500伤害时, 全场塔伤+30%持续5秒; 关联段线伤-15%",
        stops_tower_attack = false,
        drop_weight = 12,
        effects = {
            { type = "custom", logic_id = "feedback_coil", threshold = 500, tower_dmg_bonus = 0.30, duration = 5 },
        },
        downsides = {
            { type = "custom", logic_id = "line_damage_modifier", modifier = -0.15 },
        },
    },
}

-- 稀有度颜色
M.RARITY_COLORS = {
    white  = { 200, 200, 200, 255 },
    blue   = { 80, 160, 255, 255 },
    purple = { 180, 80, 255, 255 },
    gold   = { 255, 200, 50, 255 },
}

M.RARITY_NAMES = {
    white  = "普通",
    blue   = "精良",
    purple = "史诗",
    gold   = "传说",
}

-- ============================================================================
-- 背包管理
-- ============================================================================

--- 初始化圣器系统 (游戏开始时调用)
function M.Init()
    GS.artifactInventory = {}   -- 背包: { {id, defRef}, ... }
    GS.artifactDropPending = false  -- 是否有待处理的掉落选择
    GS.artifactDropCandidates = nil -- 3选1 候选列表
    print("[Artifact] System initialized")
end

--- 添加圣器到背包
--- @param artifactId string
--- @return table|nil 新增的背包条目
function M.AddToInventory(artifactId)
    local def = M.DEFS[artifactId]
    if not def then
        print("[Artifact] ERROR: Unknown artifact: " .. tostring(artifactId))
        return nil
    end
    local entry = {
        id = artifactId,
        def = def,
        equipped = false,    -- 是否已装备
        towerIndex = nil,    -- 装备在哪座塔 (GS.towers 的索引)
        slotType = nil,      -- "slot1" / "slot2" / "slot3"
    }
    table.insert(GS.artifactInventory, entry)
    print(string.format("[Artifact] Added to inventory: %s (%s)", def.name, M.RARITY_NAMES[def.rarity]))
    return entry
end

--- 从背包移除圣器 (按背包索引)
--- @param invIndex number 背包索引 (1-based)
function M.RemoveFromInventory(invIndex)
    if invIndex < 1 or invIndex > #GS.artifactInventory then return end
    local entry = GS.artifactInventory[invIndex]
    -- 先卸下
    if entry.equipped then
        M.UnequipFromTower(invIndex)
    end
    table.remove(GS.artifactInventory, invIndex)
end

-- ============================================================================
-- 塔槽位系统 (每座塔: 3个等效配件槽，效力均为 100%)
-- ============================================================================

local SLOT_KEYS = { "slot1", "slot2", "slot3" }  -- 三个槽的 key

--- 装备圣器到塔
--- @param invIndex number 背包索引
--- @param towerIndex number 塔索引 (GS.towers)
--- @param slotType string "slot1" / "slot2" / "slot3"
--- @return boolean 是否成功
function M.EquipToTower(invIndex, towerIndex, slotType)
    if invIndex < 1 or invIndex > #GS.artifactInventory then return false end
    if towerIndex < 1 or towerIndex > #GS.towers then return false end
    -- 校验槽位 key
    local slotIdx = nil
    for i, k in ipairs(SLOT_KEYS) do
        if k == slotType then slotIdx = i; break end
    end
    if not slotIdx then return false end

    local entry = GS.artifactInventory[invIndex]
    local tower = GS.towers[towerIndex]

    -- 检查是否已装备在其他地方
    if entry.equipped then
        M.UnequipFromTower(invIndex)
    end

    -- 检查目标槽是否已有圣器
    local currentOccupant = M.GetEquippedAt(towerIndex, slotType)
    if currentOccupant then
        M.UnequipFromTower(currentOccupant)
    end

    -- 装备
    entry.equipped = true
    entry.towerIndex = towerIndex
    entry.slotType = slotType
    tower.slots[slotIdx] = invIndex

    -- 应用属性修正
    M.RecalcTowerArtifactStats(towerIndex)

    -- 触发 VFX（延迟 require 避免循环依赖）
    local ok, VFX = pcall(require, "ArtifactVFX")
    if ok and VFX then
        VFX.OnEquip(tower, entry.def.id)
    end

    print(string.format("[Artifact] Equipped %s to Tower(%d,%d) %s",
        entry.def.name, tower.gx, tower.gz, slotType))
    return true
end

--- 从塔卸下圣器
--- @param invIndex number 背包索引
function M.UnequipFromTower(invIndex)
    if invIndex < 1 or invIndex > #GS.artifactInventory then return end
    local entry = GS.artifactInventory[invIndex]
    if not entry.equipped then return end

    local towerIndex = entry.towerIndex
    local tower = GS.towers[towerIndex]
    if tower then
        -- 触发 VFX 卸除
        local ok, VFX = pcall(require, "ArtifactVFX")
        if ok and VFX then
            VFX.OnUnequip(tower, entry.def.id)
        end
        for i = 1, 3 do
            if tower.slots[i] == invIndex then
                tower.slots[i] = nil
            end
        end
        M.RecalcTowerArtifactStats(towerIndex)
    end

    entry.equipped = false
    entry.towerIndex = nil
    entry.slotType = nil
end

--- 获取指定塔槽位上的背包索引
--- @param towerIndex number
--- @param slotType string "slot1"/"slot2"/"slot3"
--- @return number|nil 背包索引
function M.GetEquippedAt(towerIndex, slotType)
    if towerIndex < 1 or towerIndex > #GS.towers then return nil end
    local tower = GS.towers[towerIndex]
    for i, k in ipairs(SLOT_KEYS) do
        if k == slotType then
            return tower.slots[i]
        end
    end
    return nil
end

--- 获取塔上装备的所有圣器效果列表
--- @param towerIndex number
--- @return table 效果列表 { {effect, effectiveness, defRef}, ... }
function M.GetTowerEffects(towerIndex)
    local results = {}
    if towerIndex < 1 or towerIndex > #GS.towers then return results end
    local tower = GS.towers[towerIndex]

    -- 三个槽均为 100% 效力
    for i = 1, 3 do
        local slotInvIdx = tower.slots[i]
        if slotInvIdx then
            local entry = GS.artifactInventory[slotInvIdx]
            if entry and entry.def then
                for _, eff in ipairs(entry.def.effects) do
                    table.insert(results, { effect = eff, effectiveness = 1.0, def = entry.def })
                end
            end
        end
    end

    return results
end

-- ============================================================================
-- 属性修正计算
-- ============================================================================

--- 重新计算塔的圣器属性修正
--- @param towerIndex number
function M.RecalcTowerArtifactStats(towerIndex)
    if towerIndex < 1 or towerIndex > #GS.towers then return end
    local tower = GS.towers[towerIndex]

    -- 重置修正值
    tower.artDmgMult = 1.0        -- 伤害乘数
    tower.artFlatDmg = 0          -- 固定加伤（占位）
    tower.artAtkSpdMult = 1.0     -- 攻速乘数
    tower.artBulletForm = "bullet" -- 弹道形态
    tower.artAreaRadius = 0        -- 范围爆炸半径
    tower.artOnHit = {}            -- 命中效果列表
    tower.artStopsAttack = false   -- 是否停止攻击（buff 类圣器）
    tower.artCritChance = 0        -- 暴击率加成
    tower.artCritMult = 1.0        -- 暴击倍数
    tower.artHitCounter = tower.artHitCounter or 0  -- 命中计数（蓄力击）
    tower.artPassiveEnergyTimer = tower.artPassiveEnergyTimer or 0  -- 凝聚塔计时

    local function applySlot(slotInvIdx)
        if not slotInvIdx then return end
        local entry = GS.artifactInventory[slotInvIdx]
        if not entry or not entry.def then return end
        local def = entry.def

        -- stops_tower_attack: 任意装备了此类圣器即停止攻击
        if def.stops_tower_attack then
            tower.artStopsAttack = true
        end

        -- 应用 effects
        for _, eff in ipairs(def.effects) do
            if eff.type == "stat_modifier" then
                if eff.stat == "damage" then
                    tower.artDmgMult = tower.artDmgMult * (1.0 + eff.modifier)
                elseif eff.stat == "attack_speed" then
                    tower.artAtkSpdMult = tower.artAtkSpdMult * (1.0 + eff.modifier)
                end
            elseif eff.type == "on_hit_status" then
                table.insert(tower.artOnHit, {
                    status = eff.status,
                    effectiveness = 1.0,
                    dot_ratio = eff.dot_ratio,
                    duration = eff.duration,
                    slow_per_stack = eff.slow_per_stack,
                    max_stacks = eff.max_stacks,
                    freeze_duration = eff.freeze_duration,
                    first_layer = eff.first_layer,
                    per_layer = eff.per_layer,
                    cap = eff.cap,
                    jumps = eff.jumps,
                    decay = eff.decay,
                    range = eff.range,
                    splinter_count = eff.splinter_count,
                    splinter_damage_pct = eff.splinter_damage_pct,
                })
            elseif eff.type == "transform_bullet" then
                tower.artBulletForm = eff.new_form or "bullet"
                tower.artAreaRadius = eff.area_radius or 0
            elseif eff.type == "custom" then
                if eff.logic_id == "auto_pickup_gold" then
                    tower.artAutoPickupRange = eff.range or 5
                elseif eff.logic_id == "crit" then
                    tower.artCritChance = tower.artCritChance + (eff.crit_chance or 0)
                    tower.artCritMult = eff.crit_multiplier or 3.0
                elseif eff.logic_id == "passive_energy_gen" then
                    tower.artPassiveEnergyRate = eff.energy_per_second or 1.0
                elseif eff.logic_id == "energy_per_hits" then
                    tower.artEnergyPerHits = eff.hits_per_energy or 3
                elseif eff.logic_id == "energy_on_kill" then
                    tower.artEnergyOnKillChance = eff.chance or 0.25
                    tower.artEnergyOnKillAmount = eff.amount or 1
                elseif eff.logic_id == "gold_drop_bonus" then
                    tower.artGoldDropBonus = (tower.artGoldDropBonus or 0) + (eff.bonus or 0)
                end
            end
        end

        -- 应用缺点 (downsides) — 始终 100% 生效
        for _, ds in ipairs(def.downsides) do
            if ds.type == "stat_modifier" then
                if ds.stat == "damage" then
                    tower.artDmgMult = tower.artDmgMult * (1.0 + ds.modifier)
                elseif ds.stat == "attack_speed" then
                    tower.artAtkSpdMult = tower.artAtkSpdMult * (1.0 + ds.modifier)
                end
            end
        end
    end

    -- stops_tower_attack = true 的圣器会让攻击类圣器的变形弹道效果失效
    for i = 1, 3 do
        applySlot(tower.slots[i])
    end

    -- 如果塔停止攻击，重置弹道形态
    if tower.artStopsAttack then
        tower.artBulletForm = "bullet"
        tower.artAreaRadius = 0
    end
end

--- 确保所有塔都有圣器属性字段 (放置新塔后调用)
function M.InitTowerSlots(tower)
    tower.slots = { nil, nil, nil }  -- 三个等效配件槽
    tower.artDmgMult = 1.0
    tower.artFlatDmg = 0
    tower.artAtkSpdMult = 1.0
    tower.artBulletForm = "bullet"
    tower.artAreaRadius = 0
    tower.artOnHit = {}
    tower.artAutoPickupRange = 0
    tower.artStopsAttack = false
    tower.artCritChance = 0
    tower.artCritMult = 1.0
    tower.artHitCounter = 0
    tower.artPassiveEnergyTimer = 0
    tower.artPassiveEnergyRate = 0
    tower.artEnergyPerHits = 0
    tower.artEnergyOnKillChance = 0
    tower.artEnergyOnKillAmount = 0
    tower.artGoldDropBonus = 0
    tower.vfxNodes = {}  -- VFX 节点表 {artifactId → node}
end

-- ============================================================================
-- 掉落逻辑 (波次结束时 3 选 1)
-- ============================================================================

--- 生成 3 个候选圣器
--- @return table candidates { {id, def}, ... }
function M.GenerateDropCandidates()
    -- 按 drop_weight 权重抽样
    local pool = {}
    local totalWeight = 0
    for id, def in pairs(M.DEFS) do
        table.insert(pool, { id = id, def = def, weight = def.drop_weight })
        totalWeight = totalWeight + def.drop_weight
    end

    local candidates = {}
    local picked = {}

    for c = 1, 3 do
        if #pool == 0 then break end

        local roll = math.random() * totalWeight
        local acc = 0
        for i, item in ipairs(pool) do
            acc = acc + item.weight
            if acc >= roll then
                table.insert(candidates, { id = item.id, def = item.def })
                picked[item.id] = true
                -- 从池中移除防止重复
                totalWeight = totalWeight - item.weight
                table.remove(pool, i)
                break
            end
        end
    end

    return candidates
end

--- 触发波次结束掉落 (由 Wave.lua 调用)
function M.TriggerWaveDrop()
    local candidates = M.GenerateDropCandidates()
    if #candidates == 0 then return end

    GS.artifactDropPending = true
    GS.artifactDropCandidates = candidates

    print(string.format("[Artifact] Wave drop: %s | %s | %s",
        candidates[1] and candidates[1].def.name or "?",
        candidates[2] and candidates[2].def.name or "?",
        candidates[3] and candidates[3].def.name or "?"))
end

--- 玩家选择掉落圣器
--- @param choiceIndex number 1-3 选择, 0 = 跳过
function M.PickDrop(choiceIndex)
    if not GS.artifactDropPending or not GS.artifactDropCandidates then return end

    if choiceIndex >= 1 and choiceIndex <= #GS.artifactDropCandidates then
        local chosen = GS.artifactDropCandidates[choiceIndex]
        M.AddToInventory(chosen.id)
    else
        -- 跳过: 给 50 金币补偿
        GS.gold = GS.gold + 50
        print("[Artifact] Drop skipped, +50 gold")
    end

    GS.artifactDropPending = false
    GS.artifactDropCandidates = nil
end

-- ============================================================================
-- 磁币圣器: 自动吸取金币
-- ============================================================================

--- 每帧更新磁币效果 (在 main.lua 中调用)
function M.UpdateAutoPickup(dt)
    for _, tower in ipairs(GS.towers) do
        if tower.artAutoPickupRange and tower.artAutoPickupRange > 0 then
            local range = tower.artAutoPickupRange
            for _, loot in ipairs(GS.loots) do
                if loot.node and loot.type == "gold" and not loot.collecting then
                    local dx = loot.node.position.x - tower.gx
                    local dz = loot.node.position.z - tower.gz
                    local dist = math.sqrt(dx * dx + dz * dz)
                    if dist <= range then
                        loot.collecting = true -- 触发自动收集
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- 查询接口
-- ============================================================================

--- 获取背包中未装备的圣器列表
function M.GetUnequippedArtifacts()
    local list = {}
    for i, entry in ipairs(GS.artifactInventory) do
        if not entry.equipped then
            table.insert(list, { invIndex = i, entry = entry })
        end
    end
    return list
end

--- 获取塔的圣器信息 (用于 UI 显示)
--- @param towerIndex number
--- @return table { [1]=def|nil, [2]=def|nil, [3]=def|nil }
function M.GetTowerArtifactInfo(towerIndex)
    local info = { nil, nil, nil }
    if towerIndex < 1 or towerIndex > #GS.towers then return info end
    local tower = GS.towers[towerIndex]
    for i = 1, 3 do
        if tower.slots[i] then
            local entry = GS.artifactInventory[tower.slots[i]]
            if entry then info[i] = entry.def end
        end
    end
    return info
end

return M
