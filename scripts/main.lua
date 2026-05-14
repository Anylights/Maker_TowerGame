-- ============================================================================
-- 正交能源塔防 V0.2 — 模块化入口
-- ============================================================================

local Cfg         = require("Config")
local CONFIG      = Cfg.CONFIG
local GS          = Cfg.GS
local Scene       = require("Scene")
local EnergyTower = require("EnergyTower")
local Tower       = require("Tower")
local Monster     = require("Monster")
local Wave        = require("Wave")
local Utils       = require("Utils")
local GameUI      = require("GameUI")

-- ============================================================================
-- 生命周期
-- ============================================================================

-- 记录是否已显示 GameOver/Victory 覆盖层（只触发一次）
local gameOverShown_ = false
local victoryShown_ = false

function Start()
    graphics.windowTitle = CONFIG.Title

    -- UI
    GameUI.InitUI()

    -- 场景 & 相机
    Scene.CreateScene()
    Scene.SetupCamera()
    Scene.CreateGrid()
    Scene.CreateRangeCircle()

    -- 能源塔
    EnergyTower.PlaceEnergyTower()

    -- 悬停指示器
    Scene.CreateHoverIndicator()

    -- HUD
    GameUI.CreateGameUI()

    -- 主循环
    SubscribeToEvent("Update", "HandleUpdate")

    print("=== Energy Tower Defense V0.2 Started ===")
end

function Stop()
    GameUI.Shutdown()
end

-- ============================================================================
-- 主循环
-- ============================================================================

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 相机（始终可操作）
    Scene.HandleCameraPan()
    Scene.HandleCameraZoom()

    -- 能源塔血条更新（始终刷新颜色）
    EnergyTower.UpdateEnergyTowerHP()

    -- 能源线脉冲动画
    EnergyTower.UpdateEnergyLinePulse(dt)

    -- 浮动伤害数字
    Utils.UpdateDmgTexts(dt)

    -- GameOver 检测
    if GS.gameOver then
        if not gameOverShown_ then
            gameOverShown_ = true
            GameUI.ShowGameOver()
            print("[GameOver] Energy Tower destroyed!")
        end
        return
    end

    -- Victory 检测
    if GS.wavePhase == "victory" then
        if not victoryShown_ then
            victoryShown_ = true
            GameUI.ShowVictory()
        end
        return
    end

    -- 交互
    Tower.HandleGridHover()
    Tower.HandlePlacement()

    -- 波次调度
    Wave.Update(dt)

    -- 怪物
    Monster.UpdateMonsters(dt)

    -- 塔攻击 & 炮弹
    Tower.UpdateTowerAttacks(dt)
    Tower.UpdateProjectiles(dt)

    -- 掉落物
    Utils.UpdateLoots(dt)

    -- HUD 刷新
    GameUI.RefreshUI()
end
