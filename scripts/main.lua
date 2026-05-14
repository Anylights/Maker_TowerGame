-- ============================================================================
-- 正交能源塔防 - 核心原型
-- ============================================================================

local UI = require("urhox-libs/UI")

-- ============================================================================
-- 莫比斯画风渲染模块
-- ============================================================================
local nvgCtx_ = nil
local nvgFont_ = -1

-- 莫比斯配色（高饱和度 + 暖色调）
local MOEBIUS = {
    -- 轮廓线（极细 + 各物体固有色相近的深色描边）
    OutlineWidth   = 1.0,                        -- 极细线宽
    -- 各物体描边色：与固有色同色相，饱和度更高、明度更低
    OutlineEnergy  = { 160, 95, 8, 220 },        -- 深金橙（能源塔）
    OutlineTower   = { 45, 60, 115, 220 },       -- 深蓝（防御塔）
    OutlineMonster = { 135, 18, 12, 220 },       -- 深红（怪物）
    OutlineProj    = { 8, 95, 105, 200 },        -- 深青（炮弹）
    OutlineLootG   = { 150, 105, 5, 210 },       -- 深金（金币掉落）
    OutlineLootE   = { 25, 55, 125, 210 },       -- 深蓝（能量掉落）
    -- 交叉影线
    HatchColor     = { 20, 15, 10, 50 },         -- 半透明深色
    HatchSpacing   = 6,                          -- 线间距（像素）
    HatchAngle1    = 0.52,                       -- ~30度
    HatchAngle2    = -0.52,                      -- ~-30度
    -- 色调（用于材质）
    FloorDiff      = Color(0.82, 0.72, 0.55, 1), -- 沙漠暖黄
    FloorEmit      = Color(0.35, 0.30, 0.20),
    EnergyDiff     = Color(0.95, 0.68, 0.15, 1), -- 明亮金橙
    EnergyEmit     = Color(0.50, 0.35, 0.08),
    TowerDiff      = Color(0.45, 0.55, 0.72, 1), -- 天际蓝灰
    TowerEmit      = Color(0.12, 0.18, 0.30),
    MonsterDiff    = Color(0.85, 0.22, 0.18, 1), -- 鲜红
    MonsterEmit    = Color(0.35, 0.08, 0.05),
    ProjectileDiff = Color(0.15, 0.80, 0.85, 1), -- 青蓝
    ProjectileEmit = Color(0.10, 0.45, 0.50),
    GridColor      = Color(0.50, 0.42, 0.32, 0.30),-- 暖色网格
    RangeColor     = Color(0.40, 0.60, 0.80, 0.35),
    SkyTopColor    = { 140, 180, 210, 255 },     -- 天空渐变顶部
    SkyBotColor    = { 210, 195, 165, 255 },     -- 天空渐变底部
    LootGoldDiff   = Color(1.0, 0.82, 0.20, 1),
    LootGoldEmit   = Color(0.45, 0.35, 0.05),
    LootEnergyDiff = Color(0.30, 0.55, 0.90, 1),
    LootEnergyEmit = Color(0.15, 0.25, 0.50),
    LinesDiff      = Color(0.35, 0.70, 0.85, 0.85),
    LinesEmit      = Color(0.25, 0.45, 0.65),
    -- 画面边框色（极淡）
    FrameColor     = { 120, 100, 75, 60 },
}

-- ============================================================================
-- 配置
-- ============================================================================
local CONFIG = {
    Title = "Energy Tower Defense",
    -- 地图
    MapHalfW = 90,              -- 地图半宽（格）
    MapHalfH = 60,              -- 地图半高（格）
    GridSize = 1.0,             -- 每格 1 米
    -- 相机
    OrthoSize = 18.0,           -- 正交视野高度
    PanSpeed = 1.0,             -- 中键拖拽灵敏度
    ZoomSpeed = 1.5,
    ZoomMin = 6.0,
    ZoomMax = 30.0,
    -- 能源塔
    TotalPower = 100,
    EnergyRange = 7,            -- 供能半径（格）
    -- 经济
    InitialGold = 300,
    BaseCost = 30,
    CostLinear = 8,
    CostQuad = 2,
    -- 视觉
    GridColor = MOEBIUS.GridColor,
    RangeColor = MOEBIUS.RangeColor,
    LineWidth = 0.18,           -- 能源线半宽（米）
    EnergyLineY = 0.06,
    GridY = 0.02,
    HoverY = 0.04,
    -- 能源塔
    EnergyTowerHP = 500,
    EnergyTowerHPBarW = 1.4,
    EnergyTowerHPBarH = 0.12,
    EnergyTowerHPBarOffY = 2.8,  -- 圆锥顶上方
    MonsterDmgToTower = 20,      -- 每只怪物到达中心造成的伤害
    -- 怪物
    MonsterHP = 80,
    MonsterSpeed = 1.8,         -- 米/秒
    MonsterSize = 0.38,         -- 正方体边长
    SpawnInterval = 2.5,        -- 秒
    SpawnDistance = 18,          -- 从边缘多远刷新
    MonsterGoldDrop = 15,
    MonsterEnergyDrop = 5,
    -- 塔攻击
    TowerRange = 5.0,           -- 塔射程（米）
    TowerFireInterval = 1.0,    -- 射击间隔（秒）
    TowerBaseDmg = 20,          -- 基础伤害
    -- 炮弹
    ProjectileSpeed = 12.0,     -- 米/秒
    ProjectileSize = 0.15,      -- 球体半径缩放
    -- 掉落
    LootStayTime = 1.5,         -- 落地停留秒数
    LootCollectSpeed = 6.0,     -- 自动拾取飞行速度
    LootFloatHeight = 0.4,      -- 掉落物浮空高度
    -- 血条
    HPBarW = 0.5,
    HPBarH = 0.06,
    HPBarOffY = 0.6,            -- 血条在怪物上方偏移
}

-- ============================================================================
-- 状态
-- ============================================================================
---@type Scene
local scene_ = nil
---@type Node
local cameraNode_ = nil
---@type Camera
local camera_ = nil

-- 基础塔列表 { node, gx, gz, dist, delivered, linePwr, ratio }
local towers_ = {}

-- 悬停
---@type Node
local hoverNode_ = nil
local hoverGX_ = 0
local hoverGZ_ = 0
local hoverValid_ = false
local hoverOnMap_ = false

-- 能源线
---@type Node
local linesNode_ = nil

-- 经济
local gold_ = CONFIG.InitialGold

-- UI 引用
local goldLabel_ = nil
local costLabel_ = nil
local statsLabel_ = nil
local hintLabel_ = nil

-- 怪物 / 炮弹 / 掉落
local monsters_ = {}        -- { node, hp, maxHp, dir, hpBg, hpFill, fillMat }
local projectiles_ = {}     -- { node, target, speed }
local loots_ = {}           -- { node, type, timer, collecting }
local spawnTimer_ = 0

-- 浮动伤害数字
local dmgTexts_ = {}        -- { node, timer, maxTime }

-- 能源塔状态
local etHP_ = 0             -- 当前血量
local etMaxHP_ = 0
local etHPBg_ = nil         -- 血条根节点
local etHPFill_ = nil       -- 填充条节点
local etFillMat_ = nil      -- 填充条材质
local gameOver_ = false

-- 共享材质缓存
local monsterMat_ = nil
local projectileMat_ = nil
local hpBgMat_ = nil
local lootGoldMat_ = nil
local lootEnergyMat_ = nil

-- ============================================================================
-- 生命周期
-- ============================================================================

function Start()
    graphics.windowTitle = CONFIG.Title
    InitUI()
    CreateScene()
    SetupCamera()
    CreateGrid()
    CreateRangeCircle()
    PlaceEnergyTower()
    CreateHoverIndicator()
    CreateGameUI()
    InitMoebiusRenderer()
    SubscribeToEvent("Update", "HandleUpdate")
    print("=== Energy Tower Defense Started (Moebius Style) ===")
end

function Stop()
    if nvgCtx_ then
        nvgDelete(nvgCtx_)
        nvgCtx_ = nil
    end
    UI.Shutdown()
end

-- ============================================================================
-- 场景
-- ============================================================================

function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")

    -- 光照
    local lgFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    local lg = scene_:CreateChild("LightGroup")
    lg:LoadXML(lgFile:GetRoot())

    -- 地面
    local floor = scene_:CreateChild("Floor")
    floor.position = Vector3(0, -0.05, 0)
    floor.scale = Vector3(CONFIG.MapHalfW * 2 + 4, 0.1, CONFIG.MapHalfH * 2 + 4)
    local model = floor:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(MOEBIUS.FloorDiff))
    mat:SetShaderParameter("MatEmissiveColor", Variant(MOEBIUS.FloorEmit))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(1.0))
    model:SetMaterial(mat)
end

-- ============================================================================
-- 相机
-- ============================================================================

function SetupCamera()
    cameraNode_ = scene_:CreateChild("Camera")
    -- 等距45度：pitch 45 + yaw -45，位置沿反方向偏移
    cameraNode_.position = Vector3(14, 20, -14)
    cameraNode_.rotation = Quaternion(45, -45, 0)

    camera_ = cameraNode_:CreateComponent("Camera")
    camera_.nearClip = 0.5
    camera_.farClip = 500.0
    camera_.orthographic = true
    camera_.orthoSize = CONFIG.OrthoSize

    renderer:SetViewport(0, Viewport:new(scene_, camera_))
    renderer.hdrRendering = true
end

-- ============================================================================
-- 网格
-- ============================================================================

function CreateGrid()
    local node = scene_:CreateChild("Grid")
    node.position = Vector3(0, CONFIG.GridY, 0)
    local geom = node:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, LINE_LIST)

    local hw = CONFIG.MapHalfW
    local hh = CONFIG.MapHalfH

    -- 竖线（沿X）
    for x = -hw, hw do
        geom:DefineVertex(Vector3(x, 0, -hh))
        geom:DefineVertex(Vector3(x, 0, hh))
    end
    -- 横线（沿Z）
    for z = -hh, hh do
        geom:DefineVertex(Vector3(-hw, 0, z))
        geom:DefineVertex(Vector3(hw, 0, z))
    end

    geom:Commit()

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(CONFIG.GridColor))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.20, 0.16, 0.10)))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(1.0))
    geom:SetMaterial(mat)
end

-- ============================================================================
-- 供能范围圆
-- ============================================================================

function CreateRangeCircle()
    local node = scene_:CreateChild("RangeCircle")
    node.position = Vector3(0, CONFIG.GridY + 0.01, 0)
    local geom = node:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, LINE_LIST)

    local segments = 64
    local r = CONFIG.EnergyRange + 0.5  -- 半格余量，视觉上包住第7格
    for i = 0, segments - 1 do
        local a1 = (i / segments) * math.pi * 2
        local a2 = ((i + 1) / segments) * math.pi * 2
        geom:DefineVertex(Vector3(math.cos(a1) * r, 0, math.sin(a1) * r))
        geom:DefineVertex(Vector3(math.cos(a2) * r, 0, math.sin(a2) * r))
    end

    geom:Commit()

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(CONFIG.RangeColor))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.15, 0.35, 0.6)))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(0.5))
    geom:SetMaterial(mat)
end

-- ============================================================================
-- 能源塔（圆锥体）
-- ============================================================================

function PlaceEnergyTower()
    local node = scene_:CreateChild("EnergyTower")
    -- Cone 高度 1.0，底面中心在原点，需要 y=0.5 放在地面上；再放大一些
    node.position = Vector3(0, 0, 0)
    node.scale = Vector3(1.4, 2.0, 1.4)
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Cone.mdl"))

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(MOEBIUS.EnergyDiff))
    mat:SetShaderParameter("MatEmissiveColor", Variant(MOEBIUS.EnergyEmit))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(1.0))
    model:SetMaterial(mat)
    model.castShadows = true

    -- Cone 模型底面在 y=-0.5, 顶在 y=0.5，缩放 2.0 后范围 y=-1..1
    -- 要让底面贴地(y=0)，需要 node.y = 1.0 (scale.y * 0.5)
    node.position = Vector3(0, 1.0, 0)

    -- 初始化能源塔血量
    etHP_ = CONFIG.EnergyTowerHP
    etMaxHP_ = CONFIG.EnergyTowerHP

    -- 创建能源塔血条（独立节点，不受圆锥缩放影响）
    etHPBg_ = scene_:CreateChild("EnergyTowerHPBar")
    etHPBg_.position = Vector3(0, CONFIG.EnergyTowerHPBarOffY, 0)

    local bg = etHPBg_:CreateChild("ETHPBg")
    bg.scale = Vector3(CONFIG.EnergyTowerHPBarW, CONFIG.EnergyTowerHPBarH, 0.01)
    local bgModel = bg:CreateComponent("StaticModel")
    bgModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bgModel:SetMaterial(GetHPBgMaterial())

    etHPFill_ = etHPBg_:CreateChild("ETHPFill")
    etHPFill_.scale = Vector3(CONFIG.EnergyTowerHPBarW, CONFIG.EnergyTowerHPBarH * 0.75, 0.015)
    etHPFill_.position = Vector3(0, 0, 0.005)
    local fillModel = etHPFill_:CreateComponent("StaticModel")
    fillModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    etFillMat_ = Material:new()
    etFillMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    etFillMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.1, 0.9, 0.1, 1.0)))
    etFillMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.05, 0.4, 0.05)))
    etFillMat_:SetShaderParameter("Metallic", Variant(0.0))
    etFillMat_:SetShaderParameter("Roughness", Variant(0.5))
    fillModel:SetMaterial(etFillMat_)
end

-- ============================================================================
-- 悬停指示器
-- ============================================================================

function CreateHoverIndicator()
    hoverNode_ = scene_:CreateChild("Hover")
    hoverNode_.position = Vector3(0, CONFIG.HoverY, 0)
    hoverNode_.scale = Vector3(0.92, 0.02, 0.92)
    local model = hoverNode_:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(0.2, 0.8, 0.2, 0.45)))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.1, 0.4, 0.1)))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(0.5))
    model:SetMaterial(mat)

    hoverNode_.enabled = false
end

-- ============================================================================
-- UI
-- ============================================================================

function InitUI()
    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } }
        },
        scale = UI.Scale.DEFAULT,
    })
end

function CreateGameUI()
    -- 先创建 Label 存引用，再组装到布局中
    goldLabel_ = UI.Label {
        text = "",
        fontSize = 16,
        fontColor = { 255, 215, 0, 255 },
    }
    costLabel_ = UI.Label {
        text = "",
        fontSize = 13,
        fontColor = { 200, 200, 200, 200 },
    }
    statsLabel_ = UI.Label {
        text = "",
        fontSize = 13,
        fontColor = { 180, 220, 255, 230 },
    }
    hintLabel_ = UI.Label {
        text = "Left Click: Build Tower | Middle Drag: Pan | Scroll: Zoom",
        fontSize = 12,
        fontColor = { 255, 255, 230, 160 },
        position = "absolute",
        bottom = 10, left = 0, right = 0,
        textAlign = "center",
    }

    local root = UI.Panel {
        width = "100%", height = "100%",
        pointerEvents = "box-none",
        children = {
            -- 顶部状态栏
            UI.Panel {
                position = "absolute", top = 8, left = 8, right = 8,
                flexDirection = "row", justifyContent = "space-between",
                alignItems = "flex-start",
                pointerEvents = "box-none",
                children = {
                    -- 左：金币 + 造塔费用
                    UI.Panel {
                        flexDirection = "column", gap = 4,
                        backgroundColor = { 0, 0, 0, 140 },
                        borderRadius = 6, paddingX = 12, paddingY = 8,
                        children = { goldLabel_, costLabel_ }
                    },
                    -- 右：能源统计
                    UI.Panel {
                        flexDirection = "column", gap = 4,
                        backgroundColor = { 0, 0, 0, 140 },
                        borderRadius = 6, paddingX = 12, paddingY = 8,
                        children = { statsLabel_ }
                    },
                }
            },
            -- 底部提示
            hintLabel_,
        }
    }
    UI.SetRoot(root)

    RefreshUI()
end

function RefreshUI()
    local cost = GetTowerCost()
    local canBuild = gold_ >= cost

    if goldLabel_ then
        goldLabel_:SetText("Gold: " .. gold_)
    end
    if costLabel_ then
        local costStr = "Next tower: " .. cost
        if not canBuild then
            costStr = costStr .. "  (insufficient)"
        end
        costLabel_:SetText(costStr)
    end

    -- 能源统计
    if statsLabel_ then
        local n = #towers_
        local nm = #monsters_
        if n == 0 then
            statsLabel_:SetText(string.format(
                "Base HP: %d/%d | Towers: 0 | Monsters: %d",
                etHP_, etMaxHP_, nm
            ))
        else
            local totalDel = 0
            local totalLine = 0
            for _, t in ipairs(towers_) do
                totalDel = totalDel + t.delivered
                totalLine = totalLine + t.linePwr
            end
            statsLabel_:SetText(string.format(
                "Base HP: %d/%d | Towers: %d | Monsters: %d | Eff: %.0f",
                etHP_, etMaxHP_, n, nm, totalDel
            ))
        end
    end
end

-- ============================================================================
-- 经济
-- ============================================================================

function GetTowerCost()
    local n = #towers_
    return CONFIG.BaseCost + CONFIG.CostLinear * n + CONFIG.CostQuad * n * n
end

-- ============================================================================
-- 三棱锥几何体
-- ============================================================================

---@type Material
local towerMat_ = nil

function GetTowerMaterial()
    if towerMat_ then return towerMat_ end
    towerMat_ = Material:new()
    towerMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    towerMat_:SetShaderParameter("MatDiffColor", Variant(MOEBIUS.TowerDiff))
    towerMat_:SetShaderParameter("MatEmissiveColor", Variant(MOEBIUS.TowerEmit))
    towerMat_:SetShaderParameter("Metallic", Variant(0.0))
    towerMat_:SetShaderParameter("Roughness", Variant(1.0))
    towerMat_.cullMode = CULL_NONE
    return towerMat_
end

--- 在 node 上创建三棱锥 CustomGeometry（底面 y=0, 顶点 y=1, 底面半径 ~0.5）
function CreateTetrahedron(node)
    local geom = node:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, TRIANGLE_LIST)

    local h = 1.0
    local r = 0.45
    local apex = Vector3(0, h, 0)
    local v1 = Vector3(0, 0, r)                    -- 前
    local v2 = Vector3(-r * 0.866, 0, -r * 0.5)    -- 左后
    local v3 = Vector3(r * 0.866, 0, -r * 0.5)     -- 右后

    local function addTri(a, b, c)
        local n = (b - a):CrossProduct(c - a):Normalized()
        geom:DefineVertex(a); geom:DefineNormal(n); geom:DefineTexCoord(Vector2(0, 0))
        geom:DefineVertex(b); geom:DefineNormal(n); geom:DefineTexCoord(Vector2(1, 0))
        geom:DefineVertex(c); geom:DefineNormal(n); geom:DefineTexCoord(Vector2(0.5, 1))
    end

    addTri(apex, v1, v3)   -- 右前面
    addTri(apex, v3, v2)   -- 后面
    addTri(apex, v2, v1)   -- 左前面
    addTri(v1, v2, v3)     -- 底面

    geom:Commit()
    geom:SetMaterial(GetTowerMaterial())
    geom.castShadows = true
    return geom
end

-- ============================================================================
-- 塔放置
-- ============================================================================

function PlaceBasicTower(gx, gz)
    local cost = GetTowerCost()
    if gold_ < cost then return end

    gold_ = gold_ - cost

    local node = scene_:CreateChild("Tower_" .. gx .. "_" .. gz)
    node.scale = Vector3(0.7, 0.9, 0.7)
    node.position = Vector3(gx, 0, gz)
    CreateTetrahedron(node)

    local dist = math.sqrt(gx * gx + gz * gz)
    local tower = {
        node = node,
        gx = gx,
        gz = gz,
        dist = dist,
        delivered = 0,
        linePwr = 0,
        ratio = 0,
        cooldown = 0,
    }
    table.insert(towers_, tower)

    RecalculateEnergy()
    RebuildEnergyLines()
    RefreshUI()

    print(string.format("Tower built at (%d, %d), dist=%.1f, cost=%d, gold=%d",
        gx, gz, dist, cost, gold_))
end

-- ============================================================================
-- 能源计算
-- ============================================================================

--- 根据距离计算能源衰减系数（0.25 ~ 1.0）
function CalcAttenuation(dist)
    local R = CONFIG.EnergyRange
    local att = 1.0 - 0.65 * math.pow(dist / R, 1.35)
    return math.max(0.25, math.min(1.0, att))
end

function RecalculateEnergy()
    local N = #towers_
    if N == 0 then return end

    local pShare = CONFIG.TotalPower / N
    for _, t in ipairs(towers_) do
        local att = CalcAttenuation(t.dist)
        t.delivered = pShare * att
        t.linePwr = pShare - t.delivered
        t.ratio = t.delivered / CONFIG.TotalPower
    end
end

-- ============================================================================
-- 共享材质工厂
-- ============================================================================

function GetMonsterMaterial()
    if monsterMat_ then return monsterMat_ end
    monsterMat_ = Material:new()
    monsterMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    monsterMat_:SetShaderParameter("MatDiffColor", Variant(MOEBIUS.MonsterDiff))
    monsterMat_:SetShaderParameter("MatEmissiveColor", Variant(MOEBIUS.MonsterEmit))
    monsterMat_:SetShaderParameter("Metallic", Variant(0.0))
    monsterMat_:SetShaderParameter("Roughness", Variant(1.0))
    return monsterMat_
end

function GetProjectileMaterial()
    if projectileMat_ then return projectileMat_ end
    projectileMat_ = Material:new()
    projectileMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    projectileMat_:SetShaderParameter("MatDiffColor", Variant(MOEBIUS.ProjectileDiff))
    projectileMat_:SetShaderParameter("MatEmissiveColor", Variant(MOEBIUS.ProjectileEmit))
    projectileMat_:SetShaderParameter("Metallic", Variant(0.0))
    projectileMat_:SetShaderParameter("Roughness", Variant(1.0))
    return projectileMat_
end

function GetHPBgMaterial()
    if hpBgMat_ then return hpBgMat_ end
    hpBgMat_ = Material:new()
    hpBgMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    hpBgMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.1, 0.1, 0.1, 0.7)))
    hpBgMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0, 0, 0)))
    hpBgMat_:SetShaderParameter("Metallic", Variant(0.0))
    hpBgMat_:SetShaderParameter("Roughness", Variant(0.9))
    return hpBgMat_
end

function GetLootGoldMaterial()
    if lootGoldMat_ then return lootGoldMat_ end
    lootGoldMat_ = Material:new()
    lootGoldMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    lootGoldMat_:SetShaderParameter("MatDiffColor", Variant(MOEBIUS.LootGoldDiff))
    lootGoldMat_:SetShaderParameter("MatEmissiveColor", Variant(MOEBIUS.LootGoldEmit))
    lootGoldMat_:SetShaderParameter("Metallic", Variant(0.0))
    lootGoldMat_:SetShaderParameter("Roughness", Variant(1.0))
    return lootGoldMat_
end

function GetLootEnergyMaterial()
    if lootEnergyMat_ then return lootEnergyMat_ end
    lootEnergyMat_ = Material:new()
    lootEnergyMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    lootEnergyMat_:SetShaderParameter("MatDiffColor", Variant(MOEBIUS.LootEnergyDiff))
    lootEnergyMat_:SetShaderParameter("MatEmissiveColor", Variant(MOEBIUS.LootEnergyEmit))
    lootEnergyMat_:SetShaderParameter("Metallic", Variant(0.0))
    lootEnergyMat_:SetShaderParameter("Roughness", Variant(1.0))
    return lootEnergyMat_
end

-- ============================================================================
-- 怪物刷新
-- ============================================================================

function SpawnMonster()
    local node = scene_:CreateChild("Monster")

    -- 从地图边缘随机方向刷新
    local angle = math.random() * math.pi * 2
    local sd = CONFIG.SpawnDistance
    local sx = math.cos(angle) * sd
    local sz = math.sin(angle) * sd
    local s = CONFIG.MonsterSize

    node.position = Vector3(sx, s * 0.5, sz)
    node.scale = Vector3(s, s, s)

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    model:SetMaterial(GetMonsterMaterial())
    model.castShadows = true

    -- 朝向能源塔中心的方向
    local dir = Vector3(0, 0, 0) - Vector3(sx, 0, sz)
    local len = dir:Length()
    if len > 0.01 then dir = dir / len else dir = Vector3(0, 0, 1) end

    -- 血条（两个扁平 Box 叠加）
    local hpBg, hpFill, fillMat = CreateHealthBar(node)

    local monster = {
        node = node,
        hp = CONFIG.MonsterHP,
        maxHp = CONFIG.MonsterHP,
        dir = dir,
        hpBg = hpBg,
        hpFill = hpFill,
        fillMat = fillMat,
    }
    table.insert(monsters_, monster)

    print(string.format("[Spawn] Monster at (%.0f, %.0f), dir=(%.2f, %.2f)", sx, sz, dir.x, dir.z))
end

-- ============================================================================
-- 血条
-- ============================================================================

function CreateHealthBar(parentNode)
    -- 血条父节点（不受怪物缩放影响，使用世界坐标）
    local barRoot = scene_:CreateChild("HPBar")
    -- 位置跟随怪物，在 UpdateHealthBars 中每帧更新

    -- 背景
    local bg = barRoot:CreateChild("HPBg")
    bg.scale = Vector3(CONFIG.HPBarW, CONFIG.HPBarH, 0.01)
    local bgModel = bg:CreateComponent("StaticModel")
    bgModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bgModel:SetMaterial(GetHPBgMaterial())

    -- 填充条
    local fill = barRoot:CreateChild("HPFill")
    fill.scale = Vector3(CONFIG.HPBarW, CONFIG.HPBarH * 0.7, 0.015)
    local fillModel = fill:CreateComponent("StaticModel")
    fillModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    -- 每个怪物的填充条需要独立材质（颜色变化）
    local fillMat = Material:new()
    fillMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    fillMat:SetShaderParameter("MatDiffColor", Variant(Color(0.1, 0.9, 0.1, 1.0)))
    fillMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.05, 0.4, 0.05)))
    fillMat:SetShaderParameter("Metallic", Variant(0.0))
    fillMat:SetShaderParameter("Roughness", Variant(0.5))
    fillModel:SetMaterial(fillMat)

    return barRoot, fill, fillMat
end

function UpdateHealthBar(m)
    if not m.node or not m.hpBg then return end
    local pos = m.node.worldPosition
    local barY = pos.y + CONFIG.HPBarOffY
    m.hpBg.position = Vector3(pos.x, barY, pos.z)

    -- 血条始终面向相机
    m.hpBg.rotation = cameraNode_.rotation

    -- 更新填充条宽度和位置
    local ratio = math.max(0, m.hp / m.maxHp)
    local fullW = CONFIG.HPBarW
    local fillW = fullW * ratio
    m.hpFill.scale = Vector3(fillW, CONFIG.HPBarH * 0.7, 0.015)
    -- 填充条左对齐：偏移 = (fullW - fillW) / 2，沿局部X轴
    local offset = (fullW - fillW) * 0.5
    m.hpFill.position = Vector3(-offset, 0, 0.005)

    -- 颜色：绿 → 黄 → 红
    local r, g
    if ratio > 0.5 then
        r = (1.0 - ratio) * 2.0
        g = 0.9
    else
        r = 0.9
        g = ratio * 2.0
    end
    m.fillMat:SetShaderParameter("MatDiffColor", Variant(Color(r, g, 0.1, 1.0)))
    m.fillMat:SetShaderParameter("MatEmissiveColor", Variant(Color(r * 0.3, g * 0.3, 0.02)))
end

-- ============================================================================
-- 能源塔血条更新
-- ============================================================================

function UpdateEnergyTowerHP()
    if not etHPBg_ then return end

    -- 血条面向相机
    etHPBg_.rotation = cameraNode_.rotation

    -- 更新填充条
    local ratio = math.max(0, etHP_ / etMaxHP_)
    local fullW = CONFIG.EnergyTowerHPBarW
    local fillW = fullW * ratio
    etHPFill_.scale = Vector3(fillW, CONFIG.EnergyTowerHPBarH * 0.75, 0.015)
    local offset = (fullW - fillW) * 0.5
    etHPFill_.position = Vector3(-offset, 0, 0.005)

    -- 颜色
    local r, g
    if ratio > 0.5 then
        r = (1.0 - ratio) * 2.0
        g = 0.9
    else
        r = 0.9
        g = ratio * 2.0
    end
    etFillMat_:SetShaderParameter("MatDiffColor", Variant(Color(r, g, 0.1, 1.0)))
    etFillMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(r * 0.3, g * 0.3, 0.02)))
end

function DamageEnergyTower(dmg)
    if gameOver_ then return end
    etHP_ = etHP_ - dmg
    SpawnDmgText(Vector3(0, 2.0, 0), dmg)
    if etHP_ <= 0 then
        etHP_ = 0
        GameOver()
    end
end

function GameOver()
    gameOver_ = true
    print("[GameOver] Energy Tower destroyed!")

    -- 显示 Game Over UI
    local overlay = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = { 0, 0, 0, 160 },
        children = {
            UI.Panel {
                flexDirection = "column", alignItems = "center", gap = 12,
                backgroundColor = { 30, 10, 10, 220 },
                borderRadius = 12, paddingX = 40, paddingY = 30,
                children = {
                    UI.Label {
                        text = "GAME OVER",
                        fontSize = 36,
                        fontColor = { 255, 60, 60, 255 },
                    },
                    UI.Label {
                        text = string.format("Towers Built: %d | Monsters Killed: --", #towers_),
                        fontSize = 16,
                        fontColor = { 200, 200, 200, 220 },
                    },
                    UI.Label {
                        text = "Energy Tower Destroyed",
                        fontSize = 14,
                        fontColor = { 255, 180, 100, 200 },
                    },
                }
            }
        }
    }
    UI.SetRoot(overlay)
end

-- ============================================================================
-- 怪物移动
-- ============================================================================

function UpdateMonsters(dt)
    local i = 1
    while i <= #monsters_ do
        local m = monsters_[i]
        if not m.node then
            table.remove(monsters_, i)
        else
            -- 移动
            local pos = m.node.position
            local speed = CONFIG.MonsterSpeed
            pos.x = pos.x + m.dir.x * speed * dt
            pos.z = pos.z + m.dir.z * speed * dt
            m.node.position = pos

            -- 更新血条
            UpdateHealthBar(m)

            -- 到达中心检测（距离 < 1 米）
            local distToCenter = math.sqrt(pos.x * pos.x + pos.z * pos.z)
            if distToCenter < 1.0 then
                -- 到达能源塔，造成伤害
                DamageEnergyTower(CONFIG.MonsterDmgToTower)
                DestroyMonster(m)
                table.remove(monsters_, i)
            else
                i = i + 1
            end
        end
    end
end

function DestroyMonster(m)
    if m.hpBg then m.hpBg:Remove() end
    if m.node then m.node:Remove() end
end

-- ============================================================================
-- 怪物刷新计时
-- ============================================================================

function UpdateSpawning(dt)
    spawnTimer_ = spawnTimer_ + dt
    if spawnTimer_ >= CONFIG.SpawnInterval then
        spawnTimer_ = spawnTimer_ - CONFIG.SpawnInterval
        SpawnMonster()
    end
end

-- ============================================================================
-- 塔攻击系统
-- ============================================================================

function UpdateTowerAttacks(dt)
    for _, tower in ipairs(towers_) do
        tower.cooldown = tower.cooldown - dt
        if tower.cooldown <= 0 then
            -- 寻找射程内最近的怪物
            local bestM = nil
            local bestDist = CONFIG.TowerRange + 1

            for _, m in ipairs(monsters_) do
                if m.node and m.hp > 0 then
                    local dx = m.node.position.x - tower.gx
                    local dz = m.node.position.z - tower.gz
                    local d = math.sqrt(dx * dx + dz * dz)
                    if d <= CONFIG.TowerRange and d < bestDist then
                        bestDist = d
                        bestM = m
                    end
                end
            end

            if bestM then
                local att = CalcAttenuation(tower.dist)
                local dmg = CONFIG.TowerBaseDmg * att
                FireProjectile(tower, bestM, dmg)
                tower.cooldown = CONFIG.TowerFireInterval
            end
        end
    end
end

-- ============================================================================
-- 炮弹
-- ============================================================================

function FireProjectile(tower, targetMonster, dmg)
    local node = scene_:CreateChild("Projectile")
    local s = CONFIG.ProjectileSize
    node.scale = Vector3(s, s, s)
    -- 从塔顶发射（三棱锥高度约 0.9）
    node.position = Vector3(tower.gx, 0.9, tower.gz)

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
    model:SetMaterial(GetProjectileMaterial())

    local proj = {
        node = node,
        target = targetMonster,
        speed = CONFIG.ProjectileSpeed,
        damage = dmg,
    }
    table.insert(projectiles_, proj)
end

function UpdateProjectiles(dt)
    local i = 1
    while i <= #projectiles_ do
        local p = projectiles_[i]
        if not p.node then
            table.remove(projectiles_, i)
        elseif not p.target or not p.target.node or p.target.hp <= 0 then
            -- 目标已死，移除炮弹
            p.node:Remove()
            table.remove(projectiles_, i)
        else
            -- 朝目标移动
            local pos = p.node.position
            local tpos = p.target.node.position
            local dir = tpos - pos
            local dist = dir:Length()

            if dist < 0.3 then
                -- 命中！
                DamageMonster(p.target, p.damage)
                p.node:Remove()
                table.remove(projectiles_, i)
            else
                dir = dir / dist
                pos = pos + dir * p.speed * dt
                p.node.position = pos
                i = i + 1
            end
        end
    end
end

-- ============================================================================
-- 伤害与死亡
-- ============================================================================

function DamageMonster(m, dmg)
    if not m.node or m.hp <= 0 then return end
    m.hp = m.hp - dmg
    -- 弹出伤害数字
    SpawnDmgText(m.node.position, dmg)
    if m.hp <= 0 then
        KillMonster(m)
    end
end

function KillMonster(m)
    local pos = m.node.position

    -- 掉落金币和能量
    SpawnLoot(pos, "gold")
    SpawnLoot(Vector3(pos.x + 0.3, pos.y, pos.z + 0.3), "energy")

    DestroyMonster(m)
    -- 从列表中标记（节点已删，UpdateMonsters 会清理）

    print(string.format("[Kill] Monster killed at (%.1f, %.1f)", pos.x, pos.z))
end

-- ============================================================================
-- 掉落物
-- ============================================================================

function SpawnLoot(pos, lootType)
    local node = scene_:CreateChild("Loot_" .. lootType)
    local s = 0.25
    node.scale = Vector3(s, s, s)
    node.position = Vector3(pos.x, CONFIG.LootFloatHeight, pos.z)

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    if lootType == "gold" then
        model:SetMaterial(GetLootGoldMaterial())
    else
        model:SetMaterial(GetLootEnergyMaterial())
    end

    local loot = {
        node = node,
        type = lootType,
        timer = 0,
        collecting = false,
    }
    table.insert(loots_, loot)
end

function UpdateLoots(dt)
    local energyTowerPos = Vector3(0, 1.0, 0)  -- 能源塔中心
    local i = 1
    while i <= #loots_ do
        local l = loots_[i]
        if not l.node then
            table.remove(loots_, i)
        else
            l.timer = l.timer + dt

            if not l.collecting and l.timer >= CONFIG.LootStayTime then
                l.collecting = true
            end

            if l.collecting then
                -- 飞向能源塔
                local pos = l.node.position
                local dir = energyTowerPos - pos
                local dist = dir:Length()
                if dist < 0.4 then
                    -- 拾取完成
                    if l.type == "gold" then
                        gold_ = gold_ + CONFIG.MonsterGoldDrop
                    end
                    -- 能量暂不做系统效果，只视觉表示
                    l.node:Remove()
                    table.remove(loots_, i)
                    RefreshUI()
                else
                    dir = dir / dist
                    pos = pos + dir * CONFIG.LootCollectSpeed * dt
                    l.node.position = pos
                    i = i + 1
                end
            else
                -- 停留阶段：轻微上下浮动
                local pos = l.node.position
                pos.y = CONFIG.LootFloatHeight + math.sin(l.timer * 4) * 0.08
                l.node.position = pos
                i = i + 1
            end
        end
    end
end

-- ============================================================================
-- 浮动伤害数字
-- ============================================================================

function SpawnDmgText(pos, dmg)
    local node = scene_:CreateChild("DmgText")
    node.position = Vector3(pos.x, pos.y + 0.5, pos.z)

    local text3d = node:CreateComponent("Text3D")
    text3d:SetFont("Fonts/MiSans-Regular.ttf", 28)
    text3d:SetText(string.format("-%.0f", dmg))
    text3d:SetColor(Color(1.0, 0.95, 0.2, 1.0))
    text3d:SetAlignment(HA_CENTER, VA_CENTER)
    text3d:SetFaceCameraMode(FC_ROTATE_XYZ)
    text3d:SetTextEffect(TE_STROKE)
    text3d:SetEffectStrokeThickness(2)
    text3d:SetEffectColor(Color(0, 0, 0, 0.8))
    text3d.fixedScreenSize = true

    local entry = { node = node, text3d = text3d, timer = 0, maxTime = 0.8 }
    table.insert(dmgTexts_, entry)
end

function UpdateDmgTexts(dt)
    local i = 1
    while i <= #dmgTexts_ do
        local d = dmgTexts_[i]
        d.timer = d.timer + dt
        if d.timer >= d.maxTime then
            d.node:Remove()
            table.remove(dmgTexts_, i)
        else
            -- 上浮
            local pos = d.node.position
            pos.y = pos.y + 1.5 * dt
            d.node.position = pos
            -- 淡出
            local alpha = 1.0 - (d.timer / d.maxTime)
            d.text3d:SetOpacity(alpha)
            i = i + 1
        end
    end
end

-- ============================================================================
-- 能源线可视化
-- ============================================================================

function RebuildEnergyLines()
    -- 清除旧线
    if linesNode_ then
        linesNode_:Remove()
        linesNode_ = nil
    end

    if #towers_ == 0 then return end

    linesNode_ = scene_:CreateChild("EnergyLines")
    linesNode_.position = Vector3(0, CONFIG.EnergyLineY, 0)

    local geom = linesNode_:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, LINE_LIST)

    local p1 = Vector3(0, 0, 0) -- 能源塔位置（地面）

    for _, t in ipairs(towers_) do
        local p2 = Vector3(t.gx, 0, t.gz)
        geom:DefineVertex(p1)
        geom:DefineVertex(p2)
    end

    geom:Commit()

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(MOEBIUS.LinesDiff))
    mat:SetShaderParameter("MatEmissiveColor", Variant(MOEBIUS.LinesEmit))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(1.0))
    geom:SetMaterial(mat)

    print(string.format("[EnergyLines] Rebuilt %d lines (LINE_LIST)", #towers_))
end

-- ============================================================================
-- 输入处理
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    HandleCameraPan()
    HandleCameraZoom()
    UpdateEnergyTowerHP()
    UpdateDmgTexts(dt)

    if gameOver_ then return end

    HandleGridHover()
    HandlePlacement()
    -- 战斗系统
    UpdateSpawning(dt)
    UpdateMonsters(dt)
    UpdateTowerAttacks(dt)
    UpdateProjectiles(dt)
    UpdateLoots(dt)
    RefreshUI()
end

-- 中键拖拽平移
function HandleCameraPan()
    if input:GetMouseButtonDown(MOUSEB_MIDDLE) then
        local dx = input.mouseMoveX
        local dy = input.mouseMoveY
        if dx ~= 0 or dy ~= 0 then
            local worldPerPx = camera_.orthoSize / graphics:GetHeight()
            cameraNode_:Translate(Vector3(-dx * worldPerPx, dy * worldPerPx, 0))
        end
    end
end

-- 滚轮缩放
function HandleCameraZoom()
    local wheel = input.mouseMoveWheel
    if wheel ~= 0 then
        local newSize = camera_.orthoSize - wheel * CONFIG.ZoomSpeed
        camera_.orthoSize = math.max(CONFIG.ZoomMin, math.min(CONFIG.ZoomMax, newSize))
    end
end

-- 网格悬停
function HandleGridHover()
    local pos = input.mousePosition
    local sx = pos.x / graphics:GetWidth()
    local sy = pos.y / graphics:GetHeight()

    local ray = camera_:GetScreenRay(sx, sy)

    -- 射线与 Y=0 平面求交
    if math.abs(ray.direction.y) < 0.001 then
        hoverNode_.enabled = false
        hoverOnMap_ = false
        return
    end

    local t = -ray.origin.y / ray.direction.y
    if t <= 0 then
        hoverNode_.enabled = false
        hoverOnMap_ = false
        return
    end

    local hit = ray.origin + ray.direction * t
    local gx = math.floor(hit.x + 0.5)
    local gz = math.floor(hit.z + 0.5)

    -- 检查是否在地图范围内
    local hw = CONFIG.MapHalfW
    local hh = CONFIG.MapHalfH
    if gx < -hw or gx > hw or gz < -hh or gz > hh then
        hoverNode_.enabled = false
        hoverOnMap_ = false
        return
    end

    hoverOnMap_ = true
    hoverGX_ = gx
    hoverGZ_ = gz

    -- 验证放置合法性
    local dist = math.sqrt(gx * gx + gz * gz)
    local inRange = dist <= CONFIG.EnergyRange + 0.01
    local isEnergyTower = (gx == 0 and gz == 0)
    local isOccupied = false
    for _, tower in ipairs(towers_) do
        if tower.gx == gx and tower.gz == gz then
            isOccupied = true
            break
        end
    end
    local canAfford = gold_ >= GetTowerCost()

    hoverValid_ = inRange and not isEnergyTower and not isOccupied and canAfford

    -- 更新指示器
    hoverNode_.enabled = true
    hoverNode_.position = Vector3(gx, CONFIG.HoverY, gz)

    local hoverMat = hoverNode_:GetComponent("StaticModel"):GetMaterial(0)
    if hoverValid_ then
        hoverMat:SetShaderParameter("MatDiffColor", Variant(Color(0.2, 0.8, 0.2, 0.45)))
        hoverMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.1, 0.4, 0.1)))
    else
        hoverMat:SetShaderParameter("MatDiffColor", Variant(Color(0.8, 0.2, 0.2, 0.45)))
        hoverMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.4, 0.1, 0.1)))
    end

    -- 悬停提示
    if hintLabel_ then
        if isEnergyTower then
            hintLabel_:SetText(string.format(
                "Energy Tower | Total Power: %d | Range: %d | Base Dmg: %d",
                CONFIG.TotalPower, CONFIG.EnergyRange, CONFIG.TowerBaseDmg
            ))
        elseif isOccupied then
            -- 找到这座塔，显示信息
            for _, tower in ipairs(towers_) do
                if tower.gx == gx and tower.gz == gz then
                    local att = CalcAttenuation(tower.dist)
                    local dmg = CONFIG.TowerBaseDmg * att
                    hintLabel_:SetText(string.format(
                        "Tower (%d,%d) | Dist: %.1f | Attn: %.0f%% | Dmg: %.1f | Power: %.0f%%",
                        gx, gz, tower.dist, att * 100, dmg, tower.ratio * 100
                    ))
                    break
                end
            end
        elseif not inRange then
            hintLabel_:SetText("Out of energy range!")
        elseif not canAfford then
            hintLabel_:SetText("Not enough gold! Need: " .. GetTowerCost())
        else
            -- 可建造位置：显示距离、衰减、预计伤害
            local att = CalcAttenuation(dist)
            local dmg = CONFIG.TowerBaseDmg * att
            hintLabel_:SetText(string.format(
                "Click to build | Cost: %d | Dist: %.1f | Attn: %.0f%% | Dmg: %.1f",
                GetTowerCost(), dist, att * 100, dmg
            ))
        end
    end
end

-- 左键放塔
function HandlePlacement()
    if input:GetMouseButtonPress(MOUSEB_LEFT) and hoverOnMap_ and hoverValid_ then
        PlaceBasicTower(hoverGX_, hoverGZ_)
    end
end

-- ============================================================================
-- 莫比斯画风渲染模块
-- ============================================================================

function InitMoebiusRenderer()
    nvgCtx_ = nvgCreate(1)
    if not nvgCtx_ then
        print("[Moebius] ERROR: Failed to create NanoVG context")
        return
    end
    nvgFont_ = nvgCreateFont(nvgCtx_, "sans", "Fonts/MiSans-Regular.ttf")
    SubscribeToEvent(nvgCtx_, "NanoVGRender", "HandleMoebiusRender")
    print("[Moebius] Renderer initialized")
end

-- -------------------------------------------------------
-- 工具：世界坐标 → 屏幕像素
-- -------------------------------------------------------
---@param worldPos Vector3
---@return number, number
function WorldToScreen(worldPos)
    local ndc = camera_:WorldToScreenPoint(worldPos)
    return ndc.x * graphics:GetWidth(), ndc.y * graphics:GetHeight()
end

-- -------------------------------------------------------
-- 2D 凸包 (Gift Wrapping / Jarvis March)
-- 输入: {{x,y}, ...}  输出: 凸包顶点（顺序排列）
-- -------------------------------------------------------
function ConvexHull2D(pts)
    local n = #pts
    if n < 3 then return pts end
    -- 找最左点
    local s = 1
    for i = 2, n do
        if pts[i][1] < pts[s][1] or
           (pts[i][1] == pts[s][1] and pts[i][2] < pts[s][2]) then
            s = i
        end
    end
    local hull = {}
    local cur = s
    repeat
        hull[#hull + 1] = pts[cur]
        local nxt = nil
        for i = 1, n do
            if i ~= cur then
                if nxt == nil then
                    nxt = i
                else
                    local cross = (pts[nxt][1] - pts[cur][1]) * (pts[i][2] - pts[cur][2])
                                - (pts[nxt][2] - pts[cur][2]) * (pts[i][1] - pts[cur][1])
                    if cross > 0 then
                        nxt = i
                    elseif cross == 0 then
                        -- 共线取更远的
                        local d1 = (pts[nxt][1] - pts[cur][1])^2 + (pts[nxt][2] - pts[cur][2])^2
                        local d2 = (pts[i][1] - pts[cur][1])^2 + (pts[i][2] - pts[cur][2])^2
                        if d2 > d1 then nxt = i end
                    end
                end
            end
        end
        cur = nxt
    until cur == s or #hull > n
    return hull
end

-- -------------------------------------------------------
-- 将凸包向外膨胀 amount 像素
-- -------------------------------------------------------
function ExpandHull(hull, amount)
    local n = #hull
    if n < 3 or amount <= 0 then return hull end
    local cx, cy = 0, 0
    for _, p in ipairs(hull) do cx = cx + p[1]; cy = cy + p[2] end
    cx, cy = cx / n, cy / n
    local result = {}
    for _, p in ipairs(hull) do
        local dx, dy = p[1] - cx, p[2] - cy
        local d = math.sqrt(dx * dx + dy * dy)
        if d > 0.001 then
            local s = (d + amount) / d
            result[#result + 1] = { cx + dx * s, cy + dy * s }
        else
            result[#result + 1] = { p[1], p[2] }
        end
    end
    return result
end

-- -------------------------------------------------------
-- 从世界空间 3D 点集 → 投影 → 凸包 → 绘制轮廓多边形
-- -------------------------------------------------------
function DrawOutlineFromVerts(ctx, worldPts, lw, expand)
    local screen = {}
    for _, wp in ipairs(worldPts) do
        local sx, sy = WorldToScreen(wp)
        screen[#screen + 1] = { sx, sy }
    end
    local hull = ConvexHull2D(screen)
    if #hull < 3 then return end
    hull = ExpandHull(hull, expand or (lw * 0.6))

    nvgBeginPath(ctx)
    nvgMoveTo(ctx, hull[1][1], hull[1][2])
    for i = 2, #hull do
        nvgLineTo(ctx, hull[i][1], hull[i][2])
    end
    nvgClosePath(ctx)
    nvgStrokeWidth(ctx, lw)
    nvgStroke(ctx)
end

-- -------------------------------------------------------
-- 获取圆锥（能源塔）的世界顶点：底面环 + 顶点
-- node pos=(0,1,0) scale=(1.4,2.0,1.4)
-- 模型底面 y=-0.5 → 世界 y=0, 顶 y=0.5 → 世界 y=2.0
-- 底面半径 0.5*1.4 = 0.7
-- -------------------------------------------------------
function GetConeWorldVerts()
    local verts = {}
    local rimR = 0.7
    local segments = 16
    -- 顶点
    verts[#verts + 1] = Vector3(0, 2.0, 0)
    -- 底面环
    for i = 0, segments - 1 do
        local a = (i / segments) * math.pi * 2
        verts[#verts + 1] = Vector3(math.cos(a) * rimR, 0, math.sin(a) * rimR)
    end
    return verts
end

-- -------------------------------------------------------
-- 获取三棱锥（防御塔）的世界顶点
-- 本地空间: apex=(0,1,0), v1=(0,0,0.45), v2=(-0.389,0,-0.225), v3=(0.389,0,-0.225)
-- node.scale=(0.7,0.9,0.7) node.pos=(gx,0,gz)
-- -------------------------------------------------------
function GetTetraWorldVerts(gx, gz)
    local sx, sy, sz = 0.7, 0.9, 0.7
    local r = 0.45
    return {
        Vector3(gx,                    sy,                gz),                  -- apex
        Vector3(gx,                    0,                 gz + r * sz),         -- 前
        Vector3(gx - r * 0.866 * sx,   0,                 gz - r * 0.5 * sz),  -- 左后
        Vector3(gx + r * 0.866 * sx,   0,                 gz - r * 0.5 * sz),  -- 右后
    }
end

-- -------------------------------------------------------
-- 获取立方体（怪物）的8个世界顶点
-- Box 模型 -0.5~0.5, scale=(s,s,s)
-- -------------------------------------------------------
function GetBoxWorldVerts(pos, halfExt)
    local hx, hy, hz = halfExt, halfExt, halfExt
    return {
        Vector3(pos.x - hx, pos.y - hy, pos.z - hz),
        Vector3(pos.x + hx, pos.y - hy, pos.z - hz),
        Vector3(pos.x - hx, pos.y + hy, pos.z - hz),
        Vector3(pos.x + hx, pos.y + hy, pos.z - hz),
        Vector3(pos.x - hx, pos.y - hy, pos.z + hz),
        Vector3(pos.x + hx, pos.y - hy, pos.z + hz),
        Vector3(pos.x - hx, pos.y + hy, pos.z + hz),
        Vector3(pos.x + hx, pos.y + hy, pos.z + hz),
    }
end

-- -------------------------------------------------------
-- 获取球体（炮弹）的轮廓采样点
-- -------------------------------------------------------
function GetSphereWorldVerts(center, radius)
    local verts = {}
    local n = 12
    for i = 0, n - 1 do
        local a = (i / n) * math.pi * 2
        -- 赤道环
        verts[#verts + 1] = Vector3(center.x + math.cos(a) * radius, center.y, center.z + math.sin(a) * radius)
        -- 经线环（XY平面）
        verts[#verts + 1] = Vector3(center.x + math.cos(a) * radius, center.y + math.sin(a) * radius, center.z)
        -- 经线环（YZ平面）
        verts[#verts + 1] = Vector3(center.x, center.y + math.sin(a) * radius, center.z + math.cos(a) * radius)
    end
    -- 极点
    verts[#verts + 1] = Vector3(center.x, center.y + radius, center.z)
    verts[#verts + 1] = Vector3(center.x, center.y - radius, center.z)
    return verts
end

-- -------------------------------------------------------
-- 交叉影线
-- -------------------------------------------------------
function DrawHatchRegion(ctx, x, y, w, h, spacing, angle)
    nvgSave(ctx)
    nvgScissor(ctx, x, y, w, h)

    local cosA = math.cos(angle)
    local sinA = math.sin(angle)
    local diag = math.sqrt(w * w + h * h)
    local centerX = x + w * 0.5
    local centerY = y + h * 0.5

    local numLines = math.ceil(diag / spacing)
    for i = -numLines, numLines do
        local offset = i * spacing
        local mx = centerX + (-sinA) * offset
        local my = centerY + cosA * offset
        local x1 = mx - cosA * diag
        local y1 = my - sinA * diag
        local x2 = mx + cosA * diag
        local y2 = my + sinA * diag
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, x1, y1)
        nvgLineTo(ctx, x2, y2)
        nvgStroke(ctx)
    end

    nvgResetScissor(ctx)
    nvgRestore(ctx)
end

-- -------------------------------------------------------
-- 主渲染
-- -------------------------------------------------------
function HandleMoebiusRender(eventType, eventData)
    if not nvgCtx_ or not camera_ then return end

    local ctx = nvgCtx_
    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    local dpr = graphics:GetDPR()

    nvgBeginFrame(ctx, w, h, 1.0)

    local lw = MOEBIUS.OutlineWidth * dpr

    -- ================================================================
    -- 1) 天空渐变叠加
    -- ================================================================
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, w, h * 0.35)
    local skyGrad = nvgLinearGradient(ctx, 0, 0, 0, h * 0.35,
        nvgRGBA(MOEBIUS.SkyTopColor[1], MOEBIUS.SkyTopColor[2], MOEBIUS.SkyTopColor[3], 35),
        nvgRGBA(MOEBIUS.SkyBotColor[1], MOEBIUS.SkyBotColor[2], MOEBIUS.SkyBotColor[3], 0))
    nvgFillPaint(ctx, skyGrad)
    nvgFill(ctx)

    -- ================================================================
    -- 2) 物体轮廓线（凸包贴合几何体，各物体固有色深色描边）
    -- ================================================================
    local expand = lw * 0.4  -- 极细线微量膨胀即可

    -- 2a) 能源塔（圆锥）— 深金橙
    local oe = MOEBIUS.OutlineEnergy
    nvgStrokeColor(ctx, nvgRGBA(oe[1], oe[2], oe[3], oe[4]))
    DrawOutlineFromVerts(ctx, GetConeWorldVerts(), lw, expand)

    -- 2b) 防御塔（三棱锥）— 深蓝
    local ot = MOEBIUS.OutlineTower
    nvgStrokeColor(ctx, nvgRGBA(ot[1], ot[2], ot[3], ot[4]))
    for _, t in ipairs(towers_) do
        if t.node then
            DrawOutlineFromVerts(ctx, GetTetraWorldVerts(t.gx, t.gz), lw, expand)
        end
    end

    -- 2c) 怪物（立方体）— 深红
    local om = MOEBIUS.OutlineMonster
    nvgStrokeColor(ctx, nvgRGBA(om[1], om[2], om[3], om[4]))
    local mHalf = CONFIG.MonsterSize * 0.5
    for _, m in ipairs(monsters_) do
        if m.node and m.hp > 0 then
            DrawOutlineFromVerts(ctx, GetBoxWorldVerts(m.node.position, mHalf), lw, expand)
        end
    end

    -- 2d) 炮弹（球体）— 深青
    local op = MOEBIUS.OutlineProj
    nvgStrokeColor(ctx, nvgRGBA(op[1], op[2], op[3], op[4]))
    for _, p in ipairs(projectiles_) do
        if p.node then
            DrawOutlineFromVerts(ctx, GetSphereWorldVerts(p.node.position, CONFIG.ProjectileSize * 0.5), lw, expand)
        end
    end

    -- 2e) 掉落物 — 各自固有色深色
    for _, l in ipairs(loots_) do
        if l.node then
            local ol = l.type == "gold" and MOEBIUS.OutlineLootG or MOEBIUS.OutlineLootE
            nvgStrokeColor(ctx, nvgRGBA(ol[1], ol[2], ol[3], ol[4]))
            DrawOutlineFromVerts(ctx, GetBoxWorldVerts(l.node.position, 0.125), lw, expand)
        end
    end

    -- ================================================================
    -- 3) 交叉影线
    -- ================================================================
    local hc = MOEBIUS.HatchColor
    local spacing = MOEBIUS.HatchSpacing * dpr

    -- 底部影线带
    nvgStrokeColor(ctx, nvgRGBA(hc[1], hc[2], hc[3], hc[4]))
    nvgStrokeWidth(ctx, 0.8 * dpr)
    DrawHatchRegion(ctx, 0, h * 0.75, w, h * 0.25, spacing, MOEBIUS.HatchAngle1)

    -- 左右边缘淡影线
    nvgStrokeColor(ctx, nvgRGBA(hc[1], hc[2], hc[3], math.floor(hc[4] * 0.5)))
    nvgStrokeWidth(ctx, 0.6 * dpr)
    DrawHatchRegion(ctx, 0, 0, w * 0.1, h, spacing * 1.2, MOEBIUS.HatchAngle2)
    DrawHatchRegion(ctx, w * 0.9, 0, w * 0.1, h, spacing * 1.2, MOEBIUS.HatchAngle2)

    -- ================================================================
    -- 4) 画面边框
    -- ================================================================
    nvgBeginPath(ctx)
    nvgRect(ctx, 2, 2, w - 4, h - 4)
    local fc = MOEBIUS.FrameColor
    nvgStrokeColor(ctx, nvgRGBA(fc[1], fc[2], fc[3], fc[4]))
    nvgStrokeWidth(ctx, 1.5 * dpr)
    nvgStroke(ctx)

    nvgEndFrame(ctx)
end
