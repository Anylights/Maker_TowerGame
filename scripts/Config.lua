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
    LinesDiff      = Color(0.35, 0.70, 0.85, 0.85),
    LinesEmit      = Color(0.25, 0.45, 0.65),
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
    -- 能源塔
    TotalPower = 100,
    EnergyRange = 7,
    EnergyTowerHP = 500,
    EnergyTowerHPBarW = 1.4,
    EnergyTowerHPBarH = 0.12,
    EnergyTowerHPBarOffY = 1.8,
    MonsterDmgToTower = 20,
    -- 经济
    InitialGold = 300,
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

    -- 经济
    gold = M.CONFIG.InitialGold,

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

    -- 能源塔血条
    etHPBg = nil,
    etHPFill = nil,
    etFillMat = nil,

    -- 波次状态
    currentWave = 0,
    wavePhase = "preparing", -- "preparing" | "spawning" | "clearing" | "complete"
    waveTimer = 0,
    waveSpawnIndex = 0,
    waveSpawnTimer = 0,
    monstersKilled = 0,
}

return M
