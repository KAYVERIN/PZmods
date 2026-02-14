-- ====================================================================
-- PropaneGeneratorDebug.lua - Тестовый перехватчик всех TimedActions
-- Включается только при ENABLE_DEBUG_PRINTS = true
-- ====================================================================

local function initDebugHooks()
    -- Проверяем, включена ли отладка
    if not ENABLE_DEBUG_PRINTS then
        print("[DEBUG] Otladka otklyuchena, perekhvatchiki ne aktivirovany")
        return
    end

    print("==========================================================")
    print("ZAPUSK MONITORINGA VSEH TimedActions")
    print("==========================================================")
    
    -- Сохраняем оригинальную функцию добавления в очередь
    local originalTimedActionAdd = ISTimedActionQueue.add
    
    -- Переопределяем добавление действий в очередь
    ISTimedActionQueue.add = function(action)
        if action then
            -- Получаем имя класса действия
            local actionName = "Unknown"
            local mt = getmetatable(action)
            
            -- Пытаемся определить имя разными способами
            if mt and mt.__index then
                if type(mt.__index) == "table" then
                    -- Проверяем наличие __name
                    if mt.__index.__name then
                        actionName = mt.__index.__name
                    else
                        -- Пытаемся найти имя по ключу в _G
                        for k, v in pairs(_G) do
                            if v == mt.__index then
                                actionName = k
                                break
                            end
                        end
                        if actionName == "Unknown" then
                            actionName = tostring(mt.__index)
                        end
                    end
                elseif type(mt.__index) == "function" then
                    -- Пытаемся получить имя через debug.getinfo
                    local info = debug.getinfo(mt.__index)
                    if info then
                        actionName = info.name or "anonymous"
                    end
                end
            end
            
            -- Альтернативный способ: проверяем по __index напрямую
            if action.__index then
                for k, v in pairs(_G) do
                    if v == action.__index then
                        actionName = k
                        break
                    end
                end
            end
            
            -- Проверяем конкретные известные типы действий
            if action.__index == ISMoveablesAction then
                actionName = "ISMoveablesAction"
            elseif action.__index == ISPlaceCursorAction then
                actionName = "ISPlaceCursorAction"
            elseif action.__index == ISInventoryTransferAction then
                actionName = "ISInventoryTransferAction"
            elseif action.__index == ISUnequipAction then
                actionName = "ISUnequipAction"
            elseif action.__index == ISAddPropaneToGenerator then
                actionName = "ISAddPropaneToGenerator (PROPAN MOD)"
            end
            
            -- Получаем информацию о предмете, если есть
            local itemInfo = ""
            if action.item then
                if type(action.item) == "table" and action.item.getType then
                    itemInfo = ", predmet: " .. tostring(action.item:getType())
                else
                    itemInfo = ", predmet: " .. tostring(action.item)
                end
            end
            
            -- Информация о генераторе
            local generatorInfo = ""
            if action.generator then
                if type(action.generator) == "table" and action.generator.getSquare then
                    local square = action.generator:getSquare()
                    if square then
                        generatorInfo = ", generator na: " .. square:getX() .. "," .. square:getY() .. "," .. square:getZ()
                    else
                        generatorInfo = ", generator (bez square)"
                    end
                end
            end
            
            -- Информация о пропановом баллоне
            local tankInfo = ""
            if action.propaneTank then
                tankInfo = ", propanovyi ballon"
            end
            
            -- Режим действия (для ISMoveablesAction)
            local modeInfo = ""
            if action.mode then
                modeInfo = ", mode: " .. tostring(action.mode)
            end
            
            -- Контейнеры (для ISInventoryTransferAction)
            local containerInfo = ""
            if action.srcContainer and action.destContainer then
                local srcType = "unknown"
                local destType = "unknown"
                
                if type(action.srcContainer) == "table" then
                    if action.srcContainer.getType then
                        srcType = action.srcContainer:getType()
                    elseif action.srcContainer == action.character:getInventory() then
                        srcType = "inventory"
                    end
                end
                
                if type(action.destContainer) == "table" then
                    if action.destContainer.getType then
                        destType = action.destContainer:getType()
                    elseif action.destContainer == action.character:getInventory() then
                        destType = "inventory"
                    end
                end
                
                containerInfo = ", " .. srcType .. " -> " .. destType
            end
            
            -- Формируем полную строку
            local fullInfo = itemInfo .. generatorInfo .. tankInfo .. modeInfo .. containerInfo
            
            -- Определяем важность действия
            local isImportant = false
            if action.item then
                if type(action.item) == "table" and action.item.getType then
                    local itemType = action.item:getType()
                    if itemType == "Generator_Old" or itemType == "Generator_Old_Propane" then
                        isImportant = true
                    end
                end
            end
            
            -- Выводим информацию
            local prefix = isImportant and "!!! VAShNO !!! " or "    "
            print(prefix .. "DEYSTVIE: " .. actionName .. fullInfo)
            
            -- Для важных действий показываем максимум информации
            if isImportant then
                print("      Polnaya informaciya o deystvii:")
                for k, v in pairs(action) do
                    if type(v) ~= "function" and type(v) ~= "table" then
                        print("        " .. tostring(k) .. " = " .. tostring(v))
                    elseif type(v) == "table" and v.getType then
                        print("        " .. tostring(k) .. " = " .. tostring(v:getType()))
                    end
                end
                
                -- Показываем ModData предмета
                if action.item and type(action.item) == "table" and action.item.getModData then
                    print("        ModData predmeta:")
                    local modData = action.item:getModData()
                    for mk, mv in pairs(modData) do
                        print("          " .. tostring(mk) .. " = " .. tostring(mv))
                    end
                end
                
                print("      ----------------------------------")
            end
        end
        
        -- Вызываем оригинальную функцию
        return originalTimedActionAdd(action)
    end
    
    print("MONITORING TimedActions AKTIVIROVAN (ENABLE_DEBUG_PRINTS = true)")
    print("==========================================================")
end

-- Запускаем при старте игры
Events.OnGameStart.Add(initDebugHooks)

print("[DEBUG] PropaneGeneratorDebug.lua ZAGRUZhEN (aktivirovan tolko pri ENABLE_DEBUG_PRINTS = true)")