-- ============================================================================
-- TestPhase2.lua — Phase 2 圣器效果验收测试
-- 覆盖: power_borrow / devour_line / overload_relay / energy_ammo / resonance_trigger
-- ============================================================================

local Cfg         = require("Config")
local CONFIG      = Cfg.CONFIG
local GS          = Cfg.GS
local Artifact    = require("Artifact")
local SkillSystem = require("SkillSystem")

local M = {}

-- ============================================================================
-- 测试工具（与 TestArtifacts.lua 保持一致）
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
    for _ = 1, n do
        table.remove(GS.towers)
    end
end

-- 装备圣器：返回 invIdx（背包索引），与 TestArtifacts.lua 保持一致
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
    -- 逆序卸下，避免索引错位
    for i = #GS.artifactInventory, 1, -1 do
        local entry = GS.artifactInventory[i]
        if entry and entry.towerIndex then
            Artifact.UnequipFromTower(i)
        end
    end
    GS.artifactInventory = {}
end

-- ============================================================================
-- T1: power_borrow — artFlatDmg 计算（借力圣器从周围塔吸取平攻加成）
-- ============================================================================
local function Test_PowerBorrow_FlatDmg()
    print("\n-- T1: power_borrow 借力平攻 --")

    -- 布置：src 在 (0,0)，周围 3 格内有 dst1(1,0) + dst2(0,1)
    local src  = MakeFakeTower(0, 0, 0)
    local dst1 = MakeFakeTower(1, 0, 40)   -- delivered=40
    local dst2 = MakeFakeTower(0, 1, 20)   -- delivered=20

    local srcIdx  = RegisterTower(src)
    local dst1Idx = RegisterTower(dst1)
    local dst2Idx = RegisterTower(dst2)

    EquipArt("power_borrow", srcIdx, "slot1")
    -- borrow_ratio=0.60, range=5: flatDmg = (40+20)*0.60 = 36

    Assert(Near(src.artFlatDmg, 36.0, 0.5),
        string.format("T1a artFlatDmg 期望36 实际%.2f", src.artFlatDmg))

    -- dst 自身的借力惩罚标志应被置位（artBorrowPenalty > 0）
    Assert((dst1.artBorrowPenalty or 0) > 0,
        "T1b dst1 artBorrowPenalty 应 > 0")
    Assert((dst2.artBorrowPenalty or 0) > 0,
        "T1c dst2 artBorrowPenalty 应 > 0")

    UnequipAll()
    PopTowers(3)
end

-- ============================================================================
-- T2: power_borrow — 超出 range 的塔不贡献
-- ============================================================================
local function Test_PowerBorrow_RangeFilter()
    print("\n-- T2: power_borrow 范围过滤 --")

    local src  = MakeFakeTower(0, 0, 0)
    local far  = MakeFakeTower(10, 0, 100)  -- 超出 range=5

    local srcIdx = RegisterTower(src)
    local farIdx = RegisterTower(far)

    EquipArt("power_borrow", srcIdx, "slot1")
    -- 距离10 > range5，far 不贡献

    Assert(Near(src.artFlatDmg, 0.0, 0.5),
        string.format("T2a 超距不借力 artFlatDmg 期望0 实际%.2f", src.artFlatDmg))
    Assert((far.artBorrowPenalty or 0) == 0,
        "T2b 超距不施加惩罚")

    UnequipAll()
    PopTowers(2)
end

-- ============================================================================
-- T3: devour_line — artLineMultiplier 由 line_multiplier 圣器正确叠加
-- ============================================================================
local function Test_DevourLine_Multiplier()
    print("\n-- T3: devour_line artLineMultiplier --")

    local t = MakeFakeTower(3, 3, 20)
    local idx = RegisterTower(t)

    -- 装备 devour_line: line_multiplier=2.5
    EquipArt("devour_line", idx, "slot1")

    Assert(Near(t.artLineMultiplier, 2.5, 0.001),
        string.format("T3a artLineMultiplier 期望2.5 实际%.3f", t.artLineMultiplier))

    -- 再装一件相同圣器（slot2），应叠乘: 2.5 × 2.5 = 6.25
    EquipArt("devour_line", idx, "slot2")
    Assert(Near(t.artLineMultiplier, 6.25, 0.01),
        string.format("T3b 叠乘 期望6.25 实际%.3f", t.artLineMultiplier))

    UnequipAll()
    PopTowers(1)
end

-- ============================================================================
-- T4: devour_line — 卸下后 artLineMultiplier 恢复 1.0
-- ============================================================================
local function Test_DevourLine_Reset()
    print("\n-- T4: devour_line 卸下恢复 --")

    local t = MakeFakeTower(4, 0, 20)
    local idx = RegisterTower(t)

    local invIdx = EquipArt("devour_line", idx, "slot1")
    Assert(Near(t.artLineMultiplier, 2.5, 0.001), "T4a 装备后=2.5")

    -- 卸下（UnequipFromTower 内部会调用 RecalcTowerArtifactStats）
    Artifact.UnequipFromTower(invIdx)

    Assert(Near(t.artLineMultiplier, 1.0, 0.001),
        string.format("T4b 卸下后恢复1.0 实际%.3f", t.artLineMultiplier))

    GS.artifactInventory = {}
    PopTowers(1)
end

-- ============================================================================
-- T5: overload_relay — 激活后 GS.lineDmgSkillMult 正确设为 2.5（1+1.5）
-- ============================================================================
local function Test_OverloadRelay_Activate()
    print("\n-- T5: overload_relay 激活线伤倍率 --")

    -- 先保证有能量可激活
    GS.energy = 10

    local t = MakeFakeTower(5, 0, 10)
    local idx = RegisterTower(t)
    EquipArt("overload_relay", idx, "slot1")

    local ok = SkillSystem.ActivateSkill()
    Assert(ok, "T5a ActivateSkill 返回 true")
    Assert(GS.overloadRelayActive == true, "T5b overloadRelayActive = true")
    Assert(Near(GS.lineDmgSkillMult, 2.5, 0.001),
        string.format("T5c lineDmgSkillMult 期望2.5 实际%.3f", GS.lineDmgSkillMult))
    Assert(GS.energy == 0, "T5d 能量已消耗为0")
    Assert(GS.overloadRelayTimer > 0, "T5e 计时器 > 0")

    -- 模拟 6 秒过去，效果应结束
    SkillSystem.Update(6.0)
    Assert(GS.overloadRelayActive == false, "T5f 6秒后 overloadRelayActive = false")
    Assert(Near(GS.lineDmgSkillMult, 1.0, 0.001),
        string.format("T5g 效果结束后 lineDmgSkillMult 恢复1.0 实际%.3f", GS.lineDmgSkillMult))

    UnequipAll()
    PopTowers(1)
end

-- ============================================================================
-- T6: overload_relay — 能量不足时 ActivateSkill 返回 false
-- ============================================================================
local function Test_OverloadRelay_NoEnergy()
    print("\n-- T6: overload_relay 能量不足 --")

    GS.energy = 0
    local result = SkillSystem.ActivateSkill()
    Assert(result == false, "T6a 能量为0时 ActivateSkill=false")
    Assert(GS.overloadRelayActive == false, "T6b overloadRelayActive 保持 false")

    -- 重置
    GS.lineDmgSkillMult = 1.0
end

-- ============================================================================
-- T7: energy_ammo — 激活后 GS.energyAmmoActive = true
-- ============================================================================
local function Test_EnergyAmmo_Activate()
    print("\n-- T7: energy_ammo 激活攻速加倍 --")

    GS.energy = 5

    local t = MakeFakeTower(6, 0, 10)
    local idx = RegisterTower(t)
    EquipArt("energy_ammo", idx, "slot1")

    local ok = SkillSystem.ActivateSkill()
    Assert(ok, "T7a ActivateSkill 返回 true")
    Assert(GS.energyAmmoActive == true, "T7b energyAmmoActive = true")
    Assert(GS.energyAmmoTimer > 0, "T7c 计时器 > 0")

    -- 模拟计时到期
    SkillSystem.Update(10.0)
    Assert(GS.energyAmmoActive == false, "T7d 10秒后 energyAmmoActive = false")

    UnequipAll()
    PopTowers(1)
end

-- ============================================================================
-- T8: energy_ammo — GS.energyMaxPenalty 正确累积
-- ============================================================================
local function Test_EnergyMaxPenalty()
    print("\n-- T8: energy_max_penalty 累积 --")

    local t = MakeFakeTower(7, 0, 10)
    local idx = RegisterTower(t)

    -- overload_relay 含 penalty=20, energy_ammo 含 penalty=15
    EquipArt("overload_relay", idx, "slot1")
    EquipArt("energy_ammo",    idx, "slot2")

    SkillSystem.RecalcEnergyMaxPenalty()
    Assert(Near(GS.energyMaxPenalty, 35, 0.1),
        string.format("T8a energyMaxPenalty 期望35 实际%.1f", GS.energyMaxPenalty))

    -- 全部卸下后应归零
    UnequipAll()
    SkillSystem.RecalcEnergyMaxPenalty()
    Assert(Near(GS.energyMaxPenalty, 0, 0.1),
        string.format("T8b 卸下后 energyMaxPenalty=0 实际%.1f", GS.energyMaxPenalty))

    PopTowers(1)
end

-- ============================================================================
-- T9: resonance_trigger — ActivateSkill 后写入 artNextShotMult + artNextShotPierce
-- ============================================================================
local function Test_ResonanceTrigger_Activate()
    print("\n-- T9: resonance_trigger 激活写入 --")

    GS.energy = 8

    local t = MakeFakeTower(8, 0, 10)
    local idx = RegisterTower(t)

    -- resonance_trigger: damage_mult=3.0, piercing=true
    local invIdx = EquipArt("resonance_trigger", idx, "slot1")
    Assert(invIdx ~= nil, "T9a invIdx 不为 nil")

    -- 确认背包条目的 towerIndex 正确
    local entry = GS.artifactInventory[invIdx]
    Assert(entry ~= nil and entry.towerIndex == idx,
        string.format("T9b entry.towerIndex=%s 期望=%d",
            entry and tostring(entry.towerIndex) or "nil", idx))

    SkillSystem.ActivateSkill()

    Assert(Near(t.artNextShotMult, 3.0, 0.001),
        string.format("T9c artNextShotMult 期望3.0 实际%.3f", t.artNextShotMult))
    Assert(t.artNextShotPierce == true,
        "T9d artNextShotPierce 应为 true")

    UnequipAll()
    PopTowers(1)
end

-- ============================================================================
-- T10: resonance_trigger — 消耗后 artNextShotMult 恢复 1.0（模拟 Tower.lua 消耗逻辑）
-- ============================================================================
local function Test_ResonanceTrigger_Consume()
    print("\n-- T10: resonance_trigger 消耗后归位 --")

    local t = MakeFakeTower(9, 0, 10)
    Artifact.InitTowerSlots(t)

    -- 直接模拟 SkillSystem 写入
    t.artNextShotMult   = 3.0
    t.artNextShotPierce = true
    t.artPierceCount    = t.artPierceCount or 0

    -- 模拟 Tower.lua 消耗逻辑（抄自 Tower.lua UpdateTowerAttacks）
    local nextMult = t.artNextShotMult or 1.0
    local dmg = 10
    if nextMult > 1.0 then
        dmg = dmg * nextMult                -- 10 × 3.0 = 30
        t.artNextShotMult = 1.0             -- 消耗
        if t.artNextShotPierce then
            t.artPierceCount = (t.artPierceCount or 0) + 1
            t._resonancePierceAdded = true
        end
    end
    -- 开火后撤销穿透临时叠加
    if t._resonancePierceAdded then
        t.artPierceCount = math.max(0, (t.artPierceCount or 1) - 1)
        t.artNextShotPierce = false
        t._resonancePierceAdded = false
    end

    Assert(Near(dmg, 30.0, 0.1),
        string.format("T10a 伤害×3 期望30 实际%.1f", dmg))
    Assert(Near(t.artNextShotMult, 1.0, 0.001),
        string.format("T10b 消耗后 artNextShotMult=1.0 实际%.3f", t.artNextShotMult))
    Assert(t.artNextShotPierce == false,
        "T10c 消耗后 artNextShotPierce=false")
    Assert((t.artPierceCount or 0) == 0,
        string.format("T10d 临时穿透已撤销 artPierceCount=0 实际=%d", t.artPierceCount or 0))
end

-- ============================================================================
-- T11: SkillSystem.Update — skillActive 在所有效果结束后变 false
-- ============================================================================
local function Test_SkillActive_ClearsAfterExpiry()
    print("\n-- T11: skillActive 在所有效果结束后清零 --")

    -- 手动注入两个 buff
    GS.overloadRelayActive = true
    GS.overloadRelayTimer  = 1.0
    GS.lineDmgSkillMult    = 2.5
    GS.energyAmmoActive    = true
    GS.energyAmmoTimer     = 2.0

    -- 推进 1.5 秒: overload 到期，energy_ammo 还剩 0.5s
    SkillSystem.Update(1.5)
    Assert(GS.overloadRelayActive == false, "T11a 1.5s后 overloadRelay 结束")
    Assert(GS.energyAmmoActive    == true,  "T11b 1.5s后 energyAmmo 仍活跃")
    Assert(GS.skillActive         == true,  "T11c skillActive 仍为 true")

    -- 再推进 1 秒: energy_ammo 到期
    SkillSystem.Update(1.0)
    Assert(GS.energyAmmoActive == false, "T11d 2.5s后 energyAmmo 结束")
    Assert(GS.skillActive      == false, "T11e skillActive = false（全部结束）")

    -- 清理
    GS.lineDmgSkillMult = 1.0
end

-- ============================================================================
-- T12: power_borrow + artBorrowPenalty 数值校验
-- ============================================================================
local function Test_PowerBorrow_PenaltyVal()
    print("\n-- T12: power_borrow 惩罚值数值校验 --")

    local src  = MakeFakeTower(0, 0, 0)
    local dst  = MakeFakeTower(2, 0, 50)  -- 距离2 < range5

    local srcIdx = RegisterTower(src)
    local dstIdx = RegisterTower(dst)

    EquipArt("power_borrow", srcIdx, "slot1")
    -- power_borrow 的 nearby_attack_speed_penalty: penalty=-0.10
    -- artBorrowPenalty = abs(-0.10) = 0.10

    Assert(Near(dst.artBorrowPenalty, 0.10, 0.001),
        string.format("T12a dst.artBorrowPenalty 期望0.10 实际%.4f", dst.artBorrowPenalty))

    -- src 自身不受惩罚
    Assert(Near(src.artBorrowPenalty, 0.0, 0.001),
        string.format("T12b src.artBorrowPenalty 期望0 实际%.4f", src.artBorrowPenalty))

    UnequipAll()
    PopTowers(2)
end

-- ============================================================================
-- 主入口
-- ============================================================================

function M.RunPhase2()
    passCount = 0
    failCount = 0

    print("\n========== Phase 2 圣器效果测试 开始 ==========")

    -- 确保测试时 GS 状态干净
    GS.energy           = 0
    GS.skillActive      = false
    GS.overloadRelayActive = false
    GS.overloadRelayTimer  = 0
    GS.lineDmgSkillMult    = 1.0
    GS.energyAmmoActive    = false
    GS.energyAmmoTimer     = 0
    GS.energyMaxPenalty    = 0

    Test_PowerBorrow_FlatDmg()
    Test_PowerBorrow_RangeFilter()
    Test_DevourLine_Multiplier()
    Test_DevourLine_Reset()
    Test_OverloadRelay_Activate()
    Test_OverloadRelay_NoEnergy()
    Test_EnergyAmmo_Activate()
    Test_EnergyMaxPenalty()
    Test_ResonanceTrigger_Activate()
    Test_ResonanceTrigger_Consume()
    Test_SkillActive_ClearsAfterExpiry()
    Test_PowerBorrow_PenaltyVal()

    print(string.format("\n===== Phase 2 测试结果: %d PASS / %d FAIL =====",
        passCount, failCount))
    if failCount == 0 then
        print("[RESULT] Phase 2 全部通过，可以进入 Phase 3")
    else
        print("[RESULT] 有测试未通过，请检查上方 FAIL 项")
    end

    return failCount == 0
end

return M
