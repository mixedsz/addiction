Config = {}

Config.AdminGroups = { 'admin', 'superadmin' } -- ESX groups that can access the Addiction Creator panel

Config.DrugImmunity = 100 -- how much the player can withstand the drug acting at the same time (drugStrength)

Config.UsableDrugs = {
    ["oxycodone_10mg"] = {
        label = "Oxycodone 10mg",
        animation = 'pill', -- (smoke/syringe/sniff/pill)
        drugStrength = 6, -- this amount is being removed from immunity of player for effect duration time
        healthEffects = {
            armour = 0,
            health = 10
        },
        addiction = {
            chance = 0,
            time = 60 -- time until drug wears out and you need other dose (in minutes)
        },
        effect = {
            duration = 30, -- in seconds
            screenFX = "DrugsMichaelAliensFightIn",
            speedMultiplier = 0.8, -- from 1.0 to 1.49
            walkingStyle = nil,
            cameraShakeIntensity = 1.0,
        }
    },
    ["oxycodone_30mg"] = {
        label = "Oxycodone 30mg",
        animation = 'pill', -- (smoke/syringe/sniff/pill)
        drugStrength = 8, -- this amount is being removed from immunity of player for effect duration time
        healthEffects = {
            armour = 0,
            health = 30
        },
        addiction = {
            chance = 0,
            time = 60 -- time until drug wears out and you need other dose (in minutes)
        },
        effect = {
            duration = 30, -- in seconds
            screenFX = "RaceTurbo",
            speedMultiplier = 1.1, -- from 1.0 to 1.49
            walkingStyle = "MOVE_M@DRUNK@moderatedrunk",
            cameraShakeIntensity = 1.0,
        }
    },
    ["alg"] = {
        label = "ALG",
        animation = 'pill', -- (smoke/syringe/sniff/pill)
        drugStrength = 8, -- this amount is being removed from immunity of player for effect duration time
        healthEffects = {
            armour = 0,
            health = 0
        },
        addiction = {
            chance = 0,
            time = 60 -- time until drug wears out and you need other dose (in minutes)
        },
        effect = {
            duration = 30, -- in seconds
            screenFX = "RaceTurbo",
            speedMultiplier = 1.1, -- from 1.0 to 1.49
            walkingStyle = nil,
            cameraShakeIntensity = 1.0,
        }
    },
    ["mdma"] = {
        label = "MDMA",
        animation = 'pill', -- (smoke/syringe/sniff/pill)
        drugStrength = 8, -- this amount is being removed from immunity of player for effect duration time
        healthEffects = {
            armour = 0,
            health = 0
        },
        addiction = {
            chance = 0,
            time = 60 -- time until drug wears out and you need other dose (in minutes)
        },
        effect = {
            duration = 30, -- in seconds
            screenFX = "spectator5",
            speedMultiplier = 1.2, -- from 1.0 to 1.49
            walkingStyle = nil,
            cameraShakeIntensity = 1.0,
        }
    },
    ["actavis"] = {
        label = "Actavis",
        animation = 'pill', -- (smoke/syringe/sniff/pill)
        drugStrength = 8, -- this amount is being removed from immunity of player for effect duration time
        healthEffects = {
            armour = 15,
            health = 0
        },
        addiction = {
            chance = 0,
            time = 60 -- time until drug wears out and you need other dose (in minutes)
        },
        effect = {
            duration = 30, -- in seconds
            screenFX = "PPPurple",
            speedMultiplier = 0.85, -- from 1.0 to 1.49
            walkingStyle = nil,
            cameraShakeIntensity = 1.0,
        }
    },
    ["tris"] = {
        label = "Tris",
        animation = 'pill', -- (smoke/syringe/sniff/pill)
        drugStrength = 8, -- this amount is being removed from immunity of player for effect duration time
        healthEffects = {
            armour = 10,
            health = 0
        },
        addiction = {
            chance = 0,
            time = 60 -- time until drug wears out and you need other dose (in minutes)
        },
        effect = {
            duration = 30, -- in seconds
            screenFX = "PPPurple",
            speedMultiplier = 1.1, -- from 1.0 to 1.49
            walkingStyle = nil,
            cameraShakeIntensity = 1.0,
        }
    },
    ["wockhardt"] = {
        label = "Wockhardt",
        animation = 'pill', -- (smoke/syringe/sniff/pill)
        drugStrength = 8, -- this amount is being removed from immunity of player for effect duration time
        healthEffects = {
            armour = 7,
            health = 0
        },
        addiction = {
            chance = 0,
            time = 60 -- time until drug wears out and you need other dose (in minutes)
        },
        effect = {
            duration = 30, -- in seconds
            screenFX = "PPPurple",
            speedMultiplier = 0.7, -- from 1.0 to 1.49
            walkingStyle = nil,
            cameraShakeIntensity = 1.0,
        }
    },
    ["quagen"] = {
        label = "Quagen",
        animation = 'pill', -- (smoke/syringe/sniff/pill)
        drugStrength = 8, -- this amount is being removed from immunity of player for effect duration time
        healthEffects = {
            armour = 5,
            health = 0
        },
        addiction = {
            chance = 0,
            time = 60 -- time until drug wears out and you need other dose (in minutes)
        },
        effect = {
            duration = 30, -- in seconds
            screenFX = "PPPurple",
            speedMultiplier = 0.7, -- from 1.0 to 1.49
            walkingStyle = nil,
            cameraShakeIntensity = 1.0,
        }
    },
    ["yellow"] = {
        label = "Yellow",
        animation = 'pill', -- (smoke/syringe/sniff/pill)
        drugStrength = 8, -- this amount is being removed from immunity of player for effect duration time
        healthEffects = {
            armour = 5,
            health = 0
        },
        addiction = {
            chance = 0,
            time = 60 -- time until drug wears out and you need other dose (in minutes)
        },
        effect = {
            duration = 30, -- in seconds
            screenFX = "MenuMGTournamentIn",
            speedMultiplier = 0.85, -- from 1.0 to 1.49
            walkingStyle = nil,
            cameraShakeIntensity = 1.0,
        }
    },
}

Config.Medication = {
    ["Naloxone"] = { 'oxycodone_10mg', 'oxycodone_30mg', 'actavis', 'tris', 'wockhardt', 'quagen' }, -- opioid/lean cures
    ["Suboxone"] = { 'oxycodone_10mg', 'oxycodone_30mg' }, -- maintenance cure for oxy
    ["Naltrexone"] = { 'mdma', 'alg', 'yellow' }, -- stimulant/party drug cure
    ["Methadone"] = { 'oxycodone_10mg', 'oxycodone_30mg', 'actavis' }, -- long-term treatment
}

Config.Translations = {
    notification_header = "Attention",
    overdose_text = "You have just",
    overdose_highlighted_text = "Overdosed",
    overdose_description = "Your body couldn't handle the amount of drugs that you took...",
    addiction_text = "You just got addicted to",
    addiction_description = "As the amount of the drug in the body decreases, you will feel worse, in order to cure the addiction, you must get the right type of cure.",
}