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
local ArtifactVFX  = require("ArtifactVFX")
local StatusEffect = require("StatusEffect")
local SkillSystem  = require("SkillSystem")

-- ============================================================================
-- 生命周期
-- ============================================================================

-- 记录是否已显示 GameOver/Victory 覆盖层（只触发一次）
local gameOverShown_ = false


function Start()
    graphics.windowTitle = CONFIG.Title

    -- 重置 GameOver 标记（重开时需要）
    gameOverShown_ = false

    -- 重置游戏状态
    Cfg.ResetGS()

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

    -- 开发模式：预填充所有圣器 (上线前移除)
    GS.devSkipWaveDrop = true
    Artifact.FillDevInventory()

    -- Phase 1 圣器逻辑验收测试 (开发期，上线前移除)
    local ok, TestArtifacts = pcall(require, "TestArtifacts")
    if ok and TestArtifacts then
        TestArtifacts.RunPhase1()
    end

    -- Phase 2 圣器逻辑验收测试 (开发期，上线前移除)
    local ok2, TestPhase2 = pcall(require, "TestPhase2")
    if ok2 and TestPhase2 then
        TestPhase2.RunPhase2()
    end

    -- Phase 3 圣器逻辑验收测试 (开发期，上线前移除)
    local ok3, TestPhase3 = pcall(require, "TestPhase3")
    if ok3 and TestPhase3 then
        TestPhase3.RunPhase3()
    end

    -- 悬停指示器 & 放置确认标记
    Scene.CreateHoverIndicator()
    Scene.CreatePlacementMarker()

    -- 升级提示箭头
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

    -- Q 键激活主动技能（消耗全部能量，触发已装备的技能类圣器）
    if input:GetKeyPress(KEY_Q) then
        SkillSystem.ActivateSkill()
    end

    local dt = rawDt * GS.gameSpeed

    -- 技能计时器每帧更新（overload_relay / energy_ammo 持续时间倒计时）
    SkillSystem.Update(dt)

    -- 相机（始终可操作，不受倍速影响）
    Scene.HandleCameraPan()
    Scene.HandleCameraZoom()

    -- 能源塔血条更新（始终刷新颜色）+ 水晶旋转动画
    EnergyTower.UpdateEnergyTowerHP()
    EnergyTower.UpdateEnergyTowerAnim(rawDt)

    -- 能源线脉冲动画 & 导线放置弹跳动画
    EnergyTower.UpdateEnergyLinePulse(dt)
    EnergyTower.UpdateWireAnimations(dt)

    -- 浮动伤害数字
    Utils.UpdateDmgTexts(dt)

    -- 升级箭头动画
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

    -- 交互：先更新 hover 数据，再处理圣器输入（需要最新 hover 数据）
    if not GS.artifactDropPending then
        Tower.HandleGridHover()
    end

    -- 圣器输入 (E键布线切换, B键面板, 数字键装备, 掉落选择, 塔详情 toggle)
    GameUI.HandleArtifactInput()

    -- 布线模式 vs 建塔/拆塔 (掉落选择期间屏蔽)
    if not GS.artifactDropPending then
        if GS.wiringMode then
            EnergyTower.HandleWiringInput()
        else
            Tower.HandlePlacement()
        end
    end

    -- 波次调度
    Wave.Update(dt)

    -- 怪物
    Monster.UpdateMonsters(dt)

    -- 状态效果 (燃烧DoT / 冰冻衰减 / 腐蚀到期)
    StatusEffect.Update(dt)

    -- 能源线伤害
    EnergyTower.UpdateLineDamage(dt)

    -- 短路持续扣血
    EnergyTower.UpdateShortCircuitDamage(dt)

    -- 塔放置动画
    Tower.UpdatePlaceAnimations(dt)

    -- 塔攻击 & 炮弹
    Tower.UpdateTowerAttacks(dt)
    Tower.UpdateProjectiles(dt)

    -- 磁币圣器自动吸取
    Artifact.UpdateAutoPickup(dt)

    -- 圣器 VFX 每帧更新（凝聚塔能量、动态效果等）
    ArtifactVFX.Update(dt)

    -- 掉落物
    Utils.UpdateLoots(dt)

    -- HUD 刷新
    GameUI.RefreshUI()

    -- 全屏公告计时
    GameUI.UpdateAnnouncement(dt)
end

-- ============================================================================
-- PostUpdate：在引擎完成所有变换后更新 UI 位置（确保跟随相机平移）
-- ============================================================================

function HandlePostUpdate(eventType, eventData)
    GameUI.UpdateTowerDetailPosition()
end
