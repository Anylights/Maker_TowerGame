-- ============================================================================
-- Artifact.lua — 圣器数据 / 背包管理 / 槽位系统 / 掉落逻辑 / 效果应用
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS

local M = {}

-- ============================================================================
-- 圣器数据定义 (最小原型: 6 件普通圣器)
-- 参照 data/artifacts.json + data/balance.json
-- ============================================================================

M.DEFS = {
    -- === 白色稀有度 ===
    fire_seed = {
        id = "fire_seed",
        name = "火种圣器",
        rarity = "white",
        description = "命中附加燃烧(DPS=命中伤害×20%×4秒, 总伤80%); 单发伤害-15%",
        drop_weight = 60,
        effects = {
            { type = "on_hit_status", status = "burn", damage_percent_of_hit = 80, duration = 4 },
        },
        downsides = {
            { type = "stat_modifier", stat = "damage", modifier = -0.15 },
        },
    },
    ice_crystal = {
        id = "ice_crystal",
        name = "冰晶圣器",
        rarity = "white",
        description = "命中附加1层减速(5层冻结1.5秒); 单发伤害-15%",
        drop_weight = 60,
        effects = {
            { type = "on_hit_status", status = "freeze", stacks = 1, max_stacks = 5, duration = 2 },
        },
        downsides = {
            { type = "stat_modifier", stat = "damage", modifier = -0.15 },
        },
    },
    coin_magnet = {
        id = "coin_magnet",
        name = "磁币圣器",
        rarity = "white",
        description = "自动吸取5格内金币",
        drop_weight = 60,
        effects = {
            { type = "custom", logic_id = "auto_pickup_gold", range = 5 },
        },
        downsides = {},
    },

    -- === 蓝色稀有度 ===
    thunder = {
        id = "thunder",
        name = "雷鸣圣器",
        rarity = "blue",
        description = "命中后跳跃到附近2个敌人, 每跳衰减35%; 单发伤害-10%",
        drop_weight = 25,
        effects = {
            { type = "on_hit_status", status = "chain_lightning", jumps = 2, decay = 0.35, range = 2 },
        },
        downsides = {
            { type = "stat_modifier", stat = "damage", modifier = -0.10 },
        },
    },
    corrosion = {
        id = "corrosion",
        name = "腐蚀圣器",
        rarity = "blue",
        description = "命中附加1层腐蚀(首层-25%护甲, 每层-5%, cap-60%, 持续8秒); 单发伤害-10%",
        drop_weight = 25,
        effects = {
            { type = "on_hit_status", status = "corrode", stacks = 1, max_stacks = 8, duration = 8 },
        },
        downsides = {
            { type = "stat_modifier", stat = "damage", modifier = -0.10 },
        },
    },
    high_explosive = {
        id = "high_explosive",
        name = "高爆圣器",
        rarity = "blue",
        description = "炮弹→范围爆炸弹(半径1.5格); 射速-40%, 单发伤害-20%",
        drop_weight = 25,
        effects = {
            { type = "transform_bullet", new_form = "area", area_radius = 1.5 },
        },
        downsides = {
            { type = "stat_modifier", stat = "damage", modifier = -0.20 },
            { type = "stat_modifier", stat = "attack_speed", modifier = -0.40 },
        },
    },
}

-- 稀有度颜色
M.RARITY_COLORS = {
    white  = { 200, 200, 200, 255 },
    blue   = { 80, 160, 255, 255 },
    purple = { 180, 80, 255, 255 },
    gold   = { 255, 200, 50, 255 },
}

M.RARITY_NAMES = {
    white  = "普通",
    blue   = "精良",
    purple = "史诗",
    gold   = "传说",
}

-- ============================================================================
-- 背包管理
-- ============================================================================

--- 初始化圣器系统 (游戏开始时调用)
function M.Init()
    GS.artifactInventory = {}   -- 背包: { {id, defRef}, ... }
    GS.artifactDropPending = false  -- 是否有待处理的掉落选择
    GS.artifactDropCandidates = nil -- 3选1 候选列表
    print("[Artifact] System initialized")
end

--- 添加圣器到背包
--- @param artifactId string
--- @return table|nil 新增的背包条目
function M.AddToInventory(artifactId)
    local def = M.DEFS[artifactId]
    if not def then
        print("[Artifact] ERROR: Unknown artifact: " .. tostring(artifactId))
        return nil
    end
    local entry = {
        id = artifactId,
        def = def,
        equipped = false,    -- 是否已装备
        towerIndex = nil,    -- 装备在哪座塔 (GS.towers 的索引)
        slotType = nil,      -- "main" 或 "sub"
    }
    table.insert(GS.artifactInventory, entry)
    print(string.format("[Artifact] Added to inventory: %s (%s)", def.name, M.RARITY_NAMES[def.rarity]))
    return entry
end

--- 从背包移除圣器 (按背包索引)
--- @param invIndex number 背包索引 (1-based)
function M.RemoveFromInventory(invIndex)
    if invIndex < 1 or invIndex > #GS.artifactInventory then return end
    local entry = GS.artifactInventory[invIndex]
    -- 先卸下
    if entry.equipped then
        M.UnequipFromTower(invIndex)
    end
    table.remove(GS.artifactInventory, invIndex)
end

-- ============================================================================
-- 塔槽位系统 (每座塔: 1主槽 + 1副槽)
-- ============================================================================

--- 装备圣器到塔
--- @param invIndex number 背包索引
--- @param towerIndex number 塔索引 (GS.towers)
--- @param slotType string "main" 或 "sub"
--- @return boolean 是否成功
function M.EquipToTower(invIndex, towerIndex, slotType)
    if invIndex < 1 or invIndex > #GS.artifactInventory then return false end
    if towerIndex < 1 or towerIndex > #GS.towers then return false end
    if slotType ~= "main" and slotType ~= "sub" then return false end

    local entry = GS.artifactInventory[invIndex]
    local tower = GS.towers[towerIndex]

    -- 检查是否已装备在其他地方
    if entry.equipped then
        M.UnequipFromTower(invIndex)
    end

    -- 检查目标槽是否已有圣器
    local currentOccupant = M.GetEquippedAt(towerIndex, slotType)
    if currentOccupant then
        -- 先卸下当前圣器
        M.UnequipFromTower(currentOccupant)
    end

    -- 装备
    entry.equipped = true
    entry.towerIndex = towerIndex
    entry.slotType = slotType

    -- 在塔数据上记录
    if slotType == "main" then
        tower.mainSlot = invIndex
    else
        tower.subSlot = invIndex
    end

    -- 应用属性修正
    M.RecalcTowerArtifactStats(towerIndex)

    print(string.format("[Artifact] Equipped %s to Tower(%d,%d) %s slot",
        entry.def.name, tower.gx, tower.gz, slotType))
    return true
end

--- 从塔卸下圣器
--- @param invIndex number 背包索引
function M.UnequipFromTower(invIndex)
    if invIndex < 1 or invIndex > #GS.artifactInventory then return end
    local entry = GS.artifactInventory[invIndex]
    if not entry.equipped then return end

    local towerIndex = entry.towerIndex
    local tower = GS.towers[towerIndex]
    if tower then
        if tower.mainSlot == invIndex then
            tower.mainSlot = nil
        end
        if tower.subSlot == invIndex then
            tower.subSlot = nil
        end
        M.RecalcTowerArtifactStats(towerIndex)
    end

    entry.equipped = false
    entry.towerIndex = nil
    entry.slotType = nil
end

--- 获取指定塔槽位上的背包索引
--- @param towerIndex number
--- @param slotType string
--- @return number|nil 背包索引
function M.GetEquippedAt(towerIndex, slotType)
    if towerIndex < 1 or towerIndex > #GS.towers then return nil end
    local tower = GS.towers[towerIndex]
    if slotType == "main" then
        return tower.mainSlot
    else
        return tower.subSlot
    end
end

--- 获取塔上装备的所有圣器效果列表
--- @param towerIndex number
--- @return table 效果列表 { {effect, effectiveness, defRef}, ... }
function M.GetTowerEffects(towerIndex)
    local results = {}
    if towerIndex < 1 or towerIndex > #GS.towers then return results end
    local tower = GS.towers[towerIndex]

    -- 主槽: 100% 效力
    if tower.mainSlot then
        local entry = GS.artifactInventory[tower.mainSlot]
        if entry and entry.def then
            for _, eff in ipairs(entry.def.effects) do
                table.insert(results, { effect = eff, effectiveness = 1.0, def = entry.def })
            end
        end
    end

    -- 副槽: 60% 效力
    if tower.subSlot then
        local entry = GS.artifactInventory[tower.subSlot]
        if entry and entry.def then
            for _, eff in ipairs(entry.def.effects) do
                table.insert(results, { effect = eff, effectiveness = 0.6, def = entry.def })
            end
        end
    end

    return results
end

-- ============================================================================
-- 属性修正计算
-- ============================================================================

--- 重新计算塔的圣器属性修正
--- @param towerIndex number
function M.RecalcTowerArtifactStats(towerIndex)
    if towerIndex < 1 or towerIndex > #GS.towers then return end
    local tower = GS.towers[towerIndex]

    -- 重置修正值
    tower.artDmgMult = 1.0       -- 伤害乘数
    tower.artAtkSpdMult = 1.0    -- 攻速乘数
    tower.artBulletForm = "bullet" -- 弹道形态
    tower.artAreaRadius = 0       -- 范围爆炸半径
    tower.artOnHit = {}           -- 命中效果列表

    local function applySlot(slotInvIdx, effectiveness)
        if not slotInvIdx then return end
        local entry = GS.artifactInventory[slotInvIdx]
        if not entry or not entry.def then return end

        -- 应用缺点 (downsides) — 始终 100% 生效
        for _, ds in ipairs(entry.def.downsides) do
            if ds.type == "stat_modifier" then
                if ds.stat == "damage" then
                    tower.artDmgMult = tower.artDmgMult * (1.0 + ds.modifier)
                elseif ds.stat == "attack_speed" then
                    tower.artAtkSpdMult = tower.artAtkSpdMult * (1.0 + ds.modifier)
                end
            end
        end

        -- 应用效果 — 按 effectiveness 缩放
        for _, eff in ipairs(entry.def.effects) do
            if eff.type == "on_hit_status" then
                table.insert(tower.artOnHit, {
                    status = eff.status,
                    effectiveness = effectiveness,
                    -- 透传具体参数
                    damage_percent_of_hit = eff.damage_percent_of_hit,
                    duration = eff.duration,
                    stacks = eff.stacks,
                    max_stacks = eff.max_stacks,
                    jumps = eff.jumps,
                    decay = eff.decay,
                    range = eff.range,
                })
            elseif eff.type == "transform_bullet" then
                tower.artBulletForm = eff.new_form or "bullet"
                tower.artAreaRadius = (eff.area_radius or 0) * effectiveness
            elseif eff.type == "custom" and eff.logic_id == "auto_pickup_gold" then
                tower.artAutoPickupRange = (eff.range or 5) * effectiveness
            end
        end
    end

    applySlot(tower.mainSlot, 1.0)
    applySlot(tower.subSlot, 0.6)
end

--- 确保所有塔都有圣器属性字段 (放置新塔后调用)
function M.InitTowerSlots(tower)
    tower.mainSlot = nil
    tower.subSlot = nil
    tower.artDmgMult = 1.0
    tower.artAtkSpdMult = 1.0
    tower.artBulletForm = "bullet"
    tower.artAreaRadius = 0
    tower.artOnHit = {}
    tower.artAutoPickupRange = 0
end

-- ============================================================================
-- 掉落逻辑 (波次结束时 3 选 1)
-- ============================================================================

--- 生成 3 个候选圣器
--- @return table candidates { {id, def}, ... }
function M.GenerateDropCandidates()
    -- 按 drop_weight 权重抽样
    local pool = {}
    local totalWeight = 0
    for id, def in pairs(M.DEFS) do
        table.insert(pool, { id = id, def = def, weight = def.drop_weight })
        totalWeight = totalWeight + def.drop_weight
    end

    local candidates = {}
    local picked = {}

    for c = 1, 3 do
        if #pool == 0 then break end

        local roll = math.random() * totalWeight
        local acc = 0
        for i, item in ipairs(pool) do
            acc = acc + item.weight
            if acc >= roll then
                table.insert(candidates, { id = item.id, def = item.def })
                picked[item.id] = true
                -- 从池中移除防止重复
                totalWeight = totalWeight - item.weight
                table.remove(pool, i)
                break
            end
        end
    end

    return candidates
end

--- 触发波次结束掉落 (由 Wave.lua 调用)
function M.TriggerWaveDrop()
    local candidates = M.GenerateDropCandidates()
    if #candidates == 0 then return end

    GS.artifactDropPending = true
    GS.artifactDropCandidates = candidates

    print(string.format("[Artifact] Wave drop: %s | %s | %s",
        candidates[1] and candidates[1].def.name or "?",
        candidates[2] and candidates[2].def.name or "?",
        candidates[3] and candidates[3].def.name or "?"))
end

--- 玩家选择掉落圣器
--- @param choiceIndex number 1-3 选择, 0 = 跳过
function M.PickDrop(choiceIndex)
    if not GS.artifactDropPending or not GS.artifactDropCandidates then return end

    if choiceIndex >= 1 and choiceIndex <= #GS.artifactDropCandidates then
        local chosen = GS.artifactDropCandidates[choiceIndex]
        M.AddToInventory(chosen.id)
    else
        -- 跳过: 给 50 金币补偿
        GS.gold = GS.gold + 50
        print("[Artifact] Drop skipped, +50 gold")
    end

    GS.artifactDropPending = false
    GS.artifactDropCandidates = nil
end

-- ============================================================================
-- 磁币圣器: 自动吸取金币
-- ============================================================================

--- 每帧更新磁币效果 (在 main.lua 中调用)
function M.UpdateAutoPickup(dt)
    for _, tower in ipairs(GS.towers) do
        if tower.artAutoPickupRange and tower.artAutoPickupRange > 0 then
            local range = tower.artAutoPickupRange
            for _, loot in ipairs(GS.loots) do
                if loot.node and loot.type == "gold" and not loot.collecting then
                    local dx = loot.node.position.x - tower.gx
                    local dz = loot.node.position.z - tower.gz
                    local dist = math.sqrt(dx * dx + dz * dz)
                    if dist <= range then
                        loot.collecting = true -- 触发自动收集
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- 查询接口
-- ============================================================================

--- 获取背包中未装备的圣器列表
function M.GetUnequippedArtifacts()
    local list = {}
    for i, entry in ipairs(GS.artifactInventory) do
        if not entry.equipped then
            table.insert(list, { invIndex = i, entry = entry })
        end
    end
    return list
end

--- 获取塔的圣器信息 (用于 UI 显示)
--- @param towerIndex number
--- @return table { main = {name,rarity,...}|nil, sub = {name,rarity,...}|nil }
function M.GetTowerArtifactInfo(towerIndex)
    local info = { main = nil, sub = nil }
    if towerIndex < 1 or towerIndex > #GS.towers then return info end
    local tower = GS.towers[towerIndex]

    if tower.mainSlot then
        local entry = GS.artifactInventory[tower.mainSlot]
        if entry then info.main = entry.def end
    end
    if tower.subSlot then
        local entry = GS.artifactInventory[tower.subSlot]
        if entry then info.sub = entry.def end
    end
    return info
end

return M
