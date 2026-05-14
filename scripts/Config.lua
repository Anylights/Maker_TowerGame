-- ============================================================================
-- Config.lua — 全局配置 + 色调 + 共享游戏状态
-- ============================================================================

local M = {}

-- ============================================================================
-- 色调配置
-- ============================================================================
M.MOEBIUS = {
    EnergyDiff     = Color(0.95, 0.68, 0.15, 1),
    EnergyEmit     = Color(0.50, 0.35, 0.08),
    TowerDiff      = Color(0.45, 0.55, 0.72, 1),
    TowerEmit      = Color(0.12, 0.18, 0.30),
    MonsterDiff    = Color(0.85, 0.22, 0.18, 1),
    MonsterEmit    = Color(0.35, 0.08, 0.05),
    ProjectileDiff = Color(0.15, 0.80, 0.85, 1),
    ProjectileEmit = Color(0.10, 0.45, 0.50),
    GridColor      = Color(0.50, 0.42, 0.32, 0.30),
    RangeColor     = Color(0.40, 0.60, 0.80, 0.35),
    LootGoldDiff   = Color(1.0, 0.82, 0.20, 1),
    LootGoldEmit   = Color(0.45, 0.35, 0.05),
    LootEnergyDiff = Color(0.30, 0.55, 0.90, 1),
    LootEnergyEmit = Color(0.15, 0.25, 0.50),
    LootMaterialDiff = Color(0.40, 0.85, 0.45, 1),
    LootMaterialEmit = Color(0.15, 0.40, 0.18),
    LinesDiff      = Color(0.35, 0.70, 0.85, 0.85),
    LinesEmit      = Color(0.25, 0.45, 0.65),
}

-- ============================================================================
-- 能源塔升级属性表 (Lv.1 ~ Lv.10)
-- ============================================================================
M.ET_LEVELS = {
    --  power, hp,  radius, energyCap, convEff
    { power = 100, hp = 100, radius = 7, energyCap = 100, convEff = 1.00 },  -- Lv.1
    { power = 110, hp = 115, radius = 7, energyCap = 110, convEff = 1.05 },  -- Lv.2
    { power = 120, hp = 130, radius = 7, energyCap = 120, convEff = 1.10 },  -- Lv.3
    { power = 130, hp = 145, radius = 8, energyCap = 130, convEff = 1.15 },  -- Lv.4 半径+1
    { power = 145, hp = 165, radius = 8, energyCap = 145, convEff = 1.20 },  -- Lv.5 核心圣器槽
    { power = 160, hp = 185, radius = 8, energyCap = 160, convEff = 1.25 },  -- Lv.6
    { power = 175, hp = 205, radius = 9, energyCap = 175, convEff = 1.30 },  -- Lv.7 半径+1
    { power = 185, hp = 220, radius = 9, energyCap = 185, convEff = 1.35 },  -- Lv.8
    { power = 195, hp = 235, radius = 9, energyCap = 195, convEff = 1.40 },  -- Lv.9
    { power = 200, hp = 250, radius = 9, energyCap = 200, convEff = 1.45 },  -- Lv.10 核心圣器觉醒
}

-- 升级消耗 (index = 升级目标等级, 即 [2] = Lv.1→Lv.2 的消耗)
M.ET_UPGRADE_COST = {
    [2]  = { gold = 80,   material = 20  },
    [3]  = { gold = 140,  material = 45  },
    [4]  = { gold = 220,  material = 80  },
    [5]  = { gold = 320,  material = 130 },
    [6]  = { gold = 450,  material = 200 },
    [7]  = { gold = 600,  material = 280 },
    [8]  = { gold = 780,  material = 380 },
    [9]  = { gold = 1000, material = 500 },
    [10] = { gold = 1300, material = 650 },
}

-- ============================================================================
-- 游戏配置常量
-- ============================================================================
M.CONFIG = {
    Title = "Energy Tower Defense",
    -- 地图
    MapHalfW = 90,
    MapHalfH = 60,
    GridSize = 1.0,
    -- 相机
    OrthoSize = 18.0,
    PanSpeed = 1.0,
    ZoomSpeed = 1.5,
    ZoomMin = 6.0,
    ZoomMax = 30.0,
    -- 能源塔 (Lv.1 初始值, 运行时由 ET_LEVELS[etLevel] 驱动)
    TotalPower = 100,
    EnergyRange = 7,
    EnergyTowerHP = 100,
    EnergyTowerHPBarW = 1.4,
    EnergyTowerHPBarH = 0.12,
    EnergyTowerHPBarOffY = 1.8,
    MonsterDmgToTower = 20,
    -- 能源线伤害
    LineDmgCoeff = 0.35,           -- line_dps = P_line * 0.35 * convEff
    LineHitRadius = 0.5,           -- 怪物到线段距离 < 0.5m 命中
    LineMultiDecay = { 1.00, 0.75, 0.55, 0.40, 0.30, 0.22, 0.16 }, -- 多线叠加递减
    -- 经济
    InitialGold = 300,
    InitialMaterial = 0,
    InitialEnergy = 0,
    BaseCost = 30,
    CostLinear = 8,
    CostQuad = 2,
    -- 视觉
    GridY = 0.02,
    HoverY = 0.04,
    LineWidth = 0.18,
    EnergyLineY = 0.06,
    -- 怪物
    MonsterHP = 80,
    MonsterSpeed = 1.8,
    MonsterSize = 0.38,
    SpawnInterval = 2.5,
    SpawnDistance = 18,
    MonsterGoldDrop = 15,
    MonsterEnergyDrop = 5,
    -- 塔攻击
    TowerRange = 5.0,
    TowerFireInterval = 1.0,
    TowerBaseDmg = 20,
    -- 炮弹
    ProjectileSpeed = 12.0,
    ProjectileSize = 0.15,
    -- 掉落
    LootStayTime = 1.5,
    LootCollectSpeed = 6.0,
    LootFloatHeight = 0.4,
    -- 血条
    HPBarW = 0.5,
    HPBarH = 0.06,
    HPBarOffY = 0.4,
}

-- ============================================================================
-- GameState — 模块间共享的运行时状态
-- ============================================================================
M.GS = {
    ---@type Scene
    scene = nil,
    ---@type Node
    cameraNode = nil,
    ---@type Camera
    camera = nil,

    -- 经济 (三资源)
    gold = M.CONFIG.InitialGold,
    material = M.CONFIG.InitialMaterial,
    energy = M.CONFIG.InitialEnergy,

    -- 能源塔等级
    etLevel = 1,

    -- 基础塔列表 { node, gx, gz, dist, delivered, linePwr, ratio, cooldown, weaponYaw, targetYaw }
    towers = {},

    -- 怪物 { node, hp, maxHp, dir, hpBg, hpFill, fillMat, type, speed, armor, shield, ... }
    monsters = {},

    -- 炮弹 { node, target, speed, damage }
    projectiles = {},

    -- 掉落 { node, type, timer, collecting }
    loots = {},

    -- 浮动伤害数字 { node, text3d, timer, maxTime }
    dmgTexts = {},

    -- 怪物刷新计时
    spawnTimer = 0,

    -- 能源塔血量
    etHP = 0,
    etMaxHP = 0,

    -- 游戏速度 (1, 2, 4)
    gameSpeed = 1,

    -- 游戏结束
    gameOver = false,

    -- 悬停状态
    hoverNode = nil,
    hoverGX = 0,
    hoverGZ = 0,
    hoverValid = false,
    hoverOnMap = false,

    -- 能源线
    linesNode = nil,
    lineMat = nil,
    linePulseTime = 0,
    pulsesNode = nil,
    pulses = {},
    lineSegments = {}, -- { {ax,az, bx,bz, linePwr}, ... } 用于线伤碰撞

    -- 能源塔血条
    etHPBg = nil,
    etHPFill = nil,
    etFillMat = nil,

    -- 场景物件 { node, type, gx, gz, hp, maxHp, buffType, buffValue, ... }
    terrainObjects = {},

    -- 波次状态
    currentWave = 0,
    wavePhase = "preparing", -- "preparing" | "spawning" | "clearing" | "complete"
    waveTimer = 0,
    waveSpawnIndex = 0,
    waveSpawnTimer = 0,
    monstersKilled = 0,
}

return M
