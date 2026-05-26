-- ============================================================================
-- Scene.lua — 场景创建 / 光照 / 地板 / 网格 / 范围圆 / 相机 / 输入
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local MOEBIUS = Cfg.MOEBIUS
local GS = Cfg.GS
local EnergyTower -- lazy require to avoid circular dependency

local M = {}

-- 范围圆子节点引用
local rangeDiscNode_ = nil
local rangeRingNode_ = nil

-- 出怪方向弧段节点列表 (在范围圈上标红)
-- spawnArcNodes_[i] = { node, mat, isActive }
local spawnArcNodes_ = {}
-- 弧段动画时间
local spawnArcTime_ = 0

-- 升级提示箭头
local upgradeHintNode_ = nil



-- ============================================================================
-- Thronefall 风格光照方案
-- 高饱和度彩色阴影 + 低多边形色块感 + 统一色调板
-- ============================================================================

--- 创建 Thronefall 风格的场景光照
local function SetupThronefallLighting()
    -- ---- Zone（全局环境光 + 雾）----
    local zoneNode = GS.scene:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-500, -500, -500), Vector3(500, 500, 500))

    -- 环境色：暗青绿，阴影深但带色调（Thronefall 标志性彩色阴影）
    zone.ambientColor = Color(0.05, 0.10, 0.12)

    -- 雾色：偏暖的低饱和色，远处地面融入天空
    zone.fogColor = Color(0.55, 0.65, 0.60)
    zone.fogStart = 60.0
    zone.fogEnd = 180.0

    -- ---- 主方向光（太阳）----
    local sunNode = GS.scene:CreateChild("Sun")
    sunNode.direction = Vector3(0.5, -0.8, 0.6)
    local sun = sunNode:CreateComponent("Light")
    sun.lightType = LIGHT_DIRECTIONAL
    -- 偏暖的阳光，但不过亮，制造与冷色阴影的对比
    sun.color = Color(1.0, 0.88, 0.72)
    sun.brightness = 1.2
    sun.castShadows = true
    sun.shadowBias = BiasParameters(0.00025, 0.5)
    sun.shadowCascade = CascadeParameters(10.0, 40.0, 150.0, 0.0, 0.8)
    -- shadowIntensity = 阴影中残留光照比例，0.0 = 全黑（最深）
    sun.shadowIntensity = 0.0
    sun.specularIntensity = 0.0  -- 完全关闭高光，纯哑光卡通感

    -- ---- 补光（天光，从上方填充，偏冷蓝）----
    local fillNode = GS.scene:CreateChild("FillLight")
    fillNode.direction = Vector3(-0.3, -1.0, -0.2)
    local fill = fillNode:CreateComponent("Light")
    fill.lightType = LIGHT_DIRECTIONAL
    fill.color = Color(0.35, 0.45, 0.60)  -- 冷蓝补光
    fill.brightness = 0.15
    fill.castShadows = false
    fill.specularIntensity = 0.0  -- 补光不产生高光

    -- ---- 渲染器设置 ----
    renderer:SetDrawShadows(true)
    renderer:SetShadowQuality(SHADOWQUALITY_PCF_24BIT)
    renderer:SetShadowMapSize(2048)
    renderer:SetSpecularLighting(false)  -- 全局关闭镜面反射，消除塑料感

    -- 保存引用，供后续动态调色使用
    GS.zone = zone
    GS.sunLight = sun
end

-- ============================================================================
-- 场景
-- ============================================================================

function M.CreateScene()
    GS.scene = Scene()
    GS.scene:CreateComponent("Octree")
    GS.scene:CreateComponent("DebugRenderer")

    -- Thronefall 风格光照
    SetupThronefallLighting()

    -- 地面
    M.CreateTileFloor()
end

-- ============================================================================
-- 地板
-- ============================================================================

function M.CreateTileFloor()
    local scaleXZ = CONFIG.MapHalfW * 2 + 4

    -- 整块地面：无光照技术，输入线性空间颜色，gamma校正后屏幕显示 #44A06D
    -- #44A06D sRGB(0.267,0.627,0.427) → 线性 = pow(sRGB, 2.2)
    local floorMat = Material:new()
    floorMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureUnlit.xml"))
    floorMat:SetShaderParameter("MatDiffColor", Variant(Vector4(0.062, 0.352, 0.143, 1.0)))

    local floor = GS.scene:CreateChild("Floor")
    floor.position = Vector3(0, -0.1, 0)
    floor.scale    = Vector3(scaleXZ, 0.2, scaleXZ)
    local floorModel = floor:CreateComponent("StaticModel")
    floorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    floorModel:SetMaterial(floorMat)
    floorModel.castShadows = false

    -- 装饰地块：tile 底板 + detail 装饰件（Kenney TD kit 配套使用）
    local decoSets = {
        {
            tile   = "Meshes/TD/tile-rock.mdl",    tileMat   = "Materials/TD/tile-rock_00_colormap.xml",
            detail = "Meshes/TD/detail-rocks.mdl", detailMat = "Materials/TD/detail-rocks_00_colormap.xml",
        },
        {
            tile   = "Meshes/TD/tile-tree.mdl",    tileMat   = "Materials/TD/tile-tree_00_colormap.xml",
            detail = "Meshes/TD/detail-tree.mdl",  detailMat = "Materials/TD/detail-tree_00_colormap.xml",
        },
        {
            tile   = "Meshes/TD/tile-crystal.mdl", tileMat   = "Materials/TD/tile-crystal_00_colormap.xml",
            detail = "Meshes/TD/detail-crystal.mdl", detailMat = "Materials/TD/detail-crystal_00_colormap.xml",
        },
        {
            tile   = "Meshes/TD/tile-dirt.mdl",    tileMat   = "Materials/TD/tile-dirt_00_colormap.xml",
            detail = "Meshes/TD/detail-dirt.mdl",  detailMat = "Materials/TD/detail-dirt_00_colormap.xml",
        },
    }

    math.randomseed(42)
    local DECO_RANGE = CONFIG.EnergyRange + 14
    local decoParent = GS.scene:CreateChild("FloorDeco")

    for x = -DECO_RANGE, DECO_RANGE do
        for z = -DECO_RANGE, DECO_RANGE do
            local dist = math.sqrt(x * x + z * z)
            if dist > CONFIG.EnergyRange + 2 and math.random() < 0.06 then
                local s   = decoSets[math.random(1, #decoSets)]
                local rot = math.random(0, 3) * 90
                local sc  = 0.8 + math.random() * 0.4

                local group = decoParent:CreateChild("FloorDecoGroup")
                group.position = Vector3(x, 0.0, z)
                group.rotation = Quaternion(rot, Vector3.UP)
                group.scale    = Vector3(sc, sc, sc)

                -- 底板 tile
                local tileNode = group:CreateChild("Tile")
                local tm = tileNode:CreateComponent("StaticModel")
                tm:SetModel(cache:GetResource("Model", s.tile))
                tm:SetMaterial(cache:GetResource("Material", s.tileMat))
                tm.castShadows = false

                -- 上方 detail 装饰
                local detailNode = group:CreateChild("Detail")
                local dm = detailNode:CreateComponent("StaticModel")
                dm:SetModel(cache:GetResource("Model", s.detail))
                dm:SetMaterial(cache:GetResource("Material", s.detailMat))
                dm.castShadows = true
            end
        end
    end
end

-- ============================================================================
-- 相机
-- ============================================================================

function M.SetupCamera()
    GS.cameraNode = GS.scene:CreateChild("Camera")
    GS.cameraNode.position = Vector3(14, 20, -14)
    GS.cameraNode.rotation = Quaternion(45, -45, 0)

    GS.camera = GS.cameraNode:CreateComponent("Camera")
    GS.camera.nearClip = 0.5
    GS.camera.farClip = 500.0
    GS.camera.orthographic = true
    GS.camera.orthoSize = CONFIG.OrthoSize

    renderer:SetViewport(0, Viewport:new(GS.scene, GS.camera))
end

-- ============================================================================
-- 网格
-- ============================================================================

function M.CreateGrid()
    local node = GS.scene:CreateChild("Grid")
    node.position = Vector3(0, CONFIG.GridY, 0)
    local geom = node:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, LINE_LIST)

    local hw = CONFIG.MapHalfW
    local hh = CONFIG.MapHalfH
    for x = -hw, hw do
        geom:DefineVertex(Vector3(x, 0, -hh))
        geom:DefineVertex(Vector3(x, 0, hh))
    end
    for z = -hh, hh do
        geom:DefineVertex(Vector3(-hw, 0, z))
        geom:DefineVertex(Vector3(hw, 0, z))
    end
    geom:Commit()

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureUnlit.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(0.10, 0.28, 0.12, 0.20)))
    geom:SetMaterial(mat)
end

-- ============================================================================
-- 供能范围圆（双层：填充圆盘 + 亮边框线圈）
-- ============================================================================

--- 辅助：构建填充圆盘几何体 (TRIANGLE_LIST 扇形)
local function BuildDiscGeometry(geom, r, segments)
    geom:BeginGeometry(0, TRIANGLE_LIST)
    local center = Vector3(0, 0, 0)
    for i = 0, segments - 1 do
        local a1 = (i / segments) * math.pi * 2
        local a2 = ((i + 1) / segments) * math.pi * 2
        geom:DefineVertex(center)
        geom:DefineNormal(Vector3.UP)
        geom:DefineVertex(Vector3(math.cos(a1) * r, 0, math.sin(a1) * r))
        geom:DefineNormal(Vector3.UP)
        geom:DefineVertex(Vector3(math.cos(a2) * r, 0, math.sin(a2) * r))
        geom:DefineNormal(Vector3.UP)
    end
    geom:Commit()
end

--- 辅助：构建线圈几何体 (LINE_LIST)
local function BuildRingGeometry(geom, r, segments)
    geom:BeginGeometry(0, LINE_LIST)
    for i = 0, segments - 1 do
        local a1 = (i / segments) * math.pi * 2
        local a2 = ((i + 1) / segments) * math.pi * 2
        geom:DefineVertex(Vector3(math.cos(a1) * r, 0, math.sin(a1) * r))
        geom:DefineVertex(Vector3(math.cos(a2) * r, 0, math.sin(a2) * r))
    end
    geom:Commit()
end

--- 辅助: 在范围圈上构建一段宽弧带 (TRIANGLE_LIST)
--- 用于出怪方向高亮, r=半径, centerAngle=中心角度, halfAngle=半角, thickness=径向宽度
local function BuildArcBandGeometry(geom, r, centerAngle, halfAngle, thickness, segments)
    geom:BeginGeometry(0, TRIANGLE_LIST)
    local r0 = r - thickness * 0.5
    local r1 = r + thickness * 0.5
    for i = 0, segments - 1 do
        local a0 = centerAngle - halfAngle + (i / segments) * halfAngle * 2
        local a1 = centerAngle - halfAngle + ((i + 1) / segments) * halfAngle * 2
        local cos0, sin0 = math.cos(a0), math.sin(a0)
        local cos1, sin1 = math.cos(a1), math.sin(a1)
        local il = Vector3(cos0 * r0, 0, sin0 * r0)
        local ir = Vector3(cos1 * r0, 0, sin1 * r0)
        local or_ = Vector3(cos1 * r1, 0, sin1 * r1)
        local ol = Vector3(cos0 * r1, 0, sin0 * r1)
        geom:DefineVertex(il); geom:DefineNormal(Vector3.UP)
        geom:DefineVertex(ir); geom:DefineNormal(Vector3.UP)
        geom:DefineVertex(or_); geom:DefineNormal(Vector3.UP)
        geom:DefineVertex(il); geom:DefineNormal(Vector3.UP)
        geom:DefineVertex(or_); geom:DefineNormal(Vector3.UP)
        geom:DefineVertex(ol); geom:DefineNormal(Vector3.UP)
    end
    geom:Commit()
end

function M.CreateRangeCircle()
    local parent = GS.scene:CreateChild("RangeCircle")
    parent.position = Vector3(0, 0, 0)
    GS.rangeCircleNode_ = parent

    local segments = 64
    local r = CONFIG.EnergyRange + 0.5

    -- 层1: 填充圆盘（半透明）
    rangeDiscNode_ = parent:CreateChild("RangeDisc")
    rangeDiscNode_.position = Vector3(0, CONFIG.GridY + 0.005, 0)
    local discGeom = rangeDiscNode_:CreateComponent("CustomGeometry")
    BuildDiscGeometry(discGeom, r, segments)

    local discMat = Material:new()
    discMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureUnlit.xml"))
    discMat:SetShaderParameter("MatDiffColor", Variant(Color(0.30, 0.55, 0.80, 0.08)))
    discGeom:SetMaterial(discMat)

    -- 层2: 边框线圈（加亮）
    rangeRingNode_ = parent:CreateChild("RangeRing")
    rangeRingNode_.position = Vector3(0, CONFIG.GridY + 0.015, 0)
    local ringGeom = rangeRingNode_:CreateComponent("CustomGeometry")
    BuildRingGeometry(ringGeom, r, segments)

    local ringMat = Material:new()
    ringMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureUnlit.xml"))
    ringMat:SetShaderParameter("MatDiffColor", Variant(Color(0.50, 0.75, 0.95, 0.55)))
    ringGeom:SetMaterial(ringMat)
end

-- ============================================================================
-- 范围圆动态更新（升级后调用）
-- ============================================================================

function M.UpdateRangeCircle()
    if not EnergyTower then
        EnergyTower = require("EnergyTower")
    end

    local segments = 64
    local r = EnergyTower.GetEnergyRange() + 0.5

    if rangeDiscNode_ then
        local discGeom = rangeDiscNode_:GetComponent("CustomGeometry")
        BuildDiscGeometry(discGeom, r, segments)
    end

    if rangeRingNode_ then
        local ringGeom = rangeRingNode_:GetComponent("CustomGeometry")
        BuildRingGeometry(ringGeom, r, segments)
    end

    -- 重建出怪弧段 (半径变了需要重建)
    M.RebuildSpawnArcs()
end

-- ============================================================================
-- 出怪方向弧段 (在范围圈上标红/灰)
-- ============================================================================

local SPAWN_ARC_HALF_ANGLE = math.rad(20)   -- 弧段半角 ±20°
local SPAWN_ARC_THICKNESS  = 0.45           -- 弧段径向宽度(米)
local SPAWN_ARC_SEGMENTS   = 20             -- 弧段细分

--- 重建出怪方向弧段节点 (大波次更新或升级后调用)
--- 由 Wave.lua 调用: 传入大波次3个固定角度
function M.RebuildSpawnArcs(bigWaveAngles)
    if not EnergyTower then
        EnergyTower = require("EnergyTower")
    end
    local r = EnergyTower.GetEnergyRange() + 0.5
    local y = CONFIG.GridY + 0.025  -- 高于范围圈轮廓线

    -- 清除旧弧段
    for _, arc in ipairs(spawnArcNodes_) do
        if arc.node then arc.node:Remove() end
    end
    spawnArcNodes_ = {}

    if not bigWaveAngles or #bigWaveAngles == 0 then return end

    local tech = cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml")

    for i, angle in ipairs(bigWaveAngles) do
        local arcNode = GS.scene:CreateChild("SpawnArc" .. i)
        arcNode.position = Vector3(0, y, 0)
        local geom = arcNode:CreateComponent("CustomGeometry")
        BuildArcBandGeometry(geom, r, angle, SPAWN_ARC_HALF_ANGLE, SPAWN_ARC_THICKNESS, SPAWN_ARC_SEGMENTS)

        local mat = Material:new()
        mat:SetTechnique(0, tech)
        -- 默认灰色 (非活跃)
        mat:SetShaderParameter("MatDiffColor",    Variant(Color(0.55, 0.55, 0.55, 0.30)))
        mat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.1, 0.1, 0.1)))
        mat:SetShaderParameter("Metallic",  Variant(0.0))
        mat:SetShaderParameter("Roughness", Variant(1.0))
        geom:SetMaterial(mat)

        table.insert(spawnArcNodes_, { node = arcNode, mat = mat, angle = angle, isActive = false })
    end
end

--- 更新活跃方向弧段颜色 (每小波开始时调用)
--- activeAngles: 本小波活跃方向角度列表
function M.UpdateSpawnArcActive(activeAngles)
    -- 构建活跃角度集合 (匹配最近的弧段)
    local activeSet = {}
    for _, a in ipairs(activeAngles) do
        for i, arc in ipairs(spawnArcNodes_) do
            local diff = math.abs(arc.angle - a)
            if diff > math.pi then diff = math.pi * 2 - diff end
            if diff < 0.01 then  -- 角度完全匹配 (同一个方向)
                activeSet[i] = true
            end
        end
    end
    for i, arc in ipairs(spawnArcNodes_) do
        arc.isActive = activeSet[i] == true
    end
end

--- 每帧更新弧段动画 (呼吸/闪烁)
function M.UpdateSpawnArcs(dt)
    if #spawnArcNodes_ == 0 then return end
    spawnArcTime_ = spawnArcTime_ + dt

    -- 活跃弧段: 红色呼吸脉冲
    -- 非活跃弧段: 暗灰色静态
    local pulseMul = 0.75 + 0.25 * math.sin(spawnArcTime_ * 2.0 * math.pi)

    for _, arc in ipairs(spawnArcNodes_) do
        if arc.mat then
            if arc.isActive then
                -- 红色, 带呼吸
                local a = 0.45 * pulseMul + 0.25
                arc.mat:SetShaderParameter("MatDiffColor",
                    Variant(Color(1.0, 0.08, 0.05, a)))
                arc.mat:SetShaderParameter("MatEmissiveColor",
                    Variant(Color(0.6 * pulseMul, 0.02, 0.01)))
            else
                -- 暗灰
                arc.mat:SetShaderParameter("MatDiffColor",
                    Variant(Color(0.50, 0.50, 0.50, 0.22)))
                arc.mat:SetShaderParameter("MatEmissiveColor",
                    Variant(Color(0.05, 0.05, 0.05)))
            end
        end
    end
end

-- ============================================================================
-- 悬停指示器
-- ============================================================================

function M.CreateHoverIndicator()
    GS.hoverNode = GS.scene:CreateChild("Hover")
    GS.hoverNode.position = Vector3(0, CONFIG.HoverY, 0)
    GS.hoverNode.scale = Vector3(0.92, 1.0, 0.92)
    local model = GS.hoverNode:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Meshes/TD/selection-a.mdl"))

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(0.2, 0.8, 0.2, 0.45)))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.1, 0.4, 0.1)))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(0.5))
    model:SetMaterial(mat)

    GS.hoverNode.enabled = false
end

-- ============================================================================
-- 放置确认标记（与 hover 相同外观，固定在待确认格子上）
-- ============================================================================

function M.CreatePlacementMarker()
    GS.placementMarker = GS.scene:CreateChild("PlacementMarker")
    GS.placementMarker.position = Vector3(0, CONFIG.HoverY, 0)
    GS.placementMarker.scale = Vector3(0.92, 1.0, 0.92)
    local model = GS.placementMarker:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Meshes/TD/selection-a.mdl"))

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.9, 1.0, 0.55)))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.15, 0.45, 0.5)))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(0.5))
    model:SetMaterial(mat)

    GS.placementMarker.enabled = false
end

-- ============================================================================
-- 相机输入
-- ============================================================================

function M.HandleCameraPan()
    if input:GetMouseButtonDown(MOUSEB_MIDDLE) then
        local dx = input.mouseMoveX
        local dy = input.mouseMoveY
        if dx ~= 0 or dy ~= 0 then
            local worldPerPx = GS.camera.orthoSize / graphics:GetHeight()
            GS.cameraNode:Translate(Vector3(-dx * worldPerPx, dy * worldPerPx, 0))
        end
    end
end

function M.HandleCameraZoom()
    local wheel = input.mouseMoveWheel
    if wheel ~= 0 then
        local newSize = GS.camera.orthoSize - wheel * CONFIG.ZoomSpeed
        GS.camera.orthoSize = math.max(CONFIG.ZoomMin, math.min(CONFIG.ZoomMax, newSize))
    end
end

-- ============================================================================
-- 升级提示箭头（能源塔可升级时浮动显示）
-- ============================================================================

function M.CreateUpgradeHint()
    upgradeHintNode_ = GS.scene:CreateChild("UpgradeHint")
    upgradeHintNode_.position = Vector3(0, 2.2, 0)
    upgradeHintNode_.enabled = false

    -- 用 CustomGeometry 画一个向上的三角箭头
    local geom = upgradeHintNode_:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, TRIANGLE_LIST)

    -- 向上箭头（正面）
    local s = 0.25
    geom:DefineVertex(Vector3(0, s * 1.2, 0))       -- 顶部
    geom:DefineNormal(Vector3.FORWARD)
    geom:DefineVertex(Vector3(-s, 0, 0))             -- 左下
    geom:DefineNormal(Vector3.FORWARD)
    geom:DefineVertex(Vector3(s, 0, 0))              -- 右下
    geom:DefineNormal(Vector3.FORWARD)

    -- 背面（反向三角，确保双面可见）
    geom:DefineVertex(Vector3(0, s * 1.2, 0))
    geom:DefineNormal(Vector3.BACK)
    geom:DefineVertex(Vector3(s, 0, 0))
    geom:DefineNormal(Vector3.BACK)
    geom:DefineVertex(Vector3(-s, 0, 0))
    geom:DefineNormal(Vector3.BACK)

    geom:Commit()

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(Color(0.30, 0.90, 0.40, 0.85)))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.20, 0.60, 0.25)))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(0.4))
    geom:SetMaterial(mat)
end

function M.UpdateUpgradeHint(dt)
    if not upgradeHintNode_ then return end

    if not EnergyTower then
        EnergyTower = require("EnergyTower")
    end

    if EnergyTower.CanUpgrade() then
        upgradeHintNode_.enabled = true
        -- sin 波上下浮动
        local t = time.elapsedTime
        local baseY = 2.2
        local floatY = baseY + math.sin(t * 2.5) * 0.15
        upgradeHintNode_.position = Vector3(0, floatY, 0)
        -- 始终面向相机（billboard）
        if GS.cameraNode then
            upgradeHintNode_.rotation = GS.cameraNode.rotation
        end
    else
        upgradeHintNode_.enabled = false
    end
end

return M
