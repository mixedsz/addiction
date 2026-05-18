local QBCore = exports['qb-core']:GetCoreObject()

-- playerAddictions[source][drugName] = remaining_seconds (internal unit)
-- The client display uses minutes: remaining_seconds / 60
-- When remaining_seconds <= 0 → player is in withdrawal (suffering)
local playerAddictions = {}
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
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then return Player.PlayerData.citizenid end
    return nil
end

local function hasAnyAddiction(src)
    if not playerAddictions[src] then return false end
    for _ in pairs(playerAddictions[src]) do return true end
    return false
end

-- Convert internal seconds → minutes for the client HUD percentage math:
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
            -- only restore drugs that still exist in config and have time left
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

-- One tick per second. The timer keeps running as long as the player has at
-- least one tracked drug (even if remaining_time is already <= 0, so the
-- client keeps receiving the suffering state until a cure is applied).
function startAddictionTimer(src)
    if playerTimerRunning[src] then return end
    playerTimerRunning[src] = true

    Citizen.CreateThread(function()
        while playerAddictions[src] and hasAnyAddiction(src) do
            Wait(1000)
            if not playerAddictions[src] then break end

            for drug, remaining in pairs(playerAddictions[src]) do
                -- countdown but floor at a small negative so the client loop
                -- keeps showing the suffering state without integer overflow
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
-- Drug item registration
-- ─────────────────────────────────────────

for drugName, drugData in pairs(Config.UsableDrugs) do
    QBCore.Functions.CreateUseableItem(drugName, function(source)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end
        if not Player.Functions.GetItemByName(drugName) then return end

        Player.Functions.RemoveItem(drugName, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[drugName], 'remove')

        if not playerAddictions[src] then playerAddictions[src] = {} end

        local addictionSecs  = drugData.addiction.time * 60  -- config time is in minutes
        local addictionChance = drugData.addiction.chance
        local gotAddicted    = false

        if playerAddictions[src][drugName] then
            -- Already tracked: refresh the withdrawal timer so the player
            -- has bought themselves another full cycle before suffering hits.
            playerAddictions[src][drugName] = addictionSecs
        elseif addictionChance > 0 and math.random(1, 100) <= addictionChance then
            -- First use rolled positive for addiction
            playerAddictions[src][drugName] = addictionSecs
            gotAddicted = true
        end
        -- addiction.chance == 0 → drug produces no addiction, just effects

        TriggerClientEvent('g4_addiction:useDrug', src, drugName, gotAddicted)
        TriggerClientEvent('g4_addiction:data', src, buildClientData(src), true)

        startAddictionTimer(src)
    end)
end

-- ─────────────────────────────────────────
-- Medication item registration
-- ─────────────────────────────────────────

-- Config.Medication keys are title-cased ("Naloxone") but inventory item names
-- are conventionally lowercase, so we register both spellings.
for medName, curesDrugs in pairs(Config.Medication) do
    local itemName = medName:lower()

    local function useMed(source)
        local src = source
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return end

        -- accept either casing from the inventory
        local item = Player.Functions.GetItemByName(itemName)
                   or Player.Functions.GetItemByName(medName)
        if not item then return end

        local usedName = item.name
        Player.Functions.RemoveItem(usedName, 1)
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[usedName], 'remove')

        if playerAddictions[src] then
            for _, drug in ipairs(curesDrugs) do
                playerAddictions[src][drug] = nil
            end
        end

        TriggerClientEvent('g4_addiction:useMedication', src)
        TriggerClientEvent('g4_addiction:data', src, buildClientData(src), false)

        savePlayerAddictions(src)
    end

    QBCore.Functions.CreateUseableItem(itemName, useMed)
    -- also register title-case variant if different (e.g. "Naloxone" vs "naloxone")
    if medName ~= itemName then
        QBCore.Functions.CreateUseableItem(medName, useMed)
    end
end

-- ─────────────────────────────────────────
-- Player lifecycle events
-- ─────────────────────────────────────────

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local src = Player.PlayerData.source
    loadPlayerAddictions(src)
end)

-- QBCore fires PlayerUnload before playerDropped so we save twice to be safe
AddEventHandler('QBCore:Server:PlayerUnload', function(src)
    savePlayerAddictions(src)
    playerAddictions[src]     = nil
    playerTimerRunning[src]   = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    if playerAddictions[src] then
        savePlayerAddictions(src)
    end
    playerAddictions[src]    = nil
    playerTimerRunning[src]  = nil
end)

-- ─────────────────────────────────────────
-- Admin command: /clearaddiction [id]
-- ─────────────────────────────────────────

QBCore.Commands.Add('clearaddiction', 'Clear all drug addictions for a player (Admin)', {
    { name = 'id', help = 'Target player server ID' }
}, true, function(src, args)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local perm = Player.PlayerData.permission
    if perm ~= 'admin' and perm ~= 'god' then
        TriggerClientEvent('QBCore:Notify', src, 'You do not have permission.', 'error')
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        TriggerClientEvent('QBCore:Notify', src, 'Invalid player ID.', 'error')
        return
    end

    playerAddictions[targetId] = {}
    TriggerClientEvent('g4_addiction:data', targetId, {}, false)

    local identifier = getIdentifier(targetId)
    if identifier then
        MySQL.query('DELETE FROM g4_addiction WHERE identifier = ?', { identifier })
    end

    TriggerClientEvent('QBCore:Notify', src, 'Cleared addictions for player ' .. targetId .. '.', 'success')
end, 'admin')

-- Console/RCON variant (src == 0 means server console)
RegisterCommand('clearaddiction_console', function(src, args)
    if src ~= 0 then return end  -- console only
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
