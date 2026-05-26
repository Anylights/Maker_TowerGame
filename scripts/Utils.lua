-- ============================================================================
-- Utils.lua — 材质工厂 / 血条 / 浮动伤害数字 / 掉落物
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local MOEBIUS = Cfg.MOEBIUS
local GS = Cfg.GS

local M = {}

-- ============================================================================
-- 共享材质缓存
-- ============================================================================
local monsterMat_ = nil
local projectileMat_ = nil
local hpBgMat_ = nil
local lootGoldMat_ = nil
local lootEnergyMat_ = nil
local lootMaterialMat_ = nil

function M.GetMonsterMaterial()
    if monsterMat_ then return monsterMat_ end
    monsterMat_ = Material:new()
    monsterMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    monsterMat_:SetShaderParameter("MatDiffColor", Variant(MOEBIUS.MonsterDiff))
    monsterMat_:SetShaderParameter("MatEmissiveColor", Variant(MOEBIUS.MonsterEmit))
    monsterMat_:SetShaderParameter("Metallic", Variant(0.0))
    monsterMat_:SetShaderParameter("Roughness", Variant(1.0))
    return monsterMat_
end

function M.GetProjectileMaterial()
    if projectileMat_ then return projectileMat_ end
    projectileMat_ = Material:new()
    projectileMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    projectileMat_:SetShaderParameter("MatDiffColor", Variant(MOEBIUS.ProjectileDiff))
    projectileMat_:SetShaderParameter("MatEmissiveColor", Variant(MOEBIUS.ProjectileEmit))
    projectileMat_:SetShaderParameter("Metallic", Variant(0.0))
    projectileMat_:SetShaderParameter("Roughness", Variant(1.0))
    return projectileMat_
end

function M.GetHPBgMaterial()
    if hpBgMat_ then return hpBgMat_ end
    hpBgMat_ = Material:new()
    hpBgMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/NoTextureUnlit.xml"))
    hpBgMat_:SetShaderParameter("MatDiffColor", Variant(Color(0.08, 0.08, 0.08, 1.0)))
    return hpBgMat_
end

function M.GetLootGoldMaterial()
    if lootGoldMat_ then return lootGoldMat_ end
    lootGoldMat_ = Material:new()
    lootGoldMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    lootGoldMat_:SetShaderParameter("MatDiffColor", Variant(MOEBIUS.LootGoldDiff))
    lootGoldMat_:SetShaderParameter("MatEmissiveColor", Variant(MOEBIUS.LootGoldEmit))
    lootGoldMat_:SetShaderParameter("Metallic", Variant(0.0))
    lootGoldMat_:SetShaderParameter("Roughness", Variant(1.0))
    return lootGoldMat_
end

function M.GetLootEnergyMaterial()
    if lootEnergyMat_ then return lootEnergyMat_ end
    lootEnergyMat_ = Material:new()
    lootEnergyMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    lootEnergyMat_:SetShaderParameter("MatDiffColor", Variant(MOEBIUS.LootEnergyDiff))
    lootEnergyMat_:SetShaderParameter("MatEmissiveColor", Variant(MOEBIUS.LootEnergyEmit))
    lootEnergyMat_:SetShaderParameter("Metallic", Variant(0.0))
    lootEnergyMat_:SetShaderParameter("Roughness", Variant(1.0))
    return lootEnergyMat_
end

function M.GetLootMaterialMaterial()
    if lootMaterialMat_ then return lootMaterialMat_ end
    lootMaterialMat_ = Material:new()
    lootMaterialMat_:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    lootMaterialMat_:SetShaderParameter("MatDiffColor", Variant(MOEBIUS.LootMaterialDiff))
    lootMaterialMat_:SetShaderParameter("MatEmissiveColor", Variant(MOEBIUS.LootMaterialEmit))
    lootMaterialMat_:SetShaderParameter("Metallic", Variant(0.0))
    lootMaterialMat_:SetShaderParameter("Roughness", Variant(1.0))
    return lootMaterialMat_
end

-- ============================================================================
-- 血条
-- ============================================================================

function M.CreateHealthBar(parentNode)
    local barRoot = GS.scene:CreateChild("HPBar")
    local bg = barRoot:CreateChild("HPBg")
    bg.scale = Vector3(CONFIG.HPBarW, CONFIG.HPBarH, 0.01)
    local bgModel = bg:CreateComponent("StaticModel")
    bgModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))
    bgModel:SetMaterial(M.GetHPBgMaterial())

    local fill = barRoot:CreateChild("HPFill")
    fill.scale = Vector3(CONFIG.HPBarW, CONFIG.HPBarH * 0.7, 0.015)
    local fillModel = fill:CreateComponent("StaticModel")
    fillModel:SetModel(cache:GetResource("Model", "Models/Box.mdl"))

    local fillMat = Material:new()
    fillMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    fillMat:SetShaderParameter("MatDiffColor", Variant(Color(0.882, 0.224, 0.224, 1.0)))
    fillMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.6, 0.0, 0.0)))
    fillMat:SetShaderParameter("Metallic", Variant(0.0))
    fillMat:SetShaderParameter("Roughness", Variant(1.0))
    fillModel:SetMaterial(fillMat)

    return barRoot, fill, fillMat
end

function M.UpdateHealthBar(m)
    if not m.node or not m.hpBg then return end
    local pos = m.node.worldPosition
    local barY = pos.y + CONFIG.HPBarOffY
    m.hpBg.position = Vector3(pos.x, barY, pos.z)
    m.hpBg.rotation = GS.cameraNode.rotation

    local ratio = math.max(0, m.hp / m.maxHp)
    local fullW = CONFIG.HPBarW
    local fillW = fullW * ratio
    m.hpFill.scale = Vector3(fillW, CONFIG.HPBarH * 0.7, 0.015)
    local offset = (fullW - fillW) * 0.5
    m.hpFill.position = Vector3(-offset, 0, -0.005)

    m.fillMat:SetShaderParameter("MatDiffColor", Variant(Color(0.882, 0.224, 0.224, 1.0)))
    m.fillMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.6, 0.0, 0.0)))
end

-- ============================================================================
-- 浮动伤害数字
-- ============================================================================

--- 生成浮动伤害数字
---@param pos Vector3
---@param dmg number
---@param color? Color 自定义颜色（默认黄色）
---@param strokeColor? Color 自定义描边（默认黑色）
function M.SpawnDmgText(pos, dmg, color, strokeColor)
    local node = GS.scene:CreateChild("DmgText")
    node.position = Vector3(pos.x, pos.y + 0.5, pos.z)

    local text3d = node:CreateComponent("Text3D")
    text3d:SetFont("Fonts/MiSans-Regular.ttf", 28)
    text3d:SetText(string.format("-%.0f", dmg))
    text3d:SetColor(color or Color(1.0, 0.18, 0.18, 1.0))
    text3d:SetAlignment(HA_CENTER, VA_CENTER)
    text3d:SetFaceCameraMode(FC_ROTATE_XYZ)
    text3d:SetTextEffect(TE_STROKE)
    text3d:SetEffectStrokeThickness(2)
    text3d:SetEffectColor(strokeColor or Color(0, 0, 0, 0.8))
    text3d.fixedScreenSize = true

    local entry = { node = node, text3d = text3d, timer = 0, maxTime = 0.8 }
    table.insert(GS.dmgTexts, entry)
end

-- 金币变化浮动提示: amount>0 绿色 +N, amount<0 红色 -N
function M.SpawnCoinText(pos, amount)
    if not GS.scene then return end
    local node = GS.scene:CreateChild("CoinText")
    node.position = Vector3(pos.x, pos.y + 1.2, pos.z)

    local text3d = node:CreateComponent("Text3D")
    text3d:SetFont("Fonts/MiSans-Regular.ttf", 24)
    if amount >= 0 then
        text3d:SetText(string.format("🪙+%d", amount))
        text3d:SetColor(Color(0.35, 1.0, 0.45, 1.0))
        text3d:SetEffectColor(Color(0.0, 0.15, 0.0, 0.9))
    else
        text3d:SetText(string.format("🪙%d", amount))
        text3d:SetColor(Color(1.0, 0.85, 0.25, 1.0))
        text3d:SetEffectColor(Color(0.2, 0.10, 0.0, 0.9))
    end
    text3d:SetAlignment(HA_CENTER, VA_CENTER)
    text3d:SetFaceCameraMode(FC_ROTATE_XYZ)
    text3d:SetTextEffect(TE_STROKE)
    text3d:SetEffectStrokeThickness(2)
    text3d.fixedScreenSize = true

    local entry = { node = node, text3d = text3d, timer = 0, maxTime = 1.1 }
    table.insert(GS.dmgTexts, entry)
end

function M.UpdateDmgTexts(dt)
    local i = 1
    while i <= #GS.dmgTexts do
        local d = GS.dmgTexts[i]
        d.timer = d.timer + dt
        if d.timer >= d.maxTime then
            d.node:Remove()
            table.remove(GS.dmgTexts, i)
        else
            local pos = d.node.position
            pos.y = pos.y + 1.5 * dt
            d.node.position = pos
            local alpha = 1.0 - (d.timer / d.maxTime)
            d.text3d:SetOpacity(alpha)
            i = i + 1
        end
    end
end

-- ============================================================================
-- 掉落物
-- ============================================================================

function M.SpawnLoot(pos, lootType, amount)
    local node = GS.scene:CreateChild("Loot_" .. lootType)
    local s = 0.6
    node.scale = Vector3(s, s, s)
    node.position = Vector3(pos.x, CONFIG.LootFloatHeight, pos.z)

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Meshes/TD/detail-crystal.mdl"))
    if lootType == "gold" then
        model:SetMaterial(M.GetLootGoldMaterial())
    elseif lootType == "material" then
        model:SetMaterial(M.GetLootMaterialMaterial())
    else
        model:SetMaterial(M.GetLootEnergyMaterial())
    end

    local loot = {
        node = node,
        type = lootType,
        amount = amount,
        timer = 0,
        collecting = false,
    }
    table.insert(GS.loots, loot)
end

function M.UpdateLoots(dt)
    local energyTowerPos = Vector3(0, 1.0, 0)
    local i = 1
    while i <= #GS.loots do
        local l = GS.loots[i]
        if not l.node then
            table.remove(GS.loots, i)
        else
            l.timer = l.timer + dt
            if not l.collecting and l.timer >= CONFIG.LootStayTime then
                l.collecting = true
            end
            if l.collecting then
                local pos = l.node.position
                local dir = energyTowerPos - pos
                local dist = dir:Length()
                if dist < 0.4 then
                    if l.type == "gold" then
                        GS.gold = GS.gold + (l.amount or CONFIG.MonsterGoldDrop)
                    elseif l.type == "material" then
                        GS.material = GS.material + (l.amount or 5)
                    elseif l.type == "energy" then
                        GS.energy = GS.energy + (l.amount or CONFIG.MonsterEnergyDrop)
                    end
                    l.node:Remove()
                    table.remove(GS.loots, i)
                else
                    dir = dir / dist
                    pos = pos + dir * CONFIG.LootCollectSpeed * dt
                    l.node.position = pos
                    i = i + 1
                end
            else
                local pos = l.node.position
                pos.y = CONFIG.LootFloatHeight + math.sin(l.timer * 4) * 0.08
                l.node.position = pos
                i = i + 1
            end
        end
    end
end

-- ============================================================================
-- 工具函数
-- ============================================================================

--- 将角度归一化到 -180 ~ 180
function M.NormalizeAngle(a)
    a = a % 360
    if a > 180 then a = a - 360 end
    return a
end

return M
