function SetStreamedTextureDictAsNoLongerNeeded() end
local handlers,callbacks,commands,api,threads,messages,events={},{},{},{},{},{},{}
local focused,clock,blurred,unregistered=false,10000,false,0
local function eq(a,b,label)assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a))end
dofile('config.lua')
function GetResourceKvpString()return nil end
function GetGameTimer()return clock end
function SetNuiFocus(value)focused=value end
function SetNuiFocusKeepInput()end
function SendNUIMessage(data)messages[#messages+1]=data end
function TriggerScreenblurFadeIn()blurred=true end
function TriggerScreenblurFadeOut()blurred=false end
function UnregisterPedheadshot()unregistered=unregistered+1 end
function PlaySoundFrontend()end
function TriggerEvent(name,value)events[#events+1]={name,value}end
function IsPauseMenuActive()return false end
function IsNuiFocused()return focused end
function NetworkIsSessionStarted()return true end
function IsEntityDead()return false end
function PlayerPedId()return 1 end
function PlayerId()return 1 end
function GetPlayerName()return 'Player' end
function TriggerServerEvent(name)events[#events+1]={name}end
function RegisterNuiCallback(name,fn)callbacks[name]=fn end
function RegisterNetEvent(name,fn)handlers[name]=fn end
function RegisterCommand(name,fn)commands[name]=fn end
function RegisterKeyMapping()end
function CreateThread(fn)threads[#threads+1]=coroutine.create(fn)end
function Wait(ms)coroutine.yield(ms)end
function SetResourceKvp(_,value)api.saved=value end
json={encode=function(value)return value end,decode=function(value)return value end}
function GetCurrentResourceName()return 'sh_pauseMenu'end
function AddEventHandler(name,fn)handlers[name]=fn end
function RegisterPedheadshot()return 12 end
function IsPedheadshotValid()return true end
function IsPedheadshotReady()return true end
function GetPedheadshotTxdString()return 'mp_headshot_0' end
function GetHashKey(value)return value end
function ActivateFrontendMenu(...)api.native={...}end
function GetEntityCoords()return {x=0,y=0,z=0}end
function GetNameOfZone()return 'PBOX'end
function GetLabelText()return 'Pillbox Hill'end
function GetStreetNameAtCoord()return 77 end
function GetStreetNameFromHashKey()return 'Power St'end
exports=setmetatable({}, {__call=function(_,name,fn)api[name]=fn end})
-- Start only the real entrypoint, without a separately loaded portrait global.
SHPortrait=nil
function ClonePed(ped,networked,host,blend)assert(ped==1 and not networked and not host and blend);return 99 end
function DoesEntityExist(ped)return ped==99 end
function DeleteEntity(ped)assert(ped==99)end
function SetEntityAsMissionEntity()end
function SetEntityCollision()end
function FreezeEntityPosition()end
function SetEntityInvincible()end
function SetEntityCoordsNoOffset(ped)assert(ped==99)end
function SetBlockingOfNonTemporaryEvents()end
function SetPedCanBeTargetted()end
function SetPedComponentVariation(ped,component,drawable)assert(ped==99 and component==1 and drawable==0)end
function ClearPedProp(ped)assert(ped==99)end
function RegisterPedheadshot_3(ped)assert(ped==99);return 12 end
local resourceStates={}
function GetResourceState(name)return resourceStates[name] or 'missing'end
dofile('client/main.lua')
local function call(name,payload)
    local reply,called;callbacks[name](payload or {},function(v)reply=v;called=true end)
    assert(called,'every callback must resolve: '..name);return reply
end
eq(api.Open(),false,'open before NUI ready is deferred');eq(focused,false)
call('ready');eq(api.IsOpen(),true);eq(focused,true);eq(blurred,true)
local portraitThread=threads[#threads];assert(coroutine.resume(portraitThread));assert(coroutine.resume(portraitThread));eq(messages[#messages].action,'portrait');eq(SHPortrait,nil,'portrait implementation is local to the entrypoint')
call('preferences',{opacity=999,blur=false,sound=false,reducedMotion=true});eq(api.saved.opacity,90,'clamp client preference');eq(blurred,false)
source=8;local before=#messages;handlers['sh_pauseMenu:data']({player={}});eq(#messages,before,'ignore forged local data event')
source=65535;handlers['sh_pauseMenu:data']({player={}});eq(messages[#messages].payload.location.zone,'Pillbox Hill')
eq(call('native',{kind='arbitrary'}).ok,false,'native whitelist')
eq(call('native',{kind='map'}).ok,true);eq(focused,false,'native handoff releases CEF');eq(api.IsOpen(),false);eq(unregistered,1,'native handoff frees mugshot')
local nativeThread=threads[#threads];assert(coroutine.resume(nativeThread));assert(coroutine.resume(nativeThread));eq(api.native[1],'FE_MENU_VERSION_MP_PAUSE');eq(api.native[3],-1)
clock=clock+4000;assert(coroutine.resume(nativeThread));clock=clock+300;assert(coroutine.resume(nativeThread));eq(api.IsOpen(),true,'failed native restores menu instead of trapping player')
api.SetEnabled(false);eq(api.Open(),false,'disabled menus cannot reopen')
api.SetEnabled(true);api.Open();call('close');eq(api.IsOpen(),false);eq(focused,false);eq(unregistered,1)
-- Closing an already closed menu must not steal another NUI's input focus.
focused=true;api.Close();eq(focused,true,'closed-menu Close must preserve other resource focus');focused=false
api.Open();local stop=handlers.onResourceStop;stop('different_resource');eq(api.IsOpen(),true);stop('sh_pauseMenu');eq(focused,false);eq(blurred,false)
print('PASS: startup handshake, focus lifecycle, native whitelist/handoff, headshot cleanup, local settings bounds, server-event guard, disable export, resource-stop cleanup')


