-- ============================================================================
-- EnergyTower.lua — 能源塔 / 升级 / 供能计算 / 能源线 / 线伤 / 脉冲动画
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

-- ============================================================================
-- 等级驱动属性读取
-- ============================================================================

--- 获取当前等级的属性
function M.GetLevelStats()
    return ET_LEVELS[GS.etLevel] or ET_LEVELS[1]
end

--- 获取当前总功率 (等级驱动)
function M.GetTotalPower()
    return M.GetLevelStats().power
end

--- 获取当前供能半径 (等级驱动)
function M.GetEnergyRange()
    return M.GetLevelStats().radius
end

--- 获取当前转伤效率
function M.GetConvEff()
    return M.GetLevelStats().convEff
end

-- ============================================================================
-- 升级
-- ============================================================================

--- 能否升级
function M.CanUpgrade()
    if GS.etLevel >= 10 then return false end
    local cost = ET_UPGRADE_COST[GS.etLevel + 1]
    if not cost then return false end
    return GS.gold >= cost.gold and GS.material >= cost.material
end

--- 获取下一级升级消耗 (nil 表示满级)
function M.GetUpgradeCost()
    if GS.etLevel >= 10 then return nil end
    return ET_UPGRADE_COST[GS.etLevel + 1]
end

--- 执行升级
function M.Upgrade()
    if not M.CanUpgrade() then return false end

    local cost = ET_UPGRADE_COST[GS.etLevel + 1]
    GS.gold = GS.gold - cost.gold
    GS.material = GS.material - cost.material
    GS.etLevel = GS.etLevel + 1

    local stats = M.GetLevelStats()

    -- 更新生命值 (按比例保留)
    local hpRatio = GS.etHP / GS.etMaxHP
    GS.etMaxHP = stats.hp
    GS.etHP = math.floor(GS.etMaxHP * hpRatio + 0.5)
    if GS.etHP < 1 then GS.etHP = 1 end

    -- 重新计算供能 (功率和半径可能变化)
    M.RecalculateEnergy()
    M.RebuildEnergyLines()

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

    -- 底座
    local baseChild = node:CreateChild("ETBase")
    local baseModel = baseChild:CreateComponent("StaticModel")
    baseModel:SetModel(cache:GetResource("Model", "Meshes/TD/tower-round-base.mdl"))
    baseModel:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-round-base_00_colormap.xml"))
    baseModel.castShadows = true

    -- 塔身第1层
    local bodyChild1 = node:CreateChild("ETBody1")
    bodyChild1.position = Vector3(0, 0.21, 0)
    local bodyModel1 = bodyChild1:CreateComponent("StaticModel")
    bodyModel1:SetModel(cache:GetResource("Model", "Meshes/TD/tower-round-top-a.mdl"))
    bodyModel1:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-round-top-a_00_colormap.xml"))
    bodyModel1.castShadows = true

    -- 塔身第2层
    local bodyChild2 = node:CreateChild("ETBody2")
    bodyChild2.position = Vector3(0, 0.71, 0)
    local bodyModel2 = bodyChild2:CreateComponent("StaticModel")
    bodyModel2:SetModel(cache:GetResource("Model", "Meshes/TD/tower-round-top-a.mdl"))
    bodyModel2:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-round-top-a_00_colormap.xml"))
    bodyModel2.castShadows = true

    -- 水晶
    local crystalChild = node:CreateChild("ETCrystals")
    crystalChild.position = Vector3(0, 1.21, 0)
    local crystalModel = crystalChild:CreateComponent("StaticModel")
    crystalModel:SetModel(cache:GetResource("Model", "Meshes/TD/tower-round-crystals.mdl"))
    crystalModel:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-round-crystals_00_colormap.xml"))
    crystalModel.castShadows = true

    -- 发光粒子（独立节点）
    local particleNode = GS.scene:CreateChild("ETParticles")
    particleNode.position = Vector3(0, 0.25, 0)

    local emitter = particleNode:CreateComponent("ParticleEmitter")
    local effect = ParticleEffect()
    effect:SetEmitterType(EMITTER_SPHERE)
    effect:SetEmitterSize(Vector3(2.6, 0.15, 2.6))
    effect:SetNumParticles(80)
    effect:SetMinEmissionRate(35)
    effect:SetMaxEmissionRate(55)
    effect:SetMinTimeToLive(0.4)
    effect:SetMaxTimeToLive(0.9)
    effect:SetMinParticleSize(Vector2(0.015, 0.015))
    effect:SetMaxParticleSize(Vector2(0.04, 0.04))
    effect:SetMinDirection(Vector3(-0.2, 1.0, -0.2))
    effect:SetMaxDirection(Vector3(0.2, 1.5, 0.2))
    effect:SetMinVelocity(0.8)
    effect:SetMaxVelocity(1.5)
    effect:SetDampingForce(1.5)
    effect:SetMinRotationSpeed(90)
    effect:SetMaxRotationSpeed(240)
    effect:AddColorTime(Color(1.0, 0.9, 0.4, 0.0), 0.0)
    effect:AddColorTime(Color(1.0, 0.8, 0.25, 1.0), 0.1)
    effect:AddColorTime(Color(1.0, 0.65, 0.15, 0.5), 0.4)
    effect:AddColorTime(Color(0.8, 0.4, 0.05, 0.0), 1.0)

    local pMat = Material:new()
    pMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    pMat:SetShaderParameter("MatDiffColor", Variant(Color(1.0, 0.85, 0.35, 1.0)))
    pMat:SetShaderParameter("MatEmissiveColor", Variant(Color(2.0, 1.5, 0.4)))
    pMat:SetShaderParameter("Metallic", Variant(0.0))
    pMat:SetShaderParameter("Roughness", Variant(1.0))
    effect:SetMaterial(pMat)
    emitter:SetEffect(effect)
    emitter:SetEmitting(true)

    -- 血量 (等级驱动)
    local stats = M.GetLevelStats()
    GS.etHP = stats.hp
    GS.etMaxHP = stats.hp

    -- 血条（独立节点）
    GS.etHPBg = GS.scene:CreateChild("EnergyTowerHPBar")
    GS.etHPBg.position = Vector3(0, 3.6, 0)

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

function M.DamageEnergyTower(dmg)
    if GS.gameOver then return end
    GS.etHP = GS.etHP - dmg
    Utils.SpawnDmgText(Vector3(0, 3.0, 0), dmg)
    if GS.etHP <= 0 then
        GS.etHP = 0
        -- GameOver 由 GameUI 处理
        GS.gameOver = true
    end
end

-- ============================================================================
-- 供能计算
-- ============================================================================

function M.CalcAttenuation(dist)
    local R = M.GetEnergyRange()
    local att = 1.0 - 0.65 * math.pow(dist / R, 1.35)
    return math.max(0.25, math.min(1.0, att))
end

function M.RecalculateEnergy()
    local N = #GS.towers
    if N == 0 then return end
    local totalPower = M.GetTotalPower()
    local pShare = totalPower / N
    for _, t in ipairs(GS.towers) do
        local att = M.CalcAttenuation(t.dist)
        t.delivered = pShare * att
        t.linePwr = pShare - t.delivered
        t.ratio = t.delivered / totalPower
    end
end

-- ============================================================================
-- 能源线可视化
-- ============================================================================

function M.RebuildEnergyLines()
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
    GS.lineSegments = {}

    if #GS.towers == 0 then return end

    local LINE_Y = 0.15
    local LINE_THICK = 0.10
    local LINE_WIDTH = 0.14

    GS.linesNode = GS.scene:CreateChild("EnergyLines")

    GS.lineMat = Material:new()
    GS.lineMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    GS.lineMat:SetShaderParameter("MatDiffColor", Variant(Color(0.25, 0.55, 0.85, 1.0)))
    GS.lineMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.5, 1.0, 1.5)))
    GS.lineMat:SetShaderParameter("Metallic", Variant(0.0))
    GS.lineMat:SetShaderParameter("Roughness", Variant(1.0))

    for _, t in ipairs(GS.towers) do
        local dx = t.gx
        local dz = t.gz
        local len = math.sqrt(dx * dx + dz * dz)
        if len > 0.01 then
            local lineNode = GS.linesNode:CreateChild("Line")
            lineNode.position = Vector3(dx * 0.5, LINE_Y, dz * 0.5)
            local angle = math.deg(math.atan(dx, dz))
            lineNode.rotation = Quaternion(angle, Vector3.UP)
            lineNode.scale = Vector3(LINE_WIDTH, LINE_THICK, len)

            local model = lineNode:CreateComponent("StaticModel")
            model:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
            model:SetMaterial(GS.lineMat)
            model.castShadows = false

            -- 记录线段数据 (起点=能源塔中心, 终点=塔位置)
            table.insert(GS.lineSegments, {
                ax = 0, az = 0,
                bx = t.gx, bz = t.gz,
                linePwr = t.linePwr,
            })
        end
    end

    -- 脉冲
    GS.pulsesNode = GS.scene:CreateChild("EnergyPulses")
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
    for _, t in ipairs(GS.towers) do
        local dist = math.sqrt(t.gx * t.gx + t.gz * t.gz)
        local speed = 1.0 / math.max(0.3, dist / 5.0)

        for k = 1, PULSES_PER_LINE do
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
                fromX = 0, fromZ = 0,
                toX = t.gx, toZ = t.gz,
                t = initT,
                speed = speed,
            }
            table.insert(GS.pulses, pulse)
        end
    end
end

-- ============================================================================
-- 能源线伤害 (怪物碰撞线段 → DPS)
-- ============================================================================

--- 点到线段的最短距离 (2D, xz 平面)
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
    local segs = GS.lineSegments
    if #segs == 0 then return end

    local hitRadius = CONFIG.LineHitRadius
    local dmgCoeff = CONFIG.LineDmgCoeff
    local convEff = M.GetConvEff()
    local decayTable = CONFIG.LineMultiDecay
    local Monster = require("Monster")

    for _, m in ipairs(GS.monsters) do
        if m.node and m.hp > 0 then
            local mx = m.node.position.x
            local mz = m.node.position.z

            -- 收集命中的线段功率 (按功率从大到小排序)
            local hitPowers = {}
            for _, seg in ipairs(segs) do
                local d = PointToSegmentDist(mx, mz, seg.ax, seg.az, seg.bx, seg.bz)
                if d < hitRadius then
                    table.insert(hitPowers, seg.linePwr)
                end
            end

            if #hitPowers > 0 then
                -- 按功率降序，高功率线先享受 100% 系数
                table.sort(hitPowers, function(a, b) return a > b end)

                local totalDps = 0
                for idx, pwr in ipairs(hitPowers) do
                    local decay = decayTable[idx] or decayTable[#decayTable]
                    totalDps = totalDps + pwr * dmgCoeff * convEff * decay
                end

                local dmg = totalDps * dt
                if dmg >= 0.5 then
                    Monster.DamageMonster(m, math.floor(dmg + 0.5))
                end
            end
        end
    end
end

-- ============================================================================
-- 能源线脉冲动画
-- ============================================================================

function M.UpdateEnergyLinePulse(dt)
    if GS.lineMat then
        GS.linePulseTime = GS.linePulseTime + dt
        local pulse = 0.5 + 0.5 * math.sin(GS.linePulseTime * 3.0)
        local intensity = 0.6 + pulse * 1.0
        GS.lineMat:SetShaderParameter("MatEmissiveColor",
            Variant(Color(0.5 * intensity, 1.0 * intensity, 1.5 * intensity)))
    end

    local LINE_Y = 0.15
    for _, p in ipairs(GS.pulses) do
        p.t = p.t + p.speed * dt
        if p.t >= 1.0 then p.t = p.t - 1.0 end

        for si, seg in ipairs(p.nodes) do
            if seg.node then
                local segT = p.t - (si - 1) * TAIL_SPACING
                if segT < 0 then segT = segT + 1.0 end
                local px = p.fromX + (p.toX - p.fromX) * segT
                local pz = p.fromZ + (p.toZ - p.fromZ) * segT
                seg.node.position = Vector3(px, LINE_Y, pz)
                local s = seg.baseSize
                seg.node.scale = Vector3(s, s, s)
            end
        end
    end
end

return M
