local drugsInUse = 0
local drugStrength = 0
local addictions = {}
local immunity = 100
local addicted = false
local isSuffering = false

-- Keep client-side Config in sync with the server whenever the resource
-- restarts. The handler lives here (main.lua loads first) so it is
-- registered before the requestSync server event fires at the bottom.
RegisterNetEvent('g4_addiction:syncConfig')
AddEventHandler('g4_addiction:syncConfig', function(drugs, meds, imm, translations)
    for k in pairs(Config.UsableDrugs) do Config.UsableDrugs[k] = nil end
    for k, v in pairs(drugs)           do Config.UsableDrugs[k] = v   end
    Config.Medication   = meds
    Config.DrugImmunity = imm
    if translations then
        for k, v in pairs(translations) do Config.Translations[k] = v end
    end
    local count = 0
    for _ in pairs(Config.UsableDrugs) do count = count + 1 end
    print(('[g4_addiction] syncConfig received — %d drug(s) active on client'):format(count))
end)

RegisterNetEvent('g4_addiction:useMedication', function()
    local playerPed = PlayerPedId()
    pill(playerPed)
    updateHUD()
end)

RegisterNetEvent('g4_addiction:useDrug', function(drugName, gotAddicted)
    local player = PlayerId()
    local playerPed = PlayerPedId()
    if not Config.UsableDrugs[drugName] then
        -- Config.UsableDrugs is empty after a resource restart until syncConfig arrives.
        -- This is a known symptom — the server will broadcast sync on start.
        print(('[g4_addiction] useDrug: Config.UsableDrugs["%s"] is nil on client — waiting for syncConfig'):format(drugName))
        return
    end
    if Config.UsableDrugs[drugName] then
        drugsInUse = drugsInUse + 1
        if drugStrength < 0 then drugStrength = 0 end
        drugStrength = drugStrength + Config.UsableDrugs[drugName].drugStrength

        if drugStrength > 0 then
            immunity = 100 - math.ceil((drugStrength/Config.DrugImmunity)*100)
        end

        if Config.UsableDrugs[drugName].animation == 'smoke' then
            smoke(playerPed)
        elseif Config.UsableDrugs[drugName].animation == 'syringe' then
            syringe(playerPed)
        elseif Config.UsableDrugs[drugName].animation == 'sniff' then
            sniff(playerPed)
        elseif Config.UsableDrugs[drugName].animation == 'pill' then
            pill(playerPed)
        end

        if drugStrength > Config.DrugImmunity then
            removeEffects()
            SetEntityHealth(playerPed, 0)
            drugStrength = 0 
            immunity = 100
            SendNUIMessage({
                alert = true,
                drugName = Config.Translations.overdose_highlighted_text,
                content = {
                    header = Config.Translations.notification_header,
                    text = Config.Translations.overdose_text,
                    description = Config.Translations.overdose_description
                }
            })
            updateHUD()
            return
        end

        if gotAddicted then
            SendNUIMessage({
                alert = true,
                drugName = Config.UsableDrugs[drugName].label,
                content = {
                    header = Config.Translations.notification_header,
                    text = Config.Translations.addiction_text,
                    description = Config.Translations.addiction_description
                }
            })
        end

        updateHUD()

        if Config.UsableDrugs[drugName].effect.walkingStyle ~= nil then
            RequestAnimSet(Config.UsableDrugs[drugName].effect.walkingStyle)
            while not HasAnimSetLoaded(Config.UsableDrugs[drugName].effect.walkingStyle) do Wait(250) end
            SetPedMovementClipset(playerPed, Config.UsableDrugs[drugName].effect.walkingStyle, true)
        end

        AnimpostfxPlay(Config.UsableDrugs[drugName].effect.screenFX, Config.UsableDrugs[drugName].effect.duration*1000, true)

        SetPedMoveRateOverride(player, Config.UsableDrugs[drugName].effect.speedMultiplier)

        SetPedMotionBlur(playerPed, true)
        SetPedIsDrunk(playerPed, true)

        ShakeGameplayCam("FAMILY5_DRUG_TRIP_SHAKE", Config.UsableDrugs[drugName].effect.cameraShakeIntensity)

        SetEntityHealth(playerPed, GetEntityHealth(playerPed) + Config.UsableDrugs[drugName].healthEffects.health)

        Wait(Config.UsableDrugs[drugName].effect.duration*1000)
        removeEffects(drugName)
        AnimpostfxStop(Config.UsableDrugs[drugName].effect.screenFX)
    end
end)

function loadAnimDict(name)
    RequestAnimDict(name)
    while (not HasAnimDictLoaded(name)) do Wait(250) end
end

function sniff(playerPed)
    loadAnimDict("anim@mp_player_intcelebrationmale@face_palm")
    TaskPlayAnim(playerPed,"anim@mp_player_intcelebrationmale@face_palm","face_palm",8.0,8.0, -1, 0, 0, false, false, false)
    Wait(2500)
    ClearPedTasks(playerPed)
end

function pill(playerPed)
    loadAnimDict("mp_suicide")
    TaskPlayAnim(playerPed,"mp_suicide","pill",8.0,8.0, -1, 0, 0, false, false, false)
    Wait(2500)
    ClearPedTasks(playerPed)
end

function syringe(playerPed)
    loadAnimDict("rcmpaparazzo1ig_4")
    TaskPlayAnim(playerPed,"rcmpaparazzo1ig_4","miranda_shooting_up",8.0,8.0, -1, 16, 0, false, false, false)

    local hash = GetHashKey("prop_syringe_01")
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(0) end
    local prop = CreateObject(hash, GetEntityCoords(playerPed), true, true, false)
    SetModelAsNoLongerNeeded(hash)
    AttachEntityToEntity(prop, playerPed, GetPedBoneIndex(playerPed, 18905), 0.12, 0.03, 0.03, 143.0, 30.0, 0.0, true, true, false, false, 1, true)
    Wait(13000)
    AttachEntityToEntity(prop, playerPed, GetPedBoneIndex(playerPed, 28422), -0.02, 0.01, -0.02, 1.0, 0, 0.0, true, true, false, false, 1, true)
    Wait(15000)
    DetachEntity(prop, 0, 0)
    DeleteEntity(prop)
    ClearPedTasks(playerPed)
end

function smoke(playerPed)
    TaskStartScenarioInPlace(playerPed, "WORLD_HUMAN_SMOKING_POT", 0, 1)
    Wait(10000)
    ClearPedTasks(playerPed)
end

function removeEffects(drugName)
    local player = PlayerId()
    local playerPed = PlayerPedId()
    drugsInUse = drugsInUse - 1
    if drugName then
        drugStrength = drugStrength - Config.UsableDrugs[drugName].drugStrength
        immunity = 100 - math.ceil((drugStrength/Config.DrugImmunity)*100)
        if drugStrength <= 0 then 
            drugStrength = 0
            immunity = 100
        end
        updateHUD()
    end
    if drugsInUse <= 0 then
        SetRunSprintMultiplierForPlayer(player, 1.0)
        SetPedMotionBlur(playerPed, false)
        ResetPedMovementClipset(playerPed)
        SetPedIsDrunk(playerPed, false)
        ShakeGameplayCam("FAMILY5_DRUG_TRIP_SHAKE", 0.0)
    end
end

RegisterNetEvent('g4_addiction:data', function(data, use)
    addictions = data
    if use then return end
    updateHUD()
end)

function updateHUD()
    local data = {}
    if immunity < 0 then
        immunity = 0
    elseif immunity > 100 then
        immunity = 100
    end
    if immunity < 100 then table.insert(data, {name = 'Immunity', percent = immunity}) end
    local addict = false
    for k,v in pairs(addictions) do
        local percent = math.ceil((v/Config.UsableDrugs[k].addiction.time)*100)
        if v <= 0 then addict = true end
        table.insert(data, {name = Config.UsableDrugs[k].label, percent = percent})
    end
    addicted = addict
    if addicted then 
        suffering()
    else
        isSuffering = false
    end
    SendNUIMessage({data = data})
end

function suffering()
    if isSuffering then return end
    isSuffering = true
    local playerPed = PlayerPedId()
    Citizen.CreateThread(function()
        while addicted do
            DisableControlAction(0, 21, true)
            AnimpostfxPlay("DeathFailMPIn", 0, true)
            Wait(1)
            if GetHashKey("MOVE_M@DRUNK@SLIGHTLYDRUNK") ~= GetPedMovementClipset(PlayerPedId()) then 
                RequestAnimSet("MOVE_M@DRUNK@SLIGHTLYDRUNK")
                while not HasAnimSetLoaded("MOVE_M@DRUNK@SLIGHTLYDRUNK") do Wait(250) end
                SetPedMovementClipset(playerPed, "MOVE_M@DRUNK@SLIGHTLYDRUNK", true)
            end
        end
        AnimpostfxStop("DeathFailMPIn")
        ResetPedMovementClipset(playerPed)
        return
    end)
end

-- On every (re)start, pull current config from server immediately so
-- Config.UsableDrugs is never stale when a player uses a drug.
TriggerServerEvent('g4_addiction:requestSync')
