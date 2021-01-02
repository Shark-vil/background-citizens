-- Creates files with preset points for maps:
-- gm_bigcity_improved
-- rp_southside
bgCitizens.loadPresets = true

-- NPC classes that fill the streets
bgCitizens.npc_classes = {
    {
        class = 'npc_citizen',
        type = 'citizen',
        fullness = 85,
        team = { 'residents' },
        weapons = {'weapon_pistol', 'weapon_357'},
        money = { 0, 250 }, -- does nothing yet
        at_damage = {
            ['fear'] = 90,
            ['defense'] = 10,
        },
        at_protect = {
            ['fear'] = 99,
            ['defense'] = 1,
        }
    },
    {
        class = 'npc_citizen',
        type = 'gangster',
        fullness = 5,
        team = { 'bandits' },
        weapons = {'weapon_pistol', 'weapon_357', 'weapon_shotgun', 'weapon_smg1'},
        money = { 0, 500 }, -- does nothing yet
        at_damage = {
            ['defense'] = 100,
        },
        at_protect = {
            ['ignore'] = 99,
            ['defense'] = 1,
        }
    },
    {
        class = 'npc_metropolice',
        type = 'police',
        fullness = 10,
        team = { 'residents', 'police' },
        weapons = {'weapon_smg1', 'weapon_pistol'},
        money = { 0, 600 }, -- does nothing yet
        at_damage = {
            ['defense'] = 100,
        },
        at_protect = {
            ['defense'] = 100,
        }
    }
}

hook.Add('bgCitizens_PreSpawnNPC', 'bgCitizensSetCustomModelFromNPC', function(npc, data)
    if data.type == 'gangster' then
        npc:SetKeyValue('citizentype', 3)
    elseif data.type == 'citizen' then
        if math.random(0, 10) > 5 then
            npc:SetKeyValue('citizentype', 2)
        end
    end
end)

hook.Add("bgCitizens_OnKilledActor", "bgCitizensDropMoney", function(actor)
    if engine.ActiveGamemode() ~= 'darkrp' then return end

    local data = actor:GetData()
    local npc = actor:GetNPC()

    if IsValid(npc) then
        local pos = npc:GetPos()
        if data.money ~= nil then
            local money = math.random(data.money[1], data.money[2])
            -- next update
        end
    end
end)