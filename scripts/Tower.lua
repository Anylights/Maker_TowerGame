-- ============================================================================
-- Tower.lua — 基础塔放置 / 攻击 / 炮弹 / 悬停 / 放置输入
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS
local Utils = require("Utils")
local EnergyTower = require("EnergyTower")

local M = {}

-- ============================================================================
-- 武器模型列表
-- ============================================================================
local WEAPON_MODELS = {
    "weapon-cannon",
    "weapon-ballista",
    "weapon-catapult",
    "weapon-turret",
}

-- ============================================================================
-- 经济
-- ============================================================================

function M.GetTowerCost()
    local n = #GS.towers
    return CONFIG.BaseCost + CONFIG.CostLinear * n + CONFIG.CostQuad * n * n
end

-- ============================================================================
-- 创建塔模型
-- ============================================================================

local function CreateTowerModel(node)
    local baseChild = node:CreateChild("TowerBase")
    local baseModel = baseChild:CreateComponent("StaticModel")
    baseModel:SetModel(cache:GetResource("Model", "Meshes/TD/tower-square-bottom-a.mdl"))
    baseModel:SetMaterial(cache:GetResource("Material", "Materials/TD/tower-square-bottom-a_00_colormap.xml"))
    baseModel.castShadows = true

    local weaponName = WEAPON_MODELS[math.random(1, #WEAPON_MODELS)]
    local weaponChild = node:CreateChild("TowerWeapon")
    weaponChild.position = Vector3(0, 0.5, 0)
    local weaponModel = weaponChild:CreateComponent("StaticModel")
    weaponModel:SetModel(cache:GetResource("Model", "Meshes/TD/" .. weaponName .. ".mdl"))
    weaponModel:SetMaterial(cache:GetResource("Material", "Materials/TD/" .. weaponName .. "_00_colormap.xml"))
    weaponModel.castShadows = true
end

-- ============================================================================
-- 放置塔
-- ============================================================================

function M.PlaceBasicTower(gx, gz)
    local cost = M.GetTowerCost()
    if GS.gold < cost then return end
    GS.gold = GS.gold - cost

    local node = GS.scene:CreateChild("Tower_" .. gx .. "_" .. gz)
    node.position = Vector3(gx, 0, gz)
    CreateTowerModel(node)

    local dist = math.sqrt(gx * gx + gz * gz)
    local tower = {
        node = node,
        gx = gx,
        gz = gz,
        dist = dist,
        delivered = 0,
        linePwr = 0,
        ratio = 0,
        cooldown = 0,
        weaponYaw = 0,
        targetYaw = nil,
    }
    table.insert(GS.towers, tower)

    EnergyTower.RecalculateEnergy()
    EnergyTower.RebuildEnergyLines()

    print(string.format("Tower built at (%d, %d), dist=%.1f, cost=%d, gold=%d",
        gx, gz, dist, cost, GS.gold))
end

-- ============================================================================
-- 塔攻击
-- ============================================================================

local ROTATE_SPEED = 720

function M.UpdateTowerAttacks(dt)
    for _, tower in ipairs(GS.towers) do
        -- 平滑旋转
        if tower.targetYaw then
            local weaponNode = tower.node:GetChild("TowerWeapon", false)
            if weaponNode then
                local diff = Utils.NormalizeAngle(tower.targetYaw - tower.weaponYaw)
                local maxStep = ROTATE_SPEED * dt
                if math.abs(diff) <= maxStep then
                    tower.weaponYaw = tower.targetYaw
                else
                    tower.weaponYaw = tower.weaponYaw + (diff > 0 and maxStep or -maxStep)
                end
                weaponNode.rotation = Quaternion(tower.weaponYaw, Vector3.UP)
            end
        end

        -- 寻找最近怪物
        local bestM = nil
        local bestDist = CONFIG.TowerRange + 1
        for _, m in ipairs(GS.monsters) do
            if m.node and m.hp > 0 then
                local dx = m.node.position.x - tower.gx
                local dz = m.node.position.z - tower.gz
                local d = math.sqrt(dx * dx + dz * dz)
                if d <= CONFIG.TowerRange and d < bestDist then
                    bestDist = d
                    bestM = m
                end
            end
        end

        -- 跟踪方向
        if bestM then
            local tpos = bestM.node.position
            local dx = tpos.x - tower.gx
            local dz = tpos.z - tower.gz
            tower.targetYaw = math.deg(math.atan(dx, dz)) + 180
        end

        -- 开火
        tower.cooldown = tower.cooldown - dt
        if tower.cooldown <= 0 and bestM then
            local att = EnergyTower.CalcAttenuation(tower.dist)
            local dmg = CONFIG.TowerBaseDmg * att
            M.FireProjectile(tower, bestM, dmg)
            tower.cooldown = CONFIG.TowerFireInterval
        end
    end
end

-- ============================================================================
-- 炮弹
-- ============================================================================

function M.FireProjectile(tower, targetMonster, dmg)
    local node = GS.scene:CreateChild("Projectile")
    local s = CONFIG.ProjectileSize / 0.28
    node.scale = Vector3(s, s, s)
    node.position = Vector3(tower.gx, 1.0, tower.gz)

    local model = node:CreateComponent("StaticModel")
    model:SetModel(cache:GetResource("Model", "Meshes/TD/weapon-ammo-cannonball.mdl"))
    model:SetMaterial(cache:GetResource("Material", "Materials/TD/weapon-ammo-cannonball_00_colormap.xml"))

    local proj = {
        node = node,
        target = targetMonster,
        speed = CONFIG.ProjectileSpeed,
        damage = dmg,
    }
    table.insert(GS.projectiles, proj)
end

function M.UpdateProjectiles(dt)
    local Monster = require("Monster")
    local i = 1
    while i <= #GS.projectiles do
        local p = GS.projectiles[i]
        if not p.node then
            table.remove(GS.projectiles, i)
        elseif not p.target or not p.target.node or p.target.hp <= 0 then
            p.node:Remove()
            table.remove(GS.projectiles, i)
        else
            local pos = p.node.position
            local tpos = p.target.node.position
            local dir = tpos - pos
            local dist = dir:Length()
            if dist < 0.3 then
                Monster.DamageMonster(p.target, p.damage)
                p.node:Remove()
                table.remove(GS.projectiles, i)
            else
                dir = dir / dist
                pos = pos + dir * p.speed * dt
                p.node.position = pos
                i = i + 1
            end
        end
    end
end

-- ============================================================================
-- 悬停 + 放置输入
-- ============================================================================

function M.HandleGridHover()
    local pos = input.mousePosition
    local sx = pos.x / graphics:GetWidth()
    local sy = pos.y / graphics:GetHeight()
    local ray = GS.camera:GetScreenRay(sx, sy)

    if math.abs(ray.direction.y) < 0.001 then
        GS.hoverNode.enabled = false
        GS.hoverOnMap = false
        return
    end

    local t = -ray.origin.y / ray.direction.y
    if t <= 0 then
        GS.hoverNode.enabled = false
        GS.hoverOnMap = false
        return
    end

    local hit = ray.origin + ray.direction * t
    local gx = math.floor(hit.x + 0.5)
    local gz = math.floor(hit.z + 0.5)

    local hw = CONFIG.MapHalfW
    local hh = CONFIG.MapHalfH
    if gx < -hw or gx > hw or gz < -hh or gz > hh then
        GS.hoverNode.enabled = false
        GS.hoverOnMap = false
        return
    end

    GS.hoverOnMap = true
    GS.hoverGX = gx
    GS.hoverGZ = gz

    local dist = math.sqrt(gx * gx + gz * gz)
    local inRange = dist <= CONFIG.EnergyRange + 0.01
    local isEnergyTower = (gx == 0 and gz == 0)
    local isOccupied = false
    for _, tower in ipairs(GS.towers) do
        if tower.gx == gx and tower.gz == gz then
            isOccupied = true
            break
        end
    end
    local canAfford = GS.gold >= M.GetTowerCost()

    GS.hoverValid = inRange and not isEnergyTower and not isOccupied and canAfford

    GS.hoverNode.enabled = true
    GS.hoverNode.position = Vector3(gx, CONFIG.HoverY, gz)

    local hoverMat = GS.hoverNode:GetComponent("StaticModel"):GetMaterial(0)
    if GS.hoverValid then
        hoverMat:SetShaderParameter("MatDiffColor", Variant(Color(0.2, 0.8, 0.2, 0.45)))
        hoverMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.1, 0.4, 0.1)))
    else
        hoverMat:SetShaderParameter("MatDiffColor", Variant(Color(0.8, 0.2, 0.2, 0.45)))
        hoverMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.4, 0.1, 0.1)))
    end
end

function M.HandlePlacement()
    if input:GetMouseButtonPress(MOUSEB_LEFT) and GS.hoverOnMap and GS.hoverValid then
        M.PlaceBasicTower(GS.hoverGX, GS.hoverGZ)
    end
end

return M
