local creatorOpen = false

-- ── Open / close ──────────────────────────────────────────────────────────

RegisterCommand('addictioncreator', function()
    if creatorOpen then return end
    -- Server validates admin status; if not admin server simply does not respond
    TriggerServerEvent('g4_addiction:admin:requestOpen')
end, false)

RegisterNetEvent('g4_addiction:admin:openCreator', function()
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
    handlerRef = AddEventHandler('g4_addiction:admin:dataReady', function(payload)
        RemoveEventHandler(handlerRef)
        handlerRef = nil
        cb(payload)
    end)
    TriggerServerEvent('g4_addiction:admin:getData')

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
    handlerRef = AddEventHandler('g4_addiction:admin:saveDrugResponse', function(ok, err)
        RemoveEventHandler(handlerRef)
        handlerRef = nil
        cb({ ok = ok, error = err })
    end)
    TriggerServerEvent('g4_addiction:admin:saveDrug', data)

    SetTimeout(6000, function()
        if handlerRef then RemoveEventHandler(handlerRef); handlerRef = nil; cb({ ok = false, error = 'Timeout' }) end
    end)
end)

-- ── Delete drug ───────────────────────────────────────────────────────────

RegisterNuiCallback('creatorDeleteDrug', function(data, cb)
    local handlerRef
    handlerRef = AddEventHandler('g4_addiction:admin:deleteDrugResponse', function(ok, err)
        RemoveEventHandler(handlerRef)
        handlerRef = nil
        cb({ ok = ok, error = err })
    end)
    TriggerServerEvent('g4_addiction:admin:deleteDrug', data)

    SetTimeout(6000, function()
        if handlerRef then RemoveEventHandler(handlerRef); handlerRef = nil; cb({ ok = false, error = 'Timeout' }) end
    end)
end)

-- ── Save medication ───────────────────────────────────────────────────────

RegisterNuiCallback('creatorSaveMedication', function(data, cb)
    local handlerRef
    handlerRef = AddEventHandler('g4_addiction:admin:saveMedResponse', function(ok, err)
        RemoveEventHandler(handlerRef)
        handlerRef = nil
        cb({ ok = ok, error = err })
    end)
    TriggerServerEvent('g4_addiction:admin:saveMedication', data)

    SetTimeout(6000, function()
        if handlerRef then RemoveEventHandler(handlerRef); handlerRef = nil; cb({ ok = false, error = 'Timeout' }) end
    end)
end)

-- ── Delete medication ─────────────────────────────────────────────────────

RegisterNuiCallback('creatorDeleteMedication', function(data, cb)
    local handlerRef
    handlerRef = AddEventHandler('g4_addiction:admin:deleteMedResponse', function(ok, err)
        RemoveEventHandler(handlerRef)
        handlerRef = nil
        cb({ ok = ok, error = err })
    end)
    TriggerServerEvent('g4_addiction:admin:deleteMedication', data)

    SetTimeout(6000, function()
        if handlerRef then RemoveEventHandler(handlerRef); handlerRef = nil; cb({ ok = false, error = 'Timeout' }) end
    end)
end)

-- ── Save settings ─────────────────────────────────────────────────────────

RegisterNuiCallback('creatorSaveSettings', function(data, cb)
    local handlerRef
    handlerRef = AddEventHandler('g4_addiction:admin:saveSettingsResponse', function(ok, err)
        RemoveEventHandler(handlerRef)
        handlerRef = nil
        cb({ ok = ok, error = err })
    end)
    TriggerServerEvent('g4_addiction:admin:saveSettings', data)

    SetTimeout(6000, function()
        if handlerRef then RemoveEventHandler(handlerRef); handlerRef = nil; cb({ ok = false, error = 'Timeout' }) end
    end)
end)

-- ── Receive live config sync from server ──────────────────────────────────
-- Keeps client-side Config.UsableDrugs current after admin adds/removes drugs
-- so the HUD and drug-use events continue working without a resource restart.

RegisterNetEvent('g4_addiction:syncConfig', function(drugs, meds, immunity, translations)
    -- Wipe and replace UsableDrugs
    for k in pairs(Config.UsableDrugs) do Config.UsableDrugs[k] = nil end
    for k, v in pairs(drugs) do Config.UsableDrugs[k] = v end

    Config.Medication   = meds
    Config.DrugImmunity = immunity

    if translations then
        for k, v in pairs(translations) do Config.Translations[k] = v end
    end
end)

-- ── First-run preset NUI callbacks ────────────────────────────────────────

RegisterNuiCallback('creatorApplyPreset', function(_, cb)
    local handlerRef
    handlerRef = AddEventHandler('g4_addiction:admin:presetDone', function(data)
        RemoveEventHandler(handlerRef); handlerRef = nil
        cb(data)
    end)
    TriggerServerEvent('g4_addiction:admin:applyPreset')
    SetTimeout(10000, function()
        if handlerRef then RemoveEventHandler(handlerRef); handlerRef = nil; cb({ ok = false, error = 'Timeout' }) end
    end)
end)

RegisterNuiCallback('creatorDeclinePreset', function(_, cb)
    local handlerRef
    handlerRef = AddEventHandler('g4_addiction:admin:presetDone', function(data)
        RemoveEventHandler(handlerRef); handlerRef = nil
        cb({ ok = true })
    end)
    TriggerServerEvent('g4_addiction:admin:declinePreset')
    SetTimeout(6000, function()
        if handlerRef then RemoveEventHandler(handlerRef); handlerRef = nil; cb({ ok = true }) end
    end)
end)
