-- shared_script '@WaveShield/resource/include.lua' -- uncomment if WaveShield is installed

fx_version 'cerulean'
game 'gta5'
description 'g4_addiction'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/creator.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/creator.html',
    'ui/assets/*.js',
    'ui/assets/*.css',
    'ui/assets/*.svg',
}
lua54 'yes'