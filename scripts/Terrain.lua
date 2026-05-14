-- ============================================================================
-- Terrain.lua — 场景物件系统 (岩石/矿脉/遗迹/水晶/封印山体)
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS
local Utils = require("Utils")

local M = {}

-- ============================================================================
-- 物件类型定义
-- ============================================================================

M.TYPES = {
    rock = {
        name = "岩石",
        hp = 80,
        size = 0.55,
        model = "Models/Box.mdl",
        color = Color(0.55, 0.50, 0.42, 1),
        emissive = Color(0.10, 0.08, 0.06),
        drop_gold = 0,
        drop_material = 8,
        drop_energy = 0,
        buff_type = nil,
    },
    ore = {
        name = "矿脉",
        hp = 120,
        size = 0.45,
        model = "Models/Box.mdl",
        color = Color(0.70, 0.55, 0.25, 1),
        emissive = Color(0.25, 0.18, 0.05),
        drop_gold = 15,
        drop_material = 20,
        drop_energy = 0,
        buff_type = "material_bonus",  -- 邻接塔 +20% 材料
        buff_value = 0.20,
    },
    ruins = {
        name = "远古遗迹",
        hp = 100,
        size = 0.50,
        model = "Models/Cylinder.mdl",
        color = Color(0.40, 0.50, 0.55, 1),
        emissive = Color(0.12, 0.18, 0.22),
        drop_gold = 10,
        drop_material = 10,
        drop_energy = 5,
        buff_type = "trigger_bonus",   -- 邻接塔 +15% 触发率 (预留)
        buff_value = 0.15,
    },
    crystal = {
        name = "能源水晶",
        hp = 60,
        size = 0.40,
        model = "Models/Cone.mdl",
        color = Color(0.30, 0.60, 0.95, 1),
        emissive = Color(0.20, 0.40, 0.80),
        drop_gold = 5,
        drop_material = 5,
        drop_energy = 15,
        buff_type = "power_bonus",     -- 邻接塔 +10% 功率系数
        buff_value = 0.10,
    },
    sealed_mountain = {
        name = "封印山体",
        hp = 300,
        size = 0.70,
        model = "Models/Box.mdl",
        color = Color(0.35, 0.30, 0.28, 1),
        emissive = Color(0.15, 0.10, 0.08),
        drop_gold = 50,
        drop_material = 40,
        drop_energy = 20,
        buff_type = nil,
    },
}

-- ============================================================================
-- 物件布局 (预定义位置, 在能量范围内的格子上)
-- ============================================================================

-- 物件列表: { type, gx, gz }
local TERRAIN_LAYOUT = {
    -- 北路附近
    { type = "rock",    gx = -3, gz = -3 },
    { type = "ore",     gx = -5, gz = -2 },
    { type = "crystal", gx = -2, gz = -5 },
    -- 南路附近
    { type = "rock",    gx = -4, gz = 3 },
    { type = "ruins",   gx = -3, gz = 5 },
    { type = "crystal", gx = -5, gz = 4 },
    -- 能源塔周围
    { type = "ore",     gx = 3,  gz = -2 },
    { type = "ruins",   gx = 2,  gz = 3 },
    -- 外围
    { type = "sealed_mountain", gx = -6, gz = 0 },
    { type = "rock",    gx = 4,  gz = -4 },
    { type = "crystal", gx = 5,  gz = 2 },
}

-- ============================================================================
-- 初始化物件
-- ============================================================================

function M.Init()
    GS.terrainObjects = {}

    for _, layout in ipairs(TERRAIN_LAYOUT) do
        local typeDef = M.TYPES[layout.type]
        if not typeDef then goto continue end

        local gx, gz = layout.gx, layout.gz
        -- 不能放在能源塔位置
        if gx == 0 and gz == 0 then goto continue end

        local node = GS.scene:CreateChild("Terrain_" .. layout.type)
        local s = typeDef.size
        node.position = Vector3(gx, s * 0.5, gz)
        node.scale = Vector3(s, s, s)

        local model = node:CreateComponent("StaticModel")
        model:SetModel(cache:GetResource("Model", typeDef.model))

        local mat = Material:new()
        mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        mat:SetShaderParameter("MatDiffColor", Variant(typeDef.color))
        mat:SetShaderParameter("MatEmissiveColor", Variant(typeDef.emissive))
        mat:SetShaderParameter("Metallic", Variant(0.0))
        mat:SetShaderParameter("Roughness", Variant(0.8))
        model:SetMaterial(mat)
        model.castShadows = true

        -- buff 指示器 (发光环)
        if typeDef.buff_type then
            local ringNode = node:CreateChild("BuffRing")
            ringNode.position = Vector3(0, -0.3, 0)
            local ringScale = 2.5 / s
            ringNode.scale = Vector3(ringScale, 0.05 / s, ringScale)
            local ringModel = ringNode:CreateComponent("StaticModel")
            ringModel:SetModel(cache:GetResource("Model", "Models/Cylinder.mdl"))
            local ringMat = Material:new()
            ringMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
            ringMat:SetShaderParameter("MatDiffColor", Variant(Color(
                typeDef.emissive.r, typeDef.emissive.g, typeDef.emissive.b, 0.25)))
            ringMat:SetShaderParameter("MatEmissiveColor", Variant(Color(
                typeDef.emissive.r * 2, typeDef.emissive.g * 2, typeDef.emissive.b * 2)))
            ringMat:SetShaderParameter("Metallic", Variant(0.0))
            ringMat:SetShaderParameter("Roughness", Variant(1.0))
            ringModel:SetMaterial(ringMat)
            ringModel.castShadows = false
        end

        -- 血条
        local hpBg, hpFill, fillMat = Utils.CreateHealthBar(node)

        local obj = {
            node = node,
            type = layout.type,
            gx = gx,
            gz = gz,
            hp = typeDef.hp,
            maxHp = typeDef.hp,
            hpBg = hpBg,
            hpFill = hpFill,
            fillMat = fillMat,
            buffType = typeDef.buff_type,
            buffValue = typeDef.buff_value or 0,
        }
        table.insert(GS.terrainObjects, obj)

        ::continue::
    end

    print(string.format("[Terrain] Initialized %d terrain objects", #GS.terrainObjects))
end

-- ============================================================================
-- 查询: 某格子是否有物件
-- ============================================================================

function M.GetObjectAt(gx, gz)
    if not GS.terrainObjects then return nil end
    for idx, obj in ipairs(GS.terrainObjects) do
        if obj.gx == gx and obj.gz == gz then
            return obj, idx
        end
    end
    return nil
end

-- ============================================================================
-- 伤害物件 (塔攻击可指向物件)
-- ============================================================================

function M.DamageObject(obj, dmg)
    if not obj or not obj.node or obj.hp <= 0 then return end

    obj.hp = obj.hp - dmg
    Utils.SpawnDmgText(obj.node.position, dmg)

    -- 更新血条
    if obj.hpFill and obj.fillMat then
        local ratio = math.max(0, obj.hp / obj.maxHp)
        local r, g
        if ratio > 0.5 then
            r = (1.0 - ratio) * 2.0
            g = 0.9
        else
            r = 0.9
            g = ratio * 2.0
        end
        obj.fillMat:SetShaderParameter("MatDiffColor", Variant(Color(r, g, 0.1, 1.0)))
        obj.fillMat:SetShaderParameter("MatEmissiveColor", Variant(Color(r * 0.3, g * 0.3, 0.02)))

        local fullW = CONFIG.HPBarW
        local fillW = fullW * ratio
        obj.hpFill.scale = Vector3(fillW, CONFIG.HPBarH * 0.75, 0.015)
        local offset = (fullW - fillW) * 0.5
        obj.hpFill.position = Vector3(-offset, 0, 0.005)
    end

    if obj.hp <= 0 then
        M.DestroyObject(obj)
    end
end

-- ============================================================================
-- 物件被破坏 → 掉落资源
-- ============================================================================

function M.DestroyObject(obj)
    if not obj or not obj.node then return end

    local typeDef = M.TYPES[obj.type]
    local pos = obj.node.position

    -- 掉落
    if typeDef then
        if typeDef.drop_gold > 0 then
            Utils.SpawnLoot(pos, "gold", typeDef.drop_gold)
        end
        if typeDef.drop_material > 0 then
            Utils.SpawnLoot(Vector3(pos.x + 0.3, pos.y, pos.z), "material", typeDef.drop_material)
        end
        if typeDef.drop_energy > 0 then
            Utils.SpawnLoot(Vector3(pos.x - 0.3, pos.y, pos.z), "energy", typeDef.drop_energy)
        end
    end

    -- 移除节点
    if obj.hpBg then obj.hpBg:Remove() end
    obj.node:Remove()

    -- 从列表移除
    if GS.terrainObjects then
        for i = #GS.terrainObjects, 1, -1 do
            if GS.terrainObjects[i] == obj then
                table.remove(GS.terrainObjects, i)
                break
            end
        end
    end

    print(string.format("[Terrain] %s at (%d,%d) destroyed!", typeDef and typeDef.name or "?", obj.gx, obj.gz))
end

-- ============================================================================
-- 每帧更新 (血条面向相机)
-- ============================================================================

function M.Update(dt)
    if not GS.terrainObjects or not GS.cameraNode then return end
    local camRot = GS.cameraNode.rotation
    for _, obj in ipairs(GS.terrainObjects) do
        if obj.hpBg and obj.node and obj.hp > 0 then
            local pos = obj.node.worldPosition
            local barY = pos.y + CONFIG.HPBarOffY + 0.2
            obj.hpBg.position = Vector3(pos.x, barY, pos.z)
            obj.hpBg.rotation = camRot
        end
    end
end

-- ============================================================================
-- 邻接 Buff 查询 (某格子周围的 buff 加成)
-- ============================================================================

--- 获取指定格子的所有邻接 buff
--- @param gx number 格子 x
--- @param gz number 格子 z
--- @return table { material_bonus=0, trigger_bonus=0, power_bonus=0 }
function M.GetAdjacentBuffs(gx, gz)
    local buffs = { material_bonus = 0, trigger_bonus = 0, power_bonus = 0 }
    if not GS.terrainObjects then return buffs end

    for _, obj in ipairs(GS.terrainObjects) do
        if obj.hp > 0 and obj.buffType then
            local dx = math.abs(obj.gx - gx)
            local dz = math.abs(obj.gz - gz)
            -- 邻接 = 曼哈顿距离 <= 1 (上下左右 + 自身格不算)
            if dx + dz == 1 then
                buffs[obj.buffType] = (buffs[obj.buffType] or 0) + obj.buffValue
            end
        end
    end

    return buffs
end

return M
