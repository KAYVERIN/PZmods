-- ====================================================================
-- PropaneGeneratorPickup.lua - Замена с поддержкой других модов
-- Версия: 2.1 (сохраняет возможность для других модов)
-- ====================================================================

require "PropaneGeneratorMod"

debugPrint("[PICKUP] ======== ZAGRUZKA MODULYA PICKUP ========")

-- Создаем цепочку функций
local completeChain = {}

-- Добавляем нашу функцию в цепочку
table.insert(completeChain, function(self)
    debugPrint("[PICKUP] Nasha logika (osnovnaya)")
    
    -- Проверяем, наш ли это генератор
    local isOurGenerator = false
    if self.generator then
        local sprite = self.generator:getSprite()
        if sprite then
            local spriteName = sprite:getName()
            local oldSprites = {
                "appliances_misc_01_4", "appliances_misc_01_5",
                "appliances_misc_01_6", "appliances_misc_01_7"
            }
            
            for _, sprite in ipairs(oldSprites) do
                if spriteName == sprite then
                    isOurGenerator = true
                    break
                end
            end
        end
    end
    
    -- Если не наш генератор - пропускаем
    if not isOurGenerator then
        debugPrint("[PICKUP] Eto ne nash generator, propuskaem")
        return nil -- nil означает "не обработано"
    end
    
    debugPrint("[PICKUP] Eto nash generator, obrabatyvaem")
    
    -- НАША ПОЛНАЯ ЛОГИКА
    forceDropHeavyItems(self.character)
    
    -- Получаем данные
    local mData = self.generator:getModData()
    local isPropane = mData.isPropaneGenerator == true
    local itemType = isPropane and "Base." .. GENERATOR_PROPANE or "Base." .. GENERATOR_OLD
    
    debugPrint("[PICKUP] Sozdaem " .. (isPropane and "PROPANOVIY" or "BENZINOVIY") .. " generator: " .. itemType)
    
    -- Создаем предмет
    local item = instanceItem(itemType)
    if not item then
        debugPrint("[PICKUP] ERROR: Failed to create item")
        return false
    end
    
    -- Добавляем в инвентарь
    self.character:getInventory():AddItem(item)
    
    -- Копируем состояние
    item:setCondition(self.generator:getCondition())
    if self.generator:getFuel() > 0 then
        item:getModData()["fuel"] = self.generator:getFuel()
    end
    
    -- Копируем весь modData
    for k, v in pairs(mData) do
        item:getModData()[k] = v
    end
    
    -- Помещаем в руки
    self.character:setPrimaryHandItem(item)
    self.character:setSecondaryHandItem(item)
    
    -- Отправляем обновления
    sendAddItemToContainer(self.character:getInventory(), item)
    sendEquip(self.character)
    self.character:getInventory():setDrawDirty(true)
    
    -- Удаляем из мира
    self.generator:remove()
    
    debugPrint("[PICKUP] Gotovo")
    return true -- true означает "обработано"
end)

-- Сохраняем оригинальную функцию как последнюю в цепочке
local originalComplete = ISTakeGenerator.complete

-- Создаем новую функцию, которая проходит по цепочке
function ISTakeGenerator:complete()
    debugPrint("[PICKUP] Zapushchena ceepochka obrabotchikov")
    
    -- Проходим по всем функциям в цепочке
    for i, func in ipairs(completeChain) do
        local result = func(self)
        if result ~= nil then
            -- Если функция вернула не nil, значит она обработала вызов
            debugPrint("[PICKUP] Obrabotchik #" .. i .. " obrabotal sobytie")
            return result == true
        end
    end
    
    -- Если ни одна функция не обработала, вызываем оригинал
    debugPrint("[PICKUP] Ni odin obrabotchik ne obrabotal, vizov originala")
    if originalComplete then
        return originalComplete(self)
    end
    
    return false
end

-- Функция для других модов, чтобы добавить свой обработчик
function ISTakeGenerator.addCompleteHandler(handlerFunc)
    table.insert(completeChain, handlerFunc)
    debugPrint("[PICKUP] Dobavlen novyy obrabotchik v ceepochku")
end

debugPrint("[PICKUP] Module PropaneGeneratorPickup.lua loaded successfully!")
debugPrint("[PICKUP] Drugie mody mogut dobavit svoi obrabotchiki cherez ISTakeGenerator.addCompleteHandler()")