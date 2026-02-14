-- ====================================================================
-- GeneratorInfoHook.lua - Перехват окна информации о генераторе
-- Версия: 1.2 (Без вмешательства в действие)
-- ====================================================================

local function debugPrint(message)
    print("[GEN_INFO] " .. tostring(message))
end

debugPrint("Загрузка модуля перехвата окна информации о генераторе")

-- ====================================================================
-- ФУНКЦИИ ДЛЯ ПОЛУЧЕНИЯ ПАРАМЕТРОВ ГЕНЕРАТОРА
-- ====================================================================

local function getPropaneGeneratorStats()
    return {
        name = "Propanovyi generator",
        conditionChance = 40,
        soundRadius = 15
    }
end

local function getOldGeneratorStats()
    return {
        name = "Benzinovyi generator",
        conditionChance = 25,
        soundRadius = 25
    }
end

local function isPropaneGenerator(generator)
    if not generator then return false end
    local modData = generator:getModData()
    return modData.isPropaneGenerator == true
end

-- ====================================================================
-- СОХРАНЯЕМ ОРИГИНАЛЬНЫЕ ФУНКЦИИ
-- ====================================================================

if not ISGeneratorInfoWindow.originalGetRichText then
    ISGeneratorInfoWindow.originalGetRichText = ISGeneratorInfoWindow.getRichText
end

if not ISGeneratorInfoWindow.originalSetObject then
    ISGeneratorInfoWindow.originalSetObject = ISGeneratorInfoWindow.setObject
end

-- ====================================================================
-- МОДИФИЦИРОВАННЫЙ МЕТОД GETRICHTEXT
-- ====================================================================

function ISGeneratorInfoWindow.getRichText(object, displayStats)
    -- Защита от nil объекта
    if not object then
        return ""
    end
    
    -- Получаем базовый текст
    local baseText = ISGeneratorInfoWindow.originalGetRichText(object, displayStats)
    
    if not displayStats then
        return baseText
    end
    
    -- Проверяем, генератор ли это
    local isGenerator = false
    if object.getSprite then
        local sprite = object:getSprite()
        if sprite then
            local spriteName = sprite:getName()
            local generatorSprites = {
                "appliances_misc_01_4", "appliances_misc_01_5",
                "appliances_misc_01_6", "appliances_misc_01_7"
            }
            for _, s in ipairs(generatorSprites) do
                if spriteName == s then
                    isGenerator = true
                    break
                end
            end
        end
    end
    
    if not isGenerator then
        return baseText
    end
    
    -- Безопасно получаем тип
    local isPropane = false
    local success, result = pcall(function()
        return isPropaneGenerator(object)
    end)
    if success then
        isPropane = result
    end
    
    local stats = isPropane and getPropaneGeneratorStats() or getOldGeneratorStats()
    
    -- Безопасно получаем значения
    local fuel = 0
    local condition = 0
    local successFuel, resultFuel = pcall(function() return object:getFuelPercentage() end)
    if successFuel then
        fuel = math.ceil(resultFuel)
    end
    
    local successCond, resultCond = pcall(function() return object:getCondition() end)
    if successCond then
        condition = resultCond
    end
    
    -- Формируем текст
    local text = getText("IGUI_Generator_FuelAmount", fuel) .. " <LINE> "
    text = text .. getText("IGUI_Generator_Condition", condition) .. " <LINE> "
    text = text .. "Tip: " .. stats.name .. " <LINE> "
    text = text .. "Nadezhnost': 1/" .. stats.conditionChance .. " <LINE> "
    text = text .. "Shum: radius " .. stats.soundRadius .. " <LINE> "
    
    if object:isActivated() then
        text = text .. " <LINE> " .. getText("IGUI_PowerConsumption") .. ": <LINE> "
        text = text .. " <INDENT:10> "
        local items = object:getItemsPowered()
        for i=0, items:size()-1 do
            text = text .. "   " .. items:get(i) .. " <LINE> "
        end
        text = text .. getText("IGUI_Generator_TypeGas") .. " (" .. object:getBasePowerConsumptionString() .. ") <LINE> "
        text = text .. getText("IGUI_Total") .. ": " .. object:getTotalPowerUsingString() .. " <LINE> "
    end
    
    local square = object:getSquare()
    if square and not square:isOutside() and square:getBuilding() then
        text = text .. " <LINE> <RED> " .. getText("IGUI_Generator_IsToxic")
    end
    
    return text
end

-- ====================================================================
-- МОДИФИЦИРОВАННЫЙ МЕТОД SETOBJECT
-- ====================================================================

function ISGeneratorInfoWindow:setObject(object)
    -- Защита от nil объекта
    if not object then
        return
    end
    
    -- Вызываем оригинальный метод безопасно
    local success, result = pcall(function()
        self:originalSetObject(object)
    end)
    
    if not success then
        debugPrint("Error in originalSetObject: " .. tostring(result))
        return
    end
    
    -- Обновляем имя
    if self.panel then
        local isPropane = false
        local success, result = pcall(function()
            return isPropaneGenerator(object)
        end)
        if success then
            isPropane = result
        end
        
        local stats = isPropane and getPropaneGeneratorStats() or getOldGeneratorStats()
        self.panel:setName(stats.name)
    end
end

debugPrint("Модуль перехвата окна информации о генераторе загружен")

-- Инициализация
Events.OnGameStart.Add(function()
    debugPrint("Перехват окна информации активирован")
end)