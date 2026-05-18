-- ============================================================================
-- Monster.lua — 怪物类型 / 路径寻路 / HP波次缩放 / 精英词缀 / 伤害 / 死亡
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS
local Utils = require("Utils")
local EnergyTower = require("EnergyTower")
local StatusEffect = require("StatusEffect")

local M = {}

-- ============================================================================
-- UFO 模型列表
-- ============================================================================
local UFO_MODELS = { "enemy-ufo-a", "enemy-ufo-b", "enemy-ufo-c", "enemy-ufo-d" }

-- HP 每波增长系数 (base_hp × HP_GROWTH^(wave-1))
local HP_GROWTH = 1.13

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
--- @param opts table|nil { path = {{x,z},...}, waveNumber = int, eliteAffixes = {"thick_armor",...} }
function M.SpawnMonster(monsterType, opts)
    monsterType = monsterType or "walker"
    opts = opts or {}
    local waveNumber = opts.waveNumber or 1
    local eliteAffixes = opts.eliteAffixes or {}
    local path = opts.path or nil

    local typeDef = GetTypeDef(monsterType)

    -- === 基础属性 ===
    local hp = typeDef.base_hp
    local speed = typeDef.base_speed
    local armorRatio = typeDef.armor_ratio or 0
    local shieldHp = typeDef.shield_hp or 0

    -- === HP 波次缩放 (Boss 也缩放，但起始已很高) ===
    hp = hp * math.pow(HP_GROWTH, waveNumber - 1)

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
        shieldHp = shieldHp * math.pow(HP_GROWTH, waveNumber - 1)
    end

    hp = math.floor(hp + 0.5)
    shieldHp = math.floor(shieldHp + 0.5)

    -- === 出生位置 ===
    local sx, sz
    if path and #path >= 1 then
        sx = path[1].x
        sz = path[1].z
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
    if typeDef.is_boss then s = s * 1.0 end -- Boss 尺寸已在 typeDef 中定义

    node.position = Vector3(sx, 0, sz)
    node.scale = Vector3(s, s, s)

    -- 朝向下一个路径点
    if path and #path >= 2 then
        local dx = path[2].x - path[1].x
        local dz = path[2].z - path[1].z
        local yaw = math.deg(math.atan(dx, dz))
        node.rotation = Quaternion(yaw, Vector3.UP)
    end

    -- === 模型 ===
    local ufoName = UFO_MODELS[math.random(1, #UFO_MODELS)]
    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Meshes/TD/" .. ufoName .. ".mdl"))

    -- 材质 (精英发光增强)
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    local emitMult = isElite and 2.5 or 1.0
    mat:SetShaderParameter("MatDiffColor", Variant(typeDef.color))
    mat:SetShaderParameter("MatEmissiveColor", Variant(Color(
        typeDef.emissive.r * emitMult,
        typeDef.emissive.g * emitMult,
        typeDef.emissive.b * emitMult
    )))
    mat:SetShaderParameter("Metallic", Variant(0.0))
    mat:SetShaderParameter("Roughness", Variant(1.0))
    model:SetMaterial(mat)
    model.castShadows = true

    -- 移动方向 (初始)
    local dir
    if path and #path >= 2 then
        local dx = path[2].x - sx
        local dz = path[2].z - sz
        local len = math.sqrt(dx * dx + dz * dz)
        dir = len > 0.01 and Vector3(dx / len, 0, dz / len) or Vector3(0, 0, 1)
    else
        local dx = 0 - sx
        local dz = 0 - sz
        local len = math.sqrt(dx * dx + dz * dz)
        dir = len > 0.01 and Vector3(dx / len, 0, dz / len) or Vector3(0, 0, 1)
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
        -- 路径
        path = path,
        pathIndex = 1, -- 已到达 path[1]，正在前往 path[2]
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
-- 怪物移动 (路径点寻路)
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

            if m.path and #m.path >= 2 then
                -- === 路径点寻路 ===
                local targetIdx = m.pathIndex + 1
                if targetIdx > #m.path then
                    -- 已到达终点 (能源塔)
                    reachedEnd = true
                else
                    local target = m.path[targetIdx]
                    local dx = target.x - pos.x
                    local dz = target.z - pos.z
                    local dist = math.sqrt(dx * dx + dz * dz)

                    if dist < 0.3 then
                        -- 到达路径点，前进到下一个
                        m.pathIndex = targetIdx
                        -- 更新朝向
                        local nextIdx = m.pathIndex + 1
                        if nextIdx <= #m.path then
                            local nx = m.path[nextIdx].x - pos.x
                            local nz = m.path[nextIdx].z - pos.z
                            local nlen = math.sqrt(nx * nx + nz * nz)
                            if nlen > 0.01 then
                                m.dir = Vector3(nx / nlen, 0, nz / nlen)
                                local yaw = math.deg(math.atan(nx, nz))
                                m.node.rotation = Quaternion(yaw, Vector3.UP)
                            end
                        else
                            reachedEnd = true
                        end
                    else
                        -- 向当前目标移动
                        m.dir = Vector3(dx / dist, 0, dz / dist)
                        pos.x = pos.x + m.dir.x * speed * dt
                        pos.z = pos.z + m.dir.z * speed * dt
                        m.node.position = pos
                    end
                end
            else
                -- === 无路径: 直线冲向中心 (兜底) ===
                pos.x = pos.x + m.dir.x * speed * dt
                pos.z = pos.z + m.dir.z * speed * dt
                m.node.position = pos

                local distToCenter = math.sqrt(pos.x * pos.x + pos.z * pos.z)
                if distToCenter < 1.0 then
                    reachedEnd = true
                end
            end

            -- === Boss 特殊机制 ===
            if m.isBoss then
                M.UpdateBossMechanics(m, dt)
            end

            -- 更新血条
            Utils.UpdateHealthBar(m)

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
function M.DamageMonster(m, dmg, isEnergyDmg)
    if not m.node or m.hp <= 0 then return end

    -- 护盾先吸收 (所有伤害类型)
    if m.shield > 0 then
        if dmg <= m.shield then
            m.shield = m.shield - dmg
            Utils.SpawnDmgText(m.node.position, dmg)
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
    Utils.SpawnDmgText(m.node.position, dmg)
    if m.hp <= 0 then
        M.KillMonster(m)
    end
end

function M.KillMonster(m)
    local pos = m.node.position
    GS.monstersKilled = GS.monstersKilled + 1

    if m.goldDrop > 0 then
        Utils.SpawnLoot(pos, "gold", m.goldDrop)
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
