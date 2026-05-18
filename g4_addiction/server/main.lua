local ESX = nil

-- Fetch ESX shared object — works for both legacy (esx:getSharedObject) and
-- modern (es_extended export) versions of ESX / es_extended.
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- playerAddictions[source][drugName] = remaining_seconds (internal unit)
-- The client display uses minutes: remaining_seconds / 60
-- When remaining_seconds <= 0 → player is in withdrawal (suffering)
local playerAddictions   = {}
local playerTimerRunning = {}

-- ─────────────────────────────────────────
-- Database bootstrap
-- ─────────────────────────────────────────

MySQL.ready(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `g4_addiction` (
            `identifier`     VARCHAR(60)  NOT NULL,
            `drug`           VARCHAR(50)  NOT NULL,
            `remaining_time` INT          NOT NULL DEFAULT 0,
            PRIMARY KEY (`identifier`, `drug`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)

-- ─────────────────────────────────────────
-- Utility helpers
-- ─────────────────────────────────────────

local function getIdentifier(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then return xPlayer.identifier end
    return nil
end

local function hasAnyAddiction(src)
    if not playerAddictions[src] then return false end
    for _ in pairs(playerAddictions[src]) do return true end
    return false
end

-- Convert internal seconds → minutes for client HUD percentage math:
--   percent = ceil( (v / addiction.time_minutes) * 100 )
local function buildClientData(src)
    local out = {}
    if playerAddictions[src] then
        for drug, secs in pairs(playerAddictions[src]) do
            out[drug] = secs / 60.0
        end
    end
    return out
end

-- ─────────────────────────────────────────
-- Database I/O
-- ─────────────────────────────────────────

local function loadPlayerAddictions(src)
    local identifier = getIdentifier(src)
    if not identifier then return end

    playerAddictions[src] = {}

    local rows = MySQL.query.await(
        'SELECT drug, remaining_time FROM g4_addiction WHERE identifier = ?',
        { identifier }
    )
    if rows then
        for _, row in ipairs(rows) do
            if Config.UsableDrugs[row.drug] and row.remaining_time > 0 then
                playerAddictions[src][row.drug] = row.remaining_time
            end
        end
    end

    TriggerClientEvent('g4_addiction:data', src, buildClientData(src), false)
    startAddictionTimer(src)
end

local function savePlayerAddictions(src)
    local identifier = getIdentifier(src)
    if not identifier then return end

    MySQL.query('DELETE FROM g4_addiction WHERE identifier = ?', { identifier })

    if not playerAddictions[src] then return end

    for drug, remaining in pairs(playerAddictions[src]) do
        -- persist negative values too so withdrawal state survives relog
        MySQL.query(
            'INSERT INTO g4_addiction (identifier, drug, remaining_time) VALUES (?, ?, ?)',
            { identifier, drug, math.floor(remaining) }
        )
    end
end

-- ─────────────────────────────────────────
-- Addiction countdown timer (per player)
-- ─────────────────────────────────────────

-- One tick per second. Keeps running while the player has any tracked drug
-- (even when remaining_time <= 0) so the client sees the suffering state
-- until a cure is applied.
function startAddictionTimer(src)
    if playerTimerRunning[src] then return end
    playerTimerRunning[src] = true

    Citizen.CreateThread(function()
        while playerAddictions[src] and hasAnyAddiction(src) do
            Wait(1000)
            if not playerAddictions[src] then break end

            for drug, remaining in pairs(playerAddictions[src]) do
                -- floor at -3600 so the client keeps showing suffering state
                -- without integer overflow on a very long session
                if remaining > -3600 then
                    playerAddictions[src][drug] = remaining - 1
                end
            end

            TriggerClientEvent('g4_addiction:data', src, buildClientData(src), false)
        end

        playerTimerRunning[src] = nil
    end)
end

-- ─────────────────────────────────────────
-- Item registration (drugs + medications)
-- Called on every resource start so new config entries are always picked up.
-- After adding a drug to Config just `restart g4_addiction` — no server reboot.
-- ─────────────────────────────────────────

local function registerItems()
    -- Drugs
    for drugName, drugData in pairs(Config.UsableDrugs) do
        ESX.RegisterUsableItem(drugName, function(source)
            local src     = source
            local xPlayer = ESX.GetPlayerFromId(src)
            if not xPlayer then return end

            local item = xPlayer.getInventoryItem(drugName)
            if not item or item.count <= 0 then return end

            xPlayer.removeInventoryItem(drugName, 1)

            if not playerAddictions[src] then playerAddictions[src] = {} end

            local addictionSecs   = drugData.addiction.time * 60
            local addictionChance = drugData.addiction.chance
            local gotAddicted     = false

            if playerAddictions[src][drugName] then
                -- Already tracked: refresh timer, buying another dose cycle.
                playerAddictions[src][drugName] = addictionSecs
            elseif addictionChance > 0 and math.random(1, 100) <= addictionChance then
                playerAddictions[src][drugName] = addictionSecs
                gotAddicted = true
            end
            -- addiction.chance == 0 → effects only, no addiction tracking

            TriggerClientEvent('g4_addiction:useDrug', src, drugName, gotAddicted)
            TriggerClientEvent('g4_addiction:data', src, buildClientData(src), true)

            startAddictionTimer(src)
        end)
    end

    -- Medications
    -- Config keys are title-cased ("Naloxone"); register lowercase too since
    -- ESX/ox_inventory item names are conventionally lowercase.
    for medName, curesDrugs in pairs(Config.Medication) do
        local itemName = medName:lower()

        local function useMed(source)
            local src     = source
            local xPlayer = ESX.GetPlayerFromId(src)
            if not xPlayer then return end

            -- Accept either casing (some servers define items as "Naloxone",
            -- others as "naloxone").
            local item = xPlayer.getInventoryItem(itemName)
            if not item or item.count <= 0 then
                item = xPlayer.getInventoryItem(medName)
            end
            if not item or item.count <= 0 then return end

            xPlayer.removeInventoryItem(item.name, 1)

            if playerAddictions[src] then
                for _, drug in ipairs(curesDrugs) do
                    playerAddictions[src][drug] = nil
                end
            end

            TriggerClientEvent('g4_addiction:useMedication', src)
            TriggerClientEvent('g4_addiction:data', src, buildClientData(src), false)

            savePlayerAddictions(src)
        end

        ESX.RegisterUsableItem(itemName, useMed)
        if medName ~= itemName then
            ESX.RegisterUsableItem(medName, useMed)
        end
    end

    local drugCount, medCount = 0, 0
    for _ in pairs(Config.UsableDrugs)  do drugCount = drugCount + 1 end
    for _ in pairs(Config.Medication)   do medCount  = medCount  + 1 end
    print(('[g4_addiction] Registered %d drug(s) and %d medication(s) as useable items.'):format(drugCount, medCount))
end

AddEventHandler('onServerResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    -- Re-fetch ESX in case it was also restarted
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    -- Merge config.json (admin-created drugs) into Config before registering items
    mergeConfigJson()
    -- Small wait to ensure ESX is fully ready before registering items
    Citizen.SetTimeout(500, registerItems)
end)

-- ─────────────────────────────────────────
-- Player lifecycle events
-- ─────────────────────────────────────────

AddEventHandler('esx:playerLoaded', function(playerId, xPlayer, isNew)
    loadPlayerAddictions(playerId)
end)

AddEventHandler('esx:playerDropped', function(playerId, reason)
    if playerAddictions[playerId] then
        savePlayerAddictions(playerId)
    end
    playerAddictions[playerId]   = nil
    playerTimerRunning[playerId] = nil
end)

-- Safety-save on raw drop in case esx:playerDropped doesn't fire
AddEventHandler('playerDropped', function()
    local src = source
    if playerAddictions[src] then
        savePlayerAddictions(src)
    end
    playerAddictions[src]   = nil
    playerTimerRunning[src] = nil
end)

-- ─────────────────────────────────────────
-- Admin command: /clearaddiction [id]
-- ─────────────────────────────────────────

ESX.RegisterCommand('clearaddiction', 'admin', function(xPlayer, args, showError)
    local targetId = tonumber(args.id)
    if not targetId then
        showError('Invalid player ID.')
        return
    end

    playerAddictions[targetId] = {}
    TriggerClientEvent('g4_addiction:data', targetId, {}, false)

    local identifier = getIdentifier(targetId)
    if identifier then
        MySQL.query('DELETE FROM g4_addiction WHERE identifier = ?', { identifier })
    end

    TriggerClientEvent('esx:showNotification', xPlayer.source,
        'Cleared addictions for player ' .. targetId .. '.')
end, false, {
    help      = 'Clear all drug addictions for a player',
    arguments = { { name = 'id', help = 'Target player server ID', type = 'number' } }
})

-- Console/RCON variant
RegisterCommand('clearaddiction_console', function(src, args)
    if src ~= 0 then return end
    local targetId = tonumber(args[1])
    if not targetId then
        print('[g4_addiction] Usage: clearaddiction_console <serverID>')
        return
    end

    playerAddictions[targetId] = {}
    TriggerClientEvent('g4_addiction:data', targetId, {}, false)

    local identifier = getIdentifier(targetId)
    if identifier then
        MySQL.query('DELETE FROM g4_addiction WHERE identifier = ?', { identifier })
    end

    print('[g4_addiction] Cleared addictions for player ' .. targetId)
end, true)

-- ═════════════════════════════════════════════════════════════════════════
-- ADDICTION CREATOR — admin panel backend
-- ═════════════════════════════════════════════════════════════════════════

-- Tracks which drug / medication keys were loaded from config.json
-- (admin-created). Base config.lua entries are NOT in these sets.
local adminDrugKeys = {}
local adminMedKeys  = {}

-- ─────────────────────────────────────────
-- config.json load / save
-- ─────────────────────────────────────────

local CONFIG_JSON = 'config.json'

local function readConfigJson()
    local raw = LoadResourceFile(GetCurrentResourceName(), CONFIG_JSON)
    if not raw or raw == '' then return {} end
    local ok, parsed = pcall(json.decode, raw)
    if not ok or type(parsed) ~= 'table' then
        print('[g4_addiction] WARNING: config.json is malformed — ignoring.')
        return {}
    end
    return parsed
end

function mergeConfigJson()
    local data = readConfigJson()

    if type(data.drugs) == 'table' then
        for k, v in pairs(data.drugs) do
            Config.UsableDrugs[k] = v
            adminDrugKeys[k]      = true
        end
    end

    if type(data.meds) == 'table' then
        for k, v in pairs(data.meds) do
            Config.Medication[k] = v
            adminMedKeys[k]      = true
        end
    end

    if type(data.drugImmunity) == 'number' then
        Config.DrugImmunity = data.drugImmunity
    end

    if type(data.translations) == 'table' then
        for k, v in pairs(data.translations) do
            Config.Translations[k] = v
        end
    end
end

local function writeConfigJson()
    local out = {
        drugs        = {},
        meds         = {},
        drugImmunity = Config.DrugImmunity,
        translations = Config.Translations,
    }
    for k in pairs(adminDrugKeys) do
        if Config.UsableDrugs[k] then out.drugs[k] = Config.UsableDrugs[k] end
    end
    for k in pairs(adminMedKeys) do
        if Config.Medication[k] then out.meds[k] = Config.Medication[k] end
    end
    local encoded = json.encode(out, { indent = true })
    SaveResourceFile(GetCurrentResourceName(), CONFIG_JSON, encoded, -1)
end

-- ─────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────

local function isAdmin(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return false end
    local g = xPlayer.getGroup()
    return g == 'admin' or g == 'superadmin'
end

-- Register a single drug as a useable item (used when admin creates a new one live)
local function registerSingleDrug(drugName, drugData)
    ESX.RegisterUsableItem(drugName, function(source)
        local src     = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return end

        local item = xPlayer.getInventoryItem(drugName)
        if not item or item.count <= 0 then return end

        xPlayer.removeInventoryItem(drugName, 1)

        if not playerAddictions[src] then playerAddictions[src] = {} end

        local addictionSecs   = drugData.addiction.time * 60
        local addictionChance = drugData.addiction.chance
        local gotAddicted     = false

        if playerAddictions[src][drugName] then
            playerAddictions[src][drugName] = addictionSecs
        elseif addictionChance > 0 and math.random(1, 100) <= addictionChance then
            playerAddictions[src][drugName] = addictionSecs
            gotAddicted = true
        end

        TriggerClientEvent('g4_addiction:useDrug', src, drugName, gotAddicted)
        TriggerClientEvent('g4_addiction:data', src, buildClientData(src), true)
        startAddictionTimer(src)
    end)
end

-- Register a single medication as a useable item
local function registerSingleMed(medName, curesDrugs)
    local itemName = medName:lower()
    local function useMed(source)
        local src     = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if not xPlayer then return end

        local item = xPlayer.getInventoryItem(itemName)
        if not item or item.count <= 0 then
            item = xPlayer.getInventoryItem(medName)
        end
        if not item or item.count <= 0 then return end

        xPlayer.removeInventoryItem(item.name, 1)

        if playerAddictions[src] then
            for _, drug in ipairs(curesDrugs) do
                playerAddictions[src][drug] = nil
            end
        end

        TriggerClientEvent('g4_addiction:useMedication', src)
        TriggerClientEvent('g4_addiction:data', src, buildClientData(src), false)
        savePlayerAddictions(src)
    end
    ESX.RegisterUsableItem(itemName, useMed)
    if medName ~= itemName then ESX.RegisterUsableItem(medName, useMed) end
end

-- Push updated Config to all connected clients
local function broadcastConfigSync()
    TriggerClientEvent('g4_addiction:syncConfig', -1,
        Config.UsableDrugs,
        Config.Medication,
        Config.DrugImmunity,
        Config.Translations
    )
end

-- ─────────────────────────────────────────
-- Creator: open request (admin check)
-- ─────────────────────────────────────────

RegisterNetEvent('g4_addiction:admin:requestOpen', function()
    local src = source
    if not isAdmin(src) then
        TriggerClientEvent('esx:showNotification', src, 'You do not have permission to use this.')
        return
    end
    TriggerClientEvent('g4_addiction:admin:openCreator', src)
end)

-- ─────────────────────────────────────────
-- Creator: get data
-- ─────────────────────────────────────────

RegisterNetEvent('g4_addiction:admin:getData', function()
    local src = source
    if not isAdmin(src) then return end

    local drugs = {}
    for k, v in pairs(Config.UsableDrugs) do
        -- Deep copy so we don't mutate Config when adding _source
        local entry = {}
        for fk, fv in pairs(v) do entry[fk] = fv end
        if type(v.healthEffects) == 'table' then
            entry.healthEffects = { armour = v.healthEffects.armour, health = v.healthEffects.health }
        end
        if type(v.addiction) == 'table' then
            entry.addiction = { chance = v.addiction.chance, time = v.addiction.time }
        end
        if type(v.effect) == 'table' then
            entry.effect = {}
            for ek, ev in pairs(v.effect) do entry.effect[ek] = ev end
        end
        entry._source = adminDrugKeys[k] and 'custom' or 'base'
        drugs[k]      = entry
    end

    local meds = {}
    for k, v in pairs(Config.Medication) do
        meds[k] = { cures = v, _source = adminMedKeys[k] and 'custom' or 'base' }
    end

    TriggerClientEvent('g4_addiction:admin:dataReady', src, {
        drugs        = drugs,
        meds         = meds,
        drugImmunity = Config.DrugImmunity,
        translations = Config.Translations,
    })
end)

-- ─────────────────────────────────────────
-- Creator: save drug
-- ─────────────────────────────────────────

RegisterNetEvent('g4_addiction:admin:saveDrug', function(data)
    local src = source
    if not isAdmin(src) then return end

    local key = data and data.key
    if type(key) ~= 'string' or key == '' then
        TriggerClientEvent('g4_addiction:admin:saveDrugResponse', src, false, 'Invalid item name.')
        return
    end

    -- Prevent overwriting base config.lua entries
    if Config.UsableDrugs[key] and not adminDrugKeys[key] then
        TriggerClientEvent('g4_addiction:admin:saveDrugResponse', src, false, 'Cannot overwrite a base config.lua drug.')
        return
    end

    local drug = data.drug
    if type(drug) ~= 'table' or not drug.label then
        TriggerClientEvent('g4_addiction:admin:saveDrugResponse', src, false, 'Invalid drug data.')
        return
    end

    Config.UsableDrugs[key] = drug
    adminDrugKeys[key]      = true

    registerSingleDrug(key, drug)
    writeConfigJson()
    broadcastConfigSync()

    TriggerClientEvent('g4_addiction:admin:saveDrugResponse', src, true, nil)
    print(('[g4_addiction] Admin %s created/updated drug: %s'):format(GetPlayerName(src), key))
end)

-- ─────────────────────────────────────────
-- Creator: delete drug
-- ─────────────────────────────────────────

RegisterNetEvent('g4_addiction:admin:deleteDrug', function(data)
    local src = source
    if not isAdmin(src) then return end

    local key = data and data.key
    if not adminDrugKeys[key] then
        TriggerClientEvent('g4_addiction:admin:deleteDrugResponse', src, false, 'Can only delete admin-created drugs.')
        return
    end

    Config.UsableDrugs[key] = nil
    adminDrugKeys[key]      = nil

    writeConfigJson()
    broadcastConfigSync()

    TriggerClientEvent('g4_addiction:admin:deleteDrugResponse', src, true, nil)
    print(('[g4_addiction] Admin %s deleted drug: %s'):format(GetPlayerName(src), key))
end)

-- ─────────────────────────────────────────
-- Creator: save medication
-- ─────────────────────────────────────────

RegisterNetEvent('g4_addiction:admin:saveMedication', function(data)
    local src = source
    if not isAdmin(src) then return end

    local name  = data and data.name
    local cures = data and data.cures

    if type(name) ~= 'string' or name == '' then
        TriggerClientEvent('g4_addiction:admin:saveMedResponse', src, false, 'Invalid medication name.')
        return
    end

    if Config.Medication[name] and not adminMedKeys[name] then
        TriggerClientEvent('g4_addiction:admin:saveMedResponse', src, false, 'Cannot overwrite a base config.lua medication.')
        return
    end

    if type(cures) ~= 'table' then cures = {} end

    Config.Medication[name] = cures
    adminMedKeys[name]      = true

    registerSingleMed(name, cures)
    writeConfigJson()
    broadcastConfigSync()

    TriggerClientEvent('g4_addiction:admin:saveMedResponse', src, true, nil)
end)

-- ─────────────────────────────────────────
-- Creator: delete medication
-- ─────────────────────────────────────────

RegisterNetEvent('g4_addiction:admin:deleteMedication', function(data)
    local src = source
    if not isAdmin(src) then return end

    local name = data and data.name
    if not adminMedKeys[name] then
        TriggerClientEvent('g4_addiction:admin:deleteMedResponse', src, false, 'Can only delete admin-created medications.')
        return
    end

    Config.Medication[name] = nil
    adminMedKeys[name]      = nil

    writeConfigJson()
    broadcastConfigSync()

    TriggerClientEvent('g4_addiction:admin:deleteMedResponse', src, true, nil)
end)

-- ─────────────────────────────────────────
-- Creator: save settings
-- ─────────────────────────────────────────

RegisterNetEvent('g4_addiction:admin:saveSettings', function(data)
    local src = source
    if not isAdmin(src) then return end

    if type(data.drugImmunity) == 'number' and data.drugImmunity > 0 then
        Config.DrugImmunity = data.drugImmunity
    end

    if type(data.translations) == 'table' then
        for k, v in pairs(data.translations) do
            Config.Translations[k] = v
        end
    end

    writeConfigJson()
    broadcastConfigSync()

    TriggerClientEvent('g4_addiction:admin:saveSettingsResponse', src, true, nil)
end)
