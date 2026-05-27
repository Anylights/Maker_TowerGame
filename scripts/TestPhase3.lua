-- ============================================================================
-- TestPhase3.lua — Phase 3 圣器效果验收测试
-- 覆盖: master_tower / prism / network / elemental_reaction
-- ============================================================================

local Cfg      = require("Config")
local GS       = Cfg.GS
local Artifact = require("Artifact")
local SE       = require("StatusEffect")
local Utils    = require("Utils")

local M = {}

-- ============================================================================
-- 测试工具
-- ============================================================================

local passCount, failCount = 0, 0

local function Assert(cond, msg)
    if cond then
        passCount = passCount + 1
        print("[PASS] " .. msg)
    else
        failCount = failCount + 1
        print("[FAIL] " .. msg)
    end
end

local function Near(a, b, eps)
    eps = eps or 0.001
    return math.abs(a - b) <= eps
end

local function MakeFakeTower(gx, gz, delivered)
    local t = { gx = gx or 0, gz = gz or 0, delivered = delivered or 10, ratio = 1.0 }
    Artifact.InitTowerSlots(t)
    return t
end

local function RegisterTower(t)
    table.insert(GS.towers, t)
    return #GS.towers
end

local function PopTowers(n)
    for _ = 1, n do table.remove(GS.towers) end
end

local function EquipArt(artifactId, towerIdx, slotType)
    local entry = Artifact.AddToInventory(artifactId)
    if not entry then
        print("[TEST-ERROR] 未找到圣器: " .. artifactId)
        return nil
    end
    local invIdx = #GS.artifactInventory
    Artifact.EquipToTower(invIdx, towerIdx, slotType or "slot1")
    return invIdx
end

local function UnequipAll()
    for i = #GS.artifactInventory, 1, -1 do
        local entry = GS.artifactInventory[i]
        if entry and entry.towerIndex then
            Artifact.UnequipFromTower(i)
        end
    end
    GS.artifactInventory = {}
end

-- 构造轻量级假怪物（不依赖真实 Node）
-- node 只提供 position / GetID / Remove，足以通过 DamageMonster / TriggerElementalReaction
local _nodeIdCounter = 8000
local function MakeFakeMonster(hp, x, z)
    _nodeIdCounter = _nodeIdCounter + 1
    local id = _nodeIdCounter
    local node = {
        position = Vector3(x or 0, 0, z or 0),
        GetID    = function(self) return id end,
        Remove   = function(self) end,
    }
    local m = {
        node          = node,
        hp            = hp or 100,
        maxHp         = hp or 100,
        shield        = 0,
        armorRatio    = 0,
        shieldNode    = nil,
        lastHitTower  = nil,
        lineDmgReduction = 0,
    }
    SE.InitMonsterEffects(m)
    return m
end

local function RegisterMonster(m)
    table.insert(GS.monsters, m)
    return #GS.monsters
end

local function PopMonsters(n)
    for _ = 1, n do table.remove(GS.monsters) end
end

-- 临时 patch Utils.SpawnDmgText 为 noop（测试期间不需要真实场景节点）
local _origSpawnDmgText
local function PatchSpawnDmgText()
    _origSpawnDmgText = Utils.SpawnDmgText
    Utils.SpawnDmgText = function() end
end
local function RestoreSpawnDmgText()
    if _origSpawnDmgText then
        Utils.SpawnDmgText = _origSpawnDmgText
        _origSpawnDmgText = nil
    end
end

-- ============================================================================
-- T1: master_tower — slot4 默认锁定
-- ============================================================================
local function Test_MasterTower_Slot4Locked()
    print("\n-- T1: master_tower slot4 默认锁定 --")

    local t   = MakeFakeTower(0, 0, 10)
    local idx = RegisterTower(t)

    -- 先向背包加一件 range 圣器（随便一件），尝试装到 slot4
    local entry = Artifact.AddToInventory("range_booster")
    if not entry then
        -- 如果 range_booster 不存在，用 prism 替代
        entry = Artifact.AddToInventory("prism")
    end
    local invIdx = #GS.artifactInventory
    local ok = Artifact.EquipToTower(invIdx, idx, "slot4")

    Assert(ok == false,
        "T1a slot4 在没有 master_tower 时装备应返回 false")
    Assert(t.slots[4] == nil,
        "T1b slot4 应保持 nil")

    UnequipAll()
    PopTowers(1)
end

-- ============================================================================
-- T2: master_tower — 装备后 artExtraSlots = 1，slot4 解锁
-- ============================================================================
local function Test_MasterTower_UnlocksSlot4()
    print("\n-- T2: master_tower 解锁 slot4 --")

    local t   = MakeFakeTower(1, 0, 10)
    local idx = RegisterTower(t)

    EquipArt("master_tower", idx, "slot1")

    Assert((t.artExtraSlots or 0) == 1,
        string.format("T2a artExtraSlots 期望1 实际%d", t.artExtraSlots or 0))

    -- 现在尝试装 slot4（装另一件圣器）
    local entry2 = Artifact.AddToInventory("prism")
    local inv2   = #GS.artifactInventory
    local ok     = Artifact.EquipToTower(inv2, idx, "slot4")

    Assert(ok == true,
        "T2b slot4 装备后应返回 true")
    Assert(t.slots[4] == inv2,
        string.format("T2c t.slots[4] 应=%d 实际=%s", inv2, tostring(t.slots[4])))

    UnequipAll()
    PopTowers(1)
end

-- ============================================================================
-- T3: master_tower — slot4 圣器效果生效
-- ============================================================================
local function Test_MasterTower_Slot4EffectApplied()
    print("\n-- T3: master_tower slot4 圣器效果生效 --")

    local t   = MakeFakeTower(2, 0, 10)
    local idx = RegisterTower(t)

    EquipArt("master_tower", idx, "slot1")
    -- 在 slot4 装 prism（transform_bullet → laser）
    local entry2 = Artifact.AddToInventory("prism")
    local inv2   = #GS.artifactInventory
    Artifact.EquipToTower(inv2, idx, "slot4")

    Assert(t.artBulletForm == "laser",
        string.format("T3a slot4 prism 生效，artBulletForm='laser' 实际='%s'", t.artBulletForm))

    UnequipAll()
    PopTowers(1)
end

-- ============================================================================
-- T4: master_tower — 卸下 master_tower 后 slot4 自动锁定（artExtraSlots=0）
-- ============================================================================
local function Test_MasterTower_RevokeLock()
    print("\n-- T4: master_tower 卸下后 artExtraSlots 归零 --")

    local t   = MakeFakeTower(3, 0, 10)
    local idx = RegisterTower(t)

    local invIdx = EquipArt("master_tower", idx, "slot1")
    Assert((t.artExtraSlots or 0) == 1, "T4a 装后 artExtraSlots=1")

    Artifact.UnequipFromTower(invIdx)
    Assert((t.artExtraSlots or 0) == 0,
        string.format("T4b 卸下后 artExtraSlots=0 实际%d", t.artExtraSlots or 0))

    GS.artifactInventory = {}
    PopTowers(1)
end

-- ============================================================================
-- T5: prism — artBulletForm = "laser" + 攻速惩罚
-- ============================================================================
local function Test_Prism_BulletForm()
    print("\n-- T5: prism 激光弹道形态 --")

    local t   = MakeFakeTower(4, 0, 10)
    local idx = RegisterTower(t)

    EquipArt("prism", idx, "slot1")

    Assert(t.artBulletForm == "laser",
        string.format("T5a artBulletForm='laser' 实际='%s'", t.artBulletForm))
    -- prism downside: attack_speed modifier = -0.667 → artAtkSpdMult = 1 * (1 - 0.667) ≈ 0.333
    Assert(Near(t.artAtkSpdMult, 1.0 - 0.667, 0.005),
        string.format("T5b artAtkSpdMult≈0.333 实际=%.4f", t.artAtkSpdMult))

    UnequipAll()
    PopTowers(1)
end

-- ============================================================================
-- T6: prism — 激光命中射程内全部怪物（伤害桩测试）
-- ============================================================================
local function Test_Prism_LaserHitsAllInRange()
    print("\n-- T6: prism 激光命中射程内全部怪物 --")

    PatchSpawnDmgText()

    -- 创建一座塔（gx=5,gz=0，delivered=20）
    local t   = MakeFakeTower(5, 0, 20)
    -- 设置 delivered 使基础伤害为 20
    -- Tower.lua 激光分支直接使用 dmg 变量，已在外层由 delivered 计算
    local idx = RegisterTower(t)
    EquipArt("prism", idx, "slot1")

    -- 塔的有效射程：默认 delivered/10 格（Artifact.GetTowerEffectiveRange 的实际逻辑需查）
    -- 为避免范围计算的不确定性，直接给两只怪物放在 (5,0,0) 附近
    -- 实际范围由 Tower.GetTowerEffectiveRange 决定；我们只验证"多怪被打"的行为

    -- 怪1: 紧贴塔（应在射程内）
    local m1 = MakeFakeMonster(200, 5.0, 0.5)   -- x=5, z=0.5，距塔 0.5 格
    -- 怪2: 距塔 1 格（应在射程内）
    local m2 = MakeFakeMonster(200, 5.0, 1.0)
    -- 怪3: 超远（距塔 50 格，应不被打到）
    local m3 = MakeFakeMonster(200, 55.0, 0.0)

    RegisterMonster(m1)
    RegisterMonster(m2)
    RegisterMonster(m3)

    -- 模拟 Tower.lua 激光逻辑（直接调用，不启动游戏循环）
    -- 为简化，用 Artifact 获取有效射程后手工执行激光分支
    local Tower = require("Tower")
    local effectiveRange = Tower.GetTowerEffectiveRange(t)

    local dmg = 10  -- 模拟基础 dmg
    local Monster = require("Monster")
    local hitList = {}
    for _, m in ipairs(GS.monsters) do
        if m.node and m.hp > 0 then
            local dx = m.node.position.x - t.gx
            local dz = m.node.position.z - t.gz
            if math.sqrt(dx*dx + dz*dz) <= effectiveRange then
                m.lastHitTower = t
                Monster.DamageMonster(m, dmg)
                table.insert(hitList, m)
            end
        end
    end

    Assert(#hitList >= 2,
        string.format("T6a 激光应命中 ≥2 只怪 实际=%d", #hitList))
    Assert(m1.hp < 200,
        string.format("T6b m1 hp 应减少 实际=%d", m1.hp))
    Assert(m2.hp < 200,
        string.format("T6c m2 hp 应减少 实际=%d", m2.hp))
    Assert(m3.hp == 200,
        string.format("T6d m3(超远) hp 应不变 实际=%d", m3.hp))

    UnequipAll()
    PopTowers(1)
    PopMonsters(3)

    RestoreSpawnDmgText()
end

-- ============================================================================
-- T7: network — 字段正确写入
-- ============================================================================
local function Test_Network_Fields()
    print("\n-- T7: network 字段写入 --")

    local t   = MakeFakeTower(6, 0, 10)
    local idx = RegisterTower(t)

    EquipArt("network", idx, "slot1")

    Assert(t.artNetworkLinks == true,
        "T7a artNetworkLinks = true")
    Assert(Near(t.artNetworkRange, 3, 0.001),
        string.format("T7b artNetworkRange=3 实际=%.1f", t.artNetworkRange))
    Assert(Near(t.artNetworkMaxLinks, 3, 0.001),
        string.format("T7c artNetworkMaxLinks=3 实际=%.1f", t.artNetworkMaxLinks))
    Assert(Near(t.artNetworkRatio, 0.35, 0.001),
        string.format("T7d artNetworkRatio=0.35 实际=%.3f", t.artNetworkRatio))
    -- 攻速惩罚 -40%: artAtkSpdMult = 1*(1-0.4) = 0.6
    Assert(Near(t.artAtkSpdMult, 0.6, 0.005),
        string.format("T7e artAtkSpdMult≈0.6 实际=%.4f", t.artAtkSpdMult))

    UnequipAll()
    PopTowers(1)
end

-- ============================================================================
-- T8: network — 卸下后字段重置
-- ============================================================================
local function Test_Network_Reset()
    print("\n-- T8: network 卸下后重置 --")

    local t   = MakeFakeTower(7, 0, 10)
    local idx = RegisterTower(t)

    local invIdx = EquipArt("network", idx, "slot1")
    Assert(t.artNetworkLinks == true, "T8a 装备后 artNetworkLinks=true")

    Artifact.UnequipFromTower(invIdx)
    Assert(t.artNetworkLinks == false,
        string.format("T8b 卸下后 artNetworkLinks=false 实际=%s", tostring(t.artNetworkLinks)))
    Assert(Near(t.artAtkSpdMult, 1.0, 0.001),
        string.format("T8c 攻速恢复1.0 实际=%.4f", t.artAtkSpdMult))

    GS.artifactInventory = {}
    PopTowers(1)
end

-- ============================================================================
-- T9: elemental_reaction — artHasElementalReaction 字段
-- ============================================================================
local function Test_ElementalReaction_Field()
    print("\n-- T9: elemental_reaction 字段写入 --")

    local t   = MakeFakeTower(8, 0, 10)
    local idx = RegisterTower(t)

    EquipArt("elemental_reaction", idx, "slot1")
    Assert(t.artHasElementalReaction == true,
        string.format("T9a artHasElementalReaction=true 实际=%s", tostring(t.artHasElementalReaction)))

    UnequipAll()
    PopTowers(1)
end

-- ============================================================================
-- T10: elemental_reaction — 蒸发 (burn + freeze) → dmg×2，双状态消耗
-- ============================================================================
local function Test_Evaporate_BurnFreeze()
    print("\n-- T10: 蒸发 (burn+freeze) 2× 伤害，双状态消耗 --")

    PatchSpawnDmgText()

    local tower = MakeFakeTower(9, 0, 10)
    tower.artHasElementalReaction = true

    local m = MakeFakeMonster(500, 9, 0)
    RegisterMonster(m)

    -- 预置 burn + freeze
    m.statusEffects.burn   = { dps = 2.0, timer = 4.0, totalDmg = 10, tickAcc = 0 }
    m.statusEffects.freeze = { stacks = 3, frozen = false, frozenTimer = 0, decayAcc = 0 }

    local hitDmg = 50
    local hpBefore = m.hp
    SE.TriggerElementalReaction(m, hitDmg, tower)
    local hpAfter = m.hp

    -- 蒸发伤害 = floor(50 * 2.0 + 0.5) = 100（无护盾、无护甲）
    local expectedDmg = math.max(1, math.floor(hitDmg * 2.0 + 0.5))
    Assert(Near(hpBefore - hpAfter, expectedDmg, 1),
        string.format("T10a 蒸发伤害=%d 期望≈%d 实际hp减少=%d",
            expectedDmg, expectedDmg, hpBefore - hpAfter))
    Assert(m.statusEffects.burn == nil,
        "T10b burn 应被消耗（nil）")
    Assert(m.statusEffects.freeze == nil,
        "T10c freeze 应被消耗（nil）")

    PopMonsters(1)
    RestoreSpawnDmgText()
end

-- ============================================================================
-- T11: elemental_reaction — 麻痹 (freeze + electric) → 感电消耗，强制冻结
-- ============================================================================
local function Test_Paralysis_FreezeElec()
    print("\n-- T11: 麻痹 (freeze+electric) 感电消耗，强制冻结 --")

    PatchSpawnDmgText()

    local tower = MakeFakeTower(10, 0, 10)
    tower.artHasElementalReaction = true

    local m = MakeFakeMonster(300, 10, 0)
    RegisterMonster(m)

    -- freeze: 尚未完全冻结（stacks=3，frozen=false）
    -- electric: 有感电
    m.statusEffects.freeze  = { stacks = 3, frozen = false, frozenTimer = 0, decayAcc = 0 }
    m.statusEffects.electric = { timer = 2.0 }

    local hpBefore = m.hp
    SE.TriggerElementalReaction(m, 40, tower)

    Assert(m.statusEffects.electric == nil,
        "T11a 感电应被消耗（nil）")
    Assert(m.statusEffects.freeze ~= nil,
        "T11b freeze 应保留")
    Assert(m.statusEffects.freeze.frozen == true,
        "T11c 应触发强制冻结 frozen=true")
    -- 无伤害（麻痹不直接造成伤害）
    Assert(m.hp == hpBefore,
        string.format("T11d 麻痹不造成直接伤害 hp=%d", m.hp))

    PopMonsters(1)
    RestoreSpawnDmgText()
end

-- ============================================================================
-- T12: elemental_reaction — 麻痹：已冻结时延长 frozenTimer
-- ============================================================================
local function Test_Paralysis_ExtendFrozen()
    print("\n-- T12: 麻痹：已冻结时延长 frozenTimer --")

    PatchSpawnDmgText()

    local tower = MakeFakeTower(11, 0, 10)
    tower.artHasElementalReaction = true

    local m = MakeFakeMonster(300, 11, 0)
    RegisterMonster(m)

    m.statusEffects.freeze   = { stacks = 0, frozen = true, frozenTimer = 1.0, decayAcc = 0 }
    m.statusEffects.electric = { timer = 2.0 }

    local timerBefore = m.statusEffects.freeze.frozenTimer
    SE.TriggerElementalReaction(m, 40, tower)

    Assert(m.statusEffects.electric == nil, "T12a 感电消耗")
    local timerAfter = m.statusEffects.freeze.frozenTimer
    Assert(Near(timerAfter, timerBefore + 2.0, 0.01),
        string.format("T12b frozenTimer 应+2.0 期望%.1f 实际%.1f", timerBefore + 2.0, timerAfter))

    PopMonsters(1)
    RestoreSpawnDmgText()
end

-- ============================================================================
-- T13: elemental_reaction — 过载 (electric + burn) → 感电消耗，AoE 溅射
-- ============================================================================
local function Test_Overload_ElecBurn()
    print("\n-- T13: 过载 (electric+burn) 溅射伤害 --")

    PatchSpawnDmgText()

    local tower = MakeFakeTower(12, 0, 10)
    tower.artHasElementalReaction = true

    -- 主目标在 (12,0)，附近 1 格内有 m2
    local m1 = MakeFakeMonster(300, 12.0, 0.0)
    local m2 = MakeFakeMonster(300, 12.5, 0.0)  -- 距离 0.5 格，在 1.5 格范围内
    local m3 = MakeFakeMonster(300, 14.0, 0.0)  -- 距离 2 格，超出 1.5 格范围
    RegisterMonster(m1)
    RegisterMonster(m2)
    RegisterMonster(m3)

    m1.statusEffects.electric = { timer = 2.0 }
    m1.statusEffects.burn     = { dps = 2.0, timer = 4.0, totalDmg = 10, tickAcc = 0 }

    local hitDmg = 40
    local expectedDmg = math.max(1, math.floor(hitDmg * 1.5 + 0.5))  -- 60

    SE.TriggerElementalReaction(m1, hitDmg, tower)

    Assert(m1.statusEffects.electric == nil,
        "T13a 感电应被消耗")
    Assert(m1.hp < 300,
        string.format("T13b m1 hp 应减少 实际=%d", m1.hp))
    Assert(m2.hp < 300,
        string.format("T13c m2(0.5格内) hp 应被溅射到 实际=%d", m2.hp))
    Assert(m3.hp == 300,
        string.format("T13d m3(2格外) hp 应不变 实际=%d", m3.hp))
    -- 溅射伤害数值校验
    Assert(Near(300 - m1.hp, expectedDmg, 1),
        string.format("T13e m1 伤害期望≈%d 实际=%d", expectedDmg, 300 - m1.hp))

    PopMonsters(3)
    RestoreSpawnDmgText()
end

-- ============================================================================
-- T14: elemental_reaction — 侵蚀 (corrode + burn) → 腐蚀消耗，爆发伤害
-- ============================================================================
local function Test_Erosion_CorrodeAny()
    print("\n-- T14: 侵蚀 (corrode+burn) 腐蚀爆发 --")

    PatchSpawnDmgText()

    local tower = MakeFakeTower(13, 0, 10)
    tower.artHasElementalReaction = true

    local m = MakeFakeMonster(500, 13, 0)
    RegisterMonster(m)

    -- corrode 3 层 + burn
    m.statusEffects.corrode = { stacks = 3, timer = 8.0 }
    m.statusEffects.burn    = { dps = 2.0, timer = 4.0, totalDmg = 10, tickAcc = 0 }

    local hitDmg = 60
    -- 侵蚀伤害 = max(1, floor(60 * 0.5 * 3 + 0.5)) = max(1, floor(90.5)) = 90
    local expectedDmg = math.max(1, math.floor(hitDmg * 0.5 * 3 + 0.5))
    local hpBefore = m.hp

    SE.TriggerElementalReaction(m, hitDmg, tower)

    Assert(m.statusEffects.corrode == nil,
        "T14a corrode 应被消耗（nil）")
    Assert(m.statusEffects.burn ~= nil,
        "T14b burn 应保留（侵蚀只消耗腐蚀）")
    Assert(Near(hpBefore - m.hp, expectedDmg, 1),
        string.format("T14c 侵蚀伤害期望≈%d 实际hp减少=%d", expectedDmg, hpBefore - m.hp))

    PopMonsters(1)
    RestoreSpawnDmgText()
end

-- ============================================================================
-- T15: elemental_reaction — 侵蚀优先级高于蒸发 (corrode+burn+freeze → 侵蚀而非蒸发)
-- ============================================================================
local function Test_Erosion_Priority()
    print("\n-- T15: 侵蚀优先级 > 蒸发 --")

    PatchSpawnDmgText()

    local tower = MakeFakeTower(14, 0, 10)
    tower.artHasElementalReaction = true

    local m = MakeFakeMonster(500, 14, 0)
    RegisterMonster(m)

    -- 同时拥有 corrode + burn + freeze
    m.statusEffects.corrode = { stacks = 2, timer = 8.0 }
    m.statusEffects.burn    = { dps = 1.0, timer = 4.0, totalDmg = 5, tickAcc = 0 }
    m.statusEffects.freeze  = { stacks = 2, frozen = false, frozenTimer = 0, decayAcc = 0 }

    local hitDmg = 40
    -- 侵蚀应触发：floor(40 * 0.5 * 2 + 0.5) = 40
    local expectedErosionDmg = math.max(1, math.floor(hitDmg * 0.5 * 2 + 0.5))
    local hpBefore = m.hp

    SE.TriggerElementalReaction(m, hitDmg, tower)

    -- 侵蚀：腐蚀消耗，burn/freeze 保留
    Assert(m.statusEffects.corrode == nil,
        "T15a corrode 被侵蚀消耗")
    Assert(m.statusEffects.burn ~= nil,
        "T15b burn 应保留（侵蚀不消耗）")
    Assert(m.statusEffects.freeze ~= nil,
        "T15c freeze 应保留（侵蚀不消耗）")
    Assert(Near(hpBefore - m.hp, expectedErosionDmg, 1),
        string.format("T15d 侵蚀伤害期望≈%d 实际=%d，确认触发的是侵蚀而非蒸发",
            expectedErosionDmg, hpBefore - m.hp))

    PopMonsters(1)
    RestoreSpawnDmgText()
end

-- ============================================================================
-- T16: elemental_reaction — 无匹配组合时不造成额外伤害
-- ============================================================================
local function Test_NoReaction_NoDmg()
    print("\n-- T16: 无匹配组合时不触发反应 --")

    PatchSpawnDmgText()

    local tower = MakeFakeTower(15, 0, 10)
    tower.artHasElementalReaction = true

    local m = MakeFakeMonster(300, 15, 0)
    RegisterMonster(m)

    -- 只有 burn，没有其他搭档
    m.statusEffects.burn = { dps = 1.0, timer = 4.0, totalDmg = 5, tickAcc = 0 }
    local hpBefore = m.hp

    SE.TriggerElementalReaction(m, 50, tower)

    Assert(m.hp == hpBefore,
        string.format("T16a 无组合时 hp 不变 实际=%d", m.hp))
    Assert(m.statusEffects.burn ~= nil,
        "T16b burn 未被消耗")

    PopMonsters(1)
    RestoreSpawnDmgText()
end

-- ============================================================================
-- T17: electric 计时器自动衰减
-- ============================================================================
local function Test_Electric_TimerDecay()
    print("\n-- T17: 感电计时器自动衰减 --")

    local m = MakeFakeMonster(100, 20, 0)
    RegisterMonster(m)

    -- 手动施加感电
    SE.ApplyElectric(m, 3.0)
    Assert(m.statusEffects.electric ~= nil,
        "T17a ApplyElectric 后 electric 不为 nil")
    Assert(Near(m.statusEffects.electric.timer, 3.0, 0.001),
        string.format("T17b timer=3.0 实际=%.3f", m.statusEffects.electric.timer))

    -- 模拟 2 秒更新
    SE.UpdateMonsterEffects(m, 2.0)
    Assert(m.statusEffects.electric ~= nil,
        "T17c 2秒后仍有感电（剩 1 秒）")
    Assert(Near(m.statusEffects.electric.timer, 1.0, 0.05),
        string.format("T17d timer≈1.0 实际=%.3f", m.statusEffects.electric.timer))

    -- 再模拟 1.5 秒 → 感电结束
    SE.UpdateMonsterEffects(m, 1.5)
    Assert(m.statusEffects.electric == nil,
        "T17e 3.5秒后感电消失")

    PopMonsters(1)
end

-- ============================================================================
-- 主入口
-- ============================================================================

function M.RunPhase3()
    passCount = 0
    failCount = 0

    print("\n========== Phase 3 圣器效果测试 开始 ==========")

    Test_MasterTower_Slot4Locked()
    Test_MasterTower_UnlocksSlot4()
    Test_MasterTower_Slot4EffectApplied()
    Test_MasterTower_RevokeLock()

    Test_Prism_BulletForm()
    Test_Prism_LaserHitsAllInRange()

    Test_Network_Fields()
    Test_Network_Reset()

    Test_ElementalReaction_Field()
    Test_Evaporate_BurnFreeze()
    Test_Paralysis_FreezeElec()
    Test_Paralysis_ExtendFrozen()
    Test_Overload_ElecBurn()
    Test_Erosion_CorrodeAny()
    Test_Erosion_Priority()
    Test_NoReaction_NoDmg()

    Test_Electric_TimerDecay()

    print(string.format("\n===== Phase 3 测试结果: %d PASS / %d FAIL =====",
        passCount, failCount))
    if failCount == 0 then
        print("[RESULT] Phase 3 全部通过 ✓")
    else
        print("[RESULT] 有测试未通过，请检查上方 FAIL 项")
    end

    return failCount == 0
end

return M
