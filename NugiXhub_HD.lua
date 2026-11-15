--[[
    NugiXhub - HD | Roblox Client Graphics Utility
    Version: 1.0
    Target: Roblox Android / Delta Executor (client-side)

    NOTE:
    - This script changes only client-visible Lighting and post-processing properties.
    - It cannot change Roblox's device Graphics Quality slider, texture resolution,
      mesh detail, server state, or render distance.
    - Reset Graphics restores values captured when the script first ran and removes
      visual-effect instances created by this script.
]]

--// Services
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    return
end

--// Executor / GUI parent compatibility
local function getEnvironment()
    local ok, env = pcall(function()
        if type(getgenv) == "function" then
            return getgenv()
        end
        return _G
    end)
    if ok and type(env) == "table" then
        return env
    end
    return _G
end

local Environment = getEnvironment()

local function getGuiParent()
    local ok, hiddenGui = pcall(function()
        if type(gethui) == "function" then
            return gethui()
        end
        return nil
    end)
    if ok and hiddenGui then
        return hiddenGui
    end

    local playerGui
    pcall(function()
        playerGui = LocalPlayer:WaitForChild("PlayerGui", 8)
    end)
    if playerGui then
        return playerGui
    end
    return CoreGui
end

local GuiParent = getGuiParent()

--// Runtime state
local SCRIPT_NAME = "NugiXhubHD"
local GUI_NAME = "NugiXhub_HD_GUI"
local connections = {}
local activeTweens = {}
local ownedEffects = {}
local ownedAtmosphere = nil
local propertySnapshots = {}
local effectSnapshots = {}
local atmosphereSnapshots = {}
local gui = nil
local mainPanel = nil
local floatingButton = nil
local loadingFrame = nil
local terminalLabel = nil
local terminalScroll = nil
local terminalCursor = nil
local fpsLabel = nil
local currentPresetLabel = nil
local activePreset = "ORIGINAL"
local selectedPreset = "EXTREME ULTRA HD"
local currentPage = "HOME"
local panelVisible = true
local terminalAnimation = true
local uiAnimations = true
local uiIntensity = 1
local panelSizeMode = "NORMAL"
local accentColor = Color3.fromRGB(0, 214, 235)
local terminalQueue = {}
local terminalBusy = false
local terminalText = "[NugiXhub] Client UI initialized."
local fpsFrames = 0
local fpsElapsed = 0
local currentFPS = 0
local isOptimizationEnabled = false
local toggleSetters = {}
local accentTargets = {}
local optionGroups = {}
local cursorTween = nil
local navButtons = {}
local switchPage = nil
local clampFloatingButton = nil
local presetCards = {}
local statusLabel = nil
local configStatusLabel = nil

local COLORS = {
    Background = Color3.fromRGB(8, 11, 16),
    Panel = Color3.fromRGB(15, 21, 29),
    Card = Color3.fromRGB(20, 29, 39),
    CardAlt = Color3.fromRGB(17, 25, 34),
    Stroke = Color3.fromRGB(43, 58, 72),
    Text = Color3.fromRGB(238, 244, 249),
    Muted = Color3.fromRGB(133, 149, 164),
    Green = Color3.fromRGB(85, 220, 163),
    Red = Color3.fromRGB(255, 105, 118),
    White = Color3.fromRGB(255, 255, 255),
}

local function trackConnection(connection)
    if connection then
        table.insert(connections, connection)
    end
    return connection
end

local function disconnectAll()
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(connections)

    for _, tween in ipairs(activeTweens) do
        pcall(function()
            tween:Cancel()
        end)
    end
    table.clear(activeTweens)
end

local function safeDestroy(instance)
    if instance then
        pcall(function()
            instance:Destroy()
        end)
    end
end

local function safeSet(instance, property, value)
    if not instance then
        return false
    end
    local ok = pcall(function()
        instance[property] = value
    end)
    return ok
end

local function safeGet(instance, property)
    if not instance then
        return nil, false
    end
    local ok, value = pcall(function()
        return instance[property]
    end)
    return value, ok
end

local function create(className, properties, parent)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        pcall(function()
            object[property] = value
        end)
    end
    if parent then
        object.Parent = parent
    end
    return object
end

local function addCorner(parent, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, parent)
end

local function addStroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        Color = color or COLORS.Stroke,
        Transparency = transparency or 0,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function addPadding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 10),
        PaddingRight = UDim.new(0, right or 10),
        PaddingTop = UDim.new(0, top or 8),
        PaddingBottom = UDim.new(0, bottom or 8),
    }, parent)
end

local function playTween(object, duration, properties, style, direction, repeatCount, reverses)
    if not object or not object.Parent then
        return nil
    end
    if not uiAnimations then
        for property, value in pairs(properties) do
            safeSet(object, property, value)
        end
        return nil
    end

    local adjustedDuration = math.max(0.06, (duration or 0.2) * uiIntensity)
    local tweenInfo = TweenInfo.new(
        adjustedDuration,
        style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out,
        repeatCount or 0,
        reverses or false
    )
    local ok, tween = pcall(function()
        return TweenService:Create(object, tweenInfo, properties)
    end)
    if ok and tween then
        table.insert(activeTweens, tween)
        local completionConnection
        completionConnection = tween.Completed:Connect(function()
            for index = #activeTweens, 1, -1 do
                if activeTweens[index] == tween then
                    table.remove(activeTweens, index)
                    break
                end
            end
            if completionConnection then
                completionConnection:Disconnect()
            end
        end)
        tween:Play()
        return tween
    end
    return nil
end

local function registerAccent(object, property)
    if object then
        table.insert(accentTargets, { Object = object, Property = property })
        safeSet(object, property, accentColor)
    end
end

local function refreshAccent()
    for _, target in ipairs(accentTargets) do
        if target.Object and target.Object.Parent then
            safeSet(target.Object, target.Property, accentColor)
        end
    end
end

local function makeLabel(parent, text, size, color, font, xAlignment)
    return create("TextLabel", {
        BackgroundTransparency = 1,
        Text = text or "",
        TextColor3 = color or COLORS.Text,
        TextSize = size or 14,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = xAlignment or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
        RichText = false,
        BorderSizePixel = 0,
    }, parent)
end

local function makeButton(parent, text, size, background, textColor)
    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = background or COLORS.Card,
        BorderSizePixel = 0,
        Text = text or "BUTTON",
        TextColor3 = textColor or COLORS.Text,
        TextSize = 12,
        Font = Enum.Font.GothamSemibold,
        Size = size or UDim2.new(1, 0, 0, 38),
    }, parent)
    addCorner(button, 10)
    addStroke(button, COLORS.Stroke, 0.25, 1)
    trackConnection(button.MouseButton1Down:Connect(function()
        if button.Parent then
            playTween(button, 0.08, { BackgroundTransparency = 0.14 }, Enum.EasingStyle.Quad)
        end
    end))
    trackConnection(button.MouseButton1Up:Connect(function()
        if button.Parent then
            playTween(button, 0.12, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quad)
        end
    end))
    return button
end

local function makeCard(parent, height)
    local card = create("Frame", {
        BackgroundColor3 = COLORS.Card,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height or 80),
    }, parent)
    addCorner(card, 13)
    addStroke(card, COLORS.Stroke, 0.3, 1)
    return card
end

local function makePage(parent, pageName)
    local page = create("ScrollingFrame", {
        Name = pageName .. "Page",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = accentColor,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 1, 0),
        Visible = false,
    }, parent)
    addPadding(page, 12, 12, 12, 15)
    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page)
    return page
end

local function addSectionTitle(parent, title, subtitle)
    local wrap = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, subtitle and 50 or 28),
    }, parent)
    local titleLabel = makeLabel(wrap, title, 16, COLORS.Text, Enum.Font.GothamBold)
    titleLabel.Size = UDim2.new(1, 0, 0, 24)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    if subtitle then
        local sub = makeLabel(wrap, subtitle, 10, COLORS.Muted, Enum.Font.Gotham)
        sub.Size = UDim2.new(1, 0, 0, 20)
        sub.Position = UDim2.new(0, 0, 0, 25)
    end
    return wrap
end

--// Snapshot and graphics helpers
local LIGHTING_PROPERTIES = {
    "Brightness",
    "ExposureCompensation",
    "EnvironmentDiffuseScale",
    "EnvironmentSpecularScale",
    "GlobalShadows",
    "ShadowSoftness",
}

local EFFECT_CLASSES = {
    "BloomEffect",
    "SunRaysEffect",
    "ColorCorrectionEffect",
    "DepthOfFieldEffect",
}

local function captureInstanceProperty(instance, property, storage)
    if not instance then
        return
    end
    storage[instance] = storage[instance] or {}
    if storage[instance][property] == nil then
        local value, ok = safeGet(instance, property)
        if ok then
            storage[instance][property] = value
        end
    end
end

local function captureLightingDefaults()
    for _, property in ipairs(LIGHTING_PROPERTIES) do
        local value, ok = safeGet(Lighting, property)
        if ok then
            propertySnapshots[property] = value
        end
    end
end

local function captureEffect(effect)
    if not effect then
        return
    end
    captureInstanceProperty(effect, "Enabled", effectSnapshots)
end

local function listEffects(className)
    local found = {}
    local seen = {}
    local function inspect(container)
        if not container then
            return
        end
        local ok, descendants = pcall(function()
            return container:GetDescendants()
        end)
        if not ok or not descendants then
            return
        end
        for _, item in ipairs(descendants) do
            if item.ClassName == className and not seen[item] then
                seen[item] = true
                table.insert(found, item)
            end
        end
    end
    inspect(Lighting)
    inspect(Workspace.CurrentCamera)
    return found
end

local function getAtmospheres()
    local result = {}
    for _, child in ipairs(Lighting:GetChildren()) do
        if child:IsA("Atmosphere") then
            table.insert(result, child)
        end
    end
    return result
end

local function captureAtmosphere(atmosphere)
    if not atmosphere then
        return
    end
    captureInstanceProperty(atmosphere, "Density", atmosphereSnapshots)
    captureInstanceProperty(atmosphere, "Haze", atmosphereSnapshots)
    captureInstanceProperty(atmosphere, "Glare", atmosphereSnapshots)
    captureInstanceProperty(atmosphere, "Offset", atmosphereSnapshots)
    captureInstanceProperty(atmosphere, "Color", atmosphereSnapshots)
    captureInstanceProperty(atmosphere, "Decay", atmosphereSnapshots)
end

local function setLightingProperty(property, value)
    if propertySnapshots[property] == nil then
        local original, ok = safeGet(Lighting, property)
        if ok then
            propertySnapshots[property] = original
        end
    end
    return safeSet(Lighting, property, value)
end

local function createEffect(className)
    local effect
    local ok = pcall(function()
        effect = Instance.new(className)
        effect.Name = "NugiXhubHD_" .. className
        effect.Parent = Lighting
    end)
    if not ok or not effect then
        return nil
    end
    ownedEffects[effect] = true

    if className == "BloomEffect" then
        safeSet(effect, "Intensity", 0.22)
        safeSet(effect, "Size", 32)
        safeSet(effect, "Threshold", 1.05)
    elseif className == "SunRaysEffect" then
        safeSet(effect, "Intensity", 0.07)
        safeSet(effect, "Spread", 0.82)
    elseif className == "ColorCorrectionEffect" then
        safeSet(effect, "Brightness", 0.015)
        safeSet(effect, "Contrast", 0.07)
        safeSet(effect, "Saturation", 0.08)
        safeSet(effect, "TintColor", Color3.fromRGB(245, 250, 255))
    elseif className == "DepthOfFieldEffect" then
        safeSet(effect, "FarIntensity", 0.08)
        safeSet(effect, "NearIntensity", 0.04)
        safeSet(effect, "FocusDistance", 55)
        safeSet(effect, "InFocusRadius", 35)
    end

    return effect
end

local function setEffectEnabled(className, enabled)
    local effects = listEffects(className)
    if #effects == 0 and enabled then
        local created = createEffect(className)
        if created then
            captureEffect(created)
            safeSet(created, "Enabled", true)
            return true
        end
        return false
    end

    local success = true
    for _, effect in ipairs(effects) do
        captureEffect(effect)
        if not safeSet(effect, "Enabled", enabled) then
            success = false
        end
    end
    return success
end

local function setAtmosphereEnabled(enabled)
    local atmospheres = getAtmospheres()
    if #atmospheres == 0 and enabled then
        local atmosphere
        local ok = pcall(function()
            atmosphere = Instance.new("Atmosphere")
            atmosphere.Name = "NugiXhubHD_Atmosphere"
            atmosphere.Density = 0.22
            atmosphere.Haze = 0.8
            atmosphere.Glare = 0.12
            atmosphere.Parent = Lighting
        end)
        if ok and atmosphere then
            ownedAtmosphere = atmosphere
            captureAtmosphere(atmosphere)
            return true
        end
        return false
    end

    for _, atmosphere in ipairs(atmospheres) do
        captureAtmosphere(atmosphere)
        if enabled then
            local snapshot = atmosphereSnapshots[atmosphere] or {}
            if snapshot.Density ~= nil then safeSet(atmosphere, "Density", snapshot.Density) end
            if snapshot.Haze ~= nil then safeSet(atmosphere, "Haze", snapshot.Haze) end
            if snapshot.Glare ~= nil then safeSet(atmosphere, "Glare", snapshot.Glare) end
        else
            safeSet(atmosphere, "Density", 0)
            safeSet(atmosphere, "Haze", 0)
            safeSet(atmosphere, "Glare", 0)
        end
    end
    return true
end

local function isEffectEnabled(className)
    local effects = listEffects(className)
    for _, effect in ipairs(effects) do
        local enabled, ok = safeGet(effect, "Enabled")
        if ok and enabled then
            return true
        end
    end
    return false
end

local function isAtmosphereEnabled()
    local atmospheres = getAtmospheres()
    for _, atmosphere in ipairs(atmospheres) do
        local density = safeGet(atmosphere, "Density")
        local haze = safeGet(atmosphere, "Haze")
        local glare = safeGet(atmosphere, "Glare")
        if (tonumber(density) or 0) > 0 or (tonumber(haze) or 0) > 0 or (tonumber(glare) or 0) > 0 then
            return true
        end
    end
    return false
end

local function getToggleState(key)
    if key == "Bloom" then return isEffectEnabled("BloomEffect") end
    if key == "SunRays" then return isEffectEnabled("SunRaysEffect") end
    if key == "ColorCorrection" then return isEffectEnabled("ColorCorrectionEffect") end
    if key == "DepthOfField" then return isEffectEnabled("DepthOfFieldEffect") end
    if key == "Atmosphere" then return isAtmosphereEnabled() end
    if key == "GlobalShadows" then
        local value, ok = safeGet(Lighting, "GlobalShadows")
        return ok and value == true
    end
    if key == "VisualEffects" then
        return isEffectEnabled("BloomEffect") or isEffectEnabled("SunRaysEffect")
            or isEffectEnabled("ColorCorrectionEffect") or isEffectEnabled("DepthOfFieldEffect")
    end
    if key == "Optimization" then return isOptimizationEnabled end
    if key == "UIAnimations" then return uiAnimations end
    if key == "TerminalAnimation" then return terminalAnimation end
    return false
end

--// Preset definitions
local PRESETS = {
    ["EXTREME ULTRA HD"] = {
        Description = "Maximum client-side lighting and post-processing accents.",
        Lighting = {
            Brightness = 2.0,
            ExposureCompensation = 0.12,
            EnvironmentDiffuseScale = 1,
            EnvironmentSpecularScale = 1,
            GlobalShadows = true,
            ShadowSoftness = 0.45,
        },
        Effects = { BloomEffect = true, SunRaysEffect = true, ColorCorrectionEffect = true, DepthOfFieldEffect = false },
        Atmosphere = true,
    },
    ["ULTRA HD"] = {
        Description = "Rich lighting with controlled visual effects.",
        Lighting = {
            Brightness = 1.8,
            ExposureCompensation = 0.08,
            EnvironmentDiffuseScale = 0.9,
            EnvironmentSpecularScale = 0.82,
            GlobalShadows = true,
            ShadowSoftness = 0.55,
        },
        Effects = { BloomEffect = true, SunRaysEffect = true, ColorCorrectionEffect = true, DepthOfFieldEffect = false },
        Atmosphere = true,
    },
    ["HIGH HD"] = {
        Description = "Sharper lighting accents while keeping effects lighter.",
        Lighting = {
            Brightness = 1.6,
            ExposureCompensation = 0.03,
            EnvironmentDiffuseScale = 0.75,
            EnvironmentSpecularScale = 0.62,
            GlobalShadows = true,
            ShadowSoftness = 0.65,
        },
        Effects = { BloomEffect = true, SunRaysEffect = false, ColorCorrectionEffect = true, DepthOfFieldEffect = false },
        Atmosphere = true,
    },
    ["BALANCED"] = {
        Description = "Moderate lighting with fewer additional effects.",
        Lighting = {
            Brightness = 1.45,
            ExposureCompensation = 0,
            EnvironmentDiffuseScale = 0.55,
            EnvironmentSpecularScale = 0.38,
            GlobalShadows = true,
            ShadowSoftness = 0.7,
        },
        Effects = { BloomEffect = false, SunRaysEffect = false, ColorCorrectionEffect = false, DepthOfFieldEffect = false },
        Atmosphere = true,
    },
    ["LOW GRAPHICS"] = {
        Description = "Turns off extra effects and reduces lighting workload.",
        Lighting = {
            Brightness = 1.25,
            ExposureCompensation = 0,
            EnvironmentDiffuseScale = 0.25,
            EnvironmentSpecularScale = 0.12,
            GlobalShadows = false,
            ShadowSoftness = 0,
        },
        Effects = { BloomEffect = false, SunRaysEffect = false, ColorCorrectionEffect = false, DepthOfFieldEffect = false },
        Atmosphere = false,
    },
    ["POTATO / BURIK BANGET"] = {
        Description = "Minimum optional effects. Map geometry and textures remain unchanged.",
        Lighting = {
            Brightness = 1,
            ExposureCompensation = -0.05,
            EnvironmentDiffuseScale = 0.05,
            EnvironmentSpecularScale = 0.05,
            GlobalShadows = false,
            ShadowSoftness = 0,
        },
        Effects = { BloomEffect = false, SunRaysEffect = false, ColorCorrectionEffect = false, DepthOfFieldEffect = false },
        Atmosphere = false,
    },
}

local function updatePresetUI()
    if currentPresetLabel then
        currentPresetLabel.Text = "ACTIVE PROFILE  /  " .. activePreset
    end
    if configStatusLabel then
        configStatusLabel.Text = isOptimizationEnabled and "OPTIMIZATION ACTIVE" or "CONFIGURATION READY"
        configStatusLabel.TextColor3 = isOptimizationEnabled and COLORS.Green or COLORS.Muted
    end
    for name, cardData in pairs(presetCards) do
        if cardData and cardData.Button and cardData.Button.Parent then
            local isActive = name == activePreset
            cardData.Badge.Text = isActive and "ACTIVE" or "READY"
            cardData.Badge.TextColor3 = isActive and COLORS.Green or COLORS.Muted
            cardData.Stroke.Color = isActive and accentColor or COLORS.Stroke
            cardData.Button.Text = isActive and "ACTIVE PROFILE" or "APPLY PRESET"
            cardData.Button.BackgroundColor3 = isActive and accentColor or COLORS.CardAlt
            cardData.Button.TextColor3 = isActive and COLORS.Background or COLORS.Text
        end
    end
    for key, setter in pairs(toggleSetters) do
        if setter and key ~= "UIAnimations" and key ~= "TerminalAnimation" then
            pcall(setter, getToggleState(key))
        end
    end
end

local function applyPreset(presetName)
    local config = PRESETS[presetName]
    if not config then
        return false
    end

    isOptimizationEnabled = false
    for property, value in pairs(config.Lighting) do
        setLightingProperty(property, value)
    end
    for className, enabled in pairs(config.Effects) do
        setEffectEnabled(className, enabled)
    end
    setAtmosphereEnabled(config.Atmosphere)

    activePreset = presetName
    selectedPreset = presetName
    updatePresetUI()

    if presetName == "POTATO / BURIK BANGET" or presetName == "LOW GRAPHICS" then
        -- The preset reduces optional effects only; it does not delete map parts.
        task.defer(function()
            if Environment.NugiXhubHD_Log then
                Environment.NugiXhubHD_Log("Applied " .. presetName .. " profile.")
            end
        end)
    else
        task.defer(function()
            if Environment.NugiXhubHD_Log then
                Environment.NugiXhubHD_Log("Applied " .. presetName .. " profile.")
            end
        end)
    end
    return true
end

local function applyOptimization(enabled)
    isOptimizationEnabled = enabled
    if enabled then
        for _, className in ipairs(EFFECT_CLASSES) do
            setEffectEnabled(className, false)
        end
        setLightingProperty("GlobalShadows", false)
        setLightingProperty("EnvironmentDiffuseScale", 0.15)
        setLightingProperty("EnvironmentSpecularScale", 0.08)
    else
        local restorePreset = PRESETS[activePreset] and activePreset or "BALANCED"
        applyPreset(restorePreset)
        return
    end
    updatePresetUI()
    if Environment.NugiXhubHD_Log then
        Environment.NugiXhubHD_Log(enabled and "Graphics optimization enabled." or "Graphics optimization disabled.")
    end
end

local function resetGraphics()
    for property, value in pairs(propertySnapshots) do
        safeSet(Lighting, property, value)
    end

    for instance, properties in pairs(effectSnapshots) do
        if instance and instance.Parent then
            for property, value in pairs(properties) do
                safeSet(instance, property, value)
            end
        end
    end

    for instance, properties in pairs(atmosphereSnapshots) do
        if instance and instance.Parent then
            for property, value in pairs(properties) do
                safeSet(instance, property, value)
            end
        end
    end

    for effect in pairs(ownedEffects) do
        safeDestroy(effect)
    end
    table.clear(ownedEffects)

    if ownedAtmosphere then
        safeDestroy(ownedAtmosphere)
        ownedAtmosphere = nil
    end

    -- Reset snapshots are retained so another reset remains safe after more changes.
    activePreset = "ORIGINAL"
    selectedPreset = "EXTREME ULTRA HD"
    isOptimizationEnabled = false
    updatePresetUI()
    if Environment.NugiXhubHD_Log then
        Environment.NugiXhubHD_Log("Original graphics values restored.")
    end
end

--// Previous-run cleanup
if type(Environment.NugiXhubHD_Cleanup) == "function" then
    pcall(Environment.NugiXhubHD_Cleanup)
end

--// Capture initial settings before changing anything
captureLightingDefaults()
for _, className in ipairs(EFFECT_CLASSES) do
    for _, effect in ipairs(listEffects(className)) do
        captureEffect(effect)
    end
end
for _, atmosphere in ipairs(getAtmospheres()) do
    captureAtmosphere(atmosphere)
end

--// Screen GUI
local oldGui = nil
pcall(function()
    oldGui = GuiParent:FindFirstChild(GUI_NAME)
end)
if oldGui then
    safeDestroy(oldGui)
end

local screenGui = create("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 10000,
    ZIndexBehavior = Enum.ZIndexBehavior.Global,
}, GuiParent)
gui = screenGui

local root = create("Frame", {
    Name = "Root",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
}, screenGui)

--// Loading screen
loadingFrame = create("Frame", {
    Name = "LoadingOverlay",
    BackgroundColor3 = COLORS.Background,
    BorderSizePixel = 0,
    Size = UDim2.fromScale(1, 1),
    ZIndex = 100,
}, root)

local loadingPanel = create("Frame", {
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(0.82, 0, 0, 300),
    ZIndex = 101,
}, loadingFrame)
addCorner(loadingPanel, 18)
addStroke(loadingPanel, COLORS.Stroke, 0.12, 1)
create("UISizeConstraint", {
    MinSize = Vector2.new(270, 290),
    MaxSize = Vector2.new(430, 310),
}, loadingPanel)

local loadingLogo = create("Frame", {
    BackgroundColor3 = COLORS.Card,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 24),
    Size = UDim2.fromOffset(54, 54),
    ZIndex = 102,
}, loadingPanel)
addCorner(loadingLogo, 15)
local loadingLogoStroke = addStroke(loadingLogo, accentColor, 0.1, 1.5)
registerAccent(loadingLogoStroke, "Color")
local logoText = makeLabel(loadingLogo, "NX", 22, accentColor, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
logoText.Size = UDim2.fromScale(1, 1)
logoText.ZIndex = 103
registerAccent(logoText, "TextColor3")

local loadingTitle = makeLabel(loadingPanel, "NugiXhub - HD", 19, COLORS.Text, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
loadingTitle.Position = UDim2.new(0, 12, 0, 88)
loadingTitle.Size = UDim2.new(1, -24, 0, 27)
loadingTitle.ZIndex = 102
local loadingSubtitle = makeLabel(loadingPanel, "CLIENT GRAPHICS UTILITY", 9, COLORS.Muted, Enum.Font.Code, Enum.TextXAlignment.Center)
loadingSubtitle.Position = UDim2.new(0, 12, 0, 115)
loadingSubtitle.Size = UDim2.new(1, -24, 0, 18)
loadingSubtitle.ZIndex = 102

local blockHolder = create("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 26, 0, 148),
    Size = UDim2.new(1, -52, 0, 42),
    ZIndex = 102,
}, loadingPanel)
local blocks = {}
for row = 1, 2 do
    for column = 1, 10 do
        local block = create("Frame", {
            BackgroundColor3 = accentColor,
            BackgroundTransparency = 0.86,
            BorderSizePixel = 0,
            Position = UDim2.new((column - 1) / 10, 0, (row - 1) * 0.52, 0),
            Size = UDim2.new(0, 17, 0, 16),
            ZIndex = 103,
        }, blockHolder)
        addCorner(block, 4)
        table.insert(blocks, block)
    end
end

local statusText = makeLabel(loadingPanel, "Initializing NugiXhub...", 10, COLORS.Muted, Enum.Font.Code)
statusText.Position = UDim2.new(0, 24, 0, 202)
statusText.Size = UDim2.new(1, -48, 0, 20)
statusText.ZIndex = 102
local progressBack = create("Frame", {
    BackgroundColor3 = COLORS.CardAlt,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 24, 0, 235),
    Size = UDim2.new(1, -48, 0, 7),
    ZIndex = 102,
}, loadingPanel)
addCorner(progressBack, 5)
local progressFill = create("Frame", {
    BackgroundColor3 = accentColor,
    BorderSizePixel = 0,
    Size = UDim2.new(0, 0, 1, 0),
    ZIndex = 103,
}, progressBack)
addCorner(progressFill, 5)
registerAccent(progressFill, "BackgroundColor3")
local progressPercent = makeLabel(loadingPanel, "0%", 10, COLORS.Text, Enum.Font.Code, Enum.TextXAlignment.Right)
progressPercent.Position = UDim2.new(0, 24, 0, 248)
progressPercent.Size = UDim2.new(1, -48, 0, 18)
progressPercent.ZIndex = 102

--// Main panel shell
mainPanel = create("Frame", {
    Name = "MainPanel",
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.new(0.9, 0, 0.78, 0),
    Visible = false,
    ClipsDescendants = true,
    ZIndex = 5,
}, root)
addCorner(mainPanel, 18)
local mainStroke = addStroke(mainPanel, COLORS.Stroke, 0.12, 1)
create("UISizeConstraint", {
    MinSize = Vector2.new(290, 410),
    MaxSize = Vector2.new(540, 720),
}, mainPanel)

local header = create("Frame", {
    BackgroundColor3 = COLORS.CardAlt,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 66),
    ZIndex = 6,
}, mainPanel)
addCorner(header, 17)
local headerCover = create("Frame", {
    BackgroundColor3 = COLORS.CardAlt,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 1, -16),
    Size = UDim2.new(1, 0, 0, 16),
    ZIndex = 6,
}, header)

local logoSquare = create("Frame", {
    BackgroundColor3 = COLORS.Card,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 14, 0, 12),
    Size = UDim2.fromOffset(42, 42),
    ZIndex = 7,
}, header)
addCorner(logoSquare, 12)
local logoStroke = addStroke(logoSquare, accentColor, 0.15, 1.3)
registerAccent(logoStroke, "Color")
local headerLogo = makeLabel(logoSquare, "NX", 16, accentColor, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
headerLogo.Size = UDim2.fromScale(1, 1)
headerLogo.ZIndex = 8
registerAccent(headerLogo, "TextColor3")

local headerTitle = makeLabel(header, "NugiXhub - HD", 15, COLORS.Text, Enum.Font.GothamBold)
headerTitle.Position = UDim2.new(0, 66, 0, 10)
headerTitle.Size = UDim2.new(1, -160, 0, 22)
headerTitle.ZIndex = 7
local headerStatus = makeLabel(header, "● GRAPHICS SYSTEM READY", 8, COLORS.Green, Enum.Font.Code)
headerStatus.Position = UDim2.new(0, 66, 0, 34)
headerStatus.Size = UDim2.new(1, -160, 0, 17)
headerStatus.ZIndex = 7
statusLabel = headerStatus

local minimizeButton = makeButton(header, "—", UDim2.fromOffset(30, 30), COLORS.Card, COLORS.Text)
minimizeButton.Position = UDim2.new(1, -76, 0, 17)
minimizeButton.ZIndex = 8
minimizeButton.TextSize = 16
local closeButton = makeButton(header, "×", UDim2.fromOffset(30, 30), COLORS.Card, COLORS.Red)
closeButton.Position = UDim2.new(1, -40, 0, 17)
closeButton.ZIndex = 8
closeButton.TextSize = 19

local contentHolder = create("Frame", {
    Name = "ContentHolder",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, 66),
    Size = UDim2.new(1, 0, 1, -124),
    ZIndex = 6,
}, mainPanel)

local navBar = create("Frame", {
    BackgroundColor3 = COLORS.CardAlt,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 1, -58),
    Size = UDim2.new(1, 0, 0, 58),
    ZIndex = 7,
}, mainPanel)
local navTopLine = create("Frame", {
    BackgroundColor3 = COLORS.Stroke,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 1),
    ZIndex = 8,
}, navBar)

local pages = {
    HOME = makePage(contentHolder, "HOME"),
    GRAPHICS = makePage(contentHolder, "GRAPHICS"),
    SETTINGS = makePage(contentHolder, "SETTINGS"),
    ABOUT = makePage(contentHolder, "ABOUT"),
}

--// Floating open button
floatingButton = create("TextButton", {
    Name = "FloatingOpenButton",
    AutoButtonColor = false,
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -16, 0.65, 0),
    Size = UDim2.fromOffset(52, 52),
    Text = "NX",
    TextColor3 = accentColor,
    TextSize = 16,
    Font = Enum.Font.GothamBlack,
    Visible = false,
    ZIndex = 30,
}, root)
addCorner(floatingButton, 17)
local floatingStroke = addStroke(floatingButton, accentColor, 0.05, 1.5)
registerAccent(floatingStroke, "Color")
registerAccent(floatingButton, "TextColor3")

--// Logging function, assigned to environment for graphics functions
local function appendLog(message)
    if not terminalLabel or not terminalLabel.Parent then
        return
    end
    table.insert(terminalQueue, tostring(message))
    if terminalBusy then
        return
    end
    terminalBusy = true
    task.spawn(function()
        while #terminalQueue > 0 do
            local line = table.remove(terminalQueue, 1)
            if terminalAnimation then
                local output = terminalText .. "\n[NugiXhub] "
                terminalText = output
                terminalLabel.Text = terminalText
                for index = 1, #line do
                    if not terminalLabel or not terminalLabel.Parent then
                        break
                    end
                    terminalText = output .. string.sub(line, 1, index)
                    terminalLabel.Text = terminalText
                    if terminalScroll then
                        terminalScroll.CanvasPosition = Vector2.new(0, math.max(0, terminalScroll.AbsoluteCanvasSize.Y))
                    end
                    task.wait(0.006)
                end
                terminalText = output .. line
            else
                terminalText = terminalText .. "\n[NugiXhub] " .. line
            end
            if terminalLabel and terminalLabel.Parent then
                terminalLabel.Text = terminalText
            end
            if terminalScroll then
                terminalScroll.CanvasPosition = Vector2.new(0, math.max(0, terminalScroll.AbsoluteCanvasSize.Y))
            end
        end
        terminalBusy = false
    end)
end
Environment.NugiXhubHD_Log = appendLog

--// HOME page
local homePage = pages.HOME
local homeSectionTitle = addSectionTitle(homePage, "OVERVIEW", "Client-side graphics control center")
homeSectionTitle.LayoutOrder = 1

local profileCard = makeCard(homePage, 94)
profileCard.LayoutOrder = 2
local profileAccent = create("Frame", {
    BackgroundColor3 = accentColor,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 13),
    Size = UDim2.new(0, 3, 0, 68),
}, profileCard)
addCorner(profileAccent, 3)
registerAccent(profileAccent, "BackgroundColor3")
local profileTitle = makeLabel(profileCard, "CURRENT GRAPHICS PROFILE", 9, COLORS.Muted, Enum.Font.Code)
profileTitle.Position = UDim2.new(0, 15, 0, 12)
profileTitle.Size = UDim2.new(1, -28, 0, 17)
currentPresetLabel = makeLabel(profileCard, "ACTIVE PROFILE  /  ORIGINAL", 13, COLORS.Text, Enum.Font.GothamBold)
currentPresetLabel.Position = UDim2.new(0, 15, 0, 32)
currentPresetLabel.Size = UDim2.new(1, -28, 0, 23)
configStatusLabel = makeLabel(profileCard, "CONFIGURATION READY", 9, COLORS.Green, Enum.Font.Code)
configStatusLabel.Position = UDim2.new(0, 15, 0, 62)
configStatusLabel.Size = UDim2.new(1, -28, 0, 16)

local actionRow = create("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 42),
    LayoutOrder = 3,
}, homePage)
create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, actionRow)
local applyButton = makeButton(actionRow, "APPLY GRAPHICS", UDim2.new(0.58, -4, 1, 0), accentColor, COLORS.Background)
applyButton.LayoutOrder = 1
registerAccent(applyButton, "BackgroundColor3")
local resetButton = makeButton(actionRow, "RESET", UDim2.new(0.42, -4, 1, 0), COLORS.Card, COLORS.Text)
resetButton.LayoutOrder = 2

local metricsRow = create("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 62),
    LayoutOrder = 4,
}, homePage)
create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, metricsRow)
local fpsCard = makeCard(metricsRow, 62)
fpsCard.Size = UDim2.new(0.5, -4, 1, 0)
local fpsTitle = makeLabel(fpsCard, "CLIENT FPS", 8, COLORS.Muted, Enum.Font.Code)
fpsTitle.Position = UDim2.new(0, 11, 0, 7)
fpsTitle.Size = UDim2.new(1, -20, 0, 16)
fpsLabel = makeLabel(fpsCard, "--", 19, COLORS.Text, Enum.Font.GothamBold)
fpsLabel.Position = UDim2.new(0, 11, 0, 25)
fpsLabel.Size = UDim2.new(1, -20, 0, 26)
local environmentCard = makeCard(metricsRow, 62)
environmentCard.Size = UDim2.new(0.5, -4, 1, 0)
local envTitle = makeLabel(environmentCard, "CLIENT STATUS", 8, COLORS.Muted, Enum.Font.Code)
envTitle.Position = UDim2.new(0, 11, 0, 7)
envTitle.Size = UDim2.new(1, -20, 0, 16)
local envValue = makeLabel(environmentCard, "CONNECTED", 13, COLORS.Green, Enum.Font.GothamBold)
envValue.Position = UDim2.new(0, 11, 0, 25)
envValue.Size = UDim2.new(1, -20, 0, 26)

local terminalCard = makeCard(homePage, 162)
terminalCard.LayoutOrder = 5
local terminalHeader = makeLabel(terminalCard, "LIVE CONFIGURATION TERMINAL", 9, COLORS.Muted, Enum.Font.Code)
terminalHeader.Position = UDim2.new(0, 12, 0, 8)
terminalHeader.Size = UDim2.new(1, -24, 0, 17)
local terminalDot = create("Frame", {
    BackgroundColor3 = COLORS.Green,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -18, 0, 13),
    Size = UDim2.fromOffset(6, 6),
}, terminalCard)
addCorner(terminalDot, 5)
terminalScroll = create("ScrollingFrame", {
    BackgroundColor3 = Color3.fromRGB(5, 9, 13),
    BorderSizePixel = 0,
    Position = UDim2.new(0, 10, 0, 31),
    Size = UDim2.new(1, -20, 1, -41),
    ScrollBarThickness = 2,
    ScrollBarImageColor3 = accentColor,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, terminalCard)
addCorner(terminalScroll, 8)
addPadding(terminalScroll, 8, 8, 6, 6)
terminalLabel = makeLabel(terminalScroll, terminalText, 10, COLORS.Green, Enum.Font.Code)
terminalLabel.TextYAlignment = Enum.TextYAlignment.Top
terminalLabel.TextWrapped = true
terminalLabel.Size = UDim2.new(1, -16, 0, 20)
terminalLabel.AutomaticSize = Enum.AutomaticSize.Y
terminalCursor = makeLabel(terminalCard, "▌", 10, accentColor, Enum.Font.Code)
terminalCursor.Position = UDim2.new(0, 12, 1, -18)
terminalCursor.Size = UDim2.fromOffset(12, 14)
registerAccent(terminalCursor, "TextColor3")

local function updateCursorBlink()
    if cursorTween then
        pcall(function() cursorTween:Cancel() end)
        cursorTween = nil
    end
    if terminalCursor and terminalCursor.Parent then
        safeSet(terminalCursor, "TextTransparency", 0)
        if terminalAnimation and uiAnimations then
            local ok, tween = pcall(function()
                return TweenService:Create(terminalCursor, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                    TextTransparency = 1,
                })
            end)
            if ok and tween then
                cursorTween = tween
                table.insert(activeTweens, tween)
                tween:Play()
            end
        end
    end
end

local quickHint = makeLabel(homePage, "TIP  /  Choose a profile in Graphics, then apply it to the current client view.", 9, COLORS.Muted, Enum.Font.Gotham)
quickHint.Size = UDim2.new(1, 0, 0, 32)
quickHint.LayoutOrder = 6

--// GRAPHICS page
local graphicsPage = pages.GRAPHICS
local graphicsSectionTitle = addSectionTitle(graphicsPage, "GRAPHICS PRESETS", "Choose a client-side lighting profile")
graphicsSectionTitle.LayoutOrder = 1

local presetDescriptions = {
    ["EXTREME ULTRA HD"] = "Maximum lighting accents • Bloom • SunRays",
    ["ULTRA HD"] = "High visual effects • rich lighting",
    ["HIGH HD"] = "High quality • balanced effect load",
    ["BALANCED"] = "Everyday look • moderate rendering effects",
    ["LOW GRAPHICS"] = "Fewer effects • lower lighting workload",
    ["POTATO / BURIK BANGET"] = "Minimum optional effects • simplest lighting",
}

local presetOrder = {
    "EXTREME ULTRA HD",
    "ULTRA HD",
    "HIGH HD",
    "BALANCED",
    "LOW GRAPHICS",
    "POTATO / BURIK BANGET",
}

for index, presetName in ipairs(presetOrder) do
    local card = makeCard(graphicsPage, 84)
    card.LayoutOrder = index + 1
    local indexLabel = makeLabel(card, string.format("%02d", index), 10, accentColor, Enum.Font.Code, Enum.TextXAlignment.Center)
    indexLabel.Position = UDim2.new(0, 9, 0, 12)
    indexLabel.Size = UDim2.fromOffset(28, 22)
    registerAccent(indexLabel, "TextColor3")
    local nameLabel = makeLabel(card, presetName, 11, COLORS.Text, Enum.Font.GothamBold)
    nameLabel.Position = UDim2.new(0, 43, 0, 10)
    nameLabel.Size = UDim2.new(1, -138, 0, 21)
    local descriptionLabel = makeLabel(card, presetDescriptions[presetName], 8, COLORS.Muted, Enum.Font.Gotham)
    descriptionLabel.Position = UDim2.new(0, 43, 0, 33)
    descriptionLabel.Size = UDim2.new(1, -138, 0, 26)
    local badge = makeLabel(card, "READY", 8, COLORS.Muted, Enum.Font.Code, Enum.TextXAlignment.Right)
    badge.Position = UDim2.new(1, -76, 0, 11)
    badge.Size = UDim2.fromOffset(64, 15)
    local useButton = makeButton(card, "APPLY PRESET", UDim2.fromOffset(112, 27), COLORS.CardAlt, COLORS.Text)
    useButton.Position = UDim2.new(1, -122, 0, 43)
    useButton.TextSize = 8
    local cardStroke = card:FindFirstChildOfClass("UIStroke")
    presetCards[presetName] = { Button = useButton, Badge = badge, Stroke = cardStroke }
    trackConnection(useButton.MouseButton1Click:Connect(function()
        applyPreset(presetName)
    end))
end

local customSectionTitle = addSectionTitle(graphicsPage, "CUSTOM GRAPHICS", "Switch individual effects on or off")
customSectionTitle.LayoutOrder = 8

local function makeToggleRow(parent, title, description, key, initial)
    local row = makeCard(parent, 58)
    local titleLabel = makeLabel(row, title, 10, COLORS.Text, Enum.Font.GothamSemibold)
    titleLabel.Position = UDim2.new(0, 12, 0, 8)
    titleLabel.Size = UDim2.new(1, -82, 0, 18)
    local descriptionLabel = makeLabel(row, description, 8, COLORS.Muted, Enum.Font.Gotham)
    descriptionLabel.Position = UDim2.new(0, 12, 0, 29)
    descriptionLabel.Size = UDim2.new(1, -82, 0, 18)
    local toggle = create("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = COLORS.CardAlt,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -60, 0.5, -13),
        Size = UDim2.fromOffset(48, 26),
        Text = "",
    }, row)
    addCorner(toggle, 13)
    local toggleStroke = addStroke(toggle, COLORS.Stroke, 0.25, 1)
    local knob = create("Frame", {
        BackgroundColor3 = COLORS.Muted,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 3, 0.5, -9),
        Size = UDim2.fromOffset(18, 18),
    }, toggle)
    addCorner(knob, 10)

    local value = initial == true
    local function setValue(nextValue)
        value = nextValue == true
        if value then
            playTween(toggle, 0.16, { BackgroundColor3 = accentColor }, Enum.EasingStyle.Quint)
            playTween(knob, 0.16, { Position = UDim2.new(1, -21, 0.5, -9), BackgroundColor3 = COLORS.White }, Enum.EasingStyle.Quint)
            safeSet(toggleStroke, "Color", accentColor)
        else
            playTween(toggle, 0.16, { BackgroundColor3 = COLORS.CardAlt }, Enum.EasingStyle.Quint)
            playTween(knob, 0.16, { Position = UDim2.new(0, 3, 0.5, -9), BackgroundColor3 = COLORS.Muted }, Enum.EasingStyle.Quint)
            safeSet(toggleStroke, "Color", COLORS.Stroke)
        end
    end
    setValue(value)
    toggleSetters[key] = setValue
    trackConnection(toggle.MouseButton1Click:Connect(function()
        local nextValue = not value
        setValue(nextValue)
        if key == "Bloom" then
            setEffectEnabled("BloomEffect", nextValue)
        elseif key == "SunRays" then
            setEffectEnabled("SunRaysEffect", nextValue)
        elseif key == "ColorCorrection" then
            setEffectEnabled("ColorCorrectionEffect", nextValue)
        elseif key == "DepthOfField" then
            setEffectEnabled("DepthOfFieldEffect", nextValue)
        elseif key == "Atmosphere" then
            setAtmosphereEnabled(nextValue)
        elseif key == "GlobalShadows" then
            setLightingProperty("GlobalShadows", nextValue)
        elseif key == "VisualEffects" then
            for _, className in ipairs(EFFECT_CLASSES) do
                setEffectEnabled(className, nextValue)
            end
        elseif key == "Optimization" then
            applyOptimization(nextValue)
        elseif key == "UIAnimations" then
            uiAnimations = nextValue
            updateCursorBlink()
        elseif key == "TerminalAnimation" then
            terminalAnimation = nextValue
            updateCursorBlink()
        end
        if Environment.NugiXhubHD_Log then
            Environment.NugiXhubHD_Log(title .. (nextValue and " enabled." or " disabled."))
        end
        updatePresetUI()
    end))
    return row
end

local customRows = {
    makeToggleRow(graphicsPage, "Bloom Effect", "Soft highlight glow", "Bloom", false),
    makeToggleRow(graphicsPage, "SunRays Effect", "Sunlight rays through the scene", "SunRays", false),
    makeToggleRow(graphicsPage, "Color Correction", "Color tone and contrast effect", "ColorCorrection", false),
    makeToggleRow(graphicsPage, "Depth Of Field", "Camera focus blur effect", "DepthOfField", false),
    makeToggleRow(graphicsPage, "Atmosphere", "Adjust atmospheric density and haze", "Atmosphere", false),
    makeToggleRow(graphicsPage, "Global Shadows", "Enable or disable global shadows", "GlobalShadows", true),
    makeToggleRow(graphicsPage, "Visual Effects", "Master switch for four post-processing effects", "VisualEffects", false),
    makeToggleRow(graphicsPage, "Graphics Optimization", "Disable optional effects and reduce lighting workload", "Optimization", false),
}
for index, row in ipairs(customRows) do
    row.LayoutOrder = 8 + index
end

local graphicsNote = makeLabel(graphicsPage, "LIMITATION  /  Roblox client scripts cannot force the engine quality slider or raise map texture and mesh detail. Potato mode only changes supported lighting and effects.", 9, COLORS.Muted, Enum.Font.Gotham)
graphicsNote.Size = UDim2.new(1, 0, 0, 48)
graphicsNote.LayoutOrder = 17

--// SETTINGS page
local settingsPage = pages.SETTINGS
local settingsSectionTitle = addSectionTitle(settingsPage, "SETTINGS", "Customize panel behavior")
settingsSectionTitle.LayoutOrder = 1

local function makeOptionRow(parent, title, description, buttonTexts, currentText, callback)
    local row = makeCard(parent, 78)
    local titleLabel = makeLabel(row, title, 10, COLORS.Text, Enum.Font.GothamSemibold)
    titleLabel.Position = UDim2.new(0, 12, 0, 7)
    titleLabel.Size = UDim2.new(1, -24, 0, 17)
    local descLabel = makeLabel(row, description, 8, COLORS.Muted, Enum.Font.Gotham)
    descLabel.Position = UDim2.new(0, 12, 0, 25)
    descLabel.Size = UDim2.new(1, -24, 0, 15)
    local optionsHolder = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 10, 0, 46),
        Size = UDim2.new(1, -20, 0, 25),
    }, row)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, optionsHolder)
    local optionButtons = {}
    local optionGroup = { Buttons = optionButtons, Current = currentText }
    optionGroups[title] = optionGroup
    for index, optionText in ipairs(buttonTexts) do
        local optionButton = makeButton(optionsHolder, optionText, UDim2.new(1 / #buttonTexts, -6, 1, 0), COLORS.CardAlt, COLORS.Text)
        optionButton.TextSize = 8
        optionButton.LayoutOrder = index
        optionButtons[optionText] = optionButton
        trackConnection(optionButton.MouseButton1Click:Connect(function()
            callback(optionText)
            optionGroup.Current = optionText
            for name, button in pairs(optionButtons) do
                local chosen = name == optionText
                button.BackgroundColor3 = chosen and accentColor or COLORS.CardAlt
                button.TextColor3 = chosen and COLORS.Background or COLORS.Text
            end
        end))
        if optionText == currentText then
            optionButton.BackgroundColor3 = accentColor
            optionButton.TextColor3 = COLORS.Background
        end
    end
    return row, optionButtons
end

local function setOptionGroup(title, choice)
    local group = optionGroups[title]
    if not group then return end
    group.Current = choice
    for name, button in pairs(group.Buttons) do
        local selected = name == choice
        button.BackgroundColor3 = selected and accentColor or COLORS.CardAlt
        button.TextColor3 = selected and COLORS.Background or COLORS.Text
    end
end

local animationToggleRow = makeToggleRow(settingsPage, "UI Animations", "Enable or disable panel transitions", "UIAnimations", true)
animationToggleRow.LayoutOrder = 2

local intensityRow = makeOptionRow(settingsPage, "ANIMATION INTENSITY", "Controls the speed of panel transitions", { "SOFT", "NORMAL", "STRONG" }, "NORMAL", function(choice)
    if choice == "SOFT" then uiIntensity = 1.35
    elseif choice == "STRONG" then uiIntensity = 0.68
    else uiIntensity = 1 end
    if Environment.NugiXhubHD_Log then
        Environment.NugiXhubHD_Log("UI animation intensity set to " .. choice .. ".")
    end
end)
intensityRow.LayoutOrder = 3

local accentRow, accentButtons = makeOptionRow(settingsPage, "ACCENT COLOR", "Choose the panel highlight color", { "CYAN", "BLUE", "VIOLET", "LIME" }, "CYAN", function(choice)
    local palette = {
        CYAN = Color3.fromRGB(0, 214, 235),
        BLUE = Color3.fromRGB(65, 137, 255),
        VIOLET = Color3.fromRGB(161, 110, 255),
        LIME = Color3.fromRGB(106, 224, 145),
    }
    accentColor = palette[choice] or palette.CYAN
    refreshAccent()
    for _, page in pairs(pages) do
        safeSet(page, "ScrollBarImageColor3", accentColor)
    end
    updatePresetUI()
    switchPage(currentPage)
    if Environment.NugiXhubHD_Log then
        Environment.NugiXhubHD_Log("Accent color changed to " .. choice .. ".")
    end
end)
accentRow.LayoutOrder = 4

local panelSizeRow, panelSizeButtons = makeOptionRow(settingsPage, "PANEL SIZE", "Adjust the panel footprint on your screen", { "COMPACT", "NORMAL", "LARGE" }, "NORMAL", function(choice)
    panelSizeMode = choice
    local sizes = {
        COMPACT = UDim2.new(0.82, 0, 0.68, 0),
        NORMAL = UDim2.new(0.9, 0, 0.78, 0),
        LARGE = UDim2.new(0.95, 0, 0.86, 0),
    }
    playTween(mainPanel, 0.22, { Size = sizes[choice] or sizes.NORMAL }, Enum.EasingStyle.Quint)
    if Environment.NugiXhubHD_Log then
        Environment.NugiXhubHD_Log("Panel size set to " .. choice .. ".")
    end
end)
panelSizeRow.LayoutOrder = 5

local terminalToggleRow = makeToggleRow(settingsPage, "Terminal Animation", "Type terminal messages character by character", "TerminalAnimation", true)
terminalToggleRow.LayoutOrder = 6

local restoreDefaultsButton = makeButton(settingsPage, "RESTORE DEFAULT SETTINGS", UDim2.new(1, 0, 0, 38), COLORS.CardAlt, COLORS.Text)
restoreDefaultsButton.LayoutOrder = 7
local resetGraphicsSettingsButton = makeButton(settingsPage, "RESET GRAPHICS", UDim2.new(1, 0, 0, 38), COLORS.CardAlt, COLORS.Text)
resetGraphicsSettingsButton.LayoutOrder = 8

--// ABOUT page
local aboutPage = pages.ABOUT
local aboutSectionTitle = addSectionTitle(aboutPage, "ABOUT NUGIXHUB", "Client graphics utility")
aboutSectionTitle.LayoutOrder = 1
local aboutCard = makeCard(aboutPage, 192)
aboutCard.LayoutOrder = 2
local aboutMark = makeLabel(aboutCard, "NX", 38, accentColor, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
aboutMark.Position = UDim2.new(0, 0, 0, 12)
aboutMark.Size = UDim2.new(1, 0, 0, 48)
registerAccent(aboutMark, "TextColor3")
local aboutName = makeLabel(aboutCard, "NugiXhub - HD", 17, COLORS.Text, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
aboutName.Position = UDim2.new(0, 10, 0, 62)
aboutName.Size = UDim2.new(1, -20, 0, 25)
local aboutType = makeLabel(aboutCard, "Roblox Client Graphics Enhancer", 10, COLORS.Muted, Enum.Font.Gotham, Enum.TextXAlignment.Center)
aboutType.Position = UDim2.new(0, 10, 0, 90)
aboutType.Size = UDim2.new(1, -20, 0, 19)
local aboutVersion = makeLabel(aboutCard, "VERSION  1.0   •   DEVELOPER  NugiXhub", 9, COLORS.Muted, Enum.Font.Code, Enum.TextXAlignment.Center)
aboutVersion.Position = UDim2.new(0, 10, 0, 119)
aboutVersion.Size = UDim2.new(1, -20, 0, 18)
local aboutTagline = makeLabel(aboutCard, "Your Map. Your Quality. Your Experience.", 10, accentColor, Enum.Font.GothamSemibold, Enum.TextXAlignment.Center)
aboutTagline.Position = UDim2.new(0, 10, 0, 151)
aboutTagline.Size = UDim2.new(1, -20, 0, 20)
registerAccent(aboutTagline, "TextColor3")

local aboutDisclaimer = makeLabel(aboutPage, "This is a client-side visual utility. Results depend on the game, Lighting setup, Roblox client, and device. It does not alter server data, map geometry, textures, or the Roblox graphics-quality setting.", 9, COLORS.Muted, Enum.Font.Gotham)
aboutDisclaimer.Size = UDim2.new(1, 0, 0, 58)
aboutDisclaimer.LayoutOrder = 3

--// Bottom navigation
local navData = {
    { Name = "HOME", Icon = "⌂" },
    { Name = "GRAPHICS", Icon = "◈" },
    { Name = "SETTINGS", Icon = "⚙" },
    { Name = "ABOUT", Icon = "i" },
}
for index, data in ipairs(navData) do
    local button = create("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new((index - 1) / 4, 0, 0, 3),
        Size = UDim2.new(0.25, 0, 1, -5),
        Text = "",
        ZIndex = 9,
    }, navBar)
    local icon = makeLabel(button, data.Icon, 17, COLORS.Muted, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    icon.Position = UDim2.new(0, 0, 0, 5)
    icon.Size = UDim2.new(1, 0, 0, 22)
    icon.ZIndex = 10
    local name = makeLabel(button, data.Name, 8, COLORS.Muted, Enum.Font.GothamSemibold, Enum.TextXAlignment.Center)
    name.Position = UDim2.new(0, 0, 0, 29)
    name.Size = UDim2.new(1, 0, 0, 15)
    name.ZIndex = 10
    navButtons[data.Name] = { Button = button, Icon = icon, Label = name }
    trackConnection(button.MouseButton1Click:Connect(function()
        switchPage(data.Name)
    end))
end

switchPage = function(pageName)
    if not pages[pageName] then
        return
    end
    currentPage = pageName
    for name, page in pairs(pages) do
        page.Visible = name == pageName
        if name == pageName then
            page.CanvasPosition = Vector2.new(0, 0)
        end
    end
    for name, data in pairs(navButtons) do
        local selected = name == pageName
        data.Icon.TextColor3 = selected and accentColor or COLORS.Muted
        data.Label.TextColor3 = selected and COLORS.Text or COLORS.Muted
    end
    local page = pages[pageName]
    if page then
        page.Position = UDim2.new(0, 0, 0, 5)
        playTween(page, 0.16, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
    end
end

--// Settings toggle behavior is handled directly by each toggle row.

--// Connect action buttons
trackConnection(applyButton.MouseButton1Click:Connect(function()
    if PRESETS[selectedPreset] then
        applyPreset(selectedPreset)
    else
        applyPreset("BALANCED")
    end
end))
trackConnection(resetButton.MouseButton1Click:Connect(resetGraphics))
trackConnection(resetGraphicsSettingsButton.MouseButton1Click:Connect(resetGraphics))

trackConnection(restoreDefaultsButton.MouseButton1Click:Connect(function()
    uiAnimations = true
    terminalAnimation = true
    uiIntensity = 1
    panelSizeMode = "NORMAL"
    accentColor = Color3.fromRGB(0, 214, 235)
    refreshAccent()
    playTween(mainPanel, 0.2, { Size = UDim2.new(0.9, 0, 0.78, 0) }, Enum.EasingStyle.Quint)
    for _, page in pairs(pages) do
        safeSet(page, "ScrollBarImageColor3", accentColor)
    end
    for key, setter in pairs(toggleSetters) do
        if key == "UIAnimations" or key == "TerminalAnimation" then
            pcall(setter, true)
        end
    end
    setOptionGroup("ANIMATION INTENSITY", "NORMAL")
    setOptionGroup("ACCENT COLOR", "CYAN")
    setOptionGroup("PANEL SIZE", "NORMAL")
    updateCursorBlink()
    if Environment.NugiXhubHD_Log then
        Environment.NugiXhubHD_Log("Panel settings restored to defaults.")
    end
end))

trackConnection(minimizeButton.MouseButton1Click:Connect(function()
    panelVisible = false
    playTween(mainPanel, 0.16, { BackgroundTransparency = 1, Size = UDim2.new(0.82, 0, 0.7, 0) }, Enum.EasingStyle.Quint)
    task.delay(uiAnimations and 0.17 * uiIntensity or 0, function()
        if mainPanel and mainPanel.Parent and not panelVisible then
            mainPanel.Visible = false
            mainPanel.BackgroundTransparency = 0
            floatingButton.Visible = true
            playTween(floatingButton, 0.18, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quint)
        end
    end)
end))

trackConnection(closeButton.MouseButton1Click:Connect(function()
    panelVisible = false
    playTween(mainPanel, 0.16, { BackgroundTransparency = 1, Size = UDim2.new(0.82, 0, 0.7, 0) }, Enum.EasingStyle.Quint)
    task.delay(uiAnimations and 0.17 * uiIntensity or 0, function()
        if mainPanel and mainPanel.Parent and not panelVisible then
            mainPanel.Visible = false
            mainPanel.BackgroundTransparency = 0
            floatingButton.Visible = true
            playTween(floatingButton, 0.18, { BackgroundTransparency = 0 }, Enum.EasingStyle.Quint)
        end
    end)
end))

local floatingWasDragged = false
local function openPanel()
    panelVisible = true
    floatingButton.Visible = false
    mainPanel.Visible = true
    mainPanel.BackgroundTransparency = 1
    mainPanel.Size = UDim2.new(0.82, 0, 0.7, 0)
    playTween(mainPanel, 0.22, {
        BackgroundTransparency = 0,
        Size = panelSizeMode == "COMPACT" and UDim2.new(0.82, 0, 0.68, 0)
            or panelSizeMode == "LARGE" and UDim2.new(0.95, 0, 0.86, 0)
            or UDim2.new(0.9, 0, 0.78, 0),
    }, Enum.EasingStyle.Back)
end
trackConnection(floatingButton.MouseButton1Click:Connect(function()
    if floatingWasDragged then
        floatingWasDragged = false
        return
    end
    openPanel()
end))

--// Floating button drag support (mouse + touch)
do
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPosition = nil

    trackConnection(floatingButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = floatingButton.Position
            if input.UserInputType == Enum.UserInputType.Touch then
                dragInput = input
            end
        end
    end))

    trackConnection(floatingButton.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    trackConnection(UserInputService.InputChanged:Connect(function(input)
        if dragging and dragStart and startPosition and (input == dragInput or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 12 then
                floatingWasDragged = true
            end
            floatingButton.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end))

    trackConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            dragStart = nil
            startPosition = nil
            if floatingWasDragged then
                task.delay(0.25, function()
                    floatingWasDragged = false
                end)
            end
            if clampFloatingButton then
                task.defer(clampFloatingButton)
            end
        end
    end))
end

--// Device viewport safety: keep floating control within visible viewport
clampFloatingButton = function()
    if not floatingButton or not floatingButton.Parent then return end
    local camera = Workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local absolute = floatingButton.AbsolutePosition
    local size = floatingButton.AbsoluteSize
    local x = math.clamp(absolute.X, 4, math.max(4, viewport.X - size.X - 4))
    local y = math.clamp(absolute.Y, 60, math.max(60, viewport.Y - size.Y - 4))
    floatingButton.Position = UDim2.fromOffset(x + size.X, y + size.Y / 2)
end

--// FPS display: measured from rendered frames while the panel is visible
trackConnection(RunService.RenderStepped:Connect(function(deltaTime)
    if not panelVisible then
        return
    end
    fpsFrames += 1
    fpsElapsed += deltaTime
    if fpsElapsed >= 1 then
        currentFPS = math.floor(fpsFrames / math.max(fpsElapsed, 0.001) + 0.5)
        fpsFrames = 0
        fpsElapsed = 0
        if fpsLabel and fpsLabel.Parent then
            fpsLabel.Text = tostring(currentFPS)
        end
    end
end))

trackConnection(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    local camera = Workspace.CurrentCamera
    if camera then
        for _, className in ipairs(EFFECT_CLASSES) do
            for _, effect in ipairs(listEffects(className)) do
                captureEffect(effect)
            end
        end
    end
    task.defer(clampFloatingButton)
end))

--// Responsive refresh when viewport changes
local function bindViewport()
    local camera = Workspace.CurrentCamera
    if camera then
        trackConnection(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            task.defer(clampFloatingButton)
        end))
    end
end
bindViewport()

--// Startup log and status
switchPage("HOME")
appendLog("Initializing client UI...")
appendLog("Lighting service found.")
appendLog("Original lighting values captured.")
appendLog("Post-processing effect states captured.")
appendLog("Six graphics profiles loaded.")
appendLog("Configuration panel ready.")

--// Loading animation
local function runLoading()
    local statusStages = {
        { At = 0, Text = "Initializing NugiXhub..." },
        { At = 16, Text = "Preparing Lighting controls..." },
        { At = 33, Text = "Preparing HD Presets..." },
        { At = 50, Text = "Preparing responsive layout..." },
        { At = 68, Text = "Building Interface..." },
        { At = 84, Text = "Finalizing Configuration..." },
        { At = 96, Text = "NugiXhub Ready!" },
    }
    for index, block in ipairs(blocks) do
        local delayTime = (index - 1) * 0.025
        task.delay(delayTime, function()
            if block and block.Parent then
                playTween(block, 0.18, { BackgroundTransparency = 0.18 }, Enum.EasingStyle.Back)
                playTween(block, 0.22, { Size = UDim2.new(0, 17, 0, 24) }, Enum.EasingStyle.Back)
            end
        end)
    end

    for progress = 0, 100, 2 do
        if not loadingFrame or not loadingFrame.Parent then
            break
        end
        local stageText = statusStages[1].Text
        for _, stage in ipairs(statusStages) do
            if progress >= stage.At then
                stageText = stage.Text
            end
        end
        statusText.Text = stageText
        progressPercent.Text = tostring(progress) .. "%"
        playTween(progressFill, 0.05, { Size = UDim2.new(progress / 100, 0, 1, 0) }, Enum.EasingStyle.Linear)
        if progress % 10 == 0 then
            local blockIndex = math.clamp(math.floor(progress / 100 * #blocks) + 1, 1, #blocks)
            local block = blocks[blockIndex]
            if block then
                playTween(block, 0.12, { BackgroundTransparency = 0.02 }, Enum.EasingStyle.Quad)
            end
        end
        task.wait(0.018)
    end

    task.wait(0.12)
    if mainPanel and mainPanel.Parent then
        mainPanel.Visible = true
        mainPanel.Size = UDim2.new(0.84, 0, 0.72, 0)
        mainPanel.BackgroundTransparency = 1
        playTween(mainPanel, 0.24, { Size = UDim2.new(0.9, 0, 0.78, 0), BackgroundTransparency = 0 }, Enum.EasingStyle.Back)
    end
    playTween(loadingFrame, 0.22, { BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
    for _, descendant in ipairs(loadingFrame:GetDescendants()) do
        if descendant:IsA("GuiObject") then
            playTween(descendant, 0.18, { BackgroundTransparency = 1, TextTransparency = 1 }, Enum.EasingStyle.Quad)
        end
    end
    task.wait(0.25)
    safeDestroy(loadingFrame)
    loadingFrame = nil
end

--// Cleanup exposed for safe reruns
local cleaned = false
local function cleanup()
    if cleaned then return end
    cleaned = true
    pcall(resetGraphics)
    disconnectAll()
    safeDestroy(gui)
    gui = nil
    if Environment.NugiXhubHD_Log == appendLog then
        Environment.NugiXhubHD_Log = nil
    end
    if Environment.NugiXhubHD_Cleanup == cleanup then
        Environment.NugiXhubHD_Cleanup = nil
    end
end
Environment.NugiXhubHD_Cleanup = cleanup

--// Final state sync
updatePresetUI()
for key, setter in pairs(toggleSetters) do
    if key == "UIAnimations" then
        pcall(setter, uiAnimations)
    elseif key == "TerminalAnimation" then
        pcall(setter, terminalAnimation)
    else
        pcall(setter, getToggleState(key))
    end
end
updateCursorBlink()

-- The floating control distinguishes a tap from a drag in its input handler.

task.spawn(runLoading)
