-- ============================================================================
-- GameUI.lua — UI 初始化 / HUD 刷新 / 升级面板 / 波次信息 / GameOver
-- ============================================================================

local UI = require("urhox-libs/UI")
local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS

local M = {}

-- UI 控件引用
local goldLabel_ = nil
local materialLabel_ = nil
local energyLabel_ = nil
local costLabel_ = nil
local statsLabel_ = nil
local hintLabel_ = nil
local waveLabel_ = nil
local powerLabel_ = nil
local previewLabel_ = nil

-- 速度指示器
local speedLabel_ = nil

-- 升级面板
local upgradePanel_ = nil
local upgradeLevelLabel_ = nil
local upgradeInfoLabel_ = nil
local upgradeCostLabel_ = nil
local upgradeBtn_ = nil
local upgradePanelVisible_ = false

-- 游戏主 HUD root（用于切换到 GameOver/Victory 时替换）
local hudRoot_ = nil

-- ============================================================================
-- 初始化
-- ============================================================================

function M.InitUI()
    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/MiSans-Regular.ttf",
            } }
        },
        scale = UI.Scale.DEFAULT,
    })
end

function M.CreateGameUI()
    -- 三资源标签
    goldLabel_ = UI.Label {
        text = "",
        fontSize = 15,
        fontColor = { 255, 215, 0, 255 },
    }
    materialLabel_ = UI.Label {
        text = "",
        fontSize = 15,
        fontColor = { 100, 220, 120, 255 },
    }
    energyLabel_ = UI.Label {
        text = "",
        fontSize = 15,
        fontColor = { 100, 180, 255, 255 },
    }
    costLabel_ = UI.Label {
        text = "",
        fontSize = 12,
        fontColor = { 200, 200, 200, 200 },
    }
    statsLabel_ = UI.Label {
        text = "",
        fontSize = 13,
        fontColor = { 180, 220, 255, 230 },
    }
    waveLabel_ = UI.Label {
        text = "",
        fontSize = 14,
        fontColor = { 255, 220, 140, 240 },
    }
    previewLabel_ = UI.Label {
        text = "",
        fontSize = 11,
        fontColor = { 200, 200, 180, 180 },
    }
    powerLabel_ = UI.Label {
        text = "",
        fontSize = 12,
        fontColor = { 140, 200, 255, 220 },
    }
    hintLabel_ = UI.Label {
        text = "Left Click: Build Tower | Middle Drag: Pan | Scroll: Zoom",
        fontSize = 12,
        fontColor = { 255, 255, 230, 160 },
        position = "absolute",
        bottom = 10, left = 0, right = 0,
        textAlign = "center",
    }

    speedLabel_ = UI.Label {
        text = "x1",
        fontSize = 14,
        fontColor = { 180, 255, 180, 220 },
    }

    -- 升级面板组件
    upgradeLevelLabel_ = UI.Label {
        text = "",
        fontSize = 16,
        fontColor = { 255, 220, 80, 255 },
    }
    upgradeInfoLabel_ = UI.Label {
        text = "",
        fontSize = 12,
        fontColor = { 200, 220, 240, 220 },
    }
    upgradeCostLabel_ = UI.Label {
        text = "",
        fontSize = 12,
        fontColor = { 200, 200, 200, 200 },
    }
    upgradeBtn_ = UI.Button {
        text = "Upgrade",
        variant = "primary",
        width = 120,
        height = 32,
        fontSize = 14,
        onClick = function(self)
            local EnergyTower = require("EnergyTower")
            if EnergyTower.Upgrade() then
                M.RefreshUpgradePanel()
                -- 升级后范围可能变化，需要更新范围圈
                local Scene = require("Scene")
                if Scene.UpdateRangeCircle then
                    Scene.UpdateRangeCircle()
                end
            end
        end,
    }

    upgradePanel_ = UI.Panel {
        position = "absolute",
        bottom = 50, left = 8,
        flexDirection = "column", gap = 6,
        backgroundColor = { 15, 20, 35, 210 },
        borderRadius = 8, paddingX = 14, paddingY = 10,
        borderWidth = 1, borderColor = { 80, 140, 200, 180 },
        display = "none",
        children = {
            upgradeLevelLabel_,
            upgradeInfoLabel_,
            upgradeCostLabel_,
            upgradeBtn_,
        }
    }

    hudRoot_ = UI.Panel {
        width = "100%", height = "100%",
        pointerEvents = "box-none",
        children = {
            -- 顶部状态栏
            UI.Panel {
                position = "absolute", top = 8, left = 8, right = 8,
                flexDirection = "row", justifyContent = "space-between",
                alignItems = "flex-start",
                pointerEvents = "box-none",
                children = {
                    -- 左：三资源 + 造塔费用
                    UI.Panel {
                        flexDirection = "column", gap = 3,
                        backgroundColor = { 0, 0, 0, 140 },
                        borderRadius = 6, paddingX = 12, paddingY = 8,
                        children = { goldLabel_, materialLabel_, energyLabel_, costLabel_ }
                    },
                    -- 中：波次信息 + 下一波预告 + 速度
                    UI.Panel {
                        flexDirection = "column", gap = 3,
                        backgroundColor = { 0, 0, 0, 140 },
                        borderRadius = 6, paddingX = 12, paddingY = 8,
                        alignItems = "center",
                        children = { waveLabel_, previewLabel_, speedLabel_ }
                    },
                    -- 右：能源统计 + 功率守恒
                    UI.Panel {
                        flexDirection = "column", gap = 3,
                        backgroundColor = { 0, 0, 0, 140 },
                        borderRadius = 6, paddingX = 12, paddingY = 8,
                        children = { statsLabel_, powerLabel_ }
                    },
                }
            },
            -- 升级面板 (左下角)
            upgradePanel_,
            -- 底部提示
            hintLabel_,
        }
    }
    UI.SetRoot(hudRoot_)

    M.RefreshUI()
end

-- ============================================================================
-- 升级面板刷新
-- ============================================================================

function M.RefreshUpgradePanel()
    local EnergyTower = require("EnergyTower")
    local stats = EnergyTower.GetLevelStats()

    if upgradeLevelLabel_ then
        upgradeLevelLabel_:SetText(string.format("Energy Tower  Lv.%d", GS.etLevel))
    end

    if upgradeInfoLabel_ then
        upgradeInfoLabel_:SetText(string.format(
            "Power: %d  HP: %d/%d  Range: %d  Eff: %.2f",
            stats.power, GS.etHP, GS.etMaxHP, stats.radius, stats.convEff
        ))
    end

    local cost = EnergyTower.GetUpgradeCost()
    if cost then
        if upgradeCostLabel_ then
            upgradeCostLabel_:SetText(string.format(
                "Cost: %d Gold + %d Material", cost.gold, cost.material
            ))
        end
        if upgradeBtn_ then
            local canUp = EnergyTower.CanUpgrade()
            upgradeBtn_:SetText(canUp and "Upgrade" or "Insufficient")
            upgradeBtn_:SetDisabled(not canUp)
        end
    else
        if upgradeCostLabel_ then
            upgradeCostLabel_:SetText("MAX LEVEL")
        end
        if upgradeBtn_ then
            upgradeBtn_:SetText("Max Lv.")
            upgradeBtn_:SetDisabled(true)
        end
    end
end

function M.ShowUpgradePanel()
    if not upgradePanel_ then return end
    upgradePanel_:SetStyle({ display = "flex" })
    upgradePanelVisible_ = true
    M.RefreshUpgradePanel()
end

function M.HideUpgradePanel()
    if not upgradePanel_ then return end
    upgradePanel_:SetStyle({ display = "none" })
    upgradePanelVisible_ = false
end

-- ============================================================================
-- 每帧刷新 HUD
-- ============================================================================

function M.RefreshUI()
    local Tower = require("Tower")
    local Wave = require("Wave")

    local cost = Tower.GetTowerCost()
    local canBuild = GS.gold >= cost

    -- 三资源
    if goldLabel_ then
        goldLabel_:SetText("Gold: " .. GS.gold)
    end
    if materialLabel_ then
        materialLabel_:SetText("Material: " .. GS.material)
    end
    if energyLabel_ then
        energyLabel_:SetText("Energy: " .. GS.energy)
    end
    if costLabel_ then
        local costStr = "Next tower: " .. cost
        if not canBuild then
            costStr = costStr .. "  (insufficient)"
        end
        costLabel_:SetText(costStr)
    end

    -- 能源统计 + 等级
    local EnergyTower = require("EnergyTower")
    if statsLabel_ then
        local n = #GS.towers
        local nm = #GS.monsters
        if n == 0 then
            statsLabel_:SetText(string.format(
                "Lv.%d | HP: %d/%d | Towers: 0 | Mobs: %d",
                GS.etLevel, GS.etHP, GS.etMaxHP, nm
            ))
        else
            statsLabel_:SetText(string.format(
                "Lv.%d | HP: %d/%d | T: %d | M: %d",
                GS.etLevel, GS.etHP, GS.etMaxHP, n, nm
            ))
        end
    end

    -- 功率守恒 HUD
    if powerLabel_ then
        local n = #GS.towers
        if n == 0 then
            local totalP = EnergyTower.GetTotalPower()
            powerLabel_:SetText(string.format("P_total: %d | Idle", totalP))
        else
            local totalP = EnergyTower.GetTotalPower()
            local sumDel = 0
            local sumLine = 0
            for _, t in ipairs(GS.towers) do
                sumDel = sumDel + t.delivered
                sumLine = sumLine + t.linePwr
            end
            local convEff = EnergyTower.GetConvEff()
            local lineDps = sumLine * CONFIG.LineDmgCoeff * convEff
            powerLabel_:SetText(string.format(
                "P: %d = Del %.0f + Line %.0f | DPS: %.1f",
                totalP, sumDel, sumLine, lineDps
            ))
        end
    end

    -- 速度指示器
    if speedLabel_ then
        local spd = GS.gameSpeed
        if spd == 1 then
            speedLabel_:SetText("[Tab] Speed: x1")
            speedLabel_:SetStyle({ fontColor = { 180, 255, 180, 220 } })
        elseif spd == 2 then
            speedLabel_:SetText("[Tab] Speed: x2 >>")
            speedLabel_:SetStyle({ fontColor = { 255, 255, 100, 240 } })
        else
            speedLabel_:SetText("[Tab] Speed: x4 >>>>")
            speedLabel_:SetStyle({ fontColor = { 255, 140, 80, 255 } })
        end
    end

    -- 波次信息
    if waveLabel_ then
        waveLabel_:SetText(Wave.GetWaveInfo())
    end

    -- 下一波预告
    if previewLabel_ then
        local preview = Wave.GetNextWavePreview()
        if preview then
            previewLabel_:SetText(string.format("Next: %s (%d)", preview.summary, preview.totalMonsters))
        else
            previewLabel_:SetText("")
        end
    end

    -- 升级面板实时刷新（如果可见）
    if upgradePanelVisible_ then
        M.RefreshUpgradePanel()
    end

    -- 悬停提示 + 升级面板显隐
    M.UpdateHintLabel()
end

-- ============================================================================
-- 悬停提示文本 + 升级面板触发
-- ============================================================================

function M.UpdateHintLabel()
    if not hintLabel_ then return end

    local Tower = require("Tower")
    local EnergyTower = require("EnergyTower")

    if not GS.hoverOnMap then
        hintLabel_:SetText("LClick: Build | X: Sell | U: Upgrade | Tab: Speed | MMB: Pan | Scroll: Zoom | Space: Skip")
        if upgradePanelVisible_ then
            M.HideUpgradePanel()
        end
        return
    end

    local gx, gz = GS.hoverGX, GS.hoverGZ
    local dist = math.sqrt(gx * gx + gz * gz)
    local inRange = dist <= EnergyTower.GetEnergyRange() + 0.01
    local isEnergyTower = (gx == 0 and gz == 0)
    local isOccupied = false
    for _, tower in ipairs(GS.towers) do
        if tower.gx == gx and tower.gz == gz then
            isOccupied = true
            break
        end
    end
    local canAfford = GS.gold >= Tower.GetTowerCost()

    if isEnergyTower then
        hintLabel_:SetText(string.format(
            "Energy Tower Lv.%d | Power: %d | Range: %d | ConvEff: %.2f | [U] Upgrade",
            GS.etLevel, EnergyTower.GetTotalPower(), EnergyTower.GetEnergyRange(), EnergyTower.GetConvEff()
        ))
        -- 悬停能源塔时显示升级面板
        if not upgradePanelVisible_ then
            M.ShowUpgradePanel()
        end
        -- U 键快捷升级
        if input:GetKeyPress(KEY_U) then
            if EnergyTower.Upgrade() then
                M.RefreshUpgradePanel()
                local Scene = require("Scene")
                if Scene.UpdateRangeCircle then
                    Scene.UpdateRangeCircle()
                end
            end
        end
    elseif isOccupied then
        if upgradePanelVisible_ then M.HideUpgradePanel() end
        -- 检查是塔还是场景物件
        local Terrain = require("Terrain")
        local terrObj = Terrain.GetObjectAt(gx, gz)
        if terrObj then
            local tDef = Terrain.TYPES[terrObj.type]
            local buffStr = ""
            if tDef and tDef.buff_type then
                buffStr = string.format(" | Buff: +%.0f%% %s", tDef.buff_value * 100, tDef.buff_type)
            end
            hintLabel_:SetText(string.format(
                "%s (%d,%d) | HP: %d/%d%s",
                tDef and tDef.name or terrObj.type, gx, gz,
                terrObj.hp, terrObj.maxHp, buffStr
            ))
        else
            for idx, tower in ipairs(GS.towers) do
                if tower.gx == gx and tower.gz == gz then
                    local att = EnergyTower.CalcAttenuation(tower.dist)
                    local dmg = CONFIG.TowerBaseDmg * att
                    -- 攻速倍率
                    local spdMult = math.max(0.30, tower.ratio * #GS.towers)
                    local fireInt = CONFIG.TowerFireInterval / spdMult
                    -- 拆除返还信息
                    local ratio = GS.wavePhase == "preparing" and 0.7 or 0.4
                    local origCost = Tower.GetTowerOriginalCost(idx)
                    local refund = math.floor(origCost * ratio + 0.5)
                    hintLabel_:SetText(string.format(
                        "Tower (%d,%d) | Dmg: %.1f | ASpd: %.2fs | Pwr: %.0f%% | [X] Sell: %d",
                        gx, gz, dmg, fireInt, tower.ratio * 100, refund
                    ))
                    break
                end
            end
        end
    elseif not inRange then
        if upgradePanelVisible_ then M.HideUpgradePanel() end
        hintLabel_:SetText("Out of energy range!")
    elseif not canAfford then
        if upgradePanelVisible_ then M.HideUpgradePanel() end
        hintLabel_:SetText("Not enough gold! Need: " .. Tower.GetTowerCost())
    else
        if upgradePanelVisible_ then M.HideUpgradePanel() end
        local att = EnergyTower.CalcAttenuation(dist)
        local dmg = CONFIG.TowerBaseDmg * att
        -- 建造预览: 预测新塔的供能%和线伤变化
        local n = #GS.towers
        local totalP = EnergyTower.GetTotalPower()
        local newN = n + 1
        local newShare = totalP / newN
        local newDel = newShare * att
        local newRatio = newDel / totalP
        local newLinePwr = newShare - newDel
        -- 预测总线功率
        local curLinePwrSum = 0
        for _, t in ipairs(GS.towers) do
            curLinePwrSum = curLinePwrSum + t.linePwr
        end
        local convEff = EnergyTower.GetConvEff()
        local curLineDps = curLinePwrSum * CONFIG.LineDmgCoeff * convEff
        -- 新塔后：每座塔都会重新分配功率
        local newTotalLine = 0
        for _, t in ipairs(GS.towers) do
            local tAtt = EnergyTower.CalcAttenuation(t.dist)
            local tDel = newShare * tAtt
            newTotalLine = newTotalLine + (newShare - tDel)
        end
        newTotalLine = newTotalLine + newLinePwr
        local newLineDps = newTotalLine * CONFIG.LineDmgCoeff * convEff
        local dpsDelta = newLineDps - curLineDps
        hintLabel_:SetText(string.format(
            "Build | Cost: %d | Pwr: %.0f%% | Dmg: %.1f | LineDPS: %+.1f",
            Tower.GetTowerCost(), newRatio * 100, dmg, dpsDelta
        ))
    end
end

-- ============================================================================
-- GameOver / Victory 覆盖层
-- ============================================================================

function M.ShowGameOver()
    local overlay = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = { 0, 0, 0, 160 },
        children = {
            UI.Panel {
                flexDirection = "column", alignItems = "center", gap = 12,
                backgroundColor = { 30, 10, 10, 220 },
                borderRadius = 12, paddingX = 40, paddingY = 30,
                children = {
                    UI.Label {
                        text = "GAME OVER",
                        fontSize = 36,
                        fontColor = { 255, 60, 60, 255 },
                    },
                    UI.Label {
                        text = string.format("Wave: %d/%d | Towers Built: %d | Monsters Killed: %d",
                            GS.currentWave, 20, #GS.towers, GS.monstersKilled),
                        fontSize = 16,
                        fontColor = { 200, 200, 200, 220 },
                    },
                    UI.Label {
                        text = "Energy Tower Destroyed",
                        fontSize = 14,
                        fontColor = { 255, 180, 100, 200 },
                    },
                }
            }
        }
    }
    UI.SetRoot(overlay)
end

function M.ShowVictory()
    local overlay = UI.Panel {
        width = "100%", height = "100%",
        justifyContent = "center", alignItems = "center",
        backgroundColor = { 0, 0, 0, 160 },
        children = {
            UI.Panel {
                flexDirection = "column", alignItems = "center", gap = 12,
                backgroundColor = { 10, 30, 10, 220 },
                borderRadius = 12, paddingX = 40, paddingY = 30,
                children = {
                    UI.Label {
                        text = "VICTORY!",
                        fontSize = 36,
                        fontColor = { 60, 255, 60, 255 },
                    },
                    UI.Label {
                        text = string.format("All 20 waves cleared! | Towers: %d | Gold: %d",
                            #GS.towers, GS.gold),
                        fontSize = 16,
                        fontColor = { 200, 255, 200, 220 },
                    },
                    UI.Label {
                        text = "Congratulations, Commander!",
                        fontSize = 14,
                        fontColor = { 255, 220, 100, 200 },
                    },
                }
            }
        }
    }
    UI.SetRoot(overlay)
end

function M.Shutdown()
    UI.Shutdown()
end

return M
