local creatorOpen = false

-- Server response events must be declared as net events or FiveM blocks them
RegisterNetEvent('flake_addiction:admin:openCreator')
RegisterNetEvent('flake_addiction:admin:dataReady')
RegisterNetEvent('flake_addiction:admin:saveDrugResponse')
RegisterNetEvent('flake_addiction:admin:deleteDrugResponse')
RegisterNetEvent('flake_addiction:admin:saveMedResponse')
RegisterNetEvent('flake_addiction:admin:deleteMedResponse')
RegisterNetEvent('flake_addiction:admin:saveSettingsResponse')
RegisterNetEvent('flake_addiction:syncConfig')

-- ── Open / close ──────────────────────────────────────────────────────────

RegisterCommand('addictioncreator', function()
    if creatorOpen then return end
    TriggerServerEvent('flake_addiction:admin:requestOpen')
end, false)

RegisterCommand('resetaddictioninstall', function()
    TriggerServerEvent('flake_addiction:admin:resetInstall')
end, false)

RegisterNetEvent('flake_addiction:admin:openCreator', function()
    if creatorOpen then return end
    creatorOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'openCreator' })
end)

-- Called by the index.html bridge script when the iframe requests close
RegisterNuiCallback('creatorClosed', function(_, cb)
    creatorOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'closeCreator' })
    cb('ok')
end)

-- ── Get all creator data ──────────────────────────────────────────────────

RegisterNuiCallback('creatorGetData', function(_, cb)
    local handlerRef
    handlerRef = AddEventHandler('flake_addiction:admin:dataReady', function(payload)
        RemoveEventHandler(handlerRef)
        handlerRef = nil
        cb(payload)
    end)
    TriggerServerEvent('flake_addiction:admin:getData')

    -- Timeout fallback so the NUI callback never hangs
    SetTimeout(6000, function()
        if handlerRef then
            RemoveEventHandler(handlerRef)
            handlerRef = nil
            cb({ drugs = {}, meds = {}, drugImmunity = 100, translations = {} })
        end
    end)
end)

-- ── Save drug ─────────────────────────────────────────────────────────────

RegisterNuiCallback('creatorSaveDrug', function(data, cb)
    local handlerRef
    handlerRef = AddEventHandler('flake_addiction:admin:saveDrugResponse', function(ok, err)
        RemoveEventHandler(handlerRef)
        handlerRef = nil
        cb({ ok = ok, error = err })
    end)
    TriggerServerEvent('flake_addiction:admin:saveDrug', data)

    SetTimeout(6000, function()
        if handlerRef then RemoveEventHandler(handlerRef); handlerRef = nil; cb({ ok = false, error = 'Timeout' }) end
    end)
end)

-- ── Delete drug ───────────────────────────────────────────────────────────

RegisterNuiCallback('creatorDeleteDrug', function(data, cb)
    local handlerRef
    handlerRef = AddEventHandler('flake_addiction:admin:deleteDrugResponse', function(ok, err)
        RemoveEventHandler(handlerRef)
        handlerRef = nil
        cb({ ok = ok, error = err })
    end)
    TriggerServerEvent('flake_addiction:admin:deleteDrug', data)

    SetTimeout(6000, function()
        if handlerRef then RemoveEventHandler(handlerRef); handlerRef = nil; cb({ ok = false, error = 'Timeout' }) end
    end)
end)

-- ── Save medication ───────────────────────────────────────────────────────

RegisterNuiCallback('creatorSaveMedication', function(data, cb)
    local handlerRef
    handlerRef = AddEventHandler('flake_addiction:admin:saveMedResponse', function(ok, err)
        RemoveEventHandler(handlerRef)
        handlerRef = nil
        cb({ ok = ok, error = err })
    end)
    TriggerServerEvent('flake_addiction:admin:saveMedication', data)

    SetTimeout(6000, function()
        if handlerRef then RemoveEventHandler(handlerRef); handlerRef = nil; cb({ ok = false, error = 'Timeout' }) end
    end)
end)

-- ── Delete medication ─────────────────────────────────────────────────────

RegisterNuiCallback('creatorDeleteMedication', function(data, cb)
    local handlerRef
    handlerRef = AddEventHandler('flake_addiction:admin:deleteMedResponse', function(ok, err)
        RemoveEventHandler(handlerRef)
        handlerRef = nil
        cb({ ok = ok, error = err })
    end)
    TriggerServerEvent('flake_addiction:admin:deleteMedication', data)

    SetTimeout(6000, function()
        if handlerRef then RemoveEventHandler(handlerRef); handlerRef = nil; cb({ ok = false, error = 'Timeout' }) end
    end)
end)

-- ── Save settings ─────────────────────────────────────────────────────────

RegisterNuiCallback('creatorSaveSettings', function(data, cb)
    local handlerRef
    handlerRef = AddEventHandler('flake_addiction:admin:saveSettingsResponse', function(ok, err)
        RemoveEventHandler(handlerRef)
        handlerRef = nil
        cb({ ok = ok, error = err })
    end)
    TriggerServerEvent('flake_addiction:admin:saveSettings', data)

    SetTimeout(6000, function()
        if handlerRef then RemoveEventHandler(handlerRef); handlerRef = nil; cb({ ok = false, error = 'Timeout' }) end
    end)
end)

-- ── Receive live config sync from server ──────────────────────────────────
-- Keeps client-side Config.UsableDrugs current after admin adds/removes drugs
-- so the HUD and drug-use events continue working without a resource restart.

-- syncConfig is handled in client/main.lua (loaded first).
-- The RegisterNetEvent declaration here keeps FiveM's net-safety check happy
-- if any code in this file were ever to reference it directly.
RegisterNetEvent('flake_addiction:syncConfig')

-- ── First-run preset NUI callbacks ────────────────────────────────────────
-- Respond immediately so the NUI fetch never hangs, then fire the server
-- event asynchronously. The UI reloads data after a short delay.

RegisterNuiCallback('creatorApplyPreset', function(_, cb)
    cb({ ok = true })
    TriggerServerEvent('flake_addiction:admin:applyPreset')
end)

RegisterNuiCallback('creatorDeclinePreset', function(_, cb)
    cb({ ok = true })
    TriggerServerEvent('flake_addiction:admin:declinePreset')
end)
