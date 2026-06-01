-- ============================================================================
-- Monster.lua — 怪物类型 / 路径寻路 / HP波次缩放 / 精英词缀 / 伤害 / 死亡
-- ============================================================================

local Cfg = require("Config")
local CONFIG = Cfg.CONFIG
local GS = Cfg.GS
local Utils = require("Utils")
local EnergyTower = require("EnergyTower")
local StatusEffect = require("StatusEffect")
local Wave -- lazy require to avoid circular dependency

local M = {}

-- HP 缩放: 使用 Wave.HPScaleFactor() (抛物线缩放, 见 Wave.lua)

-- ============================================================================
-- 怪物复合模型构建 (用基础几何体按类型堆叠，赋予各类型独特外形)
-- ============================================================================
local function BuildMonsterVisuals(node, typeDef, monsterType, isElite)
    local emitMult = isElite and 2.5 or 1.0
    local baseEmitR = typeDef.emissive.r * emitMult
    local baseEmitG = typeDef.emissive.g * emitMult
    local baseEmitB = typeDef.emissive.b * emitMult

    local bodyMat = Material:new()
    bodyMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
    bodyMat:SetShaderParameter("MatDiffColor", Variant(typeDef.color))
    bodyMat:SetShaderParameter("MatEmissiveColor", Variant(Color(baseEmitR, baseEmitG, baseEmitB)))
    bodyMat:SetShaderParameter("Metallic", Variant(0.1))
    bodyMat:SetShaderParameter("Roughness", Variant(0.8))

    local c = typeDef.color

    -- 辅助: 快速添加子部件
    local function Part(name, mdl, mat, px, py, pz, sx, sy, sz, rq)
        local pn = node:CreateChild(name)
        pn.position = Vector3(px, py, pz)
        pn.scale    = Vector3(sx, sy, sz)
        if rq then pn.rotation = rq end
        local m = pn:CreateComponent("StaticModel")
        m:SetModel(cache:GetResource("Model", mdl))
        m:SetMaterial(mat)
        m.castShadows = true
    end

    -- 辅助: 创建发光眼睛材质
    local function EyeMat(r, g, b, er, eg, eb)
        local em = Material:new()
        em:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        em:SetShaderParameter("MatDiffColor",    Variant(Color(r,  g,  b,  1)))
        em:SetShaderParameter("MatEmissiveColor", Variant(Color(er, eg, eb)))
        em:SetShaderParameter("Metallic",  Variant(0.0))
        em:SetShaderParameter("Roughness", Variant(0.4))
        return em
    end

    if monsterType == "walker" then
        -- 行尸: 椭球躯干 + 驼背头 + 僵尸前伸长臂 + 短腿 + 发光眼
        Part("Body", "Models/Sphere.mdl",   bodyMat, 0, 0.52, 0,    0.92, 0.78, 0.85)
        Part("Hump", "Models/Sphere.mdl",   bodyMat, 0, 0.88, -0.12, 0.48, 0.38, 0.45)  -- 驼背隆起
        Part("Head", "Models/Sphere.mdl",   bodyMat, 0, 1.08, 0.15, 0.48, 0.46, 0.48)
        Part("ArmL", "Models/Cylinder.mdl", bodyMat, -0.50, 0.82, 0.35, 0.14, 0.62, 0.14, Quaternion(-70, 0, -20))
        Part("ArmR", "Models/Cylinder.mdl", bodyMat,  0.50, 0.82, 0.35, 0.14, 0.62, 0.14, Quaternion(-70, 0,  20))
        Part("ClawL", "Models/Cone.mdl",    bodyMat, -0.50, 0.55, 0.72, 0.10, 0.18, 0.10, Quaternion(90, Vector3.RIGHT))  -- 爪
        Part("ClawR", "Models/Cone.mdl",    bodyMat,  0.50, 0.55, 0.72, 0.10, 0.18, 0.10, Quaternion(90, Vector3.RIGHT))
        Part("LegL", "Models/Cylinder.mdl", bodyMat, -0.28, 0.18, 0, 0.16, 0.34, 0.16)
        Part("LegR", "Models/Cylinder.mdl", bodyMat,  0.28, 0.18, 0, 0.16, 0.34, 0.16)
        -- 暗红发光眼
        local em = EyeMat(1.0, 0.15, 0.1, 2.8, 0.4, 0.2)
        Part("EyeL", "Models/Sphere.mdl", em, -0.14, 1.14, 0.38, 0.10, 0.08, 0.08)
        Part("EyeR", "Models/Sphere.mdl", em,  0.14, 1.14, 0.38, 0.10, 0.08, 0.08)

    elseif monsterType == "swarm" then
        -- 群虫: 分段甲虫体 + 8根放射刺腿 + 触角 + 发光复眼
        Part("Body", "Models/Sphere.mdl", bodyMat, 0, 0.22, 0, 1.20, 0.38, 1.20)
        -- 腹部分段
        local segMat = bodyMat:Clone()
        segMat:SetShaderParameter("MatDiffColor", Variant(Color(c.r*0.7, c.g*0.8, c.b*0.6, 1)))
        segMat:SetShaderParameter("Metallic", Variant(0.25))
        segMat:SetShaderParameter("Roughness", Variant(0.55))
        Part("Seg1", "Models/Sphere.mdl", segMat, 0, 0.22, -0.38, 0.55, 0.30, 0.48)
        Part("Seg2", "Models/Sphere.mdl", segMat, 0, 0.20, -0.72, 0.38, 0.24, 0.35)
        -- 8根刺腿（更多更密）
        for i = 0, 7 do
            local rad = math.rad(i * 45)
            Part("Leg"..i, "Models/Cone.mdl", bodyMat,
                math.sin(rad)*0.68, 0.10, math.cos(rad)*0.68,
                0.10, 0.48, 0.10,
                Quaternion(i*45, Vector3.UP) * Quaternion(60, Vector3.RIGHT))
        end
        -- 触角
        Part("AntL", "Models/Cylinder.mdl", bodyMat, -0.18, 0.34, 0.55, 0.04, 0.36, 0.04, Quaternion(-30, Vector3.RIGHT) * Quaternion(-15, Vector3.FORWARD))
        Part("AntR", "Models/Cylinder.mdl", bodyMat,  0.18, 0.34, 0.55, 0.04, 0.36, 0.04, Quaternion(-30, Vector3.RIGHT) * Quaternion(15, Vector3.FORWARD))
        -- 发光绿色复眼
        local em = EyeMat(0.4, 1.0, 0.2, 0.8, 2.8, 0.4)
        Part("EyeL", "Models/Sphere.mdl", em, -0.22, 0.30, 0.50, 0.12, 0.10, 0.10)
        Part("EyeR", "Models/Sphere.mdl", em,  0.22, 0.30, 0.50, 0.12, 0.10, 0.10)

    elseif monsterType == "shellbeast" then
        -- 甲壳兽: 宽扁躯干 + 多层背甲 + 前角 + 短粗腿 + 琥珀色眼
        Part("Body", "Models/Box.mdl", bodyMat, 0, 0.36, 0, 1.10, 0.58, 1.38)
        -- 深色金属背甲（分层叠加）
        local shellMat = bodyMat:Clone()
        shellMat:SetShaderParameter("MatDiffColor",    Variant(Color(c.r*0.55, c.g*0.45, c.b*0.30, 1)))
        shellMat:SetShaderParameter("MatEmissiveColor", Variant(Color(baseEmitR*0.5, baseEmitG*0.4, baseEmitB*0.3)))
        shellMat:SetShaderParameter("Metallic",  Variant(0.55))
        shellMat:SetShaderParameter("Roughness", Variant(0.30))
        Part("Shell1", "Models/Sphere.mdl", shellMat, 0, 0.78, -0.12, 1.22, 0.52, 1.35)
        Part("Shell2", "Models/Sphere.mdl", shellMat, 0, 0.92, -0.18, 0.90, 0.38, 1.00)  -- 上层小甲
        -- 前端尖角
        Part("HornL", "Models/Cone.mdl", shellMat, -0.32, 0.62, 0.72, 0.10, 0.28, 0.10, Quaternion(70, Vector3.RIGHT))
        Part("HornR", "Models/Cone.mdl", shellMat,  0.32, 0.62, 0.72, 0.10, 0.28, 0.10, Quaternion(70, Vector3.RIGHT))
        -- 小头
        Part("Head", "Models/Sphere.mdl", bodyMat, 0, 0.50, 0.78, 0.42, 0.38, 0.42)
        -- 4条短粗腿
        for i, lp in ipairs({{-0.42,0.14,0.35},{0.42,0.14,0.35},{-0.42,0.14,-0.35},{0.42,0.14,-0.35}}) do
            Part("Leg"..i, "Models/Cylinder.mdl", bodyMat, lp[1],lp[2],lp[3], 0.18,0.28,0.18)
        end
        -- 琥珀色小眼
        local em = EyeMat(1.0, 0.7, 0.1, 2.2, 1.5, 0.2)
        Part("EyeL", "Models/Sphere.mdl", em, -0.12, 0.58, 0.92, 0.08, 0.07, 0.07)
        Part("EyeR", "Models/Sphere.mdl", em,  0.12, 0.58, 0.92, 0.08, 0.07, 0.07)

    elseif monsterType == "sprinter" then
        -- 疾行者: 流线型椭球 + 尖锥头 + 背鳍 + 尾锥 + 4细腿 + 冰蓝眼
        Part("Body", "Models/Sphere.mdl", bodyMat, 0, 0.42, 0, 0.60, 0.52, 1.42)
        Part("Nose", "Models/Cone.mdl",   bodyMat, 0, 0.42, 0.95, 0.22, 0.48, 0.22, Quaternion(90, Vector3.RIGHT))
        -- 背鳍（3个从大到小）
        local finMat = bodyMat:Clone()
        finMat:SetShaderParameter("MatDiffColor", Variant(Color(c.r*0.8, c.g*0.9, c.b*1.2, 1)))
        finMat:SetShaderParameter("Metallic", Variant(0.40))
        finMat:SetShaderParameter("Roughness", Variant(0.35))
        Part("Fin1", "Models/Cone.mdl", finMat, 0, 0.72, -0.10, 0.06, 0.28, 0.12, Quaternion(0,0,0))
        Part("Fin2", "Models/Cone.mdl", finMat, 0, 0.66, -0.35, 0.05, 0.22, 0.10, Quaternion(0,0,0))
        Part("Fin3", "Models/Cone.mdl", finMat, 0, 0.60, -0.55, 0.04, 0.16, 0.08, Quaternion(0,0,0))
        -- 尾锥
        Part("Tail", "Models/Cone.mdl", bodyMat, 0, 0.40, -0.90, 0.15, 0.35, 0.15, Quaternion(-90, Vector3.RIGHT))
        -- 4条修长腿
        for i, lp in ipairs({{-0.32,0.16,0.30},{0.32,0.16,0.30},{-0.32,0.16,-0.30},{0.32,0.16,-0.30}}) do
            Part("Leg"..i, "Models/Cylinder.mdl", bodyMat, lp[1],lp[2],lp[3], 0.09,0.38,0.09)
        end
        -- 冰蓝发光眼
        local em = EyeMat(0.3, 0.8, 1.0, 0.5, 2.0, 3.5)
        Part("EyeL", "Models/Sphere.mdl", em, -0.16, 0.50, 0.62, 0.09, 0.07, 0.07)
        Part("EyeR", "Models/Sphere.mdl", em,  0.16, 0.50, 0.62, 0.09, 0.07, 0.07)

    elseif monsterType == "shielded" then
        -- 护盾怪: 核心球 + 内部光核 + 8根尖刺 + 赤道环 + 紫色发光眼
        Part("Body", "Models/Sphere.mdl", bodyMat, 0, 0.55, 0, 0.88, 0.84, 0.88)
        -- 内核发光球
        local coreMat = Material:new()
        coreMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        coreMat:SetShaderParameter("MatDiffColor",    Variant(Color(c.r*0.5, c.g*0.3, c.b*0.6, 1)))
        coreMat:SetShaderParameter("MatEmissiveColor", Variant(Color(baseEmitR*2.5, baseEmitG*2.0, baseEmitB*3.0)))
        coreMat:SetShaderParameter("Metallic",  Variant(0.0))
        coreMat:SetShaderParameter("Roughness", Variant(0.2))
        Part("Core", "Models/Sphere.mdl", coreMat, 0, 0.55, 0, 0.42, 0.42, 0.42)
        -- 8根尖刺（上下左右+斜向）
        local spikeMat = bodyMat:Clone()
        spikeMat:SetShaderParameter("Metallic", Variant(0.45))
        spikeMat:SetShaderParameter("Roughness", Variant(0.35))
        for i = 0, 7 do
            local rad = math.rad(i * 45)
            local yOff = (i % 2 == 0) and 0.10 or -0.08
            Part("Sp"..i, "Models/Cone.mdl", spikeMat,
                math.sin(rad)*0.88, 0.55 + yOff, math.cos(rad)*0.88,
                0.09, 0.38, 0.09,
                Quaternion(i*45, Vector3.UP) * Quaternion(-90, Vector3.RIGHT))
        end
        -- 赤道金属环
        local ringMat = bodyMat:Clone()
        ringMat:SetShaderParameter("MatDiffColor", Variant(Color(c.r*0.6, c.g*0.4, c.b*0.7, 1)))
        ringMat:SetShaderParameter("Metallic", Variant(0.70))
        ringMat:SetShaderParameter("Roughness", Variant(0.20))
        Part("Ring", "Models/Torus.mdl", ringMat, 0, 0.55, 0, 1.10, 0.10, 1.10)
        -- 紫色发光大眼
        local em = EyeMat(0.9, 0.6, 1.0, 2.2, 1.2, 4.0)
        Part("EyeL", "Models/Sphere.mdl", em, -0.22, 0.66, 0.42, 0.14, 0.13, 0.12)
        Part("EyeR", "Models/Sphere.mdl", em,  0.22, 0.66, 0.42, 0.14, 0.13, 0.12)

    elseif monsterType == "energy_devourer" then
        -- 吞能者: 球形核心 + 能量裂纹 + 双轨道环 + 4触手 + 金色大眼
        Part("Body", "Models/Sphere.mdl", bodyMat, 0, 0.50, 0, 0.85, 0.85, 0.85)
        -- 内核（高发光，模拟能量积蓄）
        local innerMat = Material:new()
        innerMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        innerMat:SetShaderParameter("MatDiffColor",    Variant(Color(c.r*1.2, c.g*1.1, c.b*0.2, 1)))
        innerMat:SetShaderParameter("MatEmissiveColor", Variant(Color(baseEmitR*3.0, baseEmitG*2.8, baseEmitB*0.8)))
        innerMat:SetShaderParameter("Metallic",  Variant(0.0))
        innerMat:SetShaderParameter("Roughness", Variant(0.15))
        Part("Inner", "Models/Sphere.mdl", innerMat, 0, 0.50, 0, 0.40, 0.40, 0.40)
        -- 双轨道环（不同倾角）
        local orbitMat = Material:new()
        orbitMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
        orbitMat:SetShaderParameter("MatDiffColor",    Variant(Color(c.r, c.g, c.b, 0.72)))
        orbitMat:SetShaderParameter("MatEmissiveColor", Variant(Color(baseEmitR*2.5, baseEmitG*2.5, baseEmitB*1.5)))
        orbitMat:SetShaderParameter("Metallic",  Variant(0.85))
        orbitMat:SetShaderParameter("Roughness", Variant(0.12))
        Part("Orbit1", "Models/Torus.mdl", orbitMat, 0, 0.50, 0, 1.38, 0.14, 1.38, Quaternion(50, Vector3.RIGHT))
        Part("Orbit2", "Models/Torus.mdl", orbitMat, 0, 0.50, 0, 1.22, 0.12, 1.22, Quaternion(-30, Vector3.FORWARD))
        -- 4条能量触手（锥体模拟）
        for i = 0, 3 do
            local rad = math.rad(i * 90 + 20)
            Part("Tend"..i, "Models/Cone.mdl", bodyMat,
                math.sin(rad)*0.52, 0.22, math.cos(rad)*0.52,
                0.08, 0.35, 0.08,
                Quaternion(i*90+20, Vector3.UP) * Quaternion(120, Vector3.RIGHT))
        end
        -- 金色发光大眼
        local em = EyeMat(1.0, 0.9, 0.2, 3.5, 2.8, 0.5)
        Part("EyeL", "Models/Sphere.mdl", em, -0.20, 0.62, 0.40, 0.16, 0.15, 0.14)
        Part("EyeR", "Models/Sphere.mdl", em,  0.20, 0.62, 0.40, 0.16, 0.15, 0.14)

    elseif monsterType == "shatter_titan" then
        -- 裂山巨像 Boss: 巨型方形躯干 + 护甲肩板 + 重型拳头 + 腰带 + 角盔头 + 粗腿 + 橙红眼
        -- 主躯干
        Part("Torso", "Models/Box.mdl", bodyMat, 0, 0.70, 0, 1.42, 1.22, 1.12)
        -- 护甲肩板（金属质感）
        local armorMat = bodyMat:Clone()
        armorMat:SetShaderParameter("MatDiffColor", Variant(Color(c.r*0.6, c.g*0.5, c.b*0.4, 1)))
        armorMat:SetShaderParameter("MatEmissiveColor", Variant(Color(baseEmitR*0.6, baseEmitG*0.5, baseEmitB*0.3)))
        armorMat:SetShaderParameter("Metallic", Variant(0.65))
        armorMat:SetShaderParameter("Roughness", Variant(0.25))
        Part("ShoulderL", "Models/Box.mdl", armorMat, -0.88, 1.30, 0, 0.52, 0.35, 0.92)
        Part("ShoulderR", "Models/Box.mdl", armorMat,  0.88, 1.30, 0, 0.52, 0.35, 0.92)
        Part("Belt", "Models/Box.mdl", armorMat, 0, 0.20, 0, 1.50, 0.18, 1.18)  -- 腰带
        -- 重型拳头
        Part("FistL", "Models/Sphere.mdl", armorMat, -1.02, 0.55, 0.25, 0.38, 0.36, 0.38)
        Part("FistR", "Models/Sphere.mdl", armorMat,  1.02, 0.55, 0.25, 0.38, 0.36, 0.38)
        -- 球头 + 双角
        Part("Head", "Models/Sphere.mdl", bodyMat, 0, 1.78, 0, 0.80, 0.78, 0.80)
        Part("HornL", "Models/Cone.mdl", armorMat, -0.28, 2.12, -0.08, 0.12, 0.35, 0.12, Quaternion(-15, Vector3.FORWARD))
        Part("HornR", "Models/Cone.mdl", armorMat,  0.28, 2.12, -0.08, 0.12, 0.35, 0.12, Quaternion(15, Vector3.FORWARD))
        -- 4条粗腿
        for i, lp in ipairs({{-0.50,0.18,0.32},{0.50,0.18,0.32},{-0.50,0.18,-0.32},{0.50,0.18,-0.32}}) do
            Part("Leg"..i, "Models/Cylinder.mdl", bodyMat, lp[1],lp[2],lp[3], 0.36, 0.50, 0.36)
        end
        -- 橙红炽热发光眼
        local em = EyeMat(1.0, 0.45, 0.1, 4.0, 1.8, 0.3)
        Part("EyeL", "Models/Sphere.mdl", em, -0.22, 1.86, 0.38, 0.18, 0.16, 0.15)
        Part("EyeR", "Models/Sphere.mdl", em,  0.22, 1.86, 0.38, 0.18, 0.16, 0.15)

    elseif monsterType == "line_devourer" then
        -- 吞线母体 Boss: 巨型球核 + 内核光球 + 三重轨道环 + 6卫星 + 8能量触须 + 脊柱冠 + 紫色巨眼
        Part("Core", "Models/Sphere.mdl", bodyMat, 0, 0.88, 0, 1.62, 1.62, 1.62)

        -- 内部能量核心（强发光）
        local innerMat = Material:new()
        innerMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTexture.xml"))
        innerMat:SetShaderParameter("MatDiffColor",    Variant(Color(c.r*1.5, c.g*0.6, c.b*1.8, 1)))
        innerMat:SetShaderParameter("MatEmissiveColor", Variant(Color(baseEmitR*4.0, baseEmitG*2.0, baseEmitB*5.0)))
        innerMat:SetShaderParameter("Metallic",  Variant(0.0))
        innerMat:SetShaderParameter("Roughness", Variant(0.10))
        Part("Inner", "Models/Sphere.mdl", innerMat, 0, 0.88, 0, 0.65, 0.65, 0.65)

        -- 三重轨道环（不同角度、尺寸递减）
        local ringRots   = { Quaternion(0,0,0), Quaternion(60,Vector3.RIGHT), Quaternion(-50,Vector3.FORWARD) }
        local ringScales = { 2.15, 1.85, 1.55 }
        local ringAlphas = { 0.72, 0.55, 0.42 }
        for i, rq in ipairs(ringRots) do
            local rm = Material:new()
            rm:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
            rm:SetShaderParameter("MatDiffColor",    Variant(Color(c.r, c.g, c.b, ringAlphas[i])))
            rm:SetShaderParameter("MatEmissiveColor", Variant(Color(baseEmitR*2.2, baseEmitG*1.8, baseEmitB*2.8)))
            rm:SetShaderParameter("Metallic",  Variant(0.80))
            rm:SetShaderParameter("Roughness", Variant(0.12))
            Part("Ring"..i, "Models/Torus.mdl", rm, 0, 0.88, 0, ringScales[i], 0.18, ringScales[i], rq)
        end

        -- 6 卫星球（围绕核心，交替高低）
        for i = 0, 5 do
            local rad = math.rad(i * 60 + 30)
            local yOff = (i % 2 == 0) and 0.15 or -0.12
            Part("Sat"..i, "Models/Sphere.mdl", bodyMat,
                math.sin(rad)*1.55, 0.88 + yOff, math.cos(rad)*1.55, 0.32, 0.32, 0.32)
        end

        -- 8 根能量触须（向下延伸，从核心底部放射）
        local tendMat = bodyMat:Clone()
        tendMat:SetShaderParameter("MatDiffColor", Variant(Color(c.r*0.7, c.g*0.4, c.b*0.9, 1)))
        tendMat:SetShaderParameter("MatEmissiveColor", Variant(Color(baseEmitR*1.8, baseEmitG*1.0, baseEmitB*2.5)))
        tendMat:SetShaderParameter("Metallic", Variant(0.30))
        tendMat:SetShaderParameter("Roughness", Variant(0.45))
        for i = 0, 7 do
            local rad = math.rad(i * 45)
            Part("Tend"..i, "Models/Cone.mdl", tendMat,
                math.sin(rad)*0.72, 0.18, math.cos(rad)*0.72,
                0.10, 0.52, 0.10,
                Quaternion(i*45, Vector3.UP) * Quaternion(135, Vector3.RIGHT))
        end

        -- 脊柱冠（顶部向上的尖刺，像王冠）
        local spineMat = bodyMat:Clone()
        spineMat:SetShaderParameter("MatDiffColor", Variant(Color(c.r*0.5, c.g*0.3, c.b*0.7, 1)))
        spineMat:SetShaderParameter("Metallic", Variant(0.60))
        spineMat:SetShaderParameter("Roughness", Variant(0.22))
        for i = 0, 5 do
            local rad = math.rad(i * 60)
            local h = (i % 2 == 0) and 0.42 or 0.30
            Part("Spine"..i, "Models/Cone.mdl", spineMat,
                math.sin(rad)*0.45, 1.72 + h*0.5, math.cos(rad)*0.45,
                0.08, h, 0.08)
        end

        -- 紫色巨型眼（Boss 级大眼增强辨识度）
        local em = EyeMat(0.85, 0.25, 1.0, 3.5, 0.8, 5.5)
        Part("EyeL", "Models/Sphere.mdl", em, -0.40, 1.06, 0.78, 0.28, 0.26, 0.25)
        Part("EyeR", "Models/Sphere.mdl", em,  0.40, 1.06, 0.78, 0.28, 0.26, 0.25)
        Part("EyeM", "Models/Sphere.mdl", em,  0.00, 1.22, 0.82, 0.18, 0.16, 0.15)

    else
        -- 兜底
        Part("Body", "Models/Sphere.mdl", bodyMat, 0,0.50,0, 0.85,0.85,0.85)
    end

    return bodyMat, baseEmitR, baseEmitG, baseEmitB
end

-- ============================================================================
-- 怪物类型定义 (对齐 enemies.json)
-- ============================================================================
M.TYPES = {
    walker = {
        name = "行尸",
        base_hp = 50,
        base_speed = 1.0,
        armor_ratio = 0,
        shield_hp = 0,
        reward_gold = 5,
        reward_material = 0,
        reward_energy = 0,
        size = 0.38,
        color = Color(0.85, 0.22, 0.18, 1),
        emissive = Color(0.35, 0.08, 0.05),
    },
    swarm = {
        name = "群虫",
        base_hp = 25,
        base_speed = 1.2,
        armor_ratio = 0,
        shield_hp = 0,
        reward_gold = 2,
        reward_material = 0,
        reward_energy = 0,
        size = 0.23,
        color = Color(0.25, 0.60, 0.20, 1),
        emissive = Color(0.08, 0.25, 0.05),
    },
    shellbeast = {
        name = "甲壳兽",
        base_hp = 80,
        base_speed = 0.6,
        armor_ratio = 0.5,
        shield_hp = 0,
        reward_gold = 10,
        reward_material = 1,
        reward_energy = 0,
        size = 0.49,
        color = Color(0.50, 0.35, 0.18, 1),
        emissive = Color(0.20, 0.12, 0.05),
    },
    sprinter = {
        name = "疾行者",
        base_hp = 35,
        base_speed = 2.0,
        armor_ratio = 0,
        shield_hp = 0,
        reward_gold = 6,
        reward_material = 0,
        reward_energy = 0,
        size = 0.30,
        color = Color(0.20, 0.65, 0.90, 1),
        emissive = Color(0.10, 0.30, 0.50),
    },
    shielded = {
        name = "护盾怪",
        base_hp = 50,
        base_speed = 1.0,
        armor_ratio = 0,
        shield_hp = 30,
        reward_gold = 8,
        reward_material = 0,
        reward_energy = 0,
        size = 0.40,
        color = Color(0.65, 0.25, 0.80, 1),
        emissive = Color(0.30, 0.10, 0.40),
    },
    energy_devourer = {
        name = "吞能者",
        base_hp = 60,
        base_speed = 1.0,
        armor_ratio = 0,
        shield_hp = 0,
        reward_gold = 8,
        reward_material = 0,
        reward_energy = 0,
        lineDmgReduction = 0.4, -- 经过能源线时该线对自己伤害 -40%
        size = 0.42,
        color = Color(0.75, 0.60, 0.15, 1),
        emissive = Color(0.35, 0.25, 0.05),
    },
}

-- Boss 类型 (独立表，HP 不随波次缩放 — 已含固定高 HP)
M.BOSSES = {
    shatter_titan = {
        name = "裂山巨像",
        base_hp = 1900,
        base_speed = 0.5,
        armor_ratio = 0,
        shield_hp = 0,
        is_boss = true,
        reward_gold = 200,
        reward_material = 50,
        reward_energy = 30,
        size = 0.80,
        color = Color(0.40, 0.27, 0.13, 1),
        emissive = Color(0.30, 0.15, 0.05),
        -- 特殊: 每15s获得护甲buff持续8s
        armorCycleInterval = 15.0,
        armorBuffDuration = 8.0,
        armorBuffValue = 0.50, -- +50% 护甲
    },
    line_devourer = {
        name = "吞线母体",
        base_hp = 7200,
        base_speed = 0.5,
        armor_ratio = 0,
        shield_hp = 0,
        is_boss = true,
        reward_gold = 500,
        reward_material = 150,
        reward_energy = 100,
        size = 0.90,
        color = Color(0.40, 0.13, 0.67, 1),
        emissive = Color(0.30, 0.10, 0.50),
        -- 特殊: 免疫能源线伤害, 每30s吸取30%功率持续5s
        lineImmune = true,
        drainInterval = 30.0,
        drainDuration = 5.0,
        drainRatio = 0.30, -- 吸取30%总功率
    },
}

-- ============================================================================
-- 精英词缀定义 (对齐 enemies.json)
-- ============================================================================
M.ELITE_AFFIXES = {
    thick_armor = {
        name = "厚甲",
        hp_multiplier = 1.5,
        armor_multiplier = 3.0, -- 护甲系数 ×3
    },
    swift = {
        name = "迅捷",
        hp_multiplier = 1.3,
        speed_multiplier = 1.5,
    },
    burn_resist = {
        name = "抗燃",
        hp_multiplier = 1.4,
        burn_resist = 0.7, -- 燃烧持续 -70% (预留)
    },
    energy_drinker = {
        name = "吸能",
        hp_multiplier = 1.4,
        line_heal_per_sec = 5, -- 经过能源线时每秒回血
    },
}

-- ============================================================================
-- 内部: 获取类型定义 (普通 + Boss)
-- ============================================================================

local function GetTypeDef(monsterType)
    return M.TYPES[monsterType] or M.BOSSES[monsterType] or M.TYPES.walker
end

-- ============================================================================
-- 生成怪物
-- ============================================================================

--- @param monsterType string 怪物 ID (walker/swarm/shellbeast/sprinter/shielded/energy_devourer/shatter_titan/line_devourer)
--- @param opts table|nil { spawnX, spawnZ, waveNumber, eliteAffixes }
function M.SpawnMonster(monsterType, opts)
    -- Lazy require Wave to avoid circular dependency
    if not Wave then Wave = require("Wave") end

    monsterType = monsterType or "walker"
    opts = opts or {}
    local waveNumber = opts.waveNumber or 1
    local eliteAffixes = opts.eliteAffixes or {}
    local spawnX = opts.spawnX
    local spawnZ = opts.spawnZ

    local typeDef = GetTypeDef(monsterType)

    -- === 基础属性 ===
    local hp = typeDef.base_hp
    local speed = typeDef.base_speed
    local armorRatio = typeDef.armor_ratio or 0
    local shieldHp = typeDef.shield_hp or 0

    -- === HP 波次缩放 (抛物线公式) ===
    local isBoss = typeDef.is_boss or false
    local scaleFactor = Wave.HPScaleFactor(waveNumber, isBoss)
    hp = hp * scaleFactor

    -- === 精英词缀 ===
    local isElite = #eliteAffixes > 0
    local lineHealPerSec = 0
    local affixNames = {}

    for _, affixId in ipairs(eliteAffixes) do
        local affix = M.ELITE_AFFIXES[affixId]
        if affix then
            table.insert(affixNames, affix.name)
            if affix.hp_multiplier then hp = hp * affix.hp_multiplier end
            if affix.speed_multiplier then speed = speed * affix.speed_multiplier end
            if affix.armor_multiplier then armorRatio = armorRatio * affix.armor_multiplier end
            if affix.line_heal_per_sec then lineHealPerSec = lineHealPerSec + affix.line_heal_per_sec end
        end
    end

    -- 护甲上限 0.9
    armorRatio = math.min(armorRatio, 0.9)
    -- 护盾也随波次缩放
    if shieldHp > 0 then
        shieldHp = shieldHp * scaleFactor
    end

    hp = math.floor(hp + 0.5)
    shieldHp = math.floor(shieldHp + 0.5)

    -- === 出生位置 (路径起点 / 兜底随机) ===
    local sx, sz
    if spawnX and spawnZ then
        sx = spawnX
        sz = spawnZ
    else
        -- 兜底: 随机角度
        local angle = math.random() * math.pi * 2
        local sd = CONFIG.SpawnDistance
        sx = math.cos(angle) * sd
        sz = math.sin(angle) * sd
    end

    -- 路径跟随数据 (由 Wave.lua 在 opts 中传入)
    local pathData = opts.pathData       -- 路径航点列表 { {x,z}, ... }
    local pathWidth = opts.pathWidth or 10  -- 路径宽度
    local waypointIdx = 2                 -- 从第2个航点开始追踪（第1个是出生点）

    -- 路径横向偏移 (让每个怪物走略微不同的车道，分散行进)
    local laneOffset = (math.random() - 0.5) * pathWidth * 0.6  -- ±30% 路径宽度

    -- === 创建节点 ===
    local node = GS.scene:CreateChild("Monster")
    local s = typeDef.size
    -- 精英/Boss 略微放大
    if isElite then s = s * 1.2 end

    node.position = Vector3(sx, 0, sz)
    node.scale = Vector3(s, s, s)

    -- 朝向能源塔中心
    local dx = 0 - sx
    local dz = 0 - sz
    local yaw = math.deg(math.atan(dx, dz))
    node.rotation = Quaternion(yaw, Vector3.UP)

    -- === 复合模型 ===
    local mat, baseEmitR, baseEmitG, baseEmitB = BuildMonsterVisuals(node, typeDef, monsterType, isElite)

    -- 移动方向 (初始: 朝向能源塔中心)
    local dirDx = 0 - sx
    local dirDz = 0 - sz
    local dirLen = math.sqrt(dirDx * dirDx + dirDz * dirDz)
    local dir = dirLen > 0.01 and Vector3(dirDx / dirLen, 0, dirDz / dirLen) or Vector3(0, 0, 1)

    -- 脚底红色位置指示圆圈
    -- 圆圈挂在 node 子节点上:
    --   node.position.y = 0 (贴地), node.scale = (s,s,s)
    --   子节点世界Y = 0 + s * localY  => localY = groundY/s
    --   子节点世界半径 = s * localScale  => localScale = worldRadius/s
    local footCircleNode = node:CreateChild("FootCircle")
    local groundY  = CONFIG.GridY + 0.012   -- 贴地稍微浮起避免 z-fighting
    local invS = 1.0 / s
    -- XZ 方向: 圆圈世界半径随怪物大小略变, 但不会太小
    local circleWorldR = math.max(0.28, s * 1.15)
    footCircleNode.position = Vector3(0, groundY * invS, 0)
    footCircleNode.scale    = Vector3(invS * circleWorldR, 1.0, invS * circleWorldR)

    local footGeom = footCircleNode:CreateComponent("CustomGeometry")
    do
        -- 环形带: 贴地平放, Y轴朝上
        local segs = 20
        local innerR = 0.88
        local outerR = 1.0
        footGeom:BeginGeometry(0, TRIANGLE_LIST)
        for i = 0, segs - 1 do
            local a0 = (i / segs) * math.pi * 2
            local a1 = ((i + 1) / segs) * math.pi * 2
            local ci0, si0 = math.cos(a0), math.sin(a0)
            local ci1, si1 = math.cos(a1), math.sin(a1)
            footGeom:DefineVertex(Vector3(ci0 * innerR, 0, si0 * innerR)); footGeom:DefineNormal(Vector3.UP)
            footGeom:DefineVertex(Vector3(ci1 * innerR, 0, si1 * innerR)); footGeom:DefineNormal(Vector3.UP)
            footGeom:DefineVertex(Vector3(ci1 * outerR, 0, si1 * outerR)); footGeom:DefineNormal(Vector3.UP)
            footGeom:DefineVertex(Vector3(ci0 * innerR, 0, si0 * innerR)); footGeom:DefineNormal(Vector3.UP)
            footGeom:DefineVertex(Vector3(ci1 * outerR, 0, si1 * outerR)); footGeom:DefineNormal(Vector3.UP)
            footGeom:DefineVertex(Vector3(ci0 * outerR, 0, si0 * outerR)); footGeom:DefineNormal(Vector3.UP)
        end
        footGeom:Commit()
        local footMat = Material:new()
        footMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
        -- Boss 用橙色, 精英用品红, 普通用红色
        local fr, fg, fb, fa
        if isBoss then
            fr, fg, fb, fa = 1.0, 0.45, 0.0, 0.85
        elseif isElite then
            fr, fg, fb, fa = 1.0, 0.10, 0.85, 0.78
        else
            fr, fg, fb, fa = 0.95, 0.08, 0.05, 0.65
        end
        footMat:SetShaderParameter("MatDiffColor",    Variant(Color(fr, fg, fb, fa)))
        footMat:SetShaderParameter("MatEmissiveColor", Variant(Color(fr * 0.55, fg * 0.15, fb * 0.15)))
        footMat:SetShaderParameter("Metallic",  Variant(0.0))
        footMat:SetShaderParameter("Roughness", Variant(1.0))
        footGeom:SetMaterial(footMat)
    end

    -- 血条
    local hpBg, hpFill, fillMat = Utils.CreateHealthBar(node)

    -- 护盾视觉
    ---@type Node
    local shieldNode = nil
    if shieldHp > 0 then
        shieldNode = node:CreateChild("Shield")
        local shieldScale = 1.8
        shieldNode.scale = Vector3(shieldScale, shieldScale, shieldScale)
        local shieldModel = shieldNode:CreateComponent("StaticModel")
        shieldModel:SetModel(cache:GetResource("Model", "Models/Sphere.mdl"))
        local shieldMat = Material:new()
        shieldMat:SetTechnique(0, cache:GetResource("Technique", "Techniques/PBR/PBRNoTextureAlpha.xml"))
        shieldMat:SetShaderParameter("MatDiffColor", Variant(Color(0.4, 0.3, 0.9, 0.25)))
        shieldMat:SetShaderParameter("MatEmissiveColor", Variant(Color(0.3, 0.2, 0.7)))
        shieldMat:SetShaderParameter("Metallic", Variant(0.0))
        shieldMat:SetShaderParameter("Roughness", Variant(0.3))
        shieldModel:SetMaterial(shieldMat)
        shieldModel.castShadows = false
    end

    -- === 怪物实例 ===
    local monster = {
        node = node,
        type = monsterType,
        hp = hp,
        maxHp = hp,
        speed = speed,
        dir = dir,
        armorRatio = armorRatio,
        baseArmorRatio = armorRatio, -- 保存基础护甲 (Boss护甲buff需要)
        shield = shieldHp,
        maxShield = shieldHp,
        shieldNode = shieldNode,
        hpBg = hpBg,
        hpFill = hpFill,
        fillMat = fillMat,
        -- 掉落
        goldDrop = typeDef.reward_gold or 0,
        energyDrop = typeDef.reward_energy or 0,
        materialDrop = typeDef.reward_material or 0,
        -- 精英
        isElite = isElite,
        eliteAffixes = eliteAffixes,
        isBoss = typeDef.is_boss or false,
        -- 特殊属性
        lineDmgReduction = typeDef.lineDmgReduction or 0,
        lineHealPerSec = lineHealPerSec,
        lineImmune = typeDef.lineImmune or false,
        -- 路径跟随
        pathData = pathData,           -- 路径航点列表 (nil 则退化为冲向中心)
        pathWidth = pathWidth,
        waypointIdx = waypointIdx,     -- 当前追踪的下一个航点索引
        laneOffset = laneOffset,       -- 横向车道偏移 (分散行进)
        -- Boss: 裂山巨像护甲周期
        armorCycleTimer = 0,
        armorBuffTimer = 0,
        armorBuffValue = typeDef.armorBuffValue or 0,
        armorCycleInterval = typeDef.armorCycleInterval or 0,
        armorBuffDuration = typeDef.armorBuffDuration or 0,
        -- 受伤泛红
        bodyMat = mat,
        baseEmitR = baseEmitR,
        baseEmitG = baseEmitG,
        baseEmitB = baseEmitB,
        flashTimer = 0,
        -- Boss: 吞线母体功率吸取
        drainTimer = 0,
        drainActiveTimer = 0,
        drainInterval = typeDef.drainInterval or 0,
        drainDuration = typeDef.drainDuration or 0,
        drainRatio = typeDef.drainRatio or 0,
        drainActive = false,
    }
    -- 初始化状态效果容器
    StatusEffect.InitMonsterEffects(monster)
    table.insert(GS.monsters, monster)

    -- 日志
    local label = typeDef.name
    if isElite then label = "[" .. table.concat(affixNames, "+") .. "] " .. label end
    if typeDef.is_boss then label = "★ BOSS: " .. label end
    print(string.format("[Monster] Spawned %s | HP: %d | Spd: %.1f | Armor: %.0f%%",
        label, hp, speed, armorRatio * 100))
end

-- ============================================================================
-- 转向避障
-- ============================================================================

--- 计算避障推力 (检测前方障碍物)
--- @param pos Vector3 当前位置
--- @param dir Vector3 当前移动方向 (归一化)
--- @return number pushX, number pushZ 推力分量
local function CalculateSteering(pos, dir, monsterSize)
    local lookAhead = CONFIG.SteerLookAhead
    local pushForce = CONFIG.SteerPushForce
    local monsterR = (monsterSize or 0.35) * 0.5  -- 怪物自身碰撞半径

    -- 前视位置
    local aheadX = pos.x + dir.x * lookAhead
    local aheadZ = pos.z + dir.z * lookAhead
    local pushX, pushZ = 0, 0

    -- 检测塔 (塔占据约 1x1 格)
    local towerAvoidR = CONFIG.SteerAvoidRadius + 0.3
    for _, t in ipairs(GS.towers) do
        if t.node then
            local tp = t.node.position
            local ddx = aheadX - tp.x
            local ddz = aheadZ - tp.z
            local dist = math.sqrt(ddx * ddx + ddz * ddz)
            if dist < towerAvoidR then
                local factor = pushForce * (1.0 - dist / towerAvoidR)
                if dist > 0.01 then
                    pushX = pushX + (ddx / dist) * factor
                    pushZ = pushZ + (ddz / dist) * factor
                else
                    pushX = pushX + (math.random() - 0.5) * factor
                    pushZ = pushZ + (math.random() - 0.5) * factor
                end
            end
        end
    end

    -- 检测地形物件 (用物件实际尺寸作碰撞半径)
    for _, obj in ipairs(GS.terrainObjects) do
        if obj.node then
            local op = obj.node.position
            local objSize = obj.node.scale.x  -- Terrain.lua 中 scale = (s,s,s)
            -- 避障半径 = 物件半径 + 怪物半径 + 安全间距
            local objAvoidR = objSize * 0.6 + monsterR + 0.4

            -- 同时检测前视位置和当前位置 (双重检查)
            for probe = 1, 2 do
                local px = (probe == 1) and aheadX or pos.x
                local pz = (probe == 1) and aheadZ or pos.z
                local ddx = px - op.x
                local ddz = pz - op.z
                local dist = math.sqrt(ddx * ddx + ddz * ddz)
                if dist < objAvoidR then
                    -- 越近推力越强, 双重探针时当前位置推力更大
                    local strength = (probe == 1) and pushForce or (pushForce * 2.0)
                    local factor = strength * (1.0 - dist / objAvoidR)
                    if dist > 0.01 then
                        pushX = pushX + (ddx / dist) * factor
                        pushZ = pushZ + (ddz / dist) * factor
                    else
                        pushX = pushX + (math.random() - 0.5) * factor * 2
                        pushZ = pushZ + (math.random() - 0.5) * factor * 2
                    end
                end
            end
        end
    end

    return pushX, pushZ
end

-- 硬碰撞: 将怪物推出地形物件 (防止重叠穿模)
local function EnforceTerrainCollision(pos, monsterSize)
    local monsterR = (monsterSize or 0.35) * 0.5
    local corrected = false
    for _, obj in ipairs(GS.terrainObjects) do
        if obj.node then
            local op = obj.node.position
            local objSize = obj.node.scale.x  -- Terrain.lua 中 scale = (s,s,s)
            local collisionR = objSize * 0.55 + monsterR  -- 硬碰撞半径(略小于避障)
            local ddx = pos.x - op.x
            local ddz = pos.z - op.z
            local dist = math.sqrt(ddx * ddx + ddz * ddz)
            if dist < collisionR then
                -- 直接推出到碰撞半径边界
                if dist > 0.01 then
                    local pushOut = collisionR - dist + 0.05
                    pos.x = pos.x + (ddx / dist) * pushOut
                    pos.z = pos.z + (ddz / dist) * pushOut
                else
                    pos.x = pos.x + (math.random() - 0.5) * collisionR
                    pos.z = pos.z + (math.random() - 0.5) * collisionR
                end
                corrected = true
            end
        end
    end
    return corrected
end

-- ============================================================================
-- 怪物移动 (路径航点跟随 + 转向避障)
-- ============================================================================

--- 计算怪物期望移动方向 (路径跟随 / 退化为冲向中心)
--- @param m table 怪物实例
--- @param pos Vector3 当前位置
--- @return number desiredX, number desiredZ, boolean reachedEnd
local function CalcDesiredDirection(m, pos)
    -- 如果有路径数据, 沿航点移动
    if m.pathData and m.waypointIdx then
        local wp = m.pathData[m.waypointIdx]
        if not wp then
            -- 已超出航点列表 → 冲向能源塔中心
            local dx = 0 - pos.x
            local dz = 0 - pos.z
            local dist = math.sqrt(dx * dx + dz * dz)
            if dist < 1.0 then return 0, 0, true end
            return dx / dist, dz / dist, false
        end

        -- 目标航点方向
        local dx = wp[1] - pos.x
        local dz = wp[2] - pos.z
        local dist = math.sqrt(dx * dx + dz * dz)

        -- 到达当前航点阈值 (越宽的路径阈值稍大)
        local arriveThreshold = math.max(1.5, (m.pathWidth or 10) * 0.15)
        if dist < arriveThreshold then
            m.waypointIdx = m.waypointIdx + 1
            return CalcDesiredDirection(m, pos)
        end

        -- 应用车道偏移: 沿路径垂直方向偏移目标点，使怪物分散行进
        local offset = m.laneOffset or 0
        if offset ~= 0 and dist > 0.1 then
            -- 路径方向归一化
            local ndx, ndz = dx / dist, dz / dist
            -- 垂直方向 (左手坐标系下右侧)
            local perpX, perpZ = -ndz, ndx
            -- 接近最终目标时逐渐收拢 (最后3个航点衰减偏移)
            local remaining = #m.pathData - m.waypointIdx
            local fadeFactor = math.min(1.0, remaining / 3.0)
            local appliedOffset = offset * fadeFactor
            -- 偏移后的目标
            local targetX = wp[1] + perpX * appliedOffset
            local targetZ = wp[2] + perpZ * appliedOffset
            dx = targetX - pos.x
            dz = targetZ - pos.z
            dist = math.sqrt(dx * dx + dz * dz)
            if dist < 0.01 then dist = 0.01 end
        end

        return dx / dist, dz / dist, false
    end

    -- 无路径: 退化为冲向能源塔中心 (0,0)
    local dx = 0 - pos.x
    local dz = 0 - pos.z
    local dist = math.sqrt(dx * dx + dz * dz)
    if dist < 1.0 then return 0, 0, true end
    return dx / dist, dz / dist, false
end

function M.UpdateMonsters(dt)
    local i = 1
    while i <= #GS.monsters do
        local m = GS.monsters[i]
        if not m.node then
            table.remove(GS.monsters, i)
        else
            local pos = m.node.position
            local speed = StatusEffect.GetEffectiveSpeed(m)

            -- 计算期望方向 (路径跟随 or 冲向中心)
            local desiredX, desiredZ, reachedEnd = CalcDesiredDirection(m, pos)

            if not reachedEnd then
                -- 转向避障 (传入怪物尺寸用于计算碰撞半径)
                local mSize = m.node.scale.x
                local pushX, pushZ = CalculateSteering(pos, m.dir, mSize)

                -- 混合: 期望方向 + 推力
                local finalX = desiredX + pushX
                local finalZ = desiredZ + pushZ
                local finalLen = math.sqrt(finalX * finalX + finalZ * finalZ)
                if finalLen > 0.01 then
                    finalX = finalX / finalLen
                    finalZ = finalZ / finalLen
                else
                    finalX = desiredX
                    finalZ = desiredZ
                end

                -- 平滑转向 (lerp)
                local turnRate = 5.0 * dt
                m.dir = Vector3(
                    m.dir.x + (finalX - m.dir.x) * turnRate,
                    0,
                    m.dir.z + (finalZ - m.dir.z) * turnRate
                )
                -- 重新归一化
                local dl = math.sqrt(m.dir.x * m.dir.x + m.dir.z * m.dir.z)
                if dl > 0.01 then
                    m.dir = Vector3(m.dir.x / dl, 0, m.dir.z / dl)
                end

                -- 移动
                pos.x = pos.x + m.dir.x * speed * dt
                pos.z = pos.z + m.dir.z * speed * dt

                -- 硬碰撞: 防止怪物穿入地形物件
                EnforceTerrainCollision(pos, mSize)

                m.node.position = pos

                -- 更新朝向
                local moveYaw = math.deg(math.atan(m.dir.x, m.dir.z))
                m.node.rotation = Quaternion(moveYaw, Vector3.UP)
            end

            -- === Boss 特殊机制 ===
            if m.isBoss then
                M.UpdateBossMechanics(m, dt)
            end

            -- 更新血条
            Utils.UpdateHealthBar(m)

            -- 受伤泛红帧更新
            if m.flashTimer > 0 and m.bodyMat then
                m.flashTimer = m.flashTimer - dt
                local t = math.max(0, m.flashTimer / 0.30)  -- 1.0 → 0.0 衰减
                m.bodyMat:SetShaderParameter("MatEmissiveColor", Variant(Color(
                    m.baseEmitR + (4.5 - m.baseEmitR) * t,
                    m.baseEmitG * (1.0 - t * 0.95),
                    m.baseEmitB * (1.0 - t * 0.95)
                )))
                if m.flashTimer <= 0 then
                    -- 归零时恢复基础颜色
                    m.bodyMat:SetShaderParameter("MatEmissiveColor", Variant(Color(m.baseEmitR, m.baseEmitG, m.baseEmitB)))
                end
            end

            -- 到达终点: 伤害能源塔
            if reachedEnd then
                EnergyTower.DamageEnergyTower(CONFIG.MonsterDmgToTower)
                M.DestroyMonster(m)
                table.remove(GS.monsters, i)
            else
                i = i + 1
            end
        end
    end
end

-- ============================================================================
-- Boss 特殊机制
-- ============================================================================

--- 更新 Boss 专属机制 (每帧调用)
function M.UpdateBossMechanics(m, dt)
    -- === 裂山巨像: 周期护甲 buff ===
    if m.armorCycleInterval > 0 then
        if m.armorBuffTimer > 0 then
            -- buff 激活中
            m.armorBuffTimer = m.armorBuffTimer - dt
            if m.armorBuffTimer <= 0 then
                -- buff 结束，恢复基础护甲
                m.armorRatio = m.baseArmorRatio
                m.armorBuffTimer = 0
                -- 恢复颜色
                local model = m.node:GetComponent("StaticModel")
                if model then
                    local mat = model:GetMaterial(0)
                    if mat then
                        local typeDef = GetTypeDef(m.type)
                        mat:SetShaderParameter("MatEmissiveColor", Variant(Color(
                            typeDef.emissive.r, typeDef.emissive.g, typeDef.emissive.b)))
                    end
                end
            end
        else
            -- 等待下次触发
            m.armorCycleTimer = m.armorCycleTimer + dt
            if m.armorCycleTimer >= m.armorCycleInterval then
                m.armorCycleTimer = 0
                m.armorBuffTimer = m.armorBuffDuration
                -- 激活护甲 buff
                m.armorRatio = math.min(0.9, m.baseArmorRatio + m.armorBuffValue)
                -- 视觉: 发光变亮
                local model = m.node:GetComponent("StaticModel")
                if model then
                    local mat = model:GetMaterial(0)
                    if mat then
                        mat:SetShaderParameter("MatEmissiveColor",
                            Variant(Color(1.0, 0.6, 0.2)))
                    end
                end
                print(string.format("[Boss] 裂山巨像 护甲强化! Armor: %.0f%% (%.0fs)",
                    m.armorRatio * 100, m.armorBuffDuration))
            end
        end
    end

    -- === 吞线母体: 周期功率吸取 ===
    if m.drainInterval > 0 then
        if m.drainActive then
            -- 吸取中
            m.drainActiveTimer = m.drainActiveTimer - dt
            if m.drainActiveTimer <= 0 then
                -- 吸取结束
                m.drainActive = false
                m.drainActiveTimer = 0
                -- 恢复颜色
                local model = m.node:GetComponent("StaticModel")
                if model then
                    local mat = model:GetMaterial(0)
                    if mat then
                        local typeDef = GetTypeDef(m.type)
                        mat:SetShaderParameter("MatEmissiveColor", Variant(Color(
                            typeDef.emissive.r, typeDef.emissive.g, typeDef.emissive.b)))
                    end
                end
                -- 恢复功率 (重新计算供能)
                EnergyTower.RecalculateEnergy()
                EnergyTower.RebuildEnergyLines()
                print("[Boss] 吞线母体 功率吸取结束，供能恢复")
            end
        else
            -- 等待下次触发
            m.drainTimer = m.drainTimer + dt
            if m.drainTimer >= m.drainInterval then
                m.drainTimer = 0
                m.drainActive = true
                m.drainActiveTimer = m.drainDuration
                -- 视觉: 紫色发光
                local model = m.node:GetComponent("StaticModel")
                if model then
                    local mat = model:GetMaterial(0)
                    if mat then
                        mat:SetShaderParameter("MatEmissiveColor",
                            Variant(Color(0.8, 0.2, 1.5)))
                    end
                end
                print(string.format("[Boss] 吞线母体 功率吸取! 吸取 %.0f%% 功率 (%.0fs)",
                    m.drainRatio * 100, m.drainDuration))
            end
        end
    end
end

-- ============================================================================
-- 伤害与死亡
-- ============================================================================

--- 对怪物造成伤害
--- @param m table 怪物实例
--- @param dmg number 伤害值
--- @param isEnergyDmg boolean|nil 是否为能源伤害 (绕过物理护甲)
function M.DamageMonster(m, dmg, isEnergyDmg, skipText)
    if not m.node or m.hp <= 0 then return end

    -- 护盾先吸收 (所有伤害类型)
    if m.shield > 0 then
        if dmg <= m.shield then
            m.shield = m.shield - dmg
            if not skipText then
                Utils.SpawnDmgText(m.node.position, dmg)
            end
            if m.shieldNode and m.shield <= 0 then
                m.shieldNode:Remove()
                m.shieldNode = nil
            end
            return
        else
            dmg = dmg - m.shield
            m.shield = 0
            if m.shieldNode then
                m.shieldNode:Remove()
                m.shieldNode = nil
            end
        end
    end

    -- 物理护甲减伤 (仅对非能源伤害)
    if not isEnergyDmg and m.armorRatio > 0 then
        dmg = dmg * (1.0 - m.armorRatio)
    end

    dmg = math.max(1, math.floor(dmg + 0.5))

    m.hp = m.hp - dmg
    -- 受伤泛红
    m.flashTimer = 0.30
    if not skipText then
        Utils.SpawnDmgText(m.node.position, dmg)
    end
    if m.hp <= 0 then
        M.KillMonster(m)
    end
end

function M.KillMonster(m)
    local pos = m.node.position
    GS.monstersKilled = GS.monstersKilled + 1

    if m.goldDrop > 0 then
        -- 金矿炼化: 击杀来源塔有 artGoldDropBonus 则增加掉落
        local goldAmt = m.goldDrop
        if m.lastHitTower and (m.lastHitTower.artGoldDropBonus or 0) > 0 then
            goldAmt = math.floor(goldAmt * (1.0 + m.lastHitTower.artGoldDropBonus) + 0.5)
        end
        Utils.SpawnLoot(pos, "gold", goldAmt)
    end
    if m.energyDrop > 0 then
        Utils.SpawnLoot(Vector3(pos.x + 0.3, pos.y, pos.z + 0.3), "energy", m.energyDrop)
    end
    if m.materialDrop > 0 then
        Utils.SpawnLoot(Vector3(pos.x - 0.3, pos.y, pos.z - 0.3), "material", m.materialDrop)
    end

    M.DestroyMonster(m)
end

function M.DestroyMonster(m)
    if m.shieldNode then m.shieldNode:Remove(); m.shieldNode = nil end
    if m.hpBg then m.hpBg:Remove(); m.hpBg = nil end
    if m.node then m.node:Remove(); m.node = nil end
    m.hp = 0
end

return M
