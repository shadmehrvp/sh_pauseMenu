SHBridge = {}

local function started(name)
    return GetResourceState(name) == 'started'
end

function SHBridge.Detect()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if started(Config.Resources.qbox) then return 'qbox' end
    if started(Config.Resources.qb) then return 'qb' end
    if started(Config.Resources.esx) then return 'esx' end
    return 'standalone'
end

-- Adapter contract: {name, characterId, job, cash, bank}; nil = not loaded.
-- Do not return license/Steam/Discord identifiers to the NUI.
SHBridge.Custom = function(source)
    return nil -- Replace for your framework; see README_FA.md.
end

local function fromQB(data)
    if not data then return nil end
    local info = data.charinfo or {}
    local name = ((info.firstname or '') .. ' ' .. (info.lastname or '')):match('^%s*(.-)%s*$')
    local job = data.job or {}
    local money = data.money or {}
    return {
        name = name ~= '' and name or data.name,
        characterId = data.citizenid,
        job = job.label or job.name,
        cash = money.cash,
        bank = money.bank
    }
end

function SHBridge.GetPlayer(source)
    local framework = SHBridge.Detect()
    if framework == 'custom' then return SHBridge.Custom(source), framework end
    if framework == 'qbox' then
        local player = exports[Config.Resources.qbox]:GetPlayer(source)
        return fromQB(player and player.PlayerData), framework
    end
    if framework == 'qb' then
        local core = exports[Config.Resources.qb]:GetCoreObject()
        local player = core.Functions.GetPlayer(source)
        return fromQB(player and player.PlayerData), framework
    end
    if framework == 'esx' then
        local core = exports[Config.Resources.esx]:getSharedObject()
        local player = core.GetPlayerFromId(source)
        if not player then return nil, framework end
        local job = player.getJob and player.getJob() or player.job or {}
        local bank = player.getAccount and player.getAccount('bank') or nil
        return {
            name = player.getName and player.getName() or player.name,
            -- ESX has no universal citizen ID. Show session ID, never license.
            characterId = tostring(source),
            job = job.label or job.name,
            cash = player.getMoney and player.getMoney() or nil,
            bank = bank and bank.money
        }, framework
    end
    return { name = GetPlayerName(source), characterId = tostring(source) }, 'standalone'
end
