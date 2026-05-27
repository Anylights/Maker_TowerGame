-- ============================================================================
-- VFXPreview.lua — 圣器特效预览场景（全部 36 件一页显示）
-- 按 P 键进入，再按 P 键退出
-- ============================================================================

local ArtifactVFX = require("ArtifactVFX")
local UI          = require("urhox-libs/UI")
local Config      = require("Config")

local M = {}

-- ============================================================================
-- 内部状态
-- ============================================================================
local active_      = false
local previewRoot_ = nil

local savedCamPos_    = nil
local savedCamRot_    = nil
local savedCamOrtho_  = nil
local savedOrthoSize_ = nil
local savedFarClip_   = nil

local towerNodes_  = {}
local artifactIds_ = {}
local uiRoot_      = nil

local PREVIEW_Y = -300.0

-- 网格布局：6 列 × 6 行 = 36
local COLS      = 6
local SPACING_X = 3.5
local SPACING_Z = 4.0

-- 相机
local camYaw_   = 15.0
local camPitch_ = 38.0
local camDist_  = 30.0
local camTarget_ = Vector3(0, PREVIEW_Y + 1.5, 0)

-- ============================================================================
-- 圣器显示名称
-- ============================================================================
local DISPLAY_NAMES = {
    rapid_fire_module   = "连射模块",   fire_seed           = "火种",
    ice_crystal         = "冰晶",       corrosion           = "腐蚀",
    thunder             = "雷鸣",       splinter            = "裂片",
    piercing_core       = "穿透弹芯",   sniper_mod          = "狙击改装",
    prism               = "棱镜",       high_explosive      = "高爆",
    crit_device         = "暴击装置",   resonance_trigger   = "共振触发",
    elemental_core      = "元素核心",   aura_attack_speed   = "攻速光环",
    aura_damage         = "伤害光环",   aura_range          = "射程光环",
    aura_crit           = "暴击光环",   range_compression   = "远程压缩",
    power_borrow        = "借力圣器",   master_tower        = "总管塔",
    defense_garrison    = "防御阵地",   network             = "网络圣器",
    devour_line         = "吞噬线",     ice_crystal_conduit = "冰晶导管",
    resonance_amplifier = "共鸣放大器", elemental_reaction  = "元素反应",
    overload_relay      = "过载继电器", energy_ammo         = "注能弹药",
    coin_magnet         = "磁币圣器",   gold_refinery       = "金矿炼化",
    energy_matrix       = "充能矩阵",   charged_hit         = "蓄力击",
    condenser           = "凝聚塔",     resource_enrichment = "资源富集",
    compound_interest   = "复利圣器",   feedback_coil       = "反馈线圈",
}

-- ============================================================================
-- 塔台模型
-- ============================================================================
local function BuildTowerMesh(parentNode)
    local base = parentNode:CreateChild("Base")
    base.position = Vector3(0, 0, 0)
    local bm = base:CreateComponent("StaticModel")
    bm.model = cache:GetResource("Model", "Models/Cylinder.mdl")
    local matBase = Material:new()
    matBase:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    matBase:SetShaderParameter("MatDiffColor",     Variant(Color(0.50, 0.58, 0.68, 1)))
    matBase:SetShaderParameter("MatEmissiveColor", Variant(Color(0.10, 0.14, 0.22)))
    matBase:SetShaderParameter("Metallic",  Variant(0.3))
    matBase:SetShaderParameter("Roughness", Variant(0.6))
    bm.material = matBase
    base.scale = Vector3(0.5, 0.08, 0.5)

    local body = parentNode:CreateChild("Body")
    body.position = Vector3(0, 0.7, 0)
    local bdm = body:CreateComponent("StaticModel")
    bdm.model = cache:GetResource("Model", "Models/Box.mdl")
    local matBody = Material:new()
    matBody:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    matBody:SetShaderParameter("MatDiffColor",     Variant(Color(0.45, 0.52, 0.62, 1)))
    matBody:SetShaderParameter("MatEmissiveColor", Variant(Color(0.08, 0.12, 0.20)))
    matBody:SetShaderParameter("Metallic",  Variant(0.4))
    matBody:SetShaderParameter("Roughness", Variant(0.5))
    bdm.material = matBody
    body.scale = Vector3(0.38, 1.2, 0.38)

    local barrel = parentNode:CreateChild("Barrel")
    barrel.position = Vector3(0, 1.2, 0.15)
    local brm = barrel:CreateComponent("StaticModel")
    brm.model = cache:GetResource("Model", "Models/Cylinder.mdl")
    local matBarrel = Material:new()
    matBarrel:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    matBarrel:SetShaderParameter("MatDiffColor",     Variant(Color(0.35, 0.40, 0.50, 1)))
    matBarrel:SetShaderParameter("MatEmissiveColor", Variant(Color(0.06, 0.09, 0.16)))
    matBarrel:SetShaderParameter("Metallic",  Variant(0.6))
    matBarrel:SetShaderParameter("Roughness", Variant(0.4))
    brm.material = matBarrel
    barrel.scale = Vector3(0.12, 0.4, 0.12)
    barrel.rotation = Quaternion(90, Vector3.RIGHT)
end

local function CreateZone(parentNode)
    local zoneNode = parentNode:CreateChild("PreviewZone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(Vector3(-120, -10, -120), Vector3(120, 20, 120))
    zone.ambientColor = Color(0.3, 0.35, 0.40)
    zone.priority = 10
    zone.fogStart = 300
    zone.fogEnd = 600
end

local function CreateFloor(parentNode)
    local floorNode = parentNode:CreateChild("Floor")
    floorNode.position = Vector3(0, -0.05, 0)
    local floorModel = floorNode:CreateComponent("StaticModel")
    floorModel.model = cache:GetResource("Model", "Models/Box.mdl")
    local matFloor = Material:new()
    matFloor:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    matFloor:SetShaderParameter("MatDiffColor",     Variant(Color(0.18, 0.20, 0.25, 1)))
    matFloor:SetShaderParameter("MatEmissiveColor", Variant(Color(0.02, 0.02, 0.04)))
    matFloor:SetShaderParameter("Metallic",  Variant(0.1))
    matFloor:SetShaderParameter("Roughness", Variant(0.9))
    floorModel.material = matFloor
    floorNode.scale = Vector3(120, 0.1, 120)
end

-- ============================================================================
-- 相机
-- ============================================================================
local function UpdateCamera()
    local GS = Config.GS
    if not GS or not GS.cameraNode then return end
    local q = Quaternion(camPitch_, Vector3.RIGHT) * Quaternion(camYaw_, Vector3.UP)
    GS.cameraNode.position = camTarget_ + q * Vector3(0, 0, -camDist_)
    GS.cameraNode.rotation = q
end

-- ============================================================================
-- 全部塔台一次性生成
-- ============================================================================
local function GetGridPos(idx)
    -- idx 从 0 开始
    local col  = idx % COLS
    local row  = math.floor(idx / COLS)
    local rows = math.ceil(#artifactIds_ / COLS)
    local x    = (col - (COLS - 1) * 0.5) * SPACING_X
    local z    = (row - (rows - 1) * 0.5) * SPACING_Z
    return Vector3(x, 0, z)
end

local function SpawnAllTowers()
    for _, n in ipairs(towerNodes_) do
        if n then n:Remove() end
    end
    towerNodes_ = {}

    for i, artifactId in ipairs(artifactIds_) do
        local towerNode = previewRoot_:CreateChild("Tower_" .. artifactId)
        towerNode.position = GetGridPos(i - 1)   -- GetGridPos 使用 0-based idx
        BuildTowerMesh(towerNode)
        local fakeTower = { node = towerNode, gx = i - 1, gz = 0, vfxNodes = {} }
        ArtifactVFX.OnEquip(fakeTower, artifactId)
        towerNodes_[#towerNodes_ + 1] = towerNode
    end
end

-- ============================================================================
-- UI（只保留标题和退出提示，底部显示全部名称）
-- ============================================================================
local function BuildUI()
    if uiRoot_ then
        UI.SetRoot(nil)
        uiRoot_ = nil
    end

    -- 底部名称格子（6 列，每格对应一个塔）
    local labelCells = {}
    for _, id in ipairs(artifactIds_) do
        local name = DISPLAY_NAMES[id] or id
        labelCells[#labelCells + 1] = UI.Label {
            text      = name,
            fontSize  = 11,
            color     = Color(0.85, 0.85, 0.85, 1),
            width     = string.format("%.4f%%", 100 / COLS),
            textAlign = "center",
            paddingBottom = 2,
        }
    end

    local nameGrid = UI.Panel {
        width          = "100%",
        flexDirection  = "row",
        flexWrap       = "wrap",
        justifyContent = "center",
        paddingLeft = 4, paddingRight = 4,
        children = labelCells,
    }

    local titleBar = UI.Panel {
        width           = "100%",
        height          = 40,
        flexDirection   = "row",
        justifyContent  = "space-between",
        alignItems      = "center",
        paddingLeft = 16, paddingRight = 16,
        backgroundColor = Color(0, 0, 0, 0.60),
        children = {
            UI.Label {
                text     = "特效预览  " .. #artifactIds_ .. " 件圣器",
                fontSize = 16,
                color    = Color(1.0, 0.9, 0.4, 1),
            },
            UI.Label { text = "[ P ] 退出 | 右键拖拽旋转 | 滚轮缩放", fontSize = 13, color = Color(0.7, 0.7, 0.7, 1) },
        },
    }

    local bottomBar = UI.Panel {
        width           = "100%",
        flexDirection   = "column",
        backgroundColor = Color(0, 0, 0, 0.55),
        paddingTop  = 4,
        paddingBottom = 4,
        children = { nameGrid },
    }

    uiRoot_ = UI.Panel {
        width          = "100%",
        height         = "100%",
        flexDirection  = "column",
        justifyContent = "space-between",
        children       = { titleBar, UI.Panel { flex = 1 }, bottomBar },
    }

    UI.SetRoot(uiRoot_)
end

-- ============================================================================
-- 进入 / 退出
-- ============================================================================
function M.Enter()
    if active_ then return end
    active_ = true

    local GS = Config.GS
    if not GS or not GS.scene or not GS.cameraNode then
        print("[VFXPreview] ERROR: GS 未就绪")
        active_ = false
        return
    end

    artifactIds_ = ArtifactVFX.GetAllArtifactIds()

    savedCamPos_    = GS.cameraNode.worldPosition
    savedCamRot_    = GS.cameraNode.worldRotation
    savedCamOrtho_  = GS.camera.orthographic
    savedOrthoSize_ = GS.camera.orthoSize
    savedFarClip_   = GS.camera.farClip

    GS.camera.orthographic = false
    GS.camera.fov          = 45
    GS.camera.farClip      = 1200.0

    pcall(function()
        UI.Init({
            fonts = { { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } } },
            scale = UI.Scale.DEFAULT,
        })
    end)

    previewRoot_ = GS.scene:CreateChild("VFXPreviewRoot")
    previewRoot_.position = Vector3(0, PREVIEW_Y, 0)

    CreateZone(previewRoot_)
    CreateFloor(previewRoot_)

    camYaw_    = 15.0
    camPitch_  = 38.0
    camDist_   = 30.0
    camTarget_ = Vector3(0, PREVIEW_Y + 1.5, 0)
    UpdateCamera()

    SpawnAllTowers()
    BuildUI()

    print("[VFXPreview] 进入，共 " .. #artifactIds_ .. " 件圣器，使用 GS.scene")
end

function M.Exit()
    if not active_ then return end
    active_ = false

    towerNodes_ = {}
    if previewRoot_ then
        previewRoot_:Remove()
        previewRoot_ = nil
    end

    if uiRoot_ then
        UI.SetRoot(nil)
        uiRoot_ = nil
    end

    local GS = Config.GS
    if GS and GS.cameraNode and savedCamPos_ then
        GS.cameraNode.position = savedCamPos_
        GS.cameraNode.rotation = savedCamRot_
        GS.camera.orthographic = savedCamOrtho_
        GS.camera.farClip      = savedFarClip_ or 500.0
        if savedCamOrtho_ then
            GS.camera.orthoSize = savedOrthoSize_
        end
    end

    savedCamPos_    = nil
    savedCamRot_    = nil
    savedCamOrtho_  = nil
    savedOrthoSize_ = nil
    savedFarClip_   = nil

    print("[VFXPreview] 退出")
end

function M.IsActive()
    return active_
end

-- ============================================================================
-- 每帧更新（只有相机控制，无翻页）
-- ============================================================================
function M.Update(dt)
    if not active_ then return end

    if input:GetMouseButtonDown(MOUSEB_RIGHT) then
        camYaw_   = camYaw_   + input.mouseMoveX * 0.4
        camPitch_ = math.max(-80, math.min(80, camPitch_ + input.mouseMoveY * 0.4))
    end

    local wheel = input.mouseMoveWheel
    if wheel ~= 0 then
        camDist_ = math.max(5, math.min(60, camDist_ - wheel * 2.0))
    end

    UpdateCamera()
end

return M
