-- ============================================================================
-- Scene.lua — 场景创建 / 光照 / 地板 / 网格 / 范围圆 / 相机 / 输入
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local MOEBIUS = Cfg.MOEBIUS
local GS = Cfg.GS
local EnergyTower -- lazy require to avoid circular dependency
local Wave -- lazy require

local M = {}

-- 范围圆子节点引用
local rangeDiscNode_ = nil
local rangeRingNode_ = nil

-- 升级提示箭头
local upgradeHintNode_ = nil

-- 路径标记
local pathMarkersParent_ = nil
local spawnMarkerNodes_ = {}

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
    -- 使用 tile.mdl + 原始调色板材质，放大覆盖整个地图
    -- tile.mdl BBox: 1×0.2×1，顶面 Y=0.2
    local scaleXZ = CONFIG.MapHalfW * 2 + 4   -- 覆盖整张地图
    local floor = GS.scene:CreateChild("Floor")
    floor.position = Vector3(0, -0.2, 0)       -- 顶面与 y=0 平齐
    floor.scale = Vector3(scaleXZ, 1, scaleXZ)  -- Y 方向不缩放保持原始厚度
    local floorModel = floor:CreateComponent("StaticModel")
    floorModel:SetModel(cache:GetResource("Model", "Meshes/TD/tile.mdl"))
    floorModel:SetMaterial(cache:GetResource("Material", "Materials/TD/tile_00_colormap.xml"))
    floorModel.castShadows = false

    -- 外围点缀装饰 tile（能源范围外随机放置少量带装饰的 tile）
    local DECO_MODELS = {
        { mdl = "Meshes/TD/tile-rock.mdl",    mat = "Materials/TD/tile-rock_00_colormap.xml" },
        { mdl = "Meshes/TD/tile-tree.mdl",    mat = "Materials/TD/tile-tree_00_colormap.xml" },
        { mdl = "Meshes/TD/tile-crystal.mdl", mat = "Materials/TD/tile-crystal_00_colormap.xml" },
        { mdl = "Meshes/TD/tile-dirt.mdl",    mat = "Materials/TD/tile-dirt_00_colormap.xml" },
    }

    math.randomseed(42)
    local DECO_RANGE = CONFIG.EnergyRange + 14
    local decoParent = GS.scene:CreateChild("FloorDeco")
    for x = -DECO_RANGE, DECO_RANGE do
        for z = -DECO_RANGE, DECO_RANGE do
            local dist = math.sqrt(x * x + z * z)
            if dist > CONFIG.EnergyRange + 2 and math.random() < 0.06 then
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
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(MOEBIUS.GridColor))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.20, 0.16, 0.10)))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(1.0))
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
    discMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    discMat:SetShaderParameter("MatDiffColor", Variant(Color(0.30, 0.55, 0.80, 0.10)))
    discMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.08, 0.18, 0.35)))
    discMat:SetShaderParameter("Metallic", Variant(0.0))
    discMat:SetShaderParameter("Roughness", Variant(1.0))
    discGeom:SetMaterial(discMat)

    -- 层2: 边框线圈（加亮）
    rangeRingNode_ = parent:CreateChild("RangeRing")
    rangeRingNode_.position = Vector3(0, CONFIG.GridY + 0.015, 0)
    local ringGeom = rangeRingNode_:CreateComponent("CustomGeometry")
    BuildRingGeometry(ringGeom, r, segments)

    local ringMat = Material:new()
    ringMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    ringMat:SetShaderParameter("MatDiffColor", Variant(Color(0.50, 0.75, 0.95, 0.55)))
    ringMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.25, 0.50, 0.80)))
    ringMat:SetShaderParameter("Metallic", Variant(0.0))
    ringMat:SetShaderParameter("Roughness", Variant(0.3))
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

-- ============================================================================
-- 敌人路径标记（路径线 + 方向箭头 + 刷新点标记）
-- ============================================================================

function M.CreatePathMarkers()
    if not Wave then
        Wave = require("Wave")
    end

    pathMarkersParent_ = GS.scene:CreateChild("PathMarkers")
    spawnMarkerNodes_ = {}

    local pathY = CONFIG.GridY + 0.008
    local pathColor = Color(0.90, 0.40, 0.20, 0.35)
    local pathEmissive = Color(0.40, 0.18, 0.08)
    local arrowColor = Color(0.95, 0.50, 0.25, 0.55)
    local arrowEmissive = Color(0.50, 0.25, 0.10)
    local spawnColor = Color(0.95, 0.30, 0.20, 0.60)
    local spawnEmissive = Color(0.55, 0.15, 0.08)

    for pathName, waypoints in pairs(Wave.PATHS) do
        if #waypoints < 2 then goto continue end

        -- ---- 路径线 ----
        local lineNode = pathMarkersParent_:CreateChild("PathLine_" .. pathName)
        lineNode.position = Vector3(0, pathY, 0)
        local lineGeom = lineNode:CreateComponent("CustomGeometry")
        lineGeom:BeginGeometry(0, LINE_LIST)
        for i = 1, #waypoints - 1 do
            local wp1 = waypoints[i]
            local wp2 = waypoints[i + 1]
            lineGeom:DefineVertex(Vector3(wp1.x, 0, wp1.z))
            lineGeom:DefineVertex(Vector3(wp2.x, 0, wp2.z))
        end
        lineGeom:Commit()

        local lineMat = Material:new()
        lineMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
        lineMat:SetShaderParameter("MatDiffColor", Variant(pathColor))
        lineMat:SetShaderParameter("MatEmissiveColor", Variant(pathEmissive))
        lineMat:SetShaderParameter("Metallic", Variant(0.0))
        lineMat:SetShaderParameter("Roughness", Variant(1.0))
        lineGeom:SetMaterial(lineMat)

        -- ---- 方向箭头（每段路径中点）----
        for i = 1, #waypoints - 1 do
            local wp1 = waypoints[i]
            local wp2 = waypoints[i + 1]
            local mx = (wp1.x + wp2.x) * 0.5
            local mz = (wp1.z + wp2.z) * 0.5
            local dx = wp2.x - wp1.x
            local dz = wp2.z - wp1.z
            local len = math.sqrt(dx * dx + dz * dz)
            if len < 0.01 then goto next_seg end
            -- 归一化方向
            local nx, nz = dx / len, dz / len
            -- 垂直方向
            local px, pz = -nz, nx

            local arrowNode = pathMarkersParent_:CreateChild("Arrow")
            arrowNode.position = Vector3(0, pathY + 0.005, 0)
            local arrowGeom = arrowNode:CreateComponent("CustomGeometry")
            arrowGeom:BeginGeometry(0, TRIANGLE_LIST)

            local as = 0.4  -- 箭头大小
            -- 箭头尖端朝行进方向
            local tipX = mx + nx * as
            local tipZ = mz + nz * as
            local lx = mx - nx * as * 0.3 + px * as * 0.4
            local lz = mz - nz * as * 0.3 + pz * as * 0.4
            local rx = mx - nx * as * 0.3 - px * as * 0.4
            local rz = mz - nz * as * 0.3 - pz * as * 0.4

            arrowGeom:DefineVertex(Vector3(tipX, 0, tipZ))
            arrowGeom:DefineNormal(Vector3.UP)
            arrowGeom:DefineVertex(Vector3(lx, 0, lz))
            arrowGeom:DefineNormal(Vector3.UP)
            arrowGeom:DefineVertex(Vector3(rx, 0, rz))
            arrowGeom:DefineNormal(Vector3.UP)

            arrowGeom:Commit()

            local arrowMat = Material:new()
            arrowMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
            arrowMat:SetShaderParameter("MatDiffColor", Variant(arrowColor))
            arrowMat:SetShaderParameter("MatEmissiveColor", Variant(arrowEmissive))
            arrowMat:SetShaderParameter("Metallic", Variant(0.0))
            arrowMat:SetShaderParameter("Roughness", Variant(0.8))
            arrowGeom:SetMaterial(arrowMat)

            ::next_seg::
        end

        -- ---- 刷新点标记（第一个路点，旋转菱形）----
        local spawn = waypoints[1]
        local spawnNode = pathMarkersParent_:CreateChild("SpawnMarker_" .. pathName)
        spawnNode.position = Vector3(spawn.x, pathY + 0.15, spawn.z)

        local spawnGeom = spawnNode:CreateComponent("CustomGeometry")
        spawnGeom:BeginGeometry(0, TRIANGLE_LIST)

        -- 菱形（4个三角形，水平面上的方形旋转45度）
        local ds = 0.5
        local top = Vector3(0, ds, 0)
        local bot = Vector3(0, -ds, 0)
        local fwd = Vector3(0, 0, ds)
        local bck = Vector3(0, 0, -ds)
        local lft = Vector3(-ds, 0, 0)
        local rgt = Vector3(ds, 0, 0)

        -- 上半部4面
        spawnGeom:DefineVertex(top); spawnGeom:DefineNormal(Vector3(0, 0.7, 0.7))
        spawnGeom:DefineVertex(fwd); spawnGeom:DefineNormal(Vector3(0, 0.7, 0.7))
        spawnGeom:DefineVertex(rgt); spawnGeom:DefineNormal(Vector3(0, 0.7, 0.7))

        spawnGeom:DefineVertex(top); spawnGeom:DefineNormal(Vector3(0.7, 0.7, 0))
        spawnGeom:DefineVertex(rgt); spawnGeom:DefineNormal(Vector3(0.7, 0.7, 0))
        spawnGeom:DefineVertex(bck); spawnGeom:DefineNormal(Vector3(0.7, 0.7, 0))

        spawnGeom:DefineVertex(top); spawnGeom:DefineNormal(Vector3(0, 0.7, -0.7))
        spawnGeom:DefineVertex(bck); spawnGeom:DefineNormal(Vector3(0, 0.7, -0.7))
        spawnGeom:DefineVertex(lft); spawnGeom:DefineNormal(Vector3(0, 0.7, -0.7))

        spawnGeom:DefineVertex(top); spawnGeom:DefineNormal(Vector3(-0.7, 0.7, 0))
        spawnGeom:DefineVertex(lft); spawnGeom:DefineNormal(Vector3(-0.7, 0.7, 0))
        spawnGeom:DefineVertex(fwd); spawnGeom:DefineNormal(Vector3(-0.7, 0.7, 0))

        -- 下半部4面
        spawnGeom:DefineVertex(bot); spawnGeom:DefineNormal(Vector3(0, -0.7, 0.7))
        spawnGeom:DefineVertex(rgt); spawnGeom:DefineNormal(Vector3(0, -0.7, 0.7))
        spawnGeom:DefineVertex(fwd); spawnGeom:DefineNormal(Vector3(0, -0.7, 0.7))

        spawnGeom:DefineVertex(bot); spawnGeom:DefineNormal(Vector3(0.7, -0.7, 0))
        spawnGeom:DefineVertex(bck); spawnGeom:DefineNormal(Vector3(0.7, -0.7, 0))
        spawnGeom:DefineVertex(rgt); spawnGeom:DefineNormal(Vector3(0.7, -0.7, 0))

        spawnGeom:DefineVertex(bot); spawnGeom:DefineNormal(Vector3(0, -0.7, -0.7))
        spawnGeom:DefineVertex(lft); spawnGeom:DefineNormal(Vector3(0, -0.7, -0.7))
        spawnGeom:DefineVertex(bck); spawnGeom:DefineNormal(Vector3(0, -0.7, -0.7))

        spawnGeom:DefineVertex(bot); spawnGeom:DefineNormal(Vector3(-0.7, -0.7, 0))
        spawnGeom:DefineVertex(fwd); spawnGeom:DefineNormal(Vector3(-0.7, -0.7, 0))
        spawnGeom:DefineVertex(lft); spawnGeom:DefineNormal(Vector3(-0.7, -0.7, 0))

        spawnGeom:Commit()

        local spawnMat = Material:new()
        spawnMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
        spawnMat:SetShaderParameter("MatDiffColor", Variant(spawnColor))
        spawnMat:SetShaderParameter("MatEmissiveColor", Variant(spawnEmissive))
        spawnMat:SetShaderParameter("Metallic", Variant(0.0))
        spawnMat:SetShaderParameter("Roughness", Variant(0.4))
        spawnGeom:SetMaterial(spawnMat)

        table.insert(spawnMarkerNodes_, spawnNode)

        ::continue::
    end
end

function M.UpdatePathMarkers(dt)
    -- 刷新点标记缓慢旋转
    for _, node in ipairs(spawnMarkerNodes_) do
        node:Rotate(Quaternion(45 * dt, Vector3.UP))
    end
end

return M
