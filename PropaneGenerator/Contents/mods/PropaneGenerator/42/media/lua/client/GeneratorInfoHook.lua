-- ====================================================================
-- GeneratorInfoHook.lua - Перехват окна информации о генераторе
-- Версия: 1.2 (Без вмешательства в действие)
-- ====================================================================

local function debugPrint(message)
    if ENABLE_DEBUG_PRINTS then
        print("[GEN_INFO] " .. tostring(message))
    end
end

debugPrint("Zagruzka modulya perekhvata okna informacii o generatore")

-- Спрайты для определения типа
local PROPANE_SPRITE = "appliances_misc_01_5"
local GASOLINE_SPRITES = {
    "appliances_misc_01_4",
    "appliances_misc_01_6",
    "appliances_misc_01_7"
}

-- ====================================================================
-- ФУНКЦИИ ДЛЯ ПОЛУЧЕНИЯ ПАРАМЕТРОВ ГЕНЕРАТОРА
-- ====================================================================

local function getPropaneGeneratorStats()
    return {
        name = getText("Tooltip_Generator_PropaneName"),
        conditionChance = 40,
        soundRadius = 15
    }
end

local function getOldGeneratorStats()
    return {
        name = getText("Tooltip_Generator_GasolineName"),
        conditionChance = 25,
        soundRadius = 25
    }
end

local function getGeneratorTypeBySprite(generator)
    if not generator then return nil end
    local sprite = generator:getSprite()
    if not sprite then return nil end
    local spriteName = sprite:getName()
    
    if spriteName == PROPANE_SPRITE then
        return "PROPANE"
    end
    
    for _, s in ipairs(GASOLINE_SPRITES) do
        if spriteName == s then
            return "GASOLINE"
        end
    end
    
    return nil
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
    
    -- Определяем тип генератора по спрайту
    local generatorType = getGeneratorTypeBySprite(object)
    if not generatorType then
        return baseText
    end
    
    local isPropane = (generatorType == "PROPANE")
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
    text = text .. getText("Tooltip_Generator_Type") .. " " .. stats.name .. " <LINE> "
    text = text .. getText("Tooltip_Generator_Reliability") .. stats.conditionChance .. " <LINE> "
    text = text .. getText("Tooltip_Generator_Noise") .. " " .. stats.soundRadius .. " <LINE> "
    
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
        local generatorType = getGeneratorTypeBySprite(object)
        if generatorType then
            local isPropane = (generatorType == "PROPANE")
            local stats = isPropane and getPropaneGeneratorStats() or getOldGeneratorStats()
            self.panel:setName(stats.name)
        end
    end
end

debugPrint("Modul perekhvata okna informacii o generatore zagruzhen")

-- Inicializaciya
Events.OnGameStart.Add(function()
    debugPrint("Perekhvat okna informacii aktivirovan")
end)