-- ============================================================================
-- 正交能源塔防 V0.2 — 模块化入口
-- ============================================================================

local Cfg          = require("Config")
local CONFIG       = Cfg.CONFIG
local GS           = Cfg.GS
local Scene        = require("Scene")
local EnergyTower  = require("EnergyTower")
local Tower        = require("Tower")
local Monster      = require("Monster")
local Wave         = require("Wave")
local Utils        = require("Utils")
local GameUI       = require("GameUI")
local Artifact     = require("Artifact")
local StatusEffect = require("StatusEffect")

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

    -- 圣器系统
    Artifact.Init()

    -- 悬停指示器
    Scene.CreateHoverIndicator()

    -- 路径标记 & 升级提示箭头
    Scene.CreatePathMarkers()
    Scene.CreateUpgradeHint()

    -- HUD
    GameUI.CreateGameUI()

    -- 主循环
    SubscribeToEvent("Update", "HandleUpdate")
    SubscribeToEvent("PostUpdate", "HandlePostUpdate")

    print("=== Energy Tower Defense V0.2 Started ===")
end

function Stop()
    GameUI.Shutdown()
end

-- ============================================================================
-- 主循环
-- ============================================================================

-- 速度档位
local SPEED_LEVELS = { 1, 2, 3 }

---@param eventType string
---@param eventData UpdateEventData
function HandleUpdate(eventType, eventData)
    local rawDt = eventData["TimeStep"]:GetFloat()

    -- Tab 切换游戏速度
    if input:GetKeyPress(KEY_TAB) then
        local cur = GS.gameSpeed
        for idx, s in ipairs(SPEED_LEVELS) do
            if s == cur then
                GS.gameSpeed = SPEED_LEVELS[(idx % #SPEED_LEVELS) + 1]
                break
            end
        end
    end

    local dt = rawDt * GS.gameSpeed

    -- 相机（始终可操作，不受倍速影响）
    Scene.HandleCameraPan()
    Scene.HandleCameraZoom()

    -- 能源塔血条更新（始终刷新颜色）
    EnergyTower.UpdateEnergyTowerHP()

    -- 能源线脉冲动画
    EnergyTower.UpdateEnergyLinePulse(dt)

    -- 浮动伤害数字
    Utils.UpdateDmgTexts(dt)

    -- 路径标记旋转 & 升级箭头动画
    Scene.UpdatePathMarkers(dt)
    Scene.UpdateUpgradeHint(dt)

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

    -- 交互：先更新 hover 数据，再处理圣器输入（需要最新 hover 数据）
    if not GS.artifactDropPending then
        Tower.HandleGridHover()
    end

    -- 圣器输入 (B键面板, 数字键装备, 掉落选择, 塔详情 toggle)
    GameUI.HandleArtifactInput()

    -- 建塔/拆塔 (掉落选择期间屏蔽)
    if not GS.artifactDropPending then
        Tower.HandlePlacement()
    end

    -- 波次调度
    Wave.Update(dt)

    -- 怪物
    Monster.UpdateMonsters(dt)

    -- 状态效果 (燃烧DoT / 冰冻衰减 / 腐蚀到期)
    StatusEffect.Update(dt)

    -- 能源线伤害
    EnergyTower.UpdateLineDamage(dt)

    -- 塔攻击 & 炮弹
    Tower.UpdateTowerAttacks(dt)
    Tower.UpdateProjectiles(dt)

    -- 磁币圣器自动吸取
    Artifact.UpdateAutoPickup(dt)

    -- 掉落物
    Utils.UpdateLoots(dt)

    -- HUD 刷新
    GameUI.RefreshUI()
end

-- ============================================================================
-- PostUpdate：在引擎完成所有变换后更新 UI 位置（确保跟随相机平移）
-- ============================================================================

function HandlePostUpdate(eventType, eventData)
    GameUI.UpdateTowerDetailPosition()
end
