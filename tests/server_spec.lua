local states, events, responses, drops, clock, reads
local function eq(a, b, label) assert(a == b, (label or 'value') .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a)) end
local function reset()
    dofile('config.lua')
    states, events, responses, drops, clock, reads = {}, {}, {}, {}, 10000, 0
    function GetResourceState(name) return states[name] or 'missing' end
    function GetPlayerName(id) return id == 42 and 'Session Name' or nil end
    function GetPlayers() return { '42', '43', '44' } end
    function GetConvarInt(_, _) return 256 end
    function GetPlayerPing(_) return 34 end
    function GetGameTimer() return clock end
    function RegisterNetEvent(name, fn) events[name] = fn end
    function AddEventHandler(name, fn) local previous=events[name];events[name]=function(...) if previous then previous(...) end;fn(...) end end
    function TriggerClientEvent(name, target, payload) responses[#responses+1] = { event=name,target=target,data=payload } end
    function DropPlayer(target, message) drops[#drops+1] = { target=target,message=message } end
    function CreateThread(_) end
    exports = {
        ['qb-core'] = { GetCoreObject = function() return {Functions={GetPlayer=function(id)
            eq(id,42);reads=reads+1;return {PlayerData={charinfo={firstname='Alex',lastname='Morgan'},citizenid='ABC1042',job={label='Mechanic'},money={cash=2450,bank=-120}}}
        end}} end },
        qbx_core = { GetPlayer = function(_,id)
            eq(id,42);reads=reads+1;return {PlayerData={charinfo={firstname='Qbox',lastname='Player'},citizenid='QBX123',job={label='Police'},money={cash=50,bank=6000}}}
        end },
        es_extended = { getSharedObject = function() return {GetPlayerFromId=function(id)
            eq(id,42);reads=reads+1;return {getName=function()return 'ESX Character'end,getJob=function()return {label='Taxi'}end,getMoney=function()return 75 end,getAccount=function(kind)eq(kind,'bank');return {money=800}end,identifier='license:NEVER_EXPOSE'}
        end} end }
    }
    dofile('server/bridge.lua'); dofile('server/main.lua'); source=42
end
local function request() events['sh_pauseMenu:request'](); return responses[#responses].data end

reset();states['qb-core']='started';states.qbx_core='started';states.es_extended='started'
eq(SHBridge.Detect(),'qbox','Qbox has priority over QB compatibility bridge')
local p=request();eq(p.player.name,'Qbox Player');eq(p.player.idLabel,'citizen');eq(p.framework,'qbox');eq(p.online,3);eq(p.maxPlayers,256)
reset();states['qb-core']='started';p=request();eq(p.player.name,'Alex Morgan');eq(p.player.cash,2450);eq(p.player.bank,-120);eq(p.player.idLabel,'citizen')
request();eq(reads,1,'rapid refresh must use cache');eq(#responses,2,'rapid reopen must still get response')
clock=clock+1001;request();eq(reads,2)
events.playerDropped();request();eq(reads,3,'disconnect clears rate/cache state')
reset();states.es_extended='started';p=request();eq(p.player.name,'ESX Character');eq(p.player.bank,800);eq(p.player.idLabel,'session');eq(p.player.characterId,'42');eq(p.player.identifier,nil,'never disclose platform identifiers')
reset();p=request();eq(p.framework,'standalone');eq(p.player.cash,false);eq(p.player.bank,false);eq(p.player.name,'Session Name')
reset();Config.Framework='custom';SHBridge.Custom=function(id)eq(id,42);return {name='<script>alert(1)</script>',cash='900',bank=0/0,job='Custom job',characterId=123}end
p=request();eq(p.player.name,'<script>alert(1)</script>','text is escaped by NUI, not interpreted');eq(p.player.cash,900);eq(p.player.bank,false,'reject NaN');eq(p.player.characterId,'123')
reset();Config.Framework='custom';SHBridge.Custom=function()error('test adapter failure')end;p=request();eq(p.player.cash,false);eq(p.player.name,'Session Name','adapter failure remains usable')
reset();Config.Framework='qb';exports['qb-core'].GetCoreObject=function()return {Functions={GetPlayer=function()return nil end}}end;p=request();eq(p.player.cash,false,'character not loaded does not become fake zero')
reset();events['sh_pauseMenu:disconnect'](9999);eq(#drops,1);eq(drops[1].target,42,'cannot disconnect another player');events['sh_pauseMenu:disconnect']();eq(#drops,1,'disconnect rate limit')
source=0;events['sh_pauseMenu:request']();eq(#responses,0,'ignore console/no player')
print('PASS: adapter selection, QB/Qbox/ESX/custom/standalone profiles, unloaded characters, failure fallback, numeric validation, cache/rate limits, identifier privacy, self-only disconnect')
