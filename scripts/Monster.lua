-- ============================================================================
-- Monster.lua — 怪物类型 / 路径寻路 / HP波次缩放 / 精英词缀 / 伤害 / 死亡
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS
local Utils = require("Utils")
local EnergyTower = require("EnergyTower")
local StatusEffect = require("StatusEffect")
local Wave -- lazy require to avoid circular dependency

local M = {}

-- HP 缩放: 使用 Wave.HPScaleFactor() (抛物线缩放, 见 Wave.lua)

-- ============================================================================
-- 怪物复合模型构建 (用基础几何体按类型堆叠，赋予各类型独特外形)
-- ============================================================================
local function BuildMonsterVisuals(node, typeDef, monsterType, isElite)
    local emitMult = isElite and 2.5 or 1.0
    local baseEmitR = typeDef.emissive.r * emitMult
    local baseEmitG = typeDef.emissive.g * emitMult
    local baseEmitB = typeDef.emissive.b * emitMult

    local bodyMat = Material:new()
    bodyMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    bodyMat:SetShaderParameter("MatDiffColor", Variant(typeDef.color))
    bodyMat:SetShaderParameter("MatEmissiveColor", Variant(Color(baseEmitR, baseEmitG, baseEmitB)))
    bodyMat:SetShaderParameter("Metallic", Variant(0.1))
    bodyMat:SetShaderParameter("Roughness", Variant(0.8))

    local c = typeDef.color

    -- 辅助: 快速添加子部件
    local function Part(name, mdl, mat, px, py, pz, sx, sy, sz, rq)
        local pn = node:CreateChild(name)
        pn.position = Vector3(px, py, pz)
        pn.scale    = Vector3(sx, sy, sz)
        if rq then pn.rotation = rq end
        local m = pn:CreateComponent("StaticModel")
        m:SetModel(cache:GetResource("Model", mdl))
        m:SetMaterial(mat)
        m.castShadows = true
    end

    -- 辅助: 创建发光眼睛材质
    local function EyeMat(r, g, b, er, eg, eb)
        local em = Material:new()
        em:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        em:SetShaderParameter("MatDiffColor",    Variant(Color(r,  g,  b,  1)))
        em:SetShaderParameter("MatEmissiveColor", Variant(Color(er, eg, eb)))
        em:SetShaderParameter("Metallic",  Variant(0.0))
        em:SetShaderParameter("Roughness", Variant(0.4))
        return em
    end

    if monsterType == "walker" then
        -- 行尸: 圆滚躯干 + 小头 + 僵尸前伸双臂
        Part("Body", "Models/Sphere.mdl",   bodyMat, 0, 0.55, 0,    0.88, 0.82, 0.88)
        Part("Head", "Models/Sphere.mdl",   bodyMat, 0, 1.13, 0.08, 0.50, 0.50, 0.50)
        Part("ArmL", "Models/Cylinder.mdl", bodyMat, -0.48, 0.88, 0.28, 0.17, 0.55, 0.17, Quaternion(-65, 0, -18))
        Part("ArmR", "Models/Cylinder.mdl", bodyMat,  0.48, 0.88, 0.28, 0.17, 0.55, 0.17, Quaternion(-65, 0,  18))

    elseif monsterType == "swarm" then
        -- 群虫: 扁平圆盘 + 6根放射刺腿
        Part("Body", "Models/Sphere.mdl", bodyMat, 0, 0.22, 0, 1.30, 0.40, 1.30)
        for i = 0, 5 do
            local rad = math.rad(i * 60)
            Part("Leg"..i, "Models/Cone.mdl", bodyMat,
                math.sin(rad)*0.72, 0.12, math.cos(rad)*0.72,
                0.13, 0.52, 0.13,
                Quaternion(i*60, Vector3.UP) * Quaternion(55, Vector3.RIGHT))
        end

    elseif monsterType == "shellbeast" then
        -- 甲壳兽: 宽扁方形躯干 + 深色隆起背甲 + 小头
        Part("Body", "Models/Box.mdl", bodyMat, 0, 0.38, 0, 1.10, 0.62, 1.38)
        local shellMat = bodyMat:Clone()
        shellMat:SetShaderParameter("MatDiffColor",    Variant(Color(c.r*0.65, c.g*0.55, c.b*0.40, 1)))
        shellMat:SetShaderParameter("MatEmissiveColor", Variant(Color(baseEmitR*0.4, baseEmitG*0.4, baseEmitB*0.3)))
        shellMat:SetShaderParameter("Metallic",  Variant(0.35))
        shellMat:SetShaderParameter("Roughness", Variant(0.40))
        Part("Shell", "Models/Sphere.mdl", shellMat, 0, 0.80, -0.08, 1.18, 0.68, 1.32)
        Part("Head",  "Models/Sphere.mdl", bodyMat,  0, 0.54,  0.77, 0.44, 0.42, 0.44)

    elseif monsterType == "sprinter" then
        -- 疾行者: 流线型椭球 + 尖锥鼻 + 4条细腿
        Part("Body", "Models/Sphere.mdl", bodyMat, 0, 0.44, 0,    0.62, 0.58, 1.38)
        Part("Nose", "Models/Cone.mdl",   bodyMat, 0, 0.44, 0.90, 0.26, 0.52, 0.26, Quaternion(90, Vector3.RIGHT))
        for i, lp in ipairs({{-0.36,0.18,0.32},{0.36,0.18,0.32},{-0.36,0.18,-0.32},{0.36,0.18,-0.32}}) do
            Part("Leg"..i, "Models/Cylinder.mdl", bodyMat, lp[1],lp[2],lp[3], 0.11,0.42,0.11)
        end

    elseif monsterType == "shielded" then
        -- 护盾怪: 圆球身体 + 圆周尖刺 + 发光双眼
        Part("Body", "Models/Sphere.mdl", bodyMat, 0, 0.55, 0, 0.92, 0.88, 0.92)
        for i = 0, 5 do
            local rad = math.rad(i * 60)
            Part("Sp"..i, "Models/Cone.mdl", bodyMat,
                math.sin(rad)*0.90, 0.55 + math.cos(rad)*0.88*0.22, math.cos(rad)*0.90,
                0.11, 0.34, 0.11,
                Quaternion(i*60, Vector3.UP) * Quaternion(-90, Vector3.RIGHT))
        end
        local em = EyeMat(0.9,0.85,1.0, 1.8,1.5,3.2)
        Part("EyeL", "Models/Sphere.mdl", em, -0.22, 0.66, 0.43, 0.14,0.14,0.14)
        Part("EyeR", "Models/Sphere.mdl", em,  0.22, 0.66, 0.43, 0.14,0.14,0.14)

    elseif monsterType == "energy_devourer" then
        -- 吞能者: 球形核心 + 倾斜轨道环 + 黄色双眼
        Part("Body", "Models/Sphere.mdl", bodyMat, 0, 0.50, 0, 0.88,0.88,0.88)
        local orbitMat = Material:new()
        orbitMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
        orbitMat:SetShaderParameter("MatDiffColor",    Variant(Color(c.r, c.g, c.b, 0.72)))
        orbitMat:SetShaderParameter("MatEmissiveColor", Variant(Color(baseEmitR*2.2, baseEmitG*2.2, baseEmitB*2.2)))
        orbitMat:SetShaderParameter("Metallic",  Variant(0.85))
        orbitMat:SetShaderParameter("Roughness", Variant(0.15))
        Part("Orbit", "Models/Torus.mdl", orbitMat, 0,0.50,0, 1.42,0.16,1.42, Quaternion(50, Vector3.RIGHT))
        local em = EyeMat(1.0,0.9,0.2, 3.0,2.5,0.5)
        Part("EyeL", "Models/Sphere.mdl", em, -0.20,0.62,0.40, 0.15,0.15,0.15)
        Part("EyeR", "Models/Sphere.mdl", em,  0.20,0.62,0.40, 0.15,0.15,0.15)

    elseif monsterType == "shatter_titan" then
        -- 裂山巨像 Boss: 方形巨躯 + 宽肩 + 球头 + 粗腿 + 橙色眼
        Part("Torso",    "Models/Box.mdl",    bodyMat, 0,0.68,0,  1.38,1.18,1.08)
        Part("Shoulder", "Models/Box.mdl",    bodyMat, 0,1.28,0,  1.92,0.28,0.88)
        Part("Head",     "Models/Sphere.mdl", bodyMat, 0,1.75,0,  0.82,0.82,0.82)
        for i, lp in ipairs({{-0.48,0.20,0.30},{0.48,0.20,0.30},{-0.48,0.20,-0.30},{0.48,0.20,-0.30}}) do
            Part("Leg"..i, "Models/Cylinder.mdl", bodyMat, lp[1],lp[2],lp[3], 0.34,0.52,0.34)
        end
        local em = EyeMat(1.0,0.55,0.1, 3.2,1.6,0.3)
        Part("EyeL", "Models/Sphere.mdl", em, -0.22,1.83,0.40, 0.18,0.18,0.18)
        Part("EyeR", "Models/Sphere.mdl", em,  0.22,1.83,0.40, 0.18,0.18,0.18)

    elseif monsterType == "line_devourer" then
        -- 吞线母体 Boss: 巨型球核 + 三重轨道环 + 四卫星 + 紫眼
        Part("Core", "Models/Sphere.mdl", bodyMat, 0,0.88,0, 1.62,1.62,1.62)
        local ringRots   = { Quaternion(0,0,0), Quaternion(60,Vector3.RIGHT), Quaternion(-50,Vector3.FORWARD) }
        local ringAlphas = { 0.65, 0.50, 0.40 }
        for i, rq in ipairs(ringRots) do
            local rm = Material:new()
            rm:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
            rm:SetShaderParameter("MatDiffColor",    Variant(Color(c.r,c.g,c.b, ringAlphas[i])))
            rm:SetShaderParameter("MatEmissiveColor", Variant(Color(baseEmitR*1.6, baseEmitG*1.6, baseEmitB*1.6)))
            rm:SetShaderParameter("Metallic",  Variant(0.75))
            rm:SetShaderParameter("Roughness", Variant(0.18))
            Part("Ring"..i, "Models/Torus.mdl", rm, 0,0.88,0, 2.05,0.17,2.05, rq)
        end
        for i = 0, 3 do
            local rad = math.rad(i*90 + 45)
            Part("Sat"..i, "Models/Sphere.mdl", bodyMat,
                math.sin(rad)*1.48, 0.88, math.cos(rad)*1.48, 0.34,0.34,0.34)
        end
        local em = EyeMat(0.85,0.25,1.0, 2.5,0.5,4.2)
        Part("EyeL", "Models/Sphere.mdl", em, -0.40,1.06,0.78, 0.25,0.25,0.25)
        Part("EyeR", "Models/Sphere.mdl", em,  0.40,1.06,0.78, 0.25,0.25,0.25)

    else
        -- 兜底
        Part("Body", "Models/Sphere.mdl", bodyMat, 0,0.50,0, 0.85,0.85,0.85)
    end

    return bodyMat, baseEmitR, baseEmitG, baseEmitB
end

-- ============================================================================
-- 怪物类型定义 (对齐 enemies.json)
-- ============================================================================
M.TYPES = {
    walker = {
        name = "行尸",
        base_hp = 50,
        base_speed = 1.0,
        armor_ratio = 0,
        shield_hp = 0,
        reward_gold = 5,
        reward_material = 0,
        reward_energy = 0,
        size = 0.38,
        color = Color(0.85, 0.22, 0.18, 1),
        emissive = Color(0.35, 0.08, 0.05),
    },
    swarm = {
        name = "群虫",
        base_hp = 25,
        base_speed = 1.2,
        armor_ratio = 0,
        shield_hp = 0,
        reward_gold = 2,
        reward_material = 0,
        reward_energy = 0,
        size = 0.23,
        color = Color(0.25, 0.60, 0.20, 1),
        emissive = Color(0.08, 0.25, 0.05),
    },
    shellbeast = {
        name = "甲壳兽",
        base_hp = 80,
        base_speed = 0.6,
        armor_ratio = 0.5,
        shield_hp = 0,
        reward_gold = 10,
        reward_material = 1,
        reward_energy = 0,
        size = 0.49,
        color = Color(0.50, 0.35, 0.18, 1),
        emissive = Color(0.20, 0.12, 0.05),
    },
    sprinter = {
        name = "疾行者",
        base_hp = 35,
        base_speed = 2.0,
        armor_ratio = 0,
        shield_hp = 0,
        reward_gold = 6,
        reward_material = 0,
        reward_energy = 0,
        size = 0.30,
        color = Color(0.20, 0.65, 0.90, 1),
        emissive = Color(0.10, 0.30, 0.50),
    },
    shielded = {
        name = "护盾怪",
        base_hp = 50,
        base_speed = 1.0,
        armor_ratio = 0,
        shield_hp = 30,
        reward_gold = 8,
        reward_material = 0,
        reward_energy = 0,
        size = 0.40,
        color = Color(0.65, 0.25, 0.80, 1),
        emissive = Color(0.30, 0.10, 0.40),
    },
    energy_devourer = {
        name = "吞能者",
        base_hp = 60,
        base_speed = 1.0,
        armor_ratio = 0,
        shield_hp = 0,
        reward_gold = 8,
        reward_material = 0,
        reward_energy = 0,
        lineDmgReduction = 0.4, -- 经过能源线时该线对自己伤害 -40%
        size = 0.42,
        color = Color(0.75, 0.60, 0.15, 1),
        emissive = Color(0.35, 0.25, 0.05),
    },
}

-- Boss 类型 (独立表，HP 不随波次缩放 — 已含固定高 HP)
M.BOSSES = {
    shatter_titan = {
        name = "裂山巨像",
        base_hp = 1900,
        base_speed = 0.5,
        armor_ratio = 0,
        shield_hp = 0,
        is_boss = true,
        reward_gold = 200,
        reward_material = 50,
        reward_energy = 30,
        size = 0.80,
        color = Color(0.40, 0.27, 0.13, 1),
        emissive = Color(0.30, 0.15, 0.05),
        -- 特殊: 每15s获得护甲buff持续8s
        armorCycleInterval = 15.0,
        armorBuffDuration = 8.0,
        armorBuffValue = 0.50, -- +50% 护甲
    },
    line_devourer = {
        name = "吞线母体",
        base_hp = 7200,
        base_speed = 0.5,
        armor_ratio = 0,
        shield_hp = 0,
        is_boss = true,
        reward_gold = 500,
        reward_material = 150,
        reward_energy = 100,
        size = 0.90,
        color = Color(0.40, 0.13, 0.67, 1),
        emissive = Color(0.30, 0.10, 0.50),
        -- 特殊: 免疫能源线伤害, 每30s吸取30%功率持续5s
        lineImmune = true,
        drainInterval = 30.0,
        drainDuration = 5.0,
        drainRatio = 0.30, -- 吸取30%总功率
    },
}

-- ============================================================================
-- 精英词缀定义 (对齐 enemies.json)
-- ============================================================================
M.ELITE_AFFIXES = {
    thick_armor = {
        name = "厚甲",
        hp_multiplier = 1.5,
        armor_multiplier = 3.0, -- 护甲系数 ×3
    },
    swift = {
        name = "迅捷",
        hp_multiplier = 1.3,
        speed_multiplier = 1.5,
    },
    burn_resist = {
        name = "抗燃",
        hp_multiplier = 1.4,
        burn_resist = 0.7, -- 燃烧持续 -70% (预留)
    },
    energy_drinker = {
        name = "吸能",
        hp_multiplier = 1.4,
        line_heal_per_sec = 5, -- 经过能源线时每秒回血
    },
}

-- ============================================================================
-- 内部: 获取类型定义 (普通 + Boss)
-- ============================================================================

local function GetTypeDef(monsterType)
    return M.TYPES[monsterType] or M.BOSSES[monsterType] or M.TYPES.walker
end

-- ============================================================================
-- 生成怪物
-- ============================================================================

--- @param monsterType string 怪物 ID (walker/swarm/shellbeast/sprinter/shielded/energy_devourer/shatter_titan/line_devourer)
--- @param opts table|nil { spawnX, spawnZ, waveNumber, eliteAffixes }
function M.SpawnMonster(monsterType, opts)
    -- Lazy require Wave to avoid circular dependency
    if not Wave then Wave = require("Wave") end

    monsterType = monsterType or "walker"
    opts = opts or {}
    local waveNumber = opts.waveNumber or 1
    local eliteAffixes = opts.eliteAffixes or {}
    local spawnX = opts.spawnX
    local spawnZ = opts.spawnZ

    local typeDef = GetTypeDef(monsterType)

    -- === 基础属性 ===
    local hp = typeDef.base_hp
    local speed = typeDef.base_speed
    local armorRatio = typeDef.armor_ratio or 0
    local shieldHp = typeDef.shield_hp or 0

    -- === HP 波次缩放 (抛物线公式) ===
    local isBoss = typeDef.is_boss or false
    local scaleFactor = Wave.HPScaleFactor(waveNumber, isBoss)
    hp = hp * scaleFactor

    -- === 精英词缀 ===
    local isElite = #eliteAffixes > 0
    local lineHealPerSec = 0
    local affixNames = {}

    for _, affixId in ipairs(eliteAffixes) do
        local affix = M.ELITE_AFFIXES[affixId]
        if affix then
            table.insert(affixNames, affix.name)
            if affix.hp_multiplier then hp = hp * affix.hp_multiplier end
            if affix.speed_multiplier then speed = speed * affix.speed_multiplier end
            if affix.armor_multiplier then armorRatio = armorRatio * affix.armor_multiplier end
            if affix.line_heal_per_sec then lineHealPerSec = lineHealPerSec + affix.line_heal_per_sec end
        end
    end

    -- 护甲上限 0.9
    armorRatio = math.min(armorRatio, 0.9)
    -- 护盾也随波次缩放
    if shieldHp > 0 then
        shieldHp = shieldHp * scaleFactor
    end

    hp = math.floor(hp + 0.5)
    shieldHp = math.floor(shieldHp + 0.5)

    -- === 出生位置 (径向刷新) ===
    local sx, sz
    if spawnX and spawnZ then
        sx = spawnX
        sz = spawnZ
    else
        -- 兜底: 随机角度
        local angle = math.random() * math.pi * 2
        local sd = CONFIG.SpawnDistance
        sx = math.cos(angle) * sd
        sz = math.sin(angle) * sd
    end

    -- === 创建节点 ===
    local node = GS.scene:CreateChild("Monster")
    local s = typeDef.size
    -- 精英/Boss 略微放大
    if isElite then s = s * 1.2 end

    node.position = Vector3(sx, 0, sz)
    node.scale = Vector3(s, s, s)

    -- 朝向能源塔中心
    local dx = 0 - sx
    local dz = 0 - sz
    local yaw = math.deg(math.atan(dx, dz))
    node.rotation = Quaternion(yaw, Vector3.UP)

    -- === 复合模型 ===
    local mat, baseEmitR, baseEmitG, baseEmitB = BuildMonsterVisuals(node, typeDef, monsterType, isElite)

    -- 移动方向 (初始: 朝向能源塔中心)
    local dirDx = 0 - sx
    local dirDz = 0 - sz
    local dirLen = math.sqrt(dirDx * dirDx + dirDz * dirDz)
    local dir = dirLen > 0.01 and Vector3(dirDx / dirLen, 0, dirDz / dirLen) or Vector3(0, 0, 1)

    -- 脚底红色位置指示圆圈
    -- 圆圈挂在 node 子节点上:
    --   node.position.y = 0 (贴地), node.scale = (s,s,s)
    --   子节点世界Y = 0 + s * localY  => localY = groundY/s
    --   子节点世界半径 = s * localScale  => localScale = worldRadius/s
    local footCircleNode = node:CreateChild("FootCircle")
    local groundY  = CONFIG.GridY + 0.012   -- 贴地稍微浮起避免 z-fighting
    local invS = 1.0 / s
    -- XZ 方向: 圆圈世界半径随怪物大小略变, 但不会太小
    local circleWorldR = math.max(0.28, s * 1.15)
    footCircleNode.position = Vector3(0, groundY * invS, 0)
    footCircleNode.scale    = Vector3(invS * circleWorldR, 1.0, invS * circleWorldR)

    local footGeom = footCircleNode:CreateComponent("CustomGeometry")
    do
        -- 环形带: 贴地平放, Y轴朝上
        local segs = 20
        local innerR = 0.88
        local outerR = 1.0
        footGeom:BeginGeometry(0, TRIANGLE_LIST)
        for i = 0, segs - 1 do
            local a0 = (i / segs) * math.pi * 2
            local a1 = ((i + 1) / segs) * math.pi * 2
            local ci0, si0 = math.cos(a0), math.sin(a0)
            local ci1, si1 = math.cos(a1), math.sin(a1)
            footGeom:DefineVertex(Vector3(ci0 * innerR, 0, si0 * innerR)); footGeom:DefineNormal(Vector3.UP)
            footGeom:DefineVertex(Vector3(ci1 * innerR, 0, si1 * innerR)); footGeom:DefineNormal(Vector3.UP)
            footGeom:DefineVertex(Vector3(ci1 * outerR, 0, si1 * outerR)); footGeom:DefineNormal(Vector3.UP)
            footGeom:DefineVertex(Vector3(ci0 * innerR, 0, si0 * innerR)); footGeom:DefineNormal(Vector3.UP)
            footGeom:DefineVertex(Vector3(ci1 * outerR, 0, si1 * outerR)); footGeom:DefineNormal(Vector3.UP)
            footGeom:DefineVertex(Vector3(ci0 * outerR, 0, si0 * outerR)); footGeom:DefineNormal(Vector3.UP)
        end
        footGeom:Commit()
        local footMat = Material:new()
        footMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
        -- Boss 用橙色, 精英用品红, 普通用红色
        local fr, fg, fb, fa
        if isBoss then
            fr, fg, fb, fa = 1.0, 0.45, 0.0, 0.85
        elseif isElite then
            fr, fg, fb, fa = 1.0, 0.10, 0.85, 0.78
        else
            fr, fg, fb, fa = 0.95, 0.08, 0.05, 0.65
        end
        footMat:SetShaderParameter("MatDiffColor",    Variant(Color(fr, fg, fb, fa)))
        footMat:SetShaderParameter("MatEmissiveColor", Variant(Color(fr * 0.55, fg * 0.15, fb * 0.15)))
        footMat:SetShaderParameter("Metallic",  Variant(0.0))
        footMat:SetShaderParameter("Roughness", Variant(1.0))
        footGeom:SetMaterial(footMat)
    end

    -- 血条
    local hpBg, hpFill, fillMat = Utils.CreateHealthBar(node)

    -- 护盾视觉
    ---@type Node
    local shieldNode = nil
    if shieldHp > 0 then
        shieldNode = node:CreateChild("Shield")
        local shieldScale = 1.8
        shieldNode.scale = Vector3(shieldScale, shieldScale, shieldScale)
        local shieldModel = shieldNode:CreateComponent("StaticModel")
        shieldModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        local shieldMat = Material:new()
        shieldMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
        shieldMat:SetShaderParameter("MatDiffColor", Variant(Color(0.4, 0.3, 0.9, 0.25)))
        shieldMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.3, 0.2, 0.7)))
        shieldMat:SetShaderParameter("Metallic", Variant(0.0))
        shieldMat:SetShaderParameter("Roughness", Variant(0.3))
        shieldModel:SetMaterial(shieldMat)
        shieldModel.castShadows = false
    end

    -- === 怪物实例 ===
    local monster = {
        node = node,
        type = monsterType,
        hp = hp,
        maxHp = hp,
        speed = speed,
        dir = dir,
        armorRatio = armorRatio,
        baseArmorRatio = armorRatio, -- 保存基础护甲 (Boss护甲buff需要)
        shield = shieldHp,
        maxShield = shieldHp,
        shieldNode = shieldNode,
        hpBg = hpBg,
        hpFill = hpFill,
        fillMat = fillMat,
        -- 掉落
        goldDrop = typeDef.reward_gold or 0,
        energyDrop = typeDef.reward_energy or 0,
        materialDrop = typeDef.reward_material or 0,
        -- 精英
        isElite = isElite,
        eliteAffixes = eliteAffixes,
        isBoss = typeDef.is_boss or false,
        -- 特殊属性
        lineDmgReduction = typeDef.lineDmgReduction or 0,
        lineHealPerSec = lineHealPerSec,
        lineImmune = typeDef.lineImmune or false,
        -- Boss: 裂山巨像护甲周期
        armorCycleTimer = 0,
        armorBuffTimer = 0,
        armorBuffValue = typeDef.armorBuffValue or 0,
        armorCycleInterval = typeDef.armorCycleInterval or 0,
        armorBuffDuration = typeDef.armorBuffDuration or 0,
        -- 受伤泛红
        bodyMat = mat,
        baseEmitR = baseEmitR,
        baseEmitG = baseEmitG,
        baseEmitB = baseEmitB,
        flashTimer = 0,
        -- Boss: 吞线母体功率吸取
        drainTimer = 0,
        drainActiveTimer = 0,
        drainInterval = typeDef.drainInterval or 0,
        drainDuration = typeDef.drainDuration or 0,
        drainRatio = typeDef.drainRatio or 0,
        drainActive = false,
    }
    -- 初始化状态效果容器
    StatusEffect.InitMonsterEffects(monster)
    table.insert(GS.monsters, monster)

    -- 日志
    local label = typeDef.name
    if isElite then label = "[" .. table.concat(affixNames, "+") .. "] " .. label end
    if typeDef.is_boss then label = "★ BOSS: " .. label end
    print(string.format("[Monster] Spawned %s | HP: %d | Spd: %.1f | Armor: %.0f%%",
        label, hp, speed, armorRatio * 100))
end

-- ============================================================================
-- 转向避障
-- ============================================================================

--- 计算避障推力 (检测前方障碍物)
--- @param pos Vector3 当前位置
--- @param dir Vector3 当前移动方向 (归一化)
--- @return number pushX, number pushZ 推力分量
local function CalculateSteering(pos, dir)
    local lookAhead = CONFIG.SteerLookAhead
    local avoidR = CONFIG.SteerAvoidRadius
    local pushForce = CONFIG.SteerPushForce

    -- 前视位置
    local aheadX = pos.x + dir.x * lookAhead
    local aheadZ = pos.z + dir.z * lookAhead
    local pushX, pushZ = 0, 0

    -- 检测塔
    for _, t in ipairs(GS.towers) do
        if t.node then
            local tp = t.node.position
            local ddx = aheadX - tp.x
            local ddz = aheadZ - tp.z
            local dist = math.sqrt(ddx * ddx + ddz * ddz)
            if dist < avoidR then
                local factor = pushForce * (1.0 - dist / avoidR)
                if dist > 0.01 then
                    pushX = pushX + (ddx / dist) * factor
                    pushZ = pushZ + (ddz / dist) * factor
                else
                    pushX = pushX + (math.random() - 0.5) * factor
                    pushZ = pushZ + (math.random() - 0.5) * factor
                end
            end
        end
    end

    -- 检测场景物件
    for _, obj in ipairs(GS.terrainObjects) do
        if obj.node then
            local op = obj.node.position
            local ddx = aheadX - op.x
            local ddz = aheadZ - op.z
            local dist = math.sqrt(ddx * ddx + ddz * ddz)
            if dist < avoidR then
                local factor = pushForce * (1.0 - dist / avoidR)
                if dist > 0.01 then
                    pushX = pushX + (ddx / dist) * factor
                    pushZ = pushZ + (ddz / dist) * factor
                else
                    pushX = pushX + (math.random() - 0.5) * factor
                    pushZ = pushZ + (math.random() - 0.5) * factor
                end
            end
        end
    end

    return pushX, pushZ
end

-- ============================================================================
-- 怪物移动 (直线冲向中心 + 转向避障)
-- ============================================================================

function M.UpdateMonsters(dt)
    local i = 1
    while i <= #GS.monsters do
        local m = GS.monsters[i]
        if not m.node then
            table.remove(GS.monsters, i)
        else
            local pos = m.node.position
            local speed = StatusEffect.GetEffectiveSpeed(m)
            local reachedEnd = false

            -- 计算朝向能源塔中心的方向
            local toDx = 0 - pos.x
            local toDz = 0 - pos.z
            local toDist = math.sqrt(toDx * toDx + toDz * toDz)

            if toDist < 1.0 then
                reachedEnd = true
            else
                -- 归一化期望方向
                local desiredX = toDx / toDist
                local desiredZ = toDz / toDist

                -- 转向避障
                local pushX, pushZ = CalculateSteering(pos, m.dir)

                -- 混合: 期望方向 + 推力
                local finalX = desiredX + pushX
                local finalZ = desiredZ + pushZ
                local finalLen = math.sqrt(finalX * finalX + finalZ * finalZ)
                if finalLen > 0.01 then
                    finalX = finalX / finalLen
                    finalZ = finalZ / finalLen
                else
                    finalX = desiredX
                    finalZ = desiredZ
                end

                -- 平滑转向 (lerp)
                local turnRate = 5.0 * dt
                m.dir = Vector3(
                    m.dir.x + (finalX - m.dir.x) * turnRate,
                    0,
                    m.dir.z + (finalZ - m.dir.z) * turnRate
                )
                -- 重新归一化
                local dl = math.sqrt(m.dir.x * m.dir.x + m.dir.z * m.dir.z)
                if dl > 0.01 then
                    m.dir = Vector3(m.dir.x / dl, 0, m.dir.z / dl)
                end

                -- 移动
                pos.x = pos.x + m.dir.x * speed * dt
                pos.z = pos.z + m.dir.z * speed * dt
                m.node.position = pos

                -- 更新朝向
                local moveYaw = math.deg(math.atan(m.dir.x, m.dir.z))
                m.node.rotation = Quaternion(moveYaw, Vector3.UP)
            end

            -- === Boss 特殊机制 ===
            if m.isBoss then
                M.UpdateBossMechanics(m, dt)
            end

            -- 更新血条
            Utils.UpdateHealthBar(m)

            -- 受伤泛红帧更新
            if m.flashTimer > 0 and m.bodyMat then
                m.flashTimer = m.flashTimer - dt
                local t = math.max(0, m.flashTimer / 0.30)  -- 1.0 → 0.0 衰减
                m.bodyMat:SetShaderParameter("MatEmissiveColor", Variant(Color(
                    m.baseEmitR + (4.5 - m.baseEmitR) * t,
                    m.baseEmitG * (1.0 - t * 0.95),
                    m.baseEmitB * (1.0 - t * 0.95)
                )))
                if m.flashTimer <= 0 then
                    -- 归零时恢复基础颜色
                    m.bodyMat:SetShaderParameter("MatEmissiveColor", Variant(Color(m.baseEmitR, m.baseEmitG, m.baseEmitB)))
                end
            end

            -- 到达终点: 伤害能源塔
            if reachedEnd then
                EnergyTower.DamageEnergyTower(CONFIG.MonsterDmgToTower)
                M.DestroyMonster(m)
                table.remove(GS.monsters, i)
            else
                i = i + 1
            end
        end
    end
end

-- ============================================================================
-- Boss 特殊机制
-- ============================================================================

--- 更新 Boss 专属机制 (每帧调用)
function M.UpdateBossMechanics(m, dt)
    -- === 裂山巨像: 周期护甲 buff ===
    if m.armorCycleInterval > 0 then
        if m.armorBuffTimer > 0 then
            -- buff 激活中
            m.armorBuffTimer = m.armorBuffTimer - dt
            if m.armorBuffTimer <= 0 then
                -- buff 结束，恢复基础护甲
                m.armorRatio = m.baseArmorRatio
                m.armorBuffTimer = 0
                -- 恢复颜色
                local model = m.node:GetComponent("StaticModel")
                if model then
                    local mat = model:GetMaterial(0)
                    if mat then
                        local typeDef = GetTypeDef(m.type)
                        mat:SetShaderParameter("MatEmissiveColor", Variant(Color(
                            typeDef.emissive.r, typeDef.emissive.g, typeDef.emissive.b)))
                    end
                end
            end
        else
            -- 等待下次触发
            m.armorCycleTimer = m.armorCycleTimer + dt
            if m.armorCycleTimer >= m.armorCycleInterval then
                m.armorCycleTimer = 0
                m.armorBuffTimer = m.armorBuffDuration
                -- 激活护甲 buff
                m.armorRatio = math.min(0.9, m.baseArmorRatio + m.armorBuffValue)
                -- 视觉: 发光变亮
                local model = m.node:GetComponent("StaticModel")
                if model then
                    local mat = model:GetMaterial(0)
                    if mat then
                        mat:SetShaderParameter("MatEmissiveColor",
                            Variant(Color(1.0, 0.6, 0.2)))
                    end
                end
                print(string.format("[Boss] 裂山巨像 护甲强化! Armor: %.0f%% (%.0fs)",
                    m.armorRatio * 100, m.armorBuffDuration))
            end
        end
    end

    -- === 吞线母体: 周期功率吸取 ===
    if m.drainInterval > 0 then
        if m.drainActive then
            -- 吸取中
            m.drainActiveTimer = m.drainActiveTimer - dt
            if m.drainActiveTimer <= 0 then
                -- 吸取结束
                m.drainActive = false
                m.drainActiveTimer = 0
                -- 恢复颜色
                local model = m.node:GetComponent("StaticModel")
                if model then
                    local mat = model:GetMaterial(0)
                    if mat then
                        local typeDef = GetTypeDef(m.type)
                        mat:SetShaderParameter("MatEmissiveColor", Variant(Color(
                            typeDef.emissive.r, typeDef.emissive.g, typeDef.emissive.b)))
                    end
                end
                -- 恢复功率 (重新计算供能)
                EnergyTower.RecalculateEnergy()
                EnergyTower.RebuildEnergyLines()
                print("[Boss] 吞线母体 功率吸取结束，供能恢复")
            end
        else
            -- 等待下次触发
            m.drainTimer = m.drainTimer + dt
            if m.drainTimer >= m.drainInterval then
                m.drainTimer = 0
                m.drainActive = true
                m.drainActiveTimer = m.drainDuration
                -- 视觉: 紫色发光
                local model = m.node:GetComponent("StaticModel")
                if model then
                    local mat = model:GetMaterial(0)
                    if mat then
                        mat:SetShaderParameter("MatEmissiveColor",
                            Variant(Color(0.8, 0.2, 1.5)))
                    end
                end
                print(string.format("[Boss] 吞线母体 功率吸取! 吸取 %.0f%% 功率 (%.0fs)",
                    m.drainRatio * 100, m.drainDuration))
            end
        end
    end
end

-- ============================================================================
-- 伤害与死亡
-- ============================================================================

--- 对怪物造成伤害
--- @param m table 怪物实例
--- @param dmg number 伤害值
--- @param isEnergyDmg boolean|nil 是否为能源伤害 (绕过物理护甲)
function M.DamageMonster(m, dmg, isEnergyDmg, skipText)
    if not m.node or m.hp <= 0 then return end

    -- 护盾先吸收 (所有伤害类型)
    if m.shield > 0 then
        if dmg <= m.shield then
            m.shield = m.shield - dmg
            if not skipText then
                Utils.SpawnDmgText(m.node.position, dmg)
            end
            if m.shieldNode and m.shield <= 0 then
                m.shieldNode:Remove()
                m.shieldNode = nil
            end
            return
        else
            dmg = dmg - m.shield
            m.shield = 0
            if m.shieldNode then
                m.shieldNode:Remove()
                m.shieldNode = nil
            end
        end
    end

    -- 物理护甲减伤 (仅对非能源伤害)
    if not isEnergyDmg and m.armorRatio > 0 then
        dmg = dmg * (1.0 - m.armorRatio)
    end

    dmg = math.max(1, math.floor(dmg + 0.5))

    m.hp = m.hp - dmg
    -- 受伤泛红
    m.flashTimer = 0.30
    if not skipText then
        Utils.SpawnDmgText(m.node.position, dmg)
    end
    if m.hp <= 0 then
        M.KillMonster(m)
    end
end

function M.KillMonster(m)
    local pos = m.node.position
    GS.monstersKilled = GS.monstersKilled + 1

    if m.goldDrop > 0 then
        -- 金矿炼化: 击杀来源塔有 artGoldDropBonus 则增加掉落
        local goldAmt = m.goldDrop
        if m.lastHitTower and (m.lastHitTower.artGoldDropBonus or 0) > 0 then
            goldAmt = math.floor(goldAmt * (1.0 + m.lastHitTower.artGoldDropBonus) + 0.5)
        end
        Utils.SpawnLoot(pos, "gold", goldAmt)
    end
    if m.energyDrop > 0 then
        Utils.SpawnLoot(Vector3(pos.x + 0.3, pos.y, pos.z + 0.3), "energy", m.energyDrop)
    end
    if m.materialDrop > 0 then
        Utils.SpawnLoot(Vector3(pos.x - 0.3, pos.y, pos.z - 0.3), "material", m.materialDrop)
    end

    M.DestroyMonster(m)
end

function M.DestroyMonster(m)
    if m.shieldNode then m.shieldNode:Remove(); m.shieldNode = nil end
    if m.hpBg then m.hpBg:Remove(); m.hpBg = nil end
    if m.node then m.node:Remove(); m.node = nil end
    m.hp = 0
end

return M
