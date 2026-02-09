-- Серверная часть для синхронизации данных
local MOD_ID = "RemoveWasherHose"

Events.OnInitGlobalModData.Add(function(isNewGame)
    if not ModData.exists(MOD_ID) then
        ModData.add(MOD_ID, {})
    end
end)

Events.OnServerStarted.Add(function()
    ModData.transmit(MOD_ID)
end)