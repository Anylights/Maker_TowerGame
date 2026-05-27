-- ============================================================================
-- StatusEffect.lua — 状态效果系统 (燃烧/冰冻/腐蚀/闪电连锁/感电/元素反应)
-- 参照 data/balance.json → status_effects
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS
local Utils = require("Utils")

local M = {}

-- ============================================================================
-- 状态效果参数 (来自 balance.json)
-- ============================================================================

M.PARAMS = {
    burn = {
        dps_ratio = 0.20,       -- DPS = 触发伤害 × 0.20
        default_duration = 4,   -- 持续 4 秒
        stack_rule = "max",     -- 刷新: 取最大伤害
    },
    freeze = {
        slow_per_stack = 0.30,  -- 每层 -30% 移速
        max_stacks = 5,         -- 满 5 层冻结
        freeze_duration = 1.5,  -- 完全冻结 1.5 秒
        decay_per_second = 0.5, -- 每秒自然衰减 0.5 层
    },
    corrode = {
        first_layer = 0.25,     -- 首层 -25% 护甲
        per_layer = 0.05,       -- 每额外层 -5%
        cap = 0.60,             -- 上限 -60%
        duration = 8,           -- 持续 8 秒
        stack_rule = "add",     -- 叠加
    },
    chain_lightning = {
        default_jumps = 2,      -- 跳 2 个目标
        decay_per_jump = 0.35,  -- 每跳衰减 35%
        max_range = 2,          -- 跳跃范围 2 格
    },
    electric = {
        duration = 3.0,         -- 感电持续 3 秒（chain_lightning 命中后留下）
    },
}

-- ============================================================================
-- 初始化怪物的状态效果字段
-- 在 Monster.SpawnMonster 后调用
-- ============================================================================

--- 为怪物实例初始化状态效果容器
--- @param monster table 怪物实例
function M.InitMonsterEffects(monster)
    monster.statusEffects = {
        burn = nil,      -- { dps, timer, totalDmg, tickAcc }
        freeze = nil,    -- { stacks, frozen, frozenTimer, decayAcc }
        corrode = nil,   -- { stacks, timer }
        electric = nil,  -- { timer }  感电（chain_lightning 命中留下的持续标记）
    }
    monster.speedMultiplier = 1.0  -- 速度乘数 (冰冻减速用)
end

-- ============================================================================
-- 施加状态效果 (命中时调用)
-- ============================================================================

--- 施加燃烧
--- @param monster table
--- @param hitDmg number 本次命中伤害
--- @param duration number 持续时间
--- @param effectiveness number 效力 (0.6~1.0)
function M.ApplyBurn(monster, hitDmg, duration, effectiveness)
    if not monster.statusEffects then return end
    local dps = hitDmg * M.PARAMS.burn.dps_ratio * effectiveness
    duration = duration or M.PARAMS.burn.default_duration

    local cur = monster.statusEffects.burn
    if cur then
        -- max 规则: 取更大 dps，刷新时间
        if dps > cur.dps then
            cur.dps = dps
        end
        cur.timer = math.max(cur.timer, duration)
    else
        monster.statusEffects.burn = {
            dps = dps,
            timer = duration,
            tickAcc = 0,  -- tick 累加器 (每 0.5s 跳一次数字)
        }
    end
end

--- 施加冰冻层数
--- @param monster table
--- @param stacks number 附加层数
--- @param effectiveness number 效力
function M.ApplyFreeze(monster, stacks, effectiveness)
    if not monster.statusEffects then return end
    local p = M.PARAMS.freeze
    stacks = math.max(1, math.floor((stacks or 1) * effectiveness + 0.5))

    local cur = monster.statusEffects.freeze
    if not cur then
        cur = { stacks = 0, frozen = false, frozenTimer = 0, decayAcc = 0 }
        monster.statusEffects.freeze = cur
    end

    if cur.frozen then return end -- 已冻结中，不叠加

    cur.stacks = math.min(cur.stacks + stacks, p.max_stacks)
    cur.decayAcc = 0  -- 重置衰减计时

    -- 达到最大层数 → 冻结
    if cur.stacks >= p.max_stacks then
        cur.frozen = true
        cur.frozenTimer = p.freeze_duration
        cur.stacks = 0
    end
end

--- 施加腐蚀层数
--- @param monster table
--- @param stacks number
--- @param duration number
--- @param effectiveness number
function M.ApplyCorrode(monster, stacks, duration, effectiveness)
    if not monster.statusEffects then return end
    stacks = math.max(1, math.floor((stacks or 1) * effectiveness + 0.5))
    duration = duration or M.PARAMS.corrode.duration

    local cur = monster.statusEffects.corrode
    if not cur then
        cur = { stacks = 0, timer = 0 }
        monster.statusEffects.corrode = cur
    end

    cur.stacks = cur.stacks + stacks
    cur.timer = math.max(cur.timer, duration)  -- 刷新持续时间
end

--- 执行闪电连锁 (立即伤害，不是持续效果)
--- @param sourceMonster table 被命中的怪物
--- @param hitDmg number 本次命中伤害
--- @param jumps number 跳跃次数
--- @param decay number 每跳衰减比例
--- @param range number 跳跃范围 (格)
--- @param effectiveness number 效力
function M.ApplyChainLightning(sourceMonster, hitDmg, jumps, decay, range, effectiveness)
    local Monster = require("Monster")
    jumps = jumps or M.PARAMS.chain_lightning.default_jumps
    decay = decay or M.PARAMS.chain_lightning.decay_per_jump
    range = range or M.PARAMS.chain_lightning.max_range

    local currentDmg = hitDmg * effectiveness
    local lastPos = sourceMonster.node.position
    local hit = { [sourceMonster] = true }

    for j = 1, jumps do
        currentDmg = currentDmg * (1.0 - decay)
        if currentDmg < 1 then break end

        -- 找最近未命中的敌人
        local bestM = nil
        local bestDist = range + 1

        for _, m in ipairs(GS.monsters) do
            if m.node and m.hp > 0 and not hit[m] then
                local dx = m.node.position.x - lastPos.x
                local dz = m.node.position.z - lastPos.z
                local d = math.sqrt(dx * dx + dz * dz)
                if d <= range and d < bestDist then
                    bestDist = d
                    bestM = m
                end
            end
        end

        if not bestM then break end

        hit[bestM] = true
        lastPos = bestM.node.position  -- 先记录位置，DamageMonster 可能移除 node
        Monster.DamageMonster(bestM, currentDmg)
        -- 感电标记: chain_lightning 命中的每个目标留下 electric 状态
        if bestM.statusEffects then
            local elec = bestM.statusEffects.electric
            local dur = M.PARAMS.electric.duration
            if elec then
                elec.timer = math.max(elec.timer, dur)  -- 刷新
            else
                bestM.statusEffects.electric = { timer = dur }
            end
        end
    end
end

--- 施加感电标记（可独立调用）
--- @param monster table
--- @param duration number 持续时间（可选，默认3秒）
function M.ApplyElectric(monster, duration)
    if not monster.statusEffects then return end
    duration = duration or M.PARAMS.electric.duration
    local cur = monster.statusEffects.electric
    if cur then
        cur.timer = math.max(cur.timer, duration)
    else
        monster.statusEffects.electric = { timer = duration }
    end
end

-- ============================================================================
-- 命中时自动施加圣器效果 (Tower 命中怪物后调用)
-- ============================================================================

--- 处理塔的命中后效果
--- @param monster table 被命中的怪物
--- @param hitDmg number 实际伤害
--- @param tower table 发射塔
function M.ProcessOnHitEffects(monster, hitDmg, tower)
    if not tower.artOnHit or #tower.artOnHit == 0 then return end
    if not monster.node or monster.hp <= 0 then return end

    for _, oh in ipairs(tower.artOnHit) do
        local eff = oh.effectiveness or 1.0

        if oh.status == "burn" then
            M.ApplyBurn(monster, hitDmg, oh.duration, eff)

        elseif oh.status == "freeze" then
            M.ApplyFreeze(monster, oh.stacks or 1, eff)

        elseif oh.status == "corrode" then
            M.ApplyCorrode(monster, oh.stacks or 1, oh.duration, eff)

        elseif oh.status == "chain_lightning" then
            M.ApplyChainLightning(monster, hitDmg,
                oh.jumps, oh.decay, oh.range, eff)
        end
    end

    -- 元素反应: 仅当塔有 artHasElementalReaction 时检测
    if tower and tower.artHasElementalReaction then
        M.TriggerElementalReaction(monster, hitDmg, tower)
    end
end

-- ============================================================================
-- 元素反应 (elemental_reaction 圣器)
-- 燃烧+冰冻=蒸发 / 冰冻+感电=麻痹 / 感电+燃烧=过载 / 腐蚀+任意=侵蚀
-- ============================================================================

--- 元素反应触发
--- @param monster table
--- @param hitDmg number 本次命中伤害（用于计算反应伤害）
--- @param tower table 触发反应的塔（用于记录击杀来源）
function M.TriggerElementalReaction(monster, hitDmg, tower)
    if not monster.statusEffects or not monster.node or monster.hp <= 0 then return end
    local se = monster.statusEffects
    local Monster = require("Monster")

    local hasBurn    = se.burn    ~= nil
    local hasFreeze  = se.freeze  ~= nil
    local hasElec    = se.electric ~= nil
    local hasCorrode = se.corrode  ~= nil

    -- 侵蚀 (腐蚀 + 任意其他状态): 最高优先级，腐蚀所有层立即爆发为伤害
    if hasCorrode and (hasBurn or hasFreeze or hasElec) then
        local stacks = se.corrode.stacks or 1
        local erosionDmg = math.max(1, math.floor(hitDmg * 0.5 * stacks + 0.5))
        se.corrode = nil  -- 消耗腐蚀
        monster.lastHitTower = tower
        Monster.DamageMonster(monster, erosionDmg)
        Utils.SpawnDmgText(monster.node.position, erosionDmg)
        return  -- 侵蚀优先，不再触发其他反应
    end

    -- 蒸发 (燃烧 + 冰冻): 双重消耗，造成高额爆发
    if hasBurn and hasFreeze then
        local evapDmg = math.max(1, math.floor(hitDmg * 2.0 + 0.5))
        se.burn   = nil
        se.freeze = nil
        monster.lastHitTower = tower
        Monster.DamageMonster(monster, evapDmg)
        Utils.SpawnDmgText(monster.node.position, evapDmg)
        return
    end

    -- 麻痹 (冰冻 + 感电): 消耗感电，延长冻结时间
    if hasFreeze and hasElec then
        se.electric = nil  -- 消耗感电
        local f = se.freeze
        if f and f.frozen then
            f.frozenTimer = f.frozenTimer + 2.0  -- 追加 2 秒冻结
        elseif f then
            -- 强制触发冻结
            f.frozen = true
            f.frozenTimer = M.PARAMS.freeze.freeze_duration + 1.0
            f.stacks = 0
        end
        return
    end

    -- 过载 (感电 + 燃烧): 消耗感电，造成范围伤害
    if hasElec and hasBurn then
        se.electric = nil  -- 消耗感电
        local overloadDmg = math.max(1, math.floor(hitDmg * 1.5 + 0.5))
        -- 对 1.5 格内所有怪造成过载溅射
        local pos = monster.node.position
        for _, m2 in ipairs(GS.monsters) do
            if m2.node and m2.hp > 0 then
                local dx = m2.node.position.x - pos.x
                local dz = m2.node.position.z - pos.z
                if math.sqrt(dx*dx + dz*dz) <= 1.5 then
                    m2.lastHitTower = tower
                    Monster.DamageMonster(m2, overloadDmg)
                    Utils.SpawnDmgText(m2.node.position, overloadDmg)
                end
            end
        end
        return
    end
end

-- ============================================================================
-- 每帧更新所有怪物的状态效果
-- ============================================================================

function M.Update(dt)
    local Monster = require("Monster")

    for _, m in ipairs(GS.monsters) do
        if m.node and m.hp > 0 and m.statusEffects then
            M.UpdateMonsterEffects(m, dt)
        end
    end
end

--- 更新单个怪物的状态效果
function M.UpdateMonsterEffects(m, dt)
    local se = m.statusEffects
    local speedMult = 1.0

    -- === 燃烧 ===
    if se.burn then
        local b = se.burn
        b.timer = b.timer - dt
        if b.timer <= 0 then
            se.burn = nil
        else
            -- DoT 伤害
            local dmgThisTick = b.dps * dt
            b.tickAcc = b.tickAcc + dt
            -- 每 0.5s 跳一次伤害数字
            if b.tickAcc >= 0.5 then
                local tickDmg = math.max(1, math.floor(b.dps * b.tickAcc + 0.5))
                m.hp = m.hp - tickDmg
                -- 燃烧伤害文字 (橙色)
                if m.node then
                    Utils.SpawnDmgText(m.node.position, tickDmg)
                end
                b.tickAcc = 0

                if m.hp <= 0 then
                    local Monster = require("Monster")
                    Monster.KillMonster(m)
                    return
                end
            end
        end
    end

    -- === 冰冻 ===
    if se.freeze then
        local f = se.freeze
        if f.frozen then
            -- 完全冻结中
            f.frozenTimer = f.frozenTimer - dt
            speedMult = 0  -- 完全停止

            if f.frozenTimer <= 0 then
                f.frozen = false
                f.frozenTimer = 0
                f.stacks = 0
                se.freeze = nil
            end
        else
            -- 减速层数
            if f.stacks > 0 then
                local slow = f.stacks * M.PARAMS.freeze.slow_per_stack
                speedMult = math.max(0.05, 1.0 - slow)  -- 最低 5% 速度

                -- 自然衰减
                f.decayAcc = f.decayAcc + dt * M.PARAMS.freeze.decay_per_second
                if f.decayAcc >= 1.0 then
                    local decayStacks = math.floor(f.decayAcc)
                    f.stacks = math.max(0, f.stacks - decayStacks)
                    f.decayAcc = f.decayAcc - decayStacks
                end

                if f.stacks <= 0 then
                    se.freeze = nil
                end
            else
                se.freeze = nil
            end
        end
    end

    -- === 腐蚀 ===
    if se.corrode then
        local c = se.corrode
        c.timer = c.timer - dt
        if c.timer <= 0 then
            -- 腐蚀消退，恢复护甲
            se.corrode = nil
        else
            -- 计算护甲削减
            local p = M.PARAMS.corrode
            local reduction = p.first_layer + p.per_layer * math.max(0, c.stacks - 1)
            reduction = math.min(reduction, p.cap)
            -- 直接减少护甲比 (基于基础值)
            m.armorRatio = math.max(0, m.baseArmorRatio - reduction)
        end
    else
        -- 无腐蚀时，恢复基础护甲 (除非 Boss 护甲 buff 在生效)
        if m.armorBuffTimer and m.armorBuffTimer > 0 then
            -- Boss 护甲 buff 正在生效，不恢复
        else
            m.armorRatio = m.baseArmorRatio
        end
    end

    -- === 感电 ===
    if se.electric then
        se.electric.timer = se.electric.timer - dt
        if se.electric.timer <= 0 then
            se.electric = nil
        end
    end

    -- 应用速度乘数
    m.speedMultiplier = speedMult
end

--- 获取怪物实际速度 (Monster.UpdateMonsters 调用)
--- @param monster table
--- @return number 实际速度
function M.GetEffectiveSpeed(monster)
    return monster.speed * (monster.speedMultiplier or 1.0)
end

--- 获取怪物当前状态效果摘要 (UI 显示用)
--- @param monster table
--- @return string
function M.GetStatusSummary(monster)
    if not monster.statusEffects then return "" end
    local parts = {}
    local se = monster.statusEffects
    if se.burn then
        table.insert(parts, string.format("Burn(%.0f/s)", se.burn.dps))
    end
    if se.freeze then
        if se.freeze.frozen then
            table.insert(parts, string.format("Frozen(%.1fs)", se.freeze.frozenTimer))
        elseif se.freeze.stacks > 0 then
            table.insert(parts, string.format("Slow(%d)", se.freeze.stacks))
        end
    end
    if se.corrode then
        table.insert(parts, string.format("Corrode(%d)", se.corrode.stacks))
    end
    if #parts == 0 then return "" end
    return table.concat(parts, " ")
end

return M
