local lastRequest, lastDisconnect, cachedData = {}, {}, {}
local warned = {}

local function cleanText(value, fallback, limit)
    if type(value) ~= 'string' and type(value) ~= 'number' then return fallback end
    local text = tostring(value):gsub('%c', '')
    return text ~= '' and text:sub(1, limit or 100) or fallback
end

local function money(value)
    local n = tonumber(value)
    -- Unknown is JSON false, not a misleading zero. Negative balances are allowed.
    if not n or n ~= n or n == math.huge or n == -math.huge then return false end
    return math.floor(n)
end

local function publicConfig()
    return {
        language = Config.Language,
        serverName = Config.ServerName,
        description = Config.ServerDescription,
        currency = Config.Currency,
        discord = Config.DiscordUrl,
        website = Config.WebsiteUrl,
        rules = Config.Rules,
        keybinds = Config.Keybinds,
        theme = Config.Theme
    }
end

RegisterNetEvent('sh_pauseMenu:request', function()
    local src = source
    if src <= 0 or not GetPlayerName(src) then return end
    local now = GetGameTimer()
    if lastRequest[src] and now - lastRequest[src] < 1000 then
        -- Rapid close/reopen still gets a response; core reads are rate limited.
        if cachedData[src] then TriggerClientEvent('sh_pauseMenu:data', src, cachedData[src]) end
        return
    end
    lastRequest[src] = now
    local ok, profile, framework = pcall(SHBridge.GetPlayer, src)
    if not ok then
        framework = SHBridge.Detect()
        if not warned[framework] then
            print(('[sh_pauseMenu] Adapter %s failed: %s. Check your core resource name/version.'):format(framework, tostring(profile)))
            warned[framework] = true
        end
        profile = nil
    end
    profile = type(profile) == 'table' and profile or {}
    local max = Config.MaxPlayers > 0 and Config.MaxPlayers or GetConvarInt('sv_maxclients', 48)
    local payload = {
        config = publicConfig(),
        player = {
            name = cleanText(profile.name, GetPlayerName(src)),
            characterId = cleanText(profile.characterId, tostring(src), 40),
            idLabel = (framework == 'qb' or framework == 'qbox') and 'citizen' or 'session',
            job = cleanText(profile.job, false),
            cash = money(profile.cash),
            bank = money(profile.bank)
        },
        online = #GetPlayers(), maxPlayers = max,
        ping = GetPlayerPing(src), framework = framework or 'standalone'
    }
    cachedData[src] = payload
    TriggerClientEvent('sh_pauseMenu:data', src, payload)
end)

-- No target ID from client. A player can only disconnect themselves.
RegisterNetEvent('sh_pauseMenu:disconnect', function()
    local src = source
    if src <= 0 or not GetPlayerName(src) then return end
    local now = GetGameTimer()
    if lastDisconnect[src] and now - lastDisconnect[src] < 2000 then return end
    lastDisconnect[src] = now
    DropPlayer(src, Config.DisconnectMessage)
end)

AddEventHandler('playerDropped', function()
    lastRequest[source], lastDisconnect[source], cachedData[source] = nil, nil, nil
end)

CreateThread(function()
    Wait(1000)
    print(('[sh_pauseMenu] Started | adapter: %s | /%s | no database required'):format(SHBridge.Detect(), Config.Command))
end)

-- Character-owned saved places and GPS sharing for the independent map UI.
local mapRate, shareRate = {}, {}
local mapColors = {}
for _,color in ipairs(Config.MapColors) do mapColors[color.id]=true end
local function mapFinite(n) return type(n)=='number' and n==n and n~=math.huge and n~=-math.huge end
local function mapXY(d) return mapFinite(d.x) and mapFinite(d.y) and math.abs(d.x)<=10000 and math.abs(d.y)<=10000 end
local function mapCharacter(src)
    if SHBridge.Detect()=='esx' then
        local esx=exports[Config.Resources.esx]:getSharedObject()
        local p=esx.GetPlayerFromId(src)
        return p and p.identifier
    end
    if SHBridge.Detect()=='qb' then
        local p=exports[Config.Resources.qb]:GetCoreObject().Functions.GetPlayer(src)
        return p and p.PlayerData and p.PlayerData.citizenid
    end
    if SHBridge.Detect()=='qbox' then
        local p=exports[Config.Resources.qbox]:GetPlayer(src)
        return p and p.PlayerData and p.PlayerData.citizenid
    end
    return GetPlayerIdentifierByType(src,'license')
end
local function mapKey(src)
    local id=mapCharacter(src)
    -- The key stays on the server; identifiers are never returned to the browser.
    return id and ('sh_pauseMenu:map:places:'..id) or nil
end
local function mapPlaces(key)
    local raw=GetResourceKvpString(key)
    if not raw then return {} end
    local ok,list=pcall(json.decode,raw)
    return ok and type(list)=='table' and list or {}
end
RegisterNetEvent('sh_pauseMenu:mapRequest',function(id,name,d)
    local src=source
    if src<=0 or not GetPlayerName(src) or type(id)~='number' or id%1~=0 or id<1 or id>1e9 then return end
    if type(d)~='table' or (name~='placesList' and name~='placesAdd' and name~='placesDelete') then return end
    local now=GetGameTimer()
    if mapRate[src] and now-mapRate[src]<150 then TriggerClientEvent('sh_pauseMenu:mapResponse',src,id,{ok=false,err='wait'});return end
    mapRate[src]=now
    local key=mapKey(src)
    if not key then TriggerClientEvent('sh_pauseMenu:mapResponse',src,id,false);return end
    local list=mapPlaces(key)
    if name=='placesAdd' then
        if #list>=30 then TriggerClientEvent('sh_pauseMenu:mapResponse',src,id,{ok=false,err='full'});return end
        local label=type(d.label)=='string' and d.label:gsub('%c',''):match('^%s*(.-)%s*$') or ''
        if not mapXY(d) or label=='' or #label>160 or not mapColors[d.color] then TriggerClientEvent('sh_pauseMenu:mapResponse',src,id,{ok=false});return end
        local nextId=0
        for _,p in ipairs(list) do nextId=math.max(nextId,tonumber(p.id) or 0) end
        table.insert(list,1,{id=nextId+1,label=label,color=d.color,x=d.x,y=d.y})
        SetResourceKvp(key,json.encode(list))
    elseif name=='placesDelete' then
        if not mapFinite(d.id) then TriggerClientEvent('sh_pauseMenu:mapResponse',src,id,{ok=false});return end
        for i=#list,1,-1 do if list[i].id==d.id then table.remove(list,i) end end
        SetResourceKvp(key,json.encode(list))
    end
    TriggerClientEvent('sh_pauseMenu:mapResponse',src,id,{ok=true,places=list})
end)
local function mapJob(src)
    if SHBridge.Detect()=='esx' then
        local p=exports[Config.Resources.esx]:getSharedObject().GetPlayerFromId(src)
        local j=p and (p.getJob and p.getJob() or p.job)
        return j and j.name or '',j and j.onDuty~=false
    end
    local p
    if SHBridge.Detect()=='qb' then p=exports[Config.Resources.qb]:GetCoreObject().Functions.GetPlayer(src)
    elseif SHBridge.Detect()=='qbox' then p=exports[Config.Resources.qbox]:GetPlayer(src) end
    local j=p and p.PlayerData and p.PlayerData.job
    return j and j.name or '',j and j.onduty~=false
end
RegisterNetEvent('sh_pauseMenu:shareGps',function(d)
    local src=source
    if src<=0 or not GetPlayerName(src) or type(d)~='table' or not mapXY(d) or (d.to~='near' and d.to~='job') then return end
    local now=GetGameTimer()
    if shareRate[src] and now-shareRate[src]<3000 then return end
    shareRate[src]=now
    local ped=GetPlayerPed(src)
    if not ped or ped==0 then return end
    local pos=GetEntityCoords(ped)
    local job,duty=mapJob(src)
    local profile=SHBridge.GetPlayer(src)
    local from=profile and profile.name or GetPlayerName(src)
    local label=type(d.label)=='string' and d.label:gsub('%c',''):sub(1,80) or 'Waypoint'
    for _,sid in ipairs(GetPlayers()) do
        local target=tonumber(sid)
        if target and target~=src and GetPlayerRoutingBucket(target)==GetPlayerRoutingBucket(src) then
            local send=false
            if d.to=='job' then
                local other,onDuty=mapJob(target)
                send=duty and onDuty and job~='' and job~='unemployed' and other==job
            else
                local otherPed=GetPlayerPed(target)
                if otherPed and otherPed~=0 then
                    local p=GetEntityCoords(otherPed)
                    send=(p.x-pos.x)^2+(p.y-pos.y)^2+(p.z-pos.z)^2<=30^2
                end
            end
            if send then TriggerClientEvent('sh_pauseMenu:sharedGps',target,{from=from,label=label,x=d.x,y=d.y}) end
        end
    end
end)
AddEventHandler('playerDropped',function() mapRate[source],shareRate[source]=nil,nil end)
