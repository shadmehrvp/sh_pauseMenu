Config = {}

-- auto | esx | qb | qbox | standalone | custom
-- Qbox is checked before qb-core because it can expose a QB compatibility bridge.
Config.Framework = 'auto'
Config.Resources = { esx = 'es_extended', qb = 'qb-core', qbox = 'qbx_core' }
Config.Language = 'en' -- English UI
Config.ServerName = 'YOUR SERVER'
Config.ServerDescription = 'Your city. Your story.'
Config.Currency = '$'
Config.MaxPlayers = 0 -- 0 = server sv_maxclients convar
Config.DiscordUrl = '' -- Set your real https://discord.gg/... invite here.
Config.WebsiteUrl = '' -- Optional https://... website.
Config.DisconnectMessage = 'You left the server. See you soon!'
Config.Command = 'pausemenu'
Config.OpenKey = 'F10' -- Additional remappable shortcut; ESC and P work too.
Config.InterceptPause = true -- Turn off when another resource owns ESC/P.
Config.ReturnFromNative = true
Config.Blur = true
Config.RefreshSeconds = 15 -- Only refresh player data while the menu is open.
Config.AllowWhileDead = true
Config.NativeMenus = {
    map = { hash = 'FE_MENU_VERSION_MP_PAUSE', component = -1 },
    settings = { hash = 'FE_MENU_VERSION_LANDING_MENU', component = -1 },
    keybinds = { hash = 'FE_MENU_VERSION_LANDING_KEYMAPPING_MENU', component = -1 }
}
Config.Theme = { accent = '#009DB0', muted = '#478991', neutral = '#7C7C7C' }
Config.Rules = {
    {
        title = 'Stay in character',
        body = 'Keep roleplay active, value your character life, and use out-of-character channels only when necessary.'
    },
    {
        title = 'No random violence',
        body = 'Every hostile action requires a valid roleplay reason and reasonable escalation.'
    },
    {
        title = 'Protect fair play',
        body = 'Exploits, duplication, combat logging, stream sniping, metagaming, and third-party advantages are prohibited.'
    },
    {
        title = 'Respect the scene',
        body = 'Allow others time to respond, follow staff directions, and report disputes after the active scene ends.'
    },
    {
        title = 'Use realistic decisions',
        body = 'Drive, communicate, commit crime, and respond to emergencies in a way that supports serious roleplay.'
    }
}
-- These are a configurable reference list. The native editor shows actual bindings.
-- Add only keys used on YOUR server. No server-specific inventory/phone assumptions.
Config.Keybinds = {
    { category = 'Menu', action = 'Pause menu', key = 'ESC / P / F10' },
    { category = 'Movement', action = 'Move', key = 'W A S D' },
    { category = 'Movement', action = 'Sprint', key = 'SHIFT' },
    { category = 'Movement', action = 'Jump', key = 'SPACE' },
    { category = 'Movement', action = 'Enter / exit vehicle', key = 'F' },
    { category = 'Communication', action = 'Chat', key = 'T' },

}

-- Custom framework? Set Framework = 'custom', then implement this server-only hook
-- in server/bridge.lua. Return nil while character data is unavailable.
-- SHBridge.Custom = function(source)
--   return { name = '...', characterId = '...', job = '...', cash = 0, bank = 0 }
-- end


-- Optional integrations. False leaves the resource fully independent.
Config.Integrations = {
    hudOverlayEvent = false, -- e.g. 'zx_interface:client:overlay'
    weatherResyncEvent = false -- e.g. 'zx_weather:server:requestSync'
}

Config.Map = {
    height = 650.0, pitch = -68.0, lod = 1.6,
    clearWeather = true,
    maxSprite = 965, maxMarkers = 1200,
    tileGrid = { x = -4140.0, y = 8400.0, size = 4500.0 }
}
-- Additional places and optional name overrides for existing blips.
-- Coordinates are GTA world units. Start empty to use actual server blips only.
Config.MapLocations = {
    -- { label = 'Hospital', category = 'Services', x = 298.0, y = -584.0, sprite = 61, color = '#60a5fa' }
}
Config.MapColors = {
    {id='purple', label='Purple', hex='#9a6bff'},
    {id='mint', label='Mint', hex='#34d399'},
    {id='cyan', label='Cyan', hex='#22d3ee'},
    {id='blue', label='Blue', hex='#60a5fa'},
    {id='pink', label='Pink', hex='#f472b6'},
    {id='red', label='Red', hex='#f87171'},
    {id='orange', label='Orange', hex='#fb923c'},
    {id='gold', label='Gold', hex='#fbbf24'}
}
-- Sprite IDs and texture names are public GTA/FiveM identifiers.
-- Only listed coordinate blips are imported. Entity blips are never imported.
-- Add public = false to keep a sprite out of the explorer.
Config.MapSprites = {
    [40]={label='Property',category='Properties',texture='radar_safehouse'},
    [52]={label='Convenience store',category='Shops',texture='radar_crim_holdups'},
    [60]={label='Police station',category='Services',texture='radar_police_station'},
    [61]={label='Hospital',category='Services',texture='radar_hospital'},
    [71]={label='Barber',category='Shops',texture='radar_barber'},
    [72]={label='Vehicle workshop',category='Transport',texture='radar_car_mod_shop'},
    [73]={label='Clothing store',category='Shops',texture='radar_clothes'},
    [75]={label='Tattoo shop',category='Shops',texture='radar_tattoo'},
    [108]={label='Bank',category='Services',texture='radar_dollar_sign'},
    [110]={label='Ammu-Nation',category='Shops',texture='radar_gun_shop'},
    [225]={label='Vehicle',category='Transport',public=false},
    [280]={label='Shared location',category='Shared',public=false},
    [357]={label='Garage',category='Transport',texture='radar_garage'},
    [361]={label='Fuel station',category='Transport'},
    [513]={label='Bus stop',category='Transport'}
}
