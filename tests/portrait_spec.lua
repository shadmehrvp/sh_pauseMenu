local threads, deleted, released, edits, messages = {}, {}, {}, {}, {}
local clock, nextPed, nextHandle, hiresFails, cloneFails = 10000, 90, 70, false, false
function CreateThread(fn) threads[#threads+1] = coroutine.create(fn) end
function Wait(ms) coroutine.yield(ms) end
function PlayerPedId() return 1 end
function GetEntityCoords() return {x=10,y=20,z=30} end
function ClonePed(ped, networked, host, blend)
    assert(ped==1 and networked==false and host==false and blend==true)
    if cloneFails then return 0 end
    nextPed=nextPed+1; return nextPed
end
function DoesEntityExist(ped) return not deleted[ped] end
function DeleteEntity(ped) assert(ped~=1); deleted[ped]=true end
function SetEntityAsMissionEntity() end
function SetEntityCollision() end
function FreezeEntityPosition() end
function SetEntityInvincible() end
function SetEntityCoordsNoOffset(ped,x,y,z) assert(ped~=1 and z==-70) end
function SetBlockingOfNonTemporaryEvents() end
function SetPedCanBeTargetted() end
function SetPedComponentVariation(ped,component,drawable) assert(ped~=1 and component==1 and drawable==0); edits[#edits+1]=ped end
function ClearPedProp(ped) assert(ped~=1) end
function RegisterPedheadshot_3(ped) assert(ped~=1); if hiresFails then return -1 end;nextHandle=nextHandle+1;return nextHandle end
function RegisterPedheadshot(ped) assert(ped~=1);nextHandle=nextHandle+1;return nextHandle end
function UnregisterPedheadshot(handle) assert(not released[handle], 'double unregister');released[handle]=true end
function IsPedheadshotValid() return true end
function IsPedheadshotReady() return true end
function GetPedheadshotTxdString(handle) return 'headshot_'..handle end
function GetGameTimer() return clock end
function SendNUIMessage(message) messages[#messages+1]=message end
local function step(thread) local ok,err=coroutine.resume(thread);assert(ok,err) end
local file=assert(io.open('client/main.lua','r'))
local source=file:read('*a');file:close()
local finish=assert(source:find('-- End portrait module',1,true))
SHPortrait=assert(load(source:sub(1,finish-1)..'\nreturn SHPortrait'))()
SHPortrait.Capture(function()return true end)
local first=threads[#threads];step(first);step(first)
assert(messages[#messages].url=='https://nui-img/headshot_71/headshot_71?v=10000')
assert(not deleted[91], 'retain clone until texture released')
SHPortrait.Clear();assert(deleted[91] and released[71]);SHPortrait.Clear()
hiresFails=true
SHPortrait.Capture(function()return true end)
local fallback=threads[#threads];step(fallback);step(fallback)
assert(messages[#messages].url:find('headshot_72',1,true));SHPortrait.Clear()
-- A cancelled capture must never release a newer job's clone or texture.
SHPortrait.Capture(function()return true end)
local cancelled=threads[#threads];step(cancelled);SHPortrait.Clear();assert(deleted[93])
SHPortrait.Capture(function()return true end)
local newer=threads[#threads];step(newer);step(cancelled);assert(not deleted[94]);step(newer)
SHPortrait.Clear();assert(deleted[94] and released[73])
cloneFails=true
local count=#messages
SHPortrait.Capture(function()return true end);step(threads[#threads]);assert(#messages==count)
assert(#edits==4)
print('PASS: high-resolution headshot, local unmasked clone, original ped untouched, fallback, cancelled jobs, idempotent cleanup')
