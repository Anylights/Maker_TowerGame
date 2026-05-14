-- ============================================================================
-- 正交能源塔防 - 核心原型
-- ============================================================================

local UI = require("urhox-libs/UI")

-- ============================================================================
-- 色调配置
-- ============================================================================
local MOEBIUS = {
    -- 色调（用于材质）
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
    LootGoldDiff   = Color(1.0, 0.82, 0.20, 1),
    LootGoldEmit   = Color(0.45, 0.35, 0.05),
    LootEnergyDiff = Color(0.30, 0.55, 0.90, 1),
    LootEnergyEmit = Color(0.15, 0.25, 0.50),
    LinesDiff      = Color(0.35, 0.70, 0.85, 0.85),
    LinesEmit      = Color(0.25, 0.45, 0.65),
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
    EnergyTowerHPBarOffY = 1.8,  -- tower-round 总高 ~1.53m，血条在上方
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
    HPBarOffY = 0.4,            -- 血条在怪物上方偏移 (UFO高约0.26m缩放后)
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
local lineMat_ = nil            -- 能源线材质（用于脉冲动画）
local linePulseTime_ = 0        -- 脉冲计时器

-- 电流脉冲系统
local pulsesNode_ = nil         -- 脉冲球的父节点
local pulses_ = {}              -- { nodes={}, fromX, fromZ, toX, toZ, t, speed }
local PULSES_PER_LINE = 3       -- 每条线上的脉冲数量
local TAIL_COUNT = 4            -- 每个脉冲的拖尾节数（不含头部，共 1+4=5 个节点）
local TAIL_SPACING = 0.045      -- 拖尾节之间的 t 间隔

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
    SubscribeToEvent("Update", "HandleUpdate")
    print("=== Energy Tower Defense Started ===")
end

function Stop()
    UI.Shutdown()
end

-- ============================================================================
-- 场景
-- ============================================================================

--- 递归遍历节点树，将所有 Light 组件的亮度乘以 factor
function DimAllLights(node, factor)
    local light = node:GetComponent("Light")
    if light then
        local b = light.brightness
        light.brightness = b * factor
    end
    for i = 0, node:GetNumChildren(false) - 1 do
        DimAllLights(node:GetChild(i), factor)
    end
end

function CreateScene()
    scene_ = Scene()
    scene_:CreateComponent("Octree")
    scene_:CreateComponent("DebugRenderer")

    -- 光照
    local lgFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    local lg = scene_:CreateChild("LightGroup")
    lg:LoadXML(lgFile:GetRoot())

    -- 整体光照降低到 0.4 倍（营造暗色氛围，突出发光效果）
    DimAllLights(lg, 0.4)

    -- 地面：用 tile 模型铺设可见区域
    CreateTileFloor()
end

--- 铺设地板
function CreateTileFloor()
    -- 纯色平整地板
    local floor = scene_:CreateChild("Floor")
    floor.position = Vector3(0, -0.05, 0)
    floor.scale = Vector3(CONFIG.MapHalfW * 2 + 4, 0.1, CONFIG.MapHalfH * 2 + 4)
    local floorModel = floor:CreateComponent("StaticModel")
    floorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    local floorMat = Material:new()
    floorMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    floorMat:SetShaderParameter("MatDiffColor", Variant(Color(0.45, 0.72, 0.56, 1)))  -- 草绿
    floorMat:SetShaderParameter("Roughness", Variant(1.0))
    floorMat:SetShaderParameter("Metallic", Variant(0.0))
    floorModel:SetMaterial(floorMat)
    floorModel.castShadows = false

    -- 装饰物（树、岩石、水晶）散布在能源范围外围
    local DECO_RANGE = CONFIG.EnergyRange + 12
    local DECO_MODELS = {
        { mdl = "Meshes/TD/tile-rock.mdl",    mat = "Materials/TD/tile-rock_00_colormap.xml" },
        { mdl = "Meshes/TD/tile-tree.mdl",    mat = "Materials/TD/tile-tree_00_colormap.xml" },
        { mdl = "Meshes/TD/tile-crystal.mdl", mat = "Materials/TD/tile-crystal_00_colormap.xml" },
        { mdl = "Meshes/TD/tile-dirt.mdl",    mat = "Materials/TD/tile-dirt_00_colormap.xml" },
    }

    math.randomseed(42)  -- 固定种子保证每次生成一致
    local decoParent = scene_:CreateChild("FloorDeco")
    for x = -DECO_RANGE, DECO_RANGE do
        for z = -DECO_RANGE, DECO_RANGE do
            local dist = math.sqrt(x * x + z * z)
            -- 在能源范围外随机放装饰
            if dist > CONFIG.EnergyRange + 1 and math.random() < 0.08 then
                local deco = DECO_MODELS[math.random(1, #DECO_MODELS)]
                local child = decoParent:CreateChild("Deco")
                child.position = Vector3(x, 0, z)
                child.rotation = Quaternion(math.random(0, 3) * 90, Vector3.UP)
                local m = child:CreateComponent("StaticModel")
                m:SetModel(cache:GetResource("Model", deco.mdl))
                m:SetMaterial(cache:GetResource("Material", deco.mat))
                m.castShadows = true
            end
        end
    end
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
    node.position = Vector3(0, 0, 0)
    -- 整体缩放 1.6 倍，让能源塔更大更醒目
    local sc = 1.6
    node.scale = Vector3(sc, sc, sc)

    -- 底座: tower-round-base (1×0.21×1m)
    local baseChild = node:CreateChild("ETBase")
    local baseModel = baseChild:CreateComponent("StaticModel")
    baseModel:SetModel(cache:GetResource("Model", "Meshes/TD/tower-round-base.mdl"))
    baseModel:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-round-base_00_colormap.xml"))
    baseModel.castShadows = true

    -- 塔身第1层: tower-round-top-a (0.92×0.5×0.92m)
    local bodyChild1 = node:CreateChild("ETBody1")
    bodyChild1.position = Vector3(0, 0.21, 0)
    local bodyModel1 = bodyChild1:CreateComponent("StaticModel")
    bodyModel1:SetModel(cache:GetResource("Model", "Meshes/TD/tower-round-top-a.mdl"))
    bodyModel1:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-round-top-a_00_colormap.xml"))
    bodyModel1.castShadows = true

    -- 塔身第2层: 再叠一层 tower-round-top-a
    local bodyChild2 = node:CreateChild("ETBody2")
    bodyChild2.position = Vector3(0, 0.71, 0)  -- 0.21 + 0.50
    local bodyModel2 = bodyChild2:CreateComponent("StaticModel")
    bodyModel2:SetModel(cache:GetResource("Model", "Meshes/TD/tower-round-top-a.mdl"))
    bodyModel2:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-round-top-a_00_colormap.xml"))
    bodyModel2.castShadows = true

    -- 水晶: tower-round-crystals (1×0.82×1m)
    local crystalChild = node:CreateChild("ETCrystals")
    crystalChild.position = Vector3(0, 1.21, 0)  -- 0.21 + 0.50 + 0.50
    local crystalModel = crystalChild:CreateComponent("StaticModel")
    crystalModel:SetModel(cache:GetResource("Model", "Meshes/TD/tower-round-crystals.mdl"))
    crystalModel:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-round-crystals_00_colormap.xml"))
    crystalModel.castShadows = true
    -- 模型原始总高度: 0.21 + 0.50 + 0.50 + 0.82 = 2.03 米
    -- 缩放后: 2.03 × 1.6 ≈ 3.25 米

    -- 发光粒子环绕效果（底部环形发射，独立节点不受塔缩放影响）
    local particleNode = scene_:CreateChild("ETParticles")
    particleNode.position = Vector3(0, 0.25, 0)  -- 底部高度

    local emitter = particleNode:CreateComponent("ParticleEmitter")
    local effect = ParticleEffect()

    -- 扁平环形发射区域：宽环、极薄高度
    effect:SetEmitterType(EMITTER_SPHERE)
    effect:SetEmitterSize(Vector3(2.6, 0.15, 2.6))
    effect:SetNumParticles(80)

    effect:SetMinEmissionRate(35)
    effect:SetMaxEmissionRate(55)
    -- 消散更快
    effect:SetMinTimeToLive(0.4)
    effect:SetMaxTimeToLive(0.9)
    -- 粒子更小
    effect:SetMinParticleSize(Vector2(0.015, 0.015))
    effect:SetMaxParticleSize(Vector2(0.04, 0.04))

    -- 向上快速飘散
    effect:SetMinDirection(Vector3(-0.2, 1.0, -0.2))
    effect:SetMaxDirection(Vector3(0.2, 1.5, 0.2))
    effect:SetMinVelocity(0.8)
    effect:SetMaxVelocity(1.5)
    effect:SetDampingForce(1.5)

    effect:SetMinRotationSpeed(90)
    effect:SetMaxRotationSpeed(240)

    -- 快速闪亮后迅速消散
    effect:AddColorTime(Color(1.0, 0.9, 0.4, 0.0), 0.0)
    effect:AddColorTime(Color(1.0, 0.8, 0.25, 1.0), 0.1)
    effect:AddColorTime(Color(1.0, 0.65, 0.15, 0.5), 0.4)
    effect:AddColorTime(Color(0.8, 0.4, 0.05, 0.0), 1.0)

    -- 强发光材质
    local pMat = Material:new()
    pMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    pMat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.85, 0.35, 1.0)))
    pMat:SetShaderParameter("MatEmissiveColor", Variant(Color(2.0, 1.5, 0.4)))
    pMat:SetShaderParameter("Metallic", Variant(0.0))
    pMat:SetShaderParameter("Roughness", Variant(1.0))
    effect:SetMaterial(pMat)

    emitter:SetEffect(effect)
    emitter:SetEmitting(true)

    -- 初始化能源塔血量
    etHP_ = CONFIG.EnergyTowerHP
    etMaxHP_ = CONFIG.EnergyTowerHP

    -- 创建能源塔血条（独立节点，不受塔缩放影响）
    etHPBg_ = scene_:CreateChild("EnergyTowerHPBar")
    etHPBg_.position = Vector3(0, 3.6, 0)  -- 缩放后塔顶约3.25m，血条在上方

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
    -- selection-a 原始 1×0.05×1m, 缩放到 0.92 适配网格
    hoverNode_.scale = Vector3(0.92, 1.0, 0.92)
    local model = hoverNode_:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Meshes/TD/selection-a.mdl"))

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
-- 防御塔武器模型列表（随机选择）
-- ============================================================================
local WEAPON_MODELS = {
    "weapon-cannon",
    "weapon-ballista",
    "weapon-catapult",
    "weapon-turret",
}

--- 在 node 上创建防御塔模型（底座 + 武器）
function CreateTowerModel(node)
    -- 底座: tower-square-bottom-a (1×0.5×1m, 底面 y=0)
    local baseChild = node:CreateChild("TowerBase")
    local baseModel = baseChild:CreateComponent("StaticModel")
    baseModel:SetModel(cache:GetResource("Model", "Meshes/TD/tower-square-bottom-a.mdl"))
    baseModel:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-square-bottom-a_00_colormap.xml"))
    baseModel.castShadows = true

    -- 武器: 随机选择一种，叠在底座上方 (底座高 0.5m)
    local weaponName = WEAPON_MODELS[math.random(1, #WEAPON_MODELS)]
    local weaponChild = node:CreateChild("TowerWeapon")
    weaponChild.position = Vector3(0, 0.5, 0)  -- 底座高度
    local weaponModel = weaponChild:CreateComponent("StaticModel")
    weaponModel:SetModel(cache:GetResource("Model", "Meshes/TD/" .. weaponName .. ".mdl"))
    weaponModel:SetMaterial(cache:GetResource("Material", "Materials/TD/" .. weaponName .. "_00_colormap.xml"))
    weaponModel.castShadows = true
    -- 总高度: 0.5 + ~0.53 ≈ 1.03 米
end

-- ============================================================================
-- 塔放置
-- ============================================================================

function PlaceBasicTower(gx, gz)
    local cost = GetTowerCost()
    if gold_ < cost then return end

    gold_ = gold_ - cost

    local node = scene_:CreateChild("Tower_" .. gx .. "_" .. gz)
    node.position = Vector3(gx, 0, gz)
    CreateTowerModel(node)

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
        weaponYaw = 0,      -- 当前武器朝向角度
        targetYaw = nil,     -- 目标朝向角度（nil=无目标）
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

-- 怪物UFO模型列表（随机选择）
local UFO_MODELS = { "enemy-ufo-a", "enemy-ufo-b", "enemy-ufo-c", "enemy-ufo-d" }

function SpawnMonster()
    local node = scene_:CreateChild("Monster")

    -- 从地图边缘随机方向刷新
    local angle = math.random() * math.pi * 2
    local sd = CONFIG.SpawnDistance
    local sx = math.cos(angle) * sd
    local sz = math.sin(angle) * sd
    local s = CONFIG.MonsterSize  -- 缩放比例

    -- UFO 模型原始宽 1m，缩放到 MonsterSize 大小
    node.position = Vector3(sx, 0, sz)  -- 模型底面 y=0，直接贴地
    node.scale = Vector3(s, s, s)

    -- 随机选择一种UFO模型
    local ufoName = UFO_MODELS[math.random(1, #UFO_MODELS)]
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Meshes/TD/" .. ufoName .. ".mdl"))
    model:SetMaterial(cache:GetResource("Material", "Materials/TD/" .. ufoName .. "_00_colormap.xml"))
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
    SpawnDmgText(Vector3(0, 3.0, 0), dmg)
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

--- 将角度归一化到 -180 ~ 180 范围
local function NormalizeAngle(a)
    a = a % 360
    if a > 180 then a = a - 360 end
    return a
end

function UpdateTowerAttacks(dt)
    local ROTATE_SPEED = 720  -- 度/秒，旋转很快但平滑

    for _, tower in ipairs(towers_) do
        -- 平滑旋转武器朝向
        if tower.targetYaw then
            local weaponNode = tower.node:GetChild("TowerWeapon", false)
            if weaponNode then
                local diff = NormalizeAngle(tower.targetYaw - tower.weaponYaw)
                local maxStep = ROTATE_SPEED * dt
                if math.abs(diff) <= maxStep then
                    tower.weaponYaw = tower.targetYaw
                else
                    if diff > 0 then
                        tower.weaponYaw = tower.weaponYaw + maxStep
                    else
                        tower.weaponYaw = tower.weaponYaw - maxStep
                    end
                end
                weaponNode.rotation = Quaternion(tower.weaponYaw, Vector3.UP)
            end
        end

        -- 每帧寻找射程内最近的怪物（用于跟踪朝向）
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

        -- 持续跟踪最近敌人方向（无论是否在冷却中）
        if bestM then
            local tpos = bestM.node.position
            local dx = tpos.x - tower.gx
            local dz = tpos.z - tower.gz
            tower.targetYaw = math.deg(math.atan(dx, dz)) + 180
        end

        -- 冷却完毕才开火
        tower.cooldown = tower.cooldown - dt
        if tower.cooldown <= 0 and bestM then
            local att = CalcAttenuation(tower.dist)
            local dmg = CONFIG.TowerBaseDmg * att
            FireProjectile(tower, bestM, dmg)
            tower.cooldown = CONFIG.TowerFireInterval
        end
    end
end

-- ============================================================================
-- 炮弹
-- ============================================================================

function FireProjectile(tower, targetMonster, dmg)
    local node = scene_:CreateChild("Projectile")
    -- weapon-ammo-cannonball 原始直径 0.28m, 按需缩放
    local s = CONFIG.ProjectileSize / 0.28  -- 相对于原始尺寸的缩放
    node.scale = Vector3(s, s, s)
    -- 从塔顶发射（tower-square-bottom 0.5 + weapon ~0.53 ≈ 1.03）
    node.position = Vector3(tower.gx, 1.0, tower.gz)

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Meshes/TD/weapon-ammo-cannonball.mdl"))
    model:SetMaterial(cache:GetResource("Material", "Materials/TD/weapon-ammo-cannonball_00_colormap.xml"))

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
    -- detail-crystal 原始尺寸约 0.25×0.43×0.29m，适当缩放
    local s = 0.6
    node.scale = Vector3(s, s, s)
    node.position = Vector3(pos.x, CONFIG.LootFloatHeight, pos.z)

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Meshes/TD/detail-crystal.mdl"))
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
    -- 清除旧线和脉冲
    if linesNode_ then
        linesNode_:Remove()
        linesNode_ = nil
    end
    if pulsesNode_ then
        pulsesNode_:Remove()
        pulsesNode_ = nil
    end
    pulses_ = {}
    lineMat_ = nil

    if #towers_ == 0 then return end

    -- === 1. 用拉伸 Box 模型实现粗发光线段 ===
    local LINE_Y = 0.15          -- 抬高到地面上方，确保可见
    local LINE_THICK = 0.10      -- 线条粗细（Y 方向）
    local LINE_WIDTH = 0.14      -- 线条宽度（垂直于线方向的XZ平面宽度）

    linesNode_ = scene_:CreateChild("EnergyLines")

    -- 共享发光材质
    lineMat_ = Material:new()
    lineMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    lineMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.25, 0.55, 0.85, 1.0)))
    lineMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.5, 1.0, 1.5)))
    lineMat_:SetShaderParameter("Metallic", Variant(0.0))
    lineMat_:SetShaderParameter("Roughness", Variant(1.0))

    for _, t in ipairs(towers_) do
        local dx = t.gx
        local dz = t.gz
        local len = math.sqrt(dx * dx + dz * dz)
        if len > 0.01 then
            local lineNode = linesNode_:CreateChild("Line")
            -- 中点位置
            lineNode.position = Vector3(dx * 0.5, LINE_Y, dz * 0.5)
            -- 旋转：让 Box 的 Z 轴对齐线段方向
            local angle = math.deg(math.atan(dx, dz))
            lineNode.rotation = Quaternion(angle, Vector3.UP)
            -- 缩放：Box 默认 1x1x1, Z=线长, X=宽, Y=厚
            lineNode.scale = Vector3(LINE_WIDTH, LINE_THICK, len)

            local model = lineNode:CreateComponent("StaticModel")
            model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            model:SetMaterial(lineMat_)
            model.castShadows = false
        end
    end

    -- === 2. 创建电流脉冲（头部+拖尾段） ===
    pulsesNode_ = scene_:CreateChild("EnergyPulses")

    -- 为头部和每级拖尾创建独立材质（emissive 递减）
    local TOTAL_SEGMENTS = 1 + TAIL_COUNT  -- 头部 + 拖尾
    local segMats = {}
    for si = 1, TOTAL_SEGMENTS do
        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        -- 从头到尾：亮度 1.0 → 0.0 指数衰减
        local falloff = 1.0 - ((si - 1) / TOTAL_SEGMENTS)
        falloff = falloff * falloff  -- 平方衰减，尾部更暗
        local eR = 1.8 * falloff
        local eG = 3.0 * falloff
        local eB = 4.0 * falloff
        local dR = 0.4 + 0.5 * falloff
        local dG = 0.7 + 0.3 * falloff
        local dB = 0.9 + 0.1 * falloff
        mat:SetShaderParameter("MatDiffColor", Variant(Color(dR, dG, dB, 1.0)))
        mat:SetShaderParameter("MatEmissiveColor", Variant(Color(eR, eG, eB)))
        mat:SetShaderParameter("Metallic", Variant(0.0))
        mat:SetShaderParameter("Roughness", Variant(1.0))
        segMats[si] = mat
    end

    local sphereMdl = cache:GetResource("Model", "Models/Sphere.mdl")

    for _, t in ipairs(towers_) do
        local dist = math.sqrt(t.gx * t.gx + t.gz * t.gz)
        local speed = 1.0 / math.max(0.3, dist / 5.0)

        for k = 1, PULSES_PER_LINE do
            local initT = (k - 1) / PULSES_PER_LINE
            local nodes = {}

            for si = 1, TOTAL_SEGMENTS do
                local n = pulsesNode_:CreateChild("Seg")
                -- 头部最大，拖尾逐渐变小
                local sizeFalloff = 1.0 - ((si - 1) / TOTAL_SEGMENTS) * 0.65
                local baseSize = 0.16 * sizeFalloff
                n.scale = Vector3(baseSize, baseSize, baseSize)
                local m = n:CreateComponent("StaticModel")
                m:SetModel(sphereMdl)
                m:SetMaterial(segMats[si])
                m.castShadows = false
                nodes[si] = { node = n, baseSize = baseSize }
            end

            local pulse = {
                nodes = nodes,
                fromX = 0, fromZ = 0,
                toX = t.gx, toZ = t.gz,
                t = initT,
                speed = speed,
            }
            table.insert(pulses_, pulse)
        end
    end

    print(string.format("[EnergyLines] Rebuilt %d lines + %d pulses (%d segments each)",
        #towers_, #pulses_, TOTAL_SEGMENTS))
end

--- 能源线脉冲动画 + 电流流动更新（在 HandleUpdate 中调用）
function UpdateEnergyLinePulse(dt)
    -- 线条呼吸动画
    if lineMat_ then
        linePulseTime_ = linePulseTime_ + dt
        local pulse = 0.5 + 0.5 * math.sin(linePulseTime_ * 3.0)
        local intensity = 0.6 + pulse * 1.0
        lineMat_:SetShaderParameter("MatEmissiveColor",
            Variant(Color(0.5 * intensity, 1.0 * intensity, 1.5 * intensity)))
    end

    -- 电流脉冲段沿线流动（头部+拖尾）
    local LINE_Y = 0.15
    for _, p in ipairs(pulses_) do
        p.t = p.t + p.speed * dt
        if p.t >= 1.0 then
            p.t = p.t - 1.0
        end

        for si, seg in ipairs(p.nodes) do
            if seg.node then
                -- 头部 si=1 在 p.t, 拖尾 si=2,3... 在 p.t 后方
                local segT = p.t - (si - 1) * TAIL_SPACING
                -- 环绕处理
                if segT < 0 then segT = segT + 1.0 end

                local px = p.fromX + (p.toX - p.fromX) * segT
                local pz = p.fromZ + (p.toZ - p.fromZ) * segT
                seg.node.position = Vector3(px, LINE_Y, pz)

                -- 缩放保持 baseSize 不变
                local s = seg.baseSize
                seg.node.scale = Vector3(s, s, s)
            end
        end
    end
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
    UpdateEnergyLinePulse(dt)
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


