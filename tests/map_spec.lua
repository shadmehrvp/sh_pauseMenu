local threads,handlers,messages,cameras,removed={}, {}, {}, {}, {}
local clock,wp=10000,nil
local rendered,focus=false,nil
local concealed={}
local radarHidden=true
function IsRadarHidden()return radarHidden end
function DisplayRadar(show)radarHidden=not show end
local blips={ [100]={sprite=61,kind=4}, [101]={sprite=61,kind=2}, [102]={sprite=480,kind=4}, [103]={sprite=225,kind=4} }
local function vec(x,y,z)return {x=x,y=y,z=z or 0}end
function PlayerId()return 1 end
function PlayerPedId()return 11 end
function GetVehiclePedIsIn()return 0 end
function GetEntityCoords()return vec(200,-900,30)end
function GetEntityHeading()return 0 end
function GetGameTimer()return clock end
function GetClockHours()return 12 end
function GetClockMinutes()return 0 end
function GetNameOfZone()return 'PBOX'end
function GetLabelText()return 'Pillbox Hill'end
function GetStreetNameAtCoord()return 1 end
function GetStreetNameFromHashKey()return 'Power St'end
function CreateThread(fn)threads[#threads+1]=coroutine.create(fn)end
function Wait()coroutine.yield()end
function SetTimeout()end
function RegisterNetEvent(name,fn)handlers[name]=fn end
function AddEventHandler(name,fn)handlers[name]=fn end
function TriggerServerEvent()end
function SendNUIMessage(m)messages[#messages+1]=m end
function GetCurrentResourceName()return 'sh_pauseMenu'end
function GetFirstBlipInfoId(s)if s==8 then return wp and 8 or 0 end;for id=100,103 do if blips[id].sprite==s then return id end end;return 0 end
function GetNextBlipInfoId(s)return s==61 and 101 or 0 end
function DoesBlipExist(id)return (id==8 and wp~=nil) or blips[id]~=nil end
function GetBlipInfoIdCoord(id)return id==8 and wp or vec(300,-1000,30) end
function GetBlipInfoIdType(id)return blips[id].kind end
function GetBlipInfoIdEntityIndex(id)return id==101 and 13 or 0 end
function GetBlipInfoIdDisplay()return 2 end
function GetBlipAlpha()return 255 end
function GetBlipHudColour()return 1 end
function GetHudColour()return 255,255,255 end
function GetPrevWeatherTypeHashName()return 1 end
function GetHashKey(s)return s=='CLEAR' and 1 or 2 end
function GetGameplayCamRot()return vec(0,0,0)end
function GetGroundZFor_3dCoord()return true,30 end
function CreateCam()local id=#cameras+1;cameras[id]={};return id end
function SetCamFarClip(_,distance)assert(distance==50000)end
function SetCamActive()end
function RenderScriptCams(value)rendered=value end
function DoesCamExist(id)return not removed[id]end
function DestroyCam(id)removed[id]=true end
function SetCamCoord(id,x,y,z)cameras[id].pos=vec(x,y,z)end
function SetCamRot(id,x,y,z)cameras[id].rot=vec(x,y,z)end
function SetCamFov()end
function GetActiveScreenResolution()return 3440,1440 end
function SetFocusPosAndVel(x,y,z)focus=vec(x,y,z)end
function ClearFocus()focus=nil end
function GetFrameTime()return .016 end
function GetGamePool(pool)return pool=='CPed' and {11,13} or pool=='CVehicle' and {12} or {14} end
function SetEntityLocallyInvisible(entity)concealed[entity]=(concealed[entity] or 0)+1 end
function HideHudComponentThisFrame()end
function GetGpsBlipRouteLength()return 400 end
function GetPosAlongGpsTypeRoute(fromPlayer,d,slot)assert(slot==0,'Only the user waypoint route is sampled');if fromPlayer then return false,nil end;return true,vec(200+d,-900,30)end
function SetNewWaypoint(x,y)wp=vec(x,y,30)end
function SetWaypointOff()wp=nil end
function HasStreamedTextureDictLoaded()return true end
for _,name in ipairs({'RequestStreamedTextureDict','SetStreamedTextureDictAsNoLongerNeeded','SetMicrophonePosition','OverrideLodscaleThisFrame','ClearOverrideWeather','SetCloudsAlpha','SetOverrideWeather','SetWeatherTypeNowPersist'})do _G[name]=function()end end
dofile('config.lua')
local file=assert(io.open('client/main.lua'));local code=file:read('*a');file:close()
local start=assert(code:find('-- sh_pauseMenu map engine.',1,true))
local finish=assert(code:find('-- End independent map module',start,true))
local Map=assert(load(code:sub(start,finish-1)..'\nreturn SHMap'))()
local function call(name,data)local result,answered;Map.Request(name,data or {},function(v)result=v;answered=true end);assert(answered);return result end
assert(call('waypoint',{x=1,y=2})==false)
local opened=assert(Map.Start());assert(opened.ok and rendered and Map.IsActive())
assert(Map.Start()==false)
assert(cameras[1].pos.z>500)
assert(not radarHidden,'Keep GTA GPS calculation enabled behind the hidden map HUD')
assert(#opened.message.frame.markers==1 and opened.message.frame.markers[1].id=='b100','Only known fixed public locations are exposed')
for _,id in ipairs({11,12,13,14})do assert(concealed[id]==1,'Hide all entities before the first camera frame')end
local loop=threads[#threads]
assert(coroutine.resume(loop));assert(focus and messages[#messages].action=='mapUpdate')
assert(call('pan',{dx=0/0,dy=1,height=1080})==false)
assert(call('zoom',{factor=0})==false)
assert(call('pick',{u=-1,v=.5})==false)
assert(call('pick',{u=.5,v=.5}).x)
assert(call('waypoint',{x=600,y=-900}));clock=clock+2100;assert(coroutine.resume(loop))
assert(#messages[#messages].message.route>2,'GPS native points are forwarded to the UI')
assert(call('tour',{on=true}));assert(call('pan',{dx=20,dy=30,height=1080}));assert(call('street',{x=100,y=-800})==false,'Street-level scouting is blocked')
for _=1,15 do assert(call('zoom',{factor=5})) end
assert(call('rotate',{dx=0,dy=3000}))
for _=1,100 do clock=clock+16;assert(coroutine.resume(loop)) end
local cam=cameras[1];assert(cam.rot.x<=-55,'Camera stays aerial even after repeated rotate input')
assert(math.abs(cam.pos.z-30)>=147,'Repeated zoom cannot reach street level')
for _,id in ipairs({11,12,13,14})do assert(concealed[id]>100,'Entity suppression is repeated each rendered frame')end
assert(call('mode',{mode='2d'}));assert(not rendered and removed[1])
assert(call('mode',{mode='3d'}));assert(#cameras==2 and rendered)
assert(call('clear'));assert(not wp)
Map.Stop();assert(not rendered and not Map.IsActive() and removed[2] and not focus)
assert(radarHidden,'Restore the radar setting after leaving the map')
assert(call('waypoint',{x=1,y=2})==false)
print('PASS: public-place filtering, entity concealment, camera bounds, native GPS, 2D/3D and cleanup')
