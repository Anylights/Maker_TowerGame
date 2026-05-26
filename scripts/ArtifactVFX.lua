-- ============================================================================
-- ArtifactVFX.lua — 36 件圣器的粒子特效系统
-- 装备/卸除时在塔体上创建对应 ParticleEmitter 节点
-- ============================================================================

local M = {}

-- ============================================================================
-- 内部状态
-- ============================================================================

-- 需要每帧更新的动态 VFX（轨道粒子、脉冲等）
-- 格式: { towerRef, artifactId, vfxNode, timer, ... }
local activeVFX_ = {}

-- ============================================================================
-- 通用粒子创建辅助
-- ============================================================================

-- 创建一个程序化粒子特效并挂到指定节点
-- @param parentNode Node  挂载父节点
-- @param cfg table        配置参数
-- @return Node  特效子节点
local function CreateParticleNode(parentNode, cfg)
    local node = parentNode:CreateChild("VFX")
    node.position = cfg.offset or Vector3(0, 0, 0)

    local emitter = node:CreateComponent("ParticleEmitter")
    local effect = ParticleEffect:new()

    -- 基础设置
    effect:SetNumParticles(cfg.maxParticles or 32)
    effect:SetMinEmissionRate(cfg.emitRateMin or cfg.emitRate or 8)
    effect:SetMaxEmissionRate(cfg.emitRateMax or cfg.emitRate or 8)
    effect:SetMinParticleSize(Vector2(cfg.sizeMin or 0.03, cfg.sizeMin or 0.03))
    effect:SetMaxParticleSize(Vector2(cfg.sizeMax or 0.06, cfg.sizeMax or 0.06))
    effect:SetMinTimeToLive(cfg.lifeMin or cfg.life or 0.8)
    effect:SetMaxTimeToLive(cfg.lifeMax or cfg.life or 0.8)
    effect:SetGravityStrength(cfg.gravity or 0)

    -- 发射方向
    local velMin = cfg.velMin or Vector3(-0.3, 0.2, -0.3)
    local velMax = cfg.velMax or Vector3(0.3, 0.6, 0.3)
    effect:SetMinVelocity(velMin.Length)
    effect:SetMaxVelocity(velMax.Length)

    -- 颜色关键帧
    local colors = cfg.colors or {
        { time = 0.0, color = Color(1, 1, 1, 1) },
        { time = 1.0, color = Color(1, 1, 1, 0) },
    }
    for _, kf in ipairs(colors) do
        effect:AddColorTime(kf.color, kf.time)
    end

    -- 发射器形状
    local shape = cfg.shape or EMITTER_SPHERE
    effect:SetEmitterType(shape)
    effect:SetEmitterSize(Vector3(cfg.shapeRadius or 0.1, cfg.shapeRadius or 0.1, cfg.shapeRadius or 0.1))

    -- 材质（粒子专用 Alpha 材质）
    local mat = Material:new()
    mat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
    mat:SetShaderParameter("MatDiffColor", Variant(cfg.matColor or Color(1, 1, 1, 1)))
    mat:SetShaderParameter("MatEmissiveColor", Variant(cfg.emissive or Color(0.5, 0.5, 0.5)))
    effect:SetMaterial(mat)

    emitter:SetEffect(effect)
    emitter:SetEmitting(cfg.emitting ~= false)

    return node
end

-- ============================================================================
-- 各圣器 VFX 创建函数
-- ============================================================================

-- 获取锚点位置（相对塔根节点的偏移）
local ANCHOR_OFFSETS = {
    muzzle           = Vector3(0, 1.2, 0),
    tower_top        = Vector3(0, 2.0, 0),
    tower_base_ring  = Vector3(0, 0.05, 0),
    tower_body       = Vector3(0, 0.8, 0),
}

-- 工厂表: artifactId → function(towerNode) → vfxNode
local VFX_CREATORS = {}

-- ─── 攻击类 ──────────────────────────────────────────────────────────────────

-- 连射模块: 亮黄色火星从炮口螺旋喷出
VFX_CREATORS["rapid_fire_module"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        maxParticles = 40,
        emitRate = 30,
        life = 0.2,
        sizeMin = 0.02, sizeMax = 0.04,
        gravity = 0,
        shapeRadius = 0.08,
        velMin = Vector3(-1, -1, -1), velMax = Vector3(1, 1, 1),
        colors = {
            { time = 0.0, color = Color(1.5, 1.5, 0.2, 1.0) },
            { time = 0.5, color = Color(1.2, 0.8, 0.1, 0.7) },
            { time = 1.0, color = Color(0.8, 0.4, 0.0, 0.0) },
        },
        matColor = Color(1, 1, 0, 1),
        emissive = Color(1.5, 1.2, 0.0),
    })
end

-- 火种圣器: 橙红色火花缓慢下落 + 每1.5s升起小火球
VFX_CREATORS["fire_seed"] = function(towerNode)
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        maxParticles = 20,
        emitRate = 8,
        life = 0.8,
        sizeMin = 0.025, sizeMax = 0.04,
        gravity = 0.5,
        shapeRadius = 0.06,
        velMin = Vector3(-0.2, 0.1, -0.2), velMax = Vector3(0.2, 0.4, 0.2),
        colors = {
            { time = 0.0, color = Color(1.5, 0.8, 0.1, 1.0) },
            { time = 0.5, color = Color(1.0, 0.3, 0.0, 0.8) },
            { time = 1.0, color = Color(0.4, 0.1, 0.0, 0.0) },
        },
        matColor = Color(1, 0.4, 0, 1),
        emissive = Color(2.0, 0.6, 0.0),
    })
    return node
end

-- 冰晶圣器: 浅蓝六角颗粒随机飘散
VFX_CREATORS["ice_crystal"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        maxParticles = 30,
        emitRate = 15,
        life = 1.2,
        sizeMin = 0.015, sizeMax = 0.03,
        gravity = 0.2,
        shapeRadius = 0.12,
        velMin = Vector3(-0.3, -0.1, -0.3), velMax = Vector3(0.3, 0.3, 0.3),
        colors = {
            { time = 0.0, color = Color(0.6, 0.9, 1.5, 1.0) },
            { time = 0.5, color = Color(0.8, 1.0, 1.5, 0.7) },
            { time = 1.0, color = Color(1.0, 1.0, 1.5, 0.0) },
        },
        matColor = Color(0.6, 0.9, 1, 1),
        emissive = Color(0.4, 0.8, 2.0),
    })
end

-- 腐蚀圣器: 黄绿液滴从炮口下方滴落
VFX_CREATORS["corrosion"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        maxParticles = 12,
        emitRate = 5,
        life = 0.6,
        sizeMin = 0.03, sizeMax = 0.05,
        gravity = 1.2,
        shapeRadius = 0.05,
        velMin = Vector3(-0.1, -0.2, -0.1), velMax = Vector3(0.1, 0.1, 0.1),
        colors = {
            { time = 0.0, color = Color(0.5, 1.2, 0.1, 1.0) },
            { time = 0.6, color = Color(0.3, 0.8, 0.0, 0.6) },
            { time = 1.0, color = Color(0.2, 0.5, 0.0, 0.0) },
        },
        matColor = Color(0.4, 1, 0, 1),
        emissive = Color(0.3, 1.5, 0.0),
    })
end

-- 雷鸣圣器: 亮紫色电弧短粒子在炮口闪烁
VFX_CREATORS["thunder"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        maxParticles = 16,
        emitRate = 4,
        life = 0.12,
        sizeMin = 0.02, sizeMax = 0.08,
        gravity = 0,
        shapeRadius = 0.15,
        velMin = Vector3(-0.5, -0.5, -0.5), velMax = Vector3(0.5, 0.5, 0.5),
        colors = {
            { time = 0.0, color = Color(0.8, 0.3, 2.0, 1.0) },
            { time = 0.5, color = Color(1.0, 0.5, 2.0, 0.6) },
            { time = 1.0, color = Color(0.5, 0.2, 1.0, 0.0) },
        },
        matColor = Color(0.7, 0.3, 1, 1),
        emissive = Color(1.0, 0.4, 3.0),
    })
end

-- 裂片圣器: 灰白色金属碎屑弧线掉落
VFX_CREATORS["splinter"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        maxParticles = 16,
        emitRate = 6,
        life = 0.6,
        sizeMin = 0.02, sizeMax = 0.035,
        gravity = 0.8,
        shapeRadius = 0.1,
        velMin = Vector3(-0.4, 0.2, -0.4), velMax = Vector3(0.4, 0.5, 0.4),
        colors = {
            { time = 0.0, color = Color(0.9, 0.9, 0.9, 1.0) },
            { time = 1.0, color = Color(0.6, 0.6, 0.6, 0.0) },
        },
        matColor = Color(0.8, 0.8, 0.8, 1),
        emissive = Color(0.3, 0.3, 0.3),
    })
end

-- 穿透弹芯: 银白色细长线状粒子从炮口高速喷出
VFX_CREATORS["piercing_core"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        maxParticles = 24,
        emitRate = 12,
        life = 0.3,
        sizeMin = 0.01, sizeMax = 0.015,
        gravity = 0,
        shapeRadius = 0.04,
        velMin = Vector3(-0.1, 0.8, -0.1), velMax = Vector3(0.1, 2.0, 0.1),
        colors = {
            { time = 0.0, color = Color(1.5, 1.5, 2.0, 1.0) },
            { time = 0.5, color = Color(1.0, 1.0, 1.5, 0.5) },
            { time = 1.0, color = Color(0.8, 0.8, 1.0, 0.0) },
        },
        matColor = Color(0.9, 0.9, 1, 1),
        emissive = Color(1.0, 1.0, 2.5),
    })
end

-- 狙击改装: 淡红色炮口微光粒子（模拟瞄准镜）
VFX_CREATORS["sniper_mod"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        maxParticles = 6,
        emitRate = 2,
        life = 1.5,
        sizeMin = 0.02, sizeMax = 0.04,
        gravity = 0,
        shapeRadius = 0.04,
        velMin = Vector3(-0.05, 0.3, -0.05), velMax = Vector3(0.05, 0.8, 0.05),
        colors = {
            { time = 0.0, color = Color(1.5, 0.3, 0.3, 0.8) },
            { time = 0.5, color = Color(1.2, 0.2, 0.2, 0.4) },
            { time = 1.0, color = Color(1.0, 0.1, 0.1, 0.0) },
        },
        matColor = Color(1, 0.2, 0.2, 0.7),
        emissive = Color(2.0, 0.3, 0.3),
    })
end

-- 棱镜圣器: 七色折射光斑绕炮口顺时针轨道旋转
VFX_CREATORS["prism"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        maxParticles = 24,
        emitRate = 8,
        life = 2.0,
        sizeMin = 0.03, sizeMax = 0.05,
        gravity = 0,
        shapeRadius = 0.08,
        velMin = Vector3(-0.1, -0.1, -0.1), velMax = Vector3(0.1, 0.1, 0.1),
        colors = {
            { time = 0.00, color = Color(2.0, 0.2, 0.2, 1.0) },
            { time = 0.17, color = Color(2.0, 1.0, 0.1, 1.0) },
            { time = 0.33, color = Color(0.2, 2.0, 0.2, 1.0) },
            { time = 0.50, color = Color(0.1, 0.5, 2.0, 1.0) },
            { time = 0.67, color = Color(0.8, 0.1, 2.0, 1.0) },
            { time = 1.00, color = Color(2.0, 0.1, 0.8, 0.0) },
        },
        matColor = Color(1, 1, 1, 1),
        emissive = Color(1.0, 1.0, 1.0),
    })
end

-- 高爆圣器: 亮黄色火星瞬闪
VFX_CREATORS["high_explosive"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.muzzle,
        maxParticles = 20,
        emitRate = 10,
        life = 0.15,
        sizeMin = 0.03, sizeMax = 0.06,
        gravity = 0,
        shapeRadius = 0.1,
        velMin = Vector3(-0.8, -0.3, -0.8), velMax = Vector3(0.8, 0.8, 0.8),
        colors = {
            { time = 0.0, color = Color(2.0, 2.0, 1.0, 1.0) },
            { time = 0.4, color = Color(2.0, 1.0, 0.1, 0.8) },
            { time = 1.0, color = Color(0.5, 0.1, 0.0, 0.0) },
        },
        matColor = Color(1, 0.8, 0, 1),
        emissive = Color(3.0, 1.5, 0.0),
    })
end

-- 暴击装置: 金色四芒星闪烁
VFX_CREATORS["crit_device"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = Vector3(0, 1.3, 0),
        maxParticles = 8,
        emitRate = 3,
        life = 1.2,
        sizeMin = 0.04, sizeMax = 0.07,
        gravity = 0,
        shapeRadius = 0.06,
        velMin = Vector3(-0.05, 0.0, -0.05), velMax = Vector3(0.05, 0.1, 0.05),
        colors = {
            { time = 0.0, color = Color(2.0, 1.5, 0.1, 1.0) },
            { time = 0.3, color = Color(2.5, 2.0, 0.2, 1.0) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
        matColor = Color(1, 0.8, 0, 1),
        emissive = Color(2.5, 2.0, 0.1),
    })
end

-- 共振触发: 蓝白色环形粒子带脉冲膨胀
VFX_CREATORS["resonance_trigger"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        maxParticles = 40,
        emitRate = 20,
        life = 0.8,
        sizeMin = 0.025, sizeMax = 0.04,
        gravity = 0,
        shapeRadius = 0.15,
        velMin = Vector3(-0.3, -0.1, -0.3), velMax = Vector3(0.3, 0.1, 0.3),
        colors = {
            { time = 0.0, color = Color(0.6, 0.8, 2.0, 0.8) },
            { time = 0.5, color = Color(0.8, 1.0, 2.0, 0.5) },
            { time = 1.0, color = Color(1.0, 1.0, 2.0, 0.0) },
        },
        matColor = Color(0.5, 0.8, 1, 0.7),
        emissive = Color(0.5, 0.8, 2.5),
    })
end

-- 元素核心: 4色粒子绕圆轨道旋转
VFX_CREATORS["elemental_core"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = Vector3(0, 1.3, 0),
        maxParticles = 16,
        emitRate = 8,
        life = 1.5,
        sizeMin = 0.02, sizeMax = 0.035,
        gravity = 0,
        shapeRadius = 0.1,
        velMin = Vector3(-0.15, -0.1, -0.15), velMax = Vector3(0.15, 0.1, 0.15),
        colors = {
            { time = 0.0,  color = Color(2.0, 0.5, 0.1, 1.0) },
            { time = 0.33, color = Color(0.2, 0.5, 2.0, 1.0) },
            { time = 0.67, color = Color(0.6, 0.1, 2.0, 1.0) },
            { time = 1.0,  color = Color(0.2, 1.5, 0.2, 0.0) },
        },
        matColor = Color(1, 0.8, 0.5, 1),
        emissive = Color(1.0, 0.8, 0.5),
    })
end

-- ─── 增益类 ──────────────────────────────────────────────────────────────────

-- 攻速光环: 亮黄色粒子沿塔基环绕旋转
VFX_CREATORS["aura_attack_speed"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        maxParticles = 48,
        emitRate = 24,
        life = 1.0,
        sizeMin = 0.015, sizeMax = 0.025,
        gravity = 0,
        shapeRadius = 5.0,  -- 5 格半径
        velMin = Vector3(-0.1, 0.05, -0.1), velMax = Vector3(0.1, 0.2, 0.1),
        colors = {
            { time = 0.0, color = Color(2.0, 2.0, 0.2, 1.0) },
            { time = 0.5, color = Color(1.5, 1.5, 0.1, 0.5) },
            { time = 1.0, color = Color(1.0, 1.0, 0.0, 0.0) },
        },
        matColor = Color(1, 1, 0.1, 1),
        emissive = Color(2.0, 2.0, 0.2),
    })
end

-- 伤害光环: 深红色厚粒子沿塔基慢速逆时针
VFX_CREATORS["aura_damage"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        maxParticles = 32,
        emitRate = 16,
        life = 2.0,
        sizeMin = 0.025, sizeMax = 0.04,
        gravity = 0,
        shapeRadius = 5.0,
        velMin = Vector3(-0.08, 0.02, -0.08), velMax = Vector3(0.08, 0.12, 0.08),
        colors = {
            { time = 0.0, color = Color(2.0, 0.1, 0.1, 1.0) },
            { time = 0.5, color = Color(1.5, 0.05, 0.05, 0.6) },
            { time = 1.0, color = Color(0.8, 0.0, 0.0, 0.0) },
        },
        matColor = Color(1, 0.1, 0.1, 1),
        emissive = Color(2.5, 0.1, 0.1),
    })
end

-- 射程光环: 亮绿色粒子从塔基向外径向扩散
VFX_CREATORS["aura_range"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        maxParticles = 60,
        emitRate = 30,
        life = 2.0,
        sizeMin = 0.015, sizeMax = 0.025,
        gravity = 0,
        shapeRadius = 0.3,
        velMin = Vector3(-2.5, 0.0, -2.5), velMax = Vector3(2.5, 0.1, 2.5),
        colors = {
            { time = 0.0, color = Color(0.2, 2.5, 0.2, 1.0) },
            { time = 0.6, color = Color(0.1, 1.5, 0.1, 0.5) },
            { time = 1.0, color = Color(0.0, 0.8, 0.0, 0.0) },
        },
        matColor = Color(0.2, 1, 0.2, 1),
        emissive = Color(0.2, 2.5, 0.2),
    })
end

-- 暴击光环: 金色四芒星粒子在5格半径上随机闪烁
VFX_CREATORS["aura_crit"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        maxParticles = 20,
        emitRate = 10,
        life = 0.25,
        sizeMin = 0.035, sizeMax = 0.055,
        gravity = 0,
        shapeRadius = 5.0,
        velMin = Vector3(-0.05, 0.0, -0.05), velMax = Vector3(0.05, 0.15, 0.05),
        colors = {
            { time = 0.0, color = Color(2.5, 2.0, 0.1, 1.0) },
            { time = 0.5, color = Color(3.0, 2.5, 0.2, 0.8) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
        matColor = Color(1, 0.85, 0, 1),
        emissive = Color(3.0, 2.5, 0.1),
    })
end

-- 远程压缩: 紫色能量沿塔体流动
VFX_CREATORS["range_compression"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        maxParticles = 20,
        emitRate = 8,
        life = 1.2,
        sizeMin = 0.02, sizeMax = 0.03,
        gravity = -0.3,
        shapeRadius = 0.12,
        velMin = Vector3(-0.1, -0.5, -0.1), velMax = Vector3(0.1, -0.2, 0.1),
        colors = {
            { time = 0.0, color = Color(0.5, 0.1, 2.0, 0.7) },
            { time = 0.5, color = Color(0.8, 0.2, 2.5, 0.5) },
            { time = 1.0, color = Color(0.3, 0.0, 1.5, 0.0) },
        },
        matColor = Color(0.5, 0.1, 1, 0.8),
        emissive = Color(0.5, 0.1, 2.0),
    })
end

-- 借力圣器: 金色细丝从塔顶流入
VFX_CREATORS["power_borrow"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        maxParticles = 24,
        emitRate = 12,
        life = 1.0,
        sizeMin = 0.015, sizeMax = 0.03,
        gravity = -0.5,
        shapeRadius = 4.0,
        velMin = Vector3(-3.0, -0.5, -3.0), velMax = Vector3(3.0, 0.2, 3.0),
        colors = {
            { time = 0.0, color = Color(2.5, 2.0, 0.1, 0.8) },
            { time = 0.5, color = Color(2.0, 1.5, 0.1, 0.5) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
        matColor = Color(1, 0.8, 0, 1),
        emissive = Color(2.5, 2.0, 0.1),
    })
end

-- 总管塔: 金色光点悬浮在塔顶缓慢旋转
VFX_CREATORS["master_tower"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        maxParticles = 6,
        emitRate = 3,
        life = 2.5,
        sizeMin = 0.04, sizeMax = 0.06,
        gravity = 0,
        shapeRadius = 0.06,
        velMin = Vector3(-0.05, 0.0, -0.05), velMax = Vector3(0.05, 0.1, 0.05),
        colors = {
            { time = 0.0, color = Color(3.0, 2.5, 0.2, 1.0) },
            { time = 0.5, color = Color(2.5, 2.0, 0.1, 0.8) },
            { time = 1.0, color = Color(2.0, 1.5, 0.0, 0.0) },
        },
        matColor = Color(1, 0.85, 0, 1),
        emissive = Color(3.0, 2.5, 0.2),
    })
end

-- 防御阵地塔: 蓝灰色粒子沿塔体竖直上升 + 地面护盾脉冲
VFX_CREATORS["defense_garrison"] = function(towerNode)
    -- 塔体上升烟雾
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        maxParticles = 24,
        emitRate = 12,
        life = 1.5,
        sizeMin = 0.025, sizeMax = 0.045,
        gravity = -0.5,
        shapeRadius = 0.2,
        velMin = Vector3(-0.1, 0.2, -0.1), velMax = Vector3(0.1, 0.6, 0.1),
        colors = {
            { time = 0.0, color = Color(0.4, 0.5, 0.8, 0.8) },
            { time = 0.5, color = Color(0.5, 0.6, 0.9, 0.5) },
            { time = 1.0, color = Color(0.3, 0.4, 0.7, 0.0) },
        },
        matColor = Color(0.4, 0.5, 0.8, 0.8),
        emissive = Color(0.4, 0.5, 1.5),
    })
    -- 地面护盾环
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        maxParticles = 30,
        emitRate = 15,
        life = 2.0,
        sizeMin = 0.02, sizeMax = 0.03,
        gravity = 0,
        shapeRadius = 5.0,
        velMin = Vector3(-0.1, 0.0, -0.1), velMax = Vector3(0.1, 0.08, 0.1),
        colors = {
            { time = 0.0, color = Color(0.3, 0.4, 2.0, 0.8) },
            { time = 0.5, color = Color(0.2, 0.3, 1.5, 0.4) },
            { time = 1.0, color = Color(0.1, 0.2, 1.0, 0.0) },
        },
        matColor = Color(0.3, 0.4, 1, 0.7),
        emissive = Color(0.3, 0.4, 2.0),
    })
    return node
end

-- 网络圣器: 淡蓝色能量双向流动
VFX_CREATORS["network"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        maxParticles = 30,
        emitRate = 15,
        life = 1.0,
        sizeMin = 0.015, sizeMax = 0.025,
        gravity = 0,
        shapeRadius = 0.5,
        velMin = Vector3(-1.5, -0.3, -1.5), velMax = Vector3(1.5, 0.3, 1.5),
        colors = {
            { time = 0.0, color = Color(0.3, 0.7, 2.0, 0.8) },
            { time = 0.5, color = Color(0.5, 0.9, 2.5, 0.5) },
            { time = 1.0, color = Color(0.8, 1.0, 2.0, 0.0) },
        },
        matColor = Color(0.3, 0.7, 1, 0.8),
        emissive = Color(0.3, 0.7, 2.5),
    })
end

-- 吞噬线: 深紫黑色烟雾从能源线流入塔体
VFX_CREATORS["devour_line"] = function(towerNode)
    -- 塔体暗紫雾
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        maxParticles = 24,
        emitRate = 15,
        life = 1.0,
        sizeMin = 0.03, sizeMax = 0.05,
        gravity = -0.3,
        shapeRadius = 0.2,
        velMin = Vector3(-0.2, 0.1, -0.2), velMax = Vector3(0.2, 0.4, 0.2),
        colors = {
            { time = 0.0, color = Color(0.4, 0.0, 0.6, 0.9) },
            { time = 0.5, color = Color(0.2, 0.0, 0.4, 0.6) },
            { time = 1.0, color = Color(0.05, 0.0, 0.1, 0.0) },
        },
        matColor = Color(0.3, 0, 0.5, 1),
        emissive = Color(0.5, 0.0, 0.8),
    })
    return node
end

-- 冰晶导管: 淡蓝色六角冰晶沿链路流动
VFX_CREATORS["ice_crystal_conduit"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        maxParticles = 24,
        emitRate = 10,
        life = 1.5,
        sizeMin = 0.015, sizeMax = 0.025,
        gravity = 0,
        shapeRadius = 0.3,
        velMin = Vector3(-0.5, -0.2, -0.5), velMax = Vector3(0.5, 0.2, 0.5),
        colors = {
            { time = 0.0, color = Color(0.5, 0.8, 2.0, 0.9) },
            { time = 0.5, color = Color(0.7, 1.0, 2.5, 0.6) },
            { time = 1.0, color = Color(0.8, 1.0, 2.0, 0.0) },
        },
        matColor = Color(0.5, 0.8, 1, 1),
        emissive = Color(0.4, 0.8, 2.5),
    })
end

-- 共鸣放大器: 粉色共鸣环从塔基向外扩散
VFX_CREATORS["resonance_amplifier"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        maxParticles = 40,
        emitRate = 20,
        life = 1.5,
        sizeMin = 0.025, sizeMax = 0.04,
        gravity = 0,
        shapeRadius = 0.3,
        velMin = Vector3(-3.0, 0.0, -3.0), velMax = Vector3(3.0, 0.1, 3.0),
        colors = {
            { time = 0.0, color = Color(2.5, 0.3, 1.0, 0.9) },
            { time = 0.5, color = Color(2.0, 0.2, 0.8, 0.5) },
            { time = 1.0, color = Color(1.5, 0.1, 0.6, 0.0) },
        },
        matColor = Color(1, 0.3, 0.8, 0.9),
        emissive = Color(2.5, 0.3, 1.5),
    })
end

-- 元素反应: 4色小漩涡环绕塔顶
VFX_CREATORS["elemental_reaction"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = Vector3(0, 2.1, 0),
        maxParticles = 32,
        emitRate = 12,
        life = 2.0,
        sizeMin = 0.02, sizeMax = 0.035,
        gravity = 0,
        shapeRadius = 0.1,
        velMin = Vector3(-0.2, -0.1, -0.2), velMax = Vector3(0.2, 0.1, 0.2),
        colors = {
            { time = 0.0,  color = Color(2.0, 0.5, 0.1, 1.0) },
            { time = 0.25, color = Color(0.2, 0.5, 2.0, 1.0) },
            { time = 0.50, color = Color(0.8, 0.1, 2.0, 1.0) },
            { time = 0.75, color = Color(0.2, 1.5, 0.2, 1.0) },
            { time = 1.0,  color = Color(1.0, 0.3, 0.5, 0.0) },
        },
        matColor = Color(1, 0.8, 0.5, 1),
        emissive = Color(1.0, 0.8, 0.5),
    })
end

-- 过载继电器: 橙红色高压电火花间歇喷出
VFX_CREATORS["overload_relay"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        maxParticles = 24,
        emitRate = 8,
        life = 0.4,
        sizeMin = 0.025, sizeMax = 0.04,
        gravity = 0,
        shapeRadius = 0.15,
        velMin = Vector3(-1.2, -0.8, -1.2), velMax = Vector3(1.2, 1.2, 1.2),
        colors = {
            { time = 0.0, color = Color(2.5, 0.5, 0.1, 1.0) },
            { time = 0.4, color = Color(2.0, 0.3, 0.0, 0.7) },
            { time = 1.0, color = Color(1.0, 0.1, 0.0, 0.0) },
        },
        matColor = Color(1, 0.4, 0, 1),
        emissive = Color(3.0, 0.5, 0.0),
    })
end

-- 注能弹药: 亮黄色弹药粒子环绕塔顶旋转
VFX_CREATORS["energy_ammo"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        maxParticles = 18,
        emitRate = 8,
        life = 2.0,
        sizeMin = 0.02, sizeMax = 0.04,
        gravity = 0,
        shapeRadius = 0.08,
        velMin = Vector3(-0.1, -0.05, -0.1), velMax = Vector3(0.1, 0.05, 0.1),
        colors = {
            { time = 0.0, color = Color(2.5, 2.0, 0.2, 1.0) },
            { time = 0.5, color = Color(2.0, 1.5, 0.1, 0.8) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
        matColor = Color(1, 0.9, 0.1, 1),
        emissive = Color(2.5, 2.0, 0.2),
    })
end

-- ─── 收集类 ──────────────────────────────────────────────────────────────────

-- 磁币圣器: 金色磁性螺旋粒子从塔顶向外撒出
VFX_CREATORS["coin_magnet"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        maxParticles = 40,
        emitRate = 20,
        life = 1.5,
        sizeMin = 0.015, sizeMax = 0.025,
        gravity = 0.3,
        shapeRadius = 0.1,
        velMin = Vector3(-3.0, 0.2, -3.0), velMax = Vector3(3.0, 0.8, 3.0),
        colors = {
            { time = 0.0, color = Color(2.5, 1.8, 0.1, 1.0) },
            { time = 0.5, color = Color(2.0, 1.5, 0.0, 0.6) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
        matColor = Color(1, 0.8, 0, 1),
        emissive = Color(2.5, 1.8, 0.1),
    })
end

-- 金矿炼化: 塔顶金色微光环
VFX_CREATORS["gold_refinery"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        maxParticles = 12,
        emitRate = 5,
        life = 1.2,
        sizeMin = 0.02, sizeMax = 0.035,
        gravity = -0.2,
        shapeRadius = 0.1,
        velMin = Vector3(-0.3, 0.05, -0.3), velMax = Vector3(0.3, 0.3, 0.3),
        colors = {
            { time = 0.0, color = Color(2.5, 1.8, 0.1, 0.9) },
            { time = 0.5, color = Color(2.0, 1.4, 0.0, 0.5) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
        matColor = Color(1, 0.8, 0, 1),
        emissive = Color(2.5, 1.8, 0.1),
    })
end

-- 充能矩阵: 浅蓝色方形粒子缓慢绕塔顶旋转
VFX_CREATORS["energy_matrix"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        maxParticles = 12,
        emitRate = 4,
        life = 4.0,
        sizeMin = 0.025, sizeMax = 0.035,
        gravity = 0,
        shapeRadius = 0.06,
        velMin = Vector3(-0.05, 0.0, -0.05), velMax = Vector3(0.05, 0.05, 0.05),
        colors = {
            { time = 0.0, color = Color(0.4, 0.8, 2.5, 1.0) },
            { time = 0.5, color = Color(0.5, 1.0, 3.0, 0.8) },
            { time = 1.0, color = Color(0.3, 0.6, 2.0, 0.0) },
        },
        matColor = Color(0.4, 0.8, 1, 1),
        emissive = Color(0.4, 0.8, 3.0),
    })
end

-- 蓄力击圣器: 蓝色能量粒子在塔顶累积
VFX_CREATORS["charged_hit"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        maxParticles = 12,
        emitRate = 4,
        life = 1.5,
        sizeMin = 0.025, sizeMax = 0.04,
        gravity = -0.3,
        shapeRadius = 0.08,
        velMin = Vector3(-0.1, 0.1, -0.1), velMax = Vector3(0.1, 0.4, 0.1),
        colors = {
            { time = 0.0, color = Color(0.3, 0.6, 3.0, 1.0) },
            { time = 0.5, color = Color(0.5, 0.8, 2.5, 0.7) },
            { time = 1.0, color = Color(0.4, 0.6, 2.0, 0.0) },
        },
        matColor = Color(0.3, 0.6, 1, 1),
        emissive = Color(0.3, 0.6, 3.0),
    })
end

-- 凝聚塔: 蓝色能量粒子从塔体内部向塔顶飘升
VFX_CREATORS["condenser"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_body,
        maxParticles = 30,
        emitRate = 15,
        life = 2.0,
        sizeMin = 0.015, sizeMax = 0.025,
        gravity = -0.8,
        shapeRadius = 0.15,
        velMin = Vector3(-0.1, 0.3, -0.1), velMax = Vector3(0.1, 0.8, 0.1),
        colors = {
            { time = 0.0, color = Color(0.3, 0.6, 3.0, 1.0) },
            { time = 0.5, color = Color(0.4, 0.8, 2.5, 0.7) },
            { time = 1.0, color = Color(0.5, 1.0, 2.0, 0.0) },
        },
        matColor = Color(0.3, 0.6, 1, 1),
        emissive = Color(0.3, 0.6, 3.0),
    })
end

-- 资源富集: 棕黄色土壤微粒向塔基流动
VFX_CREATORS["resource_enrichment"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        maxParticles = 20,
        emitRate = 8,
        life = 1.5,
        sizeMin = 0.015, sizeMax = 0.025,
        gravity = 0.2,
        shapeRadius = 1.5,
        velMin = Vector3(-0.5, 0.0, -0.5), velMax = Vector3(0.5, 0.3, 0.5),
        colors = {
            { time = 0.0, color = Color(1.2, 0.8, 0.2, 0.9) },
            { time = 0.5, color = Color(0.9, 0.6, 0.1, 0.5) },
            { time = 1.0, color = Color(0.7, 0.4, 0.0, 0.0) },
        },
        matColor = Color(0.8, 0.6, 0.1, 1),
        emissive = Color(1.0, 0.7, 0.1),
    })
end

-- 复利圣器: 金色小圆粒子螺旋上升
VFX_CREATORS["compound_interest"] = function(towerNode)
    return CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        maxParticles = 16,
        emitRate = 2,
        life = 2.0,
        sizeMin = 0.025, sizeMax = 0.04,
        gravity = -0.4,
        shapeRadius = 0.08,
        velMin = Vector3(-0.2, 0.3, -0.2), velMax = Vector3(0.2, 0.8, 0.2),
        colors = {
            { time = 0.0, color = Color(2.5, 1.8, 0.1, 1.0) },
            { time = 0.5, color = Color(2.0, 1.5, 0.0, 0.7) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
        matColor = Color(1, 0.8, 0, 1),
        emissive = Color(2.5, 1.8, 0.1),
    })
end

-- 反馈线圈: 紫色反馈环 + 塔顶金光柱
VFX_CREATORS["feedback_coil"] = function(towerNode)
    -- 塔基紫色脉冲环
    local node = CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_base_ring,
        maxParticles = 30,
        emitRate = 15,
        life = 1.0,
        sizeMin = 0.025, sizeMax = 0.04,
        gravity = 0,
        shapeRadius = 1.5,
        velMin = Vector3(-1.5, 0.0, -1.5), velMax = Vector3(1.5, 0.1, 1.5),
        colors = {
            { time = 0.0, color = Color(0.7, 0.1, 2.5, 1.0) },
            { time = 0.5, color = Color(0.5, 0.0, 2.0, 0.6) },
            { time = 1.0, color = Color(0.3, 0.0, 1.5, 0.0) },
        },
        matColor = Color(0.5, 0.1, 1, 1),
        emissive = Color(0.7, 0.1, 2.5),
    })
    -- 塔顶金色光柱向上
    CreateParticleNode(towerNode, {
        offset = ANCHOR_OFFSETS.tower_top,
        maxParticles = 16,
        emitRate = 8,
        life = 1.5,
        sizeMin = 0.015, sizeMax = 0.025,
        gravity = -0.6,
        shapeRadius = 0.06,
        velMin = Vector3(-0.1, 0.5, -0.1), velMax = Vector3(0.1, 1.5, 0.1),
        colors = {
            { time = 0.0, color = Color(2.5, 1.8, 0.1, 1.0) },
            { time = 0.5, color = Color(2.0, 1.5, 0.0, 0.6) },
            { time = 1.0, color = Color(1.5, 1.0, 0.0, 0.0) },
        },
        matColor = Color(1, 0.8, 0, 1),
        emissive = Color(2.5, 1.8, 0.1),
    })
    return node
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 圣器装备时调用: 在塔节点上创建对应的粒子 VFX 节点
--- @param tower table  GS.towers 中的塔对象
--- @param artifactId string  圣器 id
function M.OnEquip(tower, artifactId)
    if not tower or not tower.node then return end

    -- 先清除同 ID 的旧 VFX（防重复装备）
    M.OnUnequip(tower, artifactId)

    local creator = VFX_CREATORS[artifactId]
    if not creator then
        -- 未知圣器: 生成通用白色粒子占位
        creator = function(n)
            return CreateParticleNode(n, {
                offset = ANCHOR_OFFSETS.tower_top,
                maxParticles = 8, emitRate = 4, life = 1.0,
                sizeMin = 0.02, sizeMax = 0.035, gravity = -0.3,
                shapeRadius = 0.1,
                velMin = Vector3(-0.2, 0.2, -0.2), velMax = Vector3(0.2, 0.6, 0.2),
                colors = {
                    { time = 0.0, color = Color(1, 1, 1, 0.8) },
                    { time = 1.0, color = Color(1, 1, 1, 0.0) },
                },
                matColor = Color(1, 1, 1, 0.8),
                emissive = Color(0.5, 0.5, 0.5),
            })
        end
    end

    local ok, vfxNode = pcall(creator, tower.node)
    if ok and vfxNode then
        if not tower.vfxNodes then tower.vfxNodes = {} end
        tower.vfxNodes[artifactId] = vfxNode
        print(string.format("[ArtifactVFX] OnEquip: %s → tower(%d,%d)", artifactId, tower.gx, tower.gz))
    else
        print(string.format("[ArtifactVFX] ERROR creating VFX for %s: %s", artifactId, tostring(vfxNode)))
    end
end

--- 圣器卸除时调用: 移除塔节点上对应的粒子 VFX 节点
--- @param tower table
--- @param artifactId string
function M.OnUnequip(tower, artifactId)
    if not tower or not tower.vfxNodes then return end
    local vfxNode = tower.vfxNodes[artifactId]
    if vfxNode then
        vfxNode:Remove()
        tower.vfxNodes[artifactId] = nil
        print(string.format("[ArtifactVFX] OnUnequip: %s → tower(%d,%d)", artifactId, tower.gx or 0, tower.gz or 0))
    end
end

--- 移除塔上所有圣器 VFX（塔被拆除时调用）
--- @param tower table
function M.OnTowerRemoved(tower)
    if not tower or not tower.vfxNodes then return end
    for id, node in pairs(tower.vfxNodes) do
        if node then node:Remove() end
    end
    tower.vfxNodes = {}
end

--- 每帧更新（目前 ParticleEmitter 自动运行，保留接口供未来动态 VFX 扩展）
--- @param dt number
function M.Update(dt)
    -- ParticleEmitter 由引擎自动每帧更新，此处预留动态效果接口
    -- 例如: 凝聚塔、复利圣器的发射率动态调整等
    for _, tower in ipairs(require("Config").GS.towers) do
        if tower.vfxNodes and tower.artPassiveEnergyRate and tower.artPassiveEnergyRate > 0 then
            -- 凝聚塔: 累积能量
            tower.artPassiveEnergyTimer = (tower.artPassiveEnergyTimer or 0) + dt
            if tower.artPassiveEnergyTimer >= 1.0 / tower.artPassiveEnergyRate then
                tower.artPassiveEnergyTimer = tower.artPassiveEnergyTimer - 1.0 / tower.artPassiveEnergyRate
                require("Config").GS.activeEnergy = math.min(
                    require("Config").GS.activeEnergy + 1,
                    require("Config").CONFIG.MaxActiveEnergy or 100
                )
            end
        end
    end
end

return M
