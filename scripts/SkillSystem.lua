-- ============================================================================
-- SkillSystem.lua — 主动技能激活 + 计时管理
-- Phase 2 圣器: overload_relay / energy_ammo / resonance_trigger
-- ============================================================================

local Cfg = require("Config")
local GS = Cfg.GS

local M = {}

-- 技能消耗最低能量
local SKILL_MIN_ENERGY = 1

-- ============================================================================
-- 重算能量上限惩罚（每次装备/卸下时调用）
-- 扫描所有已装备圣器的 energy_max_penalty 效果
-- ============================================================================
function M.RecalcEnergyMaxPenalty()
    local total = 0
    for _, entry in ipairs(GS.artifactInventory) do
        if entry.equipped and entry.def then
            for _, eff in ipairs(entry.def.effects or {}) do
                if eff.type == "custom" and eff.logic_id == "energy_max_penalty" then
                    total = total + math.abs(eff.penalty or 0)
                end
            end
        end
    end
    GS.energyMaxPenalty = total
end

-- ============================================================================
-- 激活主动技能 (消耗当前全部能量)
-- 返回 true 表示成功激活
-- ============================================================================
function M.ActivateSkill()
    if GS.energy < SKILL_MIN_ENERGY then
        print("[Skill] 能量不足，无法激活技能 (当前=" .. GS.energy .. ")")
        return false
    end

    local spentEnergy = GS.energy
    GS.energy = 0
    GS.skillActive = true

    print(string.format("[Skill] 激活技能！消耗能量=%d", spentEnergy))

    -- 扫描所有已装备的技能触发类圣器
    for _, entry in ipairs(GS.artifactInventory) do
        if entry.equipped and entry.def then
            for _, eff in ipairs(entry.def.effects or {}) do
                if eff.type == "custom" then
                    -- 过载继电器: 全段线伤+150% 持续 5 秒
                    if eff.logic_id == "overload_relay" then
                        local bonus = eff.line_dmg_bonus or 1.5
                        local dur   = eff.duration or 5
                        GS.lineDmgSkillMult = 1.0 + bonus
                        GS.overloadRelayActive = true
                        GS.overloadRelayTimer = dur
                        print(string.format("[Skill] 过载继电器激活: 线伤×%.1f, 持续%.1f秒",
                            GS.lineDmgSkillMult, dur))
                    end

                    -- 注能弹药: 全塔攻速+100% 持续 5 秒
                    if eff.logic_id == "energy_ammo" then
                        local dur = eff.duration or 5
                        GS.energyAmmoActive = true
                        GS.energyAmmoTimer = dur
                        print(string.format("[Skill] 注能弹药激活: 攻速×2, 持续%.1f秒", dur))
                    end

                    -- 共振触发: 此塔下次攻击×3+穿透
                    if eff.logic_id == "resonance_trigger" then
                        local towerIdx = entry.towerIndex
                        if towerIdx and GS.towers[towerIdx] then
                            local t = GS.towers[towerIdx]
                            t.artNextShotMult   = eff.damage_mult or 3.0
                            t.artNextShotPierce = eff.piercing or false
                            print(string.format("[Skill] 共振触发激活: Tower[%d] 下次×%.1f%s",
                                towerIdx, t.artNextShotMult,
                                t.artNextShotPierce and "+穿透" or ""))
                        end
                    end
                end
            end
        end
    end

    return true
end

-- ============================================================================
-- 每帧更新计时器（在 main.lua HandleUpdate 里调用）
-- ============================================================================
function M.Update(dt)
    -- 过载继电器倒计时
    if GS.overloadRelayActive then
        GS.overloadRelayTimer = GS.overloadRelayTimer - dt
        if GS.overloadRelayTimer <= 0 then
            GS.overloadRelayActive = false
            GS.overloadRelayTimer = 0
            GS.lineDmgSkillMult = 1.0
            print("[Skill] 过载继电器效果结束")
        end
    end

    -- 注能弹药倒计时
    if GS.energyAmmoActive then
        GS.energyAmmoTimer = GS.energyAmmoTimer - dt
        if GS.energyAmmoTimer <= 0 then
            GS.energyAmmoActive = false
            GS.energyAmmoTimer = 0
            print("[Skill] 注能弹药效果结束")
        end
    end

    -- 整合 skillActive 标志
    GS.skillActive = GS.overloadRelayActive or GS.energyAmmoActive
end

return M
