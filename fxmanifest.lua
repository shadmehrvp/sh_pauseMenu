fx_version 'cerulean'
game 'gta5'

name 'sh_pauseMenu'
author 'SH Scripts'
description 'Pause menu with live character data, an interactive city map and native GTA settings'
version '1.0.0-rc.4'

ui_page 'html/index.html'
shared_script 'config.lua'
client_script 'client/main.lua'
server_scripts { 'server/bridge.lua', 'server/custom.lua', 'server/main.lua' }
files {
    'html/index.html', 'html/app.js', 'html/style.css', 'html/assets/*',
    'html/map/index.html', 'html/map/map.js', 'html/map/map.css'
}
