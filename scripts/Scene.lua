-- ============================================================================
-- Scene.lua — 场景创建 / 光照 / 地板 / 网格 / 范围圆 / 相机 / 输入
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local MOEBIUS = Cfg.MOEBIUS
local GS = Cfg.GS
local EnergyTower -- lazy require to avoid circular dependency

local M = {}

-- ============================================================================
-- 辅助：递归调暗灯光
-- ============================================================================

local function DimAllLights(node, factor)
    local light = node:GetComponent("Light")
    if light then
        light.brightness = light.brightness * factor
    end
    for i = 0, node:GetNumChildren(false) - 1 do
        DimAllLights(node:GetChild(i), factor)
    end
end

-- ============================================================================
-- 场景
-- ============================================================================

function M.CreateScene()
    GS.scene = Scene()
    GS.scene:CreateComponent("Octree")
    GS.scene:CreateComponent("DebugRenderer")

    -- 光照
    local lgFile = cache:GetResource("XMLFile", "LightGroup/Daytime.xml")
    local lg = GS.scene:CreateChild("LightGroup")
    lg:LoadXML(lgFile:GetRoot())
    DimAllLights(lg, 0.4)

    -- 地面
    M.CreateTileFloor()
end

-- ============================================================================
-- 地板
-- ============================================================================

function M.CreateTileFloor()
    -- 纯色平整地板
    local floor = GS.scene:CreateChild("Floor")
    floor.position = Vector3(0, -0.05, 0)
    floor.scale = Vector3(CONFIG.MapHalfW * 2 + 4, 0.1, CONFIG.MapHalfH * 2 + 4)
    local floorModel = floor:CreateComponent("StaticModel")
    floorModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    local floorMat = Material:new()
    floorMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    floorMat:SetShaderParameter("MatDiffColor", Variant(Color(0.45, 0.72, 0.56, 1)))
    floorMat:SetShaderParameter("Roughness", Variant(1.0))
    floorMat:SetShaderParameter("Metallic", Variant(0.0))
    floorModel:SetMaterial(floorMat)
    floorModel.castShadows = false

    -- 装饰物
    local DECO_RANGE = CONFIG.EnergyRange + 12
    local DECO_MODELS = {
        { mdl = "Meshes/TD/tile-rock.mdl",    mat = "Materials/TD/tile-rock_00_colormap.xml" },
        { mdl = "Meshes/TD/tile-tree.mdl",    mat = "Materials/TD/tile-tree_00_colormap.xml" },
        { mdl = "Meshes/TD/tile-crystal.mdl", mat = "Materials/TD/tile-crystal_00_colormap.xml" },
        { mdl = "Meshes/TD/tile-dirt.mdl",    mat = "Materials/TD/tile-dirt_00_colormap.xml" },
    }

    math.randomseed(42)
    local decoParent = GS.scene:CreateChild("FloorDeco")
    for x = -DECO_RANGE, DECO_RANGE do
        for z = -DECO_RANGE, DECO_RANGE do
            local dist = math.sqrt(x * x + z * z)
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
    renderer.hdrRendering = true
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
-- 供能范围圆
-- ============================================================================

function M.CreateRangeCircle()
    local node = GS.scene:CreateChild("RangeCircle")
    node.position = Vector3(0, CONFIG.GridY + 0.01, 0)
    local geom = node:CreateComponent("CustomGeometry")
    geom:BeginGeometry(0, LINE_LIST)

    local segments = 64
    local r = CONFIG.EnergyRange + 0.5
    for i = 0, segments - 1 do
        local a1 = (i / segments) * math.pi * 2
        local a2 = ((i + 1) / segments) * math.pi * 2
        geom:DefineVertex(Vector3(math.cos(a1) * r, 0, math.sin(a1) * r))
        geom:DefineVertex(Vector3(math.cos(a2) * r, 0, math.sin(a2) * r))
    end
    geom:Commit()

    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(MOEBIUS.RangeColor))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.15, 0.35, 0.6)))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(0.5))
    geom:SetMaterial(mat)

    GS.rangeCircleNode_ = node
end

-- ============================================================================
-- 范围圆动态更新（升级后调用）
-- ============================================================================

function M.UpdateRangeCircle()
    local node = GS.rangeCircleNode_
    if not node then return end

    if not EnergyTower then
        EnergyTower = require("EnergyTower")
    end

    local geom = node:GetComponent("CustomGeometry")
    geom:BeginGeometry(0, LINE_LIST)

    local segments = 64
    local r = EnergyTower.GetEnergyRange() + 0.5
    for i = 0, segments - 1 do
        local a1 = (i / segments) * math.pi * 2
        local a2 = ((i + 1) / segments) * math.pi * 2
        geom:DefineVertex(Vector3(math.cos(a1) * r, 0, math.sin(a1) * r))
        geom:DefineVertex(Vector3(math.cos(a2) * r, 0, math.sin(a2) * r))
    end
    geom:Commit()
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

return M
