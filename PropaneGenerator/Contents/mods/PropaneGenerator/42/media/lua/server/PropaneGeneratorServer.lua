require "PropaneGeneratorMod"

local function handleRefuel(player, generator, fuelAmount)
    -- Серверная логика заправки
    generator:setFuel(generator:getFuel() + fuelAmount)
    
    -- Синхронизируем со всеми клиентами
    generator:transmitCompleteItemToClients()
    
    -- Отправляем подтверждение игроку
    sendServerCommand(player, "PropaneGenerator", "refuelComplete", {
        generatorID = generator:getID(),
        newFuel = generator:getFuel()
    })
end

Events.OnServerCommand.Add(function(module, command, player, args)
    if module == "PropaneGenerator" then
        if command == "refuel" then
            handleRefuel(player, 
                IsoObject.getByID(args.generatorID), 
                args.fuelAmount)
        end
    end
end)