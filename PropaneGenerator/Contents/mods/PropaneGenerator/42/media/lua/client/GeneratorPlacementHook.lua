-- ====================================================================
-- GeneratorPlacementHook.lua - Перехват размещения генератора
-- Версия: 1.0
-- ====================================================================

local function debugPrint(message)
    print("[GEN_PLACE] " .. tostring(message))
end

debugPrint("Загрузка модуля перехвата размещения генератора")

-- ====================================================================
-- ФУНКЦИИ ДЛЯ РАБОТЫ С ГЕНЕРАТОРАМИ
-- ====================================================================

local function isPropaneGeneratorItem(item)
    if not item then return false end
    return item:getType() == "Generator_Old_Propane"
end

-- ====================================================================
-- ПЕРЕХВАТ РАЗМЕЩЕНИЯ ГЕНЕРАТОРА
-- ====================================================================

-- Сохраняем оригинальную функцию
local originalPlaceMoveableInternal = ISMoveableSpriteProps.placeMoveableInternal

-- Переопределяем функцию
function ISMoveableSpriteProps:placeMoveableInternal(_square, _item, _spriteName)
    debugPrint("placeMoveableInternal вызван для спрайта: " .. tostring(_spriteName))
    
    -- Проверяем, является ли это генератором
    local isGenerator = false
    local generatorType = "Base.Generator_Old"  -- тип по умолчанию
    
    -- Определяем тип генератора по спрайту
    if _spriteName == "appliances_misc_01_4" or
       _spriteName == "appliances_misc_01_5" or
       _spriteName == "appliances_misc_01_6" or
       _spriteName == "appliances_misc_01_7" then
        isGenerator = true
        -- Проверяем, пропановый ли предмет в инвентаре
        if _item and isPropaneGeneratorItem(_item) then
            generatorType = "Base.Generator_Old_Propane"
            debugPrint("Размещение ПРОПАНОВОГО генератора")
        else
            debugPrint("Размещение ОБЫЧНОГО генератора")
        end
    end
    
    -- Если это не генератор, просто вызываем оригинал
    if not isGenerator then
        return originalPlaceMoveableInternal(self, _square, _item, _spriteName)
    end
    
    -- Сохраняем ModData из предмета до размещения
    local itemModData = nil
    if _item and _item:getModData() then
        itemModData = {}
        for k, v in pairs(_item:getModData()) do
            itemModData[k] = v
        end
    end
    
    -- Создаем предмет нужного типа
    local genItem = instanceItem(generatorType)
    if not genItem then
        debugPrint("ОШИБКА: не удалось создать предмет " .. generatorType)
        return originalPlaceMoveableInternal(self, _square, _item, _spriteName)
    end
    
    -- Копируем состояние из оригинального предмета
    if _item then
        -- Копируем состояние
        if _item.getCondition then
            genItem:setCondition(_item:getCondition())
        end
        
        -- Копируем топливо из ModData
        if _item:getModData() and _item:getModData().fuel then
            genItem:getModData().fuel = _item:getModData().fuel
        end
        
        -- Копируем остальные ModData
        if itemModData then
            for k, v in pairs(itemModData) do
                genItem:getModData()[k] = v
            end
        end
    end
    
    -- Создаем объект генератора
    local obj = IsoGenerator.new(genItem, getCell(), _square)
    
    if not obj then
        debugPrint("ОШИБКА: не удалось создать объект генератора")
        return originalPlaceMoveableInternal(self, _square, _item, _spriteName)
    end
    
    -- Устанавливаем спрайт
    local sprite = getSprite(_spriteName)
    if sprite then
        obj:setSprite(sprite)
    end
    
    -- Копируем ModData в объект
    local objModData = obj:getModData()
    
    -- Сначала копируем все из предмета
    if itemModData then
        for k, v in pairs(itemModData) do
            objModData[k] = v
        end
    end
    
    -- Устанавливаем важные поля
    objModData.generatorFullType = generatorType
    objModData.isPropaneGenerator = (generatorType == "Base.Generator_Old_Propane")
    objModData.fuel = genItem:getModData().fuel or 0
    
    -- Устанавливаем топливо в сам генератор
    if objModData.fuel > 0 then
        obj:setFuel(objModData.fuel)
    end
    
    debugPrint(string.format("Генератор размещен: тип=%s, топливо=%s, isPropane=%s",
               generatorType,
               tostring(objModData.fuel),
               tostring(objModData.isPropaneGenerator)))
    
    -- Добавляем объект на клетку
    _square:AddSpecialObject(obj)
    
    -- Синхронизируем
    if isClient() then obj:transmitCompleteItemToServer() end
    if isServer() then obj:transmitCompleteItemToClients() end
    
    triggerEvent("OnObjectAdded", obj)
    IsoGenerator.updateGenerator(_square)
    
    return obj
end

debugPrint("Модуль перехвата размещения генератора загружен")

-- Инициализация
Events.OnGameStart.Add(function()
    debugPrint("Перехват размещения генератора активирован")
end)