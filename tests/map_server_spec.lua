local events,kv,replies={}, {}, {}
local clock=10000
json={encode=function(v)return v end,decode=function(v)return v end}
Config={Resources={esx='es_extended'},MapColors={{id='purple'}}}
SHBridge={Detect=function()return 'esx'end,GetPlayer=function(id)return {name='Character '..id}end}
exports={es_extended={getSharedObject=function()return {GetPlayerFromId=function(id)return {identifier='character:'..id,getJob=function()return {name='police',onDuty=true}end}end}end}}
function GetGameTimer()return clock end
function GetPlayerName(id)return 'Player '..id end
function RegisterNetEvent(name,fn)events[name]=fn end
function AddEventHandler(name,fn)events[name]=fn end
function GetResourceKvpString(key)return kv[key] end
function SetResourceKvp(key,data)kv[key]=data end
function TriggerClientEvent(name,target,id,result)replies[#replies+1]={name=name,target=target,id=id,result=result}end
function GetPlayers()return {'42','43','44'}end
function GetPlayerRoutingBucket(id)return id==44 and 2 or 1 end
function GetPlayerPed(id)return id end
function GetEntityCoords(id)return {x=id==43 and 1 or 0,y=0,z=30}end
local file=assert(io.open('server/main.lua','r'));local sourceCode=file:read('*a');file:close()
local start=assert(sourceCode:find('-- Character-owned saved places',1,true))
assert(load(sourceCode:sub(start)))()
local serial=0
local function request(src,name,data)
 source=src;serial=serial+1;clock=clock+200;events['sh_pauseMenu:mapRequest'](serial,name,data or {});return replies[#replies].result
end
assert(#request(42,'placesList').places==0)
local r=request(42,'placesAdd',{label='Home',color='purple',x=100,y=200});assert(r.ok and #r.places==1 and r.places[1].color=='purple')
assert(#request(43,'placesList').places==0,'saved places are owned by the actual character')
request(43,'placesDelete',{id=1});assert(#request(42,'placesList').places==1,'another player cannot delete the owner\'s places')
assert(not request(42,'placesAdd',{label='Bad',color='purple',x=0/0,y=100}).ok)
assert(not request(42,'placesAdd',{label='Bad',color='other',x=100,y=100}).ok)
request(42,'placesDelete',{id=1});assert(#request(42,'placesList').places==0)
source=42;clock=clock+4000;local before=#replies
events['sh_pauseMenu:shareGps']({to='near',x=100,y=200,label='Waypoint'})
assert(#replies==before+1 and replies[#replies].target==43,'GPS sharing respects distance and routing buckets')
events['sh_pauseMenu:shareGps']({to='near',x=100,y=200});assert(#replies==before+1,'GPS sharing is rate limited')
print('PASS: character-owned saved places, persistence, color and coordinate validation, sharing distance, buckets and rate limits')
