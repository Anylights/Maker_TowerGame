-- ============================================================================
-- Monster.lua — 怪物生成 / 移动 / 伤害 / 死亡
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS
local Utils = require("Utils")
local EnergyTower = require("EnergyTower")

local M = {}

-- ============================================================================
-- 怪物UFO模型列表
-- ============================================================================
local UFO_MODELS = { "enemy-ufo-a", "enemy-ufo-b", "enemy-ufo-c", "enemy-ufo-d" }

-- ============================================================================
-- 怪物类型定义
-- ============================================================================
M.TYPES = {
    zombie = {
        name = "行尸",
        hp = 80,
        speed = 1.8,
        size = 0.38,
        color = Color(0.85, 0.22, 0.18, 1),    -- 红色
        emissive = Color(0.35, 0.08, 0.05),
        goldDrop = 15,
        energyDrop = 5,
    },
    swarm = {
        name = "群虫",
        hp = 30,
        speed = 2.2,
        size = 0.23,                             -- 0.6x
        color = Color(0.25, 0.60, 0.20, 1),     -- 暗绿
        emissive = Color(0.08, 0.25, 0.05),
        goldDrop = 6,
        energyDrop = 2,
    },
    armored = {
        name = "甲壳兽",
        hp = 200,
        speed = 1.2,
        size = 0.49,                             -- 1.3x
        color = Color(0.50, 0.35, 0.18, 1),     -- 深棕
        emissive = Color(0.20, 0.12, 0.05),
        goldDrop = 30,
        energyDrop = 10,
        armor = 5,                               -- 每次受击减伤
    },
    sprinter = {
        name = "疾行者",
        hp = 50,
        speed = 3.6,                             -- 2x
        size = 0.30,                             -- 0.8x
        color = Color(0.20, 0.65, 0.90, 1),     -- 亮蓝
        emissive = Color(0.10, 0.30, 0.50),
        goldDrop = 20,
        energyDrop = 8,
    },
    shielded = {
        name = "护盾怪",
        hp = 100,
        speed = 1.6,
        size = 0.40,
        color = Color(0.65, 0.25, 0.80, 1),     -- 紫色
        emissive = Color(0.30, 0.10, 0.40),
        goldDrop = 25,
        energyDrop = 12,
        shield = 60,                             -- 能量盾
    },
    energyEater = {
        name = "吞能者",
        hp = 120,
        speed = 1.5,
        size = 0.42,                             -- 1.1x
        color = Color(0.75, 0.60, 0.15, 1),     -- 暗金
        emissive = Color(0.35, 0.25, 0.05),
        goldDrop = 35,
        energyDrop = 15,
    },
}

-- ============================================================================
-- 生成怪物
-- ============================================================================

function M.SpawnMonster(monsterType)
    monsterType = monsterType or "zombie"
    local typeDef = M.TYPES[monsterType]
    if not typeDef then typeDef = M.TYPES.zombie end

    local node = GS.scene:CreateChild("Monster")
    local angle = math.random() * math.pi * 2
    local sd = CONFIG.SpawnDistance
    local sx = math.cos(angle) * sd
    local sz = math.sin(angle) * sd
    local s = typeDef.size

    node.position = Vector3(sx, 0, sz)
    node.scale = Vector3(s, s, s)

    -- 随机选择UFO模型
    local ufoName = UFO_MODELS[math.random(1, #UFO_MODELS)]
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Meshes/TD/" .. ufoName .. ".mdl"))

    -- 按类型着色（独立材质）
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(typeDef.color))
    mat:SetShaderParameter("MatEmissiveColor", Variant(typeDef.emissive))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(1.0))
    model:SetMaterial(mat)
    model.castShadows = true

    -- 朝向中心
    local dir = Vector3(0, 0, 0) - Vector3(sx, 0, sz)
    local len = dir:Length()
    if len > 0.01 then dir = dir / len else dir = Vector3(0, 0, 1) end

    -- 血条
    local hpBg, hpFill, fillMat = Utils.CreateHealthBar(node)

    -- 护盾怪额外创建护盾视觉
    ---@type Node
    local shieldNode = nil
    if typeDef.shield and typeDef.shield > 0 then
        shieldNode = node:CreateChild("Shield")
        local shieldScale = 1.8  -- 外圈
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

    local monster = {
        node = node,
        hp = typeDef.hp,
        maxHp = typeDef.hp,
        dir = dir,
        hpBg = hpBg,
        hpFill = hpFill,
        fillMat = fillMat,
        type = monsterType,
        speed = typeDef.speed,
        armor = typeDef.armor or 0,
        shield = typeDef.shield or 0,
        maxShield = typeDef.shield or 0,
        shieldNode = shieldNode,
        goldDrop = typeDef.goldDrop,
        energyDrop = typeDef.energyDrop,
    }
    table.insert(GS.monsters, monster)
end

-- ============================================================================
-- 怪物移动
-- ============================================================================

function M.UpdateMonsters(dt)
    local i = 1
    while i <= #GS.monsters do
        local m = GS.monsters[i]
        if not m.node then
            table.remove(GS.monsters, i)
        else
            local pos = m.node.position
            local speed = m.speed
            pos.x = pos.x + m.dir.x * speed * dt
            pos.z = pos.z + m.dir.z * speed * dt
            m.node.position = pos

            Utils.UpdateHealthBar(m)

            local distToCenter = math.sqrt(pos.x * pos.x + pos.z * pos.z)
            if distToCenter < 1.0 then
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
-- 伤害与死亡
-- ============================================================================

function M.DamageMonster(m, dmg)
    if not m.node or m.hp <= 0 then return end

    -- 护盾先吸收
    if m.shield > 0 then
        if dmg <= m.shield then
            m.shield = m.shield - dmg
            Utils.SpawnDmgText(m.node.position, dmg)
            -- 更新护盾视觉
            if m.shieldNode then
                local ratio = m.shield / m.maxShield
                if ratio <= 0 then
                    m.shieldNode:Remove()
                    m.shieldNode = nil
                end
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

    -- 护甲减伤
    if m.armor > 0 then
        dmg = math.max(1, dmg - m.armor)
    end

    m.hp = m.hp - dmg
    Utils.SpawnDmgText(m.node.position, dmg)
    if m.hp <= 0 then
        M.KillMonster(m)
    end
end

function M.KillMonster(m)
    local pos = m.node.position
    GS.monstersKilled = GS.monstersKilled + 1

    Utils.SpawnLoot(pos, "gold")
    if m.energyDrop and m.energyDrop > 0 then
        Utils.SpawnLoot(Vector3(pos.x + 0.3, pos.y, pos.z + 0.3), "energy")
    end

    M.DestroyMonster(m)
end

function M.DestroyMonster(m)
    if m.shieldNode then m.shieldNode:Remove() end
    if m.hpBg then m.hpBg:Remove() end
    if m.node then m.node:Remove() end
end

return M
