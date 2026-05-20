-- ============================================================================
-- EnergyTower.lua — 能源塔 / 升级 / 统一图模型布线 / 电路伤害 / 短路 / 脉冲
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS
local ET_LEVELS = Cfg.ET_LEVELS
local ET_UPGRADE_COST = Cfg.ET_UPGRADE_COST
local Utils = require("Utils")

local M = {}

-- 脉冲常量
local PULSES_PER_LINE = 3
local TAIL_COUNT = 4
local TAIL_SPACING = 0.045

-- 线段视觉常量
local LINE_Y = 0.15
local LINE_THICK = 0.10
local LINE_WIDTH = 0.14

-- ============================================================================
-- Edge-Key / Node-Key 工具函数
-- ============================================================================

--- 生成规范化的边键 (保证 a < b 字典序)
local function EdgeKey(x1, z1, x2, z2)
    local a = x1 .. "," .. z1
    local b = x2 .. "," .. z2
    if a > b then a, b = b, a end
    return a .. ">" .. b
end

--- 解析边键 → x1,z1, x2,z2
local function ParseEdgeKey(key)
    local a, b = key:match("^(.-)>(.+)$")
    local x1, z1 = a:match("^(%-?%d+),(%-?%d+)$")
    local x2, z2 = b:match("^(%-?%d+),(%-?%d+)$")
    return tonumber(x1), tonumber(z1), tonumber(x2), tonumber(z2)
end

--- 节点键
local function NodeKey(x, z)
    return x .. "," .. z
end

--- 解析节点键
local function ParseNodeKey(key)
    local x, z = key:match("^(%-?%d+),(%-?%d+)$")
    return tonumber(x), tonumber(z)
end

-- ============================================================================
-- 等级驱动属性读取
-- ============================================================================

function M.GetLevelStats()
    return ET_LEVELS[GS.etLevel] or ET_LEVELS[1]
end

function M.GetTotalPower()
    return M.GetLevelStats().power
end

function M.GetEnergyRange()
    return M.GetLevelStats().radius
end

function M.GetConvEff()
    return M.GetLevelStats().convEff
end

-- ============================================================================
-- 升级
-- ============================================================================

function M.CanUpgrade()
    if GS.etLevel >= 10 then return false end
    local cost = ET_UPGRADE_COST[GS.etLevel + 1]
    if not cost then return false end
    return GS.gold >= cost.gold and GS.material >= cost.material
end

function M.GetUpgradeCost()
    if GS.etLevel >= 10 then return nil end
    return ET_UPGRADE_COST[GS.etLevel + 1]
end

function M.Upgrade()
    if not M.CanUpgrade() then return false end

    local cost = ET_UPGRADE_COST[GS.etLevel + 1]
    GS.gold = GS.gold - cost.gold
    GS.material = GS.material - cost.material
    GS.etLevel = GS.etLevel + 1

    local stats = M.GetLevelStats()

    local hpRatio = GS.etHP / GS.etMaxHP
    GS.etMaxHP = stats.hp
    GS.etHP = math.floor(GS.etMaxHP * hpRatio + 0.5)
    if GS.etHP < 1 then GS.etHP = 1 end

    -- 重新计算功率流
    M.RecalculatePowerFlow()
    M.RebuildAllVisuals()

    print(string.format("[EnergyTower] Upgraded to Lv.%d | Power: %d | HP: %d/%d | Radius: %d",
        GS.etLevel, stats.power, GS.etHP, GS.etMaxHP, stats.radius))

    return true
end

-- ============================================================================
-- 能源塔放置
-- ============================================================================

function M.PlaceEnergyTower()
    local node = GS.scene:CreateChild("EnergyTower")
    node.position = Vector3(0, 0, 0)
    local sc = 1.6
    node.scale = Vector3(sc, sc, sc)

    -- ================================================================
    -- 底座平台（方形底座 → 比圆塔身更宽，打造稳重感）
    -- ================================================================
    local platformChild = node:CreateChild("ETPlatform")
    platformChild.scale = Vector3(1.15, 1.0, 1.15)
    local platformModel = platformChild:CreateComponent("StaticModel")
    platformModel:SetModel(cache:GetResource("Model", "Meshes/TD/tower-square-bottom-a.mdl"))
    platformModel:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-square-bottom-a_00_colormap.xml"))
    platformModel.castShadows = true

    -- ================================================================
    -- 圆形底座（在方形平台上方）
    -- ================================================================
    local baseChild = node:CreateChild("ETBase")
    baseChild.position = Vector3(0, 0.18, 0)
    local baseModel = baseChild:CreateComponent("StaticModel")
    baseModel:SetModel(cache:GetResource("Model", "Meshes/TD/tower-round-base.mdl"))
    baseModel:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-round-base_00_colormap.xml"))
    baseModel.castShadows = true

    -- ================================================================
    -- 塔身：3 层递进缩小，越高越细
    -- ================================================================
    local bodyY = 0.39  -- base top = 0.18 + 0.21

    -- 第 1 层（最宽）
    local bodyChild1 = node:CreateChild("ETBody1")
    bodyChild1.position = Vector3(0, bodyY, 0)
    bodyChild1.scale = Vector3(1.0, 1.0, 1.0)
    local bodyModel1 = bodyChild1:CreateComponent("StaticModel")
    bodyModel1:SetModel(cache:GetResource("Model", "Meshes/TD/tower-round-top-a.mdl"))
    bodyModel1:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-round-top-a_00_colormap.xml"))
    bodyModel1.castShadows = true

    -- 第 2 层（略窄）
    local bodyChild2 = node:CreateChild("ETBody2")
    bodyChild2.position = Vector3(0, bodyY + 0.50, 0)
    bodyChild2.scale = Vector3(0.88, 1.0, 0.88)
    local bodyModel2 = bodyChild2:CreateComponent("StaticModel")
    bodyModel2:SetModel(cache:GetResource("Model", "Meshes/TD/tower-round-top-a.mdl"))
    bodyModel2:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-round-top-a_00_colormap.xml"))
    bodyModel2.castShadows = true

    -- 第 3 层（最窄）
    local bodyChild3 = node:CreateChild("ETBody3")
    bodyChild3.position = Vector3(0, bodyY + 1.00, 0)
    bodyChild3.scale = Vector3(0.75, 0.90, 0.75)
    local bodyModel3 = bodyChild3:CreateComponent("StaticModel")
    bodyModel3:SetModel(cache:GetResource("Model", "Meshes/TD/tower-round-top-a.mdl"))
    bodyModel3:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-round-top-a_00_colormap.xml"))
    bodyModel3.castShadows = true

    -- ================================================================
    -- 旋转能量环（3 个不同高度、速度、倾角的 Torus）
    -- ================================================================
    local ringMat = Material:new()
    ringMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    ringMat:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.85, 1.0, 0.55)))
    ringMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.6, 1.6, 2.2)))
    ringMat:SetShaderParameter("Metallic", Variant(0.8))
    ringMat:SetShaderParameter("Roughness", Variant(0.15))

    GS.etRingNodes = {}

    -- 环 1：底部，最大，水平慢转
    local ring1 = node:CreateChild("ETRing1")
    ring1.position = Vector3(0, bodyY + 0.25, 0)
    ring1.scale = Vector3(0.95, 0.8, 0.95)
    local ring1Model = ring1:CreateComponent("StaticModel")
    ring1Model:SetModel(cache:GetResource("Model", "Models/Torus.mdl"))
    ring1Model:SetMaterial(ringMat)
    GS.etRingNodes[1] = ring1

    -- 环 2：中部，略小，倾斜反转
    local ringMat2 = ringMat:Clone()
    ringMat2:SetShaderParameter("MatDiffColor", Variant(Color(0.5, 0.7, 1.0, 0.45)))
    ringMat2:SetShaderParameter("MatEmissiveColor", Variant(Color(0.9, 1.2, 2.5)))

    local ring2 = node:CreateChild("ETRing2")
    ring2.position = Vector3(0, bodyY + 0.75, 0)
    ring2.scale = Vector3(0.78, 0.7, 0.78)
    ring2.rotation = Quaternion(15, Vector3.FORWARD)  -- 略微倾斜
    local ring2Model = ring2:CreateComponent("StaticModel")
    ring2Model:SetModel(cache:GetResource("Model", "Models/Torus.mdl"))
    ring2Model:SetMaterial(ringMat2)
    GS.etRingNodes[2] = ring2

    -- 环 3：顶部，最小，反向倾斜快转
    local ringMat3 = ringMat:Clone()
    ringMat3:SetShaderParameter("MatDiffColor", Variant(Color(0.7, 0.9, 1.0, 0.5)))
    ringMat3:SetShaderParameter("MatEmissiveColor", Variant(Color(1.5, 1.8, 2.8)))

    local ring3 = node:CreateChild("ETRing3")
    ring3.position = Vector3(0, bodyY + 1.25, 0)
    ring3.scale = Vector3(0.62, 0.6, 0.62)
    ring3.rotation = Quaternion(-12, Vector3.RIGHT)  -- 反向倾斜
    local ring3Model = ring3:CreateComponent("StaticModel")
    ring3Model:SetModel(cache:GetResource("Model", "Models/Torus.mdl"))
    ring3Model:SetMaterial(ringMat3)
    GS.etRingNodes[3] = ring3

    -- ================================================================
    -- 顶部水晶冠（会旋转）
    -- ================================================================
    local crystalChild = node:CreateChild("ETCrystals")
    crystalChild.position = Vector3(0, bodyY + 1.45, 0)
    crystalChild.scale = Vector3(0.85, 0.85, 0.85)
    local crystalModel = crystalChild:CreateComponent("StaticModel")
    crystalModel:SetModel(cache:GetResource("Model", "Meshes/TD/tower-round-crystals.mdl"))
    crystalModel:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-round-crystals_00_colormap.xml"))
    crystalModel.castShadows = true
    GS.etCrystalNode = crystalChild  -- 保存引用，用于旋转动画

    -- ================================================================
    -- 四角装饰水晶（底座四角各一簇小水晶）
    -- ================================================================
    local cornerOffsets = {
        Vector3( 0.55, 0.18,  0.55),
        Vector3(-0.55, 0.18,  0.55),
        Vector3( 0.55, 0.18, -0.55),
        Vector3(-0.55, 0.18, -0.55),
    }
    local cornerYaws = { 45, 135, -45, -135 }
    for ci = 1, 4 do
        local cNode = node:CreateChild("ETCornerCrystal" .. ci)
        cNode.position = cornerOffsets[ci]
        cNode.scale = Vector3(0.6, 0.7, 0.6)
        cNode.rotation = Quaternion(cornerYaws[ci], Vector3.UP)
        local cModel = cNode:CreateComponent("StaticModel")
        cModel:SetModel(cache:GetResource("Model", "Meshes/TD/detail-crystal.mdl"))
        cModel:SetMaterial(cache:GetResource("Material", "Materials/TD/detail-crystal_00_colormap.xml"))
        cModel.castShadows = true
    end

    -- ================================================================
    -- 底座水晶圆环（tile-crystal 围绕底座）
    -- ================================================================
    local ringAngles = { 0, 90, 180, 270 }
    local ringDist = 0.65
    for ri = 1, 4 do
        local rad = math.rad(ringAngles[ri])
        local rx = math.sin(rad) * ringDist
        local rz = math.cos(rad) * ringDist
        local rNode = node:CreateChild("ETRingCrystal" .. ri)
        rNode.position = Vector3(rx, 0.0, rz)
        rNode.scale = Vector3(0.35, 0.45, 0.35)
        rNode.rotation = Quaternion(ringAngles[ri] + 45, Vector3.UP)
        local rModel = rNode:CreateComponent("StaticModel")
        rModel:SetModel(cache:GetResource("Model", "Meshes/TD/tile-crystal.mdl"))
        rModel:SetMaterial(cache:GetResource("Material", "Materials/TD/tile-crystal_00_colormap.xml"))
        rModel.castShadows = true
    end

    -- ================================================================
    -- 上升能量粒子（围绕塔身螺旋上升）
    -- ================================================================
    local particleNode = GS.scene:CreateChild("ETParticles")
    particleNode.position = Vector3(0, 0.5, 0)

    local emitter = particleNode:CreateComponent("ParticleEmitter")
    local effect = ParticleEffect()
    effect:SetEmitterType(EMITTER_SPHERE)
    effect:SetEmitterSize(Vector3(1.8, 0.1, 1.8))
    effect:SetNumParticles(100)
    effect:SetMinEmissionRate(40)
    effect:SetMaxEmissionRate(60)
    effect:SetMinTimeToLive(0.6)
    effect:SetMaxTimeToLive(1.2)
    effect:SetMinParticleSize(Vector2(0.02, 0.02))
    effect:SetMaxParticleSize(Vector2(0.055, 0.055))
    effect:SetMinDirection(Vector3(-0.3, 1.5, -0.3))
    effect:SetMaxDirection(Vector3(0.3, 2.5, 0.3))
    effect:SetMinVelocity(1.0)
    effect:SetMaxVelocity(2.0)
    effect:SetDampingForce(1.2)
    effect:SetMinRotationSpeed(120)
    effect:SetMaxRotationSpeed(300)
    effect:AddColorTime(Color(0.4, 0.8, 1.0, 0.0), 0.0)
    effect:AddColorTime(Color(0.6, 0.9, 1.0, 0.9), 0.15)
    effect:AddColorTime(Color(1.0, 0.85, 0.35, 0.7), 0.5)
    effect:AddColorTime(Color(1.0, 0.6, 0.1, 0.0), 1.0)

    local pMat = Material:new()
    pMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    pMat:SetShaderParameter("MatDiffColor", Variant(Color(0.8, 0.9, 1.0, 1.0)))
    pMat:SetShaderParameter("MatEmissiveColor", Variant(Color(1.5, 1.8, 2.5)))
    pMat:SetShaderParameter("Metallic", Variant(0.0))
    pMat:SetShaderParameter("Roughness", Variant(1.0))
    effect:SetMaterial(pMat)
    emitter:SetEffect(effect)
    emitter:SetEmitting(true)

    -- ================================================================
    -- 顶部光柱粒子（从水晶向上发射的聚焦光柱）
    -- ================================================================
    local beamNode = GS.scene:CreateChild("ETBeamParticles")
    beamNode.position = Vector3(0, 3.5, 0)

    local beamEmitter = beamNode:CreateComponent("ParticleEmitter")
    local beamEffect = ParticleEffect()
    beamEffect:SetEmitterType(EMITTER_SPHERE)
    beamEffect:SetEmitterSize(Vector3(0.25, 0.05, 0.25))
    beamEffect:SetNumParticles(30)
    beamEffect:SetMinEmissionRate(15)
    beamEffect:SetMaxEmissionRate(25)
    beamEffect:SetMinTimeToLive(0.3)
    beamEffect:SetMaxTimeToLive(0.7)
    beamEffect:SetMinParticleSize(Vector2(0.03, 0.03))
    beamEffect:SetMaxParticleSize(Vector2(0.08, 0.08))
    beamEffect:SetMinDirection(Vector3(-0.05, 1.0, -0.05))
    beamEffect:SetMaxDirection(Vector3(0.05, 1.0, 0.05))
    beamEffect:SetMinVelocity(1.5)
    beamEffect:SetMaxVelocity(3.0)
    beamEffect:SetDampingForce(0.8)
    beamEffect:AddColorTime(Color(1.0, 0.9, 0.4, 0.0), 0.0)
    beamEffect:AddColorTime(Color(1.0, 0.85, 0.3, 1.0), 0.15)
    beamEffect:AddColorTime(Color(1.0, 0.7, 0.2, 0.3), 0.6)
    beamEffect:AddColorTime(Color(0.8, 0.5, 0.1, 0.0), 1.0)

    local beamMat = Material:new()
    beamMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    beamMat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.9, 0.5, 1.0)))
    beamMat:SetShaderParameter("MatEmissiveColor", Variant(Color(2.5, 2.0, 0.6)))
    beamMat:SetShaderParameter("Metallic", Variant(0.0))
    beamMat:SetShaderParameter("Roughness", Variant(1.0))
    beamEffect:SetMaterial(beamMat)
    beamEmitter:SetEffect(beamEffect)
    beamEmitter:SetEmitting(true)

    -- 血量 (等级驱动)
    local stats = M.GetLevelStats()
    GS.etHP = stats.hp
    GS.etMaxHP = stats.hp

    -- 血条
    GS.etHPBg = GS.scene:CreateChild("EnergyTowerHPBar")
    GS.etHPBg.position = Vector3(0, 4.6, 0)

    local bg = GS.etHPBg:CreateChild("ETHPBg")
    bg.scale = Vector3(CONFIG.EnergyTowerHPBarW, CONFIG.EnergyTowerHPBarH, 0.01)
    local bgModel = bg:CreateComponent("StaticModel")
    bgModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bgModel:SetMaterial(Utils.GetHPBgMaterial())

    GS.etHPFill = GS.etHPBg:CreateChild("ETHPFill")
    GS.etHPFill.scale = Vector3(CONFIG.EnergyTowerHPBarW, CONFIG.EnergyTowerHPBarH * 0.75, 0.015)
    GS.etHPFill.position = Vector3(0, 0, 0.005)
    local fillModel = GS.etHPFill:CreateComponent("StaticModel")
    fillModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    GS.etFillMat = Material:new()
    GS.etFillMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    GS.etFillMat:SetShaderParameter("MatDiffColor", Variant(Color(0.1, 0.9, 0.1, 1.0)))
    GS.etFillMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.05, 0.4, 0.05)))
    GS.etFillMat:SetShaderParameter("Metallic", Variant(0.0))
    GS.etFillMat:SetShaderParameter("Roughness", Variant(0.5))
    fillModel:SetMaterial(GS.etFillMat)
end

-- ============================================================================
-- 能源塔血条更新
-- ============================================================================

function M.UpdateEnergyTowerHP()
    if not GS.etHPBg then return end
    GS.etHPBg.rotation = GS.cameraNode.rotation

    local ratio = math.max(0, GS.etHP / GS.etMaxHP)
    local fullW = CONFIG.EnergyTowerHPBarW
    local fillW = fullW * ratio
    GS.etHPFill.scale = Vector3(fillW, CONFIG.EnergyTowerHPBarH * 0.75, 0.015)
    local offset = (fullW - fillW) * 0.5
    GS.etHPFill.position = Vector3(-offset, 0, 0.005)

    local r, g
    if ratio > 0.5 then
        r = (1.0 - ratio) * 2.0
        g = 0.9
    else
        r = 0.9
        g = ratio * 2.0
    end
    GS.etFillMat:SetShaderParameter("MatDiffColor", Variant(Color(r, g, 0.1, 1.0)))
    GS.etFillMat:SetShaderParameter("MatEmissiveColor", Variant(Color(r * 0.3, g * 0.3, 0.02)))
end

-- ============================================================================
-- 水晶 & 能量环旋转动画
-- ============================================================================
local etCrystalYaw_ = 0
local etRingYaws_ = { 0, 0, 0 }
-- 环旋转速度（度/秒）：底环慢、中环中速反转、顶环快
local RING_SPEEDS = { 25, -40, 55 }
-- 环的基础倾斜（初始旋转保持）
local RING_TILTS = {
    Quaternion(0, 0, 0),                 -- 环1 水平
    Quaternion(15, Vector3.FORWARD),      -- 环2 前倾15°
    Quaternion(-12, Vector3.RIGHT),       -- 环3 右倾-12°
}

function M.UpdateEnergyTowerAnim(dt)
    -- 水晶旋转
    if GS.etCrystalNode then
        etCrystalYaw_ = etCrystalYaw_ + dt * 30
        if etCrystalYaw_ >= 360 then etCrystalYaw_ = etCrystalYaw_ - 360 end
        GS.etCrystalNode.rotation = Quaternion(etCrystalYaw_, Vector3.UP)
    end

    -- 能量环旋转
    if GS.etRingNodes then
        for i = 1, 3 do
            local ring = GS.etRingNodes[i]
            if ring then
                etRingYaws_[i] = etRingYaws_[i] + dt * RING_SPEEDS[i]
                if etRingYaws_[i] >= 360 then etRingYaws_[i] = etRingYaws_[i] - 360 end
                if etRingYaws_[i] <= -360 then etRingYaws_[i] = etRingYaws_[i] + 360 end
                -- 先倾斜再绕 Y 轴自转
                ring.rotation = RING_TILTS[i] * Quaternion(etRingYaws_[i], Vector3.UP)
            end
        end
    end
end

function M.DamageEnergyTower(dmg)
    if GS.gameOver then return end
    GS.etHP = GS.etHP - dmg
    Utils.SpawnDmgText(Vector3(0, 3.0, 0), dmg)
    if GS.etHP <= 0 then
        GS.etHP = 0
        GS.gameOver = true
    end
end

-- ============================================================================
-- 图操作: AddEdge / RemoveEdge
-- ============================================================================

--- 确保节点存在于图中
local function EnsureNode(gx, gz)
    local key = NodeKey(gx, gz)
    local graph = GS.energyGraph
    if not graph.nodes[key] then
        graph.nodes[key] = { x = gx, z = gz, edges = {} }
    end
    return key
end

--- 添加一条边到图中
--- @return boolean 是否成功添加 (false = 边已存在)
function M.AddEdge(x1, z1, x2, z2)
    local graph = GS.energyGraph
    local eKey = EdgeKey(x1, z1, x2, z2)

    -- 已存在则跳过
    if graph.edges[eKey] then
        return false
    end

    -- 创建边
    local dx = math.abs(x2 - x1)
    graph.edges[eKey] = { x1 = x1, z1 = z1, x2 = x2, z2 = z2, isHoriz = (dx > 0) }
    graph.edgeCount = graph.edgeCount + 1

    -- 确保两端节点存在并添加边引用
    local nk1 = EnsureNode(x1, z1)
    local nk2 = EnsureNode(x2, z2)
    table.insert(graph.nodes[nk1].edges, eKey)
    table.insert(graph.nodes[nk2].edges, eKey)

    return true
end

--- 删除一条边
--- @return boolean 是否成功删除
function M.RemoveEdge(x1, z1, x2, z2)
    local graph = GS.energyGraph
    local eKey = EdgeKey(x1, z1, x2, z2)

    if not graph.edges[eKey] then
        return false
    end

    graph.edges[eKey] = nil
    graph.edgeCount = graph.edgeCount - 1

    -- 从节点的边列表中移除
    local nk1 = NodeKey(x1, z1)
    local nk2 = NodeKey(x2, z2)

    local function removeFromList(nk)
        local node = graph.nodes[nk]
        if not node then return end
        for i = #node.edges, 1, -1 do
            if node.edges[i] == eKey then
                table.remove(node.edges, i)
                break
            end
        end
        -- 如果节点没有边了，删除节点
        if #node.edges == 0 then
            graph.nodes[nk] = nil
        end
    end

    removeFromList(nk1)
    removeFromList(nk2)

    return true
end

-- ============================================================================
-- Union-Find 环路检测
-- ============================================================================

local function UFFind(parent, x)
    if parent[x] ~= x then
        parent[x] = UFFind(parent, parent[x])  -- 路径压缩
    end
    return parent[x]
end

local function UFUnion(parent, rank, a, b)
    local ra = UFFind(parent, a)
    local rb = UFFind(parent, b)
    if ra == rb then return false end  -- 同一集合，合并会形成环

    -- 按秩合并
    if (rank[ra] or 0) < (rank[rb] or 0) then
        parent[ra] = rb
    elseif (rank[ra] or 0) > (rank[rb] or 0) then
        parent[rb] = ra
    else
        parent[rb] = ra
        rank[ra] = (rank[ra] or 0) + 1
    end
    return true
end

--- 检测整个图是否有环路
--- @return boolean hasCycle
function M.DetectCycles()
    local graph = GS.energyGraph
    local parent = {}
    local rank = {}

    -- 初始化每个节点为自己的父节点
    for nk, _ in pairs(graph.nodes) do
        parent[nk] = nk
        rank[nk] = 0
    end

    -- 逐边合并
    for eKey, edge in pairs(graph.edges) do
        local nk1 = NodeKey(edge.x1, edge.z1)
        local nk2 = NodeKey(edge.x2, edge.z2)
        if not UFUnion(parent, rank, nk1, nk2) then
            -- 合并失败 = 环路
            return true
        end
    end

    return false
end

-- ============================================================================
-- BFS 生成树 + 功率传播
-- ============================================================================

--- 从源节点 (0,0) BFS 构建生成树
function M.BuildSpanningTree()
    local graph = GS.energyGraph
    local net = GS.energyNetwork

    -- 清空旧树
    net.spanTree = {}
    net.edgePower = {}
    net.nodePower = {}

    local sourceKey = NodeKey(0, 0)
    if not graph.nodes[sourceKey] then
        return  -- 源节点不在图中 (没有任何线)
    end

    -- BFS
    local visited = {}
    local queue = { sourceKey }
    visited[sourceKey] = true
    net.spanTree[sourceKey] = { parentKey = nil, childKeys = {} }

    local head = 1
    while head <= #queue do
        local curKey = queue[head]
        head = head + 1

        local curNode = graph.nodes[curKey]
        if curNode then
            for _, eKey in ipairs(curNode.edges) do
                local edge = graph.edges[eKey]
                if edge then
                    -- 找到邻居节点
                    local nk1 = NodeKey(edge.x1, edge.z1)
                    local nk2 = NodeKey(edge.x2, edge.z2)
                    local neighborKey = (nk1 == curKey) and nk2 or nk1

                    if not visited[neighborKey] then
                        visited[neighborKey] = true
                        net.spanTree[neighborKey] = { parentKey = curKey, childKeys = {} }
                        table.insert(net.spanTree[curKey].childKeys, neighborKey)
                        table.insert(queue, neighborKey)
                    end
                end
            end
        end
    end
end

--- 从生成树根自上而下传播功率
function M.PropagatePower()
    local net = GS.energyNetwork
    local graph = GS.energyGraph

    local sourceKey = NodeKey(0, 0)
    if not net.spanTree[sourceKey] then
        -- 无生成树，所有塔断电
        for _, t in ipairs(GS.towers) do
            t.activated = false
            t.delivered = 0
            t.linePwr = 0
            t.ratio = 0
        end
        return
    end

    -- Boss 功率吸取
    local drainMult = 1.0
    for _, m in ipairs(GS.monsters) do
        if m.drainActive and m.drainRatio > 0 then
            drainMult = drainMult - m.drainRatio
        end
    end
    drainMult = math.max(0.1, drainMult)

    local totalPower = M.GetTotalPower() * drainMult

    -- 如果短路，功率归零（但仍计算树结构以渲染）
    if GS.shortCircuit.active then
        totalPower = 0
    end

    -- 自上而下 BFS 传播
    net.nodePower[sourceKey] = totalPower

    local queue = { sourceKey }
    local head = 1
    while head <= #queue do
        local curKey = queue[head]
        head = head + 1

        local treeNode = net.spanTree[curKey]
        if treeNode then
            local curPower = net.nodePower[curKey] or 0
            local numChildren = #treeNode.childKeys

            if numChildren > 0 then
                -- 功率均分给子节点
                local childPower = curPower / numChildren

                for _, childKey in ipairs(treeNode.childKeys) do
                    net.nodePower[childKey] = childPower

                    -- 记录边上的功率
                    local cx, cz = ParseNodeKey(curKey)
                    local chx, chz = ParseNodeKey(childKey)
                    local eKey = EdgeKey(cx, cz, chx, chz)
                    net.edgePower[eKey] = childPower

                    table.insert(queue, childKey)
                end
            end
        end
    end

    -- 更新塔的激活状态和功率
    for _, t in ipairs(GS.towers) do
        local tKey = NodeKey(t.gx, t.gz)
        local pwr = net.nodePower[tKey]
        if pwr and pwr > 0 then
            t.activated = true
            t.delivered = pwr
            t.linePwr = pwr
            t.ratio = pwr / M.GetTotalPower()
        else
            t.activated = false
            t.delivered = 0
            t.linePwr = 0
            t.ratio = 0
        end
    end
end

-- ============================================================================
-- 统一功率重算入口
-- ============================================================================

function M.RecalculatePowerFlow()
    -- 1. 检测环路
    local hasCycle = M.DetectCycles()
    GS.energyNetwork.hasCycle = hasCycle
    GS.shortCircuit.active = hasCycle

    -- 2. 构建生成树
    M.BuildSpanningTree()

    -- 3. 传播功率
    M.PropagatePower()
end

--- 兼容旧接口
function M.RecalculateConnectivity()
    M.RecalculatePowerFlow()
end

function M.RecalculateEnergy()
    M.RecalculatePowerFlow()
end

-- ============================================================================
-- 边的添加/删除 (含金币消耗/返还)
-- ============================================================================

--- 查找某个格子上是否有塔 (不含能源塔 0,0)
local function FindTowerAt(gx, gz)
    for _, tower in ipairs(GS.towers) do
        if tower.gx == gx and tower.gz == gz then
            return tower
        end
    end
    return nil
end

--- 查找指向某座塔的线路 ID (兼容旧接口，新系统不再需要)
function M.FindLineToTower(gx, gz)
    return nil  -- 新系统中不再有独立线路概念
end

--- 删除经过指定格子的所有边 (用于 右键删除)
--- @return number 删除的边数
function M.RemoveEdgesAtCell(gx, gz)
    local graph = GS.energyGraph
    local nk = NodeKey(gx, gz)
    local node = graph.nodes[nk]
    if not node then return 0 end

    -- 收集要删除的边
    local toRemove = {}
    for _, eKey in ipairs(node.edges) do
        table.insert(toRemove, eKey)
    end

    local removedCount = 0
    for _, eKey in ipairs(toRemove) do
        local edge = graph.edges[eKey]
        if edge then
            M.RemoveEdge(edge.x1, edge.z1, edge.x2, edge.z2)
            removedCount = removedCount + 1
        end
    end

    return removedCount
end

--- 删除特定的一条边 (右键精确删除)
--- @return boolean
function M.RemoveEdgeAtSegment(gx, gz, nx, nz)
    local eKey = EdgeKey(gx, gz, nx, nz)
    if not GS.energyGraph.edges[eKey] then
        return false
    end
    M.RemoveEdge(gx, gz, nx, nz)
    return true
end

--- 旧接口兼容: RemoveLine
function M.RemoveLine(lineId, refund)
    -- 新系统中不再有独立线路，此函数为空操作
end

-- ============================================================================
-- 布线输入处理 (自由画线模式)
-- ============================================================================

--- 鼠标位置 → 网格坐标
local function MouseToGrid()
    local pos = input.mousePosition
    local sx = pos.x / graphics:GetWidth()
    local sy = pos.y / graphics:GetHeight()
    local ray = GS.camera:GetScreenRay(sx, sy)
    if math.abs(ray.direction.y) < 0.001 then return nil, nil end
    local t = -ray.origin.y / ray.direction.y
    if t <= 0 then return nil, nil end
    local hit = ray.origin + ray.direction * t
    return math.floor(hit.x + 0.5), math.floor(hit.z + 0.5)
end

--- 清除预览线段
local function ClearPreview()
    for _, n in ipairs(GS.wiringPreviewNodes) do
        if n then n:Remove() end
    end
    GS.wiringPreviewNodes = {}
end

-- 拖拽画线状态 (模块局部)
local wiringPath_ = nil      -- 拖拽期间累计的路径 cell 列表 {{gx,gz}, ...}
local wiringLastCell_ = nil   -- 上一帧鼠标所在的格子 {gx, gz}
local wiringEdgeSet_ = nil    -- 拖拽期间累计的边 key → true (去重用)

--- 将 (fromX,fromZ) 到 (toX,toZ) 之间跳过的格子填充进 wiringPath_
local function FillGapCells(fromX, fromZ, toX, toZ)
    local cx, cz = fromX, fromZ

    while cx ~= toX or cz ~= toZ do
        local dx = toX - cx
        local dz = toZ - cz
        local adx = math.abs(dx)
        local adz = math.abs(dz)

        if adx >= adz then
            cx = cx + (dx > 0 and 1 or -1)
        else
            cz = cz + (dz > 0 and 1 or -1)
        end

        table.insert(wiringPath_, {cx, cz})

        local prevIdx = #wiringPath_ - 1
        local prev = wiringPath_[prevIdx]
        local key = EdgeKey(prev[1], prev[2], cx, cz)
        wiringEdgeSet_[key] = true
    end
end

--- 预览材质 (缓存)
local previewMatNew_ = nil
local previewMatExist_ = nil
local previewMatInvalid_ = nil

local function EnsurePreviewMats()
    if previewMatNew_ then return end

    previewMatNew_ = Material:new()
    previewMatNew_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    previewMatNew_:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.9, 0.4, 0.5)))
    previewMatNew_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.2, 0.6, 0.3)))
    previewMatNew_:SetShaderParameter("Metallic", Variant(0.0))
    previewMatNew_:SetShaderParameter("Roughness", Variant(1.0))

    previewMatExist_ = Material:new()
    previewMatExist_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    previewMatExist_:SetShaderParameter("MatDiffColor", Variant(Color(0.6, 0.6, 0.3, 0.35)))
    previewMatExist_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.3, 0.3, 0.1)))
    previewMatExist_:SetShaderParameter("Metallic", Variant(0.0))
    previewMatExist_:SetShaderParameter("Roughness", Variant(1.0))

    previewMatInvalid_ = Material:new()
    previewMatInvalid_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    previewMatInvalid_:SetShaderParameter("MatDiffColor", Variant(Color(0.9, 0.3, 0.3, 0.5)))
    previewMatInvalid_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.5, 0.1, 0.1)))
    previewMatInvalid_:SetShaderParameter("Metallic", Variant(0.0))
    previewMatInvalid_:SetShaderParameter("Roughness", Variant(1.0))
end

--- 检查添加这些边后是否会形成环路 (预检)
local function WouldCauseCycle(newEdges)
    local graph = GS.energyGraph
    local parent = {}
    local rank = {}

    -- 初始化所有现有节点
    for nk, _ in pairs(graph.nodes) do
        parent[nk] = nk
        rank[nk] = 0
    end

    -- 也初始化新边涉及的节点
    for key, _ in pairs(newEdges) do
        local x1, z1, x2, z2 = ParseEdgeKey(key)
        local nk1 = NodeKey(x1, z1)
        local nk2 = NodeKey(x2, z2)
        if not parent[nk1] then parent[nk1] = nk1; rank[nk1] = 0 end
        if not parent[nk2] then parent[nk2] = nk2; rank[nk2] = 0 end
    end

    -- 合并现有的边
    for eKey, edge in pairs(graph.edges) do
        local nk1 = NodeKey(edge.x1, edge.z1)
        local nk2 = NodeKey(edge.x2, edge.z2)
        UFUnion(parent, rank, nk1, nk2)
    end

    -- 尝试合并新边
    for key, _ in pairs(newEdges) do
        if graph.edges[key] then
            goto continue_edge  -- 已存在的边不算新添加
        end
        local x1, z1, x2, z2 = ParseEdgeKey(key)
        local nk1 = NodeKey(x1, z1)
        local nk2 = NodeKey(x2, z2)
        if not UFUnion(parent, rank, nk1, nk2) then
            return true  -- 会形成环路
        end
        ::continue_edge::
    end

    return false
end

--- 从路径 edge set 生成预览线段
local function RebuildPreviewFromEdges()
    ClearPreview()
    if not wiringEdgeSet_ then return end

    EnsurePreviewMats()
    local boxMdl = cache:GetResource("Model", "Models/Box.mdl")

    -- 计算新边数量（不含已存在的）
    local newCount = 0
    for key, _ in pairs(wiringEdgeSet_) do
        if not GS.energyGraph.edges[key] then
            newCount = newCount + 1
        end
    end

    -- 检查是否会形成环路
    local wouldCycle = WouldCauseCycle(wiringEdgeSet_)

    for key, _ in pairs(wiringEdgeSet_) do
        local x1, z1, x2, z2 = ParseEdgeKey(key)
        local midX = (x1 + x2) * 0.5
        local midZ = (z1 + z2) * 0.5
        local lenX = math.abs(x2 - x1)
        local alreadyExists = GS.energyGraph.edges[key] ~= nil

        local n = GS.scene:CreateChild("WiringPreview")
        n.position = Vector3(midX, LINE_Y + 0.02, midZ)

        if lenX > 0 then
            n.scale = Vector3(1.0, LINE_THICK, LINE_WIDTH)
        else
            n.scale = Vector3(LINE_WIDTH, LINE_THICK, 1.0)
        end

        local model = n:CreateComponent("StaticModel")
        model:SetModel(boxMdl)

        if alreadyExists then
            model:SetMaterial(previewMatExist_)
        elseif wouldCycle then
            model:SetMaterial(previewMatInvalid_)  -- 红色: 会形成环路
        else
            model:SetMaterial(previewMatNew_)  -- 绿色: 可以放置
        end
        model.castShadows = false

        table.insert(GS.wiringPreviewNodes, n)
    end
end

--- 设置布线提示信息 (显示数秒)
local function SetWiringHint(msg)
    GS.wiringHintMsg = msg
    GS.wiringHintTimer = 2.5
    print("[Wiring] " .. msg)
end

--- 布线模式下的输入处理 (每帧调用)
function M.HandleWiringInput()
    local GameUI = require("GameUI")
    local gx, gz = MouseToGrid()

    -- 提示倒计时
    if GS.wiringHintTimer > 0 then
        GS.wiringHintTimer = GS.wiringHintTimer - time.timeStep
        if GS.wiringHintTimer <= 0 then
            GS.wiringHintMsg = nil
        end
    end

    -- 右键删除: 删经过此格的所有边
    if input:GetMouseButtonPress(MOUSEB_RIGHT) then
        if gx and gz then
            local dirs = { {0, 1}, {0, -1}, {1, 0}, {-1, 0} }
            local removed = 0
            for _, d in ipairs(dirs) do
                local nx, nz = gx + d[1], gz + d[2]
                local eKey = EdgeKey(gx, gz, nx, nz)
                if GS.energyGraph.edges[eKey] then
                    M.RemoveEdge(gx, gz, nx, nz)
                    removed = removed + 1
                end
            end
            if removed > 0 then
                -- 返还金币
                local refundGold = math.floor(removed * CONFIG.LineCostPerSegment * CONFIG.LineRefundRatio + 0.5)
                GS.gold = GS.gold + refundGold
                print(string.format("[Wiring] Removed %d edges at (%d,%d) → refund %d gold",
                    removed, gx, gz, refundGold))
                M.RecalculatePowerFlow()
                M.RebuildAllVisuals()
                local Tower = require("Tower")
                Tower.UpdateAllActivationVisuals()
            end
        end
        return
    end

    -- 左键按下: 开始自由画线
    if input:GetMouseButtonPress(MOUSEB_LEFT) then
        if GameUI.IsMouseOverUIPanel() then return end
        if gx and gz then
            GS.wiringStart = {gx, gz}
            wiringPath_ = { {gx, gz} }
            wiringLastCell_ = {gx, gz}
            wiringEdgeSet_ = {}
        end
        return
    end

    -- 左键拖拽中: 追踪鼠标所在格子, 逐格延伸路径
    if input:GetMouseButtonDown(MOUSEB_LEFT) and GS.wiringStart and wiringLastCell_ then
        if gx and gz then
            local lx, lz = wiringLastCell_[1], wiringLastCell_[2]
            if gx ~= lx or gz ~= lz then
                local dx = math.abs(gx - lx)
                local dz = math.abs(gz - lz)

                if dx + dz == 1 then
                    table.insert(wiringPath_, {gx, gz})
                    local key = EdgeKey(lx, lz, gx, gz)
                    wiringEdgeSet_[key] = true
                    wiringLastCell_ = {gx, gz}
                else
                    FillGapCells(lx, lz, gx, gz)
                    wiringLastCell_ = {gx, gz}
                end

                RebuildPreviewFromEdges()
            end
        end
        return
    end

    -- 左键释放: 放置边
    if GS.wiringStart and not input:GetMouseButtonDown(MOUSEB_LEFT) then
        ClearPreview()

        if wiringEdgeSet_ then
            -- 过滤掉已存在的边
            local newEdges = {}
            local newCount = 0
            for key, _ in pairs(wiringEdgeSet_) do
                if not GS.energyGraph.edges[key] then
                    newEdges[key] = true
                    newCount = newCount + 1
                end
            end

            if newCount == 0 then
                -- 没有新边需要添加
            else
                -- 检查金币
                local totalCost = newCount * CONFIG.LineCostPerSegment
                if GS.gold < totalCost then
                    SetWiringHint(string.format("Not enough gold! Need %d, have %d", totalCost, GS.gold))
                else
                    -- 预检环路: 如果会形成环路仍然允许放置，但显示警告
                    local willCycle = WouldCauseCycle(newEdges)

                    -- 扣金，添加边
                    GS.gold = GS.gold - totalCost
                    for key, _ in pairs(newEdges) do
                        local x1, z1, x2, z2 = ParseEdgeKey(key)
                        M.AddEdge(x1, z1, x2, z2)
                    end

                    -- 重算功率
                    M.RecalculatePowerFlow()
                    M.RebuildAllVisuals()

                    local Tower = require("Tower")
                    Tower.UpdateAllActivationVisuals()

                    if willCycle then
                        SetWiringHint("WARNING: Short circuit detected! Energy Tower taking damage!")
                    else
                        print(string.format("[Wiring] Added %d edges (cost %d)", newCount, totalCost))
                    end
                end
            end
        end

        GS.wiringStart = nil
        wiringPath_ = nil
        wiringLastCell_ = nil
        wiringEdgeSet_ = nil
        return
    end
end

--- 进入/退出布线模式
function M.ToggleWiringMode()
    GS.wiringMode = not GS.wiringMode
    if not GS.wiringMode then
        ClearPreview()
        GS.wiringStart = nil
        wiringPath_ = nil
        wiringLastCell_ = nil
        wiringEdgeSet_ = nil
        GS.wiringHintMsg = nil
    end
    -- 切换布线模式时取消待确认的建塔加号
    local Tower = require("Tower")
    Tower.CancelPlacement()
    print("[Wiring] Mode: " .. (GS.wiringMode and "ON" or "OFF"))
end

-- ============================================================================
-- 能源线可视化 (三层着色)
-- ============================================================================

--- 短路材质缓存
local shortCircuitMat_ = nil
local disconnectedMat_ = nil

function M.RebuildAllVisuals()
    -- 清除旧可视化
    if GS.linesNode then
        GS.linesNode:Remove()
        GS.linesNode = nil
    end
    if GS.pulsesNode then
        GS.pulsesNode:Remove()
        GS.pulsesNode = nil
    end
    GS.pulses = {}
    GS.lineMat = nil

    local graph = GS.energyGraph
    if graph.edgeCount == 0 then return end

    GS.linesNode = GS.scene:CreateChild("EnergyLines")

    -- 正常连通材质 (蓝色发光)
    GS.lineMat = Material:new()
    GS.lineMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    GS.lineMat:SetShaderParameter("MatDiffColor", Variant(Color(0.25, 0.55, 0.85, 1.0)))
    GS.lineMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.5, 1.0, 1.5)))
    GS.lineMat:SetShaderParameter("Metallic", Variant(0.0))
    GS.lineMat:SetShaderParameter("Roughness", Variant(1.0))

    -- 短路材质 (红色闪烁)
    shortCircuitMat_ = Material:new()
    shortCircuitMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    shortCircuitMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.85, 0.15, 0.10, 1.0)))
    shortCircuitMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(1.5, 0.3, 0.2)))
    shortCircuitMat_:SetShaderParameter("Metallic", Variant(0.0))
    shortCircuitMat_:SetShaderParameter("Roughness", Variant(1.0))

    -- 断连材质 (暗灰)
    disconnectedMat_ = Material:new()
    disconnectedMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    disconnectedMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.3, 0.3, 0.3, 1.0)))
    disconnectedMat_:SetShaderParameter("MatEmissiveColor", Variant(Color(0.05, 0.05, 0.05)))
    disconnectedMat_:SetShaderParameter("Metallic", Variant(0.0))
    disconnectedMat_:SetShaderParameter("Roughness", Variant(1.0))

    local boxMdl = cache:GetResource("Model", "Models/Box.mdl")
    local net = GS.energyNetwork

    -- 判断边所在的连通分量是否包含源节点 (0,0)
    local function isEdgeConnected(eKey)
        return net.edgePower[eKey] ~= nil
    end

    -- 渲染每条边
    for eKey, edge in pairs(graph.edges) do
        local midX = (edge.x1 + edge.x2) * 0.5
        local midZ = (edge.z1 + edge.z2) * 0.5

        local lineNode = GS.linesNode:CreateChild("Line")
        lineNode.position = Vector3(midX, LINE_Y, midZ)

        if edge.isHoriz then
            local lenX = math.abs(edge.x2 - edge.x1) + LINE_WIDTH
            lineNode.scale = Vector3(lenX, LINE_THICK, LINE_WIDTH)
        else
            local lenZ = math.abs(edge.z2 - edge.z1) + LINE_WIDTH
            lineNode.scale = Vector3(LINE_WIDTH, LINE_THICK, lenZ)
        end

        local model = lineNode:CreateComponent("StaticModel")
        model:SetModel(boxMdl)

        -- 三层着色
        if GS.shortCircuit.active then
            model:SetMaterial(shortCircuitMat_)
        elseif isEdgeConnected(eKey) then
            model:SetMaterial(GS.lineMat)
        else
            model:SetMaterial(disconnectedMat_)
        end
        model.castShadows = false
    end

    -- 转角方块
    local cornerSet = {}
    for eKey, edge in pairs(graph.edges) do
        local nk1 = NodeKey(edge.x1, edge.z1)
        local nk2 = NodeKey(edge.x2, edge.z2)
        -- 检查每个节点是否是转角 (连有水平和垂直边)
        for _, nk in ipairs({nk1, nk2}) do
            local node = graph.nodes[nk]
            if node and #node.edges >= 2 then
                local hasH, hasV = false, false
                for _, ek in ipairs(node.edges) do
                    local e = graph.edges[ek]
                    if e then
                        if e.isHoriz then hasH = true else hasV = true end
                    end
                end
                if hasH and hasV then
                    cornerSet[nk] = true
                end
            end
        end
    end

    for nk, _ in pairs(cornerSet) do
        local cx, cz = ParseNodeKey(nk)
        local cornerNode = GS.linesNode:CreateChild("Corner")
        cornerNode.position = Vector3(cx, LINE_Y, cz)
        cornerNode.scale = Vector3(LINE_WIDTH, LINE_THICK, LINE_WIDTH)
        local model = cornerNode:CreateComponent("StaticModel")
        model:SetModel(boxMdl)
        if GS.shortCircuit.active then
            model:SetMaterial(shortCircuitMat_)
        else
            model:SetMaterial(GS.lineMat)
        end
        model.castShadows = false
    end

    -- 分叉节点 (3+方向的交叉点)
    local sphereMdlJ = cache:GetResource("Model", "Models/Sphere.mdl")
    local junctionMat = Material:new()
    junctionMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))

    if GS.shortCircuit.active then
        junctionMat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.3, 0.2, 1.0)))
        junctionMat:SetShaderParameter("MatEmissiveColor", Variant(Color(2.0, 0.5, 0.3)))
    else
        junctionMat:SetShaderParameter("MatDiffColor", Variant(Color(0.35, 0.70, 1.0, 1.0)))
        junctionMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.8, 1.5, 2.5)))
    end
    junctionMat:SetShaderParameter("Metallic", Variant(0.0))
    junctionMat:SetShaderParameter("Roughness", Variant(1.0))

    for nk, node in pairs(graph.nodes) do
        if #node.edges >= 3 then
            local dotNode = GS.linesNode:CreateChild("JunctionDot")
            local dotSize = LINE_WIDTH * 1.6
            dotNode.position = Vector3(node.x, LINE_Y + 0.02, node.z)
            dotNode.scale = Vector3(dotSize, LINE_THICK * 1.2, dotSize)
            local model = dotNode:CreateComponent("StaticModel")
            model:SetModel(sphereMdlJ)
            model:SetMaterial(junctionMat)
            model.castShadows = false
        end
    end

    -- ====== 脉冲动画: 沿生成树的边创建脉冲 ======
    if not GS.shortCircuit.active then
        M.BuildPulses()
    end
end

--- 构建脉冲动画 (沿生成树的路径)
function M.BuildPulses()
    if GS.pulsesNode then
        GS.pulsesNode:Remove()
    end
    GS.pulsesNode = GS.scene:CreateChild("EnergyPulses")
    GS.pulses = {}

    local net = GS.energyNetwork
    local sourceKey = NodeKey(0, 0)
    if not net.spanTree[sourceKey] then return end

    -- 收集从源节点到每个叶节点的路径
    local paths = {}

    local function collectPaths(nodeKey, currentPath)
        local treeNode = net.spanTree[nodeKey]
        if not treeNode then return end

        table.insert(currentPath, nodeKey)

        if #treeNode.childKeys == 0 then
            -- 叶节点，保存路径副本
            local pathCopy = {}
            for _, k in ipairs(currentPath) do
                table.insert(pathCopy, k)
            end
            table.insert(paths, pathCopy)
        else
            for _, childKey in ipairs(treeNode.childKeys) do
                collectPaths(childKey, currentPath)
            end
        end

        table.remove(currentPath)
    end

    collectPaths(sourceKey, {})

    -- 为每条路径创建脉冲
    local TOTAL_SEGMENTS = 1 + TAIL_COUNT
    local segMats = {}
    for si = 1, TOTAL_SEGMENTS do
        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        local falloff = 1.0 - ((si - 1) / TOTAL_SEGMENTS)
        falloff = falloff * falloff
        mat:SetShaderParameter("MatDiffColor", Variant(Color(
            0.4 + 0.5 * falloff, 0.7 + 0.3 * falloff, 0.9 + 0.1 * falloff, 1.0)))
        mat:SetShaderParameter("MatEmissiveColor", Variant(Color(
            1.8 * falloff, 3.0 * falloff, 4.0 * falloff)))
        mat:SetShaderParameter("Metallic", Variant(0.0))
        mat:SetShaderParameter("Roughness", Variant(1.0))
        segMats[si] = mat
    end

    local sphereMdl = cache:GetResource("Model", "Models/Sphere.mdl")

    for _, path in ipairs(paths) do
        if #path < 2 then goto continue_path end

        -- 转换为坐标路径
        local coordPath = {}
        for _, nk in ipairs(path) do
            local x, z = ParseNodeKey(nk)
            table.insert(coordPath, {x, z})
        end

        local pathLen = #coordPath - 1
        local speed = 1.0 / math.max(0.3, pathLen / 5.0)

        for k = 1, math.min(PULSES_PER_LINE, math.max(1, math.floor(pathLen / 2))) do
            local initT = (k - 1) / PULSES_PER_LINE
            local nodes = {}
            for si = 1, TOTAL_SEGMENTS do
                local n = GS.pulsesNode:CreateChild("Seg")
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
                path = coordPath,
                t = initT,
                speed = speed,
            }
            table.insert(GS.pulses, pulse)
        end

        ::continue_path::
    end
end

-- ============================================================================
-- 能源线伤害 (基于图模型: 边上有功率 → 对接触怪物造成伤害)
-- ============================================================================

local function PointToSegmentDist(px, pz, ax, az, bx, bz)
    local dx, dz = bx - ax, bz - az
    local len2 = dx * dx + dz * dz
    if len2 < 0.001 then
        local ex, ez = px - ax, pz - az
        return math.sqrt(ex * ex + ez * ez)
    end
    local t = ((px - ax) * dx + (pz - az) * dz) / len2
    t = math.max(0, math.min(1, t))
    local cx, cz = ax + t * dx, az + t * dz
    local ex, ez = px - cx, pz - cz
    return math.sqrt(ex * ex + ez * ez)
end

function M.UpdateLineDamage(dt)
    local graph = GS.energyGraph
    local net = GS.energyNetwork

    if graph.edgeCount == 0 then return end
    if GS.shortCircuit.active then return end  -- 短路时不造成伤害

    local hitRadius = CONFIG.LineHitRadius
    local dmgCoeff = CONFIG.CircuitDmgCoeff
    local convEff = M.GetConvEff()
    local Monster = require("Monster")

    for _, m in ipairs(GS.monsters) do
        if m.node and m.hp > 0 then
            if m.lineImmune then goto continue_monster end

            local mx = m.node.position.x
            local mz = m.node.position.z

            local totalDps = 0

            -- 检查每条有功率的边
            for eKey, edge in pairs(graph.edges) do
                local edgePwr = net.edgePower[eKey]
                if edgePwr and edgePwr > 0 then
                    local d = PointToSegmentDist(mx, mz, edge.x1, edge.z1, edge.x2, edge.z2)
                    if d < hitRadius then
                        -- DPS = edgePower / pathLen × dmgCoeff × convEff
                        -- 简化: 使用 edgePower 作为 current 的替代
                        local current = edgePwr / math.max(1, graph.edgeCount)
                        totalDps = totalDps + current * dmgCoeff * convEff
                    end
                end
            end

            if totalDps > 0 then
                -- 能量吸取怪 (精英词缀)
                if m.lineHealPerSec and m.lineHealPerSec > 0 then
                    local heal = m.lineHealPerSec * dt
                    m.hp = math.min(m.hp + heal, m.maxHp)
                end

                -- 线伤减免
                if m.lineDmgReduction and m.lineDmgReduction > 0 then
                    totalDps = totalDps * (1.0 - m.lineDmgReduction)
                end

                local dmg = totalDps * dt
                if dmg >= 0.5 then
                    Monster.DamageMonster(m, math.floor(dmg + 0.5), true)
                end
            end

            ::continue_monster::
        end
    end
end

-- ============================================================================
-- 短路伤害 (环路形成时持续扣血)
-- ============================================================================

function M.UpdateShortCircuitDamage(dt)
    if not GS.shortCircuit.active then
        GS.shortCircuit.dmgAccum = 0
        return
    end

    local totalPower = M.GetTotalPower()
    local dmgPerSec = totalPower * CONFIG.ShortCircuitDmgPerSec / 100.0
    GS.shortCircuit.dmgAccum = GS.shortCircuit.dmgAccum + dmgPerSec * dt

    if GS.shortCircuit.dmgAccum >= 1.0 then
        local dmg = math.floor(GS.shortCircuit.dmgAccum)
        GS.shortCircuit.dmgAccum = GS.shortCircuit.dmgAccum - dmg
        M.DamageEnergyTower(dmg)
    end
end

-- ============================================================================
-- 路径插值 (脉冲动画沿路径走)
-- ============================================================================

local function InterpolateAlongPath(path, t)
    local numSegs = #path - 1
    if numSegs <= 0 then
        return path[1][1], path[1][2]
    end

    t = math.max(0, math.min(1, t))
    local pos = t * numSegs
    local idx = math.floor(pos)
    local frac = pos - idx

    idx = idx + 1
    if idx > numSegs then
        idx = numSegs
        frac = 1.0
    end

    local a = path[idx]
    local b = path[idx + 1] or path[idx]
    return a[1] + (b[1] - a[1]) * frac,
           a[2] + (b[2] - a[2]) * frac
end

-- ============================================================================
-- 能源线脉冲动画 (路径跟随)
-- ============================================================================

function M.UpdateEnergyLinePulse(dt)
    -- 线材质呼吸效果
    if GS.lineMat then
        GS.linePulseTime = GS.linePulseTime + dt

        if GS.shortCircuit.active then
            -- 短路时红色闪烁
            local flash = 0.5 + 0.5 * math.sin(GS.linePulseTime * 8.0)
            if shortCircuitMat_ then
                shortCircuitMat_:SetShaderParameter("MatEmissiveColor",
                    Variant(Color(1.5 + flash * 1.5, 0.2 + flash * 0.3, 0.1 + flash * 0.1)))
            end
        else
            -- 正常蓝色呼吸
            local pulse = 0.5 + 0.5 * math.sin(GS.linePulseTime * 3.0)
            local intensity = 0.6 + pulse * 1.0
            GS.lineMat:SetShaderParameter("MatEmissiveColor",
                Variant(Color(0.5 * intensity, 1.0 * intensity, 1.5 * intensity)))
        end
    end

    -- 脉冲沿路径移动
    for _, p in ipairs(GS.pulses) do
        p.t = p.t + p.speed * dt
        if p.t >= 1.0 then p.t = p.t - 1.0 end

        for si, seg in ipairs(p.nodes) do
            if seg.node then
                local segT = p.t - (si - 1) * TAIL_SPACING
                if segT < 0 then segT = segT + 1.0 end

                local px, pz = InterpolateAlongPath(p.path, segT)
                seg.node.position = Vector3(px, LINE_Y, pz)
                local s = seg.baseSize
                seg.node.scale = Vector3(s, s, s)
            end
        end
    end
end

-- ============================================================================
-- 兼容旧接口
-- ============================================================================

M.RebuildEnergyLines = M.RebuildAllVisuals

--- 衰减计算 (用于塔伤害缩放)
function M.CalcAttenuation(dist)
    local R = M.GetEnergyRange()
    local att = 1.0 - 0.65 * math.pow(dist / R, 1.35)
    return math.max(0.25, math.min(1.0, att))
end

return M
