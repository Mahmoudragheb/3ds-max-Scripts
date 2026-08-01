-- =====================================================================================
--  NEOCAPTURE TOOL ULTIMATE  (v2 - tabbed UI)
--  V-Ray / Corona capture, render and pipeline assistant for 3ds Max
--
--  File structure:
--    [1] Globals and session cleanup
--    [2] Render-elements live helpers + V-Ray PRO settings panels (tabbed)
--    [3] Action / Vantage / converter helpers (verified against this machine)
--    [4] Corona PRO settings panels (tabbed)
--    [5] Render element parameter rollouts
--    [6] NeoCapture extensions: log, presets, scene check, contact sheet,
--        resolution slots, light lister, script manager, tools
--    [6c] Machine profile (written to NeoCaptureProfile.ini), splash screen, self-update
--    [6b] Shared state for the tabbed UI
--    [7] Main UI: cameras, engine boxes (V-Ray blue / Corona orange)
--    [8] Capture and output panel (batch render, versioning, backup)
--    [9] Launcher and engine-sync callbacks
-- =====================================================================================

-- ============================ [1] GLOBALS AND SESSION CLEANUP ============================
-- IMPORTANT: a rollout treats any name it does not yet know as a rollout-LOCAL variable.
-- Every global used inside a rollout must therefore be declared before that rollout is
-- defined, which is what this forward-declaration block is for.
global neoScriptVersion, neoRepoBase, neoScriptPath
global neoProfileFile, neoProfile, neoMaxYear, neoProfAdd
global neoProbeMax, neoProbeHardware, neoProbeRenderers, neoProbePlugins, neoProbeScripts
global neoWriteProfile, neoCheckRepo, neoApplyUpdate, neoStartup, neoSplashStep, rltNeoSplash
global neoTargetEngine, neoProPanel, neoElemPanel, neoSelCamNames
global neoIsVRayRnd, neoIsCoronaRnd, neoSyncProUI, neoSyncElements, neoSetTargetEngine
global neoCurrentTab, neoShowTab, rltEngines, rltNeoTabBar
global neoLog, neoLogFile, neoActiveEngineName, neoSafeFileName, neoSafeDirName
global neoStartDownload, neoDirectDownloadURL, neoInstallerDir, neoIsAdmin
global neoDL_VRayURL, neoDL_CoronaURL, neoDL_VantageURL
global neoScriptManifest, neoBuiltInScripts, neoFetchScriptManifest, neoInstallScript
global neoCapturePresetsFile, neoListPresets, neoSavePreset, neoApplyPreset, neoDeletePreset
global neoResSlots, neoResEditIdx, neoLoadResSlots, neoSaveResSlot, rltNeoResEdit
global neoRunSceneCheck, neoExportProxy, neoPreviewCamera, neoCleanCameraNames
global neoVRayLightLister, neoCoronaLightLister, neoVRayInteractive, neoCoronaInteractive
global neoLightMixSetup, neoLightMixBake, neoBuildContactSheet, neoCRSettingsLoaded

global neoReManager = maxOps.GetCurRenderElementMgr()
global CaptureToolUI
global CaptureToolBottom
global rltVR_GlobalSwitches
global rltVR_ImageSampler
global rltVR_BucketSampler
global rltVR_ImageFilter
global rltVR_ColorMapping
global rltVR_GlobalIllum
global rltVR_LightCache
global rltVR_System
global rltVR_SettingsTabBar
global ProSettingsCoronaUI
global rltCR_SettingsTabBar
global rltCR_Quality
global rltCR_Denoising
global rltCR_Filtering
global rltCR_BloomGlare
global rltCR_GI
global rltCR_Performance
global rltCR_MBDOF
global rltCR_Caustics
global rltCR_SysVFB
global rltCR_SysOverrides
global rltCR_VantageTools
global showCRSettingsTab
global neoCRSettingsLoaded = false
global NeoCaptureMainUI
global neoCaptureFloater
global neoSettingsFloater
global neoElementsFloater
try(closeRolloutFloater neoCaptureFloater) catch()
try(closeRolloutFloater neoSettingsFloater) catch()
try(closeRolloutFloater neoElementsFloater) catch()
try(destroyDialog NeoCaptureMainUI) catch()
try(destroyDialog CaptureToolUI) catch()
try(destroyDialog CaptureToolBottom) catch()
try(destroyDialog ProSettingsCoronaUI) catch()

global addElementLive
global removeElementLive
global applyElementParamsLive
global neoOpenConverter
global neoCheckForeignElements
global neoRunActionByText
global neoCallVantageFn
global neoStartVantageLiveLink

-- ============================ [2] ELEMENT HELPERS + V-RAY PRO SETTINGS ============================
fn addElementLive elClass = (
    local el = undefined
    try(el = execute (elClass + "()")) catch()
    if el != undefined do (
        neoReManager.AddRenderElement el
        try(applyElementParamsLive())catch()
    )
)
fn removeElementLive elClass = (
    for i = neoReManager.numRenderElements() - 1 to 0 by -1 do (
        local currentEl = neoReManager.getRenderElement i
        if (classof currentEl as string) == elClass then neoReManager.removeRenderElement currentEl
    )
)

global showVRSettingsTab
fn showVRSettingsTab tabName = (
    if neoSettingsFloater == undefined then return()
    local vrGroup = #(rltVR_GlobalSwitches, rltVR_ImageSampler, rltVR_BucketSampler, rltVR_ImageFilter, rltVR_ColorMapping)
    local giGroup = #(rltVR_GlobalIllum, rltVR_LightCache)
    local sysGroup = #(rltVR_System)

    for r in vrGroup do try(removeRollout r neoSettingsFloater)catch()
    for r in giGroup do try(removeRollout r neoSettingsFloater)catch()
    for r in sysGroup do try(removeRollout r neoSettingsFloater)catch()

    local targetGroup = if tabName == #vray then vrGroup else if tabName == #gi then giGroup else sysGroup
    for i = 1 to targetGroup.count do addRollout targetGroup[i] neoSettingsFloater rolledUp:(i != 1)

    try(rltVR_SettingsTabBar.tabVRayMain.checked = (tabName == #vray))catch()
    try(rltVR_SettingsTabBar.tabVRayGI.checked = (tabName == #gi))catch()
    try(rltVR_SettingsTabBar.tabVRaySystem.checked = (tabName == #system))catch()
)

rollout rltVR_SettingsTabBar "" (
    checkbutton tabVRayMain "V-Ray" width:130 height:24 across:3 checked:true highlightColor:(color 30 120 220) tooltip:"Show the main V-Ray quality and sampling panels"
    checkbutton tabVRayGI "GI" width:130 height:24 highlightColor:(color 30 120 220) tooltip:"Show the global illumination and light cache panels"
    checkbutton tabVRaySystem "Settings" width:130 height:24 highlightColor:(color 30 120 220) tooltip:"Show the V-Ray system panels"

    on tabVRayMain changed state do ( if state then showVRSettingsTab #vray else tabVRayMain.checked = true )
    on tabVRayGI changed state do ( if state then showVRSettingsTab #gi else tabVRayGI.checked = true )
    on tabVRaySystem changed state do ( if state then showVRSettingsTab #system else tabVRaySystem.checked = true )
)

rollout rltVR_GlobalSwitches "V-Ray - Global Switches" (
    checkbox chkVR_Disp "Displace" across:4 checked:true
    checkbox chkVR_Lights "Lights" checked:true
    checkbox chkVR_Shadows "Shadows" checked:true
    checkbox chkVR_Hidden "Hidden Lights" checked:true

    dropdownlist ddlVR_Adapt "Adaptive Lights:" items:#("Full lights evaluation", "Light tree", "Adaptive lights") width:170 offset:[0,8]

    checkbox chkVR_DontRender "Don't render final image" offset:[0,8]

    checkbox chkVR_ReflRefr "Reflection/Refraction" across:2 checked:true offset:[0,8]
    checkbox chkVR_Glossy "Glossy effects" checked:true

    spinner spnVR_MaxTransp "Max transp:" range:[0,100,50] type:#integer fieldWidth:50 across:2 offset:[0,8]
    spinner spnVR_TranspCutoff "Transp cutoff:" range:[0,1,0.001] type:#float scale:0.001 fieldWidth:50

    checkbox chkVR_MaxRayIntOn "Max ray intensity:" across:2 offset:[0,8]
    spinner spnVR_MaxRayInt "" range:[0,10000,20.0] type:#float scale:1.0 fieldWidth:60

    spinner spnVR_SecRaysBias "Sec rays bias:" range:[0,100,0.0] type:#float scale:0.1 fieldWidth:60 offset:[0,8]

    checkbox chkVR_MikkTS "Use MikkTSpace" across:2 offset:[0,8]
    checkbox chkVR_PhysMtlAsVRayMtl "Physical Material as VRayMtl" checked:true

    label lblVR_ProbVolHdr "Probabilistic volumetrics (Adaptive lights only):" align:#left offset:[0,8]
    spinner spnVR_ProbVolSamples "Direct samples:" range:[1,1000,20] type:#integer fieldWidth:50

    on chkVR_Disp changed val do try(renderers.current.options_displacement = val)catch()
    on chkVR_Lights changed val do try(renderers.current.options_lights = val)catch()
    on chkVR_Shadows changed val do try(renderers.current.options_shadows = val)catch()
    on chkVR_Hidden changed val do try(renderers.current.options_hiddenLights = val)catch()
    on ddlVR_Adapt selected val do (
        -- options_probabilisticLights: 0 = Full lights evaluation, 1 = Light tree, 2 = Adaptive lights
        -- items are ordered to match the V-Ray Render Setup dropdown, so value = selection - 1
        try(renderers.current.options_probabilisticLights = val - 1)catch()
        spnVR_ProbVolSamples.enabled = (val == 3)
    )
    on chkVR_DontRender changed val do try(renderers.current.options_dontRenderImage = val)catch()
    on chkVR_ReflRefr changed val do try(renderers.current.options_reflectionRefraction = val)catch()
    on chkVR_Glossy changed val do try(renderers.current.options_glossyEffects = val)catch()
    on spnVR_MaxTransp changed val do try(renderers.current.options_transpMaxLevels = val)catch()
    on spnVR_TranspCutoff changed val do try(renderers.current.options_transpCutoff = val)catch()
    on chkVR_MaxRayIntOn changed val do try(renderers.current.options_maxRayIntensity_on = val)catch()
    on spnVR_MaxRayInt changed val do try(renderers.current.options_maxRayIntensity = val)catch()
    on spnVR_SecRaysBias changed val do try(renderers.current.options_ray_bias = val)catch()
    on chkVR_MikkTS changed val do try(renderers.current.options_useMikkTS = val)catch()
    on chkVR_PhysMtlAsVRayMtl changed val do try(renderers.current.options_physicalMaterialAsVRayMtl = val)catch()
    on spnVR_ProbVolSamples changed val do try(renderers.current.options_probabilisticLightsCount = val)catch()

    on rltVR_GlobalSwitches open do (
        local vr = renderers.current
        try(chkVR_Disp.checked = vr.options_displacement)catch()
        try(chkVR_Lights.checked = vr.options_lights)catch()
        try(chkVR_Shadows.checked = vr.options_shadows)catch()
        try(chkVR_Hidden.checked = vr.options_hiddenLights)catch()
        try(ddlVR_Adapt.selection = vr.options_probabilisticLights + 1)catch()
        try(chkVR_DontRender.checked = vr.options_dontRenderImage)catch()
        try(chkVR_ReflRefr.checked = vr.options_reflectionRefraction)catch()
        try(chkVR_Glossy.checked = vr.options_glossyEffects)catch()
        try(spnVR_MaxTransp.value = vr.options_transpMaxLevels)catch()
        try(spnVR_TranspCutoff.value = vr.options_transpCutoff)catch()
        try(chkVR_MaxRayIntOn.checked = vr.options_maxRayIntensity_on)catch()
        try(spnVR_MaxRayInt.value = vr.options_maxRayIntensity)catch()
        try(spnVR_SecRaysBias.value = vr.options_ray_bias)catch()
        try(chkVR_MikkTS.checked = vr.options_useMikkTS)catch()
        try(chkVR_PhysMtlAsVRayMtl.checked = vr.options_physicalMaterialAsVRayMtl)catch()
        try(spnVR_ProbVolSamples.value = vr.options_probabilisticLightsCount)catch()
        try(spnVR_ProbVolSamples.enabled = (ddlVR_Adapt.selection == 3))catch()
    )
)

rollout rltVR_ImageSampler "V-Ray - Image Sampler (Antialiasing)" (
    dropdownlist ddlVR_Sampler "Type:" items:#("Bucket", "Progressive") width:130 selection:1
    dropdownlist ddlVR_RenderMask "Render mask:" items:#("None", "Texture", "Object IDs", "Layers") width:140 selection:1 offset:[0,8]
    spinner spnVR_ShadingRate "Min shading rate:" range:[1,100,6] type:#integer fieldWidth:50 across:2 offset:[0,8]
    spinner spnVR_AdaptClamp "Adaptivity clamp:" range:[0,10,1.5] type:#float scale:0.1 fieldWidth:60
    checkbox chkVR_LockNoise "Lock noise pattern" offset:[0,8]

    on ddlVR_Sampler selected val do try(renderers.current.imageSampler_type = if val == 1 then 1 else 3)catch()
    on ddlVR_RenderMask selected val do try(renderers.current.imageSampler_renderMask_type = val - 1)catch()
    on spnVR_ShadingRate changed val do try(renderers.current.imageSampler_shadingRate = val)catch()
    on spnVR_AdaptClamp changed val do try(renderers.current.imageSampler_dmc_adaptivityClamp = val)catch()
    on chkVR_LockNoise changed val do (
        -- V-Ray 7 ships both names; write whichever exists
        try(renderers.current.dmc_lockNoisePattern = val)catch()
        try(renderers.current.mc_lockNoisePattern = val)catch()
    )

    on rltVR_ImageSampler open do (
        local vr = renderers.current
        try(ddlVR_Sampler.selection = if vr.imageSampler_type == 1 then 1 else 2)catch()
        try(ddlVR_RenderMask.selection = vr.imageSampler_renderMask_type + 1)catch()
        try(spnVR_ShadingRate.value = vr.imageSampler_shadingRate)catch()
        try(spnVR_AdaptClamp.value = vr.imageSampler_dmc_adaptivityClamp)catch()
        try(chkVR_LockNoise.checked = vr.dmc_lockNoisePattern)catch()
        try(chkVR_LockNoise.checked = vr.mc_lockNoisePattern)catch()
    )
)

rollout rltVR_BucketSampler "V-Ray - Bucket Image Sampler" (
    spinner spnVR_MinSub "Min subdivs:" range:[1,1000,1] type:#integer fieldWidth:40 across:3
    spinner spnVR_MaxSub "Max subdivs:" range:[1,10000,24] type:#integer fieldWidth:40
    spinner spnVR_Noise "Noise thresh:" range:[0,1,0.01] type:#float scale:0.001 fieldWidth:45

    spinner spnVR_BucketW "Bucket W:" range:[16,512,48] type:#integer fieldWidth:40 across:2 offset:[0,8]
    spinner spnVR_BucketH "Bucket H:" range:[16,512,48] type:#integer fieldWidth:40

    checkbox chkVR_Firefly "Firefly removal:" across:2 offset:[0,8]
    spinner spnVR_FireflyThresh "" range:[0,1,0.05] type:#float scale:0.01 fieldWidth:45

    on spnVR_MinSub changed val do ( try(renderers.current.twoLevel_baseSubdivs = val)catch(); try(renderers.current.progressive_minSamples = val)catch() )
    on spnVR_MaxSub changed val do ( try(renderers.current.twoLevel_fineSubdivs = val)catch(); try(renderers.current.progressive_maxSamples = val)catch() )
    on spnVR_Noise changed val do ( try(renderers.current.twoLevel_threshold = val)catch(); try(renderers.current.progressive_noise_threshold = val)catch() )
    on spnVR_BucketW changed val do try(renderers.current.twoLevel_bucket_width = val)catch()
    on spnVR_BucketH changed val do try(renderers.current.twoLevel_bucket_height = val)catch()
    on chkVR_Firefly changed val do try(renderers.current.twoLevel_fireflyRemoval_on = val)catch()
    on spnVR_FireflyThresh changed val do try(renderers.current.twoLevel_fireflyRemoval_threshold = val)catch()

    on rltVR_BucketSampler open do (
        local vr = renderers.current
        try(spnVR_MinSub.value = vr.twoLevel_baseSubdivs)catch()
        try(spnVR_MinSub.value = vr.progressive_minSamples)catch()
        try(spnVR_MaxSub.value = vr.twoLevel_fineSubdivs)catch()
        try(spnVR_MaxSub.value = vr.progressive_maxSamples)catch()
        try(spnVR_Noise.value = vr.twoLevel_threshold)catch()
        try(spnVR_Noise.value = vr.progressive_noise_threshold)catch()
        try(spnVR_BucketW.value = vr.twoLevel_bucket_width)catch()
        try(spnVR_BucketH.value = vr.twoLevel_bucket_height)catch()
        try(chkVR_Firefly.checked = vr.twoLevel_fireflyRemoval_on)catch()
        try(spnVR_FireflyThresh.value = vr.twoLevel_fireflyRemoval_threshold)catch()
    )
)

rollout rltVR_ImageFilter "V-Ray - Image Filter" (
    checkbox chkVR_Filter "Enable" across:2 checked:true
    dropdownlist ddlVR_FilterType items:#("VRayLanczosFilter", "Area", "Catmull-Rom", "VRaySincFilter", "VRayBoxFilter", "VRayTriangleFilter", "Sharp Quadratic", "Plate Match/MAX R2", "Quadratic", "Cubic", "Video", "Soften", "Cook Variable", "Blend", "Blackman", "Mitchell-Netravali") width:160 selection:1
    spinner spnVR_FilterSize "Size:" range:[0.1,10,2.0] type:#float scale:0.1 fieldWidth:50 offset:[0,8]

    on chkVR_Filter changed val do try(renderers.current.filter_on = val)catch()
    on ddlVR_FilterType selected val do (
        local fClasses = #("VRayLanczosFilter", "Area", "Catmull_Rom", "VRaySincFilter", "VRayBoxFilter", "VRayTriangleFilter", "Sharp_Quadratic", "Plate_Match_MAX_R2", "Quadratic", "Cubic", "Video", "Soften", "Cook_Variable", "Blend", "Blackman", "Mitchell_Netravali")
        local ok = false
        try(
            renderers.current.filter_kernel = execute (fClasses[val] + "()")
            ok = (((classof renderers.current.filter_kernel) as string) == fClasses[val])
        )catch()
        if ok then (
            -- each filter has its own default size - pull it back into the spinner
            try(spnVR_FilterSize.value = renderers.current.filter_size)catch()
            -- force the open Render Setup dialog to redraw so the change is visible immediately
            try(renderSceneDialog.update())catch()
        )
        else messageBox ("Could not set the image filter to: " + fClasses[val] + "\nPlease report this filter name.") title:"NeoCapture"
    )
    on spnVR_FilterSize changed val do try(renderers.current.filter_size = val)catch()

    on rltVR_ImageFilter open do (
        local vr = renderers.current
        try(chkVR_Filter.checked = vr.filter_on)catch()
        try(
            local fClasses = #("VRayLanczosFilter", "Area", "Catmull_Rom", "VRaySincFilter", "VRayBoxFilter", "VRayTriangleFilter", "Sharp_Quadratic", "Plate_Match_MAX_R2", "Quadratic", "Cubic", "Video", "Soften", "Cook_Variable", "Blend", "Blackman", "Mitchell_Netravali")
            local curClassName = (classof vr.filter_kernel) as string
            local idx = findItem fClasses curClassName
            if idx > 0 then ddlVR_FilterType.selection = idx
        )catch()
        try(spnVR_FilterSize.value = vr.filter_size)catch()
    )
)

rollout rltVR_ColorMapping "V-Ray - Color Mapping" (
    dropdownlist ddlVR_CMType "Type:" items:#("Linear multiply", "Exponential", "HSV exponential", "Intensity exponential", "Gamma correction", "Intensity gamma", "Reinhard") width:170 selection:7
    spinner spnVR_CMMult "Multiplier:" range:[0.001,1000,1.0] type:#float scale:0.01 fieldWidth:50 across:2 offset:[0,8]
    spinner spnVR_CMBurn "Burn value:" range:[0.0,1.0,1.0] type:#float scale:0.01 fieldWidth:50

    on ddlVR_CMType selected val do try(renderers.current.colorMapping_type = (val - 1))catch()
    on spnVR_CMMult changed val do try(renderers.current.colorMapping_darkMult = val)catch()
    on spnVR_CMBurn changed val do try(renderers.current.colorMapping_brightMult = val)catch()

    on rltVR_ColorMapping open do (
        local vr = renderers.current
        try(ddlVR_CMType.selection = vr.colorMapping_type + 1)catch()
        try(spnVR_CMMult.value = vr.colorMapping_darkMult)catch()
        try(spnVR_CMBurn.value = vr.colorMapping_brightMult)catch()
    )
)

rollout rltVR_GlobalIllum "V-Ray - Global Illumination" (
    checkbox chkVR_GI "Enable GI" checked:true
    dropdownlist ddlVR_PrimGI "Primary Engine:" items:#("Brute force", "Irradiance map", "Light cache") width:150 offset:[0,8]
    dropdownlist ddlVR_SecGI "Secondary Engine:" items:#("Light cache", "Brute force", "None") width:150 offset:[0,8]

    on chkVR_GI changed val do try(renderers.current.gi_on = val)catch()
    on ddlVR_PrimGI selected val do try(renderers.current.gi_primary_type = if val == 1 then 2 else if val == 3 then 3 else 0)catch()
    on ddlVR_SecGI selected val do try(renderers.current.gi_secondary_type = if val == 1 then 3 else if val == 2 then 2 else 0)catch()

    on rltVR_GlobalIllum open do (
        local vr = renderers.current
        try(chkVR_GI.checked = vr.gi_on)catch()
        try(
            local p = vr.gi_primary_type
            ddlVR_PrimGI.selection = if p == 2 then 1 else if p == 3 then 3 else 2
        )catch()
        try(
            local p = vr.gi_secondary_type
            ddlVR_SecGI.selection = if p == 3 then 1 else if p == 2 then 2 else 3
        )catch()
    )
)

rollout rltVR_LightCache "V-Ray - Light Cache" (
    dropdownlist ddlVR_LC "Preset:" items:#("Still", "Animation") width:100 selection:1
    spinner spnVR_LCSub "Subdivs:" range:[100,10000,1000] type:#integer fieldWidth:60 across:2 offset:[0,8]
    spinner spnVR_LCSamp "Sample size:" range:[0.001,10,0.01] type:#float scale:0.001 fieldWidth:60

    checkbox chkVR_LCPhase "Show phase" across:2 checked:true offset:[0,8]
    checkbox chkVR_LCDir "Store direct" checked:true
    checkbox chkVR_LCRetrace "Retrace:" across:2 checked:true offset:[0,8]
    spinner spnVR_LCRetraceVal "" range:[0.1,10,2.0] type:#float scale:0.1 fieldWidth:50

    on ddlVR_LC selected val do (
        try(renderers.current.lightmap_preset = val - 1)catch()
        if val == 1 then (
            try(renderers.current.lightcache_retrace_on = true)catch()
            try(renderers.current.lightcache_subdivs = 1000)catch()
            spnVR_LCSub.value = 1000
            chkVR_LCRetrace.checked = true
        ) else (
            try(renderers.current.lightcache_retrace_on = false)catch()
            try(renderers.current.lightcache_subdivs = 3000)catch()
            spnVR_LCSub.value = 3000
            chkVR_LCRetrace.checked = false
        )
    )
    on spnVR_LCSub changed val do try(renderers.current.lightcache_subdivs = val)catch()
    on spnVR_LCSamp changed val do try(renderers.current.lightcache_sampleSize = val)catch()
    on chkVR_LCPhase changed val do try(renderers.current.lightcache_showCalcPhase = val)catch()
    on chkVR_LCDir changed val do try(renderers.current.lightcache_storeDirectLight = val)catch()
    on chkVR_LCRetrace changed val do try(renderers.current.lightcache_retrace_on = val)catch()
    on spnVR_LCRetraceVal changed val do try(renderers.current.lightcache_retrace_threshold = val)catch()

    on rltVR_LightCache open do (
        local vr = renderers.current
        try(ddlVR_LC.selection = vr.lightmap_preset + 1)catch()
        try(spnVR_LCSub.value = vr.lightcache_subdivs)catch()
        try(spnVR_LCSamp.value = vr.lightcache_sampleSize)catch()
        try(chkVR_LCPhase.checked = vr.lightcache_showCalcPhase)catch()
        try(chkVR_LCDir.checked = vr.lightcache_storeDirectLight)catch()
        try(chkVR_LCRetrace.checked = vr.lightcache_retrace_on)catch()
        try(spnVR_LCRetraceVal.value = vr.lightcache_retrace_threshold)catch()
    )
)

rollout rltVR_System "V-Ray - System" (
    dropdownlist ddlVR_Seq "Sequence:" items:#("Triangulation", "Top-bottom", "Left-right") width:150 selection:1
    spinner spnVR_PostRate "Post rate:" range:[1,100,10] type:#integer fieldWidth:50 offset:[0,8]
    checkbox chkVR_PostShow "Auto-show post defs" checked:true offset:[0,8]

    on ddlVR_Seq selected val do try(renderers.current.system_region_sequence = if val == 1 then 4 else if val == 2 then 0 else 1)catch()
    on spnVR_PostRate changed val do try(renderers.current.system_effects_progressive_update = val)catch()
    on chkVR_PostShow changed val do try(renderers.current.system_autoswitch_effectsResult = val)catch()

    on rltVR_System open do (
        local vr = renderers.current
        try(
            local p = vr.system_region_sequence
            ddlVR_Seq.selection = if p == 4 then 1 else if p == 0 then 2 else 3
        )catch()
        try(spnVR_PostRate.value = vr.system_effects_progressive_update)catch()
        try(chkVR_PostShow.checked = vr.system_autoswitch_effectsResult)catch()
    )
)

-- ============================ [4] CORONA PRO SETTINGS (tabbed, mirrors the V-Ray system) ============================
-- All property names below were verified against a live dump of this machine's Corona renderer (NeoCoronaDump.txt).

fn showCRSettingsTab tabName = (
    if neoSettingsFloater == undefined then return()
    local mainGroup = #(rltCR_Quality, rltCR_Denoising, rltCR_Filtering, rltCR_BloomGlare)
    local giGroup = #(rltCR_GI, rltCR_Performance, rltCR_MBDOF, rltCR_Caustics)
    local sysGroup = #(rltCR_SysVFB, rltCR_SysOverrides, rltCR_VantageTools)

    for r in mainGroup do try(removeRollout r neoSettingsFloater)catch()
    for r in giGroup do try(removeRollout r neoSettingsFloater)catch()
    for r in sysGroup do try(removeRollout r neoSettingsFloater)catch()

    local targetGroup = if tabName == #main then mainGroup else if tabName == #gi then giGroup else sysGroup
    for i = 1 to targetGroup.count do addRollout targetGroup[i] neoSettingsFloater rolledUp:(i != 1)

    try(rltCR_SettingsTabBar.tabCRMain.checked = (tabName == #main))catch()
    try(rltCR_SettingsTabBar.tabCRGI.checked = (tabName == #gi))catch()
    try(rltCR_SettingsTabBar.tabCRSystem.checked = (tabName == #system))catch()
)

rollout rltCR_SettingsTabBar "" (
    checkbutton tabCRMain "Corona" width:130 height:24 across:3 checked:true highlightColor:(color 255 128 32) tooltip:"Show the main Corona quality and denoising panels"
    checkbutton tabCRGI "GI and Perf" width:130 height:24 highlightColor:(color 255 128 32) tooltip:"Show the global illumination and performance panels"
    checkbutton tabCRSystem "System" width:130 height:24 highlightColor:(color 255 128 32) tooltip:"Show the Corona system, VFB and Vantage panels"

    on tabCRMain changed state do ( if state then showCRSettingsTab #main else tabCRMain.checked = true )
    on tabCRGI changed state do ( if state then showCRSettingsTab #gi else tabCRGI.checked = true )
    on tabCRSystem changed state do ( if state then showCRSettingsTab #system else tabCRSystem.checked = true )
)

rollout rltCR_Quality "Corona - Quality and Limits" (
    spinner spnPassLimit "Pass limit (0 = unlimited):" range:[0,100000,0] type:#integer fieldWidth:60
    spinner spnTimeLimit "Time limit (min, 0 = off):" range:[0,10080,0] type:#float scale:0.5 fieldWidth:60 offset:[0,8]
    spinner spnNoiseLimit "Noise level limit %:" range:[0,100,0] type:#float scale:0.1 fieldWidth:60 offset:[0,8]
    spinner spnMSI "Max sample intensity (MSI):" range:[0,10000,20.0] type:#float scale:0.5 fieldWidth:60 offset:[0,8]
    spinner spnRayDepth "Max ray depth:" range:[1,200,25] type:#integer fieldWidth:60 offset:[0,8]
    spinner spnGIAA "GI vs AA balance:" range:[1,128,16] type:#integer fieldWidth:60 offset:[0,8]
    spinner spnLightSamples "Light samples multiplier:" range:[0.1,10,2.0] type:#float scale:0.1 fieldWidth:60 offset:[0,8]

    on spnPassLimit changed val do try(renderers.current.progressive_passLimit = val)catch()
    on spnTimeLimit changed val do try(renderers.current.progressive_timeLimit = ((val * 60000.0) as integer))catch()
    on spnNoiseLimit changed val do try(renderers.current.adaptivity_targetError = val)catch()
    on spnMSI changed val do try(renderers.current.shading_maxSampleIntensity = val)catch()
    on spnRayDepth changed val do try(renderers.current.shading_maxRayDepth = val)catch()
    on spnGIAA changed val do try(renderers.current.shading_giToAaRatio = val)catch()
    on spnLightSamples changed val do try(renderers.current.lights_samplesMult = val)catch()

    on rltCR_Quality open do (
        neoCRSettingsLoaded = true
        local cr = renderers.current
        try(spnPassLimit.value = cr.progressive_passLimit)catch()
        try(spnTimeLimit.value = cr.progressive_timeLimit / 60000.0)catch()
        try(spnNoiseLimit.value = cr.adaptivity_targetError)catch()
        try(spnMSI.value = cr.shading_maxSampleIntensity)catch()
        try(spnRayDepth.value = cr.shading_maxRayDepth)catch()
        try(spnGIAA.value = cr.shading_giToAaRatio)catch()
        try(spnLightSamples.value = cr.lights_samplesMult)catch()
    )
)

rollout rltCR_Denoising "Corona - Denoising" (
    dropdownlist ddlDenoiser "Denoiser:" items:#("None", "Corona High Quality", "Fast Preview (GPU)", "Intel AI (CPU)", "NVIDIA AI (GPU)") width:200
    spinner spnBlend "Denoise blend amount:" range:[0,1,0.65] type:#float scale:0.01 fieldWidth:60 offset:[0,8]
    spinner spnTexBlur "Texture blur:" range:[0,1,1.0] type:#float scale:0.01 fieldWidth:60 offset:[0,8]

    on ddlDenoiser selected val do try(renderers.current.denoise_filterType = val - 1)catch()
    on spnBlend changed val do try(renderers.current.denoise_blendAmount = val)catch()
    on spnTexBlur changed val do try(renderers.current.denoise_textureBlur = val)catch()

    on rltCR_Denoising open do (
        neoCRSettingsLoaded = true
        local cr = renderers.current
        try(ddlDenoiser.selection = cr.denoise_filterType + 1)catch()
        try(spnBlend.value = cr.denoise_blendAmount)catch()
        try(spnTexBlur.value = cr.denoise_textureBlur)catch()
    )
)

rollout rltCR_Filtering "Corona - Filtering and Sharpening" (
    spinner spnFilterW "Image filter width (px):" range:[1,8,2.0] type:#float scale:0.1 fieldWidth:60
    dropdownlist ddlFirefly "Fireflies removal:" items:#("Disabled", "Enabled") width:160 offset:[0,8]
    spinner spnFireflyStr "Fireflies strength:" range:[0.1,5,1.0] type:#float scale:0.1 fieldWidth:60 offset:[0,8]
    checkbox chkSharp "Enable sharpening / blurring" offset:[0,8]
    spinner spnSharpAmt "Sharpen amount:" range:[0,10,1.0] type:#float scale:0.05 fieldWidth:60 offset:[0,8]
    spinner spnSharpRad "Sharpen radius:" range:[0,5,0.5] type:#float scale:0.05 fieldWidth:60 offset:[0,8]
    spinner spnBlurRad "Blur radius:" range:[0,10,1.33] type:#float scale:0.05 fieldWidth:60 offset:[0,8]

    on spnFilterW changed val do try(renderers.current.image_prefilter_width = val)catch()
    on ddlFirefly selected val do try(renderers.current.fireflyFilter_mode = val - 1)catch()
    on spnFireflyStr changed val do try(renderers.current.fireflyFilter_strength = val)catch()
    on chkSharp changed val do try(renderers.current.sharpening_blurring_enable = val)catch()
    on spnSharpAmt changed val do try(renderers.current.sharpening_amount = val)catch()
    on spnSharpRad changed val do try(renderers.current.sharpening_radius = val)catch()
    on spnBlurRad changed val do try(renderers.current.blurring_radius = val)catch()

    on rltCR_Filtering open do (
        neoCRSettingsLoaded = true
        local cr = renderers.current
        try(spnFilterW.value = cr.image_prefilter_width)catch()
        try(ddlFirefly.selection = cr.fireflyFilter_mode + 1)catch()
        try(spnFireflyStr.value = cr.fireflyFilter_strength)catch()
        try(chkSharp.checked = cr.sharpening_blurring_enable)catch()
        try(spnSharpAmt.value = cr.sharpening_amount)catch()
        try(spnSharpRad.value = cr.sharpening_radius)catch()
        try(spnBlurRad.value = cr.blurring_radius)catch()
    )
)

rollout rltCR_BloomGlare "Corona - Bloom and Glare" (
    checkbox chkBG "Enable Bloom and Glare"
    spinner spnBloomInt "Bloom intensity:" range:[0,100,1.0] type:#float scale:0.05 fieldWidth:60 offset:[0,8]
    spinner spnGlareInt "Glare intensity:" range:[0,100,1.0] type:#float scale:0.05 fieldWidth:60 offset:[0,8]
    spinner spnBGSize "Size:" range:[0,1000,15.0] type:#float scale:0.5 fieldWidth:60 offset:[0,8]
    spinner spnBGThresh "Threshold:" range:[0,1000,1.0] type:#float scale:0.05 fieldWidth:60 offset:[0,8]
    spinner spnBGStreaks "Streak count:" range:[1,30,3] type:#integer fieldWidth:60 offset:[0,8]
    spinner spnBGRot "Streaks rotation:" range:[-360,360,15.0] type:#float scale:1.0 fieldWidth:60 offset:[0,8]

    on chkBG changed val do try(renderers.current.bloomGlare_enabled = val)catch()
    on spnBloomInt changed val do try(renderers.current.bloomGlare_bloomIntensity = val)catch()
    on spnGlareInt changed val do try(renderers.current.bloomGlare_glareIntensity = val)catch()
    on spnBGSize changed val do try(renderers.current.bloomGlare_size = val)catch()
    on spnBGThresh changed val do try(renderers.current.bloomGlare_threshold = val)catch()
    on spnBGStreaks changed val do try(renderers.current.bloomGlare_streakCount = val)catch()
    on spnBGRot changed val do try(renderers.current.bloomGlare_rotation = val)catch()

    on rltCR_BloomGlare open do (
        local cr = renderers.current
        try(chkBG.checked = cr.bloomGlare_enabled)catch()
        try(spnBloomInt.value = cr.bloomGlare_bloomIntensity)catch()
        try(spnGlareInt.value = cr.bloomGlare_glareIntensity)catch()
        try(spnBGSize.value = cr.bloomGlare_size)catch()
        try(spnBGThresh.value = cr.bloomGlare_threshold)catch()
        try(spnBGStreaks.value = cr.bloomGlare_streakCount)catch()
        try(spnBGRot.value = cr.bloomGlare_rotation)catch()
    )
)

rollout rltCR_GI "Corona - Global Illumination" (
    dropdownlist ddlPrim "Primary solver:" items:#("Path Tracing", "None") width:160
    dropdownlist ddlSec "Secondary solver:" items:#("None", "Path Tracing", "UHD Cache", "4K Cache") width:160 offset:[0,8]
    spinner spnUHDPrec "UHD Cache precision:" range:[0.1,10,1.0] type:#float scale:0.1 fieldWidth:60 offset:[0,8]
    spinner spn4KQual "4K Cache quality:" range:[0.1,10,1.0] type:#float scale:0.1 fieldWidth:60 offset:[0,8]

    on ddlPrim selected val do try(renderers.current.shading_primarySolver = (if val == 1 then 1 else 0))catch()
    on ddlSec selected val do try(renderers.current.shading_secondarySolver = val - 1)catch()
    on spnUHDPrec changed val do try(renderers.current.gi_uhdcache_precision = val)catch()
    on spn4KQual changed val do try(renderers.current.gi_fourkcache_quality = val)catch()

    on rltCR_GI open do (
        local cr = renderers.current
        try(ddlPrim.selection = (if cr.shading_primarySolver == 1 then 1 else 2))catch()
        try(ddlSec.selection = cr.shading_secondarySolver + 1)catch()
        try(spnUHDPrec.value = cr.gi_uhdcache_precision)catch()
        try(spn4KQual.value = cr.gi_fourkcache_quality)catch()
    )
)

rollout rltCR_Performance "Corona - Performance" (
    checkbox chkAdapt "Adaptive image sampling" checked:true
    checkbox chkLockPattern "Lock sampling pattern (animation)" offset:[0,8]
    spinner spnThreads "Render threads (0 = all):" range:[0,256,0] type:#integer fieldWidth:60 offset:[0,8]
    spinner spnIntPasses "Interactive pass limit:" range:[0,100000,200] type:#integer fieldWidth:60 offset:[0,8]
    spinner spnDispSize "Displacement size (px):" range:[0.1,100,2.0] type:#float scale:0.1 fieldWidth:60 offset:[0,8]
    checkbox chkAutoBump "Displacement auto bump" checked:true offset:[0,8]
    checkbox chkOOC "Out-of-core textures" checked:true offset:[0,8]

    on chkAdapt changed val do try(renderers.current.adaptivity_enable = val)catch()
    on chkLockPattern changed val do try(renderers.current.lockSamplingPattern = val)catch()
    on spnThreads changed val do try(renderers.current.system_numThreads = val)catch()
    on spnIntPasses changed val do try(renderers.current.interactive_passLimit = val)catch()
    on spnDispSize changed val do try(renderers.current.geometry_displace_maxSizeScreen = val)catch()
    on chkAutoBump changed val do try(renderers.current.geometry_displace_useAutoBump = val)catch()
    on chkOOC changed val do try(renderers.current.ooct_enable = val)catch()

    on rltCR_Performance open do (
        local cr = renderers.current
        try(chkAdapt.checked = cr.adaptivity_enable)catch()
        try(chkLockPattern.checked = cr.lockSamplingPattern)catch()
        try(spnThreads.value = cr.system_numThreads)catch()
        try(spnIntPasses.value = cr.interactive_passLimit)catch()
        try(spnDispSize.value = cr.geometry_displace_maxSizeScreen)catch()
        try(chkAutoBump.checked = cr.geometry_displace_useAutoBump)catch()
        try(chkOOC.checked = cr.ooct_enable)catch()
    )
)

rollout rltCR_MBDOF "Corona - Motion Blur and DOF" (
    checkbox chkMBCam "Camera motion blur"
    checkbox chkMBGeo "Geometry motion blur"
    spinner spnMBTrans "Transform segments:" range:[1,64,6] type:#integer fieldWidth:60 offset:[0,8]
    spinner spnMBGeoS "Geometry segments:" range:[1,64,3] type:#integer fieldWidth:60 offset:[0,8]
    spinner spnMBOffset "Frame offset:" range:[-10,10,0.0] type:#float scale:0.05 fieldWidth:60 offset:[0,8]
    checkbox chkDOF "Depth of field" offset:[0,8]
    checkbox chkDOFSolver "Fast DOF solver" offset:[0,8]

    on chkMBCam changed val do try(renderers.current.mb_useCamera = val)catch()
    on chkMBGeo changed val do try(renderers.current.mb_useGeometry = val)catch()
    on spnMBTrans changed val do try(renderers.current.mb_segmentsTransform = val)catch()
    on spnMBGeoS changed val do try(renderers.current.mb_segmentsGeometry = val)catch()
    on spnMBOffset changed val do try(renderers.current.mb_frameOffset = val)catch()
    on chkDOF changed val do try(renderers.current.dof_use = val)catch()
    on chkDOFSolver changed val do try(renderers.current.dofSolver_enable = val)catch()

    on rltCR_MBDOF open do (
        local cr = renderers.current
        try(chkMBCam.checked = cr.mb_useCamera)catch()
        try(chkMBGeo.checked = cr.mb_useGeometry)catch()
        try(spnMBTrans.value = cr.mb_segmentsTransform)catch()
        try(spnMBGeoS.value = cr.mb_segmentsGeometry)catch()
        try(spnMBOffset.value = cr.mb_frameOffset)catch()
        try(chkDOF.checked = cr.dof_use)catch()
        try(chkDOFSolver.checked = cr.dofSolver_enable)catch()
    )
)

rollout rltCR_Caustics "Corona - Caustics" (
    checkbox chkCaustics "Enable fast caustics"
    spinner spnCausticsPPP "Photons per pixel:" range:[0.01,100,1.5] type:#float scale:0.1 fieldWidth:60 offset:[0,8]
    spinner spnCausticsMSI "Caustics max sample intensity:" range:[0,1000,3.0] type:#float scale:0.1 fieldWidth:60 offset:[0,8]
    checkbox chkCausticsEnv "Emit from environment" checked:true offset:[0,8]
    checkbox chkCausticsVol "Volume caustics" checked:true offset:[0,8]

    on chkCaustics changed val do try(renderers.current.caustics_use = val)catch()
    on spnCausticsPPP changed val do try(renderers.current.caustics_photonsPerPixel = val)catch()
    on spnCausticsMSI changed val do try(renderers.current.caustics_maxSampleIntensity = val)catch()
    on chkCausticsEnv changed val do try(renderers.current.caustics_emitFromEnviro = val)catch()
    on chkCausticsVol changed val do try(renderers.current.caustics_volumeEnable = val)catch()

    on rltCR_Caustics open do (
        local cr = renderers.current
        try(chkCaustics.checked = cr.caustics_use)catch()
        try(spnCausticsPPP.value = cr.caustics_photonsPerPixel)catch()
        try(spnCausticsMSI.value = cr.caustics_maxSampleIntensity)catch()
        try(chkCausticsEnv.checked = cr.caustics_emitFromEnviro)catch()
        try(chkCausticsVol.checked = cr.caustics_volumeEnable)catch()
    )
)

rollout rltCR_SysVFB "Corona - VFB and Render Stamp" (
    checkbox chkClearVFB "Clear VFB between renders" checked:true
    checkbox chkStamp "Render stamp" offset:[0,8]
    edittext edtStamp "" text:"Chaos Corona | %c | Time: %pt | Passes: %pp" width:340
    spinner spnStampSize "Stamp font size:" range:[4,64,8] type:#integer fieldWidth:60 offset:[0,8]
    checkbox chkAutosave "VFB autosave" offset:[0,8]
    spinner spnAutosaveInt "Autosave interval (min):" range:[0.1,1440,10.0] type:#float scale:0.5 fieldWidth:60 offset:[0,8]

    on chkClearVFB changed val do try(renderers.current.vfb_clearBetweenRenders = val)catch()
    on chkStamp changed val do try(renderers.current.renderstamp_use = val)catch()
    on edtStamp changed txt do try(renderers.current.renderStamp = txt)catch()
    on spnStampSize changed val do try(renderers.current.renderstamp_fontSize = val)catch()
    on chkAutosave changed val do try(renderers.current.vfb_autosave_enable = val)catch()
    on spnAutosaveInt changed val do try(renderers.current.vfb_autosave_interval = val)catch()

    on rltCR_SysVFB open do (
        neoCRSettingsLoaded = true
        local cr = renderers.current
        try(chkClearVFB.checked = cr.vfb_clearBetweenRenders)catch()
        try(chkStamp.checked = cr.renderstamp_use)catch()
        try(edtStamp.text = cr.renderStamp)catch()
        try(spnStampSize.value = cr.renderstamp_fontSize)catch()
        try(chkAutosave.checked = cr.vfb_autosave_enable)catch()
        try(spnAutosaveInt.value = cr.vfb_autosave_interval)catch()
    )
)

rollout rltCR_SysOverrides "Corona - System and Overrides" (
    checkbox chkMtlOverride "Material override"
    checkbox chkPresGlass "Preserve glass materials" offset:[0,4]
    checkbox chkPresLight "Preserve light materials" offset:[0,4]
    checkbox chkPresDispl "Preserve displacement" offset:[0,4]
    checkbox chkDR "Distributed rendering" offset:[0,8]
    edittext edtVantageAddr "Vantage address:" text:"localhost:20701" width:220 offset:[0,8]

    on chkMtlOverride changed val do try(renderers.current.mtlOverride_enabled = val)catch()
    on chkPresGlass changed val do try(renderers.current.mtlOverride_preserveGlassMtl = val)catch()
    on chkPresLight changed val do try(renderers.current.mtlOverride_preserveLightMtl = val)catch()
    on chkPresDispl changed val do try(renderers.current.mtlOverride_preserveDisplacement = val)catch()
    on chkDR changed val do try(renderers.current.dr_enable = val)catch()
    on edtVantageAddr changed txt do try(renderers.current.vantage_address = txt)catch()

    on rltCR_SysOverrides open do (
        local cr = renderers.current
        try(chkMtlOverride.checked = cr.mtlOverride_enabled)catch()
        try(chkPresGlass.checked = cr.mtlOverride_preserveGlassMtl)catch()
        try(chkPresLight.checked = cr.mtlOverride_preserveLightMtl)catch()
        try(chkPresDispl.checked = cr.mtlOverride_preserveDisplacement)catch()
        try(chkDR.checked = cr.dr_enable)catch()
        try(edtVantageAddr.text = cr.vantage_address)catch()
    )
)

rollout rltCR_VantageTools "Chaos Vantage" (
    button btnCR_V1 "System Settings" width:130 height:24 across:3 tooltip:"Open the Render Setup dialog"
    button btnCR_V2 "Send Scene" width:130 height:24 tooltip:"Export and send the current scene to Chaos Vantage (V-Ray)"
    button btnCR_V3 "Send Animation" width:130 height:24 tooltip:"Export and send the scene with animation to Chaos Vantage (V-Ray)"
    button btnCR_V4 "Import Changes" width:130 height:24 highlightColor:(color 0 150 255) across:3 tooltip:"Import cameras / changes back from Chaos Vantage"
    button btnCR_V5 "Vantage Live Link" width:130 height:24 highlightColor:(color 0 150 255) tooltip:"Toggle Chaos Vantage Live Link (Corona native, V-Ray fallback)"
    button btnCR_V6 "Anim via Live Link" width:130 height:24 highlightColor:(color 0 150 255) tooltip:"Render animation in Vantage through Live Link"

    on btnCR_V1 pressed do try(renderSceneDialog.open())catch()
    on btnCR_V2 pressed do (
        if (neoCallVantageFn "VRayVantage_transferStaticScene") == #notfound do messageBox "Chaos Vantage scripts not found.\nMake sure Chaos Vantage is installed." title:"NeoCapture"
    )
    on btnCR_V3 pressed do (
        if (neoCallVantageFn "VRayVantage_transferAnimScene") == #notfound do messageBox "Chaos Vantage scripts not found.\nMake sure Chaos Vantage is installed." title:"NeoCapture"
    )
    on btnCR_V4 pressed do (
        if (neoCallVantageFn "VRayVantage_importChanges") == #notfound do messageBox "Chaos Vantage scripts not found.\nMake sure Chaos Vantage is installed." title:"NeoCapture"
    )
    on btnCR_V5 pressed do (
        -- Corona 12+ ships its own Vantage live link (CoronaFp interface, confirmed in the dump)
        local ok = false
        try(CoronaRenderer.vantageLiveLink(); ok = true)catch()
        if not ok then neoStartVantageLiveLink()
    )
    on btnCR_V6 pressed do (
        local ok = false
        try(CoronaRenderer.vantageAnimation(); ok = true)catch()
        if not ok then (
            if (neoCallVantageFn "VRayVantage_liveLinkAnimUI") == #notfound do messageBox "Chaos Vantage scripts not found.\nMake sure Chaos Vantage is installed." title:"NeoCapture"
        )
    )
)

-- ============================ [5] RENDER ELEMENT PARAMETER ROLLOUTS ============================
rollout rltVR_Denoiser "VRay Denoiser" (
    checkbox chkEnable "Enable" across:2
    dropdownlist ddPreset "Preset:" items:#("Default","High","Mild") selection:1
    spinner spnStrength "Strength:" range:[0,10,1] type:#float fieldWidth:50 across:2
    spinner spnRadius "Radius:" range:[0,100,10] type:#float fieldWidth:50
    on chkEnable changed state do ( if state then addElementLive "VRayDenoiser" else removeElementLive "VRayDenoiser" )
)
rollout rltVR_ZDepth "VRay ZDepth" (
    checkbox chkEnable "Enable" 
    spinner spnMin "Min (cm):" range:[0,99999,0] type:#float fieldWidth:60 across:2
    spinner spnMax "Max (cm):" range:[0,99999,1000] type:#float fieldWidth:60
    checkbox chkClamp "Clamp" checked:true across:2
    checkbox chkInvert "Invert" checked:true
    on chkEnable changed state do ( if state then addElementLive "VRayZDepth" else removeElementLive "VRayZDepth" )
)
rollout rltVR_LightMix "VRay LightMix" (
    checkbox chkEnable "Enable" across:2
    dropdownlist ddGroup "Group by:" items:#("Instanced lights","Individual lights","Grouped lights","Layers","Manual light selects") selection:1
    checkbox chkSepEmissive "Separate emissive material"
    on chkEnable changed state do ( if state then addElementLive "VRayLightMix" else removeElementLive "VRayLightMix" )
)
rollout rltVR_ColorID "VRay Color ID (WireColor)" (
    checkbox chkEnable "Enable"
    on chkEnable changed state do ( if state then addElementLive "VRayWireColor" else removeElementLive "VRayWireColor" )
)
rollout rltVR_GI "VRay Global Illumination" (
    checkbox chkEnable "Enable" across:2
    spinner spnMult "Multiplier:" range:[0,100,1] type:#float fieldWidth:60
    checkbox chkDenoise "Denoise"
    on chkEnable changed state do ( if state then addElementLive "VRayGlobalIllumination" else removeElementLive "VRayGlobalIllumination" )
)
rollout rltVR_Lighting "VRay Lighting" (
    checkbox chkEnable "Enable" across:2
    spinner spnMult "Multiplier:" range:[0,100,1] type:#float fieldWidth:60
    checkbox chkDenoise "Denoise"
    on chkEnable changed state do ( if state then addElementLive "VRayLighting" else removeElementLive "VRayLighting" )
)
rollout rltVR_Reflection "VRay Reflection" (
    checkbox chkEnable "Enable" across:2
    spinner spnMult "Multiplier:" range:[0,100,1] type:#float fieldWidth:60
    checkbox chkDenoise "Denoise"
    on chkEnable changed state do ( if state then addElementLive "VRayReflection" else removeElementLive "VRayReflection" )
)
rollout rltVR_Refraction "VRay Refraction" (
    checkbox chkEnable "Enable" across:2
    spinner spnMult "Multiplier:" range:[0,100,1] type:#float fieldWidth:60
    checkbox chkDenoise "Denoise"
    on chkEnable changed state do ( if state then addElementLive "VRayRefraction" else removeElementLive "VRayRefraction" )
)
rollout rltVR_Shadows "VRay Shadows" (
    checkbox chkEnable "Enable" across:2
    spinner spnMult "Multiplier:" range:[0,100,1] type:#float fieldWidth:60
    checkbox chkDenoise "Denoise"
    on chkEnable changed state do ( if state then addElementLive "VRayShadows" else removeElementLive "VRayShadows" )
)

rollout rltCR_Cryptomatte "CMasking_Cryptomatte" (
    checkbox chkEnable "Enable"
    on chkEnable changed state do ( if state then addElementLive "CMasking_Cryptomatte" else removeElementLive "CMasking_Cryptomatte" )
)
rollout rltCR_ZDepth "CGeometry_ZDepth" (
    checkbox chkEnable "Enable" 
    spinner spnMin "Min (cm):" range:[0,99999,0] type:#float fieldWidth:60 across:2
    spinner spnMax "Max (cm):" range:[0,99999,1000] type:#float fieldWidth:60
    on chkEnable changed state do ( if state then addElementLive "CGeometry_ZDepth" else removeElementLive "CGeometry_ZDepth" )
)
rollout rltCR_LightMix "CShading_LightMix" (
    checkbox chkEnable "Enable"
    on chkEnable changed state do ( if state then addElementLive "CShading_LightMix" else removeElementLive "CShading_LightMix" )
)
rollout rltCR_ColorID "CMasking_WireColor" (
    checkbox chkEnable "Enable"
    on chkEnable changed state do ( if state then addElementLive "CMasking_WireColor" else removeElementLive "CMasking_WireColor" )
)
rollout rltCR_Reflect "CESSENTIAL_Reflect" (
    checkbox chkEnable "Enable"
    on chkEnable changed state do ( if state then addElementLive "CESSENTIAL_Reflect" else removeElementLive "CESSENTIAL_Reflect" )
)
rollout rltCR_Refract "CESSENTIAL_Refract" (
    checkbox chkEnable "Enable"
    on chkEnable changed state do ( if state then addElementLive "CESSENTIAL_Refract" else removeElementLive "CESSENTIAL_Refract" )
)
rollout rltCR_Shadows "CShading_Shadows" (
    checkbox chkEnable "Enable"
    on chkEnable changed state do ( if state then addElementLive "CShading_Shadows" else removeElementLive "CShading_Shadows" )
)

fn applyElementParamsLive = (
    for i = 0 to neoReManager.numRenderElements() - 1 do (
        local el = neoReManager.getRenderElement i
        local cls = classof el as string
        case cls of (
            "VRayZDepth": (
                try(el.zdepth_min = rltVR_ZDepth.spnMin.value)catch()
                try(el.zdepth_max = rltVR_ZDepth.spnMax.value)catch()
                try(el.zdepth_clamp = rltVR_ZDepth.chkClamp.checked)catch()
                try(el.clamp_zdepth = rltVR_ZDepth.chkClamp.checked)catch()
                try(el.invert_zdepth = rltVR_ZDepth.chkInvert.checked)catch()
            )
            "VRayDenoiser": (
                try(el.preset = rltVR_Denoiser.ddPreset.selection - 1)catch()
                try(el.strength = rltVR_Denoiser.spnStrength.value)catch()
                try(el.radius = rltVR_Denoiser.spnRadius.value)catch()
            )
            "VRayLightMix": (
                try(el.mode = rltVR_LightMix.ddGroup.selection - 1)catch()
                try(el.groupBy = rltVR_LightMix.ddGroup.selection - 1)catch()
                try(el.separateEmissive = rltVR_LightMix.chkSepEmissive.checked)catch()
                try(el.separate_emissive = rltVR_LightMix.chkSepEmissive.checked)catch()
            )
            "VRayGlobalIllumination": (
                try(el.multiplier = rltVR_GI.spnMult.value)catch()
                try(el.mult = rltVR_GI.spnMult.value)catch()
                try(el.denoise_on = rltVR_GI.chkDenoise.checked)catch()
                try(el.denoise = rltVR_GI.chkDenoise.checked)catch()
            )
            "VRayLighting": (
                try(el.multiplier = rltVR_Lighting.spnMult.value)catch()
                try(el.mult = rltVR_Lighting.spnMult.value)catch()
                try(el.denoise_on = rltVR_Lighting.chkDenoise.checked)catch()
                try(el.denoise = rltVR_Lighting.chkDenoise.checked)catch()
            )
            "VRayReflection": (
                try(el.multiplier = rltVR_Reflection.spnMult.value)catch()
                try(el.mult = rltVR_Reflection.spnMult.value)catch()
                try(el.denoise_on = rltVR_Reflection.chkDenoise.checked)catch()
                try(el.denoise = rltVR_Reflection.chkDenoise.checked)catch()
            )
            "VRayRefraction": (
                try(el.multiplier = rltVR_Refraction.spnMult.value)catch()
                try(el.mult = rltVR_Refraction.spnMult.value)catch()
                try(el.denoise_on = rltVR_Refraction.chkDenoise.checked)catch()
                try(el.denoise = rltVR_Refraction.chkDenoise.checked)catch()
            )
            "VRayShadows": (
                try(el.multiplier = rltVR_Shadows.spnMult.value)catch()
                try(el.mult = rltVR_Shadows.spnMult.value)catch()
                try(el.denoise_on = rltVR_Shadows.chkDenoise.checked)catch()
                try(el.denoise = rltVR_Shadows.chkDenoise.checked)catch()
            )
            "CGeometry_ZDepth": (
                try(el.minDepth = rltCR_ZDepth.spnMin.value)catch()
                try(el.maxDepth = rltCR_ZDepth.spnMax.value)catch()
                try(el.depthMin = rltCR_ZDepth.spnMin.value)catch()
                try(el.depthMax = rltCR_ZDepth.spnMax.value)catch()
            )
        )
    )
)

-- ============================ [3] ACTION / VANTAGE / CONVERTER HELPERS ============================
-- Search all actionMan tables for an action whose text matches itemPat and execute it.
-- Used as a robust fallback when hardcoded action IDs / macro names differ between installs.
fn neoRunActionByText itemPat tablePat:"*" = (
    local ok = false
    local tableCount = 0
    try(tableCount = actionMan.numActionTables)catch()
    -- per-table try so one broken table cannot abort the whole scan
    for i = 1 to tableCount while not ok do (
        try(
            local aTable = actionMan.getActionTable i
            if aTable != undefined and (matchPattern aTable.name pattern:tablePat ignoreCase:true) then (
                for j = 1 to aTable.numActionItems while not ok do (
                    try(
                        local aItem = aTable.getActionItem j
                        if aItem != undefined then (
                            local descTxt = ""; local btnTxt = ""; local mnuTxt = ""
                            try(descTxt = aItem.getDescriptionText())catch()
                            try(btnTxt = aItem.getButtonText())catch()
                            try(mnuTxt = aItem.getMenuText())catch()
                            if (matchPattern descTxt pattern:itemPat ignoreCase:true) or (matchPattern btnTxt pattern:itemPat ignoreCase:true) or (matchPattern mnuTxt pattern:itemPat ignoreCase:true) then (
                                try(ok = aItem.executeAction())catch()
                                if not ok then try(ok = (actionMan.executeAction aTable.contextId ((aItem.id) as string)))catch()
                            )
                        )
                    )catch()
                )
            )
        )catch()
    )
    ok
)

-- Call an official Chaos Vantage DCC function by name, loading the Vantage scripts if needed.
-- These are the exact scripts the Vantage toolbar buttons use (<Vantage install>\dcc_scripts\3dsMax).
-- Returns #ok (executed), #failed (found but raised an error) or #notfound.
fn neoCallVantageFn fnName = (
    local theFn = undefined
    try(if (globalVars.isGlobal fnName) do theFn = globalVars.get fnName)catch()
    if theFn == undefined then (
        local dccDirs = #("C:\\Program Files\\Chaos\\Vantage\\dcc_scripts\\3dsMax\\", "C:\\Program Files\\Chaos Group\\Vantage\\dcc_scripts\\3dsMax\\")
        for d in dccDirs while theFn == undefined do (
            if doesFileExist (d + "Vantage-UtilityFunctions.ms") do (
                for f in #("Vantage-UtilityFunctions.ms", "Vantage-LiveLink.ms", "Vantage-Settings.ms", "Vantage-TransferStaticVrscene.ms", "Vantage-TransferAnimVrscene.ms", "Vantage-ImportChanges.ms") do (
                    try(if doesFileExist (d + f) do fileIn (d + f))catch()
                )
                try(if (globalVars.isGlobal fnName) do theFn = globalVars.get fnName)catch()
            )
        )
    )
    if theFn == undefined then return #notfound
    local res = #ok
    try(theFn())catch(
        messageBox ("Chaos Vantage error:\n" + (getCurrentException() as string)) title:"NeoCapture"
        res = #failed
    )
    res
)

fn neoStartVantageLiveLink = (
    local ok = false
    -- 1) Official entry point - the exact function the Vantage toolbar Live Link button calls (toggles on/off)
    local res = neoCallVantageFn "VRayVantage_liveLink"
    if res == #ok then ok = true
    else if res == #failed then return false
    -- 2) Fallbacks for older Vantage / V-Ray builds: known macroscripts, then action table scan
    if not ok then (
        local combos = #(#("Chaos Vantage","VantageLiveLink"), #("V-Ray","VantageLiveLink"), #("Chaos Vantage","LiveLink"), #("Vantage","LiveLink"), #("Vantage","VantageLiveLink"), #("V-Ray","vantageLiveLink"))
        for c in combos while not ok do try(macros.run c[1] c[2]; ok = true)catch()
    )
    if not ok then ok = neoRunActionByText "*vantage*live*"
    if not ok then ok = neoRunActionByText "*live*vantage*"
    if not ok then ok = neoRunActionByText "*live*link*" tablePat:"*vantage*"
    -- 3) Scan macroscript folders on disk for a Vantage macro (files are named "Category-Name.mcr")
    if not ok then (
        local macroDirs = #((getDir #userMacros), ((getDir #maxroot) + "MacroScripts"))
        for d in macroDirs while not ok do (
            local mcrFiles = #()
            try(mcrFiles = getFiles (d + "\\*antage*.mcr"))catch()
            for f in mcrFiles while not ok do (
                local base = getFilenameFile f
                local dashPos = findString base "-"
                if dashPos != undefined and dashPos > 1 then (
                    local cat = substring base 1 (dashPos - 1)
                    local nm = substring base (dashPos + 1) base.count
                    if matchPattern nm pattern:"*live*" ignoreCase:true then try(macros.run cat nm; ok = true)catch()
                )
            )
        )
    )
    -- 4) Last resort: offer to launch the Vantage application itself
    if not ok then (
        local exePaths = #("C:\\Program Files\\Chaos Group\\Vantage\\vantage.exe", "C:\\Program Files\\Chaos\\Vantage\\vantage.exe", "C:\\Program Files\\Chaos Group\\Chaos Vantage\\vantage.exe", "C:\\Program Files\\Chaos\\Chaos Vantage\\vantage.exe")
        for p in exePaths while not ok do (
            if doesFileExist p then (
                if queryBox "Live Link command not found inside 3ds Max.\nLaunch the Chaos Vantage application instead?" title:"NeoCapture" then ShellLaunch p ""
                ok = true
            )
        )
    )
    if not ok then messageBox "Chaos Vantage Live Link not found.\nMake sure V-Ray 5+ and the Chaos Vantage Live Link plugin are installed." title:"NeoCapture"
    ok
)

fn neoOpenConverter targetEngine = (
    local opened = false
    if targetEngine == #vray then (
        -- Recorded via Macro Recorder: V-Ray > Convert all scene materials to VRayMtl + raytraced shadows to VRay shadows
        try(opened = (actionMan.executeAction (-905641955) "44"))catch()
        if not opened then opened = neoRunActionByText "*Convert*scene materials*" tablePat:"*V-Ray*"
        if not opened then opened = neoRunActionByText "*scene converter*" tablePat:"*V-Ray*"
        if not opened then try(macros.run "V-Ray" "vraySceneConverter"; opened = true)catch()
        if not opened then try(macros.run "V-Ray" "SceneConverter"; opened = true)catch()
        if not opened then messageBox "Could not run the V-Ray converter automatically.\nOpen it manually: Rendering menu > V-Ray scene converter" title:"NeoCapture"
    ) else (
        -- Recorded via Macro Recorder: Chaos Corona > Open Corona Converter
        try(opened = (actionMan.executeAction 572340868 "7"))catch()
        if not opened then opened = neoRunActionByText "*Corona Converter*"
        if not opened then opened = neoRunActionByText "*converter*" tablePat:"*Corona*"
        if not opened then try(CoronaConverter.openGUI(); opened = true)catch()
        if not opened then try(macros.run "Corona Renderer" "CoronaConverter"; opened = true)catch()
        if not opened then messageBox "Could not open the Corona Converter automatically.\nOpen it manually: Rendering menu > Corona Converter" title:"NeoCapture"
    )
    opened
)

fn neoCheckForeignElements targetEngine = (
    local foreignPat = if targetEngine == #vray then "*Corona*" else "*VRay*"
    local foreignName = if targetEngine == #vray then "Corona" else "V-Ray"
    local targetName = if targetEngine == #vray then "V-Ray" else "Corona"
    local mtlCount = 0
    for mc in material.classes where matchPattern (mc as string) pattern:foreignPat do (
        try(mtlCount += (getClassInstances mc).count)catch()
    )
    local mapCount = 0
    for tc in textureMap.classes where matchPattern (tc as string) pattern:foreignPat do (
        try(mapCount += (getClassInstances tc).count)catch()
    )
    local lightCount = 0
    for l in lights where matchPattern (classOf l as string) pattern:foreignPat do lightCount += 1
    local camCount = 0
    for c in cameras where matchPattern (classOf c as string) pattern:foreignPat do camCount += 1
    if (mtlCount + mapCount + lightCount + camCount) > 0 then (
        local msg = "This scene contains " + foreignName + " elements:\n\n"
        msg += "Materials: " + (mtlCount as string) + "\n"
        msg += "Maps: " + (mapCount as string) + "\n"
        msg += "Lights: " + (lightCount as string) + "\n"
        msg += "Cameras: " + (camCount as string) + "\n\n"
        msg += (if targetEngine == #vray then ("Convert them to " + targetName + " now?") else ("Open the converter to convert them to " + targetName + "?"))
        if queryBox msg title:"NeoCapture - Engine Mismatch" then neoOpenConverter targetEngine
    )
)

global neoCaptureSettingsFile = getDir #userscripts + "\\NeoCaptureSettings.ini"

-- ============================ [6] NEOCAPTURE EXTENSIONS ============================
-- Log, presets, scene check, contact sheet, resolution slots, light lister, script manager, tools

global neoLogFile = (getDir #userscripts) + "\\NeoCaptureLog.txt"
global neoLog
fn neoLog msg = (
    try(
        local sf = if doesFileExist neoLogFile then openFile neoLogFile mode:"a" else createFile neoLogFile
        if sf != undefined do (
            format "% | %\n" localTime msg to:sf
            close sf
        )
    )catch()
)

global neoActiveEngineName
fn neoActiveEngineName = ( if (matchPattern ((classof renderers.current) as string) pattern:"*Corona*") then "CR" else "VR" )

-- ---------- Render presets (per engine, stored in an INI that survives restarts) ----------
global neoCapturePresetsFile = (getDir #userscripts) + "\\NeoCapturePresets.ini"

-- property lists verified against live dumps of this machine (V-Ray 7 / Corona)
global neoVRayPresetProps = #("options_displacement","options_lights","options_shadows","options_hiddenLights","options_probabilisticLights","options_probabilisticLightsCount","options_dontRenderImage","options_reflectionRefraction","options_glossyEffects","options_transpMaxLevels","options_transpCutoff","options_maxRayIntensity_on","options_maxRayIntensity","options_ray_bias","options_useMikkTS","options_physicalMaterialAsVRayMtl","imageSampler_type","imageSampler_renderMask_type","imageSampler_shadingRate","imageSampler_dmc_adaptivityClamp","dmc_lockNoisePattern","twoLevel_baseSubdivs","twoLevel_fineSubdivs","twoLevel_threshold","twoLevel_bucket_width","twoLevel_bucket_height","twoLevel_fireflyRemoval_on","twoLevel_fireflyRemoval_threshold","progressive_minSamples","progressive_maxSamples","progressive_noise_threshold","filter_on","filter_size","colorMapping_type","colorMapping_darkMult","colorMapping_brightMult","gi_on","gi_primary_type","gi_secondary_type","lightcache_subdivs","lightcache_sampleSize","lightcache_showCalcPhase","lightcache_storeDirectLight","lightcache_retrace_on","lightcache_retrace_threshold","system_region_sequence","system_effects_progressive_update","system_autoswitch_effectsResult")
global neoCoronaPresetProps = #("progressive_passLimit","progressive_timeLimit","adaptivity_targetError","shading_maxSampleIntensity","shading_maxRayDepth","shading_giToAaRatio","lights_samplesMult","denoise_filterType","denoise_blendAmount","denoise_textureBlur","image_prefilter_width","fireflyFilter_mode","fireflyFilter_strength","sharpening_blurring_enable","sharpening_amount","sharpening_radius","blurring_radius","bloomGlare_enabled","bloomGlare_bloomIntensity","bloomGlare_glareIntensity","bloomGlare_size","bloomGlare_threshold","bloomGlare_streakCount","bloomGlare_rotation","shading_primarySolver","shading_secondarySolver","gi_uhdcache_precision","gi_fourkcache_quality","adaptivity_enable","lockSamplingPattern","system_numThreads","interactive_passLimit","geometry_displace_maxSizeScreen","geometry_displace_useAutoBump","ooct_enable","mb_useCamera","mb_useGeometry","mb_segmentsTransform","mb_segmentsGeometry","mb_frameOffset","dof_use","dofSolver_enable","caustics_use","caustics_photonsPerPixel","caustics_maxSampleIntensity","caustics_emitFromEnviro","caustics_volumeEnable","vfb_clearBetweenRenders","renderstamp_use","renderStamp","renderstamp_fontSize","vfb_autosave_enable","vfb_autosave_interval")

-- Windows forbids \ / : * ? " < > | in file names - swap them out before building any path
global neoSafeFileName
fn neoSafeFileName str = (
    local badChars = #("\\", "/", ":", "*", "?", "\"", "<", ">", "|")
    local s = str
    for b in badChars do s = substituteString s b "_"
    s
)

-- Windows also refuses folders that END with a space or a dot (e.g. a camera named "cam 1 ")
global neoSafeDirName
fn neoSafeDirName str = (
    local s = neoSafeFileName str
    s = trimRight s " ."
    s = trimLeft s " "
    if s == "" do s = "unnamed"
    s
)

-- Auto-fix camera names carrying leading/trailing spaces or dots - they break output folders
-- and the AI app's data export. Runs silently on every camera list refresh.
global neoCleanCameraNames
fn neoCleanCameraNames = (
    local fixedCount = 0
    for c in cameras do (
        local nm = c.name
        local clean = trimRight (trimLeft nm " ") " ."
        if clean != "" and clean != nm do (
            c.name = clean
            fixedCount += 1
        )
    )
    if fixedCount > 0 do neoLog ("Auto-cleaned " + fixedCount as string + " camera name(s) with stray spaces/dots")
    fixedCount
)

global neoSavePreset
fn neoSavePreset presetName resW:0 resH:0 = (
    local eng = neoActiveEngineName()
    local props = if eng == "CR" then neoCoronaPresetProps else neoVRayPresetProps
    local section = eng + "|" + presetName
    local r = renderers.current
    local count = 0
    for p in props do (
        try(
            setINISetting neoCapturePresetsFile section p ((getProperty r (p as name)) as string)
            count += 1
        )catch()
    )
    -- the V-Ray image filter is an object, store its class name instead of a value
    if eng == "VR" do try(setINISetting neoCapturePresetsFile section "filter_kernel_class" ((classof r.filter_kernel) as string))catch()
    -- output resolution is part of the preset too
    local pw = if resW > 0 then resW else renderWidth
    local ph = if resH > 0 then resH else renderHeight
    try(setINISetting neoCapturePresetsFile section "NEO_ResW" (pw as string))catch()
    try(setINISetting neoCapturePresetsFile section "NEO_ResH" (ph as string))catch()
    -- also save a native 3ds Max render preset (.rps) into Documents\...\renderpresets
    -- so the preset shows up in Render Setup > Preset dropdown as well
    -- saving also APPLIES the chosen resolution to the scene right away
    -- (close Render Setup first so its stale values don't fight back, reopen after)
    local reopenRS = false
    try(if renderSceneDialog.isOpen() do ( renderSceneDialog.close(); reopenRS = true ))catch()
    try(renderWidth = pw; renderHeight = ph)catch()
    try(
        local rpsDir = getDir #renderPresets
        makeDir rpsDir all:true
        local rpsName = "NeoCapture_" + (neoSafeFileName presetName) + ".rps"
        renderPresets.SaveAll 0 (rpsDir + "\\" + rpsName)
        neoLog ("Native .rps preset saved: " + rpsName + " (" + pw as string + "x" + ph as string + ")")
    )catch(neoLog ("Native .rps save failed: " + getCurrentException()))
    if reopenRS do try(renderSceneDialog.open())catch()
    neoLog ("Preset saved: " + section + " (" + count as string + " properties)")
    count
)

global neoApplyPreset
fn neoApplyPreset presetName = (
    -- close Render Setup while applying: an open dialog holds stale copies of the values
    -- and can push them back over the preset; reopening reads everything fresh
    local reopenRS = false
    try(if renderSceneDialog.isOpen() do ( renderSceneDialog.close(); reopenRS = true ))catch()
    local eng = neoActiveEngineName()
    local props = if eng == "CR" then neoCoronaPresetProps else neoVRayPresetProps
    local section = eng + "|" + presetName
    local r = renderers.current
    local count = 0
    for p in props do (
        local sVal = getINISetting neoCapturePresetsFile section p
        if sVal != "" do (
            try(
                local curVal = getProperty r (p as name)
                if (classof curVal == String) then setProperty r (p as name) sVal
                else setProperty r (p as name) (execute sVal)
                count += 1
            )catch()
        )
    )
    if eng == "VR" do (
        local kClass = getINISetting neoCapturePresetsFile section "filter_kernel_class"
        if kClass != "" do (
            try(r.filter_kernel = execute (kClass + "()"))catch()
            try(renderSceneDialog.update())catch()
        )
    )
    -- restore the output resolution saved with the preset
    local sResW = getINISetting neoCapturePresetsFile section "NEO_ResW"
    local sResH = getINISetting neoCapturePresetsFile section "NEO_ResH"
    if sResW != "" do try(renderWidth = sResW as integer)catch()
    if sResH != "" do try(renderHeight = sResH as integer)catch()
    if reopenRS do try(renderSceneDialog.open())catch()
    neoLog ("Preset applied: " + section + " (" + count as string + " properties, " + renderWidth as string + "x" + renderHeight as string + ")")
    count
)

global neoListPresets
fn neoListPresets = (
    local eng = neoActiveEngineName()
    local names = #()
    try(
        for s in (getINISetting neoCapturePresetsFile) do (
            if matchPattern s pattern:(eng + "|*") do append names (substring s 4 s.count)
        )
    )catch()
    names
)

global neoDeletePreset
fn neoDeletePreset presetName = (
    local section = (neoActiveEngineName()) + "|" + presetName
    try(delIniSetting neoCapturePresetsFile section)catch()
    try(deleteFile ((getDir #renderPresets) + "\\NeoCapture_" + (neoSafeFileName presetName) + ".rps"))catch()
    neoLog ("Preset deleted: " + section)
)

-- ---------- Scene check ----------
global neoSceneCheckReportText = ""
global rltNeoReport
rollout rltNeoReport "NeoCapture - Scene Check Report" width:520 height:420 (
    dotNetControl txtReport "System.Windows.Forms.TextBox" pos:[10,10] width:500 height:360
    button btnCopyRep "Copy to Clipboard" width:150 height:26 pos:[10,378] tooltip:"Copy the whole report text to the clipboard"
    button btnCloseRep "Close" width:100 height:26 pos:[410,378] tooltip:"Close the report window"
    on rltNeoReport open do (
        txtReport.MultiLine = true
        txtReport.ReadOnly = true
        txtReport.ScrollBars = txtReport.ScrollBars.Vertical
        txtReport.Text = neoSceneCheckReportText
    )
    on btnCopyRep pressed do try(setclipboardText neoSceneCheckReportText)catch()
    on btnCloseRep pressed do destroyDialog rltNeoReport
)

global neoRunSceneCheck
fn neoRunSceneCheck = (
    local out = stringStream ""
    local issues = 0
    format "NeoCapture Scene Check - %\n" localTime to:out
    format "Renderer: %\n\n" ((classof renderers.current) as string) to:out

    -- 1) missing texture files
    local missingMaps = #()
    try(for f in (usedMaps()) do ( if not (doesFileExist f) do append missingMaps f ))catch()
    if missingMaps.count > 0 then (
        issues += 1
        format "[!] Missing texture files: %\n" missingMaps.count to:out
        for f in missingMaps do format "      %\n" f to:out
    ) else format "[OK] All texture files found.\n" to:out

    -- 2) cameras
    local camCount = cameras.count
    if camCount == 0 then ( issues += 1; format "[!] No cameras in the scene.\n" to:out )
    else format "[OK] Cameras/targets in scene: %\n" camCount to:out

    -- 3) foreign engine elements
    local isCor = ((neoActiveEngineName()) == "CR")
    local foreignPat = if isCor then "*VRay*" else "*Corona*"
    local fMtl = 0
    for mc in material.classes where matchPattern (mc as string) pattern:foreignPat do try(fMtl += (getClassInstances mc).count)catch()
    local fLights = 0
    for l in lights where matchPattern ((classof l) as string) pattern:foreignPat do fLights += 1
    if (fMtl + fLights) > 0 then ( issues += 1; format "[!] Foreign engine elements found: % materials, % lights (pattern %)\n" fMtl fLights foreignPat to:out )
    else format "[OK] No foreign engine elements.\n" to:out

    -- 4) output resolution sanity
    if (renderWidth * renderHeight) > 40000000 then ( issues += 1; format "[!] Very high output resolution: % x %\n" renderWidth renderHeight to:out )
    else format "[OK] Output resolution: % x %\n" renderWidth renderHeight to:out

    -- 5) material override left enabled
    local ovr = false
    if isCor then try(ovr = renderers.current.mtlOverride_enabled)catch()
    else try(ovr = renderers.current.options_overrideMtl_on)catch()
    if ovr then ( issues += 1; format "[!] Material override is ENABLED - final render will be clay!\n" to:out )
    else format "[OK] Material override is off.\n" to:out

    -- 6) objects from missing plugins
    local missingCount = 0
    for cls in #("Missing_Geometry", "Missing_Modifier", "Missing_Material", "Missing_TextureMap", "Missing_Light") do (
        try(missingCount += (getClassInstances (execute cls)).count)catch()
    )
    if missingCount > 0 then ( issues += 1; format "[!] Objects from MISSING plugins: %\n" missingCount to:out )
    else format "[OK] No missing plugin objects.\n" to:out

    format "\n==== Total issues: % ====\n" issues to:out
    neoSceneCheckReportText = out as string
    neoLog ("Scene check run: " + issues as string + " issues found")
    try(destroyDialog rltNeoReport)catch()
    createDialog rltNeoReport
    issues
)

-- ---------- Interactive rendering (engine-specific) ----------
global neoVRayInteractive
fn neoVRayInteractive = (
    local ok = neoRunActionByText "*activeshade*floater*"
    if not ok then ok = neoRunActionByText "*activeshade*"
    neoLog ("V-Ray interactive (ActiveShade) start: " + ok as string)
    if not ok then messageBox "Could not open ActiveShade." title:"NeoCapture"
    ok
)

global neoCoronaInteractive
fn neoCoronaInteractive = (
    local ok = false
    try(CoronaRenderer.startInteractive(); ok = true)catch()
    neoLog ("Corona interactive start: " + ok as string)
    if not ok then messageBox "Could not start Corona interactive rendering.\nMake sure Corona is the active renderer." title:"NeoCapture"
    ok
)

-- ---------- LightMix (Corona native, confirmed in the interface dump) ----------
global neoLightMixSetup
fn neoLightMixSetup = (
    if (neoActiveEngineName()) == "CR" then (
        try(CoronaRenderer.showLightMixSetupDialog())catch(messageBox "Corona LightMix dialog unavailable." title:"NeoCapture")
        neoLog "LightMix setup dialog opened"
    )
    else messageBox "LightMix setup is a Corona feature.\nFor V-Ray: add VRayLightSelect elements, then use VFB > Layers > LightMix." title:"NeoCapture"
)

global neoLightMixBake
fn neoLightMixBake = (
    if (neoActiveEngineName()) == "CR" then (
        try(CoronaRenderer.bakeLightMix(); neoLog "LightMix baked")catch(messageBox "Nothing to bake - render with LightMix elements first." title:"NeoCapture")
    )
    else messageBox "LightMix bake is a Corona feature." title:"NeoCapture"
)

-- ---------- Proxy / assets ----------
global neoExportProxy
fn neoExportProxy = (
    if selection.count == 0 then ( messageBox "Select objects first." title:"NeoCapture"; return false )
    local ok = false
    if (neoActiveEngineName()) == "CR" then (
        -- Verified from this machine's UI config: Corona action table 572340868, action 5 = Create Corona Proxy
        try(ok = (actionMan.executeAction 572340868 "5"))catch()
        if not ok then try(ok = (actionMan.executeAction 572340868 "6"))catch()  -- Open Corona Proxy Exporter
        if not ok then ok = neoRunActionByText "*corona*proxy*"
        if not ok then ok = neoRunActionByText "*proxy*" tablePat:"*Corona*"
    ) else (
        -- Verified from this machine's UI config: V-Ray action table -905641955, action 3 = Create V-Ray Proxy
        try(ok = (actionMan.executeAction (-905641955) "3"))catch()
        if not ok then try(vrayMeshExport(); ok = true)catch()
        if not ok then ok = neoRunActionByText "*mesh export*"
        if not ok then ok = neoRunActionByText "*proxy*" tablePat:"*V-Ray*"
    )
    neoLog ("Proxy export: " + ok as string)
    if not ok then messageBox "Proxy export command not found for the active engine." title:"NeoCapture"
    ok
)

-- ---------- Camera preview ----------
-- Same idea as the viewport capture button but nothing is saved to disk:
-- apply the camera's own resolution, turn on safe frames, jump to the camera,
-- then grab the viewport cropped to the camera aspect and display it inside Max.
global neoPreviewCamera
fn neoPreviewCamera cam = (
    if cam == undefined then return false
    local res = #(renderWidth, renderHeight)
    try(res = CaptureToolUI.getCamRes cam)catch()
    renderWidth = res[1]
    renderHeight = res[2]
    viewport.setCamera cam
    displaySafeFrames = true
    forceCompleteRedraw()
    local dib = viewport.getViewportDib()
    local vpW = dib.width; local vpH = dib.height
    local camAspect = res[1] as float / res[2]
    local vpAspect = vpW as float / vpH
    local cropX = 0; local cropY = 0; local cropW = vpW; local cropH = vpH
    if camAspect < vpAspect then (
        cropW = (vpH * camAspect) as integer
        cropX = ((vpW - cropW) / 2) as integer
    ) else (
        cropH = (vpW / camAspect) as integer
        cropY = ((vpH - cropH) / 2) as integer
    )
    local cropped = bitmap cropW cropH
    for y = 0 to cropH - 1 do setPixels cropped [0, y] (getPixels dib [cropX, cropY + y] cropW)
    try(free dib)catch()
    display cropped
    neoLog ("Camera preview: " + cam.name + " (" + res[1] as string + "x" + res[2] as string + ")")
    true
)

-- ---------- Engine auto-sync (fires when the renderer changes outside the script) ----------
global neoOnRendererChanged
fn neoOnRendererChanged = (
    try(
        if neoCaptureFloater == undefined then return()
        local rName = (classof renderers.current) as string
        if (matchPattern rName pattern:"*Corona*") and neoTargetEngine != #corona then (
            neoSetTargetEngine #corona askUser:false
            neoLog "Engine UI auto-synced to Corona"
        )
        else if (matchPattern rName pattern:"*V_Ray*") and neoTargetEngine != #vray then (
            neoSetTargetEngine #vray askUser:false
            neoLog "Engine UI auto-synced to V-Ray"
        )
    )catch()
)

-- ---------- Presets rollout ----------
global rltNeoPresets
rollout rltNeoPresets "NeoCapture - Render Presets" (
    dropdownlist ddlPresetList "Saved presets (active engine):" items:#() width:340 across:2 align:#left
    button btnPresetRefresh "Refresh" width:90 height:22 offset:[0,18] align:#right tooltip:"Reload the preset list for the active engine"
    edittext edtPresetName "New preset name:" width:340 across:2 align:#left
    button btnPresetSave "Save Current" width:90 height:22 align:#right tooltip:"Save the current render settings and the resolution below as a new preset"
    spinner spnPresetW "Resolution:" range:[10,20000,1920] type:#integer fieldWidth:66 across:3 align:#left offset:[0,6]
    spinner spnPresetH "x" range:[10,20000,1080] type:#integer fieldWidth:66 offset:[0,6]
    button btnPresetGrabRes "Get Current" width:90 height:20 align:#right offset:[0,4] tooltip:"Fill the resolution fields from the current render output size"
    button btnPresetApply "Apply Selected" width:200 height:26 across:2 align:#left offset:[0,6] tooltip:"Push every saved setting of the selected preset (plus its resolution) onto the current renderer"
    button btnPresetDelete "Delete Selected" width:200 height:26 align:#right offset:[0,6] tooltip:"Delete the selected preset and its native .rps copy"
    label lblPresetStatus "" align:#left offset:[0,6]

    fn refreshList = ( ddlPresetList.items = neoListPresets() )

    on rltNeoPresets open do (
        refreshList()
        spnPresetW.value = renderWidth
        spnPresetH.value = renderHeight
    )
    on btnPresetRefresh pressed do refreshList()
    on btnPresetGrabRes pressed do ( spnPresetW.value = renderWidth; spnPresetH.value = renderHeight )
    on ddlPresetList selected idx do (
        -- show the resolution stored inside the picked preset
        local nm = ddlPresetList.items[idx]
        local section = (neoActiveEngineName()) + "|" + nm
        local sw = getINISetting neoCapturePresetsFile section "NEO_ResW"
        local sh = getINISetting neoCapturePresetsFile section "NEO_ResH"
        if sw != "" do try(spnPresetW.value = sw as integer)catch()
        if sh != "" do try(spnPresetH.value = sh as integer)catch()
    )
    on btnPresetSave pressed do (
        local nm = edtPresetName.text
        if nm == "" then messageBox "Type a preset name first." title:"NeoCapture"
        else (
            local n = neoSavePreset nm resW:spnPresetW.value resH:spnPresetH.value
            refreshList()
            lblPresetStatus.text = "Saved '" + nm + "' (" + n as string + " settings + " + spnPresetW.value as string + "x" + spnPresetH.value as string + ")."
        )
    )
    on btnPresetApply pressed do (
        if ddlPresetList.items.count == 0 or ddlPresetList.selection == 0 then messageBox "No preset selected." title:"NeoCapture"
        else (
            local nm = ddlPresetList.items[ddlPresetList.selection]
            local n = neoApplyPreset nm
            lblPresetStatus.text = "Applied '" + nm + "' (" + n as string + " settings)."
        )
    )
    on btnPresetDelete pressed do (
        if ddlPresetList.items.count == 0 or ddlPresetList.selection == 0 then messageBox "No preset selected." title:"NeoCapture"
        else (
            local nm = ddlPresetList.items[ddlPresetList.selection]
            if queryBox ("Delete preset '" + nm + "'?") title:"NeoCapture" do (
                neoDeletePreset nm
                refreshList()
                lblPresetStatus.text = "Deleted '" + nm + "'."
            )
        )
    )
)

-- ---------- Contact sheet: dark minimalist HTML review page of a finished batch ----------
global neoBuildContactSheet
fn neoBuildContactSheet renderRoot sheetData totalSec = (
    local out = stringStream ""
    local projName = if maxFileName != "" then (getFilenameFile maxFileName) else "Untitled Project"
    local okCount = 0
    for e in sheetData where e[5] do okCount += 1

    format "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n" to:out
    format "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n" to:out
    format "<title>% - Render Review</title>\n" projName to:out
    format "<style>\n" to:out
    format ":root { --bg:#101214; --surface:#191c1f; --line:#2a2e33; --text:#e8e6e1; --muted:#8b9298; --accent:#4aa3c0; --ok:#57b47a; --fail:#d06565; }\n" to:out
    format "* { margin:0; padding:0; box-sizing:border-box; }\n" to:out
    format "body { background:var(--bg); color:var(--text); font-family:'Segoe UI', system-ui, sans-serif; padding:48px 5vw; }\n" to:out
    format "header { border-bottom:1px solid var(--line); padding-bottom:24px; margin-bottom:36px; display:flex; justify-content:space-between; align-items:flex-end; flex-wrap:wrap; gap:12px; }\n" to:out
    format "h1 { font-family:Georgia, 'Times New Roman', serif; font-weight:400; font-size:2rem; letter-spacing:0.02em; }\n" to:out
    format "h1 span { color:var(--accent); }\n" to:out
    format ".meta { color:var(--muted); font-size:0.85rem; text-align:right; line-height:1.7; }\n" to:out
    format ".grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(340px, 1fr)); gap:24px; }\n" to:out
    format ".card { background:var(--surface); border:1px solid var(--line); border-radius:6px; overflow:hidden; transition:border-color .2s ease; }\n" to:out
    format ".card:hover { border-color:var(--accent); }\n" to:out
    format ".card img { width:100%; aspect-ratio:16/10; object-fit:cover; display:block; background:#000; cursor:pointer; }\n" "%" to:out
    format ".card .info { padding:14px 16px; display:flex; justify-content:space-between; align-items:baseline; gap:8px; }\n" to:out
    format ".card .name { font-size:0.95rem; letter-spacing:0.03em; }\n" to:out
    format ".card .sub { color:var(--muted); font-size:0.75rem; margin-top:4px; }\n" to:out
    format ".tag { font-size:0.7rem; padding:2px 10px; border-radius:10px; border:1px solid var(--ok); color:var(--ok); white-space:nowrap; }\n" to:out
    format ".tag.fail { border-color:var(--fail); color:var(--fail); }\n" to:out
    format "footer { margin-top:48px; padding-top:16px; border-top:1px solid var(--line); color:var(--muted); font-size:0.72rem; letter-spacing:0.14em; text-transform:uppercase; }\n" to:out
    format "</style>\n</head>\n<body>\n" to:out
    format "<header><h1>%<span> / Render Review</span></h1>" projName to:out
    format "<div class=\"meta\">% cameras &middot; % rendered &middot; % failed<br>Total time: %s &middot; %</div></header>\n" sheetData.count okCount (sheetData.count - okCount) totalSec localTime to:out
    format "<div class=\"grid\">\n" to:out
    for e in sheetData do (
        local imgRel = (neoSafeDirName e[1]) + "/images/preview.jpg"
        format "<div class=\"card\"><a href=\"%\" target=\"_blank\"><img src=\"%\" alt=\"%\" loading=\"lazy\"></a>" imgRel imgRel e[1] to:out
        format "<div class=\"info\"><div><div class=\"name\">%</div><div class=\"sub\">% x % px &middot; %s</div></div>" e[1] e[2] e[3] e[4] to:out
        if e[5] then format "<span class=\"tag\">rendered</span>" to:out
        else format "<span class=\"tag fail\">failed</span>" to:out
        format "</div></div>\n" to:out
    )
    format "</div>\n<footer>NeoCapture &middot; Contact Sheet</footer>\n</body>\n</html>\n" to:out

    local fpath = renderRoot + "\\contact_sheet.html"
    local sf = createFile fpath
    format "%" (out as string) to:sf
    close sf
    shellLaunch fpath ""
    neoLog ("Contact sheet built: " + fpath)
    fpath
)

-- ---------- Customizable quick-resolution slots (right-click a button to edit it) ----------
global neoResSlots = #()
global neoDefaultResSlots = #(#("HD 720",1280,720), #("FHD 1080",1920,1080), #("2K QHD",2560,1440), #("Film 2K",1920,820), #("UW 2K",2560,1080), #("IG Land",1080,566), #("4:3 PC",1600,1200), #("1:1 SQ",1080,1080), #("IG 4:5",1080,1350), #("IG Story",1080,1920), #("2K Vert",1440,2560), #("3:4 Vert",1200,1600), #("A4 Draft",1240,1754), #("Tablet",1536,2048), #("Film Vert",820,1920), #("2K SQ",1500,1500))

global neoLoadResSlots
fn neoLoadResSlots = (
    neoResSlots = #()
    for i = 1 to 16 do (
        local d = neoDefaultResSlots[i]
        local lbl = getINISetting neoCaptureSettingsFile "ResSlots" ("Label" + i as string)
        local sw = getINISetting neoCaptureSettingsFile "ResSlots" ("W" + i as string)
        local sh = getINISetting neoCaptureSettingsFile "ResSlots" ("H" + i as string)
        append neoResSlots #((if lbl != "" then lbl else d[1]), (if sw != "" then (sw as integer) else d[2]), (if sh != "" then (sh as integer) else d[3]))
    )
)

global neoSaveResSlot
fn neoSaveResSlot i lbl w h = (
    setINISetting neoCaptureSettingsFile "ResSlots" ("Label" + i as string) lbl
    setINISetting neoCaptureSettingsFile "ResSlots" ("W" + i as string) (w as string)
    setINISetting neoCaptureSettingsFile "ResSlots" ("H" + i as string) (h as string)
    neoResSlots[i] = #(lbl, w, h)
    neoLog ("Resolution slot " + i as string + " saved: " + lbl + " " + w as string + "x" + h as string)
)

global neoResEditIdx = 1
global rltNeoResEdit
rollout rltNeoResEdit "Edit Resolution Button" width:260 height:132 (
    edittext edtLbl "Label:" width:236 align:#left
    spinner spnW "Width:" range:[10,20000,1920] type:#integer fieldWidth:70 across:2 offset:[0,8]
    spinner spnH "Height:" range:[10,20000,1080] type:#integer fieldWidth:70 offset:[0,8]
    button btnOk "Save" width:112 height:26 across:2 offset:[0,10] tooltip:"Save this label and size permanently to the resolution button"
    button btnCancel "Cancel" width:112 height:26 offset:[0,10] tooltip:"Close without saving changes"

    on rltNeoResEdit open do (
        local s = neoResSlots[neoResEditIdx]
        if s != undefined do ( edtLbl.text = s[1]; spnW.value = s[2]; spnH.value = s[3] )
    )
    on btnOk pressed do (
        neoSaveResSlot neoResEditIdx edtLbl.text spnW.value spnH.value
        try(CaptureToolUI.applyResSlotCaptions())catch()
        destroyDialog rltNeoResEdit
    )
    on btnCancel pressed do destroyDialog rltNeoResEdit
)

-- ---------- Light listers (engine-specific) ----------
-- Max's standard Light Lister does NOT see V-Ray / Corona lights, so each engine gets its own:
-- V-Ray Lister = action 2 in the V-Ray table (verified from this machine's UI config),
-- Corona has a native lister interface.
global neoVRayLightLister
fn neoVRayLightLister = (
    local ok = false
    try(ok = (actionMan.executeAction (-905641955) "2"))catch()
    if not ok then ok = neoRunActionByText "*lister*" tablePat:"*V-Ray*"
    neoLog ("V-Ray light lister: " + ok as string)
    if not ok then messageBox "V-Ray Lister not found." title:"NeoCapture"
    ok
)

global neoCoronaLightLister
fn neoCoronaLightLister = (
    local ok = false
    try(CoronaRenderer.showListerDialog 0; ok = true)catch()
    if not ok then try(CoronaRenderer.showListerDialog 1; ok = true)catch()
    neoLog ("Corona light lister: " + ok as string)
    if not ok then messageBox "Corona Light Lister not found.\nMake sure Corona is the active renderer." title:"NeoCapture"
    ok
)

-- ---------- In-Max download manager (async, Max stays responsive) ----------
-- ############ PASTE THE DOWNLOAD LINKS HERE (Google Drive share links are fine) ############
global neoDL_VRayURL = ""      -- V-Ray 7 Update 4.1
global neoDL_CoronaURL = ""    -- Chaos Corona 15 Hotfix 2
global neoDL_VantageURL = ""   -- Chaos Vantage 3.3.1
-- ###########################################################################################

global neoDLName = ""
global neoDLDest = ""
global neoDLSourceURL = ""
global neoDLClient

global rltNeoDownloader
rollout rltNeoDownloader "NeoCapture - Downloader" width:420 height:172 (
    label lblDLName "" pos:[16,12] width:388
    progressbar prgDL "" pos:[16,34] width:388 height:18 color:(color 60 180 80) value:0
    label lblDL "Connecting..." pos:[16,60] width:388
    groupBox grpDLNote "Please note" pos:[12,82] width:396 height:56
    label lblNote1 "Do NOT close 3ds Max while downloading - the file would be lost." pos:[22,100] width:380
    label lblNote2 "You can keep working. While rendering, only this bar lags - the download keeps running." pos:[22,116] width:380
    button btnDLCancel "Cancel Download" pos:[145,142] width:130 height:24 tooltip:"Stop this download and delete the partial file"

    on rltNeoDownloader open do lblDLName.text = neoDLName
    on btnDLCancel pressed do try(neoDLClient.CancelAsync())catch()
)

global neoDLProgress
fn neoDLProgress s e = (
    try(
        local gotMB = ((e.BytesReceived / 1048576) as integer) as string
        local totMB = if e.TotalBytesToReceive > 0 then (((e.TotalBytesToReceive / 1048576) as integer) as string) else "?"
        rltNeoDownloader.prgDL.value = e.ProgressPercentage
        rltNeoDownloader.lblDL.text = gotMB + " / " + totMB + " MB"
    )catch()
)

global neoDLComplete
fn neoDLComplete s e = (
    local wasCancelled = false
    local errMsg = ""
    try(wasCancelled = e.Cancelled)catch()
    try(if e.Error != undefined do errMsg = e.Error.Message)catch()
    try(destroyDialog rltNeoDownloader)catch()
    if wasCancelled then (
        try(deleteFile neoDLDest)catch()
        neoLog ("Download cancelled: " + neoDLName)
    )
    else if errMsg != "" then (
        try(deleteFile neoDLDest)catch()
        neoLog ("Download FAILED: " + neoDLName + " - " + errMsg)
        -- A firewall rule on 3dsmax.exe blocks every connection made from inside Max.
        -- The browser is not affected by it, so offer that route instead.
        local msg = neoDLName + " could not be downloaded.\n\nReason reported:\n" + errMsg
        msg += "\n\nIf 3ds Max itself is blocked from the internet by a firewall rule,"
        msg += "\nno download can start from inside Max - but your browser still works."
        msg += "\n\nOpen the download link in the browser instead?"
        if queryBox msg title:"NeoCapture - Download failed" do (
            try(ShellLaunch neoDLSourceURL "")catch()
            neoLog ("Download link opened in browser: " + neoDLName)
        )
    )
    else (
        -- Google Drive sometimes answers with a web page instead of the file
        local looksHtml = false
        try(
            if (getFileSize neoDLDest) < 1000000 do (
                local rf = openFile neoDLDest mode:"r"
                local head = readChars rf 200 errorAtEOF:false
                close rf
                if (matchPattern head pattern:"*<html*" ignoreCase:true) or (matchPattern head pattern:"*<!DOCTYPE*" ignoreCase:true) do looksHtml = true
            )
        )catch()
        if looksHtml then (
            try(deleteFile neoDLDest)catch()
            messageBox (neoDLName + ": the link returned a web page, not the file.\nSet the Drive file to 'Anyone with the link' and try again.") title:"NeoCapture"
        ) else (
            neoLog ("Download finished: " + neoDLDest)
            if queryBox (neoDLName + " downloaded successfully.\n\nSaved in:\n" + (getFilenamePath neoDLDest) + "\n\nRun the setup now?\n(No = just open the folder)") title:"NeoCapture" then (
                ShellLaunch neoDLDest ""
                neoLog ("Installer launched: " + neoDLDest)
            ) else try(ShellLaunch "explorer.exe" ("/select,\"" + neoDLDest + "\""))catch()
        )
    )
)

-- Setups land straight on the Desktop: this tool is mostly used on other people's
-- machines, so the file must be impossible to miss. Falls back to the Max data folder
-- only if the Desktop path cannot be resolved.
global neoInstallerDir
fn neoInstallerDir = (
    local d = ""
    try(
        local envCls = dotNetClass "System.Environment"
        local sfCls = dotNetClass "System.Environment+SpecialFolder"
        d = envCls.GetFolderPath sfCls.DesktopDirectory
    )catch()
    if d == "" or not (doesFileExist d) do (
        d = (getDir #maxData) + "\\NeoInstallers"
        makeDir d all:true
    )
    d
)

global neoStartDownload
fn neoStartDownload dlName url = (
    if url == undefined or url == "" then (
        messageBox (dlName + ": the download link is not added yet." ) title:"NeoCapture"
        return false
    )
    local dlUrl = neoDirectDownloadURL url
    local ext = toLower (getFilenameType url)
    if ext != ".exe" and ext != ".msi" and ext != ".zip" do ext = ".exe"
    local destDir = neoInstallerDir()
    local destFile = destDir + "\\" + (neoSafeDirName dlName) + ext
    -- already on disk? offer to run it instead of downloading again
    if (doesFileExist destFile) and (getFileSize destFile) > 1000000 then (
        local sizeMB = ((getFileSize destFile) / 1048576.0) as integer
        if queryBox (dlName + " is already downloaded (" + sizeMB as string + " MB).\n\nLocation:\n" + destFile + "\n\nRun the setup now?\n(No = delete it and download it again)") title:"NeoCapture" then (
            ShellLaunch destFile ""
            neoLog ("Installer launched: " + destFile)
            return true
        )
        try(deleteFile destFile)catch()
    )
    neoDLName = dlName
    neoDLDest = destFile
    neoDLSourceURL = url
    try(neoDLClient.CancelAsync())catch()
    neoDLClient = dotNetObject "System.Net.WebClient"
    try(dotNet.setLifetimeControl neoDLClient #dotnet)catch()
    neoDLClient.Headers.Add "User-Agent" "Mozilla/5.0"
    try((dotNetClass "System.Net.ServicePointManager").SecurityProtocol = (dotNetClass "System.Net.SecurityProtocolType").Tls12)catch()
    dotNet.addEventHandler neoDLClient "DownloadProgressChanged" neoDLProgress
    dotNet.addEventHandler neoDLClient "DownloadFileCompleted" neoDLComplete
    try(destroyDialog rltNeoDownloader)catch()
    createDialog rltNeoDownloader
    neoDLClient.DownloadFileAsync (dotNetObject "System.Uri" dlUrl) destFile
    neoLog ("In-Max download started: " + dlName)
    true
)

-- true when 3ds Max is running elevated (needed for a few protected system folders)
global neoIsAdmin
fn neoIsAdmin = (
    local isAdm = false
    try(
        local ident = (dotNetClass "System.Security.Principal.WindowsIdentity").GetCurrent()
        local principal = dotNetObject "System.Security.Principal.WindowsPrincipal" ident
        isAdm = principal.IsInRole ((dotNetClass "System.Security.Principal.WindowsBuiltInRole").Administrator)
    )catch()
    isAdm
)

-- ---------- Script Manager: install pipeline scripts from a GitHub manifest ----------
-- Manifest = a plain text file (raw GitHub URL), one entry per line:
--    Name | type | direct-download-url
-- types: macro (usermacros) | startup (auto-runs with Max) | script (userscripts)
--        mzp / zip (packages) | plugin (.dlm/.dlt/... -> user plugin folder)
--        installer (.exe/.msi: downloaded by curl in its own console window so Max does not
--                   freeze on multi-GB files; pressing Install again launches the setup.
--                   Use Google Drive links - GitHub caps files at 100 MB)
--        chaoslicense (vrlclient.xml -> C:\ProgramData\Chaos Group\vrlclient, old one backed up)
-- Scripts and plugins install into USER folders - no administrator rights needed.
global neoScriptManifest = #()

-- scripts that ship with NeoCapture out of the box (user's GitHub collection)
global neoBuiltInScripts = #(
    #("Auto Light v1.38", "mzp", "https://raw.githubusercontent.com/Mahmoudragheb/3ds-max-Scripts/main/Auto.Light.v.1.38.-2016-2024-iTooHelper.mzp"),
    #("Camera Converter v1.26", "mzp", "https://raw.githubusercontent.com/Mahmoudragheb/3ds-max-Scripts/main/Camera.Converter.v1.26-2016-2025-iTooHelper.mzp"),
    #("Floor Generator (Max 2026)", "plugin", "https://raw.githubusercontent.com/Mahmoudragheb/3ds-max-Scripts/main/FloorGenerator_max2026_64bit.dlm"),
    #("MultiTexture v2.04 (Max 2026)", "plugin", "https://raw.githubusercontent.com/Mahmoudragheb/3ds-max-Scripts/main/MultiTexture_max2026_ver2.04_64bit.dlt"),
    #("Prune Scene", "mzp", "https://raw.githubusercontent.com/Mahmoudragheb/3ds-max-Scripts/main/PruneScene.mzp"),
    #("Relink Bitmaps v2.17", "mzp", "https://raw.githubusercontent.com/Mahmoudragheb/3ds-max-Scripts/main/Relink%20Bitmaps%20v2.17.mzp"),
    #("Smart Camera View v3.99", "mzp", "https://raw.githubusercontent.com/Mahmoudragheb/3ds-max-Scripts/main/Smart.Camera.View.v3.99-2016-2025-iTooHelper.mzp"),
    #("Dappled Light Generator v1.0", "mzp", "https://raw.githubusercontent.com/Mahmoudragheb/3ds-max-Scripts/main/Dappled%20Light%20Generator%20v1.0.mzp"),
    #("QuickAttach v1.82", "macro", "https://raw.githubusercontent.com/Mahmoudragheb/3ds-max-Scripts/main/quickattach_v1.82.mcr"),
    #("Move To Surface v2", "macro", "https://raw.githubusercontent.com/Mahmoudragheb/3ds-max-Scripts/main/MoveToSurface_v2.mcr"),
    #("Make it Instance", "script", "https://raw.githubusercontent.com/Mahmoudragheb/3ds-max-Scripts/main/Make%20it%20Instance.ms")
)

global neoFetchScriptManifest
fn neoFetchScriptManifest url = (
    local txt = ""
    try(
        local wc = dotNetObject "System.Net.WebClient"
        wc.Headers.Add "User-Agent" "Mozilla/5.0"
        try((dotNetClass "System.Net.ServicePointManager").SecurityProtocol = (dotNetClass "System.Net.SecurityProtocolType").Tls12)catch()
        txt = wc.DownloadString url
    )catch()
    if txt == "" then false
    else (
        local fetched = #()
        for line in (filterString txt "\n\r") do (
            local trimmed = trimLeft (trimRight line)
            if trimmed.count > 0 and trimmed[1] != "#" do (
                local parts = filterString trimmed "|"
                if parts.count >= 3 do (
                    append fetched #(trimLeft (trimRight parts[1]), toLower (trimLeft (trimRight parts[2])), trimLeft (trimRight parts[3]))
                )
            )
        )
        -- manifest entries win; built-ins fill in only names the manifest does not have
        neoScriptManifest = fetched
        for b in neoBuiltInScripts do (
            local dup = false
            for f in fetched where (toLower f[1]) == (toLower b[1]) do dup = true
            if not dup do append neoScriptManifest b
        )
        neoLog ("Script manifest fetched: " + neoScriptManifest.count as string + " entries")
        true
    )
)

-- Google Drive share links return an HTML page, not the file - convert them
-- to their direct-download form so the installer can fetch the real file
global neoDirectDownloadURL
fn neoDirectDownloadURL url = (
    local u = url
    local fid = ""
    local marker = "drive.google.com/file/d/"
    local p = findString u marker
    if p != undefined then (
        local rest = substring u (p + marker.count) u.count
        local cutP = findString rest "/"
        fid = if cutP != undefined then substring rest 1 (cutP - 1) else rest
    ) else (
        marker = "drive.google.com/open?id="
        p = findString u marker
        if p != undefined do fid = substring u (p + marker.count) u.count
    )
    if fid != "" do (
        local qP = findString fid "?"
        if qP != undefined do fid = substring fid 1 (qP - 1)
        -- confirm=t skips the "can't scan for viruses" page that large files trigger
        u = "https://drive.usercontent.google.com/download?id=" + fid + "&export=download&confirm=t"
    )
    u
)

-- User-level plugin folder (no admin rights): created once and registered as an
-- additional plugin path in Plugin.UserSettings.ini so Max loads it on every start
global neoEnsureUserPluginDir
fn neoEnsureUserPluginDir = (
    local pdir = (getDir #maxData) + "\\NeoPlugins"
    makeDir pdir all:true
    try(
        local iniFile = (getDir #maxData) + "\\Plugin.UserSettings.ini"
        local existing = getINISetting iniFile "Directories" "NeoCapture Plugins"
        if existing != pdir do (
            setINISetting iniFile "Directories" "NeoCapture Plugins" pdir
            neoLog ("User plugin folder registered: " + pdir)
        )
    )catch()
    pdir
)

global neoInstallScript
fn neoInstallScript entry = (
    local nm = entry[1]; local typ = entry[2]; local url = entry[3]
    local dlUrl = neoDirectDownloadURL url
    local ext = toLower (getFilenameType url)
    -- links without a real file extension (e.g. Google Drive) take it from the declared type
    local knownExts = #(".mcr", ".ms", ".mzp", ".zip", ".dlm", ".dlt", ".dlr", ".dlo", ".dlu", ".exe", ".msi")
    if (findItem knownExts ext) == 0 do (
        ext = case typ of (
            "macro": ".mcr"
            "mzp": ".mzp"
            "zip": ".zip"
            "plugin": ".dlr"
            "installer": ".exe"
            default: ".ms"
        )
    )
    -- compiled plugins (.dlm/.dlt/.dlr/.dlo/.dlu) go to the user plugin folder
    local pluginExts = #(".dlm", ".dlt", ".dlr", ".dlo", ".dlu")
    local isPlugin = ((findItem pluginExts ext) != 0) or (typ == "plugin")
    local destDir = case typ of (
        "macro": (getDir #userMacros)
        "startup": (getDir #userStartupScripts)
        default: (getDir #userScripts)
    )
    if isPlugin do destDir = neoEnsureUserPluginDir()
    -- installer packages always land in user scripts first, their own installer takes over from there
    if ext == ".mzp" or ext == ".zip" do destDir = (getDir #userScripts)
    -- application installers (V-Ray, Corona, Vantage...) are only downloaded, never run
    local isInstaller = (typ == "installer") or (ext == ".exe") or (ext == ".msi")
    if isInstaller do destDir = neoInstallerDir()
    -- Chaos license-server client config (vrlclient.xml): points this machine at the
    -- company license server. Goes to the shared Chaos config folder.
    local isLicCfg = (typ == "chaoslicense")
    if isLicCfg do (
        destDir = "C:\\ProgramData\\Chaos Group\\vrlclient"
        ext = ".xml"
    )
    makeDir destDir all:true
    -- decode url-encoded spaces so the saved file gets a clean name;
    -- links without a usable file name (e.g. Google Drive) fall back to the script name
    local destName = substituteString (filenameFromPath url) "%20" " "
    if not (matchPattern destName pattern:("*" + ext)) do destName = (neoSafeFileName nm) + ext
    -- the license client config must keep its exact expected file name
    if isLicCfg do destName = "vrlclient.xml"
    local destFile = destDir + "\\" + destName

    -- Application setups go through the in-Max async downloader (progress dialog, no freeze)
    if isInstaller do return (neoStartDownload nm url)

    -- smart permission check: a few system folders need Max to run elevated
    if isLicCfg do (
        local canWrite = false
        try(
            local testFile = destDir + "\\neo_write_test.tmp"
            local tsf = createFile testFile
            if tsf != undefined do ( close tsf; deleteFile testFile; canWrite = true )
        )catch()
        if not canWrite do (
            local admNote = if (neoIsAdmin()) then "The folder is locked by the system." else "Close 3ds Max, right-click its icon and choose 'Run as administrator', then install this item again."
            messageBox ("No permission to write to:\n" + destDir + "\n\n" + admNote) title:"NeoCapture - Permission needed"
            neoLog ("License config install blocked - no write access to " + destDir)
            return false
        )
    )

    -- never silently overwrite an existing license config - back it up first
    if isLicCfg and (doesFileExist destFile) do (
        try(
            local bak = destDir + "\\vrlclient_backup.xml"
            if doesFileExist bak do deleteFile bak
            copyFile destFile bak
            neoLog "Existing vrlclient.xml backed up to vrlclient_backup.xml"
        )catch()
    )
    local ok = false
    try(
        local wc = dotNetObject "System.Net.WebClient"
        wc.Headers.Add "User-Agent" "Mozilla/5.0"
        try((dotNetClass "System.Net.ServicePointManager").SecurityProtocol = (dotNetClass "System.Net.SecurityProtocolType").Tls12)catch()
        wc.DownloadFile dlUrl destFile
        if (doesFileExist destFile) and (getFileSize destFile) > 100 then ok = true
    )catch()
    -- if the server answered with a web page instead of the file, treat it as a failure
    -- (.exe/.msi are binary and can trip the text reader, so skip the check for them)
    if ok and not isInstaller do (
        try(
            local rf = openFile destFile mode:"r"
            local head = readChars rf 200 errorAtEOF:false
            close rf
            if (matchPattern head pattern:"*<!DOCTYPE*" ignoreCase:true) or (matchPattern head pattern:"*<html*" ignoreCase:true) do (
                ok = false
                try(deleteFile destFile)catch()
                neoLog ("Download returned a web page, not a file (link is not direct): " + nm)
            )
        )catch()
    )
    if ok then (
        if ext == ".zip" then (
            -- unpack next to the user scripts so the user can run the content
            try(
                dotNet.loadAssembly "System.IO.Compression.FileSystem"
                local unzipDir = (getDir #userScripts) + "\\" + nm
                makeDir unzipDir all:true
                (dotNetClass "System.IO.Compression.ZipFile").ExtractToDirectory destFile unzipDir
                neoLog ("Zip package extracted to " + unzipDir)
            )catch(neoLog ("Zip extract failed: " + getCurrentException()))
        )
        else if ext == ".mzp" then (
            -- run the package installer - it places its own files where they belong
            local mzpOk = false
            try(fileIn destFile; mzpOk = true)catch(neoLog ("MZP run failed: " + getCurrentException()))
            if not mzpOk do messageBox ("Downloaded to:\n" + destFile + "\n\nCould not auto-run the installer - drag and drop this file into the 3ds Max viewport once to finish installing.") title:"NeoCapture"
        )
        else if isLicCfg then (
            neoLog ("Chaos license client config installed: " + destFile)
            messageBox ("License server configuration installed:\n" + destFile + "\n\nRestart 3ds Max so the license client picks it up.") title:"NeoCapture"
        )
        else if isPlugin then (
            -- try to load the plugin right away; it will auto-load on every restart anyway
            try(loadDllsFromDir (destDir + "\\"))catch()
            neoLog ("Plugin installed to user plugin folder: " + destName)
        )
        else if typ == "macro" or typ == "startup" then try(fileIn destFile)catch()
        neoLog ("Script installed: " + nm + " -> " + destFile)
    ) else (
        try(deleteFile destFile)catch()
        neoLog ("Script install FAILED: " + nm + " (" + url + ")")
    )
    ok
)

global rltNeoScriptMgr
rollout rltNeoScriptMgr "NeoCapture - Script Manager" (
    label lblMgrTitle "Check the scripts you want, then press Install Checked:" align:#left
    dotNetControl lvScripts "System.Windows.Forms.CheckedListBox" width:540 height:140 align:#center
    button btnFetch "Update List" width:170 height:26 across:3 align:#left tooltip:"Reload the script list from the online source"
    button btnInstallSel "Install Checked" width:170 height:26 tooltip:"Download and install every checked script - no admin rights needed"
    button btnInstallAll "Install All" width:170 height:26 tooltip:"Download and install every script in the list"
    label lblMgrInfo "" align:#left offset:[0,4]

    fn manifestURL = (
        local saved = getINISetting neoCaptureSettingsFile "ScriptMgr" "ManifestURL"
        if saved != "" then saved else "https://raw.githubusercontent.com/Mahmoudragheb/3ds-max-Scripts/main/scripts_list.txt"
    )
    fn fillList = (
        try(
            lvScripts.Items.Clear()
            for e in neoScriptManifest do lvScripts.Items.Add (e[1] + "   [" + e[2] + "]") false
        )catch()
        lblMgrInfo.text = neoScriptManifest.count as string + " scripts available"
    )

    on rltNeoScriptMgr open do (
        try(
            lvScripts.CheckOnClick = true
            lvScripts.BackColor = (dotNetClass "System.Drawing.Color").fromArgb 45 45 48
            lvScripts.ForeColor = (dotNetClass "System.Drawing.Color").fromArgb 220 220 220
        )catch()
        if neoScriptManifest.count == 0 do neoScriptManifest = for e in neoBuiltInScripts collect e
        fillList()
    )
    on btnFetch pressed do (
        if (neoFetchScriptManifest (manifestURL())) then fillList()
        else messageBox "Could not update the list - check the internet connection.\n(The built-in list keeps working offline.)" title:"NeoCapture"
    )
    on btnInstallSel pressed do (
        local done = 0; local fails = 0; local noneChecked = true
        for i = 1 to neoScriptManifest.count do (
            local isChecked = false
            try(isChecked = lvScripts.GetItemChecked (i - 1))catch()
            if isChecked do (
                noneChecked = false
                if (neoInstallScript neoScriptManifest[i]) then done += 1 else fails += 1
            )
        )
        if noneChecked then messageBox "Check at least one script first." title:"NeoCapture"
        else (
            lblMgrInfo.text = done as string + " installed, " + fails as string + " failed"
            if done > 0 do messageBox (done as string + " script(s) installed - no administrator rights needed.") title:"NeoCapture"
        )
    )
    on btnInstallAll pressed do (
        local done = 0; local fails = 0
        for e in neoScriptManifest do ( if (neoInstallScript e) then done += 1 else fails += 1 )
        lblMgrInfo.text = done as string + " installed, " + fails as string + " failed"
    )
)

-- ---------- Tools rollout (general tools only - engine tools live in the main engine boxes) ----------
global rltNeoTools
rollout rltNeoTools "NeoCapture - Tools" (
    group "General" (
        button btnCheck "Scene Check" width:170 height:26 across:3 tooltip:"Check missing textures, foreign elements, overrides and more"
        button btnProxy "Selection to Proxy" width:170 height:26 tooltip:"Export selection as proxy (active engine)"
        button btnOpenLog "Open Log" width:170 height:26 tooltip:"Open the NeoCapture operations log"
    )
    group "This machine" (
        label lblSys1 "" align:#left
        label lblSys2 "" align:#left
        label lblSys3 "" align:#left
        button btnOpenProfile "Open Profile File" width:170 height:24 across:3 tooltip:"Open the machine profile that NeoCapture writes and keeps updated"
        button btnRescan "Rescan Machine" width:170 height:24 tooltip:"Read the machine again and update the profile file"
        button btnCheckUpd "Check for Update" width:170 height:24 tooltip:"Ask the online repository whether a newer NeoCapture exists"
    )

    fn profVal section key = (
        local v = ""
        try(v = getINISetting neoProfileFile section key)catch()
        if v == "" then "-" else v
    )
    fn refreshSysLabels = (
        lblSys1.text = "3ds Max " + (profVal "Max" "Year") + "   |   " + (profVal "System" "CPUCores") + " cores   |   " + (profVal "System" "RAM_GB") + " GB RAM   |   " + (profVal "System" "DiskFree_GB") + " GB free"
        lblSys2.text = "GPU: " + (profVal "System" "GPU")
        lblSys3.text = "V-Ray: " + (profVal "Renderers" "VRay") + "   |   Corona: " + (profVal "Renderers" "Corona") + "   |   Vantage: " + (profVal "Renderers" "Vantage")
    )

    on rltNeoTools open do refreshSysLabels()
    on btnCheck pressed do neoRunSceneCheck()
    on btnProxy pressed do neoExportProxy()
    on btnOpenLog pressed do ( if doesFileExist neoLogFile then shellLaunch neoLogFile "" else messageBox "Log is empty so far." title:"NeoCapture" )
    on btnOpenProfile pressed do ( if doesFileExist neoProfileFile then shellLaunch neoProfileFile "" else messageBox "The profile file has not been written yet." title:"NeoCapture" )
    on btnRescan pressed do (
        neoProfile = #()
        neoProbeMax(); neoProbeHardware(); neoProbeRenderers(); neoProbePlugins(); neoProbeScripts()
        local n = neoWriteProfile()
        refreshSysLabels()
        messageBox ("Machine rescanned.\n" + n as string + " value(s) changed since the last scan.") title:"NeoCapture"
    )
    on btnCheckUpd pressed do (
        neoCheckRepo()
        messageBox "Checking the repository in the background.\nYou will be told only if a newer version exists." title:"NeoCapture"
    )
)

-- ==================== END NEOCAPTURE EXTENSIONS ====================

-- ============================ [6c] MACHINE PROFILE, SPLASH AND SELF-UPDATE ============================
global neoScriptVersion = "2.0.0"
global neoRepoBase = "https://raw.githubusercontent.com/Mahmoudragheb/3ds-max-Scripts/main/"
global neoScriptPath = ""
try(neoScriptPath = getThisScriptFilename())catch()

global neoProfileFile = (getDir #userScripts) + "\\NeoCaptureProfile.ini"
global neoProfile = #()          -- #( #(section, key, value), ... )
global neoMaxYear = 0            -- e.g. 2026, used by the version-aware downloads

global neoProfAdd
fn neoProfAdd section key val = ( append neoProfile #(section, key, (val as string)) )

-- ---- individual probes, each isolated so one failure cannot stop the scan ----
global neoProbeMax
fn neoProbeMax = (
    try(
        local mv = maxVersion()
        neoMaxYear = mv[8]
        neoProfAdd "Max" "Year" neoMaxYear
        neoProfAdd "Max" "Build" (mv[1] as string)
        neoProfAdd "Max" "ProductName" (productAppID as string)
    )catch()
    try(neoProfAdd "Max" "InstallPath" (getDir #maxroot))catch()
)

global neoProbeHardware
fn neoProbeHardware = (
    try(neoProfAdd "System" "Computer" sysInfo.computername)catch()
    try(neoProfAdd "System" "User" sysInfo.username)catch()
    try(neoProfAdd "System" "CPUCores" sysInfo.cpucount)catch()
    try(neoProfAdd "System" "OS" ((dotNetClass "System.Environment").OSVersion.VersionString))catch()
    try(
        local mem = sysInfo.getSystemMemoryInfo()
        neoProfAdd "System" "RAM_GB" ((((mem[1] as float) / 1073741824.0) * 10) as integer / 10.0)
    )catch()
    try(
        local drv = dotNetObject "System.IO.DriveInfo" (substring (getDir #maxroot) 1 3)
        neoProfAdd "System" "DiskFree_GB" ((((drv.AvailableFreeSpace as float) / 1073741824.0)) as integer)
    )catch()
    -- GPU name through WMI; harmless if the query is unavailable
    try(
        dotNet.loadAssembly "System.Management"
        local searcher = dotNetObject "System.Management.ManagementObjectSearcher" "SELECT Name FROM Win32_VideoController"
        local en = (searcher.Get()).GetEnumerator()
        local gpus = ""
        while en.MoveNext() do (
            local n = (en.Current.Item "Name") as string
            gpus = if gpus == "" then n else (gpus + " | " + n)
        )
        if gpus != "" do neoProfAdd "System" "GPU" gpus
    )catch()
)

global neoProbeRenderers
fn neoProbeRenderers = (
    local vrayVer = "not installed"
    try(
        if (for c in RendererClass.classes where matchPattern (c as string) pattern:"*V_Ray*" collect c).count > 0 do (
            vrayVer = "installed"
            try(vrayVer = (vrayVersion())[1] as string)catch()
        )
    )catch()
    neoProfAdd "Renderers" "VRay" vrayVer

    local corVer = "not installed"
    try(
        if (for c in RendererClass.classes where matchPattern (c as string) pattern:"*Corona*" collect c).count > 0 do (
            corVer = "installed"
            try(corVer = CoronaRenderer.getVersionString())catch()
        )
    )catch()
    neoProfAdd "Renderers" "Corona" corVer

    local vantage = "not installed"
    try(
        for p in #("C:\\Program Files\\Chaos\\Vantage\\vantage.exe", "C:\\Program Files\\Chaos Group\\Vantage\\vantage.exe") while vantage == "not installed" do (
            if doesFileExist p do (
                vantage = "installed"
                try(vantage = ((dotNetClass "System.Diagnostics.FileVersionInfo").GetVersionInfo p).FileVersion as string)catch()
            )
        )
    )catch()
    neoProfAdd "Renderers" "Vantage" vantage
    try(neoProfAdd "Renderers" "Current" ((classOf renderers.current) as string))catch()
)

global neoProbePlugins
fn neoProbePlugins = (
    fn hasClass superCls pat = (
        local found = false
        try(found = ((for c in superCls.classes where matchPattern (c as string) pattern:pat collect c).count > 0))catch()
        if found then "installed" else "missing"
    )
    neoProfAdd "Plugins" "FloorGenerator" (hasClass geometry "*Floor*Generator*")
    neoProfAdd "Plugins" "MultiTexture" (hasClass textureMap "*MultiTexture*")
    neoProfAdd "Plugins" "Forest" (hasClass geometry "*Forest*")
    neoProfAdd "Plugins" "RailClone" (hasClass geometry "*RailClone*")
    neoProfAdd "Plugins" "ChaosScatter" (hasClass geometry "*Scatter*")
    neoProfAdd "Plugins" "PhoenixFD" (hasClass geometry "*Phoenix*")
)

global neoProbeScripts
fn neoProbeScripts = (
    local dirs = #((getDir #userMacros), (getDir #userScripts))
    fn anyFile pat dirList = (
        local found = false
        for d in dirList while not found do (
            try(if (getFiles (d + "\\" + pat)).count > 0 do found = true)catch()
        )
        if found then "installed" else "missing"
    )
    neoProfAdd "Scripts" "RelinkBitmaps" (anyFile "*elink*" dirs)
    neoProfAdd "Scripts" "PruneScene" (anyFile "*rune*cene*" dirs)
    neoProfAdd "Scripts" "AutoLight" (anyFile "*uto*ight*" dirs)
    neoProfAdd "Scripts" "CameraConverter" (anyFile "*amera*onverter*" dirs)
    neoProfAdd "Scripts" "SmartCameraView" (anyFile "*mart*amera*" dirs)
)

-- write the profile, reporting anything that changed since the last run
global neoWriteProfile
fn neoWriteProfile = (
    local changes = #()
    for e in neoProfile do (
        local old = ""
        try(old = getINISetting neoProfileFile e[1] e[2])catch()
        if old != e[3] do (
            if old != "" do append changes (e[2] + ": " + old + " -> " + e[3])
            try(setINISetting neoProfileFile e[1] e[2] e[3])catch()
        )
    )
    try(setINISetting neoProfileFile "Meta" "LastRun" (localTime as string))catch()
    try(setINISetting neoProfileFile "Meta" "ToolVersion" neoScriptVersion)catch()
    if changes.count > 0 do (
        neoLog ("Machine profile changed: " + (changes as string))
    )
    changes.count
)

-- ---------- self-update from the repo (fully async, never blocks Max) ----------
global neoUpdClient
global neoManClient

global neoApplyUpdate
fn neoApplyUpdate newVersion = (
    if neoScriptPath == "" or not (doesFileExist neoScriptPath) then (
        messageBox ("A newer NeoCapture is available (" + newVersion + ") but the script file path is unknown.\nRe-run the script from its .ms file to enable updating.") title:"NeoCapture"
        return false
    )
    local ok = false
    try(
        local bak = (getFilenamePath neoScriptPath) + (getFilenameFile neoScriptPath) + "_backup_" + neoScriptVersion + ".ms"
        if doesFileExist bak do deleteFile bak
        copyFile neoScriptPath bak
        local wc = dotNetObject "System.Net.WebClient"
        wc.Headers.Add "User-Agent" "Mozilla/5.0"
        try((dotNetClass "System.Net.ServicePointManager").SecurityProtocol = (dotNetClass "System.Net.SecurityProtocolType").Tls12)catch()
        local body = wc.DownloadString (neoRepoBase + "NeoCapture.ms")
        if body.count > 5000 and (matchPattern body pattern:"*NEOCAPTURE TOOL*" ignoreCase:true) do (
            local sf = createFile neoScriptPath
            format "%" body to:sf
            close sf
            ok = true
        )
    )catch()
    if ok then (
        neoLog ("Self-update applied: " + neoScriptVersion + " -> " + newVersion)
        if queryBox ("NeoCapture was updated to " + newVersion + ".\n(The old file was kept as a backup next to it.)\n\nReload it now?") title:"NeoCapture" do (
            try(fileIn neoScriptPath)catch()
        )
    ) else messageBox "The update could not be downloaded.\nThe current version keeps working." title:"NeoCapture"
    ok
)

global neoUpdCompleted
fn neoUpdCompleted s e = (
    try(
        local errored = false
        try(if e.Error != undefined do errored = true)catch()
        if errored do return()
        local remote = e.Result as string
        remote = trimRight remote " \n\r\t"
        remote = trimLeft remote " \n\r\t"
        if remote == "" or remote == neoScriptVersion do return()
        neoLog ("Update available: " + neoScriptVersion + " -> " + remote)
        if queryBox ("A newer NeoCapture is available.\n\nInstalled: " + neoScriptVersion + "\nAvailable: " + remote + "\n\nUpdate now?") title:"NeoCapture" do (
            neoApplyUpdate remote
        )
    )catch()
)

global neoManCompleted
fn neoManCompleted s e = (
    try(
        local errored = false
        try(if e.Error != undefined do errored = true)catch()
        if errored do return()
        local txt = e.Result as string
        local fetched = #()
        for line in (filterString txt "\n\r") do (
            local trimmed = trimLeft (trimRight line)
            if trimmed.count > 0 and trimmed[1] != "#" do (
                local parts = filterString trimmed "|"
                if parts.count >= 3 do append fetched #(trimLeft (trimRight parts[1]), toLower (trimLeft (trimRight parts[2])), trimLeft (trimRight parts[3]))
            )
        )
        if fetched.count > 0 do (
            neoScriptManifest = fetched
            for b in neoBuiltInScripts do (
                local dup = false
                for f in fetched where (toLower f[1]) == (toLower b[1]) do dup = true
                if not dup do append neoScriptManifest b
            )
            neoLog ("Script list refreshed from repo: " + neoScriptManifest.count as string + " entries")
        )
    )catch()
)

global neoCheckRepo
fn neoCheckRepo = (
    try(
        try((dotNetClass "System.Net.ServicePointManager").SecurityProtocol = (dotNetClass "System.Net.SecurityProtocolType").Tls12)catch()
        neoUpdClient = dotNetObject "System.Net.WebClient"
        try(dotNet.setLifetimeControl neoUpdClient #dotnet)catch()
        neoUpdClient.Headers.Add "User-Agent" "Mozilla/5.0"
        dotNet.addEventHandler neoUpdClient "DownloadStringCompleted" neoUpdCompleted
        neoUpdClient.DownloadStringAsync (dotNetObject "System.Uri" (neoRepoBase + "version.txt"))

        neoManClient = dotNetObject "System.Net.WebClient"
        try(dotNet.setLifetimeControl neoManClient #dotnet)catch()
        neoManClient.Headers.Add "User-Agent" "Mozilla/5.0"
        dotNet.addEventHandler neoManClient "DownloadStringCompleted" neoManCompleted
        neoManClient.DownloadStringAsync (dotNetObject "System.Uri" (neoRepoBase + "scripts_list.txt"))
    )catch(neoLog ("Repo check could not start: " + getCurrentException()))
)

-- ---------- splash screen shown while the machine is being profiled ----------
global rltNeoSplash
rollout rltNeoSplash "NeoCapture" width:420 height:150 (
    label lblTitle "NEO CAPTURE TOOL ULTIMATE" pos:[16,16] width:388 align:#center
    label lblVer "" pos:[16,36] width:388 align:#center
    progressbar prgSplash "" pos:[20,66] width:380 height:16 color:(color 45 135 165) value:0
    label lblStep "Starting..." pos:[20,92] width:380
    label lblHint "Reading machine, 3ds Max, renderers and installed tools" pos:[20,114] width:380

    on rltNeoSplash open do lblVer.text = "version " + neoScriptVersion
)

global neoSplashStep
fn neoSplashStep pct txt = (
    try(
        rltNeoSplash.prgSplash.value = pct
        rltNeoSplash.lblStep.text = txt
        windows.processPostedMessages()
    )catch()
)

global neoStartup
fn neoStartup = (
    try(destroyDialog rltNeoSplash)catch()
    createDialog rltNeoSplash style:#(#style_border, #style_sysmenu)
    neoProfile = #()

    neoSplashStep 10 "Reading 3ds Max version..."
    neoProbeMax()
    neoSplashStep 30 "Reading machine hardware..."
    neoProbeHardware()
    neoSplashStep 50 "Detecting render engines..."
    neoProbeRenderers()
    neoSplashStep 65 "Detecting plugins..."
    neoProbePlugins()
    neoSplashStep 78 "Detecting installed scripts..."
    neoProbeScripts()
    neoSplashStep 88 "Saving machine profile..."
    local changed = neoWriteProfile()
    neoSplashStep 95 "Checking the online repository..."
    neoCheckRepo()
    neoSplashStep 100 "Ready"

    try(destroyDialog rltNeoSplash)catch()
    neoLog ("Startup profile done for Max " + (neoMaxYear as string) + " - " + changed as string + " change(s)")
    launchNeoCaptureFloater()
)

-- ============================ [6b] SHARED STATE FOR THE TABBED UI ============================
-- With tabs, a rollout can be hidden while other code still needs its state, so the state
-- lives in globals and the controls only mirror it.
global neoTargetEngine = #vray   -- #vray | #corona : the engine this tool targets
global neoSelCamNames = #()      -- camera ticks survive tab switches (the list control is rebuilt)
global neoProPanel = #none       -- #none | #vray | #corona : which PRO settings floater is open
global neoElemPanel = #none      -- #none | #vray | #corona : which render elements floater is open

global neoIsVRayRnd
fn neoIsVRayRnd = matchPattern ((classOf renderers.current) as string) pattern:"*V_Ray*"
global neoIsCoronaRnd
fn neoIsCoronaRnd = matchPattern ((classOf renderers.current) as string) pattern:"*Corona*"

global neoSyncElements
fn neoSyncElements = (
    try(closeRolloutFloater neoElementsFloater) catch()
    if neoElemPanel != #none and neoCaptureFloater != undefined then (
        local mainPos = neoCaptureFloater.pos
        local elemX = mainPos.x - 420
        if elemX < 0 do elemX = 0
        local flTitle = if neoElemPanel == #vray then "Render Elements - V-Ray" else "Render Elements - Corona"
        global neoElementsFloater = newRolloutFloater flTitle 420 720 pos:[elemX, mainPos.y]
        try(neoElementsFloater.pos = [elemX, mainPos.y]) catch()
        local vrRollouts = #(rltVR_Denoiser, rltVR_ZDepth, rltVR_LightMix, rltVR_ColorID, rltVR_GI, rltVR_Lighting, rltVR_Reflection, rltVR_Refraction, rltVR_Shadows)
        local crRollouts = #(rltCR_Cryptomatte, rltCR_ZDepth, rltCR_LightMix, rltCR_ColorID, rltCR_Reflect, rltCR_Refract, rltCR_Shadows)
        local elemList = if neoElemPanel == #vray then vrRollouts else crRollouts
        for r in elemList do addRollout r neoElementsFloater rolledUp:false
    )
)

global neoSyncProUI
fn neoSyncProUI = (
    try(closeRolloutFloater neoSettingsFloater) catch()
    if neoProPanel != #none and neoCaptureFloater != undefined then (
        local mainPos = neoCaptureFloater.pos
        local settingsX = mainPos.x + 580
        local flTitle = if neoProPanel == #vray then "NeoCapture PRO Settings - V-Ray" else "NeoCapture PRO Settings - Corona"
        global neoSettingsFloater = newRolloutFloater flTitle 420 720 pos:[settingsX, mainPos.y]
        try(neoSettingsFloater.pos = [settingsX, mainPos.y]) catch()
        if neoProPanel == #vray then (
            addRollout rltVR_SettingsTabBar neoSettingsFloater
            showVRSettingsTab #vray
        ) else (
            addRollout rltCR_SettingsTabBar neoSettingsFloater
            showCRSettingsTab #main
        )
    )
)

-- switch the tool to an engine (asks to change the system renderer when it differs)
global neoSetTargetEngine
fn neoSetTargetEngine eng askUser:true = (
    local wantVR = (eng == #vray)
    local matches = if wantVR then (neoIsVRayRnd()) else (neoIsCoronaRnd())
    if not matches and askUser then (
        local engName = if wantVR then "V-Ray" else "Corona"
        if queryBox ("System renderer is not " + engName + ".\nDo you want to switch to " + engName + " now?") title:"Renderer Mismatch" then (
            local pat = if wantVR then "*V_Ray*" else "*Corona*"
            local rndClass = undefined
            for c in RendererClass.classes where matchPattern (c as string) pattern:pat do rndClass = c
            if rndClass != undefined then renderers.current = rndClass()
            else ( messageBox (engName + " plugin not found!") title:"Error"; return false )
        ) else return false
    )
    neoTargetEngine = eng
    -- close panels that belong to the other engine
    if neoProPanel != #none and neoProPanel != eng do ( neoProPanel = #none; neoSyncProUI() )
    if neoElemPanel != #none and neoElemPanel != eng do ( neoElemPanel = #none; neoSyncElements() )
    try(rltEngines.refreshEngineUI())catch()
    neoLog ("Target engine set to " + (eng as string))
    true
)

-- ============================ [7] MAIN UI: CAMERAS AND CAPTURE ============================
rollout CaptureToolUI "Cameras and Resolution" width:560 height:388 (

    fn fmtFloat val = ( local str = val as string; if matchPattern str pattern:"*.*" then str else (str + ".0") )
    fn fmtColor clr = ( "[" + ((clr.r as integer) as string) + ", " + ((clr.g as integer) as string) + ", " + ((clr.b as integer) as string) + "]" )
    fn fmtVec v = ( "[" + fmtFloat(v.x) + ", " + fmtFloat(v.y) + ", " + fmtFloat(v.z) + "]" )
    fn fmtStr str = ( "\"" + (substituteString str "\\" "\\\\") + "\"" )

    fn isEnglishOnly txt = (
        local ok = true
        for i = 1 to txt.count do ( if (bit.charAsInt txt[i]) > 127 then ok = false )
        ok
    )

    fn translateProjectName txt = (
        local translated = undefined
        try (
            local wc = dotNetObject "System.Net.WebClient"
            wc.Headers.Add "User-Agent" "Mozilla/5.0"
            local encoded = (dotNetClass "System.Uri").EscapeDataString txt
            local url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=en&dt=t&q=" + encoded
            local response = wc.DownloadString url
            local q1 = findString response "\""
            local rest = substring response (q1 + 1) (response.count - q1)
            local q2 = findString rest "\""
            if q1 != undefined and q2 != undefined then translated = substring rest 1 (q2 - 1)
        ) catch ( translated = undefined )
        translated
    )

    fn sanitizeFileName txt = (
        local badChars = "\\/:*?\"<>|"
        local result = txt
        for i = 1 to badChars.count do ( result = substituteString result (badChars[i] as string) "" )
        result
    )

    fn getExportBaseName = (
        local rawName = getFilenameFile maxFileName
        if rawName == undefined or rawName == "" then rawName = "Untitled"
        local finalName = sanitizeFileName rawName
        if not (isEnglishOnly rawName) then (
            local t = translateProjectName rawName
            finalName = if t != undefined and t != "" then sanitizeFileName t else "The X Files"
        )
        local isCoronaEngine = matchPattern (classOf renderers.current as string) pattern:"*Corona*"
        local engineSuffix = if isCoronaEngine then "Corona" else "VRay"
        finalName + "_" + engineSuffix
    )

    fn extractAllCameras = (
        local cJson = "  \"cameras\": [\n"
        local camList = for c in cameras where ((classOf c == Physical_Camera) or matchPattern (classOf c as string) pattern:"*VRay*Cam*") collect c
        for i = 1 to camList.count do (
            local cam = camList[i]
            local fovVal = if isProperty cam #fov then cam.fov else 45.0
            local flVal = if isProperty cam #focal_length_mm then cam.focal_length_mm else (if isProperty cam #focal_length then cam.focal_length else 35.0)
            local tgPos = if cam.target != undefined then fmtVec(cam.target.pos) else "[0.0, 0.0, 0.0]"
            local resW = renderWidth; local resH = renderHeight
            if (isProperty cam #override_resolution) and cam.override_resolution == true do ( resW = cam.override_width; resH = cam.override_height )
            
            local camStr = ""
            camStr += "    {\n      \"name\": " + fmtStr(cam.name) + ",\n"
            camStr += "      \"fov\": " + fmtFloat(fovVal) + ",\n"
            camStr += "      \"focal_length\": " + fmtFloat(flVal) + ",\n"
            camStr += "      \"position\": " + fmtVec(cam.pos) + ",\n"
            camStr += "      \"target\": " + tgPos + ",\n"
            camStr += "      \"resolution\": [" + (resW as string) + ", " + (resH as string) + "]\n    }"
            if i < camList.count then camStr += ","
            cJson += camStr + "\n"
        )
        cJson += "  ]"
        cJson
    )

    fn extractLights = (
        local lJson = "  \"lights\": [\n"
        local suns = for l in lights where matchPattern (classOf l as string) pattern:"*Sun*" collect l
        for i = 1 to suns.count do (
            local s = suns[i]
            local intens = if isProperty s #intensity_multiplier then s.intensity_multiplier else 1.0
            local filterClr = if isProperty s #color then s.color else (color 255 255 255)
            lJson += "    {\n      \"name\": " + fmtStr(s.name) + ",\n      \"type\": " + fmtStr(classOf s as string) + ",\n"
            lJson += "      \"intensity\": " + fmtFloat(intens) + ",\n      \"color\": " + fmtColor(filterClr) + ",\n      \"position\": " + fmtVec(s.pos) + "\n    }"
            if i < suns.count then lJson += ",\n" else lJson += "\n"
        )
        lJson += "  ]"
        lJson
    )

    fn boolStr b = ( if b then "true" else "false" )

    fn buildAiDescription glossiness fresnelIor isMetal roughness hasOpacity selfIllum = (
        local tags = #()
        if glossiness > 0.85 and fresnelIor > 1.3 then append tags "polished, highly reflective"
        if fresnelIor > 1.4 and hasOpacity then append tags "transparent glass"
        if roughness > 0.5 then append tags "rough textured surface"
        if isMetal > 0.5 then append tags "metallic surface"
        if selfIllum > 0.0 then append tags "emissive glowing material"
        local desc = ""
        for i = 1 to tags.count do ( desc += tags[i]; if i < tags.count then desc += ", " )
        desc
    )

    fn extractMaterials = (
        local mJson = "  \"materials\": [\n"
        local supportedClasses = #("VRayMtl", "CoronaMtl", "CoronaLegacyMtl", "CoronaPhysicalMtl")
        local uniqueMtls = #()
        for obj in geometry where obj.material != undefined do (
            local m = obj.material
            if findItem supportedClasses (classof m as string) > 0 then (
                local idx = findItem uniqueMtls m
                if idx == 0 then append uniqueMtls m
            )
        )
        for i = 1 to uniqueMtls.count do (
            local m = uniqueMtls[i]
            local mClass = classof m as string
            local appliedNodes = for op in refs.dependents m where isValidNode op collect op.name
            local appliedStr = "["
            for k=1 to appliedNodes.count do ( appliedStr += fmtStr(appliedNodes[k]); if k < appliedNodes.count then appliedStr += ", " )
            appliedStr += "]"
            local wColor = color 128 128 128
            for d in refs.dependents m where isValidNode d do (wColor = d.wirecolor; exit)

            local diffClr = color 128 128 128
            local refGlos = 1.0
            local isFresnel = true
            local iorVal = 1.6
            local isMetal = 0.0
            local rough = 0.0
            local refrIor = 1.0
            local refrGlos = 1.0
            local hasBump = false
            local hasOpacity = false
            local selfIllum = 0.0
            local coatAmt = 0.0
            local coatGlos = 1.0
            local sheenAmt = 0.0
            local sheenGlos = 1.0
            local aniso = 0.0

            if mClass == "VRayMtl" then (
                try(if isProperty m #diffuse then diffClr = m.diffuse)catch()
                try(if isProperty m #reflection_glossiness then refGlos = m.reflection_glossiness as float)catch()
                try(if isProperty m #reflection_fresnel then isFresnel = m.reflection_fresnel)catch()
                try(if isProperty m #reflection_ior then iorVal = m.reflection_ior as float)catch()
                try(if isProperty m #reflection_metalness then isMetal = m.reflection_metalness as float)catch()
                try(if isProperty m #reflection_roughness then rough = m.reflection_roughness as float)catch()
                try(if isProperty m #refraction_ior then refrIor = m.refraction_ior as float)catch()
                try(if isProperty m #refraction_glossiness then refrGlos = m.refraction_glossiness as float)catch()
                try(if isProperty m #texmap_bump then hasBump = (m.texmap_bump != undefined))catch()
                try(if isProperty m #texmap_opacity then hasOpacity = (m.texmap_opacity != undefined))catch()
                try(if isProperty m #self_illumination then selfIllum = (m.self_illumination as float))catch()
                try(if isProperty m #coat_amount then coatAmt = m.coat_amount as float)catch()
                try(if isProperty m #coat_glossiness then coatGlos = m.coat_glossiness as float)catch()
                try(if isProperty m #sheen_amount then sheenAmt = m.sheen_amount as float)catch()
                try(if isProperty m #sheen_glossiness then sheenGlos = m.sheen_glossiness as float)catch()
                try(if isProperty m #anisotropy then aniso = m.anisotropy as float)catch()
            ) else if mClass == "CoronaPhysicalMtl" then (
                try(if isProperty m #baseColor then diffClr = m.baseColor)catch()
                try(if isProperty m #roughness then rough = m.roughness as float)catch()
                refGlos = 1.0 - rough
                try(if isProperty m #IOR then ( iorVal = m.IOR as float; refrIor = m.IOR as float ))catch()
                try(if isProperty m #metalness then isMetal = m.metalness as float)catch()
                try(if isProperty m #refractionAmount then refrGlos = m.refractionAmount as float)catch()
                try(if isProperty m #opacityMap then hasOpacity = (m.opacityMap != undefined))catch()
                try(if isProperty m #bumpMap then hasBump = (m.bumpMap != undefined))catch()
                try(if isProperty m #emissionMultiplier then selfIllum = m.emissionMultiplier as float)catch()
                try(if isProperty m #clearcoatAmount then coatAmt = m.clearcoatAmount as float)catch()
                try(if isProperty m #clearcoatRoughness then coatGlos = 1.0 - (m.clearcoatRoughness as float))catch()
                try(if isProperty m #sheenAmount then sheenAmt = m.sheenAmount as float)catch()
                try(if isProperty m #sheenRoughness then sheenGlos = 1.0 - (m.sheenRoughness as float))catch()
                try(if isProperty m #anisotropy then aniso = m.anisotropy as float)catch()
            ) else (
                try(if isProperty m #colorDiffuse then diffClr = m.colorDiffuse)catch()
                try(
                    if isProperty m #reflectGlossiness then refGlos = m.reflectGlossiness as float
                    else if isProperty m #levelReflection then refGlos = m.levelReflection as float
                )catch()
                try(if isProperty m #fresnelIOR then iorVal = m.fresnelIOR as float)catch()
                try(if isProperty m #levelRefraction then refrGlos = m.levelRefraction as float)catch()
                try(if isProperty m #refractionIOR then refrIor = m.refractionIOR as float)catch()
                try(if isProperty m #texmapOpacity then hasOpacity = (m.texmapOpacity != undefined))catch()
                try(if isProperty m #bumpMap then hasBump = (m.bumpMap != undefined))catch()
                try(if isProperty m #levelSelfIllum then selfIllum = m.levelSelfIllum as float)catch()
            )

            local aiDesc = buildAiDescription refGlos iorVal isMetal rough hasOpacity selfIllum

            mJson += "    {\n      \"id\": " + (i as string) + ",\n      \"name\": " + fmtStr(m.name) + ",\n      \"class\": " + fmtStr(mClass) + ",\n"
            mJson += "      \"applied_to\": " + appliedStr + ",\n      \"wire_color_rgb\": " + fmtColor(wColor) + ",\n"
            mJson += "      \"diffuse\": {\"color\": " + fmtColor(diffClr) + "},\n"
            mJson += "      \"reflection\": {\"glossiness\": " + fmtFloat(refGlos) + ", \"fresnel\": " + boolStr(isFresnel) + ", \"fresnel_ior\": " + fmtFloat(iorVal) + "},\n"
            mJson += "      \"refraction\": {\"ior\": " + fmtFloat(refrIor) + ", \"glossiness\": " + fmtFloat(refrGlos) + "},\n"
            mJson += "      \"metalness\": " + fmtFloat(isMetal) + ",\n      \"roughness\": " + fmtFloat(rough) + ",\n"
            mJson += "      \"coat\": {\"amount\": " + fmtFloat(coatAmt) + ", \"glossiness\": " + fmtFloat(coatGlos) + "},\n"
            mJson += "      \"sheen\": {\"amount\": " + fmtFloat(sheenAmt) + ", \"glossiness\": " + fmtFloat(sheenGlos) + "},\n"
            mJson += "      \"anisotropy\": " + fmtFloat(aniso) + ",\n"
            mJson += "      \"has_bump_map\": " + boolStr(hasBump) + ",\n      \"has_opacity_map\": " + boolStr(hasOpacity) + ",\n"
            mJson += "      \"self_illumination\": " + fmtFloat(selfIllum) + ",\n      \"description_for_ai\": " + fmtStr(aiDesc) + "\n    }"
            if i < uniqueMtls.count then mJson += ",\n" else mJson += "\n"
        )
        mJson += "  ]"
        mJson
    )

    fn buildSceneJSON = (
        local maxVer = ((maxVersion())[1]/1000) + 1998
        local scnName = maxFileName
        if scnName == "" then scnName = "Untitled"
        local isCoronaEngine = matchPattern (classOf renderers.current as string) pattern:"*Corona*"
        local engineName = if isCoronaEngine then "corona" else "vray"
        local jStr = "{\n  \"scene\": {\n    \"name\": " + fmtStr(scnName) + ",\n    \"render_engine\": " + fmtStr(engineName) + ",\n"
        jStr += "    \"max_version\": " + fmtStr(maxVer as string) + ",\n    \"export_date\": " + fmtStr(localTime) + ",\n"
        jStr += "    \"units\": " + fmtStr(units.SystemType as string) + "\n  },\n"
        jStr += extractAllCameras() + ",\n" + extractMaterials() + ",\n" + extractLights() + "\n}"
        jStr
    )

    groupBox grpCams "Cameras" pos:[8,8] width:544 height:272
    edittext edtSearch "" pos:[16,28] width:396 height:20 text:""

    dotNetControl lvCams "System.Windows.Forms.CheckedListBox" pos:[16,54] width:396 height:216
    
    button btnCreateCam "Create Cam" pos:[424,28] width:118 height:22 tooltip:"Create Physical Camera from View"
    button btnRefresh "Refresh" pos:[424,52] width:118 height:22 tooltip:"Refresh Camera List"
    button btnSelAll "Select All" pos:[424,76] width:118 height:22 tooltip:"Select All Cameras"
    button btnSelNone "Deselect All" pos:[424,100] width:118 height:22 tooltip:"Deselect All Cameras"

    button btnSortName "Sort A-Z" pos:[424,124] width:57 height:22 tooltip:"Sort cameras alphabetically"
    button btnSortRes "Sort Res" pos:[485,124] width:57 height:22 tooltip:"Sort cameras by resolution"
    button btnGoCam "Go to Cam" pos:[424,148] width:118 height:22 tooltip:"Set active viewport to selected camera"

    label lblResW "Width:" pos:[424,174] width:38 height:16
    spinner spnResW "" pos:[462,172] width:80 height:16 type:#integer range:[10,20000,1920]
    
    label lblResH "Height:" pos:[424,196] width:38 height:16
    spinner spnResH "" pos:[462,194] width:80 height:16 type:#integer range:[10,20000,1080]
    
    checkbutton chkLock "Lock" pos:[424,216] width:57 height:22 highlightColor:(color 220 160 40) checked:true tooltip:"Lock Aspect Ratio"
    button btnSetRes "Apply" pos:[485,216] width:57 height:22 tooltip:"Apply Resolution to Camera"
    
    dotNetControl btnPreviewCam "System.Windows.Forms.Button" pos:[424,242] width:118 height:30

    groupBox grpResCards "Quick Resolutions (Max 2K Range)" pos:[8, 298] width:544 height:80
    button btnL1 "HD 720" pos:[16,318] width:62 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"
    button btnL2 "FHD 1080" pos:[82,318] width:62 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"
    button btnL3 "2K QHD" pos:[148,318] width:62 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"
    button btnL4 "Film 2K" pos:[214,318] width:62 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"
    button btnL5 "UW 2K" pos:[280,318] width:62 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"
    button btnL6 "IG Land" pos:[346,318] width:62 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"
    button btnL7 "4:3 PC" pos:[412,318] width:62 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"
    button btnL8 "1:1 SQ" pos:[478,318] width:66 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"

    button btnP1 "IG 4:5" pos:[16,346] width:62 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"
    button btnP2 "IG Story" pos:[82,346] width:62 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"
    button btnP3 "2K Vert" pos:[148,346] width:62 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"
    button btnP4 "3:4 Vert" pos:[214,346] width:62 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"
    button btnP5 "A4 Draft" pos:[280,346] width:62 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"
    button btnP6 "Tablet" pos:[346,346] width:62 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"
    button btnP7 "Film Vert" pos:[412,346] width:62 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"
    button btnP8 "2K SQ" pos:[478,346] width:66 height:22 tooltip:"Apply this resolution - right-click to customize its label and size"

    local camArray = #()
    local camArrayFiltered = #()
    local qualityValues = #(0.1, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5)
    local currentRatio = 1920.0 / 1080.0

    fn getIsVray = neoIsVRayRnd()
    fn getIsCorona = neoIsCoronaRnd()

    fn getCamRes cam = (
        local w = renderWidth; local h = renderHeight
        if (isProperty cam #override_resolution) and cam.override_resolution == true then (w = cam.override_width; h = cam.override_height)
        #(w, h)
    )

    fn buildCamList cams = (
        lvCams.items.clear()
        for cam in cams do (
            local res = getCamRes cam
            local tag = if (isProperty cam #override_resolution) and cam.override_resolution == true then " *" else ""
            lvCams.items.add (cam.name + "  [" + res[1] as string + "x" + res[2] as string + "]" + tag)
        )
        -- restore the ticks the user had before the tab was switched away
        for i = 0 to cams.count - 1 do (
            if (findItem neoSelCamNames cams[i+1].name) != 0 do try(lvCams.setItemChecked i true)catch()
        )
    )

    -- called by the tab switcher just before this rollout is removed
    fn storeSelection = (
        try(
            local names = #()
            for i = 0 to lvCams.items.count - 1 do if lvCams.getItemChecked i do append names camArrayFiltered[i+1].name
            neoSelCamNames = names
        )catch()
    )

    fn refreshCams = (
        try(neoCleanCameraNames())catch()
        camArray = for obj in objects where superClassOf obj == camera collect obj
        local searchTxt = edtSearch.text
        camArrayFiltered = if searchTxt == "" then camArray else (
            for cam in camArray where (findString (toLower cam.name) (toLower searchTxt)) != undefined collect cam
        )
        buildCamList camArrayFiltered
    )

    fn getSelectedCams = (
        local result = #()
        for i = 0 to lvCams.items.count - 1 do if lvCams.getItemChecked i then append result camArrayFiltered[i+1]
        result
    )

    fn applyPreset w h = (
        spnResW.value = w; spnResH.value = h
        if chkLock.state then currentRatio = w as float / h
    )

    on spnResW changed val do ( if chkLock.state then spnResH.value = (val / currentRatio) as integer else currentRatio = val as float / spnResH.value )
    on spnResH changed val do ( if chkLock.state then spnResW.value = (val * currentRatio) as integer else currentRatio = spnResW.value as float / val )
    on chkLock changed state do ( if state then currentRatio = spnResW.value as float / spnResH.value )

    -- quick-resolution slots: left-click applies, right-click edits (label + size, saved to INI)
    fn applyResSlotCaptions = (
        local btns = #(btnL1,btnL2,btnL3,btnL4,btnL5,btnL6,btnL7,btnL8,btnP1,btnP2,btnP3,btnP4,btnP5,btnP6,btnP7,btnP8)
        for i = 1 to 16 do try(btns[i].text = neoResSlots[i][1])catch()
    )
    fn applyResSlot i = ( if neoResSlots[i] != undefined do applyPreset neoResSlots[i][2] neoResSlots[i][3] )
    fn editResSlot i = (
        neoResEditIdx = i
        try(destroyDialog rltNeoResEdit)catch()
        createDialog rltNeoResEdit
    )

    on btnL1 pressed do applyResSlot 1
    on btnL2 pressed do applyResSlot 2
    on btnL3 pressed do applyResSlot 3
    on btnL4 pressed do applyResSlot 4
    on btnL5 pressed do applyResSlot 5
    on btnL6 pressed do applyResSlot 6
    on btnL7 pressed do applyResSlot 7
    on btnL8 pressed do applyResSlot 8
    on btnP1 pressed do applyResSlot 9
    on btnP2 pressed do applyResSlot 10
    on btnP3 pressed do applyResSlot 11
    on btnP4 pressed do applyResSlot 12
    on btnP5 pressed do applyResSlot 13
    on btnP6 pressed do applyResSlot 14
    on btnP7 pressed do applyResSlot 15
    on btnP8 pressed do applyResSlot 16

    on btnL1 rightclick do editResSlot 1
    on btnL2 rightclick do editResSlot 2
    on btnL3 rightclick do editResSlot 3
    on btnL4 rightclick do editResSlot 4
    on btnL5 rightclick do editResSlot 5
    on btnL6 rightclick do editResSlot 6
    on btnL7 rightclick do editResSlot 7
    on btnL8 rightclick do editResSlot 8
    on btnP1 rightclick do editResSlot 9
    on btnP2 rightclick do editResSlot 10
    on btnP3 rightclick do editResSlot 11
    on btnP4 rightclick do editResSlot 12
    on btnP5 rightclick do editResSlot 13
    on btnP6 rightclick do editResSlot 14
    on btnP7 rightclick do editResSlot 15
    on btnP8 rightclick do editResSlot 16

    on CaptureToolUI open do (
        lvCams.checkOnClick = true
        lvCams.backColor = (dotNetClass "System.Drawing.Color").fromArgb 45 45 48
        lvCams.foreColor = (dotNetClass "System.Drawing.Color").fromArgb 220 220 220
        try(
            btnPreviewCam.Text = "PREVIEW CAMERA"
            btnPreviewCam.BackColor = (dotNetClass "System.Drawing.Color").fromArgb 45 135 165
            btnPreviewCam.ForeColor = (dotNetClass "System.Drawing.Color").fromArgb 245 245 245
            btnPreviewCam.FlatStyle = btnPreviewCam.FlatStyle.Flat
            btnPreviewCam.FlatAppearance.BorderColor = (dotNetClass "System.Drawing.Color").fromArgb 30 100 125
        )catch()
        neoLoadResSlots()
        applyResSlotCaptions()
        refreshCams()
    )

    on edtSearch changed txt do refreshCams()
    on btnRefresh pressed do (refreshCams(); CaptureToolBottom.lblStatus.text = "Refreshed: " + camArray.count as string + " cameras found.")
    on btnSelAll pressed do for i = 0 to lvCams.items.count - 1 do lvCams.setItemChecked i true
    on btnSelNone pressed do for i = 0 to lvCams.items.count - 1 do lvCams.setItemChecked i false

    on btnSortName pressed do (
        local sorted = #(); local indices = #(); local names = for cam in camArrayFiltered collect cam.name
        for i = 1 to names.count do append indices i
        for i = 1 to indices.count - 1 do for j = i + 1 to indices.count do if names[indices[i]] > names[indices[j]] then (local tmp = indices[i]; indices[i] = indices[j]; indices[j] = tmp)
        for i in indices do append sorted camArrayFiltered[i]
        camArrayFiltered = sorted; buildCamList camArrayFiltered; CaptureToolBottom.lblStatus.text = "Sorted A-Z"
    )

    on btnSortRes pressed do (
        local sorted = #(); local indices = #(); local widths = for cam in camArrayFiltered collect (getCamRes cam)[1]
        for i = 1 to widths.count do append indices i
        for i = 1 to indices.count - 1 do for j = i + 1 to indices.count do if widths[indices[i]] > widths[indices[j]] then (local tmp = indices[i]; indices[i] = indices[j]; indices[j] = tmp)
        for i in indices do append sorted camArrayFiltered[i]
        camArrayFiltered = sorted; buildCamList camArrayFiltered; CaptureToolBottom.lblStatus.text = "Sorted by Resolution"
    )

    on btnGoCam pressed do (
        local selectedCams = getSelectedCams()
        if selectedCams.count == 0 then (messageBox "Select a camera first." title:"Warning"; return false)
        viewport.setCamera selectedCams[1]; CaptureToolBottom.lblStatus.text = "Viewing: " + selectedCams[1].name
    )

    on btnPreviewCam Click arg do (
        local selectedCams = getSelectedCams()
        if selectedCams.count == 0 then (messageBox "Select a camera first." title:"Warning"; return false)
        if selectedCams.count > 1 then (messageBox "Select only ONE camera for the preview." title:"NeoCapture"; return false)
        neoPreviewCamera selectedCams[1]
    )

    on btnCreateCam pressed do (
        try ( macros.run "Lights and Cameras" "PhysicalCamera_CreateFromView"; refreshCams(); CaptureToolBottom.lblStatus.text = "Camera Created!" ) catch()
    )

    on lvCams SelectedIndexChanged arg do (
        local idx = lvCams.selectedIndex
        if idx >= 0 then ( local res = getCamRes camArrayFiltered[idx+1]; spnResW.value = res[1]; spnResH.value = res[2]; if chkLock.state then currentRatio = spnResW.value as float / spnResH.value )
    )

    on btnSetRes pressed do (
        local idx = lvCams.selectedIndex
        if idx < 0 then (messageBox "Select a camera first." title:"Warning"; return false)
        local cam = camArrayFiltered[idx+1]
        if (isProperty cam #override_resolution) and cam.override_resolution == true then (
            if (queryBox ("Camera already overridden. Override anyway?") title:"Warning") then (cam.override_width = spnResW.value; cam.override_height = spnResH.value)
        ) else ( cam.override_resolution = true; cam.override_width = spnResW.value; cam.override_height = spnResH.value )
        refreshCams(); CaptureToolBottom.lblStatus.text = "Resolution updated."
    )

    on CaptureToolUI close do (
        try(closeRolloutFloater neoSettingsFloater) catch()
    )
)

-- ============================ [7b] RENDER ENGINES PANEL (its own tab) ============================
global rltEngines
rollout rltEngines "Render Engines" width:560 height:224 (
    groupBox grpEngVR "V-Ray Engine" pos:[4, 4] width:268 height:212
    checkbutton chkEngVRay "USE V-RAY" pos:[12,24] width:252 height:28 highlightColor:(color 30 120 220) checked:true tooltip:"Set V-Ray as the target render engine"
    checkbutton chkProVR "V-Ray Settings" pos:[12,56] width:252 height:22 highlightColor:(color 30 120 220) tooltip:"Open the V-Ray PRO settings panel"
    checkbutton chkElemVR "Render Elements" pos:[12,82] width:252 height:22 highlightColor:(color 30 120 220) tooltip:"Open the V-Ray render elements panel"
    button btnVRIPRStart "Interactive" pos:[12,108] width:122 height:22 tooltip:"Start V-Ray interactive rendering via ActiveShade"
    button btnVRIPRStop "Stop" pos:[142,108] width:122 height:22 tooltip:"Stop V-Ray interactive rendering"
    button btnVantageLL "CHAOS VANTAGE LIVE LINK" pos:[12,134] width:252 height:22 tooltip:"Start Chaos Vantage Live Link session (V-Ray)"
    button btnLLVR "Light Lister" pos:[12,160] width:252 height:22 tooltip:"Open the V-Ray light lister with every V-Ray light in the scene"
    button btnDLVRay "Download V-Ray 7" pos:[12,186] width:122 height:22 tooltip:"V-Ray 7 update 4.1"
    button btnDLVantage "Download Vantage" pos:[142,186] width:122 height:22 tooltip:"Chaos Vantage 3.3.1"

    groupBox grpEngCR "Corona Engine" pos:[280, 4] width:268 height:212
    checkbutton chkEngCorona "USE CORONA" pos:[288,24] width:252 height:28 highlightColor:(color 255 128 32) checked:false tooltip:"Set Corona as the target render engine"
    checkbutton chkProCR "Corona Settings" pos:[288,56] width:252 height:22 highlightColor:(color 255 128 32) tooltip:"Open the Corona PRO settings panel"
    checkbutton chkElemCR "Render Elements" pos:[288,82] width:252 height:22 highlightColor:(color 255 128 32) tooltip:"Open the Corona render elements panel"
    button btnCRIPRStart "Interactive" pos:[288,108] width:122 height:22 tooltip:"Start Corona interactive rendering"
    button btnCRIPRStop "Stop" pos:[418,108] width:122 height:22 tooltip:"Stop Corona interactive rendering"
    button btnLMSetup "LightMix Setup" pos:[288,134] width:122 height:22 tooltip:"Open Corona's LightMix setup dialog"
    button btnLMBake "Bake LightMix" pos:[418,134] width:122 height:22 tooltip:"Bake LightMix values back to the scene lights"
    button btnCRCheck "Corona Check" pos:[288,160] width:122 height:22 tooltip:"Run Corona's own native scene check"
    button btnLLCR "Light Lister" pos:[418,160] width:122 height:22 tooltip:"Open the Corona light lister with every Corona light in the scene"
    button btnDLCorona "Download Corona 15" pos:[288,186] width:252 height:22 tooltip:"Chaos Corona 15 hotfix 2"

    -- mirror the shared globals onto the controls (called after every engine change)
    fn refreshEngineUI = (
        try(
            chkEngVRay.checked = (neoTargetEngine == #vray)
            chkEngCorona.checked = (neoTargetEngine == #corona)
            chkProVR.checked = (neoProPanel == #vray)
            chkProCR.checked = (neoProPanel == #corona)
            chkElemVR.checked = (neoElemPanel == #vray)
            chkElemCR.checked = (neoElemPanel == #corona)
            btnVantageLL.enabled = (neoTargetEngine == #vray)
        )catch()
    )

    on rltEngines open do refreshEngineUI()

    on chkEngVRay changed state do (
        if state then (
            if (neoSetTargetEngine #vray) then neoCheckForeignElements #vray
            refreshEngineUI()
        ) else chkEngVRay.checked = true
    )
    on chkEngCorona changed state do (
        if state then (
            if (neoSetTargetEngine #corona) then neoCheckForeignElements #corona
            refreshEngineUI()
        ) else chkEngCorona.checked = true
    )

    on chkProVR changed state do (
        if state and neoTargetEngine != #vray then (
            chkProVR.checked = false
            messageBox "V-Ray is not the selected engine.\nSwitch to V-Ray first to open its settings." title:"NeoCapture"
        ) else (
            neoProPanel = if state then #vray else #none
            refreshEngineUI()
            neoSyncProUI()
        )
    )
    on chkProCR changed state do (
        if state and neoTargetEngine != #corona then (
            chkProCR.checked = false
            messageBox "Corona is not the selected engine.\nSwitch to Corona first to open its settings." title:"NeoCapture"
        ) else (
            neoProPanel = if state then #corona else #none
            refreshEngineUI()
            neoSyncProUI()
        )
    )
    on chkElemVR changed state do (
        if state and neoTargetEngine != #vray then (
            chkElemVR.checked = false
            messageBox "V-Ray is not the selected engine.\nSwitch to V-Ray first to open its render elements." title:"NeoCapture"
        ) else (
            neoElemPanel = if state then #vray else #none
            refreshEngineUI()
            neoSyncElements()
        )
    )
    on chkElemCR changed state do (
        if state and neoTargetEngine != #corona then (
            chkElemCR.checked = false
            messageBox "Corona is not the selected engine.\nSwitch to Corona first to open its render elements." title:"NeoCapture"
        ) else (
            neoElemPanel = if state then #corona else #none
            refreshEngineUI()
            neoSyncElements()
        )
    )

    on btnVantageLL pressed do neoStartVantageLiveLink()
    on btnVRIPRStart pressed do (
        if (neoActiveEngineName()) == "VR" then neoVRayInteractive()
        else messageBox "Switch to V-Ray first." title:"NeoCapture"
    )
    on btnVRIPRStop pressed do (
        try(closeActiveShadeFloater())catch()
        neoLog "V-Ray interactive stop requested"
    )
    on btnCRIPRStart pressed do (
        if (neoActiveEngineName()) == "CR" then neoCoronaInteractive()
        else messageBox "Switch to Corona first." title:"NeoCapture"
    )
    on btnCRIPRStop pressed do (
        try(CoronaRenderer.stopRender())catch()
        neoLog "Corona interactive stop requested"
    )
    on btnCRCheck pressed do (
        if (neoActiveEngineName()) == "CR" then try(CoronaRenderer.runSceneCheck())catch(messageBox "Corona scene check unavailable." title:"NeoCapture")
        else messageBox "Switch to Corona to use its native scene check." title:"NeoCapture"
    )
    on btnLMSetup pressed do neoLightMixSetup()
    on btnLMBake pressed do neoLightMixBake()
    on btnLLVR pressed do (
        if (neoActiveEngineName()) == "VR" then neoVRayLightLister()
        else messageBox "Switch to V-Ray first." title:"NeoCapture"
    )
    on btnLLCR pressed do (
        if (neoActiveEngineName()) == "CR" then neoCoronaLightLister()
        else messageBox "Switch to Corona first." title:"NeoCapture"
    )
    on btnDLVRay pressed do neoStartDownload "V-Ray 7 Update 4.1" neoDL_VRayURL
    on btnDLVantage pressed do neoStartDownload "Chaos Vantage 3.3.1" neoDL_VantageURL
    on btnDLCorona pressed do neoStartDownload "Chaos Corona 15 Hotfix 2" neoDL_CoronaURL
)

-- ============================ [8] CAPTURE AND OUTPUT PANEL ============================
rollout CaptureToolBottom "Neo Capture Tool - Capture and Output" width:560 height:466 (

    groupBox grpCapture "Viewport Capture" pos:[8, 8] width:544 height:50
    checkbox chkNormal "Default Shading" pos:[16, 28] width:100 height:16 checked:true tooltip:"Capture the viewport with default realistic shading"
    checkbox chkClay "Clay Mode" pos:[120, 28] width:80 height:16 checked:true tooltip:"Capture the viewport in clay display mode"
    button btnCapture "VIEWPORT CAPTURE" pos:[210, 24] width:330 height:24 tooltip:"Auto-hides Lights and Cameras before capture."

    groupBox grpQuality "Render Quality" pos:[8,63] width:544 height:50
    label lblQuality "Scale Quality:" pos:[16,85] width:70 height:16
    dropdownlist ddlQuality "" pos:[90,83] width:130 height:20 items:#("10%","25%","50%","75%","100%","125%","150%") selection:5

    groupBox grpOverride "Override Material" pos:[8,118] width:544 height:70
    checkbox chkOverrideActive "Enable Override" pos:[16,138] width:110 height:16 checked:false
    checkbox chkAutoGlass "Auto-Exclude Transparent Models" pos:[136,138] width:240 height:16 checked:true

    label lblExcl "Exclude Names:" pos:[16,160] width:90 height:16
    edittext edtExclude "" pos:[110,158] width:425 height:20 text:"Curtain*, Plant*, Tree*"

    groupBox grpOutput "Output" pos:[8,193] width:544 height:76
    edittext edtFolder "" pos:[16,213] width:440 height:20 text:""
    button btnBrowse "..." pos:[462,211] width:40 height:24 tooltip:"Choose the output folder for captures and renders"
    checkbox chkBackupScene "Backup scene" pos:[16,242] width:110 height:16 checked:false tooltip:"Save a safety copy of the scene into the output folder before rendering"
    checkbox chkVersionOut "Version outputs (v001...)" pos:[136,242] width:165 height:16 checked:false tooltip:"Render every batch into a fresh numbered subfolder so nothing is overwritten"
    checkbox chkSheet "Contact sheet" pos:[312,242] width:110 height:16 checked:true tooltip:"Build an HTML review page of all renders when the batch finishes"

    button btnUnified "CAPTURE + RENDER (ONE CLICK)" pos:[8,276] width:544 height:38 tooltip:"Viewport Capture then Production Render for all selected cameras"
    button btnRender "PRODUCTION RENDER" pos:[8,318] width:544 height:32 tooltip:"Batch-render every selected camera at its own resolution into the output folder"
    button btnLaunchAI "LAUNCH AI APP (Standalone)" pos:[8,354] width:544 height:32 highlightColor:(color 40 160 220) tooltip:"Export the scene data as JSON and launch the NeoCapture AI companion app"

    progressbar prgBar "" pos:[8,392] width:544 height:20 color:(color 60 180 80) value:0
    label lblStatus "" pos:[8,416] width:544 height:40

    fn isMtlTransparent m = (
        if m == undefined then return false
        local isTransp = false; local mClass = classof m as string
        if mClass == "VRayMtl" then isTransp = (m.refraction != (color 0 0 0)) or (m.texmap_opacity != undefined)
        else if mClass == "CoronaPhysicalMtl" then isTransp = (m.refractionAmount > 0.0) or (m.opacityMap != undefined)
        else if mClass == "CoronaMtl" or mClass == "CoronaLegacyMtl" then isTransp = (m.levelRefraction > 0.0) or (m.levelOpacity < 1.0) or (m.texmapOpacity != undefined)
        else if mClass == "PhysicalMaterial" then isTransp = (m.transparency > 0.0)
        else if classof m == multimaterial then for i = 1 to m.numsubs do if isMtlTransparent m[i] then isTransp = true
        else if mClass == "VRayBlendMtl" then (
            if isMtlTransparent m.baseMtl then isTransp = true
            for i = 1 to 9 do if isMtlTransparent m.coatMtl[i] then isTransp = true
        )
        else if mClass == "CoronaLayeredMtl" then (
            if isMtlTransparent m.baseMtl then isTransp = true
            for i = 1 to 9 do if isMtlTransparent m.layerMtl[i] then isTransp = true
        )
        isTransp
    )

    fn applyExcludeList = (
        local excludeNames = filterString edtExclude.text ","
        local excludeList = #()
        local autoGlass = chkAutoGlass.checked

        for obj in geometry do (
            if obj.material != undefined then (
                local bypass = false
                if autoGlass and isMtlTransparent obj.material then bypass = true
                if not bypass then (
                    for excl in excludeNames do (
                        local exclTrim = trimLeft (trimRight excl) " "
                        if matchPattern obj.material.name pattern:exclTrim then bypass = true
                    )
                )
                if bypass then if findItem excludeList obj == 0 then append excludeList obj
            )
        )
        try(renderers.current.excludeListOverrideMtl = excludeList) catch()
        try(renderers.current.mtlOverride_exclude = excludeList) catch()
    )

    fn updateProgress step total statusTxt = (
        prgBar.value = (step as float / total * 100) as integer
        lblStatus.text = statusTxt
    )

    fn saveCropped bmp filePath cx cy cw ch = (
        local cropped = bitmap cw ch
        for y = 0 to ch - 1 do setPixels cropped [0, y] (getPixels bmp [cx, cy + y] cw)
        cropped.filename = filePath
        save cropped
        free cropped
    )

    fn pushSettingsToVRay = (
        try (
            local vr = renderers.current
            try(vr.options_displacement = rltVR_GlobalSwitches.chkVR_Disp.checked)catch()
            try(vr.options_lights = rltVR_GlobalSwitches.chkVR_Lights.checked)catch()
            try(vr.options_shadows = rltVR_GlobalSwitches.chkVR_Shadows.checked)catch()
            try(vr.options_hiddenLights = rltVR_GlobalSwitches.chkVR_Hidden.checked)catch()
            try(vr.imageSampler_type = if rltVR_ImageSampler.ddlVR_Sampler.selection == 1 then 1 else 3)catch()
            try(vr.twoLevel_baseSubdivs = rltVR_BucketSampler.spnVR_MinSub.value)catch()
            try(vr.twoLevel_fineSubdivs = rltVR_BucketSampler.spnVR_MaxSub.value)catch()
            try(vr.twoLevel_threshold = rltVR_BucketSampler.spnVR_Noise.value)catch()
            try(vr.twoLevel_bucket_width = rltVR_BucketSampler.spnVR_BucketW.value)catch()
            try(vr.twoLevel_bucket_height = rltVR_BucketSampler.spnVR_BucketH.value)catch()
            try(vr.twoLevel_fireflyRemoval_on = rltVR_BucketSampler.chkVR_Firefly.checked)catch()
            try(vr.twoLevel_fireflyRemoval_threshold = rltVR_BucketSampler.spnVR_FireflyThresh.value)catch()
            try(vr.options_reflectionRefraction = rltVR_GlobalSwitches.chkVR_ReflRefr.checked)catch()
            try(vr.options_glossyEffects = rltVR_GlobalSwitches.chkVR_Glossy.checked)catch()
            try(vr.options_transpMaxLevels = rltVR_GlobalSwitches.spnVR_MaxTransp.value)catch()
            try(vr.options_ray_bias = rltVR_GlobalSwitches.spnVR_SecRaysBias.value)catch()
            try(vr.colorMapping_type = rltVR_ColorMapping.ddlVR_CMType.selection - 1)catch()
            try(vr.colorMapping_darkMult = rltVR_ColorMapping.spnVR_CMMult.value)catch()
            try(vr.colorMapping_brightMult = rltVR_ColorMapping.spnVR_CMBurn.value)catch()
            try(vr.filter_on = rltVR_ImageFilter.chkVR_Filter.checked)catch()
            try(vr.filter_size = rltVR_ImageFilter.spnVR_FilterSize.value)catch()
            try(vr.gi_on = rltVR_GlobalIllum.chkVR_GI.checked)catch()
            try(vr.gi_primary_type = if rltVR_GlobalIllum.ddlVR_PrimGI.selection == 1 then 2 else if rltVR_GlobalIllum.ddlVR_PrimGI.selection == 3 then 3 else 0)catch()
            try(vr.gi_secondary_type = if rltVR_GlobalIllum.ddlVR_SecGI.selection == 1 then 3 else if rltVR_GlobalIllum.ddlVR_SecGI.selection == 2 then 2 else 0)catch()
            try(vr.lightcache_subdivs = rltVR_LightCache.spnVR_LCSub.value)catch()
            try(vr.lightcache_sampleSize = rltVR_LightCache.spnVR_LCSamp.value)catch()
            try(vr.lightcache_showCalcPhase = rltVR_LightCache.chkVR_LCPhase.checked)catch()
            try(vr.lightcache_storeDirectLight = rltVR_LightCache.chkVR_LCDir.checked)catch()
            try(vr.lightcache_retrace_on = rltVR_LightCache.chkVR_LCRetrace.checked)catch()
            try(vr.lightcache_retrace_threshold = rltVR_LightCache.spnVR_LCRetraceVal.value)catch()
        ) catch()
    )

    fn pushSettingsToCorona = (
        -- Only push if the Corona settings panels were actually opened at least once;
        -- otherwise the controls still hold definition defaults and would clobber the scene.
        if not neoCRSettingsLoaded then return()
        try (
            local cr = renderers.current
            try(cr.progressive_passLimit = rltCR_Quality.spnPassLimit.value)catch()
            try(cr.progressive_timeLimit = ((rltCR_Quality.spnTimeLimit.value * 60000.0) as integer))catch()
            try(cr.adaptivity_targetError = rltCR_Quality.spnNoiseLimit.value)catch()
            try(cr.shading_maxSampleIntensity = rltCR_Quality.spnMSI.value)catch()
            try(cr.shading_maxRayDepth = rltCR_Quality.spnRayDepth.value)catch()
            try(cr.denoise_filterType = rltCR_Denoising.ddlDenoiser.selection - 1)catch()
            try(cr.denoise_blendAmount = rltCR_Denoising.spnBlend.value)catch()
            try(cr.denoise_textureBlur = rltCR_Denoising.spnTexBlur.value)catch()
            try(cr.image_prefilter_width = rltCR_Filtering.spnFilterW.value)catch()
            try(cr.fireflyFilter_mode = rltCR_Filtering.ddlFirefly.selection - 1)catch()
            try(cr.fireflyFilter_strength = rltCR_Filtering.spnFireflyStr.value)catch()
            try(cr.vfb_clearBetweenRenders = rltCR_SysVFB.chkClearVFB.checked)catch()
            try(cr.renderstamp_use = rltCR_SysVFB.chkStamp.checked)catch()
            try(cr.renderStamp = rltCR_SysVFB.edtStamp.text)catch()
        ) catch()
    )

    fn saveSettings = (
        setINISetting neoCaptureSettingsFile "Settings" "FolderPath" edtFolder.text
        setINISetting neoCaptureSettingsFile "Settings" "ResW" (CaptureToolUI.spnResW.value as string)
        setINISetting neoCaptureSettingsFile "Settings" "ResH" (CaptureToolUI.spnResH.value as string)
        setINISetting neoCaptureSettingsFile "Settings" "Lock" (CaptureToolUI.chkLock.checked as string)
        setINISetting neoCaptureSettingsFile "Settings" "AutoGlass" (chkAutoGlass.checked as string)
    )

    fn loadSettings = (
        local pathTxt = getINISetting neoCaptureSettingsFile "Settings" "FolderPath"
        if pathTxt != "" then edtFolder.text = pathTxt

        local lWTxt = getINISetting neoCaptureSettingsFile "Settings" "ResW"; if lWTxt != "" then CaptureToolUI.spnResW.value = lWTxt as integer
        local lHTxt = getINISetting neoCaptureSettingsFile "Settings" "ResH"; if lHTxt != "" then CaptureToolUI.spnResH.value = lHTxt as integer
        local lLock = getINISetting neoCaptureSettingsFile "Settings" "Lock"; if lLock != "" then CaptureToolUI.chkLock.checked = (lLock == "true")
        local lGlass = getINISetting neoCaptureSettingsFile "Settings" "AutoGlass"; if lGlass != "" then chkAutoGlass.checked = (lGlass == "true")
    )

    on CaptureToolBottom open do (
        loadSettings()
        try (chkOverrideActive.checked = renderers.current.options_overrideMtl_on) catch(
            try (chkOverrideActive.checked = renderers.current.useMtlOverride) catch()
        )
    )

    on chkAutoGlass changed state do ( if chkOverrideActive.checked then applyExcludeList() )

    on chkOverrideActive changed state do (
        local isCorona = neoIsCoronaRnd()
        if state then (
            local clayMtl = VRayMtl()
            if isCorona then ( try ( clayMtl = CoronaPhysicalMtl(); clayMtl.baseColor = color 188 188 188; clayMtl.roughness = 1.0 ) catch ( clayMtl = execute "CoronaMtl()"; if clayMtl != undefined do (clayMtl.colorDiffuse = color 188 188 188; clayMtl.levelReflection = 0) ))
            else ( clayMtl.diffuse = color 188 188 188; clayMtl.reflection = color 0 0 0; clayMtl.refraction = color 0 0 0 )

            try(renderers.current.options_overrideMtl_mtl = clayMtl) catch()
            try(renderers.current.options_overrideMtl_on = true) catch()
            try(renderers.current.mtlOverride = clayMtl) catch()
            try(renderers.current.enableMtlOverride = true) catch()
            try(renderers.current.useMtlOverride = true) catch()
            applyExcludeList()
            lblStatus.text = "Override Material ON"
        ) else (
            try(renderers.current.options_overrideMtl_on = false) catch()
            try(renderers.current.enableMtlOverride = false) catch()
            try(renderers.current.useMtlOverride = false) catch()
            try(renderers.current.excludeListOverrideMtl = #()) catch()
            try(renderers.current.mtlOverride_exclude = #()) catch()
            lblStatus.text = "Override Material OFF"
        )
    )

    on btnBrowse pressed do (
        local folder = getSavePath caption:"Choose output folder"
        if folder != undefined then edtFolder.text = folder
    )

    fn doCapture showMsg:true = (
        local saveFolder = edtFolder.text
        if saveFolder == "" then (
            saveFolder = getSavePath caption:"Choose output folder"
            if saveFolder == undefined then return false
            edtFolder.text = saveFolder
        )
        local selectedCams = CaptureToolUI.getSelectedCams()
        if selectedCams.count == 0 then ( messageBox "Select at least one camera." title:"Warning"; return false )
        if (not chkNormal.checked) and (not chkClay.checked) then ( messageBox "Select a mode." title:"Warning"; return false )

        local vs = NitrousGraphicsManager.GetActiveViewportSetting()
        local origStyle = vs.VisualStyleMode
        local totalSteps = 0
        if chkNormal.checked then totalSteps += selectedCams.count
        if chkClay.checked then totalSteps += selectedCams.count
        local currentStep = 0

        local origHideLights = hideByCategory.lights
        local origHideCams = hideByCategory.cameras
        hideByCategory.lights = true
        hideByCategory.cameras = true
        local boxModeObjs = for obj in geometry where obj.boxmode == true collect obj
        if boxModeObjs.count > 0 do for obj in boxModeObjs do obj.boxmode = false

        local okDone = true
        try (
            for cam in selectedCams do (
                if keyboard.escPressed then throw "Cancelled by user (ESC)"
                local res = CaptureToolUI.getCamRes cam
                local oldW = renderWidth; local oldH = renderHeight
                renderWidth = res[1]; renderHeight = res[2]
                viewport.setCamera cam
                local vpSize = getViewSize()
                local vpW = vpSize.x; local vpH = vpSize.y
                local camAspect = res[1] as float / res[2] as float
                local vpAspect = vpW as float / vpH as float
                local cropX = 0; local cropY = 0
                local cropW = vpW; local cropH = vpH

                if camAspect < vpAspect then (
                    cropW = (vpH * camAspect) as integer
                    cropX = ((vpW - cropW) / 2) as integer
                ) else (
                    cropH = (vpW / camAspect) as integer
                    cropY = ((vpH - cropH) / 2) as integer
                )

                local camDir = saveFolder + "\\" + (neoSafeDirName cam.name) + "\\images"
                makeDir camDir all:true

                if chkNormal.checked then (
                    vs.VisualStyleMode = #Realistic; redrawViews(); local bmp = viewport.getViewportDib()
                    saveCropped bmp (camDir + "\\default_shading.png") cropX cropY cropW cropH
                    free bmp; currentStep += 1; updateProgress currentStep totalSteps ("Viewport: " + cam.name)
                )
                if chkClay.checked then (
                    vs.VisualStyleMode = #Clay; redrawViews(); local bmp = viewport.getViewportDib()
                    saveCropped bmp (camDir + "\\clay.png") cropX cropY cropW cropH
                    free bmp; currentStep += 1; updateProgress currentStep totalSteps ("Clay: " + cam.name)
                )
                vs.VisualStyleMode = origStyle; renderWidth = oldW; renderHeight = oldH; redrawViews()
            )
            prgBar.value = 100; lblStatus.text = "Done! captured."
            hideByCategory.lights = origHideLights
            hideByCategory.cameras = origHideCams
            if boxModeObjs.count > 0 do for obj in boxModeObjs do obj.boxmode = true
            if showMsg then messageBox "Viewport Capture Finished!" title:"Neo Capture"
        ) catch (
            vs.VisualStyleMode = origStyle
            hideByCategory.lights = origHideLights
            hideByCategory.cameras = origHideCams
            if boxModeObjs.count > 0 do for obj in boxModeObjs do obj.boxmode = true
            lblStatus.text = getCurrentException(); prgBar.value = 0
            okDone = false
        )
        okDone
    )

    fn doRender showMsg:true = (
        local isVray = neoIsVRayRnd(); local isCorona = neoIsCoronaRnd()
        if neoTargetEngine == #vray and not isVray then (messageBox "Active renderer is NOT V-Ray!" title:"Warning"; return false)
        if neoTargetEngine == #corona and not isCorona then (messageBox "Active renderer is NOT Corona!" title:"Warning"; return false)

        local saveFolder = edtFolder.text
        if saveFolder == "" then ( saveFolder = getSavePath caption:"Choose folder"; if saveFolder == undefined then return false; edtFolder.text = saveFolder )
        local selectedCams = CaptureToolUI.getSelectedCams()
        if selectedCams.count == 0 then ( messageBox "Select a camera." title:"Warning"; return false )

        local origWidth = renderWidth; local origHeight = renderHeight

        if neoTargetEngine == #vray then pushSettingsToVRay() else pushSettingsToCorona()
        try(applyElementParamsLive())catch()

        local origObjIDs = #()
        if (neoTargetEngine == #vray and rltVR_ColorID.chkEnable.checked) or (neoTargetEngine == #corona and rltCR_ColorID.chkEnable.checked) then (
            for obj in objects do append origObjIDs #(obj, obj.gbufferchannel)
            local idCounter = 1
            for obj in objects do ( obj.gbufferchannel = idCounter; idCounter += 1 )
        )

        -- versioned outputs: every batch renders into a fresh numbered subfolder
        local renderRoot = saveFolder
        if chkVersionOut.checked do (
            local vIdx = 1
            while doesFileExist (saveFolder + "\\v" + (formattedPrint vIdx format:"03d")) do vIdx += 1
            renderRoot = saveFolder + "\\v" + (formattedPrint vIdx format:"03d")
        )
        makeDir renderRoot all:true

        -- scene safety copy next to the renders (does not change the current file name)
        if chkBackupScene.checked do (
            try(
                saveMaxFile (renderRoot + "\\scene_backup.max") useNewFile:false quiet:true
                neoLog ("Scene backup saved in " + renderRoot)
            )catch(neoLog ("Scene backup failed: " + getCurrentException()))
        )

        local okDone = true
        neoLog ("Batch render started: " + selectedCams.count as string + " cameras -> " + renderRoot)
        try (
            local camIdx = 0
            local failedCams = #()
            local sheetData = #()
            local batchStart = timeStamp()
            for cam in selectedCams do (
                if keyboard.escPressed then throw "Cancelled by user (ESC)"
                camIdx += 1
                -- rough time estimate based on the cameras already finished
                local etaTxt = ""
                if camIdx > 1 do (
                    local perCam = ((timeStamp() - batchStart) / 1000.0) / (camIdx - 1)
                    local remainSec = (perCam * (selectedCams.count - camIdx + 1)) as integer
                    etaTxt = " | ~" + remainSec as string + "s left"
                )
                updateProgress camIdx selectedCams.count ("Rendering " + (camIdx as string) + "/" + (selectedCams.count as string) + ": " + cam.name + etaTxt)
                local res = CaptureToolUI.getCamRes cam; local qualVal = CaptureToolUI.qualityValues[ddlQuality.selection]
                renderWidth = (res[1] * qualVal) as integer; renderHeight = (res[2] * qualVal) as integer
                local ext = if neoTargetEngine == #corona then ".cxr" else ".vrimg"

                local camDir = renderRoot + "\\" + (neoSafeDirName cam.name) + "\\images"
                makeDir camDir all:true

                -- one failing camera must not kill the whole batch
                local camStart = timeStamp()
                try (
                    local bm = render camera:cam outputfile:(camDir + "\\render" + ext) vfb:false
                    -- browser-friendly copy for the contact sheet
                    try(
                        bm.filename = camDir + "\\preview.jpg"
                        save bm
                    )catch()
                    try(free bm)catch()
                    append sheetData #(cam.name, renderWidth, renderHeight, (((timeStamp() - camStart) / 1000.0) as integer), true)
                    neoLog ("Rendered OK: " + cam.name + " (" + renderWidth as string + "x" + renderHeight as string + ")")
                ) catch (
                    append failedCams cam.name
                    append sheetData #(cam.name, renderWidth, renderHeight, (((timeStamp() - camStart) / 1000.0) as integer), false)
                    neoLog ("Render FAILED: " + cam.name + " - " + getCurrentException())
                )
            )
            renderWidth = origWidth; renderHeight = origHeight
            if origObjIDs.count > 0 then for item in origObjIDs do item[1].gbufferchannel = item[2]
            local totalSec = ((timeStamp() - batchStart) / 1000.0) as integer
            prgBar.value = 100
            lblStatus.text = "Done in " + totalSec as string + "s. OK: " + (selectedCams.count - failedCams.count) as string + " | Failed: " + failedCams.count as string
            neoLog ("Batch render finished in " + totalSec as string + "s, failed: " + failedCams.count as string)
            try((dotNetClass "System.Media.SystemSounds").Asterisk.Play())catch()
            if chkSheet.checked and sheetData.count > 0 do (
                try(neoBuildContactSheet renderRoot sheetData totalSec)catch(neoLog ("Contact sheet failed: " + getCurrentException()))
            )
            if showMsg then (
                local msg = "Render Finished!\nCameras: " + selectedCams.count as string + "\nTime: " + totalSec as string + " sec"
                if failedCams.count > 0 do (
                    msg += "\n\nFAILED (" + failedCams.count as string + "):"
                    for f in failedCams do msg += "\n - " + f
                )
                messageBox msg title:"Neo Capture Tool"
            )
        ) catch (
            renderWidth = origWidth; renderHeight = origHeight
            if origObjIDs.count > 0 then for item in origObjIDs do item[1].gbufferchannel = item[2]
            lblStatus.text = getCurrentException(); prgBar.value = 0
            neoLog ("Batch render aborted: " + getCurrentException())
            okDone = false
        )
        okDone
    )

    on btnCapture pressed do doCapture()

    on btnRender pressed do doRender()

    on btnUnified pressed do (
        if (doCapture showMsg:false) then (
            if (doRender showMsg:false) then messageBox "Capture + Render Finished!" title:"Neo Capture Tool"
        )
    )

    on btnLaunchAI pressed do (
        local saveFolder = edtFolder.text
        if saveFolder == "" then ( messageBox "Please select Output Folder first." title:"NeoCapture"; return false )

        lblStatus.text = "Exporting Global Scene Data..."

        -- Create the master project json in the root
        makeDir saveFolder all:true
        local jsonPath = saveFolder + "\\" + CaptureToolUI.getExportBaseName() + ".json"
        if doesFileExist jsonPath then deleteFile jsonPath
        local f = createfile jsonPath
        local buildOk = true
        try ( format "%" (CaptureToolUI.buildSceneJSON()) to:f ) catch ( buildOk = false; lblStatus.text = "Export failed: " + getCurrentException() )
        close f
        if not buildOk then return false

        lblStatus.text = "Data Exported! Launching AI App..."

        local runBat = (pathConfig.removePathLeaf (getFilenamePath (getThisScriptFilename()))) + "\\run_app.bat"

        if doesFileExist runBat then (
            HiddenDOSCommand ("\"" + runBat + "\" \"" + saveFolder + "\"") donotwait:true
        ) else (
            messageBox ("Cannot find run_app.bat!\nTried: " + runBat)
        )
    )

    on CaptureToolBottom close do (
        try(saveSettings())catch()
    )
)

-- ============================ [9] TAB BAR, LAUNCHER AND CALLBACKS ============================
-- The main window is split into tabs: only the rollouts of the active tab are added to the
-- floater. Anything shared between tabs lives in the globals declared in section [6b].
global neoCurrentTab = #capture
global rltNeoTabBar
global neoShowTab

fn neoShowTab tabName = (
    if neoCaptureFloater == undefined then return()
    local captureGroup = #(CaptureToolUI, CaptureToolBottom)
    local renderGroup  = #(rltEngines, rltNeoPresets)
    local setupGroup   = #(rltNeoTools, rltNeoScriptMgr)

    try(CaptureToolUI.storeSelection())catch()
    for r in captureGroup do try(removeRollout r neoCaptureFloater)catch()
    for r in renderGroup do try(removeRollout r neoCaptureFloater)catch()
    for r in setupGroup do try(removeRollout r neoCaptureFloater)catch()

    local target = case tabName of (
        #capture: captureGroup
        #render: renderGroup
        default: setupGroup
    )
    for r in target do addRollout r neoCaptureFloater rolledUp:false

    try(
        rltNeoTabBar.tabCapture.checked = (tabName == #capture)
        rltNeoTabBar.tabRender.checked = (tabName == #render)
        rltNeoTabBar.tabSetup.checked = (tabName == #setup)
    )catch()
    neoCurrentTab = tabName
)

rollout rltNeoTabBar "" width:560 height:34 (
    checkbutton tabCapture "CAPTURE" pos:[6,4] width:180 height:26 checked:true highlightColor:(color 45 135 165) tooltip:"Cameras, resolutions, viewport capture and production render"
    checkbutton tabRender "RENDER" pos:[190,4] width:180 height:26 highlightColor:(color 45 135 165) tooltip:"Render engines, their panels and render presets"
    checkbutton tabSetup "SETUP" pos:[374,4] width:180 height:26 highlightColor:(color 45 135 165) tooltip:"Scene tools and the script/plugin manager"

    -- lives here because the tab bar is the only rollout that is always visible
    timer posSyncTimer "Pos Sync" interval:30 active:true
    local lastMainPos = undefined

    on tabCapture changed state do ( if state then neoShowTab #capture else tabCapture.checked = true )
    on tabRender changed state do ( if state then neoShowTab #render else tabRender.checked = true )
    on tabSetup changed state do ( if state then neoShowTab #setup else tabSetup.checked = true )

    on posSyncTimer tick do (
        if neoCaptureFloater != undefined and (neoProPanel != #none or neoElemPanel != #none) then (
            local p = neoCaptureFloater.pos
            if lastMainPos == undefined or p.x != lastMainPos.x or p.y != lastMainPos.y then (
                lastMainPos = p
                if neoProPanel != #none do try(neoSettingsFloater.pos = [p.x + 580, p.y]) catch()
                if neoElemPanel != #none do try(neoElementsFloater.pos = [(amax 0 (p.x - 420)), p.y]) catch()
            )
        )
    )
)

fn launchNeoCaptureFloater = (
    try(closeRolloutFloater neoCaptureFloater) catch()
    local mainW = 580
    local mainH = 900
    local screenW = (dotNetClass "System.Windows.Forms.Screen").PrimaryScreen.WorkingArea.Width
    local screenH = (dotNetClass "System.Windows.Forms.Screen").PrimaryScreen.WorkingArea.Height
    local mainX = (screenW - mainW) / 2
    local mainY = (screenH - mainH) / 2
    if mainY < 0 do mainY = 0
    global neoCaptureFloater = newRolloutFloater "Neo Capture Tool Ultimate" mainW mainH pos:[mainX, mainY]
    try(neoCaptureFloater.pos = [mainX, mainY]) catch()
    -- the engine the tool starts on follows the current system renderer
    neoTargetEngine = if (neoIsCoronaRnd()) then #corona else #vray
    addRollout rltNeoTabBar neoCaptureFloater
    neoShowTab #capture
)

-- splash + machine profile + repo check, then the main window
neoStartup()

-- keep the engine checkboxes in sync when the renderer is changed from Max itself
try(callbacks.removeScripts id:#neoEngineSync)catch()
try(callbacks.addScript #postRendererChange "neoOnRendererChanged()" id:#neoEngineSync)catch()

-- Max limitation: .rps files never store the output resolution. When a NeoCapture
-- preset is loaded from the native Render Setup dropdown, this hook fires and applies
-- the resolution we stored alongside it in the script's own preset file.
global neoOnRenderPresetLoaded
fn neoOnRenderPresetLoaded = (
    try(
        local p = callbacks.notificationParam()
        local fname = ""
        if (classof p == String) then fname = p
        else if (classof p == Array) then ( for x in p where (classof x == String) and (matchPattern x pattern:"*.rps") do fname = x )
        if fname == "" then return()
        local base = getFilenameFile (filenameFromPath fname)
        if not (matchPattern base pattern:"NeoCapture_*") then return()
        local safeName = substring base 12 base.count
        local sections = #()
        try(sections = getINISetting neoCapturePresetsFile)catch()
        for s in sections do (
            local nm = substring s 4 s.count
            if (neoSafeFileName nm) == safeName do (
                local sw = getINISetting neoCapturePresetsFile s "NEO_ResW"
                local sh = getINISetting neoCapturePresetsFile s "NEO_ResH"
                if sw != "" and sh != "" do (
                    local reopenRS = false
                    try(if renderSceneDialog.isOpen() do ( renderSceneDialog.close(); reopenRS = true ))catch()
                    try(renderWidth = sw as integer)catch()
                    try(renderHeight = sh as integer)catch()
                    if reopenRS do try(renderSceneDialog.open())catch()
                    neoLog ("Resolution restored after native preset load: " + sw + "x" + sh)
                )
            )
        )
    )catch()
)
try(callbacks.removeScripts id:#neoPresetSync)catch()
try(callbacks.addScript #postRenderPresetLoad "neoOnRenderPresetLoaded()" id:#neoPresetSync)catch()

neoLog "NeoCapture launched"