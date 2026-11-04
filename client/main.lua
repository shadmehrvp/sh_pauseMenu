-- Begin portrait module: loaded atomically with the menu entrypoint.
local SHPortrait = (function()
local SHPortrait = {}
local current

function SHPortrait.Clear()
    local job = current
    current = nil
    if not job then return end
    if job.handle and job.handle >= 0 then pcall(UnregisterPedheadshot, job.handle) end
    if job.ped and DoesEntityExist(job.ped) then pcall(DeleteEntity, job.ped) end
end

function SHPortrait.Capture(isCurrent)
    SHPortrait.Clear()
    local job = {}
    current = job
    CreateThread(function()
        if current ~= job then return end
        if not isCurrent() then SHPortrait.Clear(); return end
        local ok, clone = pcall(ClonePed, PlayerPedId(), false, false, true)
        if not ok or not clone or clone == 0 then
            if current == job then SHPortrait.Clear() end
            return
        end
        job.ped = clone
        -- Only a local duplicate is edited. Never remove the player's real mask.
        SetEntityAsMissionEntity(clone, true, true)
        SetEntityCollision(clone, false, false)
        FreezeEntityPosition(clone, true)
        SetEntityInvincible(clone, true)
        local coords = GetEntityCoords(PlayerPedId())
        SetEntityCoordsNoOffset(clone, coords.x, coords.y, coords.z - 100.0, false, false, false)
        SetBlockingOfNonTemporaryEvents(clone, true)
        SetPedCanBeTargetted(clone, false)
        SetPedComponentVariation(clone, 1, 0, 0, 0)
        ClearPedProp(clone, 0) -- Hat/helmet.
        ClearPedProp(clone, 1) -- Glasses.
        Wait(100) -- Let the cloned face and clothing finish updating.
        if current ~= job then return end
        if not isCurrent() then SHPortrait.Clear(); return end

        local highResolution = RegisterPedheadshot_3 or RegisterPedheadshot3
        local function highRes(ped)
            if highResolution then return highResolution(ped) end
            return Citizen.InvokeNative(0xBA8805A1108A2515, ped, Citizen.ResultAsInteger())
        end
        for _, register in ipairs({highRes, RegisterPedheadshot}) do
            local success, handle = pcall(register, clone)
            if success and type(handle) == 'number' and handle >= 0 then
                job.handle = handle
                local deadline = GetGameTimer() + 3000
                while current == job and isCurrent() and GetGameTimer() < deadline do
                    if IsPedheadshotValid(handle) and IsPedheadshotReady(handle) then
                        local txd = GetPedheadshotTxdString(handle)
                        if type(txd) == 'string' and txd ~= '' then
                            SendNUIMessage({action = 'portrait', url = ('https://nui-img/%s/%s?v=%d'):format(txd, txd, GetGameTimer())})
                            return -- Keep the texture and its local ped alive until close.
                        end
                    end
                    Wait(30)
                end
                if current ~= job then return end
                UnregisterPedheadshot(handle)
                job.handle = nil
            end
            if not isCurrent() then break end
        end
        if current == job then SHPortrait.Clear() end
    end)
end

return SHPortrait
end)()
-- End portrait module

-- sh_pauseMenu map engine. Original implementation using public FiveM natives.
local SHMap = (function()
    local api, opened, camera, version = {}, false, nil, 0
    local pose, target, markers, route, saved, received = nil, nil, {}, {}, {}, {}
    local callbacks, serial, tiles, waypointKey = {}, 0, {}, ''
    local tour, weather, lastRouteAt = nil, nil, 0
    local routeRevision,lastPublishedRoute=0,-1
    local radarWasHidden
    -- The explorer is a map, never a close-range spectator camera.
    local minimumHeight, maximumPitch = 180.0, -55.0
    local function valid(n) return type(n)=='number' and n==n and math.abs(n)<1000000 end
    local function limit(n,a,b) return math.max(a,math.min(b,n)) end
    local function location(d) return type(d)=='table' and valid(d.x) and valid(d.y) and math.abs(d.x)<=10000 and math.abs(d.y)<=10000 end
    local function ground(x,y,fallback)
        local found,z=GetGroundZFor_3dCoord(x+0.0,y+0.0,1500.0,false)
        if found then return z end
        if GetHeightmapTopZForPosition then return GetHeightmapTopZForPosition(x+0.0,y+0.0) end
        return fallback or 30.0
    end
    local function emit(message) SendNUIMessage({action='mapUpdate',message=message}) end
    local function player()
        local ped=PlayerPedId()
        local p=GetEntityCoords(ped)
        local zone=GetLabelText(GetNameOfZone(p.x,p.y,p.z))
        local street=GetStreetNameAtCoord(p.x,p.y,p.z)
        local veh=GetVehiclePedIsIn(ped,false)
        return {x=p.x,y=p.y,z=p.z,heading=GetEntityHeading(veh~=0 and veh or ped),
            zone=zone~='NULL' and zone or 'Los Santos',street=GetStreetNameFromHashKey(street)}
    end
    local function waypoint()
        local b=GetFirstBlipInfoId(8)
        if not DoesBlipExist(b) then return false end
        local p=GetBlipInfoIdCoord(b)
        return {x=p.x,y=p.y,z=ground(p.x,p.y,p.z)}
    end
    local function scan()
        local list={}
        for sprite=11,Config.Map.maxSprite do
            local b,seen=GetFirstBlipInfoId(sprite),{}
            while DoesBlipExist(b) and not seen[b] and #list<Config.Map.maxMarkers do
                seen[b]=true
                local info=Config.MapSprites[sprite]
                -- Only explicitly registered, coordinate-based public places.
                -- Entity blips and unknown sprites can expose player tracking.
                if info and info.public ~= false and GetBlipInfoIdType(b)==4
                    and GetBlipInfoIdEntityIndex(b)==0 and GetBlipInfoIdDisplay(b)~=0 and GetBlipAlpha(b)>0 then
                    local p=GetBlipInfoIdCoord(b)
                    if valid(p.x) and valid(p.y) and (p.x~=0 or p.y~=0) then
                        local name,category=info.label or ('Map marker '..sprite),info.category or 'Other'
                        for _,custom in ipairs(Config.MapLocations) do
                            if (p.x-custom.x)^2+(p.y-custom.y)^2<((custom.radius or 30)^2) then name,category=custom.label,custom.category or category;break end
                        end
                        local r,g,blue=GetHudColour(GetBlipHudColour(b))
                        list[#list+1]={id='b'..b,sprite=sprite,label=name,category=category,x=p.x,y=p.y,z=ground(p.x,p.y,p.z),
                            color=('#%02x%02x%02x'):format(r or 255,g or 255,blue or 255),texture=info.texture}
                    end
                end
                b=GetNextBlipInfoId(sprite)
            end
        end
        for i,p in ipairs(Config.MapLocations) do
            local copy={id='c'..i,label=p.label,category=p.category or 'Services',x=p.x,y=p.y,z=ground(p.x,p.y,p.z),color=p.color or '#9a6bff',sprite=p.sprite or 1}
            list[#list+1]=copy
        end
        return list
    end
    local function readRoute()
        routeRevision=routeRevision+1
        local destination=waypoint()
        if not destination then route={};return end
        local length=GetGpsBlipRouteLength()
        local maximum=length and length>0 and math.min(length,30000) or 16000
        local step=math.max(12,maximum/220)
        local points={}
        -- An off-road player projection can fail even when the next road node
        -- has a valid route. Stay in waypoint slot 0; never borrow mission GPS.
        for _,fromPlayer in ipairs({true,false}) do
            local sampled={}
            for distance=0,maximum,step do
                local ok,p=GetPosAlongGpsTypeRoute(fromPlayer,distance,0)
                if not ok or ok==0 or not p or not valid(p.x) or not valid(p.y) or (p.x==0 and p.y==0) then
                    if #sampled>0 or distance>step*3 then break end
                else
                    local previous=sampled[#sampled]
                    if previous and (previous.x-p.x)^2+(previous.y-p.y)^2<0.25 then break end
                    sampled[#sampled+1]={x=p.x,y=p.y,z=p.z}
                end
            end
            if #sampled>=2 then points=sampled;break end
        end
        if #points>=2 then route=points else route={} end
    end
    local function angles(s)
        local yaw=math.rad(s.yaw)
        local tilt=math.rad(s.pitch)
        local sy,cy,st,ct=math.sin(yaw),math.cos(yaw),math.sin(tilt),math.cos(tilt)
        return {-sy*ct,cy*ct,st},{cy,sy,0},{sy*st,-cy*st,ct}
    end
    local function cameraPosition()
        local forward=angles(pose)
        return pose.x-forward[1]*pose.distance,pose.y-forward[2]*pose.distance,pose.z-forward[3]*pose.distance
    end
    local function concealMapEntities()
        -- Frame-local only: never change network visibility, collision or alpha.
        for _,pool in ipairs({'CPed','CVehicle','CObject'}) do
            for _,entity in ipairs(GetGamePool(pool)) do SetEntityLocallyInvisible(entity) end
        end
    end
    local function stopCamera()
        if not camera then return end
        local old=camera;camera=nil;tour=nil
        RenderScriptCams(false,false,0,true,false)
        if DoesCamExist(old) then DestroyCam(old,false) end
        ClearFocus()
        SetMicrophonePosition(false,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0)
        if weather then
            ClearOverrideWeather();SetCloudsAlpha(1.0)
            for _,name in ipairs({'EXTRASUNNY','CLEAR','CLOUDS','OVERCAST','RAIN','THUNDER','FOGGY','SMOG','CLEARING','NEUTRAL','SNOW','BLIZZARD','SNOWLIGHT','XMAS','HALLOWEEN'}) do
                if GetHashKey(name)==weather then SetWeatherTypeNowPersist(name);break end
            end
            weather=nil
            if Config.Integrations.weatherResyncEvent then TriggerServerEvent(Config.Integrations.weatherResyncEvent) end
        end
    end
    local function startCamera()
        if camera then return end
        local p=player()
        pose={x=p.x,y=p.y,z=ground(p.x,p.y,p.z),distance=math.max(minimumHeight,Config.Map.height),pitch=limit(Config.Map.pitch,-89,maximumPitch),yaw=GetGameplayCamRot(2).z}
        target={};for k,v in pairs(pose) do target[k]=v end
        camera=CreateCam('DEFAULT_SCRIPTED_CAMERA',false)
        SetCamFov(camera,50.0);SetCamFarClip(camera,50000.0)
        SetCamCoord(camera,cameraPosition());SetCamRot(camera,pose.pitch,0.0,pose.yaw,2)
        concealMapEntities() -- Protect the first rendered frame as well.
        SetCamActive(camera,true);RenderScriptCams(true,false,0,true,false)
        if Config.Map.clearWeather then weather=GetPrevWeatherTypeHashName() end
    end
    local function loadTiles(token)
        tiles={}
        CreateThread(function()
            local loaded={}
            for row=0,2 do for col=0,1 do
                if not opened or version~=token then return end
                local name=('minimap_sea_%d_%d'):format(row,col)
                RequestStreamedTextureDict(name,false)
                local deadline=GetGameTimer()+1500
                while not HasStreamedTextureDictLoaded(name) and GetGameTimer()<deadline and opened and version==token do Wait(25) end
                if HasStreamedTextureDictLoaded(name) then
                    loaded[#loaded+1]={row=row,col=col,url=('https://nui-img/%s/%s'):format(name,name)}
                end
            end end
            if opened and version==token then tiles=loaded;emit({type='tiles',tiles=tiles}) end
        end)
    end
    local function liveShared()
        local list={}
        for i=#received,1,-1 do
            local p=received[i]
            if p.expires<GetGameTimer() then
                if DoesBlipExist(p.blip) then RemoveBlip(p.blip) end
                table.remove(received,i)
            else list[#list+1]={id='shared'..p.blip,x=p.x,y=p.y,label=p.label,category='Shared',from=p.from,color='#e7e3ee'} end
        end
        return list
    end
    local function snapshot(full)
        local frame={type='frame',player=player(),waypoint=waypoint(),touring=tour~=nil}
        if full or routeRevision~=lastPublishedRoute then frame.route=route;lastPublishedRoute=routeRevision end
        if camera then
            local x,y,z=cameraPosition()
            frame.camera={x=x,y=y,z=z,pitch=pose.pitch,yaw=pose.yaw,fov=50,distance=pose.distance}
        else frame.camera=false end
        if full then frame.markers=markers;frame.places=saved;frame.shared=liveShared() end
        return frame
    end
    function api.IsActive() return opened end
    function api.Start()
        if opened then return false end
        opened=true;version=version+1
        local token=version
        -- A HUD integration may persistently disable the radar. GTA then stops
        -- calculating GPS samples. Enable calculation while keeping its UI hidden
        -- with the pause menu's existing HideHudAndRadarThisFrame loop.
        radarWasHidden=IsRadarHidden()
        DisplayRadar(true)
        markers=scan();readRoute();startCamera();loadTiles(token)
        RequestStreamedTextureDict('blips',false)
        CreateThread(function()
            local nextUpdate,nextScan,nextWeather=0,GetGameTimer()+5000,0
            while opened and version==token do
                local now=GetGameTimer()
                DisplayRadar(true)
                if camera then
                    if tour then
                        tour.elapsed=tour.elapsed+math.min(GetFrameTime(),0.05)
                        local at=1+tour.elapsed/tour.duration*(#route-1)
                        if at>=#route then tour=nil else
                            local a,b=route[math.floor(at)],route[math.floor(at)+1]
                            local ratio=at%1
                            target.x=a.x+(b.x-a.x)*ratio;target.y=a.y+(b.y-a.y)*ratio
                            target.distance=300;target.pitch=-65
                            target.yaw=math.deg(math.atan(-(b.x-a.x),b.y-a.y))
                        end
                    end
                    local blend=1-math.exp(-math.min(GetFrameTime(),0.05)*10)
                    target.z=ground(target.x,target.y,target.z)
                    for _,key in ipairs({'x','y','z','distance','pitch'}) do pose[key]=pose[key]+(target[key]-pose[key])*blend end
                    pose.yaw=pose.yaw+((target.yaw-pose.yaw+180)%360-180)*blend
                    SetCamCoord(camera,cameraPosition());SetCamRot(camera,pose.pitch,0.0,pose.yaw,2)
                    SetFocusPosAndVel(pose.x,pose.y,pose.z,0.0,0.0,0.0)
                    OverrideLodscaleThisFrame(Config.Map.lod)
                    local ped=PlayerPedId();local p=GetEntityCoords(ped)
                    SetMicrophonePosition(true,p.x,p.y,p.z,p.x,p.y,p.z,p.x,p.y,p.z)
                    concealMapEntities()
                    HideHudComponentThisFrame(19) -- Weapon wheel / live target UI.
                    if weather and now>=nextWeather then nextWeather=now+1000;SetOverrideWeather('EXTRASUNNY');SetCloudsAlpha(0.0) end
                end
                if now>=nextUpdate then
                    nextUpdate=now+33
                    local wp=waypoint();local key=wp and ('%.1f:%.1f'):format(wp.x,wp.y) or ''
                    if key~=waypointKey or (wp and now-lastRouteAt>2000) then waypointKey=key;lastRouteAt=now;readRoute() end
                    local full=now>=nextScan
                    if full then nextScan=now+5000;markers=scan() end
                    emit(snapshot(full))
                end
                Wait(camera and 0 or 100)
            end
        end)
        return {ok=true,message={type='open',serverName=Config.ServerName,frame=snapshot(true),colors=Config.MapColors,tiles=tiles,tileGrid=Config.Map.tileGrid}}
    end
    function api.Stop()
        opened=false;version=version+1;stopCamera()
        if radarWasHidden~=nil then DisplayRadar(not radarWasHidden);radarWasHidden=nil end
        for _,t in ipairs(tiles) do SetStreamedTextureDictAsNoLongerNeeded(('minimap_sea_%d_%d'):format(t.row,t.col)) end
        tiles={}
        SetStreamedTextureDictAsNoLongerNeeded('blips')
        for id,cb in pairs(callbacks) do callbacks[id]=nil;cb(false) end
    end
    local function serverRequest(name,data,cb)
        serial=serial+1;local id=serial;callbacks[id]=cb
        TriggerServerEvent('sh_pauseMenu:mapRequest',id,name,data)
        SetTimeout(5000,function() if callbacks[id] then local answer=callbacks[id];callbacks[id]=nil;answer(false) end end)
    end
    RegisterNetEvent('sh_pauseMenu:mapResponse',function(id,result)
        if source~=65535 or not callbacks[id] then return end
        if type(result)=='table' and result.ok and type(result.places)=='table' then saved=result.places end
        local cb=callbacks[id];callbacks[id]=nil;cb(result)
    end)
    RegisterNetEvent('sh_pauseMenu:sharedGps',function(d)
        if source~=65535 or not location(d) then return end
        local blip=AddBlipForCoord(d.x+0.0,d.y+0.0,30.0)
        SetBlipSprite(blip,280);SetBlipColour(blip,7)
        BeginTextCommandSetBlipName('STRING');AddTextComponentSubstringPlayerName(tostring(d.from or 'Player').."'s GPS");EndTextCommandSetBlipName(blip)
        received[#received+1]={x=d.x,y=d.y,label=tostring(d.label or 'Waypoint'),from=tostring(d.from or 'Player'),blip=blip,expires=GetGameTimer()+600000}
        SendNUIMessage({action='mapNotice',text='GPS shared by '..tostring(d.from or 'Player')})
    end)
    function api.Request(name,d,cb)
        if not opened or type(d)~='table' then cb(false);return end
        if name=='placesList' or name=='placesAdd' or name=='placesDelete' then serverRequest(name,d,cb);return end
        if name=='mode' then if d.mode=='2d' then stopCamera() else startCamera() end
        elseif name=='waypoint' then if not location(d) then cb(false);return end;SetNewWaypoint(d.x+0.0,d.y+0.0);lastRouteAt=0
        elseif name=='clear' then SetWaypointOff();route={};routeRevision=routeRevision+1;tour=nil
        elseif name=='pick' then
            if not camera or not valid(d.u) or not valid(d.v) or d.u<0 or d.u>1 or d.v<0 or d.v>1 then cb(false);return end
            local forward,right,up=angles(pose);local x,y,z=cameraPosition();local w,h=GetActiveScreenResolution()
            local scale=math.tan(math.rad(25));local u=(2*d.u-1)*scale*w/h;local v=(1-2*d.v)*scale
            local dx,dy,dz=forward[1]+right[1]*u+up[1]*v,forward[2]+right[2]*u+up[2]*v,forward[3]+up[3]*v
            if dz>=-0.01 then cb(false);return end
            local distance=(pose.z-z)/dz;local px,py=x+dx*distance,y+dy*distance
            for _=1,2 do distance=(ground(px,py,pose.z)-z)/dz;px,py=x+dx*distance,y+dy*distance end
            cb(location({x=px,y=py}) and {x=px,y=py} or false);return
        elseif name=='pan' or name=='rotate' then
            if not camera or not valid(d.dx) or not valid(d.dy) or math.abs(d.dx)>5000 or math.abs(d.dy)>5000 then cb(false);return end
            tour=nil
            if name=='rotate' then target.yaw=(target.yaw-d.dx/4)%360;target.pitch=limit(target.pitch+d.dy/5,-89,maximumPitch)
            else
                if not valid(d.height) or d.height<100 then cb(false);return end
                local scale=pose.distance*math.tan(math.rad(25))*2/d.height;local yaw=math.rad(pose.yaw)
                local dy=d.dy/math.max(.3,-math.sin(math.rad(pose.pitch)))
                target.x=limit(target.x-scale*(math.cos(yaw)*d.dx+math.sin(yaw)*dy),-4500,5000)
                target.y=limit(target.y+scale*(-math.sin(yaw)*d.dx+math.cos(yaw)*dy),-5000,8500)
            end
        elseif name=='zoom' then
            if not camera or not valid(d.factor) or d.factor<.2 or d.factor>5 then cb(false);return end
            tour=nil;target.distance=limit(target.distance/d.factor,minimumHeight,6000)
        elseif name=='fly' or name=='street' or name=='recenter' then
            if not camera or name=='street' then cb(false);return end
            if name=='recenter' then d=player() elseif not location(d) then cb(false);return end
            tour=nil;target.x,target.y=d.x,d.y
            target.distance=math.max(minimumHeight,Config.Map.height);target.pitch=limit(Config.Map.pitch,-89,maximumPitch)
        elseif name=='tour' then
            if not camera or #route<2 then cb(false);return end
            tour=d.on==true and {elapsed=0,duration=limit(#route/10,8,22)} or nil
        elseif name=='shareGps' then
            if not location(d) or (d.to~='near' and d.to~='job') then cb(false);return end
            TriggerServerEvent('sh_pauseMenu:shareGps',d)
        else cb(false);return end
        cb(true)
    end
    CreateThread(function() while true do Wait(60000);liveShared() end end)
    AddEventHandler('onResourceStop',function(name)
        if name~=GetCurrentResourceName() then return end
        api.Stop();for _,p in ipairs(received) do if DoesBlipExist(p.blip) then RemoveBlip(p.blip) end end
    end)
    return api
end)()
-- End independent map module



local visible, nativePending, enabled = false, false, true
local ready, pendingOpen, generation = false, false, 0
local ignoreUntil, blurActive = 0, false
local preferences = { opacity = 64, blur = Config.Blur, sound = true, reducedMotion = false }

local saved = GetResourceKvpString('sh_pauseMenu:preferences:v1')
if saved then
    local ok, decoded = pcall(json.decode, saved)
    if ok and type(decoded) == 'table' then
        preferences.opacity = math.max(45, math.min(90, tonumber(decoded.opacity) or 64))
        for _, key in ipairs({ 'blur', 'sound', 'reducedMotion' }) do
            if type(decoded[key]) == 'boolean' then preferences[key] = decoded[key] end
        end
    end
end

local function blur(toggle)
    if toggle and not blurActive then TriggerScreenblurFadeIn(180.0); blurActive = true end
    if not toggle and blurActive then TriggerScreenblurFadeOut(180.0); blurActive = false end
end

local function clearHeadshot()
    SHPortrait.Clear()
end

local function hudOverlay(active)
    if Config.Integrations.hudOverlayEvent then TriggerEvent(Config.Integrations.hudOverlayEvent, 'sh_pauseMenu', active) end
end

local function playSound(name)
    if preferences.sound then PlaySoundFrontend(-1, name, 'HUD_FRONTEND_DEFAULT_SOUNDSET', true) end
end

local function closeMenu(silent)
    if not visible and not pendingOpen then return false end
    generation = generation + 1
    visible, pendingOpen = false, false
    SHMap.Stop()
    hudOverlay(false)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
    blur(false)
    clearHeadshot()
    ignoreUntil = GetGameTimer() + 350
    if not silent then playSound('BACK') end
    TriggerEvent('sh_pauseMenu:visibility', false)
    return true
end

local function portrait(token)
    SHPortrait.Capture(function() return token == generation and visible end)
end

local function openMenu()
    if not enabled or visible or nativePending or IsPauseMenuActive() or IsNuiFocused() then return false end
    if not NetworkIsSessionStarted() then return false end
    if not Config.AllowWhileDead and IsEntityDead(PlayerPedId()) then return false end
    if not ready then pendingOpen = true; return false end
    generation = generation + 1
    visible = true
    hudOverlay(true)
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    blur(preferences.blur)
    SendNUIMessage({ action = 'open', preferences = preferences, language = Config.Language, name = GetPlayerName(PlayerId()) })
    TriggerServerEvent('sh_pauseMenu:request')
    portrait(generation)
    playSound('SELECT')
    TriggerEvent('sh_pauseMenu:visibility', true)
    return true
end

local function openNative(kind)
    local menu = Config.NativeMenus[kind]
    if not menu or nativePending then return false end
    closeMenu(true)
    nativePending = true
    CreateThread(function()
        Wait(80) -- release CEF input before handing focus to Rockstar frontend
        ActivateFrontendMenu(GetHashKey(menu.hash), false, menu.component or -1)
        local deadline = GetGameTimer() + 3500
        local appeared = false
        while GetGameTimer() < deadline do
            if IsPauseMenuActive() then appeared = true; break end
            Wait(30)
        end
        if appeared then
            while IsPauseMenuActive() do Wait(100) end
        end
        Wait(300)
        nativePending = false
        ignoreUntil = GetGameTimer() + 350
        if Config.ReturnFromNative and enabled then
            openMenu()
            if not appeared then
                SendNUIMessage({ action = 'error', key = 'nativeFailed' })
            end
        end
    end)
    return true
end

local registerNui = RegisterNuiCallback or RegisterNUICallback
registerNui('ready', function(_, cb)
    ready = true
    cb({ ok = true })
    if pendingOpen then pendingOpen = false; openMenu() end
end)
registerNui('close', function(_, cb) closeMenu(); cb({ ok = true }) end)
registerNui('mapOpen', function(_,cb)
    if not visible or nativePending then cb({ok=false}); return end
    local ok,result=pcall(SHMap.Start)
    if not ok or not result then SHMap.Stop(); cb({ok=false}); return end
    blur(false)
    cb(result)
end)
registerNui('mapClose', function(_,cb)
    SHMap.Stop()
    if visible then blur(preferences.blur) end
    cb({ok=true})
end)
registerNui('mapAction', function(data,cb)
    if not visible or type(data)~='table' then return cb(false) end
    local answered=false
    local function answer(result) if not answered then answered=true;cb(result) end end
    local ok,err=pcall(SHMap.Request,data.name,data.data or {},answer)
    if not ok then print('[sh_pauseMenu] Map callback: '..tostring(err));answer(false) end
end)
registerNui('native', function(data, cb)
    if not visible or type(data) ~= 'table' then cb({ ok = false }); return end
    cb({ ok = openNative(data.kind) })
end)
registerNui('refresh', function(_, cb)
    if visible then TriggerServerEvent('sh_pauseMenu:request') end
    cb({ ok = true })
end)
registerNui('preferences', function(data, cb)
    if type(data) ~= 'table' then cb({ ok = false }); return end
    preferences.opacity = math.max(45, math.min(90, tonumber(data.opacity) or preferences.opacity))
    for _, key in ipairs({ 'blur', 'sound', 'reducedMotion' }) do
        if type(data[key]) == 'boolean' then preferences[key] = data[key] end
    end
    SetResourceKvp('sh_pauseMenu:preferences:v1', json.encode(preferences))
    if visible then blur(preferences.blur and not SHMap.IsActive()) end
    cb({ ok = true })
end)
registerNui('disconnect', function(_, cb)
    if not visible then cb({ ok = false }); return end
    cb({ ok = true })
    closeMenu(true)
    TriggerServerEvent('sh_pauseMenu:disconnect')
end)

RegisterNetEvent('sh_pauseMenu:data', function(data)
    -- Server-origin event only; local scripts should use the documented exports.
    if source ~= 65535 or not visible or type(data) ~= 'table' then return end
    local coords = GetEntityCoords(PlayerPedId())
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    local street = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    data.location = { zone = zone ~= 'NULL' and zone or 'Los Santos', street = GetStreetNameFromHashKey(street) }
    SendNUIMessage({ action = 'data', payload = data })
end)

RegisterCommand(Config.Command, function()
    if visible then closeMenu() else openMenu() end
end, false)
RegisterKeyMapping(Config.Command, 'Open pause menu', 'keyboard', Config.OpenKey)

exports('Open', openMenu)
exports('Close', function() closeMenu(true) end)
exports('IsOpen', function() return visible end)
exports('SetEnabled', function(value)
    enabled = value == true
    if not enabled then closeMenu(true) end
end)

CreateThread(function()
    while true do
        -- One cheap frame loop is needed to intercept ESC without a stock-menu flash.
        if visible then
            DisableAllControlActions(0)
            DisableAllControlActions(1)
            DisableAllControlActions(2)
            DisablePlayerFiring(PlayerId(), true)
            HideHudAndRadarThisFrame()
        elseif Config.InterceptPause and enabled and not nativePending and not IsPauseMenuActive() and not IsNuiFocused() then
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            if GetGameTimer() > ignoreUntil and (IsDisabledControlJustReleased(0, 200) or IsDisabledControlJustReleased(0, 199)) then
                openMenu()
            end
        end
        Wait(0)
    end
end)

CreateThread(function()
    local interval = math.max(5, tonumber(Config.RefreshSeconds) or 15) * 1000
    while true do
        Wait(interval)
        if visible then TriggerServerEvent('sh_pauseMenu:request') end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        -- Do not steal another resource's focus if our menu is closed.
        if visible then SetNuiFocus(false, false); SetNuiFocusKeepInput(false) end
        SHMap.Stop()
        hudOverlay(false)
        blur(false)
        clearHeadshot()
    end
end)
