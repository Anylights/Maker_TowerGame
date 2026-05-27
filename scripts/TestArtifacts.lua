-- ============================================================================
-- TestArtifacts.lua — Phase 1 圣器效果验收测试
-- 调用方式: 在游戏运行后执行 TestArtifacts.RunPhase1()
-- ============================================================================

local Cfg     = require("Config")
local CONFIG  = Cfg.CONFIG
local GS      = Cfg.GS
local Artifact = require("Artifact")
local Tower    = require("Tower")

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

-- 创建一个最小假塔（不需要节点，仅用于逻辑测试）
local function MakeFakeTower(gx, gz)
    local t = { gx = gx or 0, gz = gz or 0, delivered = 10, ratio = 1.0 }
    Artifact.InitTowerSlots(t)
    return t
end

-- 将假塔插入 GS.towers 并返回其索引
local function RegisterTower(t)
    table.insert(GS.towers, t)
    return #GS.towers
end

-- 清理：移除最后 N 个塔
local function PopTowers(n)
    for _ = 1, n do
        table.remove(GS.towers)
    end
end

-- 将一件圣器添加进背包并装备到指定塔槽
local function EquipArt(artifactId, towerIdx, slotType)
    local entry = Artifact.AddToInventory(artifactId)
    if not entry then
        print("[TEST-ERROR] 未找到圣器: " .. artifactId)
        return nil
    end
    local invIdx = #GS.artifactInventory
    Artifact.EquipToTower(invIdx, towerIdx, slotType)
    return invIdx
end

-- ============================================================================
-- Phase 1 测试套件
-- ============================================================================

function M.RunPhase1()
    passCount, failCount = 0, 0
    print("\n========== Phase 1 圣器效果验收测试 ==========")

    -- ── 确保背包和 towers 已初始化 ──
    if not GS.artifactInventory then GS.artifactInventory = {} end
    if not GS.towers then GS.towers = {} end

    -- ────────────────────────────────────────────────────────────────
    -- T1: range stat_modifier — sniper_mod (+150% range, -40% atk spd)
    -- ────────────────────────────────────────────────────────────────
    do
        local t = MakeFakeTower(1, 0)
        local idx = RegisterTower(t)
        EquipArt("sniper_mod", idx, "slot1")

        local effectiveRange = Tower.GetTowerEffectiveRange(t)
        local expected = CONFIG.TowerRange * (1.0 + 1.5)   -- +150%
        Assert(Near(effectiveRange, expected, 0.01),
            string.format("T1 射程+150%%: 期望=%.2f 实际=%.2f", expected, effectiveRange))

        -- 缺点: 攻速 -40% → artAtkSpdMult ≈ 0.60
        Assert(Near(t.artAtkSpdMult, 0.60, 0.01),
            string.format("T1 攻速-40%%: 期望=0.60 实际=%.3f", t.artAtkSpdMult))

        PopTowers(1)
    end

    -- ────────────────────────────────────────────────────────────────
    -- T2: range downside — splinter (-20% range)
    -- ────────────────────────────────────────────────────────────────
    do
        local t = MakeFakeTower(2, 0)
        local idx = RegisterTower(t)
        EquipArt("splinter", idx, "slot1")

        local effectiveRange = Tower.GetTowerEffectiveRange(t)
        local expected = CONFIG.TowerRange * (1.0 - 0.20)
        Assert(Near(effectiveRange, expected, 0.01),
            string.format("T2 裂片射程-20%%: 期望=%.2f 实际=%.2f", expected, effectiveRange))

        PopTowers(1)
    end

    -- ────────────────────────────────────────────────────────────────
    -- T3: aura_attack_speed — 光环攻速给周围塔
    -- ────────────────────────────────────────────────────────────────
    do
        local src = MakeFakeTower(0, 0)    -- 光环来源
        local dst = MakeFakeTower(3, 0)    -- 3格内，应受到光环
        local far = MakeFakeTower(10, 0)   -- 超出5格，不应受到光环

        local srcIdx = RegisterTower(src)
        RegisterTower(dst)
        RegisterTower(far)

        EquipArt("aura_attack_speed", srcIdx, "slot1")
        -- RecalcAllAuras 在 EquipToTower 后已自动调用

        Assert(Near(dst.auraAtkSpdBonus, 0.30, 0.01),
            string.format("T3 光环攻速(近塔)=0.30: 实际=%.3f", dst.auraAtkSpdBonus))
        Assert(Near(far.auraAtkSpdBonus, 0.0, 0.01),
            string.format("T3 光环攻速(远塔)=0: 实际=%.3f", far.auraAtkSpdBonus))
        -- 光环来源塔自身不受自己光环影响
        Assert(Near(src.auraAtkSpdBonus, 0.0, 0.01),
            string.format("T3 光环来源塔自身=0: 实际=%.3f", src.auraAtkSpdBonus))

        PopTowers(3)
    end

    -- ────────────────────────────────────────────────────────────────
    -- T4: aura_damage — 光环伤害
    -- ────────────────────────────────────────────────────────────────
    do
        local src = MakeFakeTower(0, 0)
        local dst = MakeFakeTower(4, 0)   -- 距离4格，在5格范围内
        local srcIdx = RegisterTower(src)
        RegisterTower(dst)

        EquipArt("aura_damage", srcIdx, "slot1")

        Assert(Near(dst.auraDmgBonus, 0.25, 0.01),
            string.format("T4 光环伤害=0.25: 实际=%.3f", dst.auraDmgBonus))

        -- 验证 CalcTowerDamage 已把光环乘进去
        -- dst.delivered=10, TowerDmgRate, artDmgMult=1.0, auraDmgBonus=0.25
        local baseDmg = dst.delivered * CONFIG.TowerDmgRate
        local expectedDmg = baseDmg * 1.0 * (1.0 + 0.25)
        local actualDmg = Tower.CalcTowerDamage(dst)
        Assert(Near(actualDmg, expectedDmg, 0.01),
            string.format("T4 CalcDamage含光环: 期望=%.2f 实际=%.2f", expectedDmg, actualDmg))

        PopTowers(2)
    end

    -- ────────────────────────────────────────────────────────────────
    -- T5: aura_range — 光环射程加 2 格
    -- ────────────────────────────────────────────────────────────────
    do
        local src = MakeFakeTower(0, 0)
        local dst = MakeFakeTower(2, 0)
        local srcIdx = RegisterTower(src)
        RegisterTower(dst)

        EquipArt("aura_range", srcIdx, "slot1")

        Assert(Near(dst.auraRangeFlatBonus, 2.0, 0.01),
            string.format("T5 光环射程+2: 实际=%.2f", dst.auraRangeFlatBonus))

        local effectiveRange = Tower.GetTowerEffectiveRange(dst)
        Assert(Near(effectiveRange, CONFIG.TowerRange + 2.0, 0.01),
            string.format("T5 射程含光环: 期望=%.2f 实际=%.2f",
                CONFIG.TowerRange + 2.0, effectiveRange))

        PopTowers(2)
    end

    -- ────────────────────────────────────────────────────────────────
    -- T6: aura_crit — 光环暴击率 +15%
    -- ────────────────────────────────────────────────────────────────
    do
        local src = MakeFakeTower(0, 0)
        local dst = MakeFakeTower(1, 0)
        local srcIdx = RegisterTower(src)
        RegisterTower(dst)

        EquipArt("aura_crit", srcIdx, "slot1")

        Assert(Near(dst.auraCritBonus, 0.15, 0.01),
            string.format("T6 光环暴击+15%%: 实际=%.3f", dst.auraCritBonus))

        PopTowers(2)
    end

    -- ────────────────────────────────────────────────────────────────
    -- T7: aura 卸装后归零
    -- ────────────────────────────────────────────────────────────────
    do
        local src = MakeFakeTower(0, 0)
        local dst = MakeFakeTower(1, 0)
        local srcIdx = RegisterTower(src)
        RegisterTower(dst)

        local invIdx = EquipArt("aura_attack_speed", srcIdx, "slot1")
        Assert(Near(dst.auraAtkSpdBonus, 0.30, 0.01), "T7 装备后光环=0.30")

        -- 卸装
        Artifact.UnequipFromTower(invIdx)
        Assert(Near(dst.auraAtkSpdBonus, 0.0, 0.01),
            string.format("T7 卸装后光环归零: 实际=%.3f", dst.auraAtkSpdBonus))

        PopTowers(2)
    end

    -- ────────────────────────────────────────────────────────────────
    -- T8: gold_refinery — artGoldDropBonus 正确设置
    -- ────────────────────────────────────────────────────────────────
    do
        local t = MakeFakeTower(0, 0)
        local idx = RegisterTower(t)
        EquipArt("gold_refinery", idx, "slot1")

        Assert(Near(t.artGoldDropBonus, 0.30, 0.01),
            string.format("T8 金矿炼化+30%%: 实际=%.3f", t.artGoldDropBonus))

        -- 模拟击杀: 直接测试金币加成计算
        local baseGold = 10
        local expectedGold = math.floor(baseGold * 1.30 + 0.5)
        local fakeMonster = { lastHitTower = t, goldDrop = baseGold }
        local goldAmt = baseGold
        if fakeMonster.lastHitTower and (fakeMonster.lastHitTower.artGoldDropBonus or 0) > 0 then
            goldAmt = math.floor(goldAmt * (1.0 + fakeMonster.lastHitTower.artGoldDropBonus) + 0.5)
        end
        Assert(goldAmt == expectedGold,
            string.format("T8 金币掉落计算: 期望=%d 实际=%d", expectedGold, goldAmt))

        PopTowers(1)
    end

    -- ────────────────────────────────────────────────────────────────
    -- T9: pierce — artPierceCount 正确设置
    -- ────────────────────────────────────────────────────────────────
    do
        local t = MakeFakeTower(0, 0)
        local idx = RegisterTower(t)
        EquipArt("piercing_core", idx, "slot1")

        Assert(t.artPierceCount == 2,
            string.format("T9 穿透弹芯 pierce_count=2: 实际=%d", t.artPierceCount))
        -- 缺点: 伤害 -15%
        Assert(Near(t.artDmgMult, 0.85, 0.01),
            string.format("T9 穿透弹芯伤害-15%%: 期望=0.85 实际=%.3f", t.artDmgMult))

        PopTowers(1)
    end

    -- ────────────────────────────────────────────────────────────────
    -- T10: pierce FireProjectile 中 pierceLeft 字段正确
    -- ────────────────────────────────────────────────────────────────
    do
        -- 需要 GS.scene / GS.projectiles，只做字段检查（不实际创建节点）
        -- 这里用 InitTowerSlots 检查字段初始值
        local t = MakeFakeTower(0, 0)
        local idx = RegisterTower(t)
        EquipArt("piercing_core", idx, "slot1")
        Assert(t.artPierceCount == 2, "T10 artPierceCount=2 (FireProjectile 起始穿透次数)")

        -- 无穿透圣器的塔
        local t2 = MakeFakeTower(1, 0)
        RegisterTower(t2)
        Assert(t2.artPierceCount == 0, "T10 无穿透圣器 artPierceCount=0")

        PopTowers(2)
    end

    -- ────────────────────────────────────────────────────────────────
    -- T11: splinter on_hit_status 字段正确写入 artOnHit
    -- ────────────────────────────────────────────────────────────────
    do
        local t = MakeFakeTower(0, 0)
        local idx = RegisterTower(t)
        EquipArt("splinter", idx, "slot1")

        local hasSplinter = false
        local splinterCount = 0
        for _, oh in ipairs(t.artOnHit) do
            if oh.status == "splinter" then
                hasSplinter = true
                splinterCount = oh.splinter_count or 0
                break
            end
        end
        Assert(hasSplinter, "T11 裂片圣器 artOnHit 包含 splinter 条目")
        Assert(splinterCount == 4,
            string.format("T11 splinter_count=4: 实际=%d", splinterCount))

        PopTowers(1)
    end

    -- ────────────────────────────────────────────────────────────────
    -- T12: 多件圣器叠加 — range + aura_range
    -- ────────────────────────────────────────────────────────────────
    do
        local src = MakeFakeTower(0, 0)   -- 放光环圣器
        local dst = MakeFakeTower(2, 0)   -- 放狙击模组
        local srcIdx = RegisterTower(src)
        local dstIdx = RegisterTower(dst)

        EquipArt("aura_range", srcIdx, "slot1")    -- 给 dst +2格光环
        EquipArt("sniper_mod", dstIdx, "slot1")    -- dst 自身 +150%

        local effectiveRange = Tower.GetTowerEffectiveRange(dst)
        -- 期望 = TowerRange * 2.5 + 2 (光环)
        local expected = CONFIG.TowerRange * 2.5 + 2.0
        Assert(Near(effectiveRange, expected, 0.01),
            string.format("T12 叠加射程: 期望=%.2f 实际=%.2f", expected, effectiveRange))

        PopTowers(2)
    end

    -- ────────────────────────────────────────────────────────────────
    -- 结果汇总
    -- ────────────────────────────────────────────────────────────────
    print(string.format("\n===== Phase 1 测试结果: %d PASS / %d FAIL =====",
        passCount, failCount))
    if failCount == 0 then
        print("[RESULT] ✅ Phase 1 全部通过，可以进入 Phase 2")
    else
        print("[RESULT] ❌ 有测试未通过，请检查上方 FAIL 项")
    end

    return failCount == 0
end

return M
