-- ============================================================================
-- Config.lua — 全局配置 + 色调 + 共享游戏状态
-- ============================================================================

local M = {}

-- ============================================================================
-- 色调配置
-- ============================================================================
-- Thronefall 风格色板：高饱和度纯色块 + 暖冷对比
M.MOEBIUS = {
    -- 能源塔：金琥珀色，温暖突出
    EnergyDiff     = Color(0.95, 0.72, 0.18, 1),
    EnergyEmit     = Color(0.55, 0.38, 0.10),
    -- 防御塔：石灰蓝，冷静厚重
    TowerDiff      = Color(0.50, 0.58, 0.68, 1),
    TowerEmit      = Color(0.10, 0.14, 0.22),
    -- 怪物：深红紫，威胁感强烈
    MonsterDiff    = Color(0.82, 0.18, 0.22, 1),
    MonsterEmit    = Color(0.40, 0.08, 0.10),
    -- 炮弹：青色能量弹
    ProjectileDiff = Color(0.20, 0.82, 0.85, 1),
    ProjectileEmit = Color(0.12, 0.50, 0.55),
    -- 网格线：暗褐色极低透明
    GridColor      = Color(0.45, 0.38, 0.28, 0.22),
    -- 范围圈
    RangeColor     = Color(0.35, 0.55, 0.75, 0.30),
    -- 掉落：金币-纯金
    LootGoldDiff   = Color(1.0, 0.85, 0.22, 1),
    LootGoldEmit   = Color(0.50, 0.38, 0.06),
    -- 掉落：能源-深蓝
    LootEnergyDiff = Color(0.25, 0.50, 0.90, 1),
    LootEnergyEmit = Color(0.12, 0.22, 0.50),
    -- 掉落：材料-翠绿
    LootMaterialDiff = Color(0.35, 0.82, 0.40, 1),
    LootMaterialEmit = Color(0.12, 0.38, 0.15),
    -- 能源线：深青色
    LinesDiff      = Color(0.30, 0.65, 0.80, 0.80),
    LinesEmit      = Color(0.20, 0.40, 0.60),
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
    -- 能源线伤害 (电路模型)
    CircuitDmgCoeff = 8.0,         -- DPS = current × coeff × convEff
    LineHitRadius = 0.5,           -- 怪物到线段距离 < 0.5m 命中
    ShortCircuitDmgPerSec = 5.0,   -- 短路每秒扣血 (占总功率百分比)
    -- 布线系统
    LineCostPerSegment = 5,        -- 每段能源线花费金币
    LineRefundRatio = 0.50,        -- 回收返还比例 50%
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

    -- 建塔两步确认
    placementPending = false,   -- 是否有待确认的建塔位置
    placementGX = 0,            -- 待确认位置 X
    placementGZ = 0,            -- 待确认位置 Z
    placementMarker = nil,      -- 放置确认标记节点
    etCrystalNode = nil,        -- 能源塔顶部水晶节点（旋转动画用）
    etRingNodes = nil,          -- 能源塔旋转能量环节点列表

    -- 能源网络 (统一图模型)
    energyGraph = {
        nodes = {},        -- nodeKey("x,z") → { x=gx, z=gz, edges={edgeKey,...} }
        edges = {},        -- edgeKey → { x1,z1, x2,z2, isHoriz }
        edgeCount = 0,     -- 边总数
    },
    energyNetwork = {
        parent = {},       -- Union-Find: nodeKey → nodeKey
        rank = {},         -- Union-Find: nodeKey → rank
        hasCycle = false,  -- 是否存在环路 (短路)
        spanTree = {},     -- BFS生成树: nodeKey → { parentKey, childKeys={...} }
        edgePower = {},    -- edgeKey → 该边上的功率
        nodePower = {},    -- nodeKey → 到达该节点的功率
    },
    shortCircuit = {
        active = false,    -- 是否短路中
        dmgAccum = 0,      -- 短路伤害累积
    },
    wiringMode = false,    -- 是否处于布线模式
    wiringStart = nil,     -- 拖拽画线起点 {gx, gz} 或 nil
    wiringPreviewNodes = {},-- 预览线段节点列表
    wiringHintMsg = nil,   -- 布线失败提示信息 (临时)
    wiringHintTimer = 0,   -- 提示信息倒计时

    linesNode = nil,
    lineMat = nil,
    linePulseTime = 0,
    pulsesNode = nil,
    pulses = {},

    -- 能源塔血条
    etHPBg = nil,
    etHPFill = nil,
    etFillMat = nil,

    -- 场景物件 { node, type, gx, gz, hp, maxHp, buffType, buffValue, ... }
    terrainObjects = {},

    -- 波次状态
    currentWave = 0,
    wavePhase = "preparing", -- "preparing" | "spawning" | "clearing" | "dropping" | "complete"
    waveTimer = 0,
    waveSpawnIndex = 0,
    waveSpawnTimer = 0,
    monstersKilled = 0,

    -- 圣器系统
    artifactInventory = {},       -- 背包: { {id, def, equipped, towerIndex, slotType}, ... }
    artifactDropPending = false,  -- 是否有待处理的掉落选择
    artifactDropCandidates = nil, -- 3选1 候选列表
}

-- ============================================================================
-- 重置游戏状态（重开时调用）
-- ============================================================================

function M.ResetGS()
    -- 清理旧场景
    if M.GS.scene then
        M.GS.scene:Remove()
    end

    -- 重置所有运行时状态到初始值
    M.GS.scene = nil
    M.GS.cameraNode = nil
    M.GS.camera = nil

    M.GS.gold = M.CONFIG.InitialGold
    M.GS.material = M.CONFIG.InitialMaterial
    M.GS.energy = M.CONFIG.InitialEnergy

    M.GS.etLevel = 1
    M.GS.towers = {}
    M.GS.monsters = {}
    M.GS.projectiles = {}
    M.GS.loots = {}
    M.GS.dmgTexts = {}
    M.GS.spawnTimer = 0

    M.GS.etHP = 0
    M.GS.etMaxHP = 0
    M.GS.gameSpeed = 1
    M.GS.gameOver = false

    M.GS.hoverNode = nil
    M.GS.hoverGX = 0
    M.GS.hoverGZ = 0
    M.GS.hoverValid = false
    M.GS.hoverOnMap = false

    M.GS.placementPending = false
    M.GS.placementGX = 0
    M.GS.placementGZ = 0
    M.GS.placementMarker = nil
    M.GS.etCrystalNode = nil
    M.GS.etRingNodes = nil

    M.GS.energyGraph = { nodes = {}, edges = {}, edgeCount = 0 }
    M.GS.energyNetwork = {
        parent = {}, rank = {},
        hasCycle = false, spanTree = {},
        edgePower = {}, nodePower = {},
    }
    M.GS.shortCircuit = { active = false, dmgAccum = 0 }
    M.GS.wiringMode = false
    M.GS.wiringStart = nil
    M.GS.wiringPreviewNodes = {}
    M.GS.wiringHintMsg = nil
    M.GS.wiringHintTimer = 0

    M.GS.linesNode = nil
    M.GS.lineMat = nil
    M.GS.linePulseTime = 0
    M.GS.pulsesNode = nil
    M.GS.pulses = {}

    M.GS.etHPBg = nil
    M.GS.etHPFill = nil
    M.GS.etFillMat = nil

    M.GS.terrainObjects = {}

    M.GS.currentWave = 0
    M.GS.wavePhase = "preparing"
    M.GS.waveTimer = 0
    M.GS.waveSpawnIndex = 0
    M.GS.waveSpawnTimer = 0
    M.GS.monstersKilled = 0

    M.GS.artifactInventory = {}
    M.GS.artifactDropPending = false
    M.GS.artifactDropCandidates = nil
end

return M
